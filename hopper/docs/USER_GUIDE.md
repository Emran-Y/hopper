# Hopper — User Guide

Hopper gives your phone and your PC one shared clipboard. It works entirely over your local Wi‑Fi: nothing leaves your network, there is no account, and no internet connection is needed.

---

## 1. Install

| Device | How |
|---|---|
| **Windows** | Unzip `Hopper-windows-x64.zip` anywhere (e.g. `C:\Program Files\Hopper`) and run `hopper.exe`. To start with Windows, put a shortcut in `shell:startup`. |
| **macOS** | Drag `Hopper.app` to Applications. First launch: right‑click → Open (unsigned build). |
| **Linux** | Extract the tarball and run `./hopper`. Needs GTK 3 and `libayatana-appindicator` for the tray icon. |
| **Android** | Install `hopper-release.apk` (allow "install from unknown sources" when asked). |

Install Hopper on **both** devices and connect both to the **same Wi‑Fi network**. A phone hotspot counts as a network too.

---

## 2. First launch: the welcome tour

The first time you open Hopper you get a short, five‑page walkthrough. Tap **Next** to go through it or **Skip** at any time:

1. **One clipboard for all your devices** — what the app does.
2. **Works completely offline** — same Wi‑Fi is all you need.
3. **Private by design** — pairing and encryption in plain words.
4. **You choose the direction** — how the per‑device rules work, and why phones need one tap to send.
5. **Name this device** — this is the name your other devices will see. Change it later in Settings.

After **Get started**, a quick in‑app tour highlights the four tabs (Home, History, Devices, Settings) and the Send button. You can replay both from **Settings → Show the welcome tour again**.

---

## 3. Pair your devices (once, ~20 seconds)

Pairing tells the two devices to trust each other. You only do it once per pair.

**On the PC**
1. Open Hopper → **Devices** → **Pair device**.
2. The **Show code** tab displays a QR code and a 6‑digit code. Both change every 60 seconds and work only once.

**On the phone**
1. Open Hopper → **Devices** → **Pair device**. The **Join a device** tab opens with the camera.
2. Point the camera at the PC's QR code.
   *No camera or can't scan?* Pick the PC from the list under "1. Pick the device" and type the 6 digits.
3. When pairing succeeds, both devices show **four emoji**. Check they match — that confirms nobody intercepted the pairing. Tap **Done**.

You can also pair the other way round (phone shows the code, PC joins with the 6‑digit code), and you can pair as many devices as you like.

> If the phone can't find the PC: make sure both are on the same Wi‑Fi (not one on mobile data), and that the PC's firewall allows Hopper (see Troubleshooting).

---

## 4. Everyday use

### PC → phone (automatic)
Copy anything on the PC. Within a second the phone's clipboard has it and a small notice appears: *"Copied from Work‑Laptop — ready to paste"*. Long‑press in any text field and paste.

### Phone → PC (one tap)
Android and iOS don't let apps read the clipboard in the background — a privacy protection, not a Hopper limitation. So sending from the phone takes one tap:

- **In the app:** open Hopper → Home → **Send to <PC name>**. The card shows what's on your clipboard so you can check before sending.
- **From any app:** select text → **Share** → **Hopper**. The text is sent straight to your paired devices without opening the app fully.

### Images
Screenshots and copied images sync too (up to 25 MB by default, adjustable per device). On the receiving PC the image is on the clipboard ready to paste into a document or chat; on Android it's placed on the clipboard where supported and always available in **History**.

### Manual sending of anything, anywhere
**History** → long‑press a clip (or tap ⋯) → **Send to…** → pick a device. This works regardless of the direction setting.

---

## 5. The four tabs

### Home
- **Last received** card — what arrived last, from which device. **Copy again** puts it back on your clipboard.
- **Your clipboard** — what's on this device's clipboard right now and the **Send** button.
- **Devices** — your paired devices with a green dot when connected.

### History
Every clip you copied or received, newest first. Search by text, filter All / Text / Images / Pinned.
Tap a clip to copy it again. Long‑press (or ⋯) for **Copy**, **Send to…**, **Pin** (keeps it at the top and exempt from clean‑up), **Delete**. The ⋮ menu clears history (pinned items stay).

