# WariSphere 🚩 — Warkari Safety Platform

**वारकरांचा सोबती — सुरक्षित वारी, निश्चिंत यात्रा**

WariSphere is the safety platform for Warkari pilgrims on the annual
**Dnyaneshwar Mauli (Alandi → Pandharpur) Wari**:

* **`mobile/`** — *WariSathi*, the Flutter app (Android/iOS/Web/desktop).
  SOS button, medical camps, lost & found, route timeline, QR pilgrim ID.
  **Offline-first**: everything works with zero network and syncs when
  connectivity returns.
* **`backend/`** — FastAPI service that stores SOS alerts and lost-person
  reports in **Firestore**, uploads photos to Firebase Storage, and now
  sends **automatic server-side SMS alerts** for every SOS.

---

## The automatic SOS SMS pipeline

```
Flutter App (hold SOS 2s)
      │  POST /sos  (user, GPS, note, ICE contact name + phone)
      ▼
FastAPI backend
      │
      ├─ 1. Validate request
      ├─ 2. Save the SOS document to Firestore  ◄── ALWAYS happens first
      │
      ├─ 3. Send SMS from the SERVER (pluggable gateway):
      │        • pilgrim's ICE / emergency contact
      │        • every SOS_CONTROL_ROOM_NUMBERS number
      │        providers: none (dev) · Fast2SMS (India) · Twilio
      │
      └─ 4. Record delivery results back on the Firestore SOS doc:
              { "sms": { "provider": "fast2sms",
                         "attempted": 2, "sent": 2, "results": [...] } }
```

**Critical guarantees:**

* The SOS is stored in Firestore **before** any SMS is attempted.
* An SMS failure **never** fails the API request or loses the alert — the
  failure is recorded in the document's `sms` block.
* If the provider is not configured (or there are no recipients), the
  backend makes **no HTTP request** — it records a clean `skipped` status.
* API keys/tokens are **never** logged or stored in Firestore.

### What the SMS contains

```
WariSphere SOS ALERT
Pilgrim in distress: Mayur Patil (call: 9876543210)
Type: medical
Emergency location: https://maps.google.com/?q=18.5204,73.8567
Note: Near Yavat toll naka, leg injury
Time (UTC): 2026-08-29 10:30:00
Please respond immediately. - WariSphere
```

### Recipients & number handling

* The pilgrim's ICE contact comes from the app profile
  (`emergency_contact_name` / `emergency_contact_phone` in `POST /sos`).
* Control-room numbers come from the backend environment variable
  `SOS_CONTROL_ROOM_NUMBERS` (comma-separated).
* Indian 10-digit numbers are expanded with `DEFAULT_COUNTRY_CODE`
  (default `+91`); E.164 numbers (`+91…`, `+1…`) are kept as-is.
* Recipients are **de-duplicated** (an ICE contact also listed in the
  control room gets one SMS). Missing ICE or missing control-room list
  both degrade gracefully; with no recipients at all, nothing is sent.

### The app-side `sms:` fallback still exists (mobile only)

The Flutter app's `sms:` deep link (pre-fills the OS SMS app with a Google
Maps link) remains as a **zero-internet / mobile fallback**. It is:

* **never auto-launched on Flutter Web** (browsers have no SMS app — the
  server-side SMS is the automatic mechanism there; the UI copies the
  text instead),
* only triggered on mobile when the user has "auto emergency SMS" enabled.

---

## Quick start

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env               # optional; defaults already work for dev
uvicorn app.main:app --reload
```

`SMS_PROVIDER=none` is the default: no SMS is sent, no external calls are
made — the backend logs/records what *would* have been sent. Drop a
Firebase `firebase-service-account.json` in `backend/` to enable
Firestore (see [`backend/README.md`](backend/README.md)); without it the
API still boots and `/sos` returns a clean 503.

### Mobile app

```bash
cd mobile
flutter pub get
flutter run                        # device/emulator; flutter run -d chrome for web
```

Point the app at your backend:

```bash
flutter run --dart-define=WARISATHI_API_URL=http://192.168.1.23:8000
```

(Chrome uses `http://localhost:8000` automatically.)

