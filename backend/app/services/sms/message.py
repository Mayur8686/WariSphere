"""Builds the emergency SOS SMS body.

Plain ASCII on purpose: it must survive every SMS gateway (Fast2SMS DLT
templates, Twilio) without emoji/encoding surprises. Kept short to stay
within a single SMS segment where possible.
"""

from __future__ import annotations

from datetime import datetime, timezone


def build_sos_message(
    *,
    user_name: str | None = None,
    user_phone: str | None = None,
    sos_type: str | None = None,
    message: str | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    created_at: datetime | None = None,
) -> str:
    """Compose the human-readable SOS text sent to every recipient."""
    lines = ["WariSphere SOS ALERT"]

    name = (user_name or "").strip()
    phone = (user_phone or "").strip()
    if name or phone:
        who = name or "A Warkari pilgrim"
        if phone:
            who = f"{who} (call: {phone})"
        lines.append(f"Pilgrim in distress: {who}")

    kind = (sos_type or "").strip()
    if kind and kind != "general":
        lines.append(f"Type: {kind}")

    if latitude is not None and longitude is not None:
        # Google Maps link with a PIN — opens directly to the alert location.
        lines.append(
            f"Emergency location: https://maps.google.com/?q={latitude},{longitude}"
        )
    else:
        lines.append("Emergency location: GPS unavailable - please call immediately.")

    note = (message or "").strip()
    if note:
        lines.append(f"Note: {note}")

    when = (created_at or datetime.now(timezone.utc)).astimezone(timezone.utc)
    lines.append(f"Time (UTC): {when.strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("Please respond immediately. - WariSphere")

    return "\n".join(lines)
