"""Pydantic schemas for the volunteer system.

Volunteers are created by an authority (never self-registered) and carry
two independent state axes:

  status        account lifecycle: active | inactive | suspended
  availability  dispatch readiness:  available | busy | offline
"""

from pydantic import BaseModel, Field, field_validator

ACCOUNT_STATUSES = {"active", "inactive", "suspended"}
AVAILABILITY_STATES = {"available", "busy", "offline"}

# Suggested skills surfaced by the dashboards. Free-form skills are still
# accepted (stored lowercase) so authorities are not blocked by a typo.
SUGGESTED_SKILLS = [
    "first_aid",
    "crowd_management",
    "lost_person_assistance",
    "medical_assistance",
    "route_assistance",
    "emergency_response",
]


def _clean_skills(value: list[str] | None) -> list[str]:
    out: list[str] = []
    for skill in value or []:
        norm = " ".join(str(skill).strip().lower().split())
        if norm and norm not in out:
            out.append(norm)
    return out[:12]


class VolunteerCreate(BaseModel):
    """Authority creates a volunteer account (name + credentials + profile)."""

    name: str = Field(..., min_length=2, max_length=80)
    email: str = Field(..., min_length=5, max_length=120)
    password: str = Field(..., min_length=6, max_length=72)
    phone: str | None = Field(default=None, max_length=24)
    emergency_contact: str | None = Field(default=None, max_length=24)
    zone: str | None = Field(default=None, max_length=120)
    skills: list[str] | None = None
    availability: str = "available"

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        v = v.strip().lower()
        if "@" not in v or "." not in v.split("@")[-1]:
            raise ValueError("email must look like an email address")
        return v

    @field_validator("availability")
    @classmethod
    def _availability(cls, v: str) -> str:
        v = (v or "available").strip().lower()
        if v not in AVAILABILITY_STATES:
            raise ValueError(f"availability must be one of {sorted(AVAILABILITY_STATES)}")
        return v

    _skills = field_validator("skills", mode="before")(_clean_skills)


class VolunteerUpdate(BaseModel):
    """Patch a volunteer profile.

    `role`, `skills`, counters and ownership are deliberately NOT here so a
    volunteer can never escalate privileges through this endpoint.
    """

    name: str | None = Field(default=None, min_length=2, max_length=80)
    phone: str | None = Field(default=None, max_length=24)
    emergency_contact: str | None = Field(default=None, max_length=24)
    zone: str | None = Field(default=None, max_length=120)
    skills: list[str] | None = None

    _skills = field_validator("skills", mode="before")(_clean_skills)


class VolunteerStatusUpdate(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def _status(cls, v: str) -> str:
        v = (v or "").strip().lower()
        if v not in ACCOUNT_STATUSES:
            raise ValueError(f"status must be one of {sorted(ACCOUNT_STATUSES)}")
        return v


class AvailabilityUpdate(BaseModel):
    availability: str

    @field_validator("availability")
    @classmethod
    def _availability(cls, v: str) -> str:
        v = (v or "").strip().lower()
        if v not in AVAILABILITY_STATES:
            raise ValueError(f"availability must be one of {sorted(AVAILABILITY_STATES)}")
        return v
