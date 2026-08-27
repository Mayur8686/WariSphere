# WariSathi 🚩 — Warkari Safety Companion (Flutter)

**वारकरांचा सोबती — सुरक्षित वारी, निश्चिंत यात्रा**

Member 1 deliverable: the Flutter mobile app everything a Warkari sees —
SOS, medical camps, lost & found, route info, QR pilgrim ID and profile.
**Offline-first**: every feature works with zero network; sync comes later.

---

## 1. App flow

```
Splash Screen
     ↓ (offline session restore)
Login / Register  ── (mock auth now · Firebase Auth in Phase 3)
     ↓
Home
  ├── SOS                  hold-2s → confirm → GPS capture → alert
  ├── Medical Camps        search/filter/call/directions
  ├── Lost Person          report lost/found + active reports
  ├── Route                Dehu/Alandi → Pandharpur timeline
  ├── My QR ID             scannable pilgrim ID (works offline)
  └── Profile              view/edit, logout
```

## 2. Quick start (from zero)

> 🪟 **Windows laptop?** Follow the step-by-step guide in [SETUP.md](SETUP.md).

1. **Install Flutter** (stable ≥ 3.27): https://docs.flutter.dev/get-started/install
2. From this `mobile/` folder:

```bash
flutter pub get
flutter run                # with a device/emulator connected
```

3. Platform folders (`android/`, `ios/`) are **already generated and
   pre-configured** — location permissions and dialer/maps intent filters
   are already in `AndroidManifest.xml` and `Info.plist`.

4. Log in with the demo account (shown on the login screen):

| Mobile     | Password  |
| ---------- | --------- |
| 9876543210 | wari123   |

…or register a fresh Wari ID from the app. Everything is stored on-device.

Verify quality gates:

```bash
flutter analyze   # 0 issues
flutter test      # smoke test passes
```

## 3. Project structure

```
lib/
├── main.dart                     entry point (initialises offline storage)
├── app.dart                      MaterialApp + theme + routes
├── core/
│   ├── di/app_bootstrap.dart     dependency wiring (swap mocks → Firebase here)
│   ├── constants/                app constants, strings (EN + MR)
│   ├── routes/                   named route table + auth guard
│   ├── theme/                    bhagwa-saffron design system
│   ├── services/
│   │   ├── auth_service.dart     interface + MockAuthService (→ FirebaseAuth)
│   │   ├── location_service.dart geolocator wrapper (GeoFix)
│   │   ├── sms_service.dart      emergency-SMS fallback to ICE contact
│   │   ├── storage_service.dart  offline persistence (shared_preferences)
│   │   ├── data_repository.dart  cache-first data door + seeded Wari data
│   │   └── notification_service.dart  stub (→ FCM in Phase 3)
│   └── utils/                    validators, formatters, geo helpers
├── models/                       AppUser, SosAlert, MedicalCamp,
│                                 LostPersonReport, WariRoute/RouteStop
├── state/                        providers (auth, sos, camps, lost, route)
├── widgets/                      reusable UI kit
└── screens/
    ├── splash/  auth/  home/
    ├── sos/     (screen + confirmation sheet + success view)
    ├── medical/ lost/  route/  qr/  profile/
```

## 4. How offline-first works today

| Data            | Where it lives now                                | Phase 3 target |
| --------------- | ------------------------------------------------- | -------------- |
| User profile    | `shared_preferences` (device)                     | Firestore `users` |
| SOS alerts      | device first → mock "server ack"                  | Firestore `sos_alerts` + FCM fan-out |
| Medical camps   | seeded sample set cached on device                | Firestore `medical_camps` (admin-managed) |
| Lost reports    | device + seeded community samples                 | Firestore `lost_reports` (live listener) |
| Wari route      | seeded, cached on device                          | Firestore `wari_route` |

Pending-sync items are badged **"Offline mode / pending sync"** in the UI so
nothing silently disappears.

## 5. Phase checklist (Member 1)

### Phase 1 — done ✅
- [x] Flutter project setup (pubspec, lints, structure)
- [x] App theme (saffron/maroon Material 3 design system)
- [x] Navigation (named routes + auth guard)
- [x] Home dashboard (all six features)
- [x] Login UI (validation, demo credentials)
- [x] Registration UI (Wari ID: personal + ICE + dindi + password)

### Phase 2 — done ✅
- [x] SOS screen (emergency-type chips, optional note)
- [x] SOS confirmation (5-second auto-send countdown, cancellable)
- [x] GPS location capture (graceful degradation without GPS)
- [x] Medical camp screen (search, filters, call, directions, distance)
- [x] Lost-person reporting screen (report + active list + mark reunited)
- [x] QR ID screen (QR pilgrim card, high-contrast toggle, payload copy)
- [x] **Bonus:** Emergency SMS fallback — after every SOS the app pre-fills an SMS
      to the ICE contact with a live Google Maps link (works with zero internet;
      toggle in Profile → Settings)

### Phase 3 — hooks ready 🔌
- [ ] **Firebase Authentication** → implement `FirebaseAuthService`, register it
      in `lib/core/di/app_bootstrap.dart` (search `TODO(Phase 3)`)
- [ ] **Firestore data** → swap `DataRepository` internals; keep the
      cache-first pattern (write local → queue → sync)
- [ ] **FCM notifications** → replace `StubNotificationService`;
      topic `wari-sos` fan-out to volunteers/admin
- [ ] **Offline queue drain** → `connectivity_plus` to push pending records

### Firebase setup steps (when Phase 3 starts)
```bash
dart pub global activate flutterfire_cli
flutterfire configure            # pick project + android/ios apps
flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging
```
Then follow every `TODO(Phase 3)` marker — screens and providers won't change.

## 6. Useful commands

```bash
flutter run                  # run on connected device
flutter run --release        # release-mode performance check
flutter build apk --release  # shareable APK for the team
flutter analyze              # static analysis (0 issues)
flutter test                 # widget smoke test
```

## 7. Notes for the team

- **Scanned QR payload format** (for whoever builds the volunteer scanner):
  `WARISATHI|<ID>|<NAME>|BG:<blood>|AGE:<age>|ICE:<emergency-phone>`
- Emergency numbers centralised in `AppConstants` (112 / 108 / 1091 / 1098).
- Sample camp & route data are **indicative** — the admin app (Member 2/3)
  becomes the source of truth in Phase 3.
- The SOS pipeline degrades gracefully: no GPS → alert still goes out and
  the UI shows the reason (permission / timeout / services off).
