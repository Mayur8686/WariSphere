"""Pluggable server-side SMS gateway for SOS alerts.

Flow: `dispatch_sos_sms()` collects recipients (ICE contact + control-room
numbers), builds the emergency message and hands it to the configured
provider ("none" / "fast2sms" / "twilio"). It NEVER raises and never
logs credentials — failures come back as structured result records that
the SOS service stores on the Firestore document.
"""

from app.services.sms.gateway import dispatch_sos_sms
from app.services.sms.phone import collect_recipients, normalize_phone

__all__ = ["dispatch_sos_sms", "collect_recipients", "normalize_phone"]
