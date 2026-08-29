"""Shared test setup: no Firebase, no InsightFace warmup, isolated JSON store."""

import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("FIREBASE_SERVICE_ACCOUNT_PATH", "/nonexistent/key.json")
os.environ["WARISPHERE_FACE_WARMUP"] = "0"
os.environ["WARISPHERE_AUTO_FACE_PROCESS"] = "0"

# StaticFiles is mounted at import time, so the uploads dir must be stable
# for the whole pytest session (save_photo and GET /uploads share it).
_UPLOADS = tempfile.mkdtemp(prefix="warisphere-uploads-")
os.environ["WARISPHERE_UPLOADS_DIR"] = _UPLOADS

import pytest


@pytest.fixture(autouse=True)
def _isolate_store(tmp_path, monkeypatch):
    # Isolate the JSON record store per test. Photos stay in the session
    # uploads dir so FastAPI's /uploads mount can serve them.
    monkeypatch.setenv("WARISPHERE_DATA_DIR", str(tmp_path))
    yield
