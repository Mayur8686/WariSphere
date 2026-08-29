"""Tests for the volunteer + task system (dev-mode local store, no Firebase).

Exercises the whole role-based flow end to end:
authority login → create volunteers → seed SOS → assign → volunteer
lifecycle → SOS resolution sync → security guards.

    cd backend && python -m pytest tests/test_volunteers_tasks.py -v
"""

import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("FIREBASE_SERVICE_ACCOUNT_PATH", "/nonexistent/key.json")
os.environ["WARISPHERE_FACE_WARMUP"] = "0"
os.environ["WARISPHERE_AUTO_FACE_PROCESS"] = "0"
_TMP = tempfile.mkdtemp(prefix="warisphere-vol-test-")
os.environ.setdefault("WARISPHERE_DATA_DIR", _TMP)

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402
from app.services import auth as auth_service  # noqa: E402

client = TestClient(app)

AUTH_TOKEN = f"dev:{auth_service.DEV_AUTHORITY_UID}"
AUTH = {"Authorization": f"Bearer {AUTH_TOKEN}"}

RAHUL = {
    "name": "Rahul Patil",
    "email": "rahul.patil@warisphere.dev",
    "password": "Volunteer@123",
    "phone": "+91 98220 11223",
    "zone": "Sector A - MMCOE",
    "skills": ["First Aid", "Emergency Response"],
}

OM = {
    "name": "Om Shinde",
    "email": "om.shinde@warisphere.dev",
    "password": "Volunteer@123",
    "phone": "+91 98220 22334",
    "zone": "Sector B - Alandi",
    "skills": ["Crowd Management"],
}


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------


def _create_volunteer(payload=None):
    response = client.post("/volunteers", json=payload or RAHUL, headers=AUTH)
    assert response.status_code == 201, response.text
    return response.json()


