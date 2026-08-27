from fastapi import APIRouter, HTTPException

from app.schemas.lost_person import LostPersonCreate
from app.services.lost_person import create_lost_person


router = APIRouter(
    prefix="/lost-person",
    tags=["Lost Person"],
)


@router.post("")
def create_lost_person_report(person_data: LostPersonCreate):
    try:
        return create_lost_person(person_data)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create lost person report: {str(e)}",
        )