# WariSphere — Volunteer Portal (React + Vite)

Field-volunteer portal: live task dispatches from the control room, task
lifecycle (accept → start → complete / reject / report issue), availability
management, task history and profile.

```bash
npm install
npm run dev        # http://127.0.0.1:5174 (proxies API calls to :8000)
```

* Sign-in uses **Firebase Authentication** with `role == "volunteer"` in
  `users/{uid}` (checked client-side via `GET /auth/me` and enforced by the
  backend on every endpoint). Accounts are **created by the authority** from
  the Authority Dashboard → Volunteers → *Create Volunteer* — there is no
  self-registration.
* New tasks arrive without manual refresh: the portal opens a Firestore
  listener on `tasks where assigned_to == <me>` and automatically falls back
  to REST polling in the backend's no-Firebase dev mode (`src/lib/live.js`).
  High-priority assignments raise an in-app **NEW EMERGENCY TASK** alert.

Demo login after `python backend/scripts/seed_demo_volunteers.py`:
`rahul.patil@warisphere.dev / Volunteer@123`.

System documentation: [`../docs/VOLUNTEER_SYSTEM.md`](../docs/VOLUNTEER_SYSTEM.md).
