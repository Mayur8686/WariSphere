# WariSphere Backend (FastAPI)

Powers WariSathi's cloud features (Phase 3): SOS alert intake → Firestore
**plus automatic server-side SMS alerts**, lost-person reports (+ photo
upload) → Firestore / Firebase Storage.

## Run locally (Windows PowerShell or any OS)

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1        # macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

Copy the environment template (optional — defaults already run in dev
mode) and fill in values as needed:

```bash
cp .env.example .env        # .env is git-ignored — never commit it
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

## Automatic server-side SOS SMS

When an SOS is created the backend **(1) writes the alert to Firestore
first**, then **(2) sends an emergency SMS from the server** and records
the delivery results on the same document:

```json
"sms": {
  "provider": "fast2sms",
  "recipient_count": 2,
  "attempted": 2,
  "sent": 2,
  "results": [
    {"phone": "+919822011223", "provider": "fast2sms",
     "status": "sent", "detail": "Fast2SMS accepted the message.",
     "http_status": 200, "message_id": "…"}
  ],
  "sent_at": "2026-08-29T10:30:00+00:00",
  "message": "WariSphere SOS ALERT\n…"
}
```

**Guarantees:** SMS failure never fails the SOS write (the alert is always
saved first); with no recipients or missing provider config **no HTTP
request** is made; API keys/tokens are never logged or stored in the
results.

### Recipients

1. The pilgrim's **ICE contact** — sent by the app as
   `emergency_contact_name` / `emergency_contact_phone`.
2. Every number in **`SOS_CONTROL_ROOM_NUMBERS`** — these receive *every*
   SOS SMS.

Indian 10-digit numbers are expanded with `DEFAULT_COUNTRY_CODE`
(default `+91`); E.164 numbers (`+91…`) are kept as-is; duplicates are
removed; invalid numbers are skipped. Missing ICE or an empty
control-room list both still work — only an empty recipient set is
skipped.

### Providers (env: `SMS_PROVIDER`)

| Provider    | Behaviour                                                                 |
| ----------- | ------------------------------------------------------------------------- |
| `none` *(default)* | Dev mode. No external HTTP request; logs/records what would be sent (`status: "simulated"`). |
| `fast2sms`  | India primary. POSTs to `https://www.fast2sms.com/dev/bulkV2` with `FAST2SMS_API_KEY` as the `authorization` header. |
| `twilio`    | Alternative. Uses HTTP basic auth (SID + token) against the Twilio Messages API; requires `TWILIO_FROM_NUMBER`. |

Unknown/missing config for the selected provider → every result is
recorded as `skipped` with an explanatory detail; the API still returns
200 and the SOS remains stored.

### Environment variables

See [`.env.example`](.env.example) for the full template:

| Variable                   | Meaning                                                     |
| -------------------------- | ----------------------------------------------------------- |
| `SMS_PROVIDER`             | `none` / `fast2sms` / `twilio`                              |
| `FAST2SMS_API_KEY`         | Fast2SMS Dev API key (secret — env/`.env` only)             |
| `FAST2SMS_SENDER_ID`       | Sender ID/header (default `FSTSMS`)                         |
| `TWILIO_ACCOUNT_SID`       | Twilio Account SID                                          |
| `TWILIO_AUTH_TOKEN`        | Twilio Auth Token (secret)                                  |
| `TWILIO_FROM_NUMBER`       | Twilio sender, E.164 (e.g. `+14155550100`)                  |
| `SOS_CONTROL_ROOM_NUMBERS` | Comma-separated control-room/help-desk numbers              |
| `DEFAULT_COUNTRY_CODE`     | Country code for local 10-digit numbers (default `+91`)     |
| `SMS_TIMEOUT_SECONDS`      | Provider HTTP timeout (default `10`)                        |

### Fast2SMS setup

1. Register at <https://www.fast2sms.com>; copy the **Dev API**
   authorization key (Dashboard → Dev API).
