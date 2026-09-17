# Hopper — setup for a Mac, an iPhone and a Samsung phone

This is the shortest path from the zip file to a working clipboard between your three devices.

## What works where (v0.2)

| | Mac | Samsung (Android) | iPhone |
|---|---|---|---|
| Receive automatically | ✅ | ✅ always (foreground service, survives closing the app and reboots) | ⚠️ while Hopper is open |
| Send automatically | ✅ everything you copy | ✅ after the one-time USB setup below (Android blocks it otherwise) | ❌ iOS blocks it for every app — use Universal Clipboard for iPhone ↔ Mac, or open Hopper (opening = send) |
| Text, links, images | ✅ | ✅ | ✅ |
| Files | ✅ copy in Finder → arrives in the phone's Downloads/Hopper; received files land in ~/Downloads/Hopper and are on the clipboard for ⌘V in Finder | ✅ receive to Downloads/Hopper; send via Share → Hopper | ✅ receive into the Files app (On My iPhone → Hopper) |
| Pair by QR / 6-digit code | ✅ | ✅ | ✅ |

The Mac is the hub: it sends everything automatically and receives from both phones with no app open on the phone side.

---

## Samsung: one-time setup for automatic sending (2 minutes)

Android 10+ does not let any app read the clipboard in the background. Hopper uses the same trick KDE Connect uses: a permission the phone's owner grants once over USB, after which Hopper notices every copy instantly and grabs it through an invisible one-frame window.

1. On the phone: **Settings → About phone → Software information → tap "Build number" 7 times**, then **Settings → Developer options → USB debugging → on**.
2. Plug the phone into the Mac with a cable. Tap **Allow** on the phone when it asks about USB debugging.
3. In Terminal, in the Hopper folder:
   ```bash
   tool/android-setup.sh
   ```
   It installs the APK if needed, grants the two permissions, exempts Hopper from battery optimisation and restarts it.
4. Open Hopper on the phone: the **"Finish automatic sync setup"** card on Home should turn green ("Automatic sync is on"). If "Appear on top" is not ticked, tap *Open* and switch it on.

**After every reboot, open Hopper once and tap "Allow one-time access".** A few seconds after Hopper opens, Android shows *"Allow Hopper to access all device logs?"* — that is the OS asking, once per boot, for the permission that lets Hopper notice you copied something. Tap **Allow one-time access**. (Swiping the dialog away counts as *Don't allow*; Hopper asks again next time you open it.) Until then the sync notification says *"Automatic capture paused — open Hopper once"*; receiving from the Mac keeps working regardless.

Test: copy any text on the phone, then ⌘V on the Mac. Android shows its own small "Hopper pasted from clipboard" toast each time — that is the OS, and it cannot be hidden.

---

## Step 1 — Build on your Mac (once, ~20 min the first time)

Everything except Xcode is already set up on this Mac (Flutter in `~/flutter`, Java, the Android SDK and CocoaPods via Homebrew — see `docs/BUILD.md` §0a). One script builds all three targets:

```bash
tool/build.sh android    # → dist/hopper-arm64-v8a-release.apk   (Samsung)
tool/build.sh macos      # → dist/Hopper.app                      (needs Xcode)
tool/build.sh ios        # → build/ios/iphoneos/Runner.app        (needs Xcode + your Apple ID team)
```

**Xcode** is the one thing to install by hand: Mac App Store → Xcode (free, ~12 GB), then in Terminal
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```
The script checks for it and prints these same steps if it is missing.

## Step 2 — Run it on the Mac

```bash
tool/build.sh macos
open dist/Hopper.app
```
Drag `Hopper.app` to Applications if you like. First launch: **right‑click → Open** (it's unsigned). Allow **Local Network** access when macOS asks — without it the Mac can't see the phones.

Go through the welcome tour (or Skip), name the Mac, and you're on the Home tab. Hopper also sits in the **menu bar**; closing the window keeps it running.

## Step 3 — Install on the Samsung

**Option A — APK (fastest):** copy `dist/hopper-arm64-v8a-release.apk` to the phone (AirDrop doesn't work to Android; use a cable, Google Drive, or `adb install`). Open it, allow *install from unknown sources*.

**Option B — build yourself:** enable *Developer options → USB debugging* on the phone, plug it in, then
```bash
flutter devices                       # find the Samsung's id
flutter run -d <id> --release         # or: flutter build apk --release
```

Then on the Samsung: **Settings → Apps → Hopper → Battery → Unrestricted**, otherwise One UI may kill it in the background and clips from the Mac stop arriving.

## Step 4 — Install on the iPhone

iOS apps must be signed by Apple, so this needs Xcode and a free Apple ID (no paid developer account required for your own devices).

1. Plug the iPhone into the Mac, unlock it, and trust the computer.
2. `open ios/Runner.xcworkspace` → select the **Runner** target → **Signing & Capabilities** → tick *Automatically manage signing* → choose your Team (your Apple ID). Change the bundle identifier if Xcode complains it's taken (e.g. `app.hopper.yourname`).
3. Back in Terminal:
   ```bash
   tool/build.sh ios
   ~/flutter/bin/flutter devices            # find the iPhone's id
   ~/flutter/bin/flutter run -d <iphone-id> --release
   ```
4. On the iPhone: **Settings → General → VPN & Device Management → trust your developer certificate**, then open Hopper. Allow **Local Network** and **Camera** when asked.

Free Apple IDs sign apps for **7 days**; re‑run step 3 to refresh. A paid developer account (US$99/yr) removes that limit and lets you use TestFlight.

## Step 5 — Pair

1. Mac: **Devices → Pair device → Show code**.
2. Samsung: **Devices → Pair device** → scan the Mac's QR. Confirm the 4 emoji match on both → Done.
3. Repeat for the iPhone.

Each phone shows up as a card in the Mac's **Devices** tab. Tap a card to set its direction — the default is Two‑way.

## Step 6 — Daily use

- **Mac → phone:** just copy on the Mac. Long‑press → Paste on the phone.
- **Samsung → Mac:** copy, then either open Hopper and tap **Send**, or select text → **Share → Hopper** (no need to open the app).
- **iPhone → Mac:** copy, open Hopper, tap **Send**. (A Share‑Sheet extension for iOS is the next item on the roadmap.)
- **Images:** screenshots on the Mac land on the phones; screenshots on a phone go via Share → Hopper (Samsung) or Send (iPhone).


### Good to know
- The same content copied again within 10 minutes is not re-sent (that is how Hopper avoids ping-pong loops). Copy it again later and it goes through.
- Something that looks like a password, one-time code or card number is held back; the phone shows a notification with **Send once**, the Mac shows a sheet. Turn the guard off in Settings if you don't want that.
- Samsung's *My Files* "Copy" uses its own clipboard that apps cannot see. To send a file from the phone use **Share → Hopper**. Copying an image in Chrome, Gallery or a screenshot works.
- Appearance: Settings → Appearance → System / Light / Dark.

## If something doesn't connect

- All three on the **same Wi‑Fi**? Phones on mobile data can't see the Mac.
- Mac: **System Settings → Privacy & Security → Local Network → Hopper** must be on.
- Check **Settings → Connection log** on both sides — it says exactly what Hopper tried.
- Corporate / guest Wi‑Fi often blocks device‑to‑device traffic: turn on the iPhone's hotspot and join both the Mac and the Samsung to it.
