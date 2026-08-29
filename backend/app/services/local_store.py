"""Tiny JSON-file document store for dev mode (no Firebase service-account).

This mirrors the fallback approach of ``app/services/lost_person.py`` so
the whole platform — including the role-based volunteer system — stays
demoable before/without a Firebase project. Each "collection" is a JSON
list under ``backend/data/<name>.json``. Drop in the service-account key
and nothing here is used: Firestore takes over automatically.

Every record is expected to carry its primary key field (``uid``,
``task_id``, ``sos_id``, ...) as a regular field.
"""

import json
import os
import threading
from datetime import datetime, timezone

# Reentrant: put()/update_fields() hold the lock while calling save().
_LOCK = threading.RLock()


def data_dir() -> str:
    """Local data directory (default ``backend/data/``).

    Override with ``WARISPHERE_DATA_DIR`` (the tests do exactly that).
    """
    root = os.environ.get("WARISPHERE_DATA_DIR", "")
    if not root:
        root = os.path.join(
            os.path.dirname(
                os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            ),
            "data",
        )
    os.makedirs(root, exist_ok=True)
    return root


def _path(collection: str) -> str:
    safe = "".join(ch for ch in collection if ch.isalnum() or ch in {"_", "-"})
    return os.path.join(data_dir(), f"{safe}.json")


def load(collection: str) -> list[dict]:
    try:
        with open(_path(collection), "r", encoding="utf-8") as fh:
            data = json.load(fh)
            return data if isinstance(data, list) else []
    except (OSError, json.JSONDecodeError):
        return []


def save(collection: str, records: list[dict]) -> None:
    with _LOCK:
        with open(_path(collection), "w", encoding="utf-8") as fh:
            json.dump(records, fh, ensure_ascii=False, indent=2)


def get(collection: str, key_field: str, key_value) -> dict | None:
    for record in load(collection):
        if record.get(key_field) == key_value:
            return record
    return None


def put(collection: str, key_field: str, record: dict) -> dict:
    """Upsert a record keyed on ``record[key_field]``."""
    with _LOCK:
        records = load(collection)
        replaced = False
        for idx, existing in enumerate(records):
            if existing.get(key_field) == record.get(key_field):
                records[idx] = record
                replaced = True
                break
        if not replaced:
            records.append(record)
        save(collection, records)
    return record


def update_fields(collection: str, key_field: str, key_value, fields: dict) -> dict | None:
    """Merge ``fields`` into the record with matching key. None if missing."""
    with _LOCK:
        records = load(collection)
        for record in records:
            if record.get(key_field) == key_value:
                for key, value in fields.items():
                    record[key] = (
                        value.isoformat() if isinstance(value, datetime) else value
                    )
                save(collection, records)
                return record
    return None


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def iso_now() -> str:
    return utcnow().isoformat()
