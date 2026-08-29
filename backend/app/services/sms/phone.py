"""Phone-number normalization and recipient collection for SOS alerts.

Indian 10-digit mobile numbers are expanded with the configured default
country code (DEFAULT_COUNTRY_CODE, e.g. +91). Numbers already in E.164
form (`+<country code><subscriber number>`) are kept as-is. Invalid
numbers return None and are skipped.
"""

from __future__ import annotations

import re

# Anything that isn't a digit or a leading plus is formatting noise
# (spaces, dashes, parentheses, a stray 00 international prefix, etc.).
_NON_DIGIT = re.compile(r"[^\d]")


def normalize_phone(raw: str | None, default_country_code: str = "+91") -> str | None:
    """Return the E.164 form of *raw*, or None when it cannot be a number.

    Examples (default country code +91):
        "9876543210"   -> "+919876543210"
        "09876543210"  -> "+919876543210"
        "+91 98765 43210" -> "+919876543210"
        "919876543210" -> "+919876543210"
        "+1 415 555 0100" -> "+14155550100"  (already E.164, kept)
        "12345"        -> None               (too short)
        ""             -> None
    """
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None

    cc = default_country_code.strip()
    if not cc.startswith("+"):
        cc = f"+{cc}"
    cc_digits = cc.lstrip("+")

    if text.startswith("+"):
        # Already in international (E.164-ish) form — keep as given.
        digits = _NON_DIGIT.sub("", text[1:])
        if len(digits) < 8:
            return None
        return f"+{digits}"

    digits = _NON_DIGIT.sub("", text)
    # Common "00" international prefix.
    if digits.startswith("00"):
        digits = digits[2:]
        if len(digits) >= 8:
            return f"+{digits}"
        return None
    # A domestic trunk prefix is not used for Indian mobiles, but strip a
    # single leading 0 just in case ("09876543210").
    if len(digits) == 11 and digits.startswith("0"):
        digits = digits[1:]

    if len(digits) == 10:
        return f"{cc}{digits}"
    if len(digits) == len(cc_digits) + 10 and digits.startswith(cc_digits):
        # e.g. "919876543210" with +91
        return f"+{digits}"
    if len(digits) >= 8:
        # Some other local number without country code — best effort.
        return f"{cc}{digits}"
    return None


def collect_recipients(
    emergency_contact_phone: str | None,
    control_room_numbers,
    default_country_code: str = "+91",
) -> list[str]:
    """Ordered, de-duplicated E.164 recipient list.

    The pilgrim's ICE contact comes first, then every configured
    control-room number. Invalid entries are silently skipped — a bad
    number must never block an emergency alert.
    """
    recipients: list[str] = []
    seen: set[str] = set()

    def _add(raw: str | None) -> None:
        normalized = normalize_phone(raw, default_country_code)
        if normalized and normalized not in seen:
            seen.add(normalized)
            recipients.append(normalized)

    _add(emergency_contact_phone)
    for number in control_room_numbers or ():
        _add(number)

    return recipients
