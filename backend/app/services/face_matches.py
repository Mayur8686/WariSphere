"""Persistence for AI face-match proposals (`face_matches`).

Mirrors the lost-person store: Firestore when configured, otherwise a
JSON file under `backend/data/face_matches.json` so the feature is
demoable without Firebase.
"""

from __future__ import annotations

import json
import os
import threading
from datetime import datetime, timezone
from uuid import uuid4

from app import firebase

try:
    from google.cloud.firestore import FieldFilter
except Exception:  # pragma: no cover
    FieldFilter = None


_LOCK = threading.Lock()

VALID_MATCH_STATUSES = {"pending", "confirmed", "rejected"}


def _data_dir() -> str:
    root = os.environ.get("WARISPHERE_DATA_DIR", "")
    if not root:
        root = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            "data",
        )
    os.makedirs(root, exist_ok=True)
    return root


def _local_path() -> str:
    return os.path.join(_data_dir(), "face_matches.json")


def _load_local() -> list[dict]:
    try:
        with open(_local_path(), "r", encoding="utf-8") as fh:
            data = json.load(fh)
            return data if isinstance(data, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def _save_local(records: list[dict]) -> None:
    with open(_local_path(), "w", encoding="utf-8") as fh:
        json.dump(records, fh, ensure_ascii=False, indent=2)


def _apply_equality_filter(query, field: str, value):
    if FieldFilter is not None:
        return query.where(filter=FieldFilter(field, "==", value))
    return query.where(field_path=field, op_string="==", value=value)


def _serialized(record: dict) -> dict:
    out = dict(record)
    for key in ("created_at", "verified_at", "updated_at"):
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.astimezone(timezone.utc).isoformat()
    return out


def create_face_match(
    *,
    found_person_id: str,
    missing_person_id: str,
    similarity: float,
    extra: dict | None = None,
) -> dict:
    """Store a pending probable match. Never auto-confirms identity."""
    match_id = str(uuid4())
    now = datetime.now(timezone.utc)
    score = int(round(max(0.0, min(1.0, float(similarity))) * 100))
    record = {
        "id": match_id,
        "found_person_id": found_person_id,
        "missing_person_id": missing_person_id,
        "similarity": round(float(similarity), 4),
        "match_score": score,
        "status": "pending",
        "created_at": now,
        "verified_by": None,
        "verified_at": None,
    }
    if extra:
        record.update(extra)

    if firebase.firebase_ready and firebase.db is not None:
        firebase.db.collection("face_matches").document(match_id).set(record)
        out = _serialized(record)
        out["stored_in"] = "firestore"
        return out

    with _LOCK:
        records = _load_local()
        records.insert(0, _serialized(record))
        _save_local(records)

    out = _serialized(record)
    out["stored_in"] = "local-dev"
    return out


def get_face_match(match_id: str) -> dict | None:
    if firebase.firebase_ready and firebase.db is not None:
        doc = firebase.db.collection("face_matches").document(match_id).get()
        if not doc.exists:
            return None
        out = _serialized(doc.to_dict() or {})
        out["stored_in"] = "firestore"
        out.setdefault("id", match_id)
        return out

    with _LOCK:
        for record in _load_local():
            if record.get("id") == match_id:
                out = dict(record)
                out.setdefault("stored_in", "local-dev")
                return out
    return None


def update_face_match(match_id: str, fields: dict) -> dict | None:
    now = datetime.now(timezone.utc)
    payload = dict(fields)
    payload["updated_at"] = now

    if firebase.firebase_ready and firebase.db is not None:
        doc_ref = firebase.db.collection("face_matches").document(match_id)
        doc = doc_ref.get()
        if not doc.exists:
            return None
        doc_ref.update(payload)
        merged = doc.to_dict() or {}
        merged.update(payload)
        merged.setdefault("id", match_id)
        out = _serialized(merged)
        out["stored_in"] = "firestore"
        return out

    with _LOCK:
        records = _load_local()
        for record in records:
            if record.get("id") == match_id:
                for key, value in payload.items():
                    if isinstance(value, datetime):
                        record[key] = value.isoformat()
                    else:
                        record[key] = value
                _save_local(records)
                out = dict(record)
                out["stored_in"] = "local-dev"
                return out
    return None


def list_face_matches(
    *,
    found_person_id: str | None = None,
    missing_person_id: str | None = None,
    status: str | None = None,
    limit: int = 50,
) -> list[dict]:
    limit = max(1, min(int(limit or 50), 200))

    if firebase.firebase_ready and firebase.db is not None:
        query = firebase.db.collection("face_matches")
        if found_person_id:
            query = _apply_equality_filter(query, "found_person_id", found_person_id)
        if missing_person_id:
            query = _apply_equality_filter(query, "missing_person_id", missing_person_id)
        if status:
            query = _apply_equality_filter(query, "status", status)
        records = []
        for doc in query.stream():
            rec = _serialized(doc.to_dict() or {})
            rec.setdefault("id", doc.id)
            rec["stored_in"] = "firestore"
            records.append(rec)
        records.sort(key=lambda r: str(r.get("created_at", "")), reverse=True)
        return records[:limit]

    with _LOCK:
        records = list(_load_local())

    if found_person_id:
        records = [r for r in records if r.get("found_person_id") == found_person_id]
    if missing_person_id:
        records = [r for r in records if r.get("missing_person_id") == missing_person_id]
    if status:
        records = [r for r in records if r.get("status") == status]
    records.sort(key=lambda r: str(r.get("created_at", "")), reverse=True)
    for record in records:
        record.setdefault("stored_in", "local-dev")
    return records[:limit]
