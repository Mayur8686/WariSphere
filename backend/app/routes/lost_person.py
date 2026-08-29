from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile

from app.schemas.lost_person import LostPersonCreate, LostPersonStatusUpdate
from app.services.lost_person import (
    VALID_STATUSES,
    create_lost_person,
    list_lost_persons,
    update_status,
)
from app.services.photo_storage import read_validated_photo, save_photo


router = APIRouter(
    prefix="/lost-person",
    tags=["Lost Person"],
)


@router.post("")
def create_lost_person_report(person_data: LostPersonCreate):
    """Store a lost/found person report (Firestore, or local dev store)."""
    try:
        return create_lost_person(person_data)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create lost person report: {str(e)}",
        )


@router.post("/photo")
async def upload_lost_person_photo(
    file: UploadFile = File(...),
    client_report_id: str | None = Form(default=None),
):
    """Upload the person's photo (JPEG/PNG/WebP, ≤ 8 MB) and get its URL.

    Call this BEFORE `POST /lost-person` and pass the returned `photo_url`
    inside the report JSON.
    """
    data = await read_validated_photo(file)
    try:
        return save_photo(data, stem=client_report_id)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to store photo: {str(e)}",
        )


@router.get("")
def list_reports(
    limit: int = Query(default=50, ge=1, le=200),
    status: str | None = Query(default=None),
    report_type: str | None = Query(default=None),
):
    """Reports, newest first (used by the app to browse active cases)."""
    if status and status not in VALID_STATUSES:
        raise HTTPException(
            status_code=422,
            detail=f"status must be one of {sorted(VALID_STATUSES)}",
        )
    try:
        reports = list_lost_persons(limit, status, report_type)
        return {"count": len(reports), "reports": reports}
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to list lost person reports: {str(e)}",
        )


@router.patch("/{lost_person_id}/status")
def update_report_status(
    lost_person_id: str,
    body: LostPersonStatusUpdate,
):
    """Mark a report found / reunited (mirrors the app's “Mark reunited”)."""
    try:
        record = update_status(lost_person_id, body.status)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update report status: {str(e)}",
        )
    if record is None:
        raise HTTPException(status_code=404, detail="Report not found.")
    return record
