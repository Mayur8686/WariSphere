from fastapi import APIRouter, HTTPException

from app import firebase
from app.schemas.sos import SOSCreate
from app.services.sos import create_sos


router = APIRouter(
    prefix="/sos",
    tags=["SOS"],
)


@router.post("")
def create_sos_alert(sos_data: SOSCreate):
    # `firebase.db`/`firebase_ready` are read through the module so tests
    # (and the key being added after boot) see the current object.
    if not firebase.firebase_ready or firebase.db is None:
        raise HTTPException(
            status_code=503,
            detail="Firebase not configured on this server - add "
            "firebase-service-account.json (see backend/README.md).",
        )
    try:
        return create_sos(sos_data)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create SOS alert: {str(e)}",
        )
