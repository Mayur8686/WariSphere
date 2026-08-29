"""Firebase-ID-token authentication + role-based authorization.

Every protected endpoint resolves the caller to a :class:`Principal`:

* **Firebase configured** → the ``Authorization: Bearer <idToken>`` header
  is verified with the Firebase Admin SDK, then the caller's role is read
  from the existing ``users/{uid}`` document. Role changes take effect on
  the next request — no custom claims to mint or revoke.
* **No service-account key (repo dev mode)** → the backend accepts
  ``dev:<uid>`` tokens issued by ``POST /auth/dev-session`` against the
  local users store, so the same authorization rules are exercised before
  the Firebase project exists. This path is *disabled automatically* the
  moment a real key is configured.

Frontend route guards alone are never trusted: every authority/volunteer
API re-checks the role server-side.
"""

from dataclasses import dataclass, field

from fastapi import Depends, Header, HTTPException

from app import firebase
from app.services import local_store, users

DEV_TOKEN_PREFIX = "dev:"

# Built-in local dev authority so the demo works with zero provisioning,
# mirroring the previous "demo mode — sign in with anything" dashboard.
# Only ever created in the LOCAL store (never in Firebase).
DEV_AUTHORITY_EMAIL = "authority@warisphere.dev"
DEV_AUTHORITY_PASSWORD = "Authority@123"
DEV_AUTHORITY_UID = "dev-authority"


@dataclass
class Principal:
    uid: str
    role: str
    name: str
    email: str | None = None
    status: str = "active"
    mode: str = field(default="firebase")  # "firebase" | "dev"


def _principal_from_user(record: dict, *, mode: str) -> Principal:
    return Principal(
        uid=str(record.get("uid") or ""),
        role=str(record.get("role") or ""),
        name=str(record.get("name") or "User"),
        email=record.get("email"),
        status=str(record.get("status") or "active"),
        mode=mode,
    )


def ensure_dev_authority() -> dict:
    """Lazily provision the built-in dev authority (local store only)."""
    record = users.get_user(DEV_AUTHORITY_UID)
    if record is None:
        record = users.create_user_record(
            DEV_AUTHORITY_UID,
            name="Control Room Authority",
            email=DEV_AUTHORITY_EMAIL,
            role="authority",
            status="active",
            created_by="system",
            dev_password=DEV_AUTHORITY_PASSWORD,
        )
    return record


def _principal_from_dev_token(token: str) -> Principal:
    uid = token[len(DEV_TOKEN_PREFIX):]
    if not uid:
        raise HTTPException(status_code=401, detail="Malformed dev token.")
    if uid == DEV_AUTHORITY_UID:
        ensure_dev_authority()
    record = users.get_user(uid)
    if record is None:
        raise HTTPException(status_code=401, detail="Unknown dev account.")
    return _principal_from_user(record, mode="dev")


def _principal_from_firebase_token(token: str) -> Principal:
    from firebase_admin import auth as admin_auth

    try:
        decoded = admin_auth.verify_id_token(token)
    except admin_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Session expired — sign in again.")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid Firebase ID token.")

    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Token has no uid.")

    record = users.get_user(uid)
    if record is None:
        raise HTTPException(
            status_code=403,
            detail="No WariSphere user profile for this account.",
        )
    return _principal_from_user(record, mode="firebase")


def get_principal(authorization: str | None = Header(default=None)) -> Principal:
    """Resolve the caller from the Authorization header (any role)."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=401,
            detail="Missing Bearer token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Empty Bearer token.")

    if firebase.firebase_ready:
        principal = _principal_from_firebase_token(token)
    else:
        if not token.startswith(DEV_TOKEN_PREFIX):
            raise HTTPException(
                status_code=503,
                detail="Firebase is not configured on this server; only dev "
                "tokens issued by POST /auth/dev-session are accepted.",
            )
        principal = _principal_from_dev_token(token)

    if principal.status != "active":
        raise HTTPException(
            status_code=403,
            detail=f"Account is {principal.status}. Contact the control room.",
        )
    return principal


def require_authority(principal: Principal = Depends(get_principal)) -> Principal:
    if principal.role != "authority":
        raise HTTPException(
            status_code=403,
            detail="Authority role required.",
        )
    return principal


def require_volunteer(principal: Principal = Depends(get_principal)) -> Principal:
    if principal.role != "volunteer":
        raise HTTPException(
            status_code=403,
            detail="Volunteer role required.",
        )
    return principal


def touch_volunteer_presence(uid: str) -> None:
    """Best-effort 'last active' marker; never raises."""
    try:
        from app.services import volunteers

        volunteers.update_volunteer_fields(
            uid, {"last_active_at": local_store.utcnow()}
        )
    except Exception:  # pragma: no cover
        pass
