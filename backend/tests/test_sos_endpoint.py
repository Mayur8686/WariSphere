"""End-to-end tests for POST /sos with a fake in-memory Firestore.

They verify the critical contract:
  1. the SOS document is stored in Firestore FIRST,
  2. SMS results are recorded back on that same document,
  3. an SMS failure NEVER fails the HTTP request or loses the document.

    cd backend && python -m pytest tests/ -v
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("FIREBASE_SERVICE_ACCOUNT_PATH", "/nonexistent/key.json")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import firebase  # noqa: E402
from app.services import sms  # noqa: E402
from app.services.sms import gateway  # noqa: E402


class FakeDocRef:
    def __init__(self, store, collection, doc_id):
        self._store = store
        self._collection = collection
        self._doc_id = doc_id

    def set(self, data):
        self._store.setdefault(self._collection, {})[self._doc_id] = dict(data)

    def update(self, data):
        self._store.setdefault(self._collection, {}).setdefault(
            self._doc_id, {}
        ).update(dict(data))

    def get(self):
        data = self._store.get(self._collection, {}).get(self._doc_id)

        class _Snap:
            exists = data is not None

            def to_dict(self_inner):
                return dict(data) if data else None

        return _Snap()


class FakeCollection:
    def __init__(self, store, name):
        self._store = store
        self._name = name

    def document(self, doc_id):
        return FakeDocRef(self._store, self._name, doc_id)


class FakeDb:
    def __init__(self):
        self.store = {}
        self.calls = []

    def collection(self, name):
        self.calls.append(name)
        return FakeCollection(self.store, name)


@pytest.fixture()
def fake_firebase(monkeypatch):
    """Wire the fake Firestore into the app without a service account."""
    fake_db = FakeDb()
    monkeypatch.setattr(firebase, "db", fake_db)
    monkeypatch.setattr(firebase, "firebase_ready", True)
    return fake_db


@pytest.fixture()
def client(monkeypatch):
    # Import lazily so the firebase monkeypatches above land first.
    from app.main import app

    # Dev mode SMS for deterministic, network-free endpoint tests;
    # individual tests override this.
    monkeypatch.setenv("SMS_PROVIDER", "none")
    with TestClient(app) as c:
        yield c


SOS_BODY = {
    "user_id": "WRI-ABC123",
    "latitude": 18.5204,
    "longitude": 73.8567,
    "sos_type": "medical",
    "message": "Near Yavat toll naka, leg injury",
    "user_name": "Mayur Patil",
    "user_phone": "9876543210",
    "accuracy_meters": 12.5,
    "emergency_contact_name": "Sunita Patil",
    "emergency_contact_phone": "9822011223",
}


# --------------------------------------------------------------------------

def test_post_sos_stores_alert_and_sms_results_with_none_provider(client, fake_firebase, monkeypatch):
    monkeypatch.setenv("SMS_PROVIDER", "none")

    resp = client.post("/sos", json=SOS_BODY)
    assert resp.status_code == 200, resp.text
    body = resp.json()

    assert body["sos_id"]
    assert body["emergency_contact_name"] == "Sunita Patil"
    assert body["emergency_contact_phone"] == "9822011223"
    assert body["status"] == "active"
    assert body["created_at"]

    # SMS summary is returned...
    sms_block = body["sms"]
    assert sms_block["provider"] == "none"
    assert sms_block["attempted"] == 1
    assert sms_block["results"][0]["status"] == "simulated"
    assert "+919822011223" in sms_block["results"][0]["phone"]
    # ...the message carries location + timestamp.
    assert "https://maps.google.com/?q=18.5204,73.8567" in sms_block["message"]
    assert "WariSphere SOS ALERT" in sms_block["message"]

    # ...and persisted onto the Firestore document.
    stored = fake_firebase.store["sos_alerts"][body["sos_id"]]
    assert stored["user_id"] == "WRI-ABC123"
    assert stored["sms"]["provider"] == "none"
    assert stored["sms"]["results"][0]["phone"].endswith("9822011223")


def test_sos_is_stored_before_sms_and_even_when_sms_fails(client, fake_firebase, monkeypatch):
    monkeypatch.setenv("SMS_PROVIDER", "fast2sms")
    monkeypatch.setenv("FAST2SMS_API_KEY", "fake-test-key")
    monkeypatch.setenv("SOS_CONTROL_ROOM_NUMBERS", "9876500000")

    import requests

    def _boom(*a, **k):
        raise requests.ConnectionError("simulated SMS provider outage")

    monkeypatch.setattr(gateway.requests, "post", _boom)

    # The endpoint must still succeed...
    resp = client.post("/sos", json=SOS_BODY)
    assert resp.status_code == 200, resp.text

    body = resp.json()
    # ...the document exists...
    stored = fake_firebase.store["sos_alerts"][body["sos_id"]]
    assert stored["user_id"] == "WRI-ABC123"
    # ...and the SMS failure is recorded, not swallowed.
    assert stored["sms"]["provider"] == "fast2sms"
    assert stored["sms"]["sent"] == 0
    assert all(r["status"] == "failed" for r in stored["sms"]["results"])
    assert "ConnectionError" in stored["sms"]["results"][0]["detail"]
    # Two recipients: ICE + control room.
    assert stored["sms"]["recipient_count"] == 2
    assert {r["phone"] for r in stored["sms"]["results"]} == {
        "+919822011223",
        "+919876500000",
    }


def test_post_sos_ice_plus_control_room_deduplicated(client, fake_firebase, monkeypatch):
    monkeypatch.setenv("SMS_PROVIDER", "none")
    # Control-room list duplicates the ICE contact in different formats.
    monkeypatch.setenv(
        "SOS_CONTROL_ROOM_NUMBERS", "9822011223,+919822011223,9876500000"
    )

    resp = client.post("/sos", json=SOS_BODY)
    assert resp.status_code == 200
    sms_block = resp.json()["sms"]
    phones = [r["phone"] for r in sms_block["results"]]
    assert phones == ["+919822011223", "+919876500000"]


def test_post_sos_no_recipients_does_not_request(client, fake_firebase, monkeypatch):
    monkeypatch.setenv("SMS_PROVIDER", "fast2sms")
    monkeypatch.setenv("FAST2SMS_API_KEY", "fake-test-key")
    monkeypatch.delenv("SOS_CONTROL_ROOM_NUMBERS", raising=False)

    def _no_post(*a, **k):
        raise AssertionError("SMS provider must not be called without recipients")

    monkeypatch.setattr(gateway.requests, "post", _no_post)

    body = {**SOS_BODY, "emergency_contact_phone": None}
    resp = client.post("/sos", json=body)
    assert resp.status_code == 200
    sms_block = resp.json()["sms"]
    assert sms_block["recipient_count"] == 0
    assert sms_block["attempted"] == 0
    assert sms_block["results"][0]["status"] == "skipped"


def test_post_sos_missing_provider_config_is_recorded(client, fake_firebase, monkeypatch):
    # fast2sms selected but no API key -> no crash, no HTTP, recorded.
    monkeypatch.setenv("SMS_PROVIDER", "fast2sms")
    monkeypatch.delenv("FAST2SMS_API_KEY", raising=False)

    def _no_post(*a, **k):
        raise AssertionError("provider must not be called without configuration")

    monkeypatch.setattr(gateway.requests, "post", _no_post)

    resp = client.post("/sos", json=SOS_BODY)
    assert resp.status_code == 200
    sms_block = resp.json()["sms"]
    assert all(r["status"] == "skipped" for r in sms_block["results"])
    assert "FAST2SMS_API_KEY" in sms_block["results"][0]["detail"]


def test_post_sos_requires_user_id(client, fake_firebase):
    resp = client.post("/sos", json={"latitude": 18.5})
    assert resp.status_code == 422


def test_post_sos_tolerates_missing_gps_and_contact(client, fake_firebase, monkeypatch):
    monkeypatch.setenv("SMS_PROVIDER", "none")
    resp = client.post("/sos", json={"user_id": "WRI-NO-LOC"})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["latitude"] is None and body["longitude"] is None
    # No recipients at all -> recorded skip, still 200.
    assert body["sms"]["recipient_count"] == 0


def test_post_sos_sms_module_never_propagates(client, fake_firebase, monkeypatch):
    # Even an unexpected exception inside dispatch is contained.
    def _boom(*a, **k):
        raise RuntimeError("unexpected SMS catastrophe")

    monkeypatch.setattr(sms, "dispatch_sos_sms", _boom)

    resp = client.post("/sos", json=SOS_BODY)
    assert resp.status_code == 200
    stored = fake_firebase.store["sos_alerts"][resp.json()["sos_id"]]
    assert stored["user_id"] == "WRI-ABC123"  # alert survived


def test_post_sos_503_without_firestore(client, monkeypatch):
    # Real module state: no key configured in this test run.
    monkeypatch.setattr(firebase, "db", None)
    monkeypatch.setattr(firebase, "firebase_ready", False)
    resp = client.post("/sos", json=SOS_BODY)
    assert resp.status_code == 503
