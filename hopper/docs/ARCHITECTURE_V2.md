# Hopper v2 — "copy here, paste there", no Send button

Goal: copy on any device, paste on any other, automatically, with nothing to tap after the one‑time
pairing. Devices: **Samsung (Android)**, **iPhone (iOS)**, **MacBook** — and the Mac side becomes a
**Chrome extension** so it can ship through the Chrome Web Store instead of a notarised app.

This document is the result of research into what each OS actually allows (Sept 2026) and how the
apps that already do this (KDE Connect, Yoink, Apple's own Universal Clipboard) get around the limits.

---

## 1. What each OS allows — the honest table

| | Read clipboard in background (needed to *send* automatically) | Write clipboard in background (needed to *receive* automatically) |
|---|---|---|
| **macOS / Chrome extension** | Yes. Extension polls the clipboard from an offscreen document with the `clipboardRead` permission (this is how clipboard‑manager extensions work). | Yes (`clipboardWrite`). |
| **Android 10+** | **Blocked by the OS** for every app except the focused app or the default keyboard. Proven workaround (used by KDE Connect since 2021): a one‑time `adb` grant of `READ_LOGS` + "Display over other apps". Hopper's service then sees the system log line the moment anything is copied, flashes an invisible 1‑frame activity to gain focus, reads the clip, and disappears. | Yes, from a foreground service. |
| **iOS** | **Impossible for third‑party apps.** No API, no permission, no hack that survives App Store review except Yoink's Picture‑in‑Picture trick (app stays "foreground" behind a tiny PiP window). | Only while the app is on screen (or in PiP mode). |

The consequence for iPhone: **Apple already ships exactly this feature between iPhone and Mac** —
Universal Clipboard (Handoff). Copy on iPhone → ⌘V on Mac, and vice‑versa, zero taps. Hopper's job
on the Mac is then to relay that to the Samsung. iPhone ↔ Samsung directly still needs Hopper on the
iPhone to be open (or in PiP "live mode", phase B).

---

## 2. Topology

```
                 Universal Clipboard (Apple, built in)
   iPhone  <════════════════════════════════════════>  MacBook
   Hopper iOS app                                       Chrome extension = hub
   (receive while open,                                  · polls Mac clipboard
    auto‑send on open,                                   · WebSocket client → each phone
    PiP live mode later)                                 · history / devices / settings popup
        ║                                                       ║
        ║  WebSocket (phone is the server)                       ║  WebSocket
        ║                                                       ║
        ╚══════════════════════  Samsung  ══════════════════════╝
                                 Hopper Android app
                                 · foreground service (always on)
                                 · READ_LOGS + floating activity = automatic capture
                                 · writes incoming clips to the clipboard
                                 · TCP + mDNS still used phone ↔ phone
```

**Why the phone is the server.** A Chrome extension cannot listen on a port or browse mDNS; it can
only open outbound `ws://` / `http://` connections. So each phone runs a small WebSocket server on
port 47331 (same port as today's TCP listener) and the extension dials it. Phone ↔ phone keeps the
existing mDNS + TCP path unchanged.

**Same protocol, different pipe.** The extension speaks the existing Hopper protocol byte‑for‑byte
(CBOR frames, HELLO handshake, Ed25519 identity, X25519 + HKDF session key, XChaCha20‑Poly1305).
On TCP frames are length‑prefixed; on WebSocket each binary message is one frame. Nothing about
pairing, trust or encryption changes.

**Finding the phone without mDNS.** The pairing QR shown on the phone already contains its LAN IP,
port and public key. The extension stores the IP, reconnects every 10 s while disconnected, and the
phone also pushes its current IP in every `HELLO` so a DHCP change is picked up on the next
successful connection. If the phone moves to a new network, re‑scan the QR (10 seconds).

---

## 3. Android — automatic capture (the KDE Connect method)

1. **Foreground service** with a persistent notification keeps the Flutter engine, the TCP/WebSocket
   servers and mDNS alive. Requested exemptions during onboarding: battery optimisation
   (Samsung kills background apps aggressively), notifications, "Display over other apps".
2. `ClipboardManager.addPrimaryClipChangedListener` **does fire** in the background; only the read is
   denied, and Android logs `E ClipboardService: Denying clipboard access to app.hopper.hopper…`.
3. With `android.permission.READ_LOGS` (grantable **only via adb**, once), the service tails
   `logcat -T <now> ClipboardService:E *:S` (Android 16+: `"E ClipboardService"`), and on a line
   mentioning our package launches `ClipboardCaptureActivity`:
   transparent theme, `excludeFromRecents`, `noHistory`, `FLAG_ACTIVITY_NEW_TASK`, reads the clip in
   `onWindowFocusChanged(true)`, hands it to Dart over a MethodChannel, `finish()`. The user sees
   nothing except Android 12+'s own "Hopper pasted from clipboard" toast (cannot be suppressed).
4. Background activity start needs the "Display over other apps" (`SYSTEM_ALERT_WINDOW`) exemption —
   still valid on Android 14–16 for activity starts.
5. One‑time setup from the Mac (`tool/android-setup.sh`, phone plugged in with USB debugging on):
   grant `READ_LOGS`, allow `SYSTEM_ALERT_WINDOW`, add the app to the battery whitelist, restart the
   app. The same commands work over Wireless debugging from the phone itself. Without either,
   Hopper falls back to today's behaviour (send from the notification / share sheet).
6. **Content types on Android:** text, links; images (clipboard holds a `content://` URI → bytes);
   files arrive from the Mac into `Downloads/Hopper/` with a notification (Android has no
   cross‑app "file on the clipboard"). Sending a *file* from the phone uses Share → Hopper.

## 4. iOS — what we build

- **Receive**: while Hopper is open (foreground). Incoming clips also raise a local notification when
  the app was backgrounded moments ago, but the clipboard write happens on next open.
- **Send without a button**: on every activation (`sceneDidBecomeActive`) compare
  `UIPasteboard.general.changeCount`; if it changed, read and send. Opening Hopper *is* the send.
  Bind "Open Hopper" to Back Tap / Action Button for a no‑look gesture.
- **Universal Clipboard** covers iPhone ↔ Mac natively; the onboarding tells you to turn Handoff on.
- **Phase B, "Live mode"**: Yoink‑style Picture‑in‑Picture keeps the app foreground, so it can poll
  `changeCount` and receive continuously. App Store‑compliant, opt‑in, ends when you close the PiP.

## 5. Chrome extension (Manifest V3)

| Part | Responsibility |
|---|---|
| `background.js` (service worker) | One WebSocket per phone, protocol + crypto, rules, history, reconnect. Kept alive by WebSocket pings every 20 s (Chrome ≥ 116 resets the idle timer on socket activity). |
| `offscreen.html/js` | Clipboard poller (every 500 ms): `execCommand('paste')` into a hidden contenteditable, hash text / image / files; writes incoming clips with `navigator.clipboard.write`. Created with reason `CLIPBOARD`. |
| `popup` | Same four tabs as the app: Home (last received, clipboard, devices), History, Devices (rules per phone), Settings. |
| `pair.html` | Scans the phone's QR with the webcam (jsQR) or takes IP + 6‑digit code by hand. Also performs one `fetch` to the phone so Chrome shows its **Local Network Access** prompt once (Chrome 142+ gates private‑IP access behind a permission; WebSockets joined in Chrome 147). |
| Crypto | `libsodium.js` (Ed25519, X25519, XChaCha20‑Poly1305 — identical primitives to the Dart side), WebCrypto HKDF‑SHA256, `cbor-x`. All bundled, no CDN, no eval. |
| Storage | `chrome.storage.local`: identity key, peers + rules, settings, history (images as blobs in IndexedDB). |

Limits to know: it works while Chrome is running (Chrome can be set to keep running in the
background); the identity key lives in extension storage, not the macOS keychain; the Web Store
review will ask why `clipboardRead` is needed (answer: it *is* the product).
The native Mac app from v0.1 stays in the repo as a fallback for people who don't use Chrome.

## 6. Content, sizes, transports

| Content | Wi‑Fi / LAN (default cap) | Bluetooth (phase C) |
|---|---|---|
| Text, links | always | ≤ 32 KB |
| Images | ≤ 25 MB (per‑device slider 5–100 MB) | preview only (~20 KB), full when Wi‑Fi returns |
| Files | ≤ 100 MB, chunked 256 KB with offer/accept so a paused or duplicate transfer costs nothing | never |
| Video | treated as a file, same cap; above the cap Hopper asks instead of sending | never |

## 7. Delivery plan

| Phase | Scope | You can test |
|---|---|---|
| **A** (next) | Android foreground service + automatic capture + `tool/android-setup.sh`; phone WebSocket server; Chrome extension with pairing, text + images, history, rules; iOS auto‑send‑on‑open + Handoff guidance. | Copy on Samsung → ⌘V in any Mac app. Copy on Mac → paste on Samsung. iPhone via Universal Clipboard. |
| **B** | Files with chunking + caps, image/file receive UX on Android (Downloads + notification), iOS PiP live mode, Web Store packaging. | Copy a file in Finder → it lands in Downloads on the phone. |
| **C** | Bluetooth LE fallback (text), offline queue, keystore for identity keys, installers. | Router off, text still syncs. |

## 8. Risks

- Samsung One UI may still kill the service despite the exemption on some firmware — the setup
  script also whitelists it in Device Care; a Quick Settings tile restarts it if needed.
- `READ_LOGS` via adb resets on some OS upgrades; the app detects that and shows the setup card again.
- Chrome's Local Network Access permission UX is new (2025–26) and may change; the fallback is the
  native Mac app.
- Universal Clipboard needs both Apple devices on the same Apple ID with Bluetooth, Wi‑Fi and Handoff
  on; it is Apple's feature and can only be recommended, not controlled.

Sources consulted: KDE Connect Android `ClipboardListener.kt` / `ClipboardFloatingActivity.java`
and merge requests !127, !150; Android "Restrictions on starting activities from the background";
Android 15 behaviour changes (SYSTEM_ALERT_WINDOW); Yoink 2.3.5/2.4 release notes (PiP clipboard
monitoring); Chrome "Offscreen documents in Manifest V3", "Use WebSockets in service workers",
"New permission prompt for Local Network Access".
