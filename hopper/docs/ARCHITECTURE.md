# How Hopper works

Short version: every device runs the same app; there is no server. Devices find each other on the local network with mDNS, connect over TCP, authenticate with keys exchanged during QR pairing, and exchange encrypted clipboard frames.

## Layers

```
Presentation   Home · History · Devices · Settings · tray · share sheet · onboarding & tour
Clipboard      read / write / watch the OS clipboard (platform/clipboard_service.dart)
Sync engine    rules · dedup & loop prevention · history · pairing · sensitive guard (core/app_controller.dart)
Transport      PeerConnection (handshake + encryption) over LanTransport (TCP)
Discovery      mDNS / DNS-SD, service type _hopper._tcp
```

## Discovery
Each device advertises `_hopper._tcp` with TXT records `id`, `n` (name), `p` (platform), `fp` (key fingerprint), `pair` (1 while in pairing mode). Devices browse for the same type and dial peers whose `id` is in their trust list. Unknown devices are shown only in pairing flows and never connected to automatically.

## Connection & handshake
TCP, default port 47331 (falls back to a random port, advertised via mDNS). Frames are `[u32 length][payload]`, payloads are CBOR maps.

```
A → B  HELLO      { v, id, name, platform, pk (Ed25519), epk (X25519 ephemeral), sig = Sign(pk_A, epk) }
B → A  HELLO_ACK  { same fields for B }
```
Both verify the signature, derive `K = HKDF-SHA256(X25519(eph_A, eph_B), salt = sorted(epk_A, epk_B), info = "hopper-session-v1")` and from then on every frame is `XChaCha20-Poly1305(K, random 24-byte nonce)`. Ephemeral keys give forward secrecy; identity keys give authentication. A connection is *attached* to a peer only if the identity key matches the stored one.

## Pairing
Host shows a 6‑digit code `c` (also embedded in the QR together with its identity key, LAN addresses and port; QR payload: `hopper://pair?d=<base64url JSON>`). Joiner connects, completes the handshake, then sends
```
PAIR_REQUEST { proof = HMAC-SHA256(c, pk_joiner || pk_host) }
```
Host recomputes and compares in constant time, replies `PAIR_OK` / `PAIR_FAIL`, both store each other's key. The code rotates every 60 s and is single‑use. A 4‑emoji check derived from both keys is shown on both screens.

## Clip transfer
```
CLIP     { id, type: text|link|image, text?, data? (PNG bytes), origin, originName, ts, sha, manual }
CLIP_ACK { id, state: delivered | duplicate | paused | direction | type blocked | too large }
```
Sender applies the pair's rules first (direction, type, size). Receiver applies its own copy of the rules again, deduplicates by SHA‑256, writes to the clipboard with a 900 ms watcher suppression, stores to history and acks.

### Loop prevention
1. Origin tagging: a device never re‑sends a clip whose origin is another device.
2. Content hashing: last 400 hashes seen are skipped.
3. Write suppression: the clipboard watcher ignores the change it caused itself.

### Rules sync
`RULES_SYNC { direction }` is sent when a connection is attached and whenever the user changes the direction, mirrored so both devices display consistent settings.

## Storage
JSON files under the app‑support directory: identity, peers (+ rules), settings, history (image bytes as PNG files in `images/`). The identity secret key is a file with 0600 permissions in this MVP; v1.0 moves it to the OS keystore.

## Platform notes
- **Desktop** polls the clipboard every 400 ms (macOS has no change event). Windows/Linux/macOS all support reading images via `pasteboard`.
- **Android** cannot read the clipboard in the background (API 29+). Hopper reads it when the app is in the foreground (Home tab), and accepts text via the share sheet (`ACTION_SEND` → `MainActivity.kt` → MethodChannel `hopper/share`). Receiving works while the app process is alive; a foreground service to keep it alive is on the roadmap.
