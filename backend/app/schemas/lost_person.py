from pydantic import BaseModel, Field


class LostPersonCreate(BaseModel):
    reporter_id: str = Field(..., min_length=1)
    name: str = Field(..., min_length=1)
    age: int | None = Field(default=None, ge=0)
    description: str | None = None
    last_seen_latitude: float
    last_seen_longitude: float
    last_seen_location: str | None = None
    contact_number: str | None = None
    photo_url: str | None = None