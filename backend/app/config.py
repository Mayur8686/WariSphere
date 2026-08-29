"""Runtime configuration for WariSphere.

Values are read from environment variables so a hackathon demo and a
later production deploy can tune thresholds without code changes.
"""

from __future__ import annotations

import os


def _env_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        return float(raw)
    except ValueError:
        return default


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


# ---------------------------------------------------------------------------
# InsightFace
# ---------------------------------------------------------------------------

# buffalo_l is the accurate default; override with buffalo_s for a faster
# first load on CPU-only hackathon laptops.
# auto → InsightFace when the model pack is on disk, otherwise OpenCV Haar.
# Set to `insightface` to fail closed, or `opencv` to skip InsightFace.
FACE_BACKEND = os.environ.get("WARISPHERE_FACE_BACKEND", "auto").strip().lower() or "auto"

FACE_MODEL_NAME = os.environ.get("WARISPHERE_FACE_MODEL", "buffalo_l").strip() or "buffalo_l"

FACE_DET_SIZE = _env_int("WARISPHERE_FACE_DET_SIZE", 640)

FACE_EMBEDDING_VERSION = (
    os.environ.get("WARISPHERE_FACE_EMBEDDING_VERSION", "").strip()
    or f"insightface-{FACE_MODEL_NAME}-v1"
)

# How many probable matches to return from a scan.
FACE_MATCH_TOP_K = _env_int("WARISPHERE_FACE_MATCH_TOP_K", 5)

# Cosine-similarity thresholds (embeddings are L2-normalised, so cosine
# is the dot product). These MUST stay configurable — never scatter
# literals through the matching code.
#   >= HIGH      → "High confidence"
#   >= POSSIBLE  → "Possible match"
#   >= MIN       → "Low confidence" (still returned)
#   <  MIN       → dropped from results
FACE_SIMILARITY_HIGH = _env_float("WARISPHERE_FACE_SIM_HIGH", 0.75)
FACE_SIMILARITY_POSSIBLE = _env_float("WARISPHERE_FACE_SIM_POSSIBLE", 0.55)
FACE_SIMILARITY_MIN = _env_float("WARISPHERE_FACE_SIM_MIN", 0.35)

# Background model warmup on API boot. Tests should set this to 0.
FACE_WARMUP_ON_START = _env_bool("WARISPHERE_FACE_WARMUP", True)

# Generate embeddings in a background thread when a lost-person report
# is created with a photo. Tests should set this to 0 to avoid races.
AUTO_FACE_PROCESS = _env_bool("WARISPHERE_AUTO_FACE_PROCESS", True)

# Optional shared secret for authority-only matching endpoints.
# When empty (default / hackathon), the endpoints stay open like the rest
# of this API. When set, requests must send header X-Authority-Token.
AUTHORITY_TOKEN = os.environ.get("WARISPHERE_AUTHORITY_TOKEN", "").strip()