---

## SMS provider configuration

All configuration is via environment variables (see
[`backend/.env.example`](backend/.env.example)). **Never commit `.env`.**

| Variable                  | Purpose                                                   |
| ------------------------- | --------------------------------------------------------- |
| `SMS_PROVIDER`            | `none` (default/dev) · `fast2sms` · `twilio`              |
| `FAST2SMS_API_KEY`        | Fast2SMS Dev API authorization key                        |
| `FAST2SMS_SENDER_ID`      | Fast2SMS sender ID (default `FSTSMS`)                     |
| `TWILIO_ACCOUNT_SID`      | Twilio Account SID                                        |
| `TWILIO_AUTH_TOKEN`       | Twilio Auth Token                                         |
| `TWILIO_FROM_NUMBER`      | Twilio sender number, E.164 (e.g. `+14155550100`)         |
| `SOS_CONTROL_ROOM_NUMBERS`| Comma-separated numbers that receive **every** SOS SMS    |
| `DEFAULT_COUNTRY_CODE`    | Used to expand local 10-digit numbers (default `+91`)     |
| `SMS_TIMEOUT_SECONDS`     | HTTP timeout for SMS requests (default `10`)              |

### Fast2SMS (primary for India)

1. Create an account at <https://www.fast2sms.com> and copy the **Dev API
   authorization key** (Dashboard → Dev API).
2. Set `SMS_PROVIDER=fast2sms` and `FAST2SMS_API_KEY=<key>` in `backend/.env`.
3. Add control-room numbers: `SOS_CONTROL_ROOM_NUMBERS=9876500000,+919876500001`.

### Twilio (alternative / international)

1. Create a Twilio account and buy/enable an SMS-capable number.
2. Set `SMS_PROVIDER=twilio`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`
   and `TWILIO_FROM_NUMBER` (E.164) in `backend/.env`.

> ⚠️ **DLT / regulatory note (India):** bulk/transactional SMS to Indian
> numbers is regulated by TRAI via the **DLT (Distributed Ledger)**
> system. Production SMS to `+91` numbers requires a registered sender ID
> (header) and pre-approved message templates on the operator's DLT
> platform (Fast2SMS supports this from its dashboard), and Twilio
> requires an India regulatory setup for local traffic. The built-in
> message is a plain template you should register before going live.

---

## Testing a real SOS SMS

1. Backend: configure a provider, e.g. `SMS_PROVIDER=fast2sms` + a real
   `FAST2SMS_API_KEY`, and set `SOS_CONTROL_ROOM_NUMBERS` to a phone you
   control. Start `uvicorn app.main:app --reload`.
2. App: register/login with your own emergency (ICE) contact, then press
   and hold the SOS button for 2 seconds → confirm.
3. Or curl the API directly:

   ```bash
   curl -X POST http://localhost:8000/sos \
     -H "Content-Type: application/json" \
     -d '{"user_id":"WRI-TEST","latitude":18.5204,"longitude":73.8567,
          "sos_type":"medical","user_name":"Test Pilgrim","user_phone":"9876543210",
          "emergency_contact_name":"Test ICE","emergency_contact_phone":"9822011223"}'
   ```

4. Check the response (and the Firestore `sos_alerts` document) for the
   `sms.results` block — `sent` means the provider accepted the message.

Local/CI testing uses `SMS_PROVIDER=none` (no SMS sent, zero cost).

---

## Tests

See [`RUN_AND_TEST.md`](RUN_AND_TEST.md).

```bash
# backend (pytest, no Firebase/SMS account needed)
cd backend && python -m pytest tests/ -v

# mobile
cd mobile && flutter analyze && flutter test
```

## Security

* `.env`, `backend/firebase-service-account.json` and `backend/.venv/`
  are git-ignored and must never be committed.
* No API keys, auth tokens, or service credentials are hard-coded
  anywhere, logged, or stored in Firestore (the `sms.results` records
  contain only phone numbers, statuses and provider message IDs).
