"""Centralised volunteer task engine.

One ``tasks`` collection serves every dispatch scenario (SOS response,
lost-person assistance, medical, crowd, route, general). A task links to
the existing source record via ``source_kind`` + ``source_id`` — the SOS
alert or lost-person report is never copied or recreated.

Lifecycle (enforced — invalid transitions raise HTTP 409):

    assigned → accepted → in_progress → completed
        │          │           │
        │          └───┬───────┴── unable_to_complete ──┐
        └── rejected ──┴────────────────────────────────┴→ (authority re-assigns) → assigned
    authority may cancel anything not completed.

Side effects kept in sync by this module:
* volunteer availability (assign → busy, release → available) and counters
* the linked SOS alert's status/timestamps (active → ... → resolved)

Firestore + local-JSON fallback, same pattern as every other service.
"""

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import HTTPException

from app import firebase
from app.schemas.task import (
    ACTIVE_TASK_STATUSES,
    TASK_TRANSITIONS,
    IncidentSnapshot,
    TaskCreate,
    TaskLocation,
)
from app.services import local_store, volunteers
from app.services import sos as sos_service
from app.services import lost_person as lost_person_service

COLLECTION = "tasks"

_DATETIME_FIELDS = (
    "created_at",
    "updated_at",
    "assigned_at",
    "accepted_at",
    "started_at",
    "completed_at",
    "cancelled_at",
)

RELEASE_STATUSES = {"rejected", "unable_to_complete", "cancelled"}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso_now() -> str:
    return _now().isoformat()


def _serialized(record: dict) -> dict:
    out = dict(record)
    for key in _DATETIME_FIELDS:
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.astimezone(timezone.utc).isoformat()
    return out


def _dt(value) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


# ---------------------------------------------------------------------------
# Persistence primitives
# ---------------------------------------------------------------------------


def _write(record: dict) -> dict:
    if firebase.firebase_ready and firebase.db is not None:
        firebase.db.collection(COLLECTION).document(record["task_id"]).set(record)
        out = _serialized(record)
        out["stored_in"] = "firestore"
        return out
    out = _serialized(record)
    out["stored_in"] = "local-dev"
    local_store.put(COLLECTION, "task_id", out)
    return out


def _update(task_id: str, fields: dict) -> dict | None:
    payload = dict(fields)
    payload["updated_at"] = _now()
    if firebase.firebase_ready and firebase.db is not None:
        ref = firebase.db.collection(COLLECTION).document(task_id)
        doc = ref.get()
        if not doc.exists:
            return None
        ref.update(payload)
        merged = doc.to_dict() or {}
        merged.update(payload)
        merged.setdefault("task_id", task_id)
        record = _serialized(merged)
        record["stored_in"] = "firestore"
        return record
    record = local_store.update_fields(COLLECTION, "task_id", task_id, payload)
    if record is not None:
        record = dict(record)
        record.setdefault("stored_in", "local-dev")
    return record


def get_task(task_id: str) -> dict | None:
    if firebase.firebase_ready and firebase.db is not None:
        doc = firebase.db.collection(COLLECTION).document(task_id).get()
        if not doc.exists:
            return None
        record = _serialized(doc.to_dict() or {})
        record.setdefault("task_id", doc.id)
        record["stored_in"] = "firestore"
        return record
    record = local_store.get(COLLECTION, "task_id", task_id)
    if record is not None:
        record = dict(record)
        record.setdefault("stored_in", "local-dev")
    return record


def _all_tasks() -> list[dict]:
    records: list[dict] = []
    if firebase.firebase_ready and firebase.db is not None:
        for doc in firebase.db.collection(COLLECTION).stream():
            record = _serialized(doc.to_dict() or {})
            record.setdefault("task_id", doc.id)
            record["stored_in"] = "firestore"
            records.append(record)
    else:
        for record in local_store.load(COLLECTION):
            record = dict(record)
            record.setdefault("stored_in", "local-dev")
            records.append(record)
    records.sort(key=lambda r: str(r.get("created_at", "")), reverse=True)
    return records


