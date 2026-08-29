"""Lost-person reports: create, list and update.

Data goes to the **Firestore `lost_persons` collection** when Firebase is
configured. Without a service-account key (dev/CI) the records land in a
small JSON-file store under `backend/data/` so the whole feature is
demoable before the Firebase project exists — every response carries a
`stored_in` marker saying which one was used. Dropping the key in later
switches to Firestore automatically, no code change.
"""

import json
import os
import threading
from datetime import datetime, timezone
from uuid import uuid4

from app.firebase import db, firebase_ready
from app.schemas.lost_person import LostPersonCreate

# --- local dev store ---------------------------------------------------------

_LOCK = threading.Lock()

VALID_STATUSES = {"missing", "found", "reunited"}


def _data_dir() -> str:
    """`backend/data/` (three levels up from this file: services → app → backend)."""
    root = os.environ.get("WARISPHERE_DATA_DIR", "")
    if not root:
        root = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "data",
        )
    os.makedirs(root, exist_ok=True)
    return root


def _local_path() -> str:
    return os.path.join(_data_dir(), "lost_persons.json")


def _load_local() -> list[dict]:
    try:
        with open(_local_path(), encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return []


def _save_local(records: list[dict]) -> None:
    with open(_local_path(), "w", encoding="utf-8") as fh:
        json.dump(records, fh, ensure_ascii=False, indent=2)


def _serialized(record: dict) -> dict:
    """Firestore returns `datetime`; JSON store returns ISO strings — make the
    outgoing payload uniform (ISO-8601 strings) for the mobile client."""
    out = dict(record)
    created = out.get("created_at")
    if isinstance(created, datetime):
        out["created_at"] = created.astimezone(timezone.utc).isoformat()
    seen = out.get("last_seen_time")
    if isinstance(seen, datetime):
        out["last_seen_time"] = seen.astimezone(timezone.utc).isoformat()
    return out


# --- public API ---------------------------------------------------------------


def create_lost_person(person_data: LostPersonCreate) -> dict:
    lost_person_id = str(uuid4())
    now = datetime.now(timezone.utc)

    person_record = {
        "lost_person_id": lost_person_id,
        "client_report_id": person_data.client_report_id,
        "report_type": person_data.report_type,
        "name": person_data.name,
        "age": person_data.age,
        "gender": person_data.gender,
        "description": person_data.description,
        "last_seen_location": person_data.last_seen_location,
        "last_seen_time": person_data.last_seen_time or now,
        "last_seen_latitude": person_data.last_seen_latitude,
        "last_seen_longitude": person_data.last_seen_longitude,
        "photo_url": person_data.photo_url,
        "reporter_id": person_data.reporter_id,
        "reporter_name": person_data.reporter_name,
        "reporter_phone": person_data.reporter_phone or person_data.contact_number,
        "status": "missing" if person_data.report_type == "lost" else "found",
        "created_at": now,
    }

    if firebase_ready and db is not None:
        # Retries after a flaky connection must not create duplicates.
        if person_data.client_report_id:
            existing = (
                db.collection("lost_persons")
                .where("client_report_id", "==", person_data.client_report_id)
                .limit(1)
                .stream()
            )
            for doc in existing:
                record = _serialized(doc.to_dict())
                record["stored_in"] = "firestore"
                record["duplicate"] = True
                return record

        db.collection("lost_persons").document(lost_person_id).set(person_record)
        record = _serialized(person_record)
        record["stored_in"] = "firestore"
        return record

    # Dev-mode JSON store.
    with _LOCK:
        records = _load_local()
        if person_data.client_report_id:
            for existing in records:
                if existing.get("client_report_id") == person_data.client_report_id:
                    out = dict(existing)
                    out["stored_in"] = "local-dev"
                    out["duplicate"] = True
                    return out
        records.insert(0, _serialized(person_record))
        _save_local(records)

    record = _serialized(person_record)
    record["stored_in"] = "local-dev"
    return record


def list_lost_persons(
    limit: int = 50, status: str | None = None, report_type: str | None = None
) -> list[dict]:
    if firebase_ready and db is not None:
        query = db.collection("lost_persons").order_by(
            "created_at", direction="DESCENDING"
        ).limit(limit)
        if status:
            query = query.where("status", "==", status)
        if report_type:
            query = query.where("report_type", "==", report_type)
        return [_serialized(doc.to_dict()) for doc in query.stream()]

    with _LOCK:
        records = _load_local()

    if status:
        records = [r for r in records if r.get("status") == status]
    if report_type:
        records = [r for r in records if r.get("report_type") == report_type]
    records.sort(key=lambda r: str(r.get("created_at", "")), reverse=True)
    return records[:limit]


def update_status(lost_person_id: str, status: str) -> dict | None:
    """Set a new status; returns the updated record or None when not found."""
    if firebase_ready and db is not None:
        doc_ref = db.collection("lost_persons").document(lost_person_id)
        doc = doc_ref.get()
        if not doc.exists:
            return None
        doc_ref.update({"status": status, "updated_at": datetime.now(timezone.utc)})
        record = _serialized(doc.to_dict())
        record["status"] = status
        record["stored_in"] = "firestore"
        return record

    with _LOCK:
        records = _load_local()
        for record in records:
            if record.get("lost_person_id") == lost_person_id:
                record["status"] = status
                record["updated_at"] = datetime.now(timezone.utc).isoformat()
                _save_local(records)
                out = dict(record)
                out["stored_in"] = "local-dev"
                return out
    return None
