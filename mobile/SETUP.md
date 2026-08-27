# WariSathi — Laptop Setup Guide (Windows-first)

Set up once in ~20 minutes, then `flutter run` forever.
Written for **Windows 10/11** (macOS/Linux notes at the bottom).

> Already have Android Studio + VS Code installed? You're most of the way —
> only **Step 1** (Flutter SDK) and **Step 3** (plugins) are new for you.

---

## Step 1 — Install the Flutter SDK

1. Download the **Windows zip** from
   <https://docs.flutter.dev/get-started/install/windows> (stable channel).
2. Extract it to a **simple path with no spaces** — recommended:
   `C:\dev\flutter`
   - ❌ not `C:\Program Files\...`
   - ❌ not inside OneDrive/Dropbox-synced folders
3. Add `C:\dev\flutter\bin` to your PATH:
   - Press `Win` → search **"Edit environment variables for your account"**
   - Under *User variables* → `Path` → **Edit** → **New** → `C:\dev\flutter\bin` → OK
4. Open a **new** PowerShell and verify:

```powershell
flutter --version
```

### Windows-specific (do once, saves hours)

```powershell
# Long paths — plugin build folders can exceed MAX_PATH
git config --global core.longpaths true

# (Optional but recommended) stop Defender slowing every build:
# Windows Security → Virus & threat protection → Exclusions → Add folder:
#   C:\dev\flutter  and your projects folder
```

## Step 2 — Run the doctor 🩺

```powershell
flutter doctor -v
```

Fix anything marked ✗ / !:

| Doctor says | Fix |
| --- | --- |
| "cmdline-tools component is missing" | Android Studio → **SDK Manager → SDK Tools** → tick **Android SDK Command-line Tools (latest)** → Apply |
| "Android licenses not accepted" | `flutter doctor --android-licenses` → accept all |
| "flutter plugin not installed" / "dart plugin" | Step 3 below |

Goal: ✅ Flutter · ✅ Android toolchain · ✅ VS Code / Android Studio.  
(Chrome & Visual Studio rows can stay unchecked — we're building Android.)

## Step 3 — IDE plugins

**Android Studio:** `Settings → Plugins → Marketplace` → install **Flutter** (it offers Dart — yes). Restart.

**VS Code:** Extensions (`Ctrl+Shift+X`) → install **Flutter** (publisher: Dart Code — auto-includes Dart). This repo also ships `.vscode/extensions.json`, so VS Code will offer these automatically on open.

## Step 4 — Clone & first run

```powershell
cd C:\dev                       # or wherever you keep projects
git clone https://github.com/Mayur8686/warisathi.git
cd warisathi\mobile

flutter pub get
flutter analyze                 # expect: No issues found!
flutter test                    # expect: All tests passed!
```

## Step 5 — Pick a device

### Option A — your Android phone (fastest, recommended)

1. **Settings → About phone → tap "Build number" 7×** (unlocks Developer options)
2. **Settings → Developer options → enable USB debugging**
   - Xiaomi/POCO (MIUI): also enable **"USB debugging (Security settings)"**
   - Realme/Oppo: may ask to sign in once before allowing it
3. Plug in via USB → set USB mode to **File transfer / MTP** if no prompt appears
4. Accept the "Allow USB debugging?" popup on the phone (tick *Always allow*)
5. Verify:

```powershell
flutter devices
```

### Option B — emulator

Android Studio → **Device Manager** (right panel) → **Create Device** →
Pixel 7, system image API 35 → Finish → ▶ start it → `flutter devices` again.

## Step 6 — Run! 🚀

```powershell
flutter run
```

- `r` in the terminal = hot reload · `R` = hot restart · `q` = quit
- **VS Code way:** open the `mobile` folder → `F5` (launch config included in this repo)
- Log in with `9876543210 / wari123`, or register a new Wari ID.
- Try the SOS flow — the emulator has a fake GPS; a real phone uses real GPS.

## Day-to-day workflow with the team

```powershell
git pull        # get code others (or the agent) pushed
# ...code, test...
git add -A && git commit -m "what you changed"
git push
```

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `flutter: command not found` / not recognized | PATH step (Step 1.3) — and **open a new terminal** |
| Build fails asking for huge RAM (`Xmx8G`) | Already fixed in the repo (`gradle.properties`) — make sure you pulled latest |
| Gradle/dependency download stalls | Corporate/college Wi-Fi blocking; try mobile hotspot |
| Phone shows "offline" in `flutter devices` | Re-plug, re-accept the debugging popup, try another USB cable/port |
| Emulator is slow | Enable virtualization in BIOS (Intel VT-x / AMD-V); or just test on a real phone |
| `Invocation failed ... Exit code 1` in Kotlin | `flutter clean && flutter pub get` then run again |

## macOS / Linux (for teammates)

1. Install Flutter per OS guide: <https://docs.flutter.dev/get-started/install>
   (`brew install --cask flutter` on macOS, snap/tarball on Linux — add `flutter/bin` to PATH, and on Linux also `sudo apt install clang cmake ninja-build pkg-config` if you'll target desktop later)
2. Same as Windows from **Step 2** onward.
3. Linux phone-debugging: create `/etc/udev/rules.d/51-android.rules` (search "android adb udev rules") so the phone is detected.
