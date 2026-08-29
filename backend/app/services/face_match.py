"""InsightFace-based face detection + embedding service.

The FaceAnalysis model is loaded **once** (lazy singleton) and reused for
every request. Cosine similarity is computed in-process against stored
embeddings — sequential scan is fine for the current prototype. The
`rank_by_cosine` helper is the seam where a FAISS / vector-DB index can
be dropped in later.

This module never writes images to disk.
"""

from __future__ import annotations

import os
import threading
from typing import Any, Iterable, Sequence

import numpy as np

from app import config


class FaceMatchError(Exception):
    """Base class for recoverable face-matching failures."""

    def __init__(self, message: str, *, code: str = "face_match_error"):
        super().__init__(message)
        self.message = message
        self.code = code


class InvalidImageError(FaceMatchError):
    def __init__(self, message: str = "Invalid image. Please upload a JPEG, PNG or WebP photograph."):
        super().__init__(message, code="invalid_image")


class NoFaceDetectedError(FaceMatchError):
    def __init__(
        self,
        message: str = "No face detected. Please upload a clear front-facing photograph.",
    ):
        super().__init__(message, code="no_face")


class MultipleFacesError(FaceMatchError):
    def __init__(
        self,
        message: str = "Multiple faces detected. Please upload a photograph containing one person.",
    ):
        super().__init__(message, code="multiple_faces")


class ModelInitError(FaceMatchError):
    def __init__(self, message: str = "AI model initialization failure. Face matching is temporarily unavailable."):
        super().__init__(message, code="model_init")


# ---------------------------------------------------------------------------
# Model singleton
# ---------------------------------------------------------------------------

_LOCK = threading.Lock()
_APP = None  # insightface.app.FaceAnalysis
_APP_ERROR: str | None = None
_APP_READY = False
_INSIGHTFACE_UNAVAILABLE = False


def _models_root() -> str:
    """Persist InsightFace weights under backend/.insightface (not the home dir)."""
    root = os.environ.get("INSIGHTFACE_HOME", "").strip()
    if not root:
        backend_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        root = os.path.join(backend_root, ".insightface")
    os.makedirs(root, exist_ok=True)
    os.environ["INSIGHTFACE_HOME"] = root
    return root


# GitHub release downloads often fail in locked-down sandboxes (SSL / CDN).
# Hugging Face mirrors the same buffalo_* ONNX files.
_HF_PACK_FILES = {
    "buffalo_l": ["det_10g.onnx", "w600k_r50.onnx"],
    "buffalo_s": ["det_500m.onnx", "w600k_mbf.onnx"],
    "buffalo_sc": ["det_500m.onnx", "w600k_mbf.onnx"],
}


def _download_file(url: str, dest: str) -> None:
    import requests

    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".part"
    last_error = None
    for verify in (True, False):
        try:
            with requests.get(url, stream=True, timeout=180, verify=verify, allow_redirects=True) as resp:
                resp.raise_for_status()
                with open(tmp, "wb") as fh:
                    for chunk in resp.iter_content(chunk_size=1024 * 1024):
                        if chunk:
                            fh.write(chunk)
            os.replace(tmp, dest)
            return
        except Exception as exc:
            last_error = exc
            continue
    raise RuntimeError(f"Failed to download {url}: {last_error}")


def _ensure_insightface_pack(name: str) -> None:
    """Make sure detection + recognition ONNX files exist before FaceAnalysis runs."""
    files = _HF_PACK_FILES.get(name)
    if not files:
        return
    dest_dir = os.path.join(_models_root(), "models", name)
    missing = [f for f in files if not os.path.isfile(os.path.join(dest_dir, f))]
    if not missing:
        return
    print(f"[face_match] downloading InsightFace pack '{name}' ({', '.join(missing)})")
    os.makedirs(dest_dir, exist_ok=True)
    for filename in missing:
        url = (
            "https://huggingface.co/public-data/insightface/resolve/main/"
            f"models/{name}/{filename}"
        )
        dest = os.path.join(dest_dir, filename)
        print(f"[face_match]   {filename}")
        _download_file(url, dest)


def _pack_present(name: str) -> bool:
    files = _HF_PACK_FILES.get(name) or []
    dest_dir = os.path.join(_models_root(), "models", name)
    return bool(files) and all(os.path.isfile(os.path.join(dest_dir, f)) for f in files)


def is_model_ready() -> bool:
    return (_APP_READY and _APP is not None) or _HAAR is not None


def model_error() -> str | None:
    return _APP_ERROR


