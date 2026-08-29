# WariSphere — Volunteer Management & Volunteer Dashboard

Role-based volunteer system built **into** the existing architecture
(FastAPI + Firebase, React + Vite Authority Dashboard, Flutter app).
Nothing is rebuilt: the SOS / Lost Person / Medical Camp modules keep
working exactly as before, and the task engine links to the existing
Firestore records instead of duplicating them.

```
Flutter User ──SOS──▶ FastAPI/Firestore ──▶ Authority Dashboard
                                                │ assign volunteer
                                                ▼
                                        Volunteer Portal
                                                │ accept → start → complete
                                                ▼
                              Authority Dashboard (SOS → RESOLVED, response time)
```

---

## 1. Files created

### Backend (`backend/`)

| File | Purpose |
| ---- | ------- |
| `app/schemas/volunteer.py` | Volunteer payloads + account/availability enums |
| `app/schemas/task.py` | Central task schema, priorities, **state-transition table** |
| `app/services/local_store.py` | Shared JSON dev store (`backend/data/*.json`, RLock-safe) |
| `app/services/users.py` | `users/{uid}` role store + Firebase Auth account creation |
| `app/services/auth.py` | Firebase-ID-token verification, role dependencies, dev tokens |
| `app/services/volunteers.py` | Volunteer profile CRUD, availability/status axes |
| `app/services/tasks.py` | **Task engine**: lifecycle, assignment, SOS sync, volunteer counters |
| `app/routes/auth.py` | `GET /auth/me`, `POST /auth/dev-session` (dev only) |
| `app/routes/volunteers.py` | Volunteer management APIs |
| `app/routes/tasks.py` | Task APIs |
| `scripts/create_authority.py` | Provision an authority account (Auth + users doc) |
| `scripts/seed_demo_volunteers.py` | Idempotent demo seed: authority + 3 volunteers + 3 SOS alerts |
| `tests/test_volunteers_tasks.py` | 14 end-to-end tests (roles, lifecycle, guards, SOS sync) |

### Authority dashboard (`dashboard/`)

| File | Purpose |
| ---- | ------- |
| `src/lib/session.js` | Firebase Auth login + role gate + dev fallback, token plumbing |
| `src/lib/live.js` | `useLiveCollection` — Firestore `onSnapshot` with REST-polling fallback |
| `src/lib/medicalCamps.js` | Existing camp directory extracted + `nearestCamp()` (Haversine) |
| `src/components/tasks/badges.jsx` | Shared status language (priority, task/SOS status, availability) |
| `src/components/tasks/AssignVolunteerModal.jsx` | Assign / re-assign picker |
| `src/components/volunteers/CreateVolunteerModal.jsx` | Account creation + credentials handover |
| `src/components/volunteers/VolunteerDetails.jsx` | Profile drawer: status, availability bucket, history, suspend/reactivate |

### Volunteer portal (`volunteer-dashboard/`) — new app

Vite + React 19 + Tailwind v4, same design system and Firebase project.
`src/lib/{session,api,live}.js` mirror the authority client; components:
`Login`, `Portal` (sidebar shell + new-task toast), `HomeDashboard`,
`TaskCard` (full lifecycle buttons), `TaskNoteModal` (complete/reject/report-issue),
`TaskHistory` (Active/Completed/All tabs), `AvailabilityPanel`, `ProfilePanel`.

### Docs / config

`firestore.rules` (production read/write lock-down), this doc, README updates.

## 2. Files modified

| File | Change |
| ---- | ------ |
| `backend/app/main.py` | Registered auth/volunteers/tasks routers |
| `backend/app/services/sos.py` | Local dev fallback + `get/list/update_sos_*` (Firestore create path untouched) |
| `backend/app/routes/sos.py` | `GET /sos`, `GET /sos/{id}`, authority `PATCH /sos/{id}/status` |
| `backend/README.md` | Auth/roles section, endpoint table, dev-mode notes |
| `dashboard/src/firebase.js` | Also exports `app` (for Auth) |
| `dashboard/src/lib/api.js` | Bearer token on every request + volunteer/task/SOS helpers |
| `dashboard/src/components/Login.jsx` | Real Firebase sign-in (authority role gate) + demo autofill |
| `dashboard/src/App.jsx` | Session restore/guard, unauthorized bounce, wrong-portal screen |
| `dashboard/src/components/Dashboard.jsx` | Live header stats, authority name from session |
| `dashboard/src/components/modules/Volunteers.jsx` | Replaced hardcoded directory with full management view |
| `dashboard/src/components/modules/ActiveSOS.jsx` | Queue/Dispatched/Resolved tabs, assign/reassign/resolve, response time |
| `dashboard/src/components/modules/LostPersons.jsx` | **Additive**: assign-volunteer from a report + dispatch chip |
| `dashboard/src/components/modules/MedicalCamps.jsx` | Camp data now imported from `lib/medicalCamps.js` (same records) |
| `dashboard/vite.config.js` | Proxy `/volunteers`, `/tasks`, `/auth` → FastAPI |
| `dashboard/index.html` | Title |

