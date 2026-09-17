<p align="center">
  <img src="hopper/assets/tray/app_icon_1024.png" width="96" alt="Hopper">
</p>

<h1 align="center">Hopper</h1>
<p align="center"><b>Copy here. Paste there.</b><br>One clipboard across your Mac and your Android phone — no cloud, no account, end‑to‑end encrypted, over your own Wi‑Fi.</p>
<p align="center"><a href="https://hopperclip.xyz">hopperclip.xyz</a> · <a href="https://hopperclip.xyz/#download">Download</a> · <a href="hopper/docs/SETUP_MAC_IPHONE_SAMSUNG.md">Setup guide</a> · <a href="hopper/docs/ARCHITECTURE.md">How it works</a></p>

---

Copy on the Mac, long‑press → Paste on the phone. Copy on the phone, ⌘V on the Mac. Text, links, images and files. Nothing to tap after the one‑time pairing, and nothing leaves your network: there is no Hopper server.

| | Mac | Android | iPhone |
|---|---|---|---|
| Receive automatically | ✅ | ✅ always on, even with the app closed | while the app is open |
| Send automatically | ✅ | ✅ after a one‑time setup | opening the app sends what's new; Apple's Universal Clipboard covers iPhone ↔ Mac |
| Text, links, images, files | ✅ | ✅ | ✅ |

## Why the install warnings?

Hopper isn't on the App Store or Play Store yet, so macOS shows *"could not verify"* (System Settings → Privacy & Security → **Open Anyway**) and Android asks to allow "unknown sources". That's the same for every app outside the stores. Instead of trusting a store, you can read this code, compare the SHA‑256 shown on the website with the file you downloaded, and note that the app has no server to phone home to.

## How it works, briefly

- Devices find each other on the local network with mDNS (`_hopper._tcp`) and talk over TCP.
- Pairing swaps Ed25519 identity keys through a QR code shown in the room; a 4‑emoji fingerprint on both screens confirms it.
- Every session does an X25519 key agreement; every clip is sealed with XChaCha20‑Poly1305. Unknown devices are ignored.
- On Android, only the app on screen may read the clipboard. Hopper uses the same workaround as KDE Connect: a one‑time `adb` grant lets it notice a copy the moment it happens and grab it through an invisible one‑frame window. Details in [`hopper/docs/ARCHITECTURE_V2.md`](hopper/docs/ARCHITECTURE_V2.md).

## Repository layout

```
hopper/     the Flutter app (macOS · Android · iOS · Windows · Linux)
  docs/     setup guide, architecture, roadmap, Play Store checklist
  tool/     build.sh (all platforms), android-setup.sh (one-time Android grant)
landing/    the website (Next.js, static export) and its deploy script
```

## Building

Requirements: Flutter 3.35+, Xcode (macOS/iOS), Android SDK + JDK 17 (Android). Then:

```bash
cd hopper
flutter pub get
flutter test
tool/build.sh macos      # → dist/Hopper.app
tool/build.sh android    # → dist/downloads/*.apk + dist/Hopper-android.aab
tool/build.sh ios        # → signed with the team in ios/Runner.xcodeproj, installs on a plugged-in iPhone
```

See [`hopper/docs/BUILD.md`](hopper/docs/BUILD.md) for the one‑time toolchain setup.

## Roadmap

iPhone app in the stores, Play Store and notarised Mac builds, Windows and Linux installers, chunked big‑file transfers, Bluetooth fallback, offline queue. Full list in [`hopper/docs/ROADMAP.md`](hopper/docs/ROADMAP.md).

## Contributing / contact

Issues and pull requests are welcome. Want to collaborate? emranyonas602@gmail.com

## Licence

MIT — see [LICENSE](LICENSE).
