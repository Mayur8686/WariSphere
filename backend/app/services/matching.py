"""Orchestration for AI-assisted lost-person face matching.

This is a *probable* matching pipeline. A high similarity score is never
treated as identity confirmation — an authority must confirm or reject.
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import HTTPException

from app import config
from app.schemas.lost_person import LostPersonCreate
from app.services import face_matches as match_store
from app.services import lost_person as persons
from app.services.photo_storage import save_photo


def _parse_time(value) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if not value:
        return None
    try:
        text = str(value).replace("Z", "+00:00")
        dt = datetime.fromisoformat(text)
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def missing_for_label(record: dict) -> str:
    """e.g. '8 hours' from last_seen_time / created_at."""
    dt = _parse_time(record.get("last_seen_time")) or _parse_time(record.get("created_at"))
    if dt is None:
        return "unknown"
    seconds = max(0, int((datetime.now(timezone.utc) - dt).total_seconds()))
    if seconds < 60:
        return f"{seconds} seconds"
    minutes = seconds // 60
    if minutes < 60:
        return f"{minutes} min" if minutes == 1 else f"{minutes} mins"
    hours = minutes // 60
    if hours < 24:
        return "1 hour" if hours == 1 else f"{hours} hours"
    days = hours // 24
    return "1 day" if days == 1 else f"{days} days"


def _match_payload(match_rec: dict, person: dict, similarity: float) -> dict:
    """Public match row — never includes embeddings."""
    return {
        "match_id": match_rec.get("id"),
        "person_id": person.get("lost_person_id"),
        "name": person.get("name"),
        "photo_url": person.get("photo_url"),
        "similarity": round(float(similarity), 4),
        "match_score": int(round(max(0.0, min(1.0, float(similarity))) * 100)),
        "confidence": _confidence(similarity),
        "status": person.get("status") or "missing",
        "location": person.get("last_seen_location"),
        "age": person.get("age"),
        "gender": person.get("gender"),
        "description": person.get("description"),
        "missing_for": missing_for_label(person),
        "last_seen_time": person.get("last_seen_time"),
        "report_type": person.get("report_type"),
        "match_status": match_rec.get("status", "pending"),
    }


def _confidence(similarity: float) -> str:
    from app.services.face_match import confidence_label

    return confidence_label(similarity)


def _ensure_embedding(record: dict) -> list[float] | None:
    """Return a usable embedding, generating one from the photo if needed."""
    from app import config as app_config
    from app.services import face_match as fm

    existing = record.get("face_embedding")
    current_version = fm.active_embedding_version()
    version_ok = record.get("face_embedding_version") == current_version

    if existing and record.get("face_processed") and version_ok:
        return list(existing)

    photo_url = record.get("photo_url")
    if not photo_url:
        return list(existing) if existing else None

    data = persons.load_photo_bytes(photo_url)
    if not data:
        return list(existing) if existing else None

    try:
        embedding = fm.extract_embedding(data)
        stored = fm.embedding_to_list(embedding)
        persons.set_face_embedding(
            record["lost_person_id"],
            stored,
            version=app_config.FACE_EMBEDDING_VERSION,
        )
        record["face_embedding"] = stored
        record["face_processed"] = True
        record["face_processing_error"] = None
        return stored
    except fm.FaceMatchError as exc:
        persons.set_face_embedding(
            record.get("lost_person_id"),
            None,
            error=exc.message,
        )
        return list(existing) if existing else None
    except Exception as exc:
        persons.set_face_embedding(
            record.get("lost_person_id"),
            None,
            error=f"Face embedding failure: {exc}",
        )
        return list(existing) if existing else None


def scan_found_image(
    image_bytes: bytes,
    *,
    reporter_name: str = "Control Room",
    client_report_id: str | None = None,
) -> dict:
    """Run the full scan pipeline on a found-person photograph.

    1. Detect the (single) face and build an embedding.
    2. Store the photo + a found-person report.
    3. Compare against active missing persons that have embeddings.
    4. Persist top probable matches as `pending` (never auto-confirmed).
    """
    from app.services import face_match as fm

    try:
        query_vec = fm.extract_embedding(image_bytes)
    except fm.NoFaceDetectedError as exc:
        raise HTTPException(status_code=422, detail=exc.message) from exc
    except fm.MultipleFacesError as exc:
        raise HTTPException(status_code=422, detail=exc.message) from exc
    except fm.InvalidImageError as exc:
        raise HTTPException(status_code=415, detail=exc.message) from exc
    except fm.ModelInitError as exc:
        raise HTTPException(status_code=503, detail=exc.message) from exc
    except fm.FaceMatchError as exc:
        raise HTTPException(status_code=500, detail=exc.message) from exc

    query_list = fm.embedding_to_list(query_vec)

    photo = save_photo(image_bytes, stem=client_report_id or "FOUND-SCAN")
    found = persons.create_lost_person(
        LostPersonCreate(
            client_report_id=client_report_id or f"ADM-SCAN-{uuid4().hex[:10]}",
            report_type="found",
            name="Unidentified person",
            description="Logged by control room (pending AI face match).",
            last_seen_location="Control room upload",
            photo_url=photo.get("photo_url"),
            reporter_name=reporter_name or "Control Room",
        )
    )
    from app.services import face_match as fm

    persons.set_face_embedding(
        found["lost_person_id"],
        query_list,
        version=fm.active_embedding_version(),
    )

    missing = persons.list_lost_persons(
        limit=200,
        status="missing",
        include_embeddings=True,
    )

    gallery = []
    records_scanned = 0
    for record in missing:
        if record.get("lost_person_id") == found.get("lost_person_id"):
            continue
        embedding = _ensure_embedding(record)
        if not embedding:
            continue
        records_scanned += 1
        gallery.append((record, embedding))

    ranked = fm.rank_by_cosine(query_list, gallery)

    matches_out = []
    for similarity, record in ranked:
        stored = match_store.create_face_match(
            found_person_id=found["lost_person_id"],
            missing_person_id=record["lost_person_id"],
            similarity=similarity,
        )
        matches_out.append(_match_payload(stored, record, similarity))

    message = None
    if records_scanned == 0:
        message = "No missing-person face records are available to compare."
    elif not matches_out:
        message = "No probable matches found."

    return {
        "success": True,
        "faces_detected": 1,
        "records_scanned": records_scanned,
        "found_person_id": found.get("lost_person_id"),
        "found_photo_url": photo.get("photo_url"),
        "matches": matches_out,
        "message": message,
        "disclaimer": (
            "These are probable matches only. Similarity is not identity. "
            "An authority must confirm or reject every proposed match."
        ),
    }


def _require_pending(match: dict) -> None:
    status = match.get("status")
    if status == "pending":
        return
    raise HTTPException(
        status_code=409,
        detail=f"This match has already been {status}.",
    )


def confirm_match(match_id: str, verified_by: str | None = None) -> dict:
    """Authority confirms a proposed match.

    Updates the match to `confirmed` and marks both the missing person and
    the found-person report as `reunited`. Does not run just because AI
    produced a score — the caller must be an authority acting deliberately.
    """
    match = match_store.get_face_match(match_id)
    if match is None:
        raise HTTPException(status_code=404, detail="Match not found.")
    _require_pending(match)

    actor = (verified_by or "").strip() or "control-room"
    now = datetime.now(timezone.utc)

    updated = match_store.update_face_match(
        match_id,
        {
            "status": "confirmed",
            "verified_by": actor,
            "verified_at": now,
            "decision": "confirmed",
        },
    )

    missing = persons.update_status(match["missing_person_id"], "reunited")
    found = persons.update_status(match["found_person_id"], "reunited")

    if missing is not None:
        persons.update_fields(
            match["missing_person_id"],
            {
                "matched_found_person_id": match.get("found_person_id"),
                "matched_by": actor,
                "matched_at": now.isoformat(),
            },
        )
        missing = persons.get_lost_person(match["missing_person_id"])

    if found is not None and missing is not None:
        persons.update_fields(
            match["found_person_id"],
            {
                "matched_missing_person_id": match.get("missing_person_id"),
                "description": (
                    f"Authority-confirmed match with {missing.get('name')} "
                    f"({match.get('missing_person_id')})."
                ),
                "matched_by": actor,
                "matched_at": now.isoformat(),
            },
        )
        found = persons.get_lost_person(match["found_person_id"])

    return {
        "success": True,
        "match": updated,
        "missing_person": missing,
        "found_person": found,
        "message": (
            f"Match confirmed. "
            f"{(missing or {}).get('name', 'The missing person')} is now marked reunited."
        ),
    }


def reject_match(match_id: str, verified_by: str | None = None) -> dict:
    """Authority rejects a proposed match. Person statuses are unchanged."""
    match = match_store.get_face_match(match_id)
    if match is None:
        raise HTTPException(status_code=404, detail="Match not found.")
    _require_pending(match)

    actor = (verified_by or "").strip() or "control-room"
    now = datetime.now(timezone.utc)
    updated = match_store.update_face_match(
        match_id,
        {
            "status": "rejected",
            "verified_by": actor,
            "verified_at": now,
            "decision": "rejected",
        },
    )
    return {
        "success": True,
        "match": updated,
        "message": "Match rejected. The missing-person record was not changed.",
    }
