# WariSphere — Authority Dashboard (React + Vite)

Control-room portal for **authority** accounts: live SOS dispatch, lost-person
reports (+ AI face matching), medical camps, volunteer management, routes and
alerts.

```bash
npm install
npm run dev        # http://127.0.0.1:5173 (proxies API calls to :8000)
```

* Sign-in uses **Firebase Authentication**; the caller must have
  `role == "authority"` in `users/{uid}` (enforced client-side and by the
  backend on every API call). Provision accounts with
  `python backend/scripts/create_authority.py` (or run
  `scripts/seed_demo_volunteers.py` in dev mode for
  `authority@warisphere.dev / Authority@123`).
* Real-time views subscribe to Firestore (`sos_alerts`, `volunteers`,
  `tasks`) and fall back to gentle REST polling when the backend runs in
  no-Firebase dev mode or rules deny the listener (`src/lib/live.js`).

Volunteer tasking system documentation: [`../docs/VOLUNTEER_SYSTEM.md`](../docs/VOLUNTEER_SYSTEM.md).
API reference: [`../backend/README.md`](../backend/README.md).
