"""SOS alert intake + lifecycle.

Firestore collection ``sos_alerts`` is the authoritative store when
Firebase is configured. Without a service-account key the alerts land in
``backend/data/sos_alerts.json`` so the full USER → SOS → AUTHORITY →
VOLUNTEER flow stays demoable (identical fallback pattern to
``lost_person.py``).

Status lifecycle (extended by the volunteer task engine):

    active          unassigned alert (_label_ "Unassigned")
      └─ assigned   a volunteer task now references this SOS
           └─ accepted / in_progress
                └─ resolved     volunteer completed the task
    cancelled       withdrawn / resolved manually by the control room
"""

from datetime import datetime, timezone
from uuid import uuid4

from app import firebase
from app.schemas.sos import SOSCreate
from app.services import local_store

COLLECTION = "sos_alerts"

VALID_STATUSES = {
    "active",
    "assigned",
    "accepted",
    "in_progress",
    "resolved",
    "cancelled",
}

_DATETIME_FIELDS = ("created_at", "assigned_at", "accepted_at", "resolved_at", "updated_at")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialized(record: dict) -> dict:
    out = dict(record)
    for key in _DATETIME_FIELDS:
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.astimezone(timezone.utc).isoformat()
    return out


# ---------------------------------------------------------------------------
# Create — Firestore path is byte-for-byte the original behaviour
# ---------------------------------------------------------------------------


def create_sos(sos_data: SOSCreate) -> dict:
    sos_id = str(uuid4())

    sos_record = {
        "sos_id": sos_id,
        "user_id": sos_data.user_id,
        "latitude": sos_data.latitude,
        "longitude": sos_data.longitude,
        "sos_type": sos_data.sos_type,
        "message": sos_data.message,
        "user_name": sos_data.user_name,
        "user_phone": sos_data.user_phone,
        "accuracy_meters": sos_data.accuracy_meters,
        "status": "active",
        "created_at": _now(),
    }

    if firebase.firebase_ready and firebase.db is not None:
        firebase.db.collection(COLLECTION).document(sos_id).set(sos_record)
        record = _serialized(sos_record)
        record["stored_in"] = "firestore"
        return record

    record = _serialized(sos_record)
    record["stored_in"] = "local-dev"
    local_store.put(COLLECTION, "sos_id", record)
    return record


# ---------------------------------------------------------------------------
# Read
# ---------------------------------------------------------------------------


def get_sos(sos_id: str) -> dict | None:
    if firebase.firebase_ready and firebase.db is not None:
        doc = firebase.db.collection(COLLECTION).document(sos_id).get()
        if not doc.exists:
            return None
        record = _serialized(doc.to_dict() or {})
        record.setdefault("sos_id", sos_id)
        record["stored_in"] = "firestore"
        return record
    record = local_store.get(COLLECTION, "sos_id", sos_id)
    if record is not None:
        record.setdefault("stored_in", "local-dev")
    return record


def list_sos(limit: int = 100, status: str | None = None) -> list[dict]:
    """Alerts newest first. Equality filters only (no composite indexes);
    sorting happens in Python — same convention as list_lost_persons()."""
    limit = max(1, min(limit, 500))
    records: list[dict] = []

    if firebase.firebase_ready and firebase.db is not None:
        query = firebase.db.collection(COLLECTION)
        if status:
            try:
                from google.cloud.firestore import FieldFilter

                query = query.where(filter=FieldFilter("status", "==", status))
            except Exception:  # pragma: no cover
                query = query.where(field_path="status", op_string="==", value=status)
        for doc in query.stream():
            record = _serialized(doc.to_dict() or {})
            record.setdefault("sos_id", doc.id)
            record["stored_in"] = "firestore"
            records.append(record)
    else:
        for record in local_store.load(COLLECTION):
            if status and record.get("status") != status:
                continue
            record = dict(record)
            record.setdefault("stored_in", "local-dev")
            records.append(record)

    records.sort(key=lambda r: str(r.get("created_at", "")), reverse=True)
    return records[:limit]


# ---------------------------------------------------------------------------
# Update (task engine keeps the alert lifecycle in sync)
# ---------------------------------------------------------------------------


def update_sos_fields(sos_id: str, fields: dict) -> dict | None:
    if not fields:
        return get_sos(sos_id)
    payload = dict(fields)
    payload["updated_at"] = _now()

    if firebase.firebase_ready and firebase.db is not None:
        ref = firebase.db.collection(COLLECTION).document(sos_id)
        doc = ref.get()
        if not doc.exists:
            return None
        ref.update(payload)
        merged = doc.to_dict() or {}
        merged.update(payload)
        merged.setdefault("sos_id", sos_id)
        record = _serialized(merged)
        record["stored_in"] = "firestore"
        return record

    record = local_store.update_fields(COLLECTION, "sos_id", sos_id, payload)
    if record is not None:
        record = dict(record)
        record["stored_in"] = "local-dev"
    return record


def update_sos_status(sos_id: str, status: str) -> dict | None:
    if status not in VALID_STATUSES:
        raise ValueError(
            f"Invalid SOS status '{status}'. Valid: {', '.join(sorted(VALID_STATUSES))}"
        )
    fields: dict = {"status": status}
    if status == "resolved":
        fields["resolved_at"] = _now()
    return update_sos_fields(sos_id, fields)
