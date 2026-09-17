import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../platform/android_bridge.dart';
import '../platform/clipboard_service.dart';
import '../storage/local_store.dart';
import 'crypto/crypto_service.dart';
import 'identity.dart';
import 'models/models.dart';
import 'protocol/frames.dart';
import 'sensitive_guard.dart';
import 'transport/discovery.dart';
import 'transport/lan_transport.dart';
import 'transport/peer_connection.dart';

/// Payload encoded in the pairing QR code.
class PairingInfo {
  final String code; // 6 digits, also the shared secret
  final String hostId, hostName, hostPlatform;
  final Uint8List hostPk;
  final List<String> hosts;
  final int port;
  final DateTime expiresAt;
  PairingInfo({required this.code, required this.hostId, required this.hostName, required this.hostPlatform,
      required this.hostPk, required this.hosts, required this.port, required this.expiresAt});

  String toQrPayload() => 'hopper://pair?d=${base64UrlEncode(utf8.encode(jsonEncode({
        'id': hostId, 'n': hostName, 'p': hostPlatform, 'pk': base64Encode(hostPk),
        'h': hosts, 'port': port, 'c': code,
      })))}';

  static PairingInfo? parse(String s) {
    try {
      final uri = Uri.parse(s.trim());
      if (uri.scheme != 'hopper' || uri.host != 'pair') return null;
      final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(uri.queryParameters['d']!))));
      return PairingInfo(
        code: j['c'], hostId: j['id'], hostName: j['n'], hostPlatform: j['p'] ?? 'unknown',
        hostPk: base64Decode(j['pk']), hosts: List<String>.from(j['h']), port: j['port'],
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );
    } catch (_) {
      return null;
    }
  }
}

class ReceivedEvent {
  final Clip clip;
  final Peer from;
  ReceivedEvent(this.clip, this.from);
}

class SensitivePrompt {
  final Clip clip;
  final String reason;
  SensitivePrompt(this.clip, this.reason);
}

/// The sync engine: owns identity, peers, history, transport and rules.
class AppController extends ChangeNotifier {
  final store = LocalStore();
  final clipboard = ClipboardService();
  final discovery = Discovery();
  late Identity identity;
  late AppSettings settings;
  late LanTransport transport;

  final peers = <Peer>[];
  final history = <Clip>[];
  final connections = <String, PeerConnection>{};
  final _recentHashes = <String, DateTime>{}; // sha256 → when we last saw it
  final _log = <String>[];
  final _held = <String, Clip>{}; // clips held back by the sensitive guard, by id

  final received = StreamController<ReceivedEvent>.broadcast();
  final sensitivePrompts = StreamController<SensitivePrompt>.broadcast();
  final toasts = StreamController<String>.broadcast();

  PairingInfo? activePairing;
  Timer? _pairingTimer;
  Timer? _reconnectTimer;
  bool ready = false;
  String? lastError;

  List<String> get log => List.unmodifiable(_log.reversed);

  void _l(String s) {
    _log.add('${DateTime.now().toIso8601String().substring(11, 19)}  $s');
    if (_log.length > 300) _log.removeAt(0);
    debugPrint('[hopper] $s');
  }

