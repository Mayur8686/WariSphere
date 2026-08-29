"""Tests for the lost-person endpoints (run without any Firebase config —
they exercise the dev-mode JSON store + local photo disk path).

    cd backend && python -m pytest tests/ -v
"""

import io
import json
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("FIREBASE_SERVICE_ACCOUNT_PATH", "/nonexistent/key.json")
os.environ["WARISPHERE_FACE_WARMUP"] = "0"
os.environ["WARISPHERE_AUTO_FACE_PROCESS"] = "0"

import pytest
from fastapi.testclient import TestClient

# Point the runtime data/uploads dirs at a temp dir before importing the app.
_TMP = tempfile.mkdtemp(prefix="warisphere-test-")
os.environ.setdefault("WARISPHERE_DATA_DIR", _TMP)
os.environ.setdefault("WARISPHERE_UPLOADS_DIR", os.path.join(_TMP, "uploads"))

from app.main import app  # noqa: E402

client = TestClient(app)

# 1x1 transparent PNG
PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000d4944415478da6364f8cfc00000030101006b04e9a70000000049454e44ae426082"
)

REPORT = {
    "client_report_id": "LP-TEST01",
    "report_type": "lost",
    "name": "Rambhau Kedari",
    "age": 68,
    "gender": "Male",
    "description": "White kurta, orange topi, walks with a stick.",
    "last_seen_location": "Near Yavat toll naka",
    "last_seen_time": "2026-08-28T18:30:00Z",
    "last_seen_latitude": 18.3712,
    "last_seen_longitude": 74.2671,
    "reporter_id": "WRI-ABC123",
    "reporter_name": "Demo Warkari",
    "reporter_phone": "9876543210",
}


def _reset_store():
    data_file = Path(_TMP) / "lost_persons.json"
    if data_file.exists():
        data_file.unlink()


@pytest.fixture(autouse=True)
def _clean(tmp_path):
    _reset_store()
    yield
    _reset_store()


def test_create_report_stores_details():
    resp = client.post("/lost-person", json=REPORT)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["name"] == "Rambhau Kedari"
    assert body["age"] == 68
    assert body["gender"] == "Male"
    assert body["last_seen_location"] == "Near Yavat toll naka"
    assert body["last_seen_latitude"] == 18.3712
    assert body["reporter_phone"] == "9876543210"
    assert body["status"] == "missing"
    assert body["lost_person_id"]
    assert body["stored_in"] in {"local-dev", "firestore"}

    # Actually persisted in the dev store file
    data_file = Path(os.environ["WARISPHERE_DATA_DIR"]) / "lost_persons.json"
    assert data_file.exists()
    saved = json.loads(data_file.read_text())
    assert len(saved) == 1 and saved[0]["name"] == "Rambhau Kedari"


def test_create_is_idempotent_for_same_client_id():
    first = client.post("/lost-person", json=REPORT).json()
    second = client.post("/lost-person", json=REPORT).json()
    assert second["duplicate"] is True
    assert second["lost_person_id"] == first["lost_person_id"]


def test_found_report_gets_found_status():
    resp = client.post("/lost-person", json={**REPORT, "report_type": "found",
                                             "client_report_id": "LP-TEST02"})
    assert resp.json()["status"] == "found"


def test_minimal_report_only_needs_name():
    resp = client.post("/lost-person", json={"name": "Unknown boy"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Unknown boy"
    assert body["age"] is None and body["photo_url"] is None


def test_bad_report_type_rejected():
    resp = client.post("/lost-person", json={"name": "X", "report_type": "zombie"})
    assert resp.status_code == 422


def test_photo_upload_returns_url_and_serves_file():
    resp = client.post(
        "/lost-person/photo",
        files={"file": ("person.png", io.BytesIO(PNG_1PX), "image/png")},
        data={"client_report_id": "LP-TEST01"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["stored_in"] == "local-disk"
    assert body["photo_url"].startswith("/uploads/lost_persons/")

    # The photo is actually retrievable.
    get = client.get(body["photo_url"])
    assert get.status_code == 200
    assert get.content == PNG_1PX


def test_photo_upload_rejects_non_images():
    resp = client.post(
        "/lost-person/photo",
        files={"file": ("notes.txt", io.BytesIO(b"just text, not an image"), "text/plain")},
    )
    assert resp.status_code == 415


def test_photo_upload_rejects_empty_file():
    resp = client.post(
        "/lost-person/photo",
        files={"file": ("empty.png", io.BytesIO(b""), "image/png")},
    )
    assert resp.status_code == 400


def test_full_flow_photo_then_report_then_list_then_reunited():
    photo = client.post(
        "/lost-person/photo",
        files={"file": ("p.png", io.BytesIO(PNG_1PX), "image/png")},
        data={"client_report_id": "LP-FLOW1"},
    ).json()

    created = client.post(
        "/lost-person", json={**REPORT, "client_report_id": "LP-FLOW1",
                              "photo_url": photo["photo_url"]}
    ).json()
    assert created["photo_url"] == photo["photo_url"]

    listed = client.get("/lost-person").json()["reports"]
    assert any(r["lost_person_id"] == created["lost_person_id"] for r in listed)
    assert any(r.get("photo_url") for r in listed)

    filtered = client.get("/lost-person", params={"status": "missing"}).json()["reports"]
    assert len(filtered) >= 1

    patched = client.patch(
        f"/lost-person/{created['lost_person_id']}/status",
        json={"status": "reunited"},
    )
    assert patched.status_code == 200
    assert patched.json()["status"] == "reunited"

    missing = client.get("/lost-person", params={"status": "missing"}).json()["reports"]
    assert not any(r["lost_person_id"] == created["lost_person_id"] for r in missing)

    gone = client.patch("/lost-person/does-not-exist/status",
                        json={"status": "reunited"})
    assert gone.status_code == 404


def test_list_rejects_bad_status():
    assert client.get("/lost-person", params={"status": "zombie"}).status_code == 422
