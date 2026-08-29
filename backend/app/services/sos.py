"""SOS alerts: persist to Firestore FIRST, then send server-side SMS.

The SMS step is strictly best-effort:

* the alert document is written to Firestore before any SMS is attempted;
* any SMS gateway failure/timeout is recorded on the SOS document but
  NEVER causes the API call to fail — a raised alert must never be lost
  because an SMS provider was unreachable.
"""

from datetime import datetime, timezone
from uuid import uuid4

from app import firebase
from app.schemas.sos import SOSCreate
from app.services.sms import dispatch_sos_sms


def _serialized(record: dict) -> dict:
    """Firestore speaks `datetime`; the mobile client expects ISO strings."""
    out = dict(record)
    created = out.get("created_at")
    if isinstance(created, datetime):
        out["created_at"] = created.astimezone(timezone.utc).isoformat()
    updated = out.get("sms_updated_at")
    if isinstance(updated, datetime):
        out["sms_updated_at"] = updated.astimezone(timezone.utc).isoformat()
    return out


def create_sos(sos_data: SOSCreate) -> dict:
    sos_id = str(uuid4())
    now = datetime.now(timezone.utc)

    sos_record = {
        "sos_id": sos_id,
        "user_id": sos_data.user_id,
        "latitude": sos_data.latitude,
        "longitude": sos_data.longitude,
        "sos_type": sos_data.sos_type,
        "message": sos_data.message,
        "user_name": sos_data.user_name,
        "user_phone": sos_data.user_phone,
        "accuracy_meters": sos_data.accuracy_meters,
        "emergency_contact_name": sos_data.emergency_contact_name,
        "emergency_contact_phone": sos_data.emergency_contact_phone,
        "status": "active",
        "created_at": now,
    }

    # 1) Persist the alert FIRST — it is the source of truth.
    doc_ref = firebase.db.collection("sos_alerts").document(sos_id)
    doc_ref.set(sos_record)

    # 2) Server-side SMS — best-effort and never fatal.
    try:
        sms_summary = dispatch_sos_sms(sos_record)
        sos_record["sms"] = sms_summary
        # Record the delivery results back onto the Firestore document.
        try:
            doc_ref.update(
                {
                    "sms": sms_summary,
                    "sms_updated_at": datetime.now(timezone.utc),
                }
            )
        except Exception as exc:  # alert is safe; only the update failed
            print(
                "[sos] WARNING: SMS was dispatched but the SOS document "
                f"could not be updated with results: {type(exc).__name__}"
            )
    except Exception as exc:
        # Absolute safety net: SMS must never undo the Firestore write.
        print(
            "[sos] WARNING: SMS dispatch failed after the SOS was stored: "
            f"{type(exc).__name__}"
        )

    return _serialized(sos_record)
