"""Pydantic schemas for the centralised volunteer task system.

One task model covers every dispatch kind (SOS, lost person, medical, ...).
A task never duplicates the source record: `source_kind` + `source_id`
reference the existing `sos_alerts` / `lost_persons` documents, and a
read-only `incident` snapshot is embedded at assignment time so the
volunteer only sees the details they need for THIS task.
"""

from pydantic import BaseModel, Field, field_validator

TASK_TYPES = {
    "sos",
    "lost_person",
    "medical_assistance",
    "crowd_assistance",
    "route_assistance",
    "general",
}

TASK_PRIORITIES = {"low", "medium", "high", "critical"}

TASK_STATUSES = {
    "assigned",
    "accepted",
    "in_progress",
    "completed",
    "rejected",
    "cancelled",
    "unable_to_complete",
}

# Statuses in which the task still occupies the assigned volunteer.
ACTIVE_TASK_STATUSES = {"assigned", "accepted", "in_progress"}

# Allowed transitions. Anything not listed here is rejected with HTTP 409.
TASK_TRANSITIONS = {
    "assigned": {"accepted", "rejected", "cancelled", "assigned"},
    "accepted": {"in_progress", "unable_to_complete", "cancelled", "assigned"},
    "in_progress": {"completed", "unable_to_complete", "cancelled", "assigned"},
    "rejected": {"assigned", "cancelled"},
    "unable_to_complete": {"assigned", "cancelled"},
    "completed": set(),
    "cancelled": {"assigned"},
}

SOURCE_KINDS = {"sos", "lost_person", "medical_camp", "manual", "none"}


class TaskLocation(BaseModel):
    latitude: float | None = None
    longitude: float | None = None
    address: str | None = Field(default=None, max_length=240)


class IncidentSnapshot(BaseModel):
    """Read-only details of the underlying SOS / lost person, embedded so
    the volunteer needs no read access to the source collections."""

    person_name: str | None = Field(default=None, max_length=120)
    person_phone: str | None = Field(default=None, max_length=24)
    details: str | None = Field(default=None, max_length=1000)
    photo_url: str | None = Field(default=None, max_length=500)
    medical_camp: dict | None = None


class TaskCreate(BaseModel):
    """Authority creates (and immediately assigns) a task."""

    type: str = Field(default="general")
    title: str = Field(..., min_length=2, max_length=140)
    description: str | None = Field(default=None, max_length=1000)
    priority: str = "medium"

    assigned_to: str = Field(..., min_length=1)

    source_kind: str = "manual"
    source_id: str | None = None

    location: TaskLocation | None = None
    incident: IncidentSnapshot | None = None

    @field_validator("type")
    @classmethod
    def _type(cls, v: str) -> str:
        v = (v or "general").strip().lower()
        if v not in TASK_TYPES:
            raise ValueError(f"type must be one of {sorted(TASK_TYPES)}")
        return v

    @field_validator("priority")
    @classmethod
    def _priority(cls, v: str) -> str:
        v = (v or "medium").strip().lower()
        if v not in TASK_PRIORITIES:
            raise ValueError(f"priority must be one of {sorted(TASK_PRIORITIES)}")
        return v

    @field_validator("source_kind")
    @classmethod
    def _source_kind(cls, v: str) -> str:
        v = (v or "manual").strip().lower()
        if v not in SOURCE_KINDS:
            raise ValueError(f"source_kind must be one of {sorted(SOURCE_KINDS)}")
        return v


class TaskAssign(BaseModel):
    """Assign (or re-assign) an existing task to a volunteer."""

    volunteer_id: str = Field(..., min_length=1)


class TaskNote(BaseModel):
    """Free-text payload carried by complete / reject / report-issue."""

    note: str | None = Field(default=None, max_length=1000)
