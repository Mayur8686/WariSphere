"""Backend configuration, read from environment variables.

A local `backend/.env` file is loaded automatically for development when
python-dotenv is available (it is in requirements.txt). `.env` is
git-ignored — never put real credentials in code or in `.env.example`.

Everything here is a plain function reading `os.environ` at call time so
that tests can monkeypatch environment variables and see the change.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field

try:  # python-dotenv is a normal dependency, but never fatal if absent.
    from dotenv import load_dotenv

    load_dotenv()
except Exception:  # pragma: no cover - defensive only
    pass

# Supported SMS gateways. "none" is the dev mode: nothing is sent.
VALID_SMS_PROVIDERS = ("none", "fast2sms", "twilio")

DEFAULT_SMS_TIMEOUT_SECONDS = 10


def _clean(value: str | None) -> str:
    return (value or "").strip()


@dataclass(frozen=True)
class SmsSettings:
    """Resolved SMS configuration. Never log/print the API key or token."""

    provider: str = "none"
    fast2sms_api_key: str = ""
    fast2sms_sender_id: str = "FSTSMS"
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""
    control_room_numbers: tuple[str, ...] = field(default_factory=tuple)
    default_country_code: str = "+91"
    timeout_seconds: float = float(DEFAULT_SMS_TIMEOUT_SECONDS)

    @property
    def is_fast2sms(self) -> bool:
        return self.provider == "fast2sms"

    @property
    def is_twilio(self) -> bool:
        return self.provider == "twilio"

    @property
    def is_none(self) -> bool:
        return self.provider == "none"


def get_sms_settings() -> SmsSettings:
    """Build an :class:`SmsSettings` from the current environment."""
    provider = _clean(os.environ.get("SMS_PROVIDER")).lower() or "none"
    if provider not in VALID_SMS_PROVIDERS:
        # Unknown value: fail safe to dev mode instead of crashing or
        # sending via an unintended gateway.
        print(
            f"[sms] WARNING: unknown SMS_PROVIDER='{provider}' - "
            f"falling back to 'none' (valid: {', '.join(VALID_SMS_PROVIDERS)})."
        )
        provider = "none"

    country_code = _clean(os.environ.get("DEFAULT_COUNTRY_CODE")) or "+91"
    if not country_code.startswith("+"):
        country_code = f"+{country_code}"

    raw_rooms = _clean(os.environ.get("SOS_CONTROL_ROOM_NUMBERS"))
    control_room_numbers = tuple(
        part.strip()
        for part in raw_rooms.replace(";", ",").split(",")
        if part.strip()
    )

    timeout_raw = _clean(os.environ.get("SMS_TIMEOUT_SECONDS"))
    try:
        timeout = float(timeout_raw) if timeout_raw else float(
            DEFAULT_SMS_TIMEOUT_SECONDS
        )
        if timeout <= 0:
            timeout = float(DEFAULT_SMS_TIMEOUT_SECONDS)
    except ValueError:
        timeout = float(DEFAULT_SMS_TIMEOUT_SECONDS)

    return SmsSettings(
        provider=provider,
        fast2sms_api_key=_clean(os.environ.get("FAST2SMS_API_KEY")),
        fast2sms_sender_id=_clean(os.environ.get("FAST2SMS_SENDER_ID"))
        or "FSTSMS",
        twilio_account_sid=_clean(os.environ.get("TWILIO_ACCOUNT_SID")),
        twilio_auth_token=_clean(os.environ.get("TWILIO_AUTH_TOKEN")),
        twilio_from_number=_clean(os.environ.get("TWILIO_FROM_NUMBER")),
        control_room_numbers=control_room_numbers,
        default_country_code=country_code,
        timeout_seconds=timeout,
    )
