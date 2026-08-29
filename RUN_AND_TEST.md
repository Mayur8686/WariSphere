# Run & Test — WariSphere

How to run and verify the whole stack: FastAPI backend (with automatic
SOS SMS) + Flutter WariSathi app.

---

## 1. Backend (FastAPI)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate            # Windows: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env                 # optional; defaults work for dev
uvicorn app.main:app --reload        # http://localhost:8000
```

Useful endpoints: <http://localhost:8000/docs> (Swagger), `/health`,
`/firebase-health`.

### Firebase

Drop `backend/firebase-service-account.json` (git-ignored) to enable
Firestore. Without it the API still boots; `/sos` returns a clean 503
and lost-person features use the dev JSON/photo store.

### Run backend tests

```bash
cd backend
python -m pytest tests/ -v
```

All 50 tests run **without** Firebase or any SMS account — SMS providers
are tested with mocked HTTP, and `/sos` is tested against a fake
in-memory Firestore.

---

## 2. Testing the SMS flow locally (`SMS_PROVIDER=none`)

The default provider `none` makes **no external HTTP request** — nothing
is billed or sent. It logs what would be sent and records `simulated`
results on the Firestore document.

```bash
# .env (or environment)
SMS_PROVIDER=none
SOS_CONTROL_ROOM_NUMBERS=9876500000,+919876500001
DEFAULT_COUNTRY_CODE=+91
SMS_TIMEOUT_SECONDS=10
```

Fire an SOS (Firebase configured):

```bash
curl -X POST http://localhost:8000/sos \
  -H "Content-Type: application/json" \
  -d '{"user_id":"WRI-TEST","latitude":18.5204,"longitude":73.8567,
       "sos_type":"medical","user_name":"Test Pilgrim","user_phone":"9876543210",
       "emergency_contact_name":"Test ICE","emergency_contact_phone":"9822011223"}'
```

Expected: HTTP 200, and the JSON body contains an `sms` block like

```json
"sms": {
  "provider": "none",
  "recipient_count": 3,
  "attempted": 3,
  "sent": 0,
  "results": [ { "status": "simulated", "phone": "+919822011223", … } ],
  "message": "WariSphere SOS ALERT\n…"
}
```

(Recipients: the ICE number `9822011223` plus the two control-room
numbers; duplicates are removed automatically.)

### Misconfiguration / edge cases to try

* `SMS_PROVIDER=fast2sms` with a blank `FAST2SMS_API_KEY` → results are
  `skipped`, no HTTP request, still HTTP 200.
* No ICE contact and no `SOS_CONTROL_ROOM_NUMBERS` →
  `recipient_count: 0`, nothing sent.
* Bad gateway response / network error → results are `failed`, but the
  SOS document is still written (this is covered by tests).

---

## 3. Real SMS providers

### Fast2SMS (India)

1. Create an account at <https://www.fast2sms.com>, open **Dashboard →
   Dev API**, copy the authorization key.
2. Configure `backend/.env`:

   ```env
   SMS_PROVIDER=fast2sms
   FAST2SMS_API_KEY=<paste key here — never commit>
   FAST2SMS_SENDER_ID=FSTSMS
   SOS_CONTROL_ROOM_NUMBERS=<your own mobile for testing>
   ```

3. Restart uvicorn and fire an SOS. `sms.results[].status` will be
   `sent` when Fast2SMS accepts the request (HTTP 200,
   `return: true`).

> ⚠️ **Production in India requires DLT registration**: TRAI's DLT rules
> require a registered sender ID (header) and pre-approved message
> template on your operator's DLT platform. Register the alert template
> (see `app/services/sms/message.py`) before real-world use.

### Twilio

1. Sign up at <https://www.twilio.com>; get Account SID, Auth Token and
   an SMS-capable phone number.

   ```env
   SMS_PROVIDER=twilio
   TWILIO_ACCOUNT_SID=AC…
   TWILIO_AUTH_TOKEN=…
   TWILIO_FROM_NUMBER=+14155550100
   SOS_CONTROL_ROOM_NUMBERS=+919876500000
   ```

2. Restart uvicorn and fire an SOS. Each recipient gets one Twilio
   Messages API call; results contain the Twilio message SID on success.

---

## 4. Mobile app (Flutter)

```bash
cd mobile
flutter pub get
flutter run                     # device/emulator
flutter run -d chrome           # web build
# point at a LAN/remote backend:
flutter run --dart-define=WARISATHI_API_URL=http://192.168.1.23:8000
```

SOS flow: register/login with an emergency (ICE) contact → SOS screen →
pick a type → **hold the button 2 seconds** → confirm. The app:

1. writes the alert locally first (offline-first),
2. `POST /sos` to the backend with the ICE contact + GPS fix — the
   server sends SMS automatically (works on web too),
3. on mobile/offline, keeps the `sms:` deep-link as a fallback
   (never auto-launched on web; web copies the message text instead).

### Analyze & test

```bash
cd mobile
flutter analyze
flutter test
```

`test/api_client_test.dart` verifies the SOS payload includes the ICE
fields; `test/ice_sms_test.dart` covers the fallback SMS message;
`test/lost_report_sync_test.dart` and the smoke/widget tests cover the
rest of the offline-first sync flow.

---

## 5. Security checklist

* `.env`, `firebase-service-account.json`, `.venv/` are git-ignored.
* No credentials are hard-coded; logs print provider/message details
  only — never keys or tokens; `sms.results` stores no secrets.