  // ------------------------------------------------------------------ lifecycle
  Future<void> init() async {
    await store.init();
    identity = await Identity.loadOrCreate(store);
    settings = await store.loadSettings(Identity.defaultDeviceName);
    peers.addAll(await store.loadPeers());
    history.addAll(await store.loadHistory());
    for (final c in history.take(50)) { _recentHashes[c.sha256Hex] = c.createdAt; if (c.originId != identity.id) _remoteHashes.add(c.sha256Hex); }

    transport = LanTransport(identity, () => settings.deviceName);
    transport.incoming.listen(_onIncomingConnection);
    try {
      await transport.start();
      _l('listening on port ${transport.port}');
    } catch (e) {
      lastError = 'Could not open a network port: $e';
      _l(lastError!);
    }
    await _advertise();
    try { await discovery.startBrowsing(); } catch (e) { _l('mDNS browse failed: $e'); }
    discovery.changes.listen((_) { _connectKnownPeers(); notifyListeners(); });

    clipboard.changes.listen((c) => onLocalClipboard(c));
    if (!settings.paused) clipboard.startWatching();

    if (Platform.isAndroid) {
      // Native side: always-on service + automatic capture. It pushes clips to us.
      AndroidBridge.init(
        onCaptured: (c, manual) async {
          try {
            await (manual ? sendContent(c) : onLocalClipboard(c));
          } catch (e, st) {
            _l('capture failed: $e');
            debugPrint('$st');
          }
        },
        onSendHeld: sendHeldClip,
      );
      await AndroidBridge.startService();
    }

    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (_) => _connectKnownPeers());
    ready = true;
    notifyListeners();
  }

  Future<void> _advertise({bool pairing = false}) async {
    try {
      await discovery.advertise(
        id: identity.id, name: settings.deviceName, platform: Identity.platformName,
        fingerprint: Peer.fingerprintOf(identity.publicKey), port: transport.port, pairing: pairing,
      );
    } catch (e) {
      _l('mDNS advertise failed: $e');
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _pairingTimer?.cancel();
    for (final c in connections.values) { c.close(); }
    clipboard.dispose();
    discovery.stop();
    transport.stop();
    super.dispose();
  }

  // ------------------------------------------------------------------ settings
  Future<void> saveSettings() async {
    await store.saveSettings(settings);
    notifyListeners();
  }

  Future<void> setPaused(bool v) async {
    settings.paused = v;
    if (v) { clipboard.stopWatching(); } else { clipboard.startWatching(); }
    await saveSettings();
  }

  Future<void> setDeviceName(String name) async {
    settings.deviceName = name.trim().isEmpty ? Identity.defaultDeviceName : name.trim();
    await saveSettings();
    await _advertise(pairing: activePairing != null);
  }

  Future<void> completeOnboarding() async {
    settings.onboardingDone = true;
    await saveSettings();
  }

  // ------------------------------------------------------------------ peers
  Peer? peerById(String id) => peers.cast<Peer?>().firstWhere((p) => p!.id == id, orElse: () => null);
  bool isConnected(String peerId) => connections[peerId]?.isOpen ?? false;
  DiscoveredDevice? discovered(String peerId) => discovery.devices[peerId];

  Future<void> savePeers() async {
    await store.savePeers(peers);
    notifyListeners();
  }

  Future<void> updateRules(Peer p, void Function(PairRules r) edit) async {
    edit(p.rules);
    await savePeers();
    // Tell the peer so both sides show the same direction.
    await connections[p.id]?.send({'t': FrameType.rulesSync, 'direction': p.rules.direction.mirrored.name});
  }

  Future<void> unpair(Peer p) async {
    await connections[p.id]?.send({'t': FrameType.unpair});
    connections.remove(p.id)?.close();
    peers.removeWhere((x) => x.id == p.id);
    await savePeers();
    _l('unpaired ${p.name}');
  }

  void _connectKnownPeers() {
    if (!ready) return;
    for (final p in peers) {
      if (isConnected(p.id)) continue;
      final d = discovery.devices[p.id];
      if (d == null) continue;
      _dial(p, d.host, d.port);
    }
  }

  final _dialing = <String>{};
  Future<void> _dial(Peer p, String host, int port) async {
    if (_dialing.contains(p.id)) return;
    _dialing.add(p.id);
    try {
      final conn = await transport.connect(host, port);
      final hello = await conn.handshake();
      if (hello.id != p.id || !CryptoService.constantTimeEquals(hello.identityPk, p.identityPk)) {
        _l('identity mismatch for ${p.name}; refusing');
        conn.close();
        return;
      }
      _attach(conn, p);
    } catch (e) {
      _l('dial ${p.name} failed: $e');
    } finally {
      _dialing.remove(p.id);
    }
  }

  Future<void> _onIncomingConnection(PeerConnection conn) async {
    try {
      final hello = await conn.handshake();
      final known = peerById(hello.id);
      if (known != null) {
        if (!CryptoService.constantTimeEquals(hello.identityPk, known.identityPk)) {
          _l('incoming ${hello.name}: key mismatch, refusing');
          conn.close();
          return;
        }
        known.name = hello.name;
        _attach(conn, known);
        return;
      }
      if (activePairing != null) {
        _awaitPairRequest(conn, hello);
        return;
      }
      _l('incoming from unknown device ${hello.name}; ignoring');
      conn.close();
    } catch (e) {
      _l('incoming handshake failed: $e');
    }
  }

  void _attach(PeerConnection conn, Peer peer) {
    connections[peer.id]?.close();
    connections[peer.id] = conn;
    peer.lastSeenAt = DateTime.now();
    _l('connected to ${peer.name} (${conn.remoteAddress})');
    conn.frames.listen((f) => _onFrame(f, peer, conn), onDone: () {
      if (connections[peer.id] == conn) connections.remove(peer.id);
      _l('disconnected from ${peer.name}');
      notifyListeners();
    });
    conn.send({'t': FrameType.rulesSync, 'direction': peer.rules.direction.mirrored.name});
    savePeers();
    toasts.add('Connected to ${peer.name}');
  }

  // ------------------------------------------------------------------ pairing (host side)
  Future<PairingInfo> startPairing() async {
    final code = List.generate(6, (_) => CryptoService.randomBytes(1)[0] % 10).join();
    final hosts = await LanTransport.localAddresses();
    activePairing = PairingInfo(
      code: code, hostId: identity.id, hostName: settings.deviceName, hostPlatform: Identity.platformName,
      hostPk: identity.publicKey, hosts: hosts, port: transport.port,
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );
    await _advertise(pairing: true);
    _pairingTimer?.cancel();
    _pairingTimer = Timer(const Duration(seconds: 60), () { if (activePairing != null) startPairing(); });
    notifyListeners();
    return activePairing!;
  }

  Future<void> stopPairing() async {
    _pairingTimer?.cancel();
    activePairing = null;
    await _advertise(pairing: false);
    notifyListeners();
  }

  Future<void> _awaitPairRequest(PeerConnection conn, HelloInfo hello) async {
    late StreamSubscription sub;
    final timer = Timer(const Duration(seconds: 30), () { sub.cancel(); conn.close(); });
    sub = conn.frames.listen((f) async {
      if (f['t'] != FrameType.pairRequest) return;
      timer.cancel();
      await sub.cancel();
      final pairing = activePairing;
      if (pairing == null) { conn.close(); return; }
      final expected = await CryptoService.hmac(utf8.encode(pairing.code), [...hello.identityPk, ...identity.publicKey]);
      final proof = f['proof'];
      if (proof is! Uint8List || !CryptoService.constantTimeEquals(proof, expected)) {
        _l('pairing from ${hello.name} rejected: wrong code');
        await conn.send({'t': FrameType.pairFail, 'reason': 'wrong code'});
        conn.close();
        return;
      }
      final peer = Peer(id: hello.id, name: hello.name, platform: hello.platform,
          identityPk: hello.identityPk, pairedAt: DateTime.now());
      peers.removeWhere((p) => p.id == peer.id);
      peers.add(peer);
      await conn.send({'t': FrameType.pairOk});
      _l('paired with ${peer.name}');
      await stopPairing();
      _attach(conn, peer);
      toasts.add('Paired with ${peer.name} · ${emojiCheckFor(peer)}');
    });
  }

  String emojiCheckFor(Peer p) => Peer.emojiCheck(identity.publicKey, p.identityPk);

  // ------------------------------------------------------------------ pairing (joining side)
  /// Connect to a host and pair using the 6-digit code. [expectedPk] comes from the QR when available.
  Future<Peer> pairWith({required List<String> hosts, required int port, required String code, Uint8List? expectedPk}) async {
    Object? lastErr;
    for (final h in hosts) {
      try {
        final conn = await transport.connect(h, port, timeout: const Duration(seconds: 4));
        final hello = await conn.handshake();
        if (expectedPk != null && !CryptoService.constantTimeEquals(hello.identityPk, expectedPk)) {
          conn.close();
          throw StateError('The device that answered is not the one in the QR code.');
        }
        final proof = await CryptoService.hmac(utf8.encode(code), [...identity.publicKey, ...hello.identityPk]);
        final reply = conn.frames.firstWhere((f) => f['t'] == FrameType.pairOk || f['t'] == FrameType.pairFail)
            .timeout(const Duration(seconds: 15));
        await conn.send({'t': FrameType.pairRequest, 'proof': proof});
        final r = await reply;
        if (r['t'] != FrameType.pairOk) {
          conn.close();
          throw StateError(r['reason']?.toString() ?? 'Pairing refused');
        }
        final peer = Peer(id: hello.id, name: hello.name, platform: hello.platform,
            identityPk: hello.identityPk, pairedAt: DateTime.now());
        peers.removeWhere((p) => p.id == peer.id);
        peers.add(peer);
        _attach(conn, peer);
        _l('paired with ${peer.name}');
        return peer;
      } catch (e) {
        lastErr = e;
        if (e is StateError) rethrow;
      }
    }
    throw StateError('Could not reach the device. Are both on the same Wi-Fi? ($lastErr)');
  }

  // ------------------------------------------------------------------ clips: outgoing
  Future<Clip?> _makeClip(ClipboardContent c) async {
    if (c.isEmpty) return null;
    final now = DateTime.now();
    if (c.fileBytes != null) {
      return Clip(id: const Uuid().v4(), type: ClipType.file, bytes: c.fileBytes, name: c.fileName, mime: c.mime,
          originId: identity.id, originName: settings.deviceName, createdAt: now,
          sha256Hex: await CryptoService.sha256Hex(c.fileBytes!));
    }
    if (c.imagePng != null) {
      return Clip(id: const Uuid().v4(), type: ClipType.image, bytes: c.imagePng, name: c.fileName, mime: c.mime ?? 'image/png',
          originId: identity.id, originName: settings.deviceName, createdAt: now,
          sha256Hex: await CryptoService.sha256Hex(c.imagePng!));
    }
    final t = c.text!;
    return Clip(id: const Uuid().v4(), type: Clip.looksLikeLink(t) ? ClipType.link : ClipType.text, text: t,
        originId: identity.id, originName: settings.deviceName, createdAt: now,
        sha256Hex: await CryptoService.sha256Hex(utf8.encode(t)));
  }

  /// Loop prevention + dedup: the same content seen within [_dedupWindow] is skipped
  /// (a clip we just received must not bounce back). Copying the same thing again
  /// later on purpose still goes through.
  /// Content that arrived from a peer is blocked from bouncing back for 10 minutes;
  /// content the user copied here is only blocked for a few seconds (so copying the
  /// same thing again on purpose re-sends it).
  static const _remoteWindow = Duration(minutes: 10);
  static const _localWindow = Duration(seconds: 8);
  final _remoteHashes = <String>{};
  bool _seen(String hash) {
    final t = _recentHashes[hash];
    if (t == null) return false;
    return DateTime.now().difference(t) < (_remoteHashes.contains(hash) ? _remoteWindow : _localWindow);
  }
  void _remember(String hash, {bool remote = false}) {
    if (remote) { _remoteHashes.add(hash); } else { _remoteHashes.remove(hash); }
    _recentHashes[hash] = DateTime.now();
    if (_recentHashes.length > 400) {
      final oldest = _recentHashes.entries.reduce((a, b) => a.value.isBefore(b.value) ? a : b).key;
      _recentHashes.remove(oldest);
    }
  }

  /// Called when the local clipboard changes (desktop poll, Android capture, or the
  /// app coming to the front on a phone).
  Future<void> onLocalClipboard(ClipboardContent c, {bool manual = false}) async {
    if (!manual && settings.paused) { _l('local clip ignored: paused'); return; }
    final clip = await _makeClip(c);
    if (clip == null) return;
    if (!manual && _seen(clip.sha256Hex)) { _l('local ${clip.type.name} (${Clip.fmtSize(clip.size)}) skipped: seen recently'); return; }
    _l('local ${clip.type.name} (${Clip.fmtSize(clip.size)})');
    try {
      await _addToHistory(clip);
    } catch (e) {
      _l('history save failed: $e');
    }
    _remember(clip.sha256Hex);

    if (!manual && settings.sensitiveGuard) {
      final reason = c.sensitive
          ? 'marked sensitive by the app you copied it from'
          : (clip.text != null ? SensitiveGuard.check(clip.text!) : null);
      if (reason != null) {
        _l('clip looks like $reason — asking before sending');
        _held[clip.id] = clip;
        sensitivePrompts.add(SensitivePrompt(clip, reason));
        if (Platform.isAndroid) {
          AndroidBridge.notify(title: 'Held back — looks like $reason',
              body: 'Hopper did not send it. Tap "Send once" to send it anyway.', heldClipId: clip.id);
        }
        return;
      }
    }
    await broadcast(clip, manual: manual);
  }

  /// Send a clip that the sensitive guard held back (from the sheet or the notification).
  Future<void> sendHeldClip(String id) async {
    final clip = _held.remove(id) ?? history.cast<Clip?>().firstWhere((c) => c!.id == id, orElse: () => null);
    if (clip == null) return;
    final n = await broadcast(clip, manual: true);
    toasts.add(n == 0 ? 'No connected device to send to' : 'Sent');
  }

  /// Send a clip to every eligible connected peer.
  Future<int> broadcast(Clip clip, {bool manual = false}) async {
    var sent = 0;
    for (final p in peers) {
      final r = p.rules;
      if (!(manual || r.direction.allowsSend)) { clip.delivery[p.id] = 'skipped'; _l('not sent to ${p.name}: direction'); continue; }
      if (!r.allows(clip.type)) { clip.delivery[p.id] = 'skipped'; _l('not sent to ${p.name}: ${clip.type.name} blocked by rules'); continue; }
      if (clip.size > r.capFor(clip.type)) { clip.delivery[p.id] = 'too large'; _l('not sent to ${p.name}: too large'); continue; }
      if (!isConnected(p.id)) { clip.delivery[p.id] = 'offline'; _l('not sent to ${p.name}: offline'); continue; }
      await sendClipTo(clip, p, manual: manual);
      sent++;
    }
    notifyListeners();
    await store.saveHistory(history);
    return sent;
  }

  Future<void> sendClipTo(Clip clip, Peer p, {bool manual = true}) async {
    final conn = connections[p.id];
    if (conn == null || !conn.isOpen) { clip.delivery[p.id] = 'offline'; notifyListeners(); return; }
    var bytes = clip.bytes;
    if (bytes == null && (clip.type == ClipType.image || clip.type == ClipType.file)) bytes = await store.loadImage(clip.blobPath);
    clip.delivery[p.id] = 'sending';
    notifyListeners();
    await conn.send({
      't': FrameType.clip, 'id': clip.id, 'type': clip.type.name,
      'text': clip.text, 'data': bytes, 'name': clip.name, 'mime': clip.mime,
      'origin': clip.originId, 'originName': clip.originName,
      'ts': clip.createdAt.millisecondsSinceEpoch, 'sha': clip.sha256Hex, 'manual': manual,
    });
    _l('sent ${clip.type.name} (${Clip.fmtSize(clip.size)}) to ${p.name}');
    clip.delivery[p.id] = 'sent';
    notifyListeners();
  }

  /// "Send clipboard" button, tray item and share-sheet path.
  Future<int> sendCurrentClipboard({String? overrideText}) async {
    final c = overrideText != null ? ClipboardContent(text: overrideText) : await clipboard.read();
    return sendContent(c);
  }

  /// Send given content by hand, ignoring direction rules and the guard.
  Future<int> sendContent(ClipboardContent c) async {
    if (c.isEmpty) { toasts.add('Clipboard is empty'); return 0; }
    final clip = await _makeClip(c);
    if (clip == null) return 0;
    _remember(clip.sha256Hex);
    await _addToHistory(clip);
    final n = await broadcast(clip, manual: true);
    toasts.add(n == 0 ? 'No connected device to send to' : 'Sent to $n device${n == 1 ? '' : 's'}');
    return n;
  }

  /// Phones: whenever the app comes to the front, whatever is new on the clipboard is
  /// sent automatically (respecting rules and the guard). Opening Hopper *is* the send.
  Future<void> syncClipboardOnResume() async {
    if (!(Platform.isAndroid || Platform.isIOS) || settings.paused) return;
    if (!peers.any((p) => isConnected(p.id))) return;
    final c = await clipboard.read();
    if (c.isEmpty) return;
    await onLocalClipboard(c);
  }

  // ------------------------------------------------------------------ clips: incoming
  Future<void> _onFrame(Map<String, Object?> f, Peer p, PeerConnection conn) async {
    switch (f['t']) {
      case FrameType.clip:
        await _onClipFrame(f, p, conn);
      case FrameType.clipAck:
        final c = history.cast<Clip?>().firstWhere((c) => c!.id == f['id'], orElse: () => null);
        if (c != null) { c.delivery[p.id] = f['state']?.toString() ?? 'delivered'; notifyListeners(); }
      case FrameType.rulesSync:
        final d = SyncDirection.values.cast<SyncDirection?>().firstWhere((x) => x!.name == f['direction'], orElse: () => null);
        if (d != null && p.rules.direction != d) { p.rules.direction = d; await savePeers(); }
      case FrameType.unpair:
        _l('${p.name} unpaired us');
        connections.remove(p.id)?.close();
        peers.removeWhere((x) => x.id == p.id);
        await savePeers();
        toasts.add('${p.name} removed this device');
    }
  }

  Future<void> _onClipFrame(Map<String, Object?> f, Peer p, PeerConnection conn) async {
    final manual = f['manual'] == true;
    final type = ClipType.values.firstWhere((t) => t.name == f['type'], orElse: () => ClipType.text);
    String state = 'delivered';
    if (settings.paused && !manual) {
      state = 'paused';
    } else if (!manual && !p.rules.direction.allowsReceive) {
      state = 'direction';
    } else if (!p.rules.allows(type)) {
      state = 'type blocked';
    }
    if (state != 'delivered') {
      await conn.send({'t': FrameType.clipAck, 'id': f['id'], 'state': state});
      return;
    }
    final sha = f['sha']?.toString() ?? '';
    if (_seen(sha)) {
      await conn.send({'t': FrameType.clipAck, 'id': f['id'], 'state': 'duplicate'});
      return;
    }
    _remember(sha, remote: true);
    final clip = Clip(
      id: f['id']?.toString() ?? const Uuid().v4(), type: type, text: f['text']?.toString(),
      bytes: f['data'] is Uint8List ? f['data'] as Uint8List : null,
      name: f['name']?.toString(), mime: f['mime']?.toString(),
      originId: f['origin']?.toString() ?? p.id, originName: f['originName']?.toString() ?? p.name,
      createdAt: DateTime.fromMillisecondsSinceEpoch((f['ts'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      sha256Hex: sha,
    );
    clip.delivery[p.id] = 'received';
    String? savedPath;
    try {
      savedPath = await clipboard.write(type == ClipType.file
          ? ClipboardContent(fileBytes: clip.bytes, fileName: clip.name, mime: clip.mime)
          : ClipboardContent(text: clip.text, imagePng: clip.bytes, mime: clip.mime));
    } catch (e) {
      _l('could not write clipboard: $e');
    }
    await _addToHistory(clip);
    _l('received ${clip.type.name} (${Clip.fmtSize(clip.size)}) from ${p.name}');
    await conn.send({'t': FrameType.clipAck, 'id': clip.id, 'state': 'delivered'});
    received.add(ReceivedEvent(clip, p));
    if (p.rules.notify) {
      final isFile = type == ClipType.file;
      toasts.add(isFile
          ? 'File from ${p.name}: ${clip.name} — saved to ${_shortPath(savedPath)}'
          : 'Copied from ${p.name} — ready to paste');
      if (Platform.isAndroid) {
        AndroidBridge.notify(
          title: isFile ? 'File from ${p.name}' : 'Copied from ${p.name}',
          body: isFile ? '${clip.name} · saved to ${_shortPath(savedPath)}' : clip.preview,
        );
      }
    }
  }

  String _shortPath(String? p) {
    if (p == null) return 'Downloads/Hopper';
    if (Platform.isAndroid) return p;
    final home = Platform.environment['HOME'];
    return home != null && p.startsWith(home) ? '~${p.substring(home.length)}' : p;
  }

  // ------------------------------------------------------------------ history
  Future<void> _addToHistory(Clip clip) async {
    if (clip.bytes != null) {
      clip.blobPath = await store.saveBlob(clip.id, clip.bytes!, _extFor(clip));
    }
    history.insert(0, clip);
    // Keep only the most recent N, never dropping pinned items.
    while (history.length > settings.historyLimit) {
      final idx = history.lastIndexWhere((c) => !c.pinned);
      if (idx < 0) break;
      final removed = history.removeAt(idx);
      await store.deleteImage(removed.blobPath);
    }
    // Drop in-memory bytes for older items to save RAM.
    for (var i = 5; i < history.length; i++) { history[i].bytes = null; }
    await store.saveHistory(history);
    notifyListeners();
  }

  String _extFor(Clip c) {
    if (c.type == ClipType.file) {
      final n = c.name ?? '';
      return n.contains('.') ? n.split('.').last : 'bin';
    }
    return switch (c.mime) { 'image/jpeg' => 'jpg', 'image/gif' => 'gif', 'image/webp' => 'webp', _ => 'png' };
  }

  Future<void> copyToLocalClipboard(Clip c) async {
    var bytes = c.bytes;
    if (bytes == null && (c.type == ClipType.image || c.type == ClipType.file)) bytes = await store.loadImage(c.blobPath);
    if (c.type == ClipType.file) {
      if (bytes == null) { toasts.add('File is no longer in history'); return; }
      final path = await clipboard.write(ClipboardContent(fileBytes: bytes, fileName: c.name, mime: c.mime));
      toasts.add(Platform.isAndroid ? 'Saved to $path' : 'File on the clipboard · ${_shortPath(path)}');
      return;
    }
    await clipboard.write(ClipboardContent(text: c.text, imagePng: bytes, mime: c.mime));
    _remember(c.sha256Hex, remote: true);
    toasts.add('Copied');
  }

  Future<void> togglePin(Clip c) async { c.pinned = !c.pinned; await store.saveHistory(history); notifyListeners(); }

  Future<void> deleteClip(Clip c) async {
    history.remove(c);
    await store.deleteImage(c.blobPath);
    await store.saveHistory(history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    for (final c in history.where((c) => !c.pinned).toList()) {
      await store.deleteImage(c.blobPath);
      history.remove(c);
    }
    await store.saveHistory(history);
    notifyListeners();
  }
}
