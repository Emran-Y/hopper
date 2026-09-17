# Hopper — offline clipboard sync between your phone and PC

Copy on one device, paste on another. Hopper moves your clipboard between devices over your local Wi‑Fi — **no internet, no account, no server**. Everything is end‑to‑end encrypted; devices are paired once with a QR code.

**Platforms:** Windows · macOS · Linux · Android · iOS (one codebase; `tool/build.sh` builds Android, macOS and iOS from a Mac).

| | |
|---|---|
| 📖 **User guide** | [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) — install, pair, use, troubleshoot |
| 🛠 **Build & setup** | [`docs/BUILD.md`](docs/BUILD.md) — build the app for each platform |
| 🧭 **Architecture** | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how it works under the hood |
| 🗺 **Roadmap** | [`docs/ROADMAP.md`](docs/ROADMAP.md) — what's in this MVP and what comes next |

## What this MVP does

- Automatic sync from PC → phone and PC ↔ PC (desktop watches the clipboard).
- One‑tap send from phone → PC (Android blocks background clipboard reading; Hopper gives you a Send button and a share‑sheet target).
- Text, links and images.
- Per‑device direction: **Two‑way**, **A → B only**, **B → A only**, or **Manual**.
- QR‑code or 6‑digit‑code pairing, end‑to‑end encryption (X25519 + XChaCha20‑Poly1305, Ed25519 identities).
- Sensitive‑content guard: asks before sending anything that looks like a password, one‑time code or card number.
- Searchable history with pin / send‑to / delete, system tray on desktop, first‑run walkthrough and in‑app tour.

## Quick start (developer)

```bash
flutter pub get
flutter run -d windows     # or macos / linux / <android device id>
```

Release builds from a Mac: `tool/build.sh android` · `tool/build.sh macos` · `tool/build.sh ios` (outputs land in `dist/`).
See `docs/BUILD.md` for release builds and the one‑time platform setup.

---
Licence: MIT (see the repository root).
