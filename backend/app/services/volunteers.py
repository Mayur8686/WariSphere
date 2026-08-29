"""Volunteer profiles — created and managed by the authority only.

Each volunteer has a Firebase Auth account (login credential) plus:

* ``users/{uid}``       — role/status lookup used by auth on every request
* ``volunteers/{uid}``  — the operational profile below

    {
        "id": "<uid>", "uid": "<uid>",
        "name": "Rahul Patil", "email": "...", "phone": "...",
        "emergency_contact": "...",
        "role": "volunteer",
        "status": "active",            # active | inactive | suspended
        "availability": "available",   # available | busy | offline
        "zone": "Sector A - Alandi",
        "skills": ["first_aid", "crowd_management"],
        "current_task_id": null,
        "tasks_completed": 0,
        "tasks_active": 0,
        "created_by": "<authority uid>",
        "created_by_name": "...",
        "created_at": "...", "updated_at": "...",
        "last_active_at": "..."
    }

Firestore + local-JSON fallback, same pattern as every other service.
"""

from datetime import datetime, timezone

from fastapi import HTTPException

from app import firebase
from app.schemas.volunteer import (
    ACCOUNT_STATUSES,
    AVAILABILITY_STATES,
    VolunteerCreate,
)
from app.services import local_store, users

COLLECTION = "volunteers"

_DATETIME_FIELDS = ("created_at", "updated_at", "last_active_at")

# Fields any caller of update_volunteer_fields() may set. Sensitive axes
# (role, ownership, counters, availability, status) have dedicated
# functions/endpoints so they can never be smuggled through a generic patch.
EDITABLE_FIELDS = {"name", "phone", "emergency_contact", "zone", "skills"}


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
# Create (authority only — the route enforces the role)
# ---------------------------------------------------------------------------


def create_volunteer(
    data: VolunteerCreate,
    *,
    created_by: str,
    created_by_name: str | None = None,
) -> dict:
    """Create the Auth account + users role doc + volunteer profile."""
    email = data.email.strip().lower()

    # 1. Login credential (Firebase Auth in prod, local pseudo-uid in dev).
    uid = users.create_auth_account(email, data.password, data.name.strip())

    # 2. Role document.
    users.create_user_record(
        uid,
        name=data.name.strip(),
        email=email,
        role="volunteer",
        phone=(data.phone or None),
        status="active",
        created_by=created_by,
        dev_password=None if firebase.firebase_ready else data.password,
    )

    # 3. Volunteer profile.
    now = _now()
    record = {
        "id": uid,
        "uid": uid,
        "name": data.name.strip(),
        "email": email,
        "phone": data.phone,
        "emergency_contact": data.emergency_contact,
        "role": "volunteer",
        "status": "active",
        "availability": data.availability,
        "zone": data.zone,
        "skills": data.skills or [],
        "current_task_id": None,
        "tasks_completed": 0,
        "tasks_active": 0,
        "created_by": created_by,
        "created_by_name": created_by_name,
        "created_at": now,
        "updated_at": now,
        "last_active_at": None,
    }

    if firebase.firebase_ready and firebase.db is not None:
        firebase.db.collection(COLLECTION).document(uid).set(record)
        out = _serialized(record)
        out["stored_in"] = "firestore"
        return out

    out = _serialized(record)
    out["stored_in"] = "local-dev"
    local_store.put(COLLECTION, "uid", out)
    return out


# ---------------------------------------------------------------------------
# Read
# ---------------------------------------------------------------------------


def get_volunteer(uid: str) -> dict | None:
    if firebase.firebase_ready and firebase.db is not None:
        doc = firebase.db.collection(COLLECTION).document(uid).get()
        if not doc.exists:
            return None
        record = _serialized(doc.to_dict() or {})
        record.setdefault("uid", uid)
        record.setdefault("id", uid)
        record["stored_in"] = "firestore"
        return record
    record = local_store.get(COLLECTION, "uid", uid)
    if record is not None:
        record = dict(record)
        record.setdefault("id", uid)
        record.setdefault("stored_in", "local-dev")
    return record


def list_volunteers(
    *,
    status: str | None = None,
    availability: str | None = None,
) -> list[dict]:
    """All volunteer profiles, newest first. Equality filters only."""
    records: list[dict] = []

    if firebase.firebase_ready and firebase.db is not None:
        query = firebase.db.collection(COLLECTION)
        filters = (("status", status), ("availability", availability))
        for field_name, value in filters:
            if not value:
                continue
            try:
                from google.cloud.firestore import FieldFilter

                query = query.where(filter=FieldFilter(field_name, "==", value))
            except Exception:  # pragma: no cover
                query = query.where(field_path=field_name, op_string="==", value=value)
        for doc in query.stream():
            record = _serialized(doc.to_dict() or {})
            record.setdefault("uid", doc.id)
            record.setdefault("id", doc.id)
            record["stored_in"] = "firestore"
            records.append(record)
    else:
        for record in local_store.load(COLLECTION):
            if status and record.get("status") != status:
                continue
            if availability and record.get("availability") != availability:
                continue
            record = dict(record)
            record.setdefault("stored_in", "local-dev")
            records.append(record)

    records.sort(key=lambda r: str(r.get("created_at", "")), reverse=True)
    return records


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------


def update_volunteer_fields(uid: str, fields: dict) -> dict | None:
    """Internal + self-service patch. Callers must pre-filter keys."""
    if not fields:
        return get_volunteer(uid)
    payload = dict(fields)
    payload["updated_at"] = _now()

    if firebase.firebase_ready and firebase.db is not None:
        ref = firebase.db.collection(COLLECTION).document(uid)
        doc = ref.get()
        if not doc.exists:
            return None
        ref.update(payload)
        merged = doc.to_dict() or {}
        merged.update(payload)
        merged.setdefault("uid", uid)
        merged.setdefault("id", uid)
        record = _serialized(merged)
        record["stored_in"] = "firestore"
        return record

    record = local_store.update_fields(COLLECTION, "uid", uid, payload)
    if record is not None:
        record = dict(record)
        record.setdefault("id", uid)
        record.setdefault("stored_in", "local-dev")
    return record


def set_availability(uid: str, availability: str) -> dict | None:
    if availability not in AVAILABILITY_STATES:
        raise HTTPException(
            status_code=422,
            detail=f"availability must be one of {sorted(AVAILABILITY_STATES)}",
        )
    return update_volunteer_fields(uid, {"availability": availability})


def set_status(uid: str, status: str) -> dict | None:
    if status not in ACCOUNT_STATUSES:
        raise HTTPException(
            status_code=422,
            detail=f"status must be one of {sorted(ACCOUNT_STATUSES)}",
        )
    # Keep the users-role doc in sync so login/session checks agree.
    users.update_user_fields(uid, {"status": status})
    return update_volunteer_fields(uid, {"status": status})
