"""
Lost-person reports: create, list and update.

Data goes to the Firestore `lost_persons` collection when Firebase is
configured. Without a service-account key (dev/CI), the records land in a
small JSON-file store under `backend/data/` so the whole feature is
demoable before the Firebase project exists.

Every response carries a `stored_in` marker saying which store was used.

Dropping the Firebase service-account key in later switches to Firestore
automatically, with no code change.

Firestore queries intentionally use equality filters only. Sorting and
limiting are done in Python so composite Firestore indexes are not required
(combining `.where()` with `.order_by()` otherwise returns a 400 "query
requires an index" until a composite index is manually created).
"""

import json
import os
import threading
from datetime import datetime, timezone
from uuid import uuid4

from app import firebase
from app.schemas.lost_person import LostPersonCreate

# Modern equality-filter API. Using FieldFilter avoids the deprecated
# positional `.where(field, op, value)` form (which prints a UserWarning)
# and keeps the query index-free.
try:
    from google.cloud.firestore import FieldFilter
except Exception:  # pragma: no cover - firestore is always pinned
    FieldFilter = None


# ---------------------------------------------------------------------------
# Local development store
# ---------------------------------------------------------------------------

_LOCK = threading.Lock()

VALID_STATUSES = {"missing", "found", "reunited"}


def _data_dir() -> str:
    """
    Returns the local data directory.

    Default:
        backend/data/

    Can be overridden with:
        WARISPHERE_DATA_DIR
    """

    root = os.environ.get("WARISPHERE_DATA_DIR", "")

    if not root:
        root = os.path.join(
            os.path.dirname(
                os.path.dirname(
                    os.path.dirname(
                        os.path.abspath(__file__)
                    )
                )
            ),
            "data",
        )

    os.makedirs(root, exist_ok=True)

    return root


def _local_path() -> str:
    """Return the path to the local lost-person JSON database."""

    return os.path.join(
        _data_dir(),
        "lost_persons.json",
    )


def _load_local() -> list[dict]:
    """Load lost-person records from the local JSON store."""

    try:
        with open(
            _local_path(),
            "r",
            encoding="utf-8",
        ) as fh:
            data = json.load(fh)

            if isinstance(data, list):
                return data

            return []

    except (OSError, json.JSONDecodeError):
        return []


def _save_local(records: list[dict]) -> None:
    """Save lost-person records to the local JSON store."""

    with open(
        _local_path(),
        "w",
        encoding="utf-8",
    ) as fh:
        json.dump(
            records,
            fh,
            ensure_ascii=False,
            indent=2,
        )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _apply_equality_filter(query, field: str, value):
    """
    Add an equality filter to a Firestore query.

    Uses the modern FieldFilter API when available and falls back to the
    keyword form otherwise. Equality filters only rely on Firestore's
    automatic single-field indexes, so no composite index is required.
    """

    if FieldFilter is not None:
        return query.where(filter=FieldFilter(field, "==", value))

    return query.where(field_path=field, op_string="==", value=value)


def _serialized(record: dict) -> dict:
    """
    Convert Firestore datetime values into ISO-8601 strings.

    The mobile client receives the same format regardless of whether the
    record came from Firestore or the local JSON store.
    """

    out = dict(record)

    created = out.get("created_at")

    if isinstance(created, datetime):
        out["created_at"] = (
            created
            .astimezone(timezone.utc)
            .isoformat()
        )

    seen = out.get("last_seen_time")

    if isinstance(seen, datetime):
        out["last_seen_time"] = (
            seen
            .astimezone(timezone.utc)
            .isoformat()
        )

    updated = out.get("updated_at")

    if isinstance(updated, datetime):
        out["updated_at"] = (
            updated
            .astimezone(timezone.utc)
            .isoformat()
        )

    return out


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------

def create_lost_person(
    person_data: LostPersonCreate,
) -> dict:
    """
    Create a new lost/found-person report.

    Firestore is used when Firebase is configured.

    Otherwise the record is stored in:
        backend/data/lost_persons.json

    `client_report_id` is used for basic duplicate protection.
    """

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

        "last_seen_time": (
            person_data.last_seen_time
            or now
        ),

        "last_seen_latitude": (
            person_data.last_seen_latitude
        ),

        "last_seen_longitude": (
            person_data.last_seen_longitude
        ),

        "photo_url": person_data.photo_url,

        "reporter_id": person_data.reporter_id,

        "reporter_name": person_data.reporter_name,

        "reporter_phone": (
            person_data.reporter_phone
            or person_data.contact_number
        ),

        "status": (
            "missing"
            if person_data.report_type == "lost"
            else "found"
        ),

        "created_at": now,
    }

    # -----------------------------------------------------------------------
    # Firestore
    # -----------------------------------------------------------------------

    if firebase.firebase_ready and firebase.db is not None:

        # Prevent duplicate records when the mobile client retries the
        # same request.
        #
        # This query only uses equality filtering and therefore does not
        # require a composite index.
        if person_data.client_report_id:

            existing = (
                _apply_equality_filter(
                    firebase.db.collection("lost_persons"),
                    "client_report_id",
                    person_data.client_report_id,
                )
                .limit(1)
                .stream()
            )

            for doc in existing:

                record = _serialized(
                    doc.to_dict()
                )

                record["stored_in"] = "firestore"
                record["duplicate"] = True

                return record

        # Create the document.
        firebase.db.collection("lost_persons") \
            .document(lost_person_id) \
            .set(person_record)

        record = _serialized(
            person_record
        )

        record["stored_in"] = "firestore"

        return record

    # -----------------------------------------------------------------------
    # Local JSON development store
    # -----------------------------------------------------------------------

    with _LOCK:

        records = _load_local()

        # Duplicate protection for local development.
        if person_data.client_report_id:

            for existing in records:

                if (
                    existing.get("client_report_id")
                    == person_data.client_report_id
                ):

                    out = dict(existing)

                    out["stored_in"] = "local-dev"
                    out["duplicate"] = True

                    return out

        # Store newest records at the beginning.
        records.insert(
            0,
            _serialized(person_record),
        )

        _save_local(records)

    record = _serialized(
        person_record
    )

    record["stored_in"] = "local-dev"

    return record


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------