Not touched: Flutter app, face-matching pipeline, LiveCrowd/Routes/Alerts modules,
`POST /sos` intake contract, lost-person endpoints.

## 3. Firestore schema changes

New collections (existing ones only gain fields — nothing is renamed):

### `users/{uid}` — one doc per login

```json
{ "uid": "…", "name": "Rahul Patil", "email": "…", "phone": "…",
  "role": "authority | volunteer", "status": "active",
  "created_by": "<authority uid>", "created_at": "…", "updated_at": "…" }
```

### `volunteers/{uid}` — operational profile (same id as the Auth user)

```json
{ "id": "<uid>", "uid": "<uid>", "name": "…", "email": "…", "phone": "…",
  "emergency_contact": "…", "role": "volunteer",
  "status": "active | inactive | suspended",
  "availability": "available | busy | offline",
  "zone": "Sector A - Alandi", "skills": ["first_aid", "crowd_management"],
  "current_task_id": null, "tasks_completed": 0, "tasks_active": 0,
  "created_by": "<authority uid>", "created_by_name": "…",
  "created_at": "…", "updated_at": "…", "last_active_at": "…" }
```

### `tasks/{task_id}` — one central model for every dispatch

```json
{ "id": "…", "task_id": "…", "type": "sos | lost_person | medical_assistance | crowd_assistance | route_assistance | general",
  "title": "Medical Emergency — Sujal Bergal", "description": "…",
  "priority": "low | medium | high | critical",
  "status": "assigned | accepted | in_progress | completed | rejected | cancelled | unable_to_complete",
  "created_at": "…", "created_by": "<authority uid>", "created_by_name": "…",
  "assigned_to": "<volunteer uid>", "assigned_volunteer_name": "…",
  "assigned_by": "<authority uid>", "assigned_at": "…",
  "source_kind": "sos | lost_person | medical_camp | manual", "source_id": "<existing record id>",
  "location": { "latitude": 18.52, "longitude": 73.85, "address": "Near MMCOE" },
  "incident": { "person_name": "…", "person_phone": "…", "details": "…", "photo_url": "…", "medical_camp": { … } },
  "accepted_at": null, "started_at": null, "completed_at": null, "cancelled_at": null,
  "completion_note": null, "resolution_note": null, "response_seconds": null,
  "history": [ { "status": "assigned", "at": "…", "by": "…", "by_name": "…", "note": "…" } ] }
```

`incident` is a **read-only snapshot** so the volunteer sees only the details
of the task they were assigned — no broad read access to `sos_alerts` /
`lost_persons` is needed.

### `sos_alerts/{sos_id}` — extended, not duplicated

Added fields (written by the backend when a task references the alert):
`task_id`, `assigned_to`, `assigned_volunteer_name`, `assigned_at`,
`resolved_at`, `response_seconds`. Status flow:

```
active ─assign→ assigned ─accept→ accepted ─start→ in_progress ─complete→ resolved
   ▲            └── reject / unable / cancel / authority-reopen ──┘
```

### Lost persons & medical camps

No new records: a lost-person task carries `source_kind="lost_person"` +
`source_id=<lost_person_id>`; a volunteer **cannot** mark a person
found/reunited — that stays an authority decision (existing AI match +
status endpoints). Camp data stays in the existing directory and is *referenced*
(nearest camp embedded on medical tasks), never copied.

## 4. Firebase Authentication changes

* One Firebase project, one auth system: email/password users are created by
  the backend Admin SDK (`auth.create_user`) when an authority creates a
  volunteer — no service-account material ever reaches the React apps.
