from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile

from app import config
from app.schemas.lost_person import (
    LostPersonCreate,
    LostPersonStatusUpdate,
    MatchDecisionRequest,
)
from app.services.lost_person import (
    VALID_STATUSES,
    create_lost_person,
    list_lost_persons,
    update_status,
)
from app.services.matching import confirm_match, reject_match, scan_found_image
from app.services.photo_storage import read_validated_photo, save_photo


router = APIRouter(
    prefix="/lost-person",
    tags=["Lost Person"],
)


def require_authority(
    x_authority_token: str | None = Header(default=None, alias="X-Authority-Token"),
) -> None:
    """Gate matching endpoints when WARISPHERE_AUTHORITY_TOKEN is set.

    The rest of this hackathon API is unauthenticated (mobile clients post
    lost-person reports without a token). Matching is authority-only once
    an operator configures the shared secret.
    """
    expected = config.AUTHORITY_TOKEN
    if not expected:
        return
    if not x_authority_token or x_authority_token != expected:
        raise HTTPException(
            status_code=401,
            detail="Authority authorization required for face matching.",
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
    """Reports, newest first (used by the app to browse active cases).

    Face embeddings are never included in this response.
    """
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


# ---------------------------------------------------------------------------
# AI-assisted face matching (authority dashboard)
# ---------------------------------------------------------------------------


@router.post("/scan-match")
async def scan_match(
    file: UploadFile = File(...),
    reporter_name: str | None = Form(default="Control Room"),
    client_report_id: str | None = Form(default=None),
    _: None = Depends(require_authority),
):
    """Upload a FOUND-person photo and return ranked probable matches.

    This does **not** confirm identity. The authority must call
    `/matches/{id}/confirm` or `/matches/{id}/reject`.
    """
    data = await read_validated_photo(file)
    try:
        return scan_found_image(
            data,
            reporter_name=reporter_name or "Control Room",
            client_report_id=client_report_id,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Face matching failed: {str(e)}",
        )


@router.post("/matches/{match_id}/confirm")
def confirm_face_match(
    match_id: str,
    body: MatchDecisionRequest | None = None,
    _: None = Depends(require_authority),
):
    """Authority confirms a proposed match and marks both people reunited."""
    payload = body or MatchDecisionRequest()
    try:
        return confirm_match(match_id, verified_by=payload.verified_by)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to confirm match: {str(e)}",
        )


@router.post("/matches/{match_id}/reject")
def reject_face_match(
    match_id: str,
    body: MatchDecisionRequest | None = None,
    _: None = Depends(require_authority),
):
    """Authority rejects a proposed match. Person statuses are unchanged."""
    payload = body or MatchDecisionRequest()
    try:
        return reject_match(match_id, verified_by=payload.verified_by)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to reject match: {str(e)}",
        )


@router.get("/face-match/status")
def face_match_status():
    """Liveness of the InsightFace model (does not expose embeddings)."""
    from app.services import face_match as fm

    insightface = fm.is_model_ready() and fm._APP is not None
    return {
        "ready": True if insightface or fm._HAAR is not None else fm.is_model_ready(),
        "backend": "insightface" if insightface else "opencv-haar-fallback",
        "model": config.FACE_MODEL_NAME if insightface else "haar+hog",
        "embedding_version": fm.active_embedding_version(),
        "top_k": config.FACE_MATCH_TOP_K,
        "thresholds": {
            "high": config.FACE_SIMILARITY_HIGH,
            "possible": config.FACE_SIMILARITY_POSSIBLE,
            "min": config.FACE_SIMILARITY_MIN,
        },
        "error": None if insightface or fm._HAAR is not None else fm.model_error(),
        "disclaimer": (
            "Probable matches only. Similarity is not identity confirmation."
        ),
    }
