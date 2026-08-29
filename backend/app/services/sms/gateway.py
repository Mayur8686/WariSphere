"""Provider dispatch for SOS SMS alerts.

Providers
---------
- ``none``     : dev mode. No HTTP request; logs/records what would be sent.
- ``fast2sms`` : Indian bulk-SMS gateway (https://www.fast2sms.com).
- ``twilio``   : international fallback (https://www.twilio.com).

Safety rules observed here:
* NEVER raise — a messaging failure must not undo the Firestore write.
* NEVER log or persist API keys / auth tokens.
* Do not make any HTTP request when the provider is ``none`` or when its
  configuration is missing; record an explanatory result instead.
"""

from __future__ import annotations

import logging
from typing import Any

import requests

from app.config import SmsSettings, get_sms_settings
from app.services.sms.message import build_sos_message
from app.services.sms.phone import collect_recipients

logger = logging.getLogger("warisphere.sms")


# --- result record ------------------------------------------------------------


def _result(
    *,
    phone: str,
    provider: str,
    status: str,
    detail: str,
    http_status: int | None = None,
    message_id: str | None = None,
) -> dict[str, Any]:
    """One SMS outcome. Deliberately contains no credentials."""
    record: dict[str, Any] = {
        "phone": phone,
        "provider": provider,
        "status": status,  # "sent" | "failed" | "simulated" | "skipped"
        "detail": detail,
    }
    if http_status is not None:
        record["http_status"] = http_status
    if message_id:
        record["message_id"] = message_id
    return record


# --- providers ----------------------------------------------------------------


def _send_none(recipients: list[str], body: str, settings: SmsSettings) -> list[dict]:
    """Dev mode: no network call. Log (recipient count only) + simulate."""
    preview = body.replace("\n", " | ")
    logger.info(
        "[sms:none] would send SOS SMS to %d recipient(s); message: %s",
        len(recipients),
        preview,
    )
    return [
        _result(
            phone=phone,
            provider="none",
            status="simulated",
            detail="SMS_PROVIDER=none (dev mode) - message logged, not sent.",
        )
        for phone in recipients
    ]


def _send_fast2sms(
    recipients: list[str], body: str, settings: SmsSettings
) -> list[dict]:
    """Fast2SMS bulk/quick route (one HTTP call, all recipients).

    Docs: POST https://www.fast2sms.com/dev/bulkV2 with headers
    ``authorization: <api key>`` and form fields ``numbers`` / ``message``.
    """
    if not settings.fast2sms_api_key:
        return [
            _result(
                phone=phone,
                provider="fast2sms",
                status="skipped",
                detail="FAST2SMS_API_KEY not configured - SMS not sent.",
            )
            for phone in recipients
        ]

    url = "https://www.fast2sms.com/dev/bulkV2"
    headers = {
        "authorization": settings.fast2sms_api_key,
        "Content-Type": "application/x-www-form-urlencoded",
    }
    # Fast2SMS expects Indian numbers without the "+".
    numbers = ",".join(phone.lstrip("+") for phone in recipients)
    data = {
        "route": "q",  # quick/transactional route
        "message": body,
        "language": "english",
        "numbers": numbers,
        "sender_id": settings.fast2sms_sender_id,
    }

    try:
        resp = requests.post(
            url,
            headers=headers,
            data=data,
            timeout=settings.timeout_seconds,
        )
    except requests.RequestException as exc:
        # Network/timeout — do not leak request objects (they carry the key).
        detail = f"Fast2SMS request error: {type(exc).__name__}"
        logger.warning("[sms:fast2sms] %s for %d recipient(s)", detail, len(recipients))
        return [
            _result(phone=phone, provider="fast2sms", status="failed", detail=detail)
            for phone in recipients
        ]

    status_code = resp.status_code
    try:
        payload = resp.json()
    except ValueError:
        payload = {}

    if status_code == 200 and payload.get("return") is True:
        request_id = str(payload.get("request_id", "")) or None
        logger.info(
            "[sms:fast2sms] accepted request_id=%s for %d recipient(s)",
            request_id,
            len(recipients),
        )
        return [
            _result(
                phone=phone,
                provider="fast2sms",
                status="sent",
                detail="Fast2SMS accepted the message.",
                http_status=status_code,
                message_id=request_id,
            )
            for phone in recipients
        ]

    # Provider rejected the send. Record status codes/messages only — the
    # gateway never echoes credentials in error bodies, and we don't either.
    detail = f"Fast2SMS rejected the request (HTTP {status_code})"
    msg = payload.get("message")
    if isinstance(msg, str) and msg:
        detail = f"{detail}: {msg[:200]}"
    logger.warning("[sms:fast2sms] failure: %s", detail)
    return [
        _result(
            phone=phone,
            provider="fast2sms",
            status="failed",
            detail=detail,
            http_status=status_code,
        )
        for phone in recipients
    ]


