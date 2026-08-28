import os

import firebase_admin
from firebase_admin import credentials, firestore


# The service-account JSON is deliberately git-ignored (it is a private key).
# Point FIREBASE_SERVICE_ACCOUNT_PATH at it, or drop the file next to this
# backend folder with the default name.
_SERVICE_KEY_PATH = os.environ.get(
    "FIREBASE_SERVICE_ACCOUNT_PATH", "firebase-service-account.json"
)

db = None  # type: ignore[assignment]


def _try_init() -> bool:
    """Initialise Firebase when a service-account key is available.

    Returns True when Firestore is ready. When the key is missing the API
    still boots (dev/CI mode) and endpoints reply with a clean 503 instead
    of crashing the process.
    """
    if not os.path.exists(_SERVICE_KEY_PATH):
        print(
            "[firebase] service account not found at "
            f"'{_SERVICE_KEY_PATH}' - running WITHOUT Firebase. "
            "Firestore-backed endpoints will return 503 until a key is added "
            "(see backend/README.md)."
        )
        return False
    if not firebase_admin._apps:
        cred = credentials.Certificate(_SERVICE_KEY_PATH)
        firebase_admin.initialize_app(cred)
    return True


firebase_ready = _try_init()

if firebase_ready:
    db = firestore.client()
