from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.schemas.sos import SOSCreate
from app.services import sos as sos_service
from app.services import tasks as tasks_service
from app.services.auth import Principal, require_authority
from app.services.sos import create_sos


router = APIRouter(
    prefix="/sos",
    tags=["SOS"],
)


class SOSStatusUpdate(BaseModel):
    status: str  # resolved | cancelled | active


@router.post("")
def create_sos_alert(sos_data: SOSCreate):
    """Mobile app intake. Firestore when configured, otherwise the local
    dev store (never a crash — see backend/README.md)."""
    try:
        return create_sos(sos_data)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create SOS alert: {str(e)}",
        )


@router.get("")
def list_sos_alerts(
    limit: int = Query(default=100, ge=1, le=500),
    status: str | None = Query(default=None),
):
    """Newest-first listing (REST fallback for the authority dashboard;
    the primary view subscribes to Firestore directly)."""
    if status and status not in sos_service.VALID_STATUSES:
        raise HTTPException(
            status_code=422,
            detail=f"status must be one of {sorted(sos_service.VALID_STATUSES)}",
        )
    alerts = sos_service.list_sos(limit=limit, status=status)
    return {"count": len(alerts), "alerts": alerts}


@router.get("/{sos_id}")
def get_sos_alert(sos_id: str):
    record = sos_service.get_sos(sos_id)
    if record is None:
        raise HTTPException(status_code=404, detail="SOS alert not found.")
    return record


@router.patch("/{sos_id}/status")
def update_sos_status(
    sos_id: str,
    body: SOSStatusUpdate,
    authority: Principal = Depends(require_authority),
):
    """Authority resolves/cancels an alert.

    Resolving an alert that still has an open volunteer task cancels that
    task and releases the volunteer, so every view stays consistent.
    """
    if body.status not in {"resolved", "cancelled", "active"}:
        raise HTTPException(status_code=422, detail="status must be resolved | cancelled | active")

    record = sos_service.get_sos(sos_id)
    if record is None:
        raise HTTPException(status_code=404, detail="SOS alert not found.")

    if body.status in {"resolved", "cancelled"} and record.get("task_id"):
        linked = tasks_service.get_task(record["task_id"])
        if linked and linked.get("status") not in {"completed", "cancelled"}:
            tasks_service.cancel_task(
                record["task_id"],
                actor_uid=authority.uid,
                actor_name=authority.name,
                note=f"SOS {body.status} directly by control room",
            )
        record = sos_service.get_sos(sos_id)

    if body.status == "resolved":
        updated = sos_service.update_sos_status(sos_id, "resolved")
    elif body.status == "cancelled":
        updated = sos_service.update_sos_status(sos_id, "cancelled")
    else:
        updated = sos_service.update_sos_fields(sos_id, {
            "status": "active",
            "task_id": None,
            "assigned_to": None,
            "assigned_volunteer_name": None,
        })
    return updated
