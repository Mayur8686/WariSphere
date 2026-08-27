from datetime import datetime, timezone
from uuid import uuid4

from app.firebase import db
from app.schemas.lost_person import LostPersonCreate


def create_lost_person(person_data: LostPersonCreate) -> dict:
    lost_person_id = str(uuid4())

    person_record = {
        "lost_person_id": lost_person_id,
        "reporter_id": person_data.reporter_id,
        "name": person_data.name,
        "age": person_data.age,
        "description": person_data.description,
        "last_seen_latitude": person_data.last_seen_latitude,
        "last_seen_longitude": person_data.last_seen_longitude,
        "last_seen_location": person_data.last_seen_location,
        "contact_number": person_data.contact_number,
        "photo_url": person_data.photo_url,
        "status": "missing",
        "created_at": datetime.now(timezone.utc),
    }

    db.collection("lost_persons").document(lost_person_id).set(person_record)

    return person_record