def list_lost_persons(
    limit: int = 50,
    status: str | None = None,
    report_type: str | None = None,
) -> list[dict]:
    """
    List lost-person reports.

    Firestore:
        - Equality filters only.
        - No order_by().
        - Sorting is performed in Python.
        - Avoids composite-index requirements.

    Local JSON:
        - Filtering and sorting are also performed in Python.
    """

    # Make sure limit is sensible.
    if limit <= 0:
        limit = 50

    # Prevent unnecessarily large responses.
    limit = min(limit, 200)

    # -----------------------------------------------------------------------
    # Firestore
    # -----------------------------------------------------------------------

    if firebase.firebase_ready and firebase.db is not None:

        query = firebase.db.collection(
            "lost_persons"
        )

        # IMPORTANT:
        #
        # Only equality filters are used here.
        #
        # DO NOT add:
        #
        #     .order_by("created_at")
        #
        # because combining filters and order_by can require a composite
        # Firestore index.
        #
        # Sorting happens below in Python instead.

        if status:

            query = _apply_equality_filter(
                query,
                "status",
                status,
            )

        if report_type:

            query = _apply_equality_filter(
                query,
                "report_type",
                report_type,
            )

        records = []

        for doc in query.stream():

            record = _serialized(
                doc.to_dict()
            )

            record["stored_in"] = "firestore"

            records.append(record)

        # Newest first.
        records.sort(
            key=lambda r: str(
                r.get("created_at", "")
            ),
            reverse=True,
        )

        # Apply limit AFTER sorting.
        return records[:limit]

    # -----------------------------------------------------------------------
    # Local JSON development store
    # -----------------------------------------------------------------------

    with _LOCK:
        records = _load_local()

    # Filter by status.
    if status:

        records = [
            record
            for record in records
            if record.get("status") == status
        ]

    # Filter by report type.
    if report_type:

        records = [
            record
            for record in records
            if record.get("report_type") == report_type
        ]

    # Newest first.
    records.sort(
        key=lambda r: str(
            r.get("created_at", "")
        ),
        reverse=True,
    )

    # Apply limit.
    records = records[:limit]

    # Mark storage location.
    for record in records:
        record.setdefault(
            "stored_in",
            "local-dev",
        )

    return records


# ---------------------------------------------------------------------------
# Update status
# ---------------------------------------------------------------------------

def update_status(
    lost_person_id: str,
    status: str,
) -> dict | None:
    """
    Update the status of a lost-person report.

    Valid statuses:
        missing
        found
        reunited

    Returns:
        Updated record

    Returns None:
        If the record does not exist.
    """

    # -----------------------------------------------------------------------
    # Validate status
    # -----------------------------------------------------------------------

    if status not in VALID_STATUSES:
        raise ValueError(
            f"Invalid status '{status}'. "
            f"Valid statuses are: "
            f"{', '.join(sorted(VALID_STATUSES))}"
        )

    now = datetime.now(timezone.utc)

    # -----------------------------------------------------------------------
    # Firestore
    # -----------------------------------------------------------------------

    if firebase.firebase_ready and firebase.db is not None:

        doc_ref = (
            firebase.db.collection("lost_persons")
            .document(lost_person_id)
        )

        doc = doc_ref.get()

        if not doc.exists:
            return None

        # Update Firestore.
        doc_ref.update(
            {
                "status": status,
                "updated_at": now,
            }
        )

        # Get the original record.
        record = _serialized(
            doc.to_dict()
        )

        # Reflect the newly updated values in the response.
        record["status"] = status
        record["updated_at"] = now.isoformat()
        record["stored_in"] = "firestore"

        return record

    # -----------------------------------------------------------------------
    # Local JSON development store
    # -----------------------------------------------------------------------

    with _LOCK:

        records = _load_local()

        for record in records:

            if (
                record.get("lost_person_id")
                == lost_person_id
            ):

                record["status"] = status

                record["updated_at"] = (
                    now.isoformat()
                )

                _save_local(records)

                out = dict(record)

                out["stored_in"] = "local-dev"

                return out

    return None