def list_tasks(
    *,
    view: str = "all",
    status: str | None = None,
    type: str | None = None,  # noqa: A002 - public API name
    assigned_to: str | None = None,
    source_kind: str | None = None,
    source_id: str | None = None,
    limit: int = 200,
) -> list[dict]:
    """Filter in Python (no composite Firestore indexes required)."""
    records = _all_tasks()

    if view == "active":
        records = [r for r in records if r.get("status") in ACTIVE_TASK_STATUSES]
    elif view == "completed":
        records = [r for r in records if r.get("status") == "completed"]

    if status:
        records = [r for r in records if r.get("status") == status]
    if type:
        records = [r for r in records if r.get("type") == type]
    if assigned_to:
        records = [r for r in records if r.get("assigned_to") == assigned_to]
    if source_kind:
        records = [r for r in records if r.get("source_kind") == source_kind]
    if source_id:
        records = [r for r in records if r.get("source_id") == source_id]

    return records[: max(1, min(limit, 500))]


def index_active_tasks_by_volunteer() -> dict[str, dict]:
    """volunteer uid → lightweight summary of their current active task."""
    index: dict[str, dict] = {}
    for task in list_tasks(view="active"):
        uid = task.get("assigned_to")
        if not uid or uid in index:
            continue
        index[uid] = {
            "task_id": task.get("task_id"),
            "title": task.get("title"),
            "type": task.get("type"),
            "priority": task.get("priority"),
            "status": task.get("status"),
        }
    return index


# ---------------------------------------------------------------------------
# Volunteer bookkeeping
# ---------------------------------------------------------------------------


def _recount_volunteer(uid: str) -> None:
    """Recompute counters + current task pointer from the task store."""
    mine = [t for t in _all_tasks() if t.get("assigned_to") == uid]
    active = [t for t in mine if t.get("status") in ACTIVE_TASK_STATUSES]
    completed = [t for t in mine if t.get("status") == "completed"]

    profile = volunteers.get_volunteer(uid)
    if profile is None:
        return

    fields: dict = {
        "tasks_active": len(active),
        "tasks_completed": len(completed),
        "current_task_id": active[0]["task_id"] if active else None,
    }

    availability = profile.get("availability", "available")
    if availability != "offline":
        # Assignment flips a volunteer to busy; once no active task remains
        # they become available again. An explicit 'offline' is untouched.
        fields["availability"] = "busy" if active else "available"

    volunteers.update_volunteer_fields(uid, fields)


def _assert_assignable(uid: str) -> dict:
    profile = volunteers.get_volunteer(uid)
    if profile is None:
        raise HTTPException(status_code=404, detail="Volunteer not found.")
    if profile.get("status") != "active":
        raise HTTPException(
            status_code=409,
            detail=f"Volunteer account is {profile.get('status')} — reactivate before assigning.",
        )
    if profile.get("availability") != "available":
        raise HTTPException(
            status_code=409,
            detail=f"Volunteer is {profile.get('availability')} — only 'available' "
            "volunteers can be assigned a new task.",
        )
    return profile


# ---------------------------------------------------------------------------
# Source synchronisation (existing SOS / lost-person records)
# ---------------------------------------------------------------------------


