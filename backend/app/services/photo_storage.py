"""Photo storage for lost-person reports.

Two backends behind one function:

* **Firebase Storage** when the service-account key is present (production) —
  the photo lands in the project bucket as `lost_persons/<id>.<ext>`.
* **Local disk** when Firebase is not configured (dev/CI, hackathon demos) —
  the photo lands in `backend/uploads/lost_persons/` and is served by
  FastAPI's static mount at `/uploads/lost_persons/<file>` so the whole
  flow works end-to-end before the Firebase project exists.

The type is validated from the file's *magic bytes* (never trust the
client-supplied content type or filename).
"""

import os
import re
import uuid
from datetime import timedelta

from fastapi import HTTPException, UploadFile

from app.firebase import firebase_ready

MAX_PHOTO_BYTES = 8 * 1024 * 1024  # 8 MB — plenty for a phone photo

# magic bytes → (extension, content type)
_SIGNATURES = {
    b"\xff\xd8\xff": (".jpg", "image/jpeg"),
    b"\x89PNG": (".png", "image/png"),
}


def _sniff(data: bytes) -> tuple[str, str]:
    """Return (extension, content_type) for JPEG/PNG/WebP, else raise 415."""
    for magic, kind in _SIGNATURES.items():
        if data.startswith(magic):
            return kind
    if len(data) > 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return (".webp", "image/webp")
    raise HTTPException(
        status_code=415,
        detail="Unsupported photo format — send JPEG, PNG or WebP.",
    )


def _safe_stem(stem: str | None) -> str:
    """Keep only [A-Za-z0-9-_] from a client-supplied stem (e.g. LP-4KD9F2)."""
    cleaned = re.sub(r"[^A-Za-z0-9._-]", "", stem or "").strip(".")
    return cleaned[:40] if cleaned else uuid.uuid4().hex[:12]


def uploads_root() -> str:
    """`backend/uploads/` (three levels up from this file: services → app → backend)."""
    root = os.environ.get("WARISPHERE_UPLOADS_DIR", "")
    if not root:
        root = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "uploads",
        )
    os.makedirs(os.path.join(root, "lost_persons"), exist_ok=True)
    return root


async def read_validated_photo(file: UploadFile) -> bytes:
    """Read an uploaded photo fully, enforcing size + real image type."""
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file — no photo received.")
    if len(data) > MAX_PHOTO_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Photo too large ({len(data) // (1024 * 1024)} MB) — 8 MB max.",
        )
    _sniff(data)  # raises 415 for non-images
    return data


def save_photo(data: bytes, stem: str | None = None) -> dict:
    """Persist `data` and return `{"photo_url", "stored_in"}`.

    The URL is absolute (or Firebase public) so the mobile app can load it
    directly; local dev URLs are built from the PUBLIC base URL when set.
    """
    ext, content_type = _sniff(data)
    filename = f"{_safe_stem(stem)}-{uuid.uuid4().hex[:8]}{ext}"

    if firebase_ready:
        url = _save_to_firebase(data, filename, content_type)
        if url:
            return {"photo_url": url, "stored_in": "firebase-storage"}

    # Dev fallback (also used if the Storage call failed): local disk.
    path = os.path.join(uploads_root(), "lost_persons", filename)
    with open(path, "wb") as fh:
        fh.write(data)

    base = os.environ.get("WARISPHERE_PUBLIC_BASE_URL", "").rstrip("/")
    if base:
        url = f"{base}/uploads/lost_persons/{filename}"
    else:
        url = f"/uploads/lost_persons/{filename}"
    return {"photo_url": url, "stored_in": "local-disk"}


def _save_to_firebase(data: bytes, filename: str, content_type: str) -> str | None:
    """Upload to Firebase Storage; public URL first, signed URL as fallback."""
    try:
        from firebase_admin import storage

        bucket = storage.bucket()
        blob = bucket.blob(f"lost_persons/{filename}")
        blob.upload_from_string(data, content_type=content_type)
        try:
            blob.make_public()
            return blob.public_url
        except Exception:
            # Bucket disallows public objects — hand out a 7-day signed URL.
            return blob.generate_signed_url(
                version="v4", expiration=timedelta(days=7), method="GET"
            )
    except Exception as e:  # storage not enabled, quota, offline …
        print(f"[photo_storage] Firebase Storage upload failed ({e}) — using local disk.")
        return None
