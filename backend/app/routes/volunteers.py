"""Volunteer management APIs.

* Authority: create / list / view / manage any volunteer.
* Volunteer: read + safe-edit ONLY their own profile, set their own
  availability. The volunteer role can never create accounts, change a
  role, or touch another volunteer — enforced here, not in the UI.
"""

from fastapi import APIRouter, Depends, HTTPException, Query

from app.schemas.volunteer import (
    AVAILABILITY_STATES,
    AvailabilityUpdate,
    VolunteerCreate,
    VolunteerStatusUpdate,
    VolunteerUpdate,
)
from app.services import tasks as tasks_service
from app.services import volunteers as volunteers_service
from app.services.auth import (
    Principal,
    get_principal,
    require_authority,
    require_volunteer,
    touch_volunteer_presence,
)
from app.services.volunteers import EDITABLE_FIELDS

router = APIRouter(
    prefix="/volunteers",
    tags=["Volunteers"],
)


def _summary(volunteers: list[dict], active_tasks: dict[str, dict]) -> dict:
    return {
        "total": len(volunteers),
        "active": sum(1 for v in volunteers if v.get("status") == "active"),
        "available": sum(1 for v in volunteers if v.get("availability") == "available"),
        "busy": sum(1 for v in volunteers if v.get("availability") == "busy"),
        "offline": sum(1 for v in volunteers if v.get("availability") == "offline"),
        "on_tasks": sum(1 for v in volunteers if v.get("uid") in active_tasks),
    }


def _enrich(record: dict, active_tasks: dict[str, dict]) -> dict:
    out = dict(record)
    out["current_task"] = active_tasks.get(record.get("uid"))
    return out


# ---------------------------------------------------------------------------
# Create (authority only)
# ---------------------------------------------------------------------------


@router.post("", status_code=201)
def create_volunteer(
    body: VolunteerCreate,
    authority: Principal = Depends(require_authority),
):
    try:
        return volunteers_service.create_volunteer(
            body,
            created_by=authority.uid,
            created_by_name=authority.name,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to create volunteer: {exc}")


# ---------------------------------------------------------------------------
# List (authority only) — includes the headline stats + current task per
# volunteer so the dashboard needs a single round trip.
# ---------------------------------------------------------------------------


@router.get("")
def list_volunteers(
    status: str | None = Query(default=None),
    availability: str | None = Query(default=None),
    _: Principal = Depends(require_authority),
):
    records = volunteers_service.list_volunteers(status=status, availability=availability)
    active_tasks = tasks_service.index_active_tasks_by_volunteer()
    return {
        "count": len(records),
        "summary": _summary(records, active_tasks),
        "volunteers": [_enrich(r, active_tasks) for r in records],
    }


# ---------------------------------------------------------------------------
# Own profile (volunteer) — must be declared before /{volunteer_id}
# ---------------------------------------------------------------------------


@router.get("/me")
def my_profile(principal: Principal = Depends(require_volunteer)):
    touch_volunteer_presence(principal.uid)
    profile = volunteers_service.get_volunteer(principal.uid)
    if profile is None:
        raise HTTPException(status_code=404, detail="Volunteer profile not found.")
    active_tasks = tasks_service.index_active_tasks_by_volunteer()
    return _enrich(profile, active_tasks)


@router.patch("/me/availability")
def set_my_availability(
    body: AvailabilityUpdate,
    principal: Principal = Depends(require_volunteer),
):
    return _set_availability_guarded(principal.uid, body.availability)


# ---------------------------------------------------------------------------
# Single volunteer (authority OR the volunteer themselves)
# ---------------------------------------------------------------------------


def _load_self_or_authority(volunteer_id: str, principal: Principal) -> dict:
    if principal.role == "volunteer" and principal.uid != volunteer_id:
        raise HTTPException(status_code=403, detail="Volunteers can only access their own profile.")
    if principal.role not in {"authority", "volunteer"}:
        raise HTTPException(status_code=403, detail="Insufficient role.")
    profile = volunteers_service.get_volunteer(volunteer_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Volunteer not found.")
    return profile


@router.get("/{volunteer_id}")
def get_volunteer(
    volunteer_id: str,
    principal: Principal = Depends(get_principal),
):
    profile = _load_self_or_authority(volunteer_id, principal)
    active_tasks = tasks_service.index_active_tasks_by_volunteer()
    return _enrich(profile, active_tasks)


@router.patch("/{volunteer_id}")
def update_volunteer(
    volunteer_id: str,
    body: VolunteerUpdate,
    principal: Principal = Depends(get_principal),
):
    _load_self_or_authority(volunteer_id, principal)

    changes = {k: v for k, v in body.model_dump(exclude_unset=True).items() if k in EDITABLE_FIELDS}
    if not changes:
        raise HTTPException(status_code=422, detail="No editable fields provided.")

    # Volunteers may only touch contact/zone fields on their own profile;
    # name/skills stay authority-managed.
    if principal.role == "volunteer":
        allowed = {"phone", "emergency_contact", "zone"}
        changes = {k: v for k, v in changes.items() if k in allowed}
        if not changes:
            raise HTTPException(
                status_code=403,
                detail="Volunteers may only update phone, emergency contact and zone.",
            )

    updated = volunteers_service.update_volunteer_fields(volunteer_id, changes)
    return updated


@router.patch("/{volunteer_id}/status")
def update_volunteer_status(
    volunteer_id: str,
    body: VolunteerStatusUpdate,
    _: Principal = Depends(require_authority),
):
    updated = volunteers_service.set_status(volunteer_id, body.status)
    if updated is None:
        raise HTTPException(status_code=404, detail="Volunteer not found.")
    return updated


@router.patch("/{volunteer_id}/availability")
def update_volunteer_availability(
    volunteer_id: str,
    body: AvailabilityUpdate,
    principal: Principal = Depends(get_principal),
):
    _load_self_or_authority(volunteer_id, principal)
    return _set_availability_guarded(volunteer_id, body.availability)


def _set_availability_guarded(volunteer_id: str, availability: str) -> dict:
    """Availability is partly system-owned: a volunteer with live tasks
    cannot claim to be 'available', and an offline→busy jump is nudged to
    'available' instead (busy is set by the engine on assignment)."""
    if availability not in AVAILABILITY_STATES:
        raise HTTPException(status_code=422, detail="Invalid availability value.")
    profile = volunteers_service.get_volunteer(volunteer_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Volunteer not found.")
    if profile.get("status") != "active":
        raise HTTPException(
            status_code=409,
            detail=f"Account is {profile.get('status')} — availability is locked.",
        )
    if availability == "available":
        active = tasks_service.list_tasks(view="active", assigned_to=volunteer_id)
        if active:
            raise HTTPException(
                status_code=409,
                detail="You still have active tasks — complete or hand them back first.",
            )
    updated = volunteers_service.set_availability(volunteer_id, availability)
    if availability in {"available", "offline"}:
        # Heading out / coming back never changes task bookkeeping, but an
        # explicit 'available' clears a stale busy flag when idle.
        tasks_service._recount_volunteer(volunteer_id)
        updated = volunteers_service.get_volunteer(volunteer_id)
    return updated