def _sync_sos(task: dict, event: str) -> None:
    if task.get("source_kind") != "sos" or not task.get("source_id"):
        return
    sos_id = task["source_id"]
    sos = sos_service.get_sos(sos_id)
    if sos is None:
        return

    if event == "assigned":
        sos_service.update_sos_fields(sos_id, {
            "status": "assigned",
            "task_id": task["task_id"],
            "assigned_to": task.get("assigned_to"),
            "assigned_volunteer_name": task.get("assigned_volunteer_name"),
            "assigned_at": _now(),
        })
    elif event in {"accepted", "in_progress"}:
        sos_service.update_sos_fields(sos_id, {"status": event})
    elif event == "completed":
        resolved_at = _now()
        fields: dict = {"status": "resolved", "resolved_at": resolved_at}
        created = _dt(sos.get("created_at"))
        if created:
            fields["response_seconds"] = max(
                0, int((resolved_at - created).total_seconds())
            )
        sos_service.update_sos_fields(sos_id, fields)
    elif event in RELEASE_STATUSES:
        # Hand the alert back to the unassigned queue only if it still
        # points at THIS task (a newer reassignment must not be clobbered).
        if sos.get("task_id") == task["task_id"]:
            sos_service.update_sos_fields(sos_id, {
                "status": "active",
                "task_id": None,
                "assigned_to": None,
                "assigned_volunteer_name": None,
            })


def _build_incident_snapshot(data: TaskCreate) -> dict | None:
    """Snapshot just-enough source details for the volunteer's task card."""
    if data.incident is not None:
        return data.incident.model_dump()

    if data.source_kind == "sos" and data.source_id:
        sos = sos_service.get_sos(data.source_id)
        if sos is None:
            raise HTTPException(status_code=404, detail="SOS alert not found.")
        return IncidentSnapshot(
            person_name=sos.get("user_name"),
            person_phone=sos.get("user_phone"),
            details=sos.get("message"),
        ).model_dump()

    if data.source_kind == "lost_person" and data.source_id:
        person = lost_person_service.get_lost_person(data.source_id)
        if person is None:
            raise HTTPException(status_code=404, detail="Lost-person report not found.")
        details = person.get("description") or ""
        if person.get("age"):
            details = f"Age approx. {person['age']}. " + details
        return IncidentSnapshot(
            person_name=person.get("name"),
            person_phone=person.get("reporter_phone"),
            details=details.strip() or None,
            photo_url=person.get("photo_url"),
        ).model_dump()

    return None


# ---------------------------------------------------------------------------
# Create / assign
# ---------------------------------------------------------------------------


def create_task(data: TaskCreate, *, authority_uid: str, authority_name: str) -> dict:
    profile = _assert_assignable(data.assigned_to)

    # One open task per source incident (re-dispatch happens via /assign).
    if data.source_id:
        existing = list_tasks(
            view="active",
            source_kind=data.source_kind,
            source_id=data.source_id,
        )
        if existing:
            raise HTTPException(
                status_code=409,
                detail="This incident already has an active task "
                f"({existing[0]['task_id']}). Re-assign it instead.",
            )

    now = _now()
    task_id = str(uuid4())
    record = {
        "id": task_id,
        "task_id": task_id,
        "type": data.type,
        "title": data.title.strip(),
        "description": data.description,
        "priority": data.priority,
        "status": "assigned",
        "created_at": now,
        "updated_at": now,
        "created_by": authority_uid,
        "created_by_name": authority_name,
        "assigned_to": data.assigned_to,
        "assigned_volunteer_name": profile.get("name"),
        "assigned_by": authority_uid,
        "assigned_at": now,
        "source_kind": data.source_kind if data.source_id else "manual",
        "source_id": data.source_id,
        "location": (data.location or TaskLocation()).model_dump(),
        "incident": _build_incident_snapshot(data),
        "accepted_at": None,
        "started_at": None,
        "completed_at": None,
        "cancelled_at": None,
        "completion_note": None,
        "resolution_note": None,
        "history": [
            {
                "status": "assigned",
                "at": now.isoformat(),
                "by": authority_uid,
                "by_name": authority_name,
            }
        ],
    }

    written = _write(record)
    volunteers.set_availability(data.assigned_to, "busy")
    _recount_volunteer(data.assigned_to)
    _sync_sos(written, "assigned")
    return written


# ---------------------------------------------------------------------------
# Status transitions
# ---------------------------------------------------------------------------


