from datetime import datetime, timezone
from uuid import uuid4

from app.firebase import db
from app.schemas.sos import SOSCreate


def create_sos(sos_data: SOSCreate) -> dict:
    sos_id = str(uuid4())

    sos_record = {
        "sos_id": sos_id,
        "user_id": sos_data.user_id,
        "latitude": sos_data.latitude,
        "longitude": sos_data.longitude,
        "sos_type": sos_data.sos_type,
        "message": sos_data.message,
        "status": "active",
        "created_at": datetime.now(timezone.utc),
    }

    db.collection("sos_alerts").document(sos_id).set(sos_record)

    return sos_record