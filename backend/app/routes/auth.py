"""Session endpoints.

Firebase is the only production authentication mechanism. The
``/auth/dev-session`` endpoint exists purely for the repository's
no-Firebase dev mode and refuses to run once a service-account key is
configured.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app import firebase
from app.services import auth as auth_service
from app.services.auth import Principal


router = APIRouter(
    prefix="/auth",
    tags=["Auth"],
)


class DevSessionRequest(BaseModel):
    email: str
    password: str


@router.get("/me")
def whoami(principal: Principal = Depends(auth_service.get_principal)):
    """Return the caller's identity + role (dashboards use this right
    after Firebase sign-in to enforce client-side role routing)."""
    if principal.role == "volunteer":
        auth_service.touch_volunteer_presence(principal.uid)
    return {
        "uid": principal.uid,
        "name": principal.name,
        "email": principal.email,
        "role": principal.role,
        "status": principal.status,
        "mode": principal.mode,
    }


@router.post("/dev-session")
def dev_session(body: DevSessionRequest):
    """Exchange seeded dev credentials for a ``dev:<uid>`` token.

    403 once Firebase is configured — production logins go through
    Firebase Authentication on the client; this backend then verifies the
    resulting ID token.
    """
    if firebase.firebase_ready:
        raise HTTPException(
            status_code=403,
            detail="Dev sessions are disabled — Firebase Authentication is active.",
        )

    auth_service.ensure_dev_authority()
    record = None
    email = (body.email or "").strip().lower()
    if email == auth_service.DEV_AUTHORITY_EMAIL:
        from app.services import users

        record = users.get_user(auth_service.DEV_AUTHORITY_UID)
        if record and record.get("dev_password") != body.password:
            record = None
    else:
        from app.services import users

        record = users.verify_dev_credentials(email, body.password)

    if record is None:
        raise HTTPException(status_code=401, detail="Invalid dev credentials.")

    if record.get("role") == "volunteer":
        auth_service.touch_volunteer_presence(record["uid"])
    return {
        "token": f"{auth_service.DEV_TOKEN_PREFIX}{record['uid']}",
        "uid": record["uid"],
        "name": record.get("name"),
        "email": record.get("email"),
        "role": record.get("role"),
        "status": record.get("status", "active"),
        "mode": "dev",
    }