def _append_history(task: dict, status: str, by_uid: str, by_name: str, note: str | None):
    history = list(task.get("history") or [])
    history.append(
        {"status": status, "at": _iso_now(), "by": by_uid, "by_name": by_name, "note": note}
    )
    return history


def transition_task(
    task_id: str,
    action: str,
    *,
    actor_uid: str,
    actor_name: str,
    is_authority: bool = False,
    note: str | None = None,
) -> dict:
    """Volunteer-facing transitions: accept | start | complete | reject |
    unable_to_complete. Authority may also cancel via cancel_task()."""
    target = {
        "accept": "accepted",
        "start": "in_progress",
        "complete": "completed",
        "reject": "rejected",
        "unable_to_complete": "unable_to_complete",
    }.get(action)
    if target is None:
        raise HTTPException(status_code=422, detail=f"Unknown action '{action}'.")

    task = get_task(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found.")

    # Ownership: only the assigned volunteer can drive their own task.
    if not is_authority and task.get("assigned_to") != actor_uid:
        raise HTTPException(status_code=403, detail="This task is assigned to another volunteer.")

    allowed = TASK_TRANSITIONS.get(task.get("status", ""), set())
    if target not in allowed or target == "assigned":
        raise HTTPException(
            status_code=409,
            detail=f"Cannot move a '{task.get('status')}' task to '{target}'.",
        )

    now = _now()
    fields: dict = {
        "status": target,
        "history": _append_history(task, target, actor_uid, actor_name, note),
    }
    if target == "accepted":
        fields["accepted_at"] = now
    elif target == "in_progress":
        fields["started_at"] = now
    elif target == "completed":
        fields["completed_at"] = now
        fields["completion_note"] = note
        created = _dt(task.get("created_at"))
        if created:
            fields["response_seconds"] = max(0, int((now - created).total_seconds()))
    elif target in {"rejected", "unable_to_complete"}:
        fields["resolution_note"] = note

    updated = _update(task_id, fields)
    _recount_volunteer(task["assigned_to"])
    _sync_sos(updated, target)
    return updated


def cancel_task(task_id: str, *, actor_uid: str, actor_name: str, note: str | None = None) -> dict:
    task = get_task(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found.")
    allowed = TASK_TRANSITIONS.get(task.get("status", ""), set())
    if "cancelled" not in allowed:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot cancel a '{task.get('status')}' task.",
        )

    updated = _update(task_id, {
        "status": "cancelled",
        "cancelled_at": _now(),
        "resolution_note": note,
        "history": _append_history(task, "cancelled", actor_uid, actor_name, note),
    })
    _recount_volunteer(task["assigned_to"])
    _sync_sos(updated, "cancelled")
    return updated


def assign_task(
    task_id: str,
    volunteer_id: str,
    *,
    authority_uid: str,
    authority_name: str,
) -> dict:
    """Assign or re-assign. Rejected / unable / cancelled tasks come back
    to life here (that is the only way out of those states)."""
    task = get_task(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found.")
    if task.get("status") == "completed":
        raise HTTPException(status_code=409, detail="Completed tasks cannot be re-assigned.")

    profile = _assert_assignable(volunteer_id)
    previous = task.get("assigned_to")
    now = _now()

    updated = _update(task_id, {
        "status": "assigned",
        "assigned_to": volunteer_id,
        "assigned_volunteer_name": profile.get("name"),
        "assigned_by": authority_uid,
        "assigned_at": now,
        "accepted_at": None,
        "started_at": None,
        "completed_at": None,
        "cancelled_at": None,
        "completion_note": None,
        "resolution_note": None,
        "response_seconds": None,
        "history": _append_history(
            task, "assigned", authority_uid, authority_name,
            f"assigned to {profile.get('name')}",
        ),
    })

    if previous and previous != volunteer_id:
        _recount_volunteer(previous)
    volunteers.set_availability(volunteer_id, "busy")
    _recount_volunteer(volunteer_id)
    _sync_sos(updated, "assigned")
    return updated
