from pydantic import BaseModel, Field


class SOSCreate(BaseModel):
    user_id: str = Field(..., min_length=1)
    latitude: float
    longitude: float
    sos_type: str = "general"
    message: str | None = None