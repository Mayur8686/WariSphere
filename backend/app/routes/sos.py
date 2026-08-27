from fastapi import APIRouter, HTTPException

from app.schemas.sos import SOSCreate
from app.services.sos import create_sos


router = APIRouter(
    prefix="/sos",
    tags=["SOS"],
)


@router.post("")
def create_sos_alert(sos_data: SOSCreate):
    try:
        return create_sos(sos_data)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create SOS alert: {str(e)}",
        )