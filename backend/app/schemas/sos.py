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
