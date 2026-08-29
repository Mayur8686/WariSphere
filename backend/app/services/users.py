"""User/role store — the single source of truth for *who someone is*.

``users/{uid}`` documents:

    {
        "uid": "...",
        "name": "Rahul Patil",
        "email": "rahul@...",
        "phone": "...",
        "role": "authority" | "volunteer",
        "status": "active",
        "created_by": "<authority uid>",
        "created_at": "...",
        "updated_at": "..."
    }

Firestore is used when Firebase is configured; otherwise a local JSON
store (dev mode — see app/services/local_store.py). Local records may
carry a ``dev_password`` field so dev-mode logins can be verified; that
field never leaves the server in Firebase mode (passwords there live in
Firebase Auth, not Firestore).
"""

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import HTTPException

from app import firebase
from app.services import local_store

COLLECTION = "users"

VALID_ROLES = {"authority", "volunteer"}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _serialized(record: dict) -> dict:
    out = dict(record)
    for key in ("created_at", "updated_at", "last_login_at"):
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.astimezone(timezone.utc).isoformat()
    return out


def public_user(record: dict) -> dict:
    """Strip server-only fields before a user dict leaves the API."""
    out = _serialized(record)
    out.pop("dev_password", None)
    return out


# ---------------------------------------------------------------------------
# Firebase Auth account creation (privileged — server side only)
# ---------------------------------------------------------------------------


def create_auth_account(email: str, password: str, display_name: str) -> str:
    """Create the login credential and return its uid.

    Firebase mode → Firebase Authentication user via the Admin SDK (the
    service-account key never leaves the backend). Dev mode → a local
    pseudo uid; the password is stored in the local users store only.
    """
    if firebase.firebase_ready:
        from firebase_admin import auth as admin_auth

        try:
            user = admin_auth.create_user(
                email=email,
                password=password,
                display_name=display_name,
            )
        except admin_auth.EmailAlreadyExistsError:
            raise HTTPException(
                status_code=409,
                detail=f"An account already exists for {email}.",
            )
        except Exception as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Firebase Auth account creation failed: {exc}",
            )
        return user.uid

    # Dev mode: make sure the email is unique inside the local store.
    if get_user_by_email(email) is not None:
        raise HTTPException(
            status_code=409,
            detail=f"An account already exists for {email}.",
        )
    return f"dev-{uuid4().hex[:12]}"


# ---------------------------------------------------------------------------
# users collection CRUD
# ---------------------------------------------------------------------------


def create_user_record(
    uid: str,
    *,
    name: str,
    email: str,
    role: str,
    phone: str | None = None,
    status: str = "active",
    created_by: str | None = None,
    dev_password: str | None = None,
) -> dict:
    if role not in VALID_ROLES:
        raise HTTPException(status_code=422, detail=f"role must be one of {sorted(VALID_ROLES)}")

    record = {
        "uid": uid,
        "name": name,
        "email": email,
        "phone": phone,
        "role": role,
        "status": status,
        "created_by": created_by,
        "created_at": _now(),
        "updated_at": _now(),
    }

    if firebase.firebase_ready and firebase.db is not None:
        firebase.db.collection(COLLECTION).document(uid).set(record)
        return _serialized(record)

    if dev_password is not None:
        record["dev_password"] = dev_password
    local_store.put(COLLECTION, "uid", _serialized(record))
    return _serialized(record)


def get_user(uid: str) -> dict | None:
    if firebase.firebase_ready and firebase.db is not None:
        doc = firebase.db.collection(COLLECTION).document(uid).get()
        if not doc.exists:
            return None
        record = _serialized(doc.to_dict() or {})
        record.setdefault("uid", uid)
        return record
    return local_store.get(COLLECTION, "uid", uid)


def get_user_by_email(email: str) -> dict | None:
    email = (email or "").strip().lower()
    if not email:
        return None
    if firebase.firebase_ready and firebase.db is not None:
        query = firebase.db.collection(COLLECTION)
        try:
            from google.cloud.firestore import FieldFilter

            query = query.where(filter=FieldFilter("email", "==", email))
        except Exception:  # pragma: no cover
            query = query.where(field_path="email", op_string="==", value=email)
        for doc in query.limit(1).stream():
            record = _serialized(doc.to_dict() or {})
            record.setdefault("uid", doc.id)
            return record
        return None
    for record in local_store.load(COLLECTION):
        if str(record.get("email", "")).lower() == email:
            return record
    return None


def update_user_fields(uid: str, fields: dict) -> dict | None:
    if not fields:
        return get_user(uid)
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
        return _serialized(merged)
    return local_store.update_fields(COLLECTION, "uid", uid, payload)


def verify_dev_credentials(email: str, password: str) -> dict | None:
    """Dev-mode login (only reachable when Firebase is NOT configured)."""
    if firebase.firebase_ready:
        return None
    record = get_user_by_email(email)
    if not record:
        return None
    if record.get("status", "active") != "active":
        return None
    if record.get("dev_password") != password:
        return None
    return record
