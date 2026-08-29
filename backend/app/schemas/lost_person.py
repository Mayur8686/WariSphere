from datetime import datetime
from pydantic import BaseModel, Field


class LostPersonCreate(BaseModel):
    """Incoming lost/found person report from the WariSathi app.

    Only `name` is mandatory — a volunteer scribbling a report at a help desk
    must be able to save whatever they know. Everything else is optional.

    Field mapping from the Flutter model (`lib/models/lost_person.dart`):

    | Flutter `LostPersonReport` | API field                  |
    | -------------------------- | -------------------------- |
    | `id` (LP-XXXX)             | `client_report_id`         |
    | `personName`               | `name`                     |
    | `type`                     | `report_type` (lost/found) |
    | `age` / `gender`           | `age` / `gender`           |
    | `description`              | `description`              |
    | `lastSeenPlace`            | `last_seen_location`       |
    | `lastSeenTime`             | `last_seen_time`           |
    | `latitude`/`longitude`     | `last_seen_latitude`/`longitude` |
    | `reporterName`/`Phone`     | `reporter_name`/`reporter_phone` |
    | `photoUrl`                 | `photo_url`                |
    """

    name: str = Field(..., min_length=1)
    report_type: str = Field(default="lost", pattern="^(lost|found)$")
    age: int | None = Field(default=None, ge=0, le=150)
    gender: str | None = None
    description: str | None = None
    last_seen_location: str | None = None
    last_seen_time: datetime | None = None
    last_seen_latitude: float | None = None
    last_seen_longitude: float | None = None
    photo_url: str | None = None

    # Reporter identity (best-effort — helps volunteers call back).
    reporter_id: str | None = None
    reporter_name: str | None = None
    reporter_phone: str | None = None
    contact_number: str | None = None  # legacy alias for reporter_phone

    # App-side ID (LP-XXXX): makes retries after a flaky network idempotent.
    client_report_id: str | None = None


class LostPersonStatusUpdate(BaseModel):
    status: str = Field(..., pattern="^(missing|found|reunited)$")