def get_face_app():
    """Return the process-wide FaceAnalysis instance, loading it if needed."""
    global _APP, _APP_ERROR, _APP_READY

    if _APP is not None:
        return _APP

    with _LOCK:
        if _APP is not None:
            return _APP
        try:
            _models_root()
            from insightface.app import FaceAnalysis  # heavy import — keep lazy

            if not _pack_present(config.FACE_MODEL_NAME):
                # Don't block every request on a doomed CDN download unless
                # the operator explicitly asked for InsightFace-only mode.
                download = os.environ.get("WARISPHERE_FACE_DOWNLOAD", "").strip().lower() in {
                    "1", "true", "yes",
                }
                if config.FACE_BACKEND == "insightface" or download:
                    _ensure_insightface_pack(config.FACE_MODEL_NAME)
                else:
                    raise ModelInitError(
                        "InsightFace weights not installed. Place buffalo_l ONNX files in "
                        "backend/.insightface/models/buffalo_l/ or set WARISPHERE_FACE_DOWNLOAD=1."
                    )
            providers = ["CPUExecutionProvider"]
            app = FaceAnalysis(
                name=config.FACE_MODEL_NAME,
                root=_models_root(),
                allowed_modules=["detection", "recognition"],
                providers=providers,
            )
            # ctx_id=-1 → CPU. det_size is (w, h).
            det = int(config.FACE_DET_SIZE) or 640
            app.prepare(ctx_id=-1, det_size=(det, det))
            _APP = app
            _APP_READY = True
            _APP_ERROR = None
            print(f"[face_match] InsightFace model '{config.FACE_MODEL_NAME}' ready")
            return _APP
        except FaceMatchError:
            raise
        except Exception as exc:  # pragma: no cover - environment-specific
            _APP_ERROR = str(exc)
            _APP_READY = False
            raise ModelInitError(
                "AI model initialization failure. Face matching is temporarily unavailable."
            ) from exc


def warmup() -> bool:
    """Load the model now (called from a startup background thread)."""
    if config.FACE_BACKEND in {"opencv", "haar"}:
        try:
            _get_haar()
            print("[face_match] OpenCV Haar backend ready")
            return True
        except Exception as exc:
            print(f"[face_match] warmup failed: {exc}")
            return False
    try:
        get_face_app()
        return True
    except Exception as exc:
        print(f"[face_match] InsightFace warmup failed: {exc}")
        if config.FACE_BACKEND == "insightface":
            return False
        try:
            _get_haar()
            print("[face_match] falling back to OpenCV Haar until InsightFace weights are available")
            return True
        except Exception as fallback_exc:
            print(f"[face_match] warmup failed: {fallback_exc}")
            return False


_HAAR = None
_HAAR_LOCK = threading.Lock()


def _get_haar():
    global _HAAR
    if _HAAR is not None:
        return _HAAR
    import cv2

    path = os.path.join(cv2.data.haarcascades, "haarcascade_frontalface_default.xml")
    classifier = cv2.CascadeClassifier(path)
    if classifier.empty():
        raise ModelInitError("AI model initialization failure. Haar cascade could not be loaded.")
    _HAAR = classifier
    return _HAAR


def _opencv_extract(img) -> "np.ndarray":
    """Fallback face embedding when InsightFace weights are not on disk.

    Detects a single frontal face with OpenCV Haar and builds an L2-normalised
    HOG descriptor of the cropped face. Same-photo scans rank at ~1.0; this is
    still probable matching, not identity confirmation.
    """
    import cv2

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    haar = _get_haar()
    with _HAAR_LOCK:
        boxes = haar.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(48, 48))
        if boxes is None or len(boxes) == 0:
            # One more pass, slightly more lenient, for softer lighting.
            boxes = haar.detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3, minSize=(32, 32))
    if boxes is None or len(boxes) == 0:
        raise NoFaceDetectedError()
    if len(boxes) > 1:
        # Ignore tiny extra detections (common Haar false positives).
        areas = [int(w) * int(h) for (_, _, w, h) in boxes]
        largest = max(areas)
        boxes = [b for b, a in zip(boxes, areas) if a >= 0.45 * largest]
        if len(boxes) > 1:
            raise MultipleFacesError()

    x, y, w, h = boxes[0]
    pad = int(0.15 * max(w, h))
    x0 = max(0, x - pad)
    y0 = max(0, y - pad)
    x1 = min(gray.shape[1], x + w + pad)
    y1 = min(gray.shape[0], y + h + pad)
    crop = gray[y0:y1, x0:x1]
    if crop.size == 0:
        raise NoFaceDetectedError()
    face = cv2.resize(crop, (112, 112), interpolation=cv2.INTER_AREA)
    face = cv2.equalizeHist(face)

    try:
        from skimage.feature import hog

        features = hog(
            face,
            orientations=8,
            pixels_per_cell=(8, 8),
            cells_per_block=(2, 2),
            feature_vector=True,
        )
        return normalize_embedding(features)
    except Exception:
        flat = face.astype(np.float64).reshape(-1) / 255.0
        return normalize_embedding(flat)


# ---------------------------------------------------------------------------
# Image → embedding
# ---------------------------------------------------------------------------

def decode_image(image_bytes: bytes) -> "np.ndarray":
    """Decode image bytes to a BGR uint8 array. Raises InvalidImageError."""
    if not image_bytes:
        raise InvalidImageError("Empty file — no photo received.")
    try:
        import cv2
    except Exception as exc:  # pragma: no cover
        raise ModelInitError(
            "AI model initialization failure. OpenCV is not available on this server."
        ) from exc

    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None or img.size == 0:
        raise InvalidImageError()
    return img


