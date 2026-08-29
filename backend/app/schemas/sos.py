from pydantic import BaseModel, Field


class SOSCreate(BaseModel):
    """Incoming SOS payload from the WariSathi app.

    latitude/longitude are optional: an alert raised without a GPS fix
    (underground, denied permission) must still reach the control room.
    """

    user_id: str = Field(..., min_length=1)
    latitude: float | None = None
    longitude: float | None = None
    sos_type: str = "general"
    message: str | None = None
    # enriched fields from the app (best-effort identity for volunteers)
    user_name: str | None = None
    user_phone: str | None = None
    accuracy_meters: float | None = None
    # ICE (In Case of Emergency) contact from the pilgrim's profile —
    # the server-side SMS goes to this number plus the control room.
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