def _send_twilio(recipients: list[str], body: str, settings: SmsSettings) -> list[dict]:
    """Twilio Messages API — one HTTP call per recipient (E.164 `to`)."""
    missing = [
        name
        for name, value in (
            ("TWILIO_ACCOUNT_SID", settings.twilio_account_sid),
            ("TWILIO_AUTH_TOKEN", settings.twilio_auth_token),
            ("TWILIO_FROM_NUMBER", settings.twilio_from_number),
        )
        if not value
    ]
    if missing:
        detail = f"{', '.join(missing)} not configured - SMS not sent."
        return [
            _result(phone=phone, provider="twilio", status="skipped", detail=detail)
            for phone in recipients
        ]

    url = (
        f"https://api.twilio.com/2010-04-01/Accounts/"
        f"{settings.twilio_account_sid}/Messages.json"
    )
    results: list[dict] = []

    for phone in recipients:
        try:
            resp = requests.post(
                url,
                data={"From": settings.twilio_from_number, "To": phone, "Body": body},
                auth=(settings.twilio_account_sid, settings.twilio_auth_token),
                timeout=settings.timeout_seconds,
            )
        except requests.RequestException as exc:
            detail = f"Twilio request error: {type(exc).__name__}"
            logger.warning("[sms:twilio] %s for %s", detail, phone)
            results.append(
                _result(phone=phone, provider="twilio", status="failed", detail=detail)
            )
            continue

        if resp.status_code in (200, 201):
            try:
                sid = str(resp.json().get("sid", "")) or None
            except ValueError:
                sid = None
            logger.info("[sms:twilio] sent message sid=%s", sid)
            results.append(
                _result(
                    phone=phone,
                    provider="twilio",
                    status="sent",
                    detail="Twilio accepted the message.",
                    http_status=resp.status_code,
                    message_id=sid,
                )
            )
        else:
            detail = f"Twilio rejected the request (HTTP {resp.status_code})"
            try:
                err = resp.json().get("message")
                if isinstance(err, str) and err:
                    detail = f"{detail}: {err[:200]}"
            except ValueError:
                pass
            logger.warning("[sms:twilio] failure: %s", detail)
            results.append(
                _result(
                    phone=phone,
                    provider="twilio",
                    status="failed",
                    detail=detail,
                    http_status=resp.status_code,
                )
            )

    return results


# --- dispatch -----------------------------------------------------------------


def dispatch_sos_sms(
    sos: dict[str, Any], settings: SmsSettings | None = None
) -> dict[str, Any]:
    """Send the SOS alert SMS. Never raises.

    Returns a summary dict stored on the Firestore SOS document:

        {"provider": "fast2sms", "attempted": 2, "sent": 2,
         "recipient_count": 2, "results": [...], "sent_at": "..."}
    """
    settings = settings or get_sms_settings()

    recipients = collect_recipients(
        sos.get("emergency_contact_phone"),
        settings.control_room_numbers,
        default_country_code=settings.default_country_code,
    )

    if not recipients:
        logger.info("[sms] no recipients for SOS %s - no SMS request made.",
                    sos.get("sos_id"))
        return {
            "provider": settings.provider,
            "recipient_count": 0,
            "attempted": 0,
            "sent": 0,
            "results": [
                _result(
                    phone="-",
                    provider=settings.provider,
                    status="skipped",
                    detail="No recipients (ICE contact or control-room numbers "
                    "configured) - no SMS sent.",
                )
            ],
        }

    body = build_sos_message(
        user_name=sos.get("user_name"),
        user_phone=sos.get("user_phone"),
        sos_type=sos.get("sos_type"),
        message=sos.get("message"),
        latitude=sos.get("latitude"),
        longitude=sos.get("longitude"),
        created_at=sos.get("created_at"),
    )

    try:
        if settings.is_none:
            results = _send_none(recipients, body, settings)
        elif settings.is_fast2sms:
            results = _send_fast2sms(recipients, body, settings)
        elif settings.is_twilio:
            results = _send_twilio(recipients, body, settings)
        else:  # pragma: no cover - get_sms_settings() already validates
            results = [
                _result(
                    phone=phone,
                    provider=settings.provider,
                    status="skipped",
                    detail=f"Unsupported SMS provider '{settings.provider}'.",
                )
                for phone in recipients
            ]
    except Exception as exc:  # absolute safety net: never propagate
        detail = f"Unexpected SMS error: {type(exc).__name__}"
        logger.warning("[sms] %s", detail)
        results = [
            _result(phone=phone, provider=settings.provider, status="failed",
                    detail=detail)
            for phone in recipients
        ]

    # "sent" counts provider-confirmed deliveries only. Dev-mode ("none")
    # simulations remain status="simulated" and do not inflate the count.
    sent = sum(1 for r in results if r["status"] == "sent")

    from datetime import datetime, timezone

    return {
        "provider": settings.provider,
        "recipient_count": len(recipients),
        "attempted": len(results),
        "sent": sent,
        "results": results,
        "sent_at": datetime.now(timezone.utc).isoformat(),
        "message": body,
    }
