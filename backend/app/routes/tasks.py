"""Task APIs — one central model for every dispatch kind.

Authority: create, assign/re-assign, cancel, monitor everything.
Volunteer: list and drive ONLY their own tasks through the lifecycle
(accept → start → complete / reject / report issue). The state machine
itself lives in app/services/tasks.py and rejects illegal transitions.
"""

from fastapi import APIRouter, Depends, HTTPException, Query

from app.schemas.task import TaskAssign, TaskCreate, TaskNote
from app.services import tasks as tasks_service
from app.services.auth import (
    Principal,
    get_principal,
    require_authority,
    require_volunteer,
    touch_volunteer_presence,
)

router = APIRouter(
    prefix="/tasks",
    tags=["Tasks"],
)


# ---------------------------------------------------------------------------
# Create + monitor (authority)
# ---------------------------------------------------------------------------


@router.post("", status_code=201)
def create_task(
    body: TaskCreate,
    authority: Principal = Depends(require_authority),
):
    try:
        return tasks_service.create_task(
            body,
            authority_uid=authority.uid,
            authority_name=authority.name,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to create task: {exc}")


@router.get("")
def list_tasks(
    view: str = Query(default="all", pattern="^(all|active|completed)$"),
    status: str | None = Query(default=None),
    type: str | None = Query(default=None),
    assigned_to: str | None = Query(default=None),
    source_kind: str | None = Query(default=None),
    source_id: str | None = Query(default=None),
    limit: int = Query(default=200, ge=1, le=500),
    _: Principal = Depends(require_authority),
):
    tasks = tasks_service.list_tasks(
        view=view,
        status=status,
        type=type,
        assigned_to=assigned_to,
        source_kind=source_kind,
        source_id=source_id,
        limit=limit,
    )
    return {"count": len(tasks), "tasks": tasks}


# ---------------------------------------------------------------------------
# Own tasks (volunteer) — before /{task_id}
# ---------------------------------------------------------------------------


@router.get("/my")
def my_tasks(
    view: str = Query(default="active", pattern="^(all|active|completed)$"),
    principal: Principal = Depends(require_volunteer),
):
    touch_volunteer_presence(principal.uid)
    tasks = tasks_service.list_tasks(view=view, assigned_to=principal.uid)
    return {"count": len(tasks), "tasks": tasks}


@router.get("/{task_id}")
def get_task(
    task_id: str,
    principal: Principal = Depends(get_principal),
):
    task = tasks_service.get_task(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found.")
    if principal.role != "authority" and task.get("assigned_to") != principal.uid:
        raise HTTPException(status_code=403, detail="This task belongs to another volunteer.")
    return task


# ---------------------------------------------------------------------------
# Lifecycle actions (assigned volunteer)
# ---------------------------------------------------------------------------


def _volunteer_action(task_id: str, action: str, principal: Principal, note: str | None):
    touch_volunteer_presence(principal.uid)
    return tasks_service.transition_task(
        task_id,
        action,
        actor_uid=principal.uid,
        actor_name=principal.name,
        note=note,
    )


@router.patch("/{task_id}/accept")
def accept_task(task_id: str, principal: Principal = Depends(require_volunteer)):
    return _volunteer_action(task_id, "accept", principal, None)


@router.patch("/{task_id}/start")
def start_task(task_id: str, principal: Principal = Depends(require_volunteer)):
    return _volunteer_action(task_id, "start", principal, None)


@router.patch("/{task_id}/complete")
def complete_task(
    task_id: str,
    body: TaskNote | None = None,
    principal: Principal = Depends(require_volunteer),
):
    note = body.note if body else None
    return _volunteer_action(task_id, "complete", principal, note)


@router.patch("/{task_id}/reject")
def reject_task(
    task_id: str,
    body: TaskNote | None = None,
    principal: Principal = Depends(require_volunteer),
):
    note = body.note if body else None
    return _volunteer_action(task_id, "reject", principal, note)


@router.patch("/{task_id}/unable-to-complete")
def unable_to_complete_task(
    task_id: str,
    body: TaskNote | None = None,
    principal: Principal = Depends(require_volunteer),
):
    note = body.note if body else None
    return _volunteer_action(task_id, "unable_to_complete", principal, note)


# ---------------------------------------------------------------------------
# Assignment management (authority)
# ---------------------------------------------------------------------------


@router.post("/{task_id}/assign")
def assign_task(
    task_id: str,
    body: TaskAssign,
    authority: Principal = Depends(require_authority),
):
    return tasks_service.assign_task(
        task_id,
        body.volunteer_id,
        authority_uid=authority.uid,
        authority_name=authority.name,
    )


@router.patch("/{task_id}/cancel")
def cancel_task(
    task_id: str,
    body: TaskNote | None = None,
    authority: Principal = Depends(require_authority),
):
    note = body.note if body else None
    return tasks_service.cancel_task(
        task_id,
        actor_uid=authority.uid,
        actor_name=authority.name,
        note=note,
    )