2. In `backend/.env`:

   ```env
   SMS_PROVIDER=fast2sms
   FAST2SMS_API_KEY=<your dev api key>
   FAST2SMS_SENDER_ID=FSTSMS
   SOS_CONTROL_ROOM_NUMBERS=9876500000
   DEFAULT_COUNTRY_CODE=+91
   ```

> ⚠️ **TRAI DLT requirement:** production SMS to Indian numbers needs a
> DLT-registered **sender ID (header)** and **message template** approved
> on your operator's DLT portal — Fast2SMS supports registering these in
> its dashboard. The alert text in `app/services/sms/message.py` is the
> template to submit for approval. Unregistered headers/templates are
> rejected by Indian carriers.

### Twilio setup

1. Create a Twilio account; grab the Account SID and Auth Token, and get
   an SMS-capable number.
2. In `backend/.env`:

   ```env
   SMS_PROVIDER=twilio
   TWILIO_ACCOUNT_SID=ACxxxxxxxx
   TWILIO_AUTH_TOKEN=xxxxxxxx
   TWILIO_FROM_NUMBER=+14155550100
   SOS_CONTROL_ROOM_NUMBERS=+919876500000
   ```

   (Twilio India messaging also has regulatory prerequisites — check
   Twilio's India SMS guidance before production.)

### Testing SMS locally

* **Zero-cost/CI:** leave `SMS_PROVIDER=none` — no SMS is sent; the
  document's `sms.results` contain `simulated` entries with the full
  message preview in the logs.
* **Real send:** set the provider credentials above (use your own number
  in `SOS_CONTROL_ROOM_NUMBERS`), start the API, then:

  ```bash
  curl -X POST http://localhost:8000/sos \
    -H "Content-Type: application/json" \
    -d '{"user_id":"WRI-TEST","latitude":18.5204,"longitude":73.8567,
         "sos_type":"medical","user_name":"Test Pilgrim",
         "emergency_contact_phone":"9822011223"}'
  ```

  The response's `sms.results` show `sent` / `failed` / `skipped` per
  recipient — no secrets are included.

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

### POST /sos body

```json
{
  "user_id": "WRI-ABC123",
  "latitude": 18.5204,
  "longitude": 73.8567,
  "sos_type": "medical",
  "message": "optional note",
  "user_name": "Mayur Patil",
  "user_phone": "9876543210",
  "accuracy_meters": 12.5,
  "emergency_contact_name": "Sunita Patil",
  "emergency_contact_phone": "9822011223"
}
```

Only `user_id` is required. `emergency_contact_*` come from the pilgrim's
app profile (ICE contact); `latitude`/`longitude` may be omitted when GPS
is unavailable — the alert and SMS still go out. The response includes
the stored record plus the `sms` delivery summary described above.

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

## Integration notes (for mobile ↔ backend, Phase 3)

The Flutter model (`lib/models/sos_alert.dart`) maps onto the API schema
(`app/schemas/sos.py`) via `ApiClient.buildSosPayload`:

| Flutter `SosAlert`                          | API `SOSCreate`/record         |
| ------------------------------------------- | ------------------------------ |
| `id` (`SOS-XXXXXX`, local)                  | `sos_id` (server uuid)         |
| `type`                                      | `sos_type` (default `general`) |
| `latitude/longitude`                        | `latitude/longitude`           |
| `note`                                      | `message`                      |
| `userName`, `userPhone`                     | `user_name`, `user_phone`      |
| `accuracyMeters`                            | `accuracy_meters`              |
| `emergencyContactName/Phone` (profile ICE)  | `emergency_contact_name/phone` → server-side SMS |

> Tip: `requirements.txt` must stay **UTF-8** — Windows PowerShell's `>`
> redirect saves UTF-16, which breaks `pip install` on Linux/CI. If regenerating,
> use `pip freeze | Out-File -Encoding utf8 requirements.txt`.