def _volunteer_headers(email, password):
    response = client.post("/auth/dev-session", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    token = response.json()["token"]
    return {"Authorization": f"Bearer {token}"}


def _create_sos():
    response = client.post("/sos", json={
        "user_id": "WRI-TEST01",
        "sos_type": "medical",
        "message": "Medical emergency near MMCOE",
        "user_name": "Sujal Bergal",
        "user_phone": "9876543210",
        "latitude": 18.5183,
        "longitude": 73.9276,
    })
    assert response.status_code == 200, response.text
    return response.json()


def _assign_from_sos(sos_id, volunteer_uid, priority="high"):
    return client.post("/tasks", json={
        "type": "sos",
        "title": "Medical Emergency",
        "description": "Warkari needs urgent help.",
        "priority": priority,
        "assigned_to": volunteer_uid,
        "source_kind": "sos",
        "source_id": sos_id,
        "location": {"latitude": 18.5183, "longitude": 73.9276, "address": "Near MMCOE"},
    }, headers=AUTH)


# ---------------------------------------------------------------------------
# auth / roles
# ---------------------------------------------------------------------------


def test_dev_session_and_me():
    auth_service.ensure_dev_authority()
    response = client.post("/auth/dev-session", json={
        "email": auth_service.DEV_AUTHORITY_EMAIL,
        "password": auth_service.DEV_AUTHORITY_PASSWORD,
    })
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["role"] == "authority"

    me = client.get("/auth/me", headers={"Authorization": f"Bearer {body['token']}"})
    assert me.status_code == 200
    assert me.json()["role"] == "authority"

    bad = client.post("/auth/dev-session", json={
        "email": auth_service.DEV_AUTHORITY_EMAIL, "password": "wrong"})
    assert bad.status_code == 401


def test_missing_and_foreign_tokens_rejected():
    assert client.get("/volunteers").status_code == 401
    assert client.get("/tasks").status_code == 401
    assert client.get("/auth/me").status_code == 401
    response = client.get("/volunteers", headers={"Authorization": "Bearer dev:ghost"})
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# volunteer management
# ---------------------------------------------------------------------------


def test_authority_creates_volunteer_and_lists():
    record = _create_volunteer()
    assert record["role"] == "volunteer"
    assert record["status"] == "active"
    assert record["availability"] == "available"
    assert record["created_by"] == auth_service.DEV_AUTHORITY_UID
    assert set(record["skills"]) == {"first aid", "emergency response"}

    listing = client.get("/volunteers", headers=AUTH)
    assert listing.status_code == 200
    body = listing.json()
    assert body["summary"]["total"] >= 1
    assert any(v["uid"] == record["uid"] for v in body["volunteers"])

    dup = client.post("/volunteers", json=RAHUL, headers=AUTH)
    assert dup.status_code == 409


def test_volunteer_cannot_act_as_authority():
    _create_volunteer()
    headers = _volunteer_headers(RAHUL["email"], RAHUL["password"])

    assert client.get("/volunteers", headers=headers).status_code == 403
    assert client.get("/tasks", headers=headers).status_code == 403
    assert client.post("/volunteers", json=OM, headers=headers).status_code == 403
    assert client.get("/volunteers/someone-else", headers=headers).status_code == 403

    me = client.get("/volunteers/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["email"] == RAHUL["email"]


def test_volunteer_profile_safe_fields_only():
    volunteer = _create_volunteer()
    headers = _volunteer_headers(RAHUL["email"], RAHUL["password"])

    ok = client.patch(f"/volunteers/{volunteer['uid']}", json={"phone": "+91 90000 00000"}, headers=headers)
    assert ok.status_code == 200
    assert ok.json()["phone"] == "+91 90000 00000"

    # role/ownership/counters simply are not editable fields
    sneaky = client.patch(
        f"/volunteers/{volunteer['uid']}",
        json={"phone": "+91 11111", "role": "authority", "tasks_completed": 99},
        headers=headers,
    )
    assert sneaky.status_code == 200
    assert sneaky.json()["role"] == "volunteer"
    assert sneaky.json()["tasks_completed"] == 0

    # volunteers cannot rename themselves or change skills
    blocked = client.patch(f"/volunteers/{volunteer['uid']}", json={"name": "Hacker"}, headers=headers)
    assert blocked.status_code == 403


def test_authority_suspends_and_reactivates():
    volunteer = _create_volunteer()
    suspended = client.patch(
        f"/volunteers/{volunteer['uid']}/status", json={"status": "suspended"}, headers=AUTH)
    assert suspended.status_code == 200

    # suspended account can no longer authenticate/use APIs
    me = client.get("/volunteers/me", headers={"Authorization": f"Bearer dev:{volunteer['uid']}"})
    assert me.status_code == 403

    revived = client.patch(
        f"/volunteers/{volunteer['uid']}/status", json={"status": "active"}, headers=AUTH)
    assert revived.status_code == 200
    assert revived.json()["status"] == "active"


# ---------------------------------------------------------------------------
# full task lifecycle + SOS sync
# ---------------------------------------------------------------------------


def test_full_sos_task_lifecycle():
    volunteer = _create_volunteer()
    headers = _volunteer_headers(RAHUL["email"], RAHUL["password"])
    sos = _create_sos()

    created = _assign_from_sos(sos["sos_id"], volunteer["uid"])
    assert created.status_code == 201, created.text
    task = created.json()
    assert task["status"] == "assigned"
    assert task["assigned_volunteer_name"] == "Rahul Patil"
    assert task["incident"]["person_name"] == "Sujal Bergal"  # auto snapshot
    assert task["source_id"] == sos["sos_id"]

    # volunteer became busy; SOS flipped to assigned
    assert client.get("/volunteers/me", headers=headers).json()["availability"] == "busy"
    sos_now = client.get(f"/sos/{sos['sos_id']}").json()
    assert sos_now["status"] == "assigned"
    assert sos_now["assigned_volunteer_name"] == "Rahul Patil"

    # duplicate active task on the same SOS is refused
    om = _create_volunteer(OM)
    dup = _assign_from_sos(sos["sos_id"], om["uid"])
    assert dup.status_code == 409

    # invalid jump: start before accept
    early = client.patch(f"/tasks/{task['task_id']}/start", headers=headers)
    assert early.status_code == 409

    # volunteer sees it as their active task
    mine = client.get("/tasks/my", headers=headers)
    assert mine.status_code == 200
    assert mine.json()["tasks"][0]["task_id"] == task["task_id"]

    # accept → start → complete
    accept = client.patch(f"/tasks/{task['task_id']}/accept", headers=headers)
    assert accept.status_code == 200
    assert accept.json()["status"] == "accepted"
    assert client.get(f"/sos/{sos['sos_id']}").json()["status"] == "accepted"

    start = client.patch(f"/tasks/{task['task_id']}/start", headers=headers)
    assert start.status_code == 200
    assert start.json()["status"] == "in_progress"
    assert client.get(f"/sos/{sos['sos_id']}").json()["status"] == "in_progress"

    done = client.patch(
        f"/tasks/{task['task_id']}/complete",
        json={"note": "Person assisted and handed over to medical team."},
        headers=headers,
    )
    assert done.status_code == 200
    body = done.json()
    assert body["status"] == "completed"
    assert body["completion_note"] == "Person assisted and handed over to medical team."
    assert body["completed_at"] is not None

    resolved = client.get(f"/sos/{sos['sos_id']}").json()
    assert resolved["status"] == "resolved"
    assert resolved["response_seconds"] >= 0

    # volunteer released → available, counters updated, task in history
    profile = client.get("/volunteers/me", headers=headers).json()
    assert profile["availability"] == "available"
    assert profile["tasks_completed"] == 1
    assert profile["tasks_active"] == 0

    history = client.get("/tasks/my?view=completed", headers=headers).json()
    assert history["count"] == 1

    # completed is terminal
    again = client.patch(f"/tasks/{task['task_id']}/accept", headers=headers)
    assert again.status_code == 409


def test_cross_volunteer_access_blocked():
    rahul = _create_volunteer()
    _create_volunteer(OM)
    om_headers = _volunteer_headers(OM["email"], OM["password"])

    manual = client.post("/tasks", json={
        "type": "general",
        "title": "Crowd build-up at bridge",
        "priority": "medium",
        "assigned_to": rahul["uid"],
    }, headers=AUTH)
    task_id = manual.json()["task_id"]

    assert client.get(f"/tasks/{task_id}", headers=om_headers).status_code == 403
    assert client.patch(f"/tasks/{task_id}/accept", headers=om_headers).status_code == 403


def test_assignment_guards_busy_and_offline():
    rahul = _create_volunteer()
    om = _create_volunteer(OM)
    om_headers = _volunteer_headers(OM["email"], OM["password"])

    client.post("/tasks", json={
        "type": "general", "title": "Task A", "assigned_to": rahul["uid"],
    }, headers=AUTH)

    # Rahul is busy now (auto), Om goes offline manually
    gone = client.patch("/volunteers/me/availability", json={"availability": "offline"}, headers=om_headers)
    assert gone.status_code == 200

    assert client.post("/tasks", json={
        "type": "general", "title": "Task B", "assigned_to": rahul["uid"],
    }, headers=AUTH).status_code == 409

    assert client.post("/tasks", json={
        "type": "general", "title": "Task C", "assigned_to": om["uid"],
    }, headers=AUTH).status_code == 409

    # Rahul cannot mark himself available mid-task
    rahul_headers = _volunteer_headers(RAHUL["email"], RAHUL["password"])
    blocked = client.patch("/volunteers/me/availability", json={"availability": "available"}, headers=rahul_headers)
    assert blocked.status_code == 409


def test_reject_then_reassign_to_another_volunteer():
    rahul = _create_volunteer()
    om = _create_volunteer(OM)
    rahul_headers = _volunteer_headers(RAHUL["email"], RAHUL["password"])
    sos = _create_sos()

    task = _assign_from_sos(sos["sos_id"], rahul["uid"]).json()

    rejected = client.patch(
        f"/tasks/{task['task_id']}/reject",
        json={"note": "Too far from my zone"},
        headers=rahul_headers,
    )
    assert rejected.status_code == 200
    assert rejected.json()["status"] == "rejected"

    # Rahul released, SOS back to the unassigned queue
    assert client.get("/volunteers/me", headers=rahul_headers).json()["availability"] == "available"
    assert client.get(f"/sos/{sos['sos_id']}").json()["status"] == "active"

    reassigned = client.post(
        f"/tasks/{task['task_id']}/assign",
        json={"volunteer_id": om["uid"]},
        headers=AUTH,
    )
    assert reassigned.status_code == 200
    body = reassigned.json()
    assert body["status"] == "assigned"
    assert body["assigned_to"] == om["uid"]
    assert body["accepted_at"] is None
    assert client.get(f"/sos/{sos['sos_id']}").json()["status"] == "assigned"


def test_unable_to_complete_and_cancel():
    rahul = _create_volunteer()
    headers = _volunteer_headers(RAHUL["email"], RAHUL["password"])

    t1 = client.post("/tasks", json={
        "type": "lost_person", "title": "Search near ghat", "assigned_to": rahul["uid"],
    }, headers=AUTH).json()
    client.patch(f"/tasks/{t1['task_id']}/accept", headers=headers)

    stuck = client.patch(
        f"/tasks/{t1['task_id']}/unable-to-complete",
        json={"note": "Area flooded, cannot reach"},
        headers=headers,
    )
    assert stuck.status_code == 200
    assert stuck.json()["status"] == "unable_to_complete"
    assert stuck.json()["resolution_note"] == "Area flooded, cannot reach"

    # cancelled → terminal for the volunteer, reassignable by authority
    cancel = client.patch(f"/tasks/{t1['task_id']}/cancel", headers=AUTH)
    assert cancel.status_code == 200
    revive = client.post(
        f"/tasks/{t1['task_id']}/assign", json={"volunteer_id": rahul["uid"]}, headers=AUTH)
    assert revive.status_code == 200
    assert revive.json()["status"] == "assigned"


def test_authority_resolve_sos_cancels_open_task():
    rahul = _create_volunteer()
    headers = _volunteer_headers(RAHUL["email"], RAHUL["password"])
    sos = _create_sos()
    task = _assign_from_sos(sos["sos_id"], rahul["uid"]).json()

    resolved = client.patch(f"/sos/{sos['sos_id']}/status", json={"status": "resolved"}, headers=AUTH)
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"

    cancelled = client.get(f"/tasks/{task['task_id']}", headers=AUTH)
    assert cancelled.json()["status"] == "cancelled"
    assert client.get("/volunteers/me", headers=headers).json()["availability"] == "available"

    # unauthenticated resolve is refused
    denied = client.patch(f"/sos/{sos['sos_id']}/status", json={"status": "resolved"})
    assert denied.status_code == 401


def test_lost_person_task_snapshot_and_sos_legacy_flow_unchanged():
    # legacy intake behaviour: creating an SOS still returns the record
    sos = _create_sos()
    assert sos["status"] == "active"
    assert sos["stored_in"] == "local-dev"

    listing = client.get("/sos")
    assert listing.status_code == 200
    assert any(a["sos_id"] == sos["sos_id"] for a in listing.json()["alerts"])

    # lost-person task carries a person snapshot for the volunteer
    person = client.post("/lost-person", json={
        "client_report_id": "LP-VOL-TEST",
        "report_type": "lost",
        "name": "Sujal Bergal",
        "age": 22,
        "description": "Yellow shirt, short black hair.",
        "last_seen_location": "Near MMCOE",
    })
    assert person.status_code == 200
    pid = person.json()["lost_person_id"]

    rahul = _create_volunteer()
    task = client.post("/tasks", json={
        "type": "lost_person",
        "title": "Locate Sujal Bergal",
        "priority": "high",
        "assigned_to": rahul["uid"],
        "source_kind": "lost_person",
        "source_id": pid,
        "location": {"address": "Near MMCOE"},
    }, headers=AUTH)
    assert task.status_code == 201, task.text
    body = task.json()
    assert body["incident"]["person_name"] == "Sujal Bergal"
    assert "Yellow shirt" in body["incident"]["details"]


def test_multi_skill_summary_counts():
    _create_volunteer()
    _create_volunteer(OM)
    listing = client.get("/volunteers", headers=AUTH).json()
    summary = listing["summary"]
    assert summary["total"] == 2
    assert summary["active"] == 2
    assert summary["available"] == 2
    assert summary["busy"] == 0


@pytest.fixture(autouse=True)
def _seed_authority():
    auth_service.ensure_dev_authority()
    yield
