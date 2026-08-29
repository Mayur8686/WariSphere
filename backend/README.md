# WariSphere Backend (FastAPI)

Powers WariSathi's cloud features (Phase 3): SOS alert intake → Firestore,
lost-person reports (+ photo upload) → Firestore / Firebase Storage.

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

| Method | Path                              | Purpose                                        |
| ------ | --------------------------------- | ---------------------------------------------- |
| GET    | `/`                               | Liveness                                       |
| GET    | `/health`                         | Health probe                                   |
| GET    | `/firebase-health`                | Verifies Firestore connectivity                |
| POST   | `/sos`                            | Create SOS alert → `sos_alerts` collection     |
| POST   | `/lost-person`                    | Store a lost/found person report               |
| POST   | `/lost-person/photo`              | Upload the person's photo (multipart) → URL    |
| GET    | `/lost-person`                    | List reports, newest first (`?limit&status&report_type`) |
| PATCH  | `/lost-person/{id}/status`        | Mark a report `missing`/`found`/`reunited`     |
| POST   | `/lost-person/scan-match`         | AI face scan of a found-person photo (probable matches only) |
| POST   | `/lost-person/matches/{id}/confirm` | Authority confirms a proposed match          |
| POST   | `/lost-person/matches/{id}/reject`  | Authority rejects a proposed match           |
| GET    | `/lost-person/face-match/status`  | InsightFace model readiness + thresholds       |

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

## Lost-person reports (Phase 3)

### 1. Upload the photo first (optional)

```bash
curl -F "file=@person.jpg" -F "client_report_id=LP-4KD9F2" \
     http://localhost:8000/lost-person/photo
# → { "photo_url": "https://…/lost_persons/LP-4KD9F2-a1b2c3d4.jpg",
#     "stored_in": "firebase-storage" | "local-disk" }
```

* JPEG / PNG / WebP, ≤ 8 MB — the type is verified from the file's magic
  bytes, not the client's claim.
* Firebase Storage when configured; otherwise the photo is written to
  `backend/uploads/lost_persons/` and served at `/uploads/lost_persons/…`
  (dev mode).

### 2. Store the details

```json
POST /lost-person
{
  "client_report_id": "LP-4KD9F2",
  "report_type": "lost",
  "name": "Rambhau Kedari",
  "age": 68,
  "gender": "Male",
  "description": "White kurta, orange topi, walks with a stick.",
  "last_seen_location": "Near Yavat toll naka",
  "last_seen_time": "2026-08-28T18:30:00Z",
  "last_seen_latitude": 18.3712,
  "last_seen_longitude": 74.2671,
  "photo_url": "…from step 1…",
  "reporter_id": "WRI-ABC123",
  "reporter_name": "Demo Warkari",
  "reporter_phone": "9876543210"
}
```

Only `name` is required. `client_report_id` makes retries idempotent —
resubmitting the same app-side ID returns the existing record with
`"duplicate": true` instead of creating a copy.

### Where the data lives

* **Firebase configured** → Firestore collection `lost_persons`, photos in
  Firebase Storage under `lost_persons/`.
* **No key yet (dev/CI)** → records go to `backend/data/lost_persons.json`
  and photos to `backend/uploads/` so the whole flow works before the
  Firebase project exists. Every response marks which store was used in
  `stored_in`, and adding the service-account key later switches to
  Firestore automatically — no code change. (Unlike `/sos`, these endpoints
  do **not** 503 in dev mode.)

## AI face matching (authority dashboard)

See **[docs/AI_FACE_MATCHING.md](../docs/AI_FACE_MATCHING.md)** for the full
write-up (endpoints, schema, env vars, demo steps, limitations).

Short version: `POST /lost-person/scan-match` with a found-person photo
returns ranked *probable* matches against active missing persons. Confirm
and reject are separate authority actions — the API never marks someone
found just because the model produced a score.

```bash
python scripts/seed_demo_missing.py   # Sujal Bergal + 2 others
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
