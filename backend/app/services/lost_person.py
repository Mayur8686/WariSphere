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


def _public_record(record: dict, include_embeddings: bool = False) -> dict:
    """Strip server-side face embeddings before they leave the API."""
    out = dict(record)
    if not include_embeddings:
        out.pop("face_embedding", None)
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

        # AI face fields — embedding itself is filled asynchronously and
        # is stripped from public API responses.
        "face_processed": False,
        "face_processing_error": None,
        "face_embedding_version": None,
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

                return _public_record(record)

        # Create the document.
        firebase.db.collection("lost_persons") \
            .document(lost_person_id) \
            .set(person_record)

        _schedule_face_processing(lost_person_id, person_data.photo_url)

        record = _serialized(
            person_record
        )

        record["stored_in"] = "firestore"

        return _public_record(record)

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

                    return _public_record(out)

        # Store newest records at the beginning.
        records.insert(
            0,
            _serialized(person_record),
        )

        _save_local(records)

    _schedule_face_processing(lost_person_id, person_data.photo_url)

    record = _serialized(
        person_record
    )

    record["stored_in"] = "local-dev"

    return _public_record(record)


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------

def list_lost_persons(
    limit: int = 50,
    status: str | None = None,
    report_type: str | None = None,
    include_embeddings: bool = False,
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
        sliced = records[:limit]
        return [
            _public_record(record, include_embeddings=include_embeddings)
            for record in sliced
        ]

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

    return [
        _public_record(record, include_embeddings=include_embeddings)
        for record in records
    ]


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

        return _public_record(record)

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

                return _public_record(out)

    return None


# ---------------------------------------------------------------------------
# Get / patch (used by face matching — embeddings stay server-side)
# ---------------------------------------------------------------------------

def get_lost_person(
    lost_person_id: str,
    include_embeddings: bool = False,
) -> dict | None:
    """Fetch a single report by id. Embeddings are omitted by default."""

    if firebase.firebase_ready and firebase.db is not None:
        doc = (
            firebase.db.collection("lost_persons")
            .document(lost_person_id)
            .get()
        )
        if not doc.exists:
            return None
        record = _serialized(doc.to_dict() or {})
        record["stored_in"] = "firestore"
        record.setdefault("lost_person_id", lost_person_id)
        return _public_record(record, include_embeddings=include_embeddings)

    with _LOCK:
        for record in _load_local():
            if record.get("lost_person_id") == lost_person_id:
                out = dict(record)
                out.setdefault("stored_in", "local-dev")
                return _public_record(out, include_embeddings=include_embeddings)
    return None


def update_fields(lost_person_id: str, fields: dict) -> dict | None:
    """Merge `fields` onto an existing report. Returns the public record."""

    if not fields:
        return get_lost_person(lost_person_id)

    now = datetime.now(timezone.utc)
    payload = dict(fields)
    payload.setdefault("updated_at", now)

    firestore_payload = {}
    for key, value in payload.items():
        firestore_payload[key] = value

    if firebase.firebase_ready and firebase.db is not None:
        doc_ref = firebase.db.collection("lost_persons").document(lost_person_id)
        doc = doc_ref.get()
        if not doc.exists:
            return None
        doc_ref.update(firestore_payload)
        merged = doc.to_dict() or {}
        merged.update(firestore_payload)
        merged.setdefault("lost_person_id", lost_person_id)
        record = _serialized(merged)
        record["stored_in"] = "firestore"
        return _public_record(record)

    with _LOCK:
        records = _load_local()
        for record in records:
            if record.get("lost_person_id") == lost_person_id:
                for key, value in payload.items():
                    if isinstance(value, datetime):
                        record[key] = value.isoformat()
                    else:
                        record[key] = value
                _save_local(records)
                out = dict(record)
                out["stored_in"] = "local-dev"
                return _public_record(out)
    return None


def set_face_embedding(
    lost_person_id: str,
    embedding: list[float] | None,
    *,
    version: str | None = None,
    error: str | None = None,
) -> dict | None:
    """Attach (or clear) a face embedding. Never returned by public APIs."""
    from app import config as app_config

    fields = {
        "face_processed": bool(embedding) and not error,
        "face_processing_error": error,
        "face_embedding_version": version or app_config.FACE_EMBEDDING_VERSION,
    }
    if embedding is not None:
        fields["face_embedding"] = [float(x) for x in embedding]
    return update_fields(lost_person_id, fields)


def load_photo_bytes(photo_url: str | None) -> bytes | None:
    if not photo_url:
        return None
    raw = str(photo_url).strip().replace("\\", "/")
    if "uploads/" in raw:
        from app.services.photo_storage import uploads_root
        rel = raw.split("uploads/", 1)[-1].split("?", 1)[0].lstrip("/")
        path = os.path.join(uploads_root(), *rel.split("/"))
        try:
            with open(path, "rb") as fh:
                return fh.read()
        except OSError as exc:
            print(f"[lost_person] local photo missing {path}: {exc}")
    if raw.startswith("http://") or raw.startswith("https://"):
        host = raw.split("://", 1)[-1].split("/", 1)[0].split(":")[0].lower()
        if host in {"localhost", "127.0.0.1", "::1"}:
            print(f"[lost_person] refusing self-fetch: {raw}")
            return None
        try:
            import requests
            r = requests.get(raw, timeout=15)
            r.raise_for_status()
            return r.content
        except Exception as exc:
            print(f"[lost_person] failed to fetch photo {raw}: {exc}")
            return None
    return None



def process_record_face(
    lost_person_id: str,
    photo_url: str | None = None,
    image_bytes: bytes | None = None,
    *,
    init_model: bool = False,
) -> dict | None:
    """Generate and store a face embedding for an existing report.

    Failures are recorded on the document; they never raise to the caller
    so lost-person create/list keep working if the AI model is down.
    """
    from app import config as app_config

    try:
        from app.services import face_match as fm
    except Exception as exc:
        return set_face_embedding(
            lost_person_id,
            None,
            error=f"Face matching library unavailable: {exc}",
        )

    if not init_model and not fm.is_model_ready():
        return set_face_embedding(
            lost_person_id,
            None,
            error="pending",
        )

    data = image_bytes
    if data is None:
        record = get_lost_person(lost_person_id)
        url = photo_url or (record or {}).get("photo_url")
        data = load_photo_bytes(url)

    if not data:
        return set_face_embedding(
            lost_person_id,
            None,
            error="No usable photo to process.",
        )

    try:
        embedding = fm.extract_embedding(data)
        return set_face_embedding(
            lost_person_id,
            fm.embedding_to_list(embedding),
            version=fm.active_embedding_version(),
        )
    except fm.FaceMatchError as exc:
        return set_face_embedding(lost_person_id, None, error=exc.message)
    except Exception as exc:  # pragma: no cover
        return set_face_embedding(
            lost_person_id,
            None,
            error=f"Face embedding failure: {exc}",
        )


def _schedule_face_processing(lost_person_id: str, photo_url: str | None) -> None:
    """Fire-and-forget embedding so mobile create stays fast."""
    from app import config as app_config

    if not photo_url or not app_config.AUTO_FACE_PROCESS:
        return

    def _run():
        try:
            process_record_face(
                lost_person_id,
                photo_url=photo_url,
                init_model=False,
            )
        except Exception as exc:  # pragma: no cover
            print(f"[lost_person] background face process failed: {exc}")

    threading.Thread(
        target=_run,
        daemon=True,
        name=f"face-embed-{lost_person_id[:8]}",
    ).start()