* The backend verifies `Authorization: Bearer <idToken>` on every protected
  call and reads the role from `users/{uid}` (the project's role store) — role
  changes take effect immediately; no custom-claim minting.
* Portal role gates: Authority Dashboard requires `role == "authority"`,
  Volunteer Portal requires `role == "volunteer"` — enforced **both** client-side
  (route guard + `GET /auth/me`) and server-side (dependency on every endpoint).
* Recommended next console step: `firebase deploy --only firestore:rules`
  using the shipped `firestore.rules` (clients get zero write access; reads
  limited to what each portal's listeners need).

## 5. Environment variables

No new **required** variables. Existing behavior preserved:

| Variable | Effect |
| -------- | ------ |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Path to the Admin SDK key (existing) |
| `VITE_API_BASE` | API origin when dashboards aren't served through the Vite proxy |
| `WARISPHERE_DATA_DIR` | Local dev-store directory (tests use it) |
| `VITE_AUTHORITY_TOKEN` / `WARISPHERE_AUTHORITY_TOKEN` | Existing optional face-match gate |

## 6. Running everything

```bash
# 1) Backend  (http://127.0.0.1:8000)
cd backend
python -m venv .venv && . .venv/bin/activate   # Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# 2) Demo data (idempotent): authority + 3 volunteers + 3 SOS alerts (+ 3 missing persons)
python scripts/seed_demo_volunteers.py
python scripts/seed_demo_missing.py     # existing script, optional

# 3) Authority Dashboard  (http://127.0.0.1:5173)
cd dashboard && npm install && npm run dev

# 4) Volunteer Portal  (http://127.0.0.1:5174)
cd volunteer-dashboard && npm install && npm run dev
```

## 7. Test credentials

Dev mode (backend without a service-account key), produced by the seed script:

| Role | Email | Password |
| ---- | ----- | -------- |
| Authority | `authority@warisphere.dev` | `Authority@123` |
| Volunteer (Rahul Patil) | `rahul.patil@warisphere.dev` | `Volunteer@123` |
| Volunteer (Om Shinde) | `om.shinde@warisphere.dev` | `Volunteer@123` |
| Volunteer (Sugal More) | `sugal.more@warisphere.dev` | `Volunteer@123` |

Production (Firebase configured):

```bash
python scripts/create_authority.py --email you@org.in --password '<pick-one>' --name "Control Room"
# volunteers are created from the Authority Dashboard → Volunteers → + Create Volunteer
```

## 8. Complete demo steps

1. Backend + seed + both dashboards running (above). Open the **Authority
   Dashboard** → sign in as the authority. Header shows **Active Alerts: 3**.
2. **Active SOS** → *Needs Response* shows e.g. **Medical Emergency — Sujal
   Bergal, Near MMCOE, HIGH-style alert card**.
3. Click **Assign Volunteer** → the modal lists only *available* volunteers
   (Rahul Patil — First Aid; Om Shinde — Crowd Management; Sugal More — Lost
   Person Assistance) → pick **Rahul Patil** → Assign. Card flips to
   *“Dispatched to Rahul Patil”* with the progress stepper; Rahul turns **busy**
   in Volunteers automatically.
4. Open the **Volunteer Portal** (5174) → sign in as Rahul. A red **NEW
   EMERGENCY TASK** toast appears (real-time) and the task card shows the SOS
   details, person, location with a Navigate link and the nearest medical camp.
5. Rahul: **ACCEPT TASK** (→ *accepted*) — the authority card moves instantly;
   **START TASK** (→ *in progress*); **COMPLETE TASK** with note
   *“Person assisted and handed over to medical team.”*
6. Authority side (no refresh): SOS shows **Resolved · responded in X mins**,
   Rahul is back to **available**, `tasks_completed` is 1, and the task appears
   in Rahul's **Task History → Completed**.
7. Extras to show: **Lost Persons → Assign Volunteer** on a missing report;
   drain a volunteer (**reject** → control room re-assigns); **suspend** a
   volunteer in the details drawer (their next API call/login is rejected);
   availability toggles in the Volunteer Portal.

## 9. Security summary

* Every protected endpoint resolves a **Principal** from the Bearer token and
  re-checks role + ownership (`assigned_to == caller`) server-side. Cross-role
  or cross-volunteer calls return 403 (tested).
* Invalid task transitions impossible (`TASK_TRANSITIONS` table, HTTP 409):
  e.g. `completed → accepted`, `start before accept`, assign to busy/offline.
* Volunteers can patch only `{phone, emergency_contact, zone}` on their own
  profile; role/ownership/counters are not editable fields at all.
* One open task per incident (409 with a pointer to the existing task).
* DEV tokens (`dev:<uid>`) work only while the backend has **no** Firebase key;
  `POST /auth/dev-session` returns 403 as soon as one is configured.

## 10. Testing

```bash
cd backend && python -m pytest tests/ -v    # 35 tests (21 pre-existing + 14 new)
```

Covered: dev login/auth guards, volunteer CRUD + safe-field limits, full
SOS→task→resolved sync, invalid transitions, cross-volunteer blocks,
busy/offline assignment guards, reject→reassign, unable-to-complete, cancel,
authority direct resolve (cancels open task + frees volunteer), lost-person
snapshot, summary stats, legacy SOS intake compatibility.

Frontend verified: `npm run build` + `npm run lint` (both dashboards; 0 errors).

## 11. Remaining limitations

1. **FCM push notifications** — the mobile app uses a local notification
   service; FCM isn't wired anywhere in the project yet. The volunteer portal
   therefore notifies **in-app** (real-time listener → toast + badges), which
   covers the demo; documented as the next step (store FCM tokens on
   `users/{uid}`, send from the backend on task creation).
2. **Firestore rules deployment** is a manual one-time console step. The
   portals handle locked-down/absent rules gracefully by falling back to REST
   polling (see `lib/live.js`).
3. Dev mode keeps dev passwords in `backend/data/users.json` (git-ignored) —
   acceptable for the no-Firebase demo path, unreachable in production mode.
4. Task photos/evidence on completion: the note text is stored; photo upload
   can reuse `POST /lost-person/photo`-style storage later.
5. Crowd/route/live-map panels remain the pre-existing static modules — out of
   scope for this feature.