def _as_vector(embedding: Sequence[float] | np.ndarray) -> np.ndarray:
    vec = np.asarray(embedding, dtype=np.float64).reshape(-1)
    if vec.size == 0:
        raise FaceMatchError("Empty face embedding.")
    return vec


def normalize_embedding(embedding: Sequence[float] | np.ndarray) -> np.ndarray:
    """L2-normalise a vector. Zero vectors are rejected."""
    vec = _as_vector(embedding)
    norm = float(np.linalg.norm(vec))
    if norm == 0.0:
        raise FaceMatchError("Face embedding was empty (zero vector).")
    return (vec / norm).astype(np.float32)


def embedding_to_list(embedding: Sequence[float] | np.ndarray) -> list[float]:
    """JSON / Firestore-safe Python floats (already normalised)."""
    vec = normalize_embedding(embedding)
    return [float(x) for x in vec.tolist()]


def extract_embedding(image_bytes: bytes) -> np.ndarray:
    """Detect a single face and return its L2-normalised embedding.

    Rejects images with zero faces or more than one face.
    """
    global _INSIGHTFACE_UNAVAILABLE
    img = decode_image(image_bytes)

    use_opencv = config.FACE_BACKEND in {"opencv", "haar"} or _INSIGHTFACE_UNAVAILABLE
    if not use_opencv:
        try:
            app = get_face_app()
            faces = app.get(img)
        except ModelInitError:
            if config.FACE_BACKEND == "insightface":
                raise
            _INSIGHTFACE_UNAVAILABLE = True
            print("[face_match] InsightFace unavailable — using OpenCV Haar fallback")
            return _opencv_extract(img)
        except FaceMatchError:
            raise
        except Exception as exc:
            raise FaceMatchError(f"Face embedding failure: {exc}") from exc

        if faces is None or len(faces) == 0:
            raise NoFaceDetectedError()
        if len(faces) > 1:
            raise MultipleFacesError()

        face = faces[0]
        raw = getattr(face, "normed_embedding", None)
        if raw is None:
            raw = getattr(face, "embedding", None)
        if raw is None:
            raise FaceMatchError("Face embedding failure: model returned no embedding.")
        return normalize_embedding(raw)

    return _opencv_extract(img)


def active_embedding_version() -> str:
    if _APP_READY:
        return config.FACE_EMBEDDING_VERSION
    return "opencv-haar-hog-v1"


# ---------------------------------------------------------------------------
# Similarity + ranking  (FAISS seam)
# ---------------------------------------------------------------------------

def cosine_similarity(a: Sequence[float], b: Sequence[float]) -> float:
    """Cosine similarity in [-1, 1]. Safe for zero / mismatched lengths."""
    va = np.asarray(list(a), dtype=np.float64).reshape(-1)
    vb = np.asarray(list(b), dtype=np.float64).reshape(-1)
    if va.size == 0 or vb.size == 0 or va.size != vb.size:
        return 0.0
    na = float(np.linalg.norm(va))
    nb = float(np.linalg.norm(vb))
    if na == 0.0 or nb == 0.0:
        return 0.0
    sim = float(np.dot(va, vb) / (na * nb))
    if sim > 1.0:
        return 1.0
    if sim < -1.0:
        return -1.0
    return sim


def confidence_label(similarity: float) -> str:
    """Human label for a cosine score. Thresholds come from config."""
    if similarity >= config.FACE_SIMILARITY_HIGH:
        return "High confidence"
    if similarity >= config.FACE_SIMILARITY_POSSIBLE:
        return "Possible match"
    return "Low confidence"


def rank_by_cosine(
    query: Sequence[float],
    gallery: Iterable[tuple[Any, Sequence[float]]],
    *,
    top_k: int | None = None,
    min_similarity: float | None = None,
) -> list[tuple[float, Any]]:
    """Rank gallery items by cosine similarity to `query`.

    `gallery` is an iterable of `(payload, embedding)`.

    Sequential scan is intentional for the prototype. To swap in FAISS
    later, replace the body with:

        import faiss
        matrix = np.vstack([normalize_embedding(e) for _, e in gallery])
        index = faiss.IndexFlatIP(matrix.shape[1])  # inner product == cosine
        index.add(matrix.astype('float32'))
        scores, idxs = index.search(query_vec[None, :], top_k)
    """
    k = config.FACE_MATCH_TOP_K if top_k is None else int(top_k)
    min_sim = config.FACE_SIMILARITY_MIN if min_similarity is None else float(min_similarity)

    scored: list[tuple[float, Any]] = []
    for payload, embedding in gallery:
        sim = cosine_similarity(query, embedding)
        if sim >= min_sim:
            scored.append((sim, payload))

    scored.sort(key=lambda item: item[0], reverse=True)
    if k > 0:
        return scored[:k]
    return scored
