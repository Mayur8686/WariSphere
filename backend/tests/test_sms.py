"""Tests for the pluggable SOS SMS gateway.

    cd backend && python -m pytest tests/ -v

No real HTTP is ever made — `requests.post` is replaced with a mock.
No credentials live here: every key/token is a fake, obviously-invalid
string.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest  # noqa: E402

from app.config import SmsSettings  # noqa: E402
from app.services.sms import collect_recipients, normalize_phone  # noqa: E402
from app.services.sms import gateway  # noqa: E402
from app.services.sms.message import build_sos_message  # noqa: E402


SOS_RECORD = {
    "sos_id": "SOS-TEST-1",
    "user_id": "WRI-ABC123",
    "user_name": "Mayur Patil",
    "user_phone": "9876543210",
    "sos_type": "medical",
    "message": "Near Yavat toll naka",
    "latitude": 18.5204,
    "longitude": 73.8567,
    "emergency_contact_name": "Sunita Patil",
    "emergency_contact_phone": "9822011223",
}


# --------------------------------------------------------------------------
# Phone normalization
# --------------------------------------------------------------------------

@pytest.mark.parametrize(
    "raw,expected",
    [
        ("9876543210", "+919876543210"),          # 10-digit Indian
        ("09876543210", "+919876543210"),         # trunk-prefixed
        ("+919876543210", "+919876543210"),       # already E.164
        ("+91 98765 43210", "+919876543210"),     # formatted
        ("91-98765-43210", "+919876543210"),      # country code, no plus
        ("919876543210", "+919876543210"),        # country code, no plus
        ("  98765 43210 ", "+919876543210"),      # spaces inside
        ("+14155550100", "+14155550100"),         # foreign E.164 kept
        ("+1 (415) 555-0100", "+14155550100"),    # formatted foreign
        ("0014155550100", "+14155550100"),        # 00 international prefix
        ("", None),
        (None, None),
        ("12345", None),                          # too short
        ("not-a-number", None),
    ],
)
def test_normalize_phone(raw, expected):
    assert normalize_phone(raw) == expected


def test_normalize_phone_respects_country_code():
    assert normalize_phone("9876543210", default_country_code="+44") == "+449876543210"


def test_collect_recipients_ice_first_then_control_rooms():
    recipients = collect_recipients(
        "9822011223",
        ["9876500000", "+919876500001"],
    )
    assert recipients == ["+919822011223", "+919876500000", "+919876500001"]


def test_collect_recipients_deduplicates():
    # ICE and a control-room entry are the same person, plus a literal
    # duplicate in the control-room list — one message each only.
    recipients = collect_recipients(
        "+919822011223",
        ["9822011223", "09822011223", "9876500000", "9876500000"],
    )
    assert recipients == ["+919822011223", "+919876500000"]
    assert len(recipients) == len(set(recipients))


def test_collect_recipients_works_without_ice():
    assert collect_recipients(None, ["9876500000"]) == ["+919876500000"]
    assert collect_recipients("", ["9876500000"]) == ["+919876500000"]


def test_collect_recipients_works_without_control_rooms():
    assert collect_recipients("9822011223", []) == ["+919822011223"]
    assert collect_recipients("9822011223", None) == ["+919822011223"]


def test_collect_recipients_empty_when_nothing_valid():
    assert collect_recipients(None, []) == []
    assert collect_recipients("123", ["bad"]) == []


# --------------------------------------------------------------------------
# Message
# --------------------------------------------------------------------------

def test_message_contains_all_emergency_details():
    from datetime import datetime, timezone

    msg = build_sos_message(
        user_name="Mayur Patil",
        user_phone="9876543210",
        sos_type="medical",
        message="Leg injury",
        latitude=18.5204,
        longitude=73.8567,
        created_at=datetime(2026, 8, 29, 10, 30, 0, tzinfo=timezone.utc),
    )
    assert "WariSphere SOS ALERT" in msg
    assert "Mayur Patil" in msg
    assert "9876543210" in msg
    assert "medical" in msg
    assert "Leg injury" in msg
    assert "https://maps.google.com/?q=18.5204,73.8567" in msg
    assert "2026-08-29 10:30:00" in msg  # UTC timestamp included


def test_message_handles_missing_gps_and_name():
    msg = build_sos_message(sos_type="general")
    assert "GPS unavailable" in msg
    assert "WariSphere SOS ALERT" in msg
    # A timestamp is always present even without an explicit one.
    import re
    assert re.search(r"Time \(UTC\): \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", msg)


# --------------------------------------------------------------------------
# Provider: none (dev mode)
# --------------------------------------------------------------------------

def test_none_provider_makes_no_http_request(monkeypatch):
    settings = SmsSettings(provider="none")

    called = {"post": False}

    def _no_post(*args, **kwargs):
        called["post"] = True
        raise AssertionError("none provider must not perform HTTP")

    monkeypatch.setattr(gateway.requests, "post", _no_post)

    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=settings)

    assert called["post"] is False
    assert summary["provider"] == "none"
    assert summary["recipient_count"] == 1  # ICE only
    assert summary["attempted"] == 1
    assert all(r["status"] == "simulated" for r in summary["results"])
    # No credential fields can leak into stored results.
    for r in summary["results"]:
        assert "api_key" not in r and "auth_token" not in r


# --------------------------------------------------------------------------
# Provider: fast2sms
# --------------------------------------------------------------------------

FAST2SMS = SmsSettings(
    provider="fast2sms",
    fast2sms_api_key="fake-test-key-not-a-real-secret",
    fast2sms_sender_id="FSTSMS",
    control_room_numbers=("9876500000",),
)


def test_fast2sms_request_shape_and_success(monkeypatch):
    captured = {}

    class _Resp:
        status_code = 200

        def json(self):
            return {"return": True, "request_id": "F2S-REQ-123", "message": "Sent"}

    def _fake_post(url, headers=None, data=None, timeout=None):
        captured["url"] = url
        captured["headers"] = headers
        captured["data"] = data
        captured["timeout"] = timeout
        return _Resp()

    monkeypatch.setattr(gateway.requests, "post", _fake_post)

    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=FAST2SMS)

    assert captured["url"] == "https://www.fast2sms.com/dev/bulkV2"
    # Key is sent as the authorization header...
    assert captured["headers"]["authorization"] == "fake-test-key-not-a-real-secret"
    # ...but never lands in the stored results.
    assert captured["data"]["route"] == "q"
    assert captured["data"]["sender_id"] == "FSTSMS"
    # Numbers are comma-joined without the "+".
    assert captured["data"]["numbers"] == "919822011223,919876500000"
    assert "WariSphere SOS ALERT" in captured["data"]["message"]
    assert captured["timeout"] == FAST2SMS.timeout_seconds

    assert summary["provider"] == "fast2sms"
    assert summary["recipient_count"] == 2
    assert summary["attempted"] == 2
    assert summary["sent"] == 2
    assert all(r["status"] == "sent" for r in summary["results"])
    assert all(r["message_id"] == "F2S-REQ-123" for r in summary["results"])
    assert "fake-test-key" not in str(summary)


def test_fast2sms_failure_response_marks_failed(monkeypatch):
    class _Resp:
        status_code = 402

        def json(self):
            return {"return": False, "message": "Insufficient balance"}

    monkeypatch.setattr(gateway.requests, "post",
                        lambda *a, **k: _Resp())

    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=FAST2SMS)

    assert summary["sent"] == 0
    assert summary["attempted"] == 2
    assert all(r["status"] == "failed" for r in summary["results"])
    assert all("Insufficient balance" in r["detail"] for r in summary["results"])
    assert all(r["http_status"] == 402 for r in summary["results"])


def test_fast2sms_network_exception_marks_failed_not_raised(monkeypatch):
    import requests

    def _boom(*a, **k):
        raise requests.ConnectionError("simulated outage")

    monkeypatch.setattr(gateway.requests, "post", _boom)

    # Must never raise.
    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=FAST2SMS)
    assert summary["sent"] == 0
    assert all(r["status"] == "failed" for r in summary["results"])
    assert "ConnectionError" in summary["results"][0]["detail"]


def test_fast2sms_missing_key_skips_without_http(monkeypatch):
    settings = SmsSettings(provider="fast2sms", fast2sms_api_key="")

    def _no_post(*a, **k):
        raise AssertionError("must not call HTTP without an API key")

    monkeypatch.setattr(gateway.requests, "post", _no_post)

    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=settings)
    assert all(r["status"] == "skipped" for r in summary["results"])
    assert all("FAST2SMS_API_KEY" in r["detail"] for r in summary["results"])
    assert summary["sent"] == 0


# --------------------------------------------------------------------------
# Provider: twilio
# --------------------------------------------------------------------------

TWILIO = SmsSettings(
    provider="twilio",
    twilio_account_sid="ACfake-sid-not-a-real-secret",
    twilio_auth_token="fake-token-not-a-real-secret",
    twilio_from_number="+14155550100",
    control_room_numbers=("+919876500000",),
)


def test_twilio_request_shape_and_success(monkeypatch):
    calls = []

    class _Resp:
        status_code = 201

        def json(self):
            return {"sid": "SM-twilio-msg-1", "status": "queued"}

    def _fake_post(url, data=None, auth=None, timeout=None):
        calls.append({"url": url, "data": dict(data or {}), "auth": auth,
                      "timeout": timeout})
        return _Resp()

    monkeypatch.setattr(gateway.requests, "post", _fake_post)

    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=TWILIO)

    assert len(calls) == 2  # one call per recipient
    url = calls[0]["url"]
    assert url == ("https://api.twilio.com/2010-04-01/Accounts/"
                   "ACfake-sid-not-a-real-secret/Messages.json")
    # Basic auth carries SID + token — credentials never go in the body or
    # the stored results.
    assert calls[0]["auth"] == ("ACfake-sid-not-a-real-secret",
                                "fake-token-not-a-real-secret")
    assert calls[0]["data"]["From"] == "+14155550100"
    targets = {c["data"]["To"] for c in calls}
    assert targets == {"+919822011223", "+919876500000"}
    assert all("WariSphere SOS ALERT" in c["data"]["Body"] for c in calls)

    assert summary["provider"] == "twilio"
    assert summary["attempted"] == 2
    assert summary["sent"] == 2
    assert all(r["status"] == "sent" for r in summary["results"])
    assert all(r["message_id"] == "SM-twilio-msg-1" for r in summary["results"])
    assert "fake-token" not in str(summary)


def test_twilio_failure_marks_failed(monkeypatch):
    class _Resp:
        status_code = 400

        def json(self):
            return {"message": "The 'From' number +1999 is not a valid SMS-capable number"}

    monkeypatch.setattr(gateway.requests, "post", lambda *a, **k: _Resp())

    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=TWILIO)
    assert summary["sent"] == 0
    assert all(r["status"] == "failed" for r in summary["results"])
    assert all(r["http_status"] == 400 for r in summary["results"])
    assert "not a valid SMS-capable" in summary["results"][0]["detail"]


def test_twilio_missing_config_skips_without_http(monkeypatch):
    settings = SmsSettings(provider="twilio")  # no SID/token/number

    def _no_post(*a, **k):
        raise AssertionError("must not call HTTP without Twilio config")

    monkeypatch.setattr(gateway.requests, "post", _no_post)

    summary = gateway.dispatch_sos_sms(dict(SOS_RECORD), settings=settings)
    assert all(r["status"] == "skipped" for r in summary["results"])
    detail = summary["results"][0]["detail"]
    assert "TWILIO_ACCOUNT_SID" in detail
    assert "TWILIO_AUTH_TOKEN" in detail
    assert "TWILIO_FROM_NUMBER" in detail


# --------------------------------------------------------------------------
# No recipients
# --------------------------------------------------------------------------

def test_no_recipients_makes_no_request_any_provider(monkeypatch):
    record = dict(SOS_RECORD)
    record["emergency_contact_phone"] = None

    for settings in (
        SmsSettings(provider="none"),
        SmsSettings(provider="fast2sms", fast2sms_api_key="fake-key"),
        SmsSettings(provider="twilio", twilio_account_sid="sid",
                    twilio_auth_token="token", twilio_from_number="+14155550100"),
    ):
        def _no_post(*a, **k):
            raise AssertionError("no recipients => no HTTP request")

        monkeypatch.setattr(gateway.requests, "post", _no_post)

        summary = gateway.dispatch_sos_sms(record, settings=settings)
        assert summary["recipient_count"] == 0
        assert summary["attempted"] == 0
        assert summary["sent"] == 0
        assert summary["results"][0]["status"] == "skipped"
        assert "No recipients" in summary["results"][0]["detail"]
