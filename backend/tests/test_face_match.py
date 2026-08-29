"""Tests for AI face matching (no InsightFace model required).

    cd backend && python -m pytest tests/test_face_match.py -v
"""

import io
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

_TMP = tempfile.mkdtemp(prefix="warisphere-face-")
os.environ.setdefault("WARISPHERE_DATA_DIR", _TMP)
os.environ.setdefault("WARISPHERE_UPLOADS_DIR", os.path.join(_TMP, "uploads"))

from app.main import app  # noqa: E402
from app.services.face_match import (  # noqa: E402
    MultipleFacesError,
    NoFaceDetectedError,
    cosine_similarity,
    confidence_label,
    normalize_embedding,
    rank_by_cosine,
)
from app.services.lost_person import set_face_embedding  # noqa: E402

client = TestClient(app)

PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000d4944415478da6364f8cfc00000030101006b04e9a70000000049454e44ae426082"
)


def _reset():
    data_dir = Path(_TMP)
    for name in ("lost_persons.json", "face_matches.json"):
        path = data_dir / name
        if path.exists():
            path.unlink()


@pytest.fixture(autouse=True)
def _clean():
    _reset()
    yield
    _reset()


def test_cosine_similarity_identical_is_one():
    assert cosine_similarity([1, 0, 0], [1, 0, 0]) == pytest.approx(1.0)


def test_cosine_similarity_orthogonal_is_zero():
    assert cosine_similarity([1, 0], [0, 1]) == pytest.approx(0.0)


def test_normalize_embedding_unit_length():
    vec = normalize_embedding([3.0, 4.0])
    assert pytest.approx(float((vec ** 2).sum()) ** 0.5, rel=1e-5) == 1.0


def test_rank_by_cosine_orders_highest_first():
    query = [1.0, 0.0, 0.0]
    gallery = [
        ("low", [0.1, 0.9, 0.0]),
        ("high", [0.99, 0.01, 0.0]),
        ("mid", [0.6, 0.4, 0.0]),
    ]
    ranked = rank_by_cosine(query, gallery, top_k=3, min_similarity=0.0)
    assert [payload for _, payload in ranked][:2] == ["high", "mid"]


def test_confidence_label_uses_config_thresholds():
    assert confidence_label(0.9) == "High confidence"
    assert confidence_label(0.6) == "Possible match"
    assert confidence_label(0.4) == "Low confidence"


def test_list_response_strips_embeddings():
    created = client.post(
        "/lost-person",
        json={"name": "Sujal Bergal", "report_type": "lost", "last_seen_location": "Near MMCOE"},
    ).json()
    set_face_embedding(created["lost_person_id"], [0.1, 0.2, 0.3])

    listed = client.get("/lost-person").json()["reports"]
    assert listed
    for row in listed:
        assert "face_embedding" not in row

    created_again = client.post(
        "/lost-person",
        json={"name": "Someone", "client_report_id": "LP-NOEMBED"},
    ).json()
    assert "face_embedding" not in created_again


def _seed_missing(name, location, embedding, client_id):
    body = client.post(
        "/lost-person",
        json={
            "client_report_id": client_id,
            "report_type": "lost",
            "name": name,
            "last_seen_location": location,
            "description": f"Demo missing person {name}",
        },
    ).json()
    set_face_embedding(body["lost_person_id"], embedding)
    return body


def test_scan_match_ranks_and_confirm_reject(monkeypatch):
    sujal_emb = [1.0, 0.0, 0.0]
    other_a = [0.72, 0.69, 0.0]
    other_b = [0.55, 0.83, 0.0]

    sujal = _seed_missing("Sujal Bergal", "Near MMCOE", sujal_emb, "LP-SUJAL")
    _seed_missing("Anjali More", "Pune station", other_a, "LP-ANJALI")
    _seed_missing("Ramesh Patil", "Alandi ghat", other_b, "LP-RAMESH")

    from app.services import face_match as fm

    monkeypatch.setattr(fm, "extract_embedding", lambda _data: sujal_emb)
    monkeypatch.setattr(fm, "embedding_to_list", lambda v: [float(x) for x in v])

    resp = client.post(
        "/lost-person/scan-match",
        files={"file": ("found.png", io.BytesIO(PNG_1PX), "image/png")},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["success"] is True
    assert body["faces_detected"] == 1
    assert body["records_scanned"] == 3
    assert body["matches"]
    assert "face_embedding" not in body
    top = body["matches"][0]
    assert top["name"] == "Sujal Bergal"
    assert top["location"] == "Near MMCOE"
    assert top["status"] == "missing"
    assert top["match_score"] == 100
    assert top["match_id"]
    assert "face_embedding" not in top

    confirm = client.post(
        f"/lost-person/matches/{top['match_id']}/confirm",
        json={"verified_by": "demo-officer"},
    )
    assert confirm.status_code == 200, confirm.text
    assert confirm.json()["match"]["status"] == "confirmed"
    assert confirm.json()["match"]["verified_by"] == "demo-officer"
    assert confirm.json()["missing_person"]["status"] == "reunited"

    listed = client.get("/lost-person").json()["reports"]
    sujal_row = next(r for r in listed if r["lost_person_id"] == sujal["lost_person_id"])
    assert sujal_row["status"] == "reunited"
    assert "face_embedding" not in sujal_row

    # Second match can be rejected without changing that person.
    if len(body["matches"]) > 1:
        other = body["matches"][1]
        rejected = client.post(
            f"/lost-person/matches/{other['match_id']}/reject",
            json={"verified_by": "demo-officer"},
        )
        assert rejected.status_code == 200
        assert rejected.json()["match"]["status"] == "rejected"
        other_person = client.get("/lost-person").json()["reports"]
        other_row = next(
            r for r in other_person if r["lost_person_id"] == other["person_id"]
        )
        assert other_row["status"] == "missing"


def test_scan_match_no_face(monkeypatch):
    from app.services import face_match as fm

    def _boom(_data):
        raise NoFaceDetectedError()

    monkeypatch.setattr(fm, "extract_embedding", _boom)
    resp = client.post(
        "/lost-person/scan-match",
        files={"file": ("found.png", io.BytesIO(PNG_1PX), "image/png")},
    )
    assert resp.status_code == 422
    assert "No face detected" in resp.json()["detail"]


def test_scan_match_multiple_faces(monkeypatch):
    from app.services import face_match as fm

    def _boom(_data):
        raise MultipleFacesError()

    monkeypatch.setattr(fm, "extract_embedding", _boom)
    resp = client.post(
        "/lost-person/scan-match",
        files={"file": ("found.png", io.BytesIO(PNG_1PX), "image/png")},
    )
    assert resp.status_code == 422
    assert "Multiple faces" in resp.json()["detail"]


def test_scan_match_rejects_non_image():
    resp = client.post(
        "/lost-person/scan-match",
        files={"file": ("notes.txt", io.BytesIO(b"not an image"), "text/plain")},
    )
    assert resp.status_code == 415


def test_confirm_unknown_match_404():
    resp = client.post(
        "/lost-person/matches/does-not-exist/confirm",
        json={"verified_by": "demo"},
    )
    assert resp.status_code == 404
