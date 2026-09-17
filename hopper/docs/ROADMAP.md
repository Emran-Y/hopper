# Roadmap

## In this MVP (v0.1)
- LAN discovery (mDNS) + encrypted TCP transport
- QR / 6‑digit pairing with emoji verification
- Text, links, images; per‑device direction, type filters, size limit
- Sensitive‑content guard (ask before sending)
- History with search, filters, pin, send‑to, delete; retention limit
- Desktop tray with pause / send / quit; hide‑to‑tray
- Android share‑sheet target; in‑app Send button
- Onboarding walkthrough + in‑app tour; connection log

## Next (v0.2 → v1.0)
1. **Android foreground service** with a persistent notification ("Send clipboard" action) so receiving keeps working when the app is in the background, plus a Quick Settings tile.
2. **Bluetooth LE fallback** (PC as central, phone as peripheral) for text‑sized clips when there is no shared Wi‑Fi; automatic transport ranking and failover.
3. **Offline queue** — hold the last clip for a device that is out of range.
4. **iOS**: Share Extension + Shortcuts action, local‑network permission flow, background BLE.
5. **OS keystore** for the identity key; encrypted history at rest (SQLCipher).
6. **Chunked transfers with offer/accept** for large images and, later, files.
7. App exclusions on desktop (never sync from password managers), global hotkey history picker, dark‑mode polish, installers (MSIX, DMG, AppImage, Play/App Store).

## Later
Files, rich text, Wi‑Fi Direct, Hopper keyboard for Android, optional self‑hosted relay for people who *want* remote sync (strictly opt‑in).