### Devices
One card per paired device. Tap it to set:

| Setting | Meaning |
|---|---|
| **Two‑way** | Clips flow automatically in both directions. |
| **This device → peer** | Only what you copy here is sent to that device. |
| **Peer → this device** | Only what that device copies arrives here. |
| **Manual** | Nothing automatic. Use Send or Send to…. |
| Text / Links / Images | Which kinds of content to accept from and send to this device. |
| Size limit | Largest image to sync with this device (5–50 MB). |
| Notify | Show a notice when a clip arrives from this device. |
| Verification emoji | The four emoji from pairing — must match on both devices. |
| Unpair | Removes the device. Pair again any time. |

The direction is shared: if you set *Phone → PC only* on the phone, the PC shows *Phone → PC only* too.

### Settings
- **Pause all syncing** — nothing is sent or received until you resume. Also in the PC tray menu.
- **Sensitive‑content guard** — when on, Hopper holds back anything that looks like a one‑time code, password, card number, private key or API token and asks first. Choose **Send once** or **Don't send**.
- **History → Keep the last N clips** — 50 to 500.
- **Device name**, **Start minimized to tray** (PC), **Show the welcome tour again**.
- **Connection log** — what Hopper is doing on the network; useful when something doesn't connect.

---

## 6. The PC tray icon

On Windows/macOS/Linux Hopper lives in the system tray / menu bar. Closing the window hides it; Hopper keeps syncing. Click the icon to show/hide the window; right‑click for:

- how many devices are connected
- **Send clipboard now** (useful in Manual mode)
- **Pause / Resume syncing**
- **Open Hopper**, **Quit**

---

## 7. Privacy & security, in short

- Devices are identified by cryptographic keys exchanged during QR pairing. Unknown devices are ignored, silently.
- Every clip is encrypted end‑to‑end before it touches the network. On a shared Wi‑Fi, others see only encrypted bytes.
- Nothing is stored anywhere except on your own devices. There is no Hopper server.
- Clips held back by the sensitive‑content guard are not kept in the receiver's history.
- Unpairing deletes the other device's key — it can't reconnect.

---

## 8. Troubleshooting

**The phone can't see the PC (or vice versa)**
- Both on the same Wi‑Fi? Phone on mobile data won't work. Guest networks and some public/office Wi‑Fi block device‑to‑device traffic ("client isolation") — use a phone hotspot instead.
- Windows: the first time Hopper runs, allow it on *Private networks* in the firewall prompt. If you missed it: Windows Security → Firewall → Allow an app → Hopper (Private). Hopper listens on TCP port 47331.
- macOS: allow "Local Network" access when prompted (System Settings → Privacy & Security → Local Network).
- Check **Settings → Connection log** on both devices.

**Pairing says "wrong code"** — the code expired (60 s) or was typed wrong. Show a fresh one and try again.

**Clips from the PC don't arrive on the phone** — is the pair set to *Phone → PC only* or *Manual*? Is syncing paused? Is the phone app killed by battery optimisation? On Android: Settings → Apps → Hopper → Battery → **Unrestricted**.

**A text was held back** — the sensitive‑content guard triggered. Tap **Send once**, or turn the guard off in Settings.

**Image didn't paste on Android** — some Android versions don't accept images on the clipboard from apps. Open **History**, tap the image → Copy, or share it from there.

**I want to move Hopper to a new PC** — pair the new PC as a new device. Pairing data lives in the app's data folder and isn't transferable on purpose (it contains the device key).

---

## 9. Where Hopper stores data

| Platform | Folder |
|---|---|
| Windows | `%APPDATA%\app.hopper\hopper\hopper\` |
| macOS | `~/Library/Application Support/app.hopper.hopper/hopper/` |
| Linux | `~/.local/share/hopper/hopper/` |
| Android | app‑private storage (not accessible to other apps) |

Contents: `identity.json` (this device's key), `peers.json`, `settings.json`, `history.json`, `images/`. Delete the folder to reset Hopper completely.
