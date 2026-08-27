# WariSphere Backend (FastAPI)

Powers WariSathi's cloud features (Phase 3): SOS alert intake → Firestore.

## Run locally (Windows PowerShell or any OS)

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1        # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

Put your Firebase **service account** JSON at `backend/firebase-service-account.json`
(Firebase console → Project settings → Service accounts → Generate new private key).
It is git-ignored — never commit it.

> **No Firebase project yet?** The API still boots without the key (dev mode):
> `POST /sos` replies with a clean **503 "Firebase not configured"** and
> `/firebase-health` explains what's missing, instead of crashing. Add the key
> later — no code change needed. You can also point at a key anywhere via the
> `FIREBASE_SERVICE_ACCOUNT_PATH` environment variable.

```powershell
uvicorn app.main:app --reload
```

## Endpoints

| Method | Path              | Purpose                                  |
| ------ | ----------------- | ---------------------------------------- |
| GET    | `/`               | Liveness                                 |
| GET    | `/health`         | Health probe                             |
| GET    | `/firebase-health`| Verifies Firestore connectivity          |
| POST   | `/sos`            | Create SOS alert → `sos_alerts` collection |

### POST /sos body

```json
{
  "user_id": "WRI-ABC123",
  "latitude": 18.5204,
  "longitude": 73.8567,
  "sos_type": "medical",
  "message": "optional note"
}
```

## Integration notes (for mobile ↔ backend, Phase 3)

Field mapping differs from the Flutter model (`lib/models/sos_alert.dart`) —
align before wiring:

| Flutter `SosAlert`        | API `SOSCreate`/record        |
| ------------------------- | ----------------------------- |
| `id` (`SOS-XXXXXX`)       | `sos_id` (uuid)               |
| `type`                    | `sos_type` (default `general`)| 
| `latitude/longitude`      | `latitude/longitude` ✅       |
| `note`                    | `message`                     |
| `userName`, `userPhone`   | ❌ not accepted yet           |
| `accuracyMeters`          | ❌ not accepted yet           |

> Tip: `requirements.txt` must stay **UTF-8** — Windows PowerShell's `>`
> redirect saves UTF-16, which breaks `pip install` on Linux/CI. If regenerating,
> use `pip freeze | Out-File -Encoding utf8 requirements.txt`.
