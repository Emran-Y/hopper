import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../crypto/crypto_service.dart';
import '../identity.dart';
import '../protocol/frames.dart';

/// Outcome of the HELLO handshake, before we decide whether to trust the peer.
class HelloInfo {
  final String id;
  final String name;
  final String platform;
  final Uint8List identityPk;
  HelloInfo(this.id, this.name, this.platform, this.identityPk);
}

/// One encrypted TCP connection to another Hopper device.
///
/// Wire format: every frame is `[u32 length][payload]`. The first two frames
/// (HELLO / HELLO_ACK) are plaintext CBOR carrying identity + ephemeral keys and
/// a signature. Every frame afterwards is XChaCha20-Poly1305 ciphertext.
class PeerConnection {
  final Socket socket;
  final Identity me;
  final String myName;
  final bool isInitiator;

  HelloInfo? remote;
  SecretKey? _key;
  final _reader = LengthPrefixedReader();
  final _incoming = StreamController<Map<String, Object?>>.broadcast();
  final _helloCompleter = Completer<HelloInfo>();
  StreamSubscription? _sub;
  bool _closed = false;
  Timer? _pingTimer;
  DateTime lastActivity = DateTime.now();

  PeerConnection(this.socket, this.me, this.myName, {required this.isInitiator}) {
    socket.setOption(SocketOption.tcpNoDelay, true);
    _sub = socket.listen(_onData, onError: (_) => close(), onDone: close);
  }

  Stream<Map<String, Object?>> get frames => _incoming.stream;
  bool get isOpen => !_closed;
  String get remoteAddress => '${socket.remoteAddress.address}:${socket.remotePort}';

  SimpleKeyPair? _eph;
  Uint8List? _ephPk;

  /// Sends our HELLO and waits for theirs. Returns the remote identity.
  Future<HelloInfo> handshake({Duration timeout = const Duration(seconds: 8)}) async {
    _eph = await CryptoService.newEphemeral();
    _ephPk = await CryptoService.ephemeralPublic(_eph!);
    final sig = await CryptoService.sign(me.keyPair, _ephPk!);
    _sendRaw(Frames.encode({
      't': isInitiator ? FrameType.hello : FrameType.helloAck,
      'v': protocolVersion,
      'id': me.id,
      'name': myName,
      'platform': Identity.platformName,
      'pk': me.publicKey,
      'epk': _ephPk,
      'sig': sig,
    }));
    return _helloCompleter.future.timeout(timeout, onTimeout: () {
      close();
      throw TimeoutException('handshake timed out');
    });
  }

  void _onData(Uint8List data) {
    lastActivity = DateTime.now();
    List<Uint8List> frames;
    try {
      frames = _reader.feed(data);
    } catch (_) {
      close();
      return;
    }
    for (final f in frames) {
      _handleFrame(f);
    }
  }

  Future<void> _handleFrame(Uint8List raw) async {
    try {
      if (_key == null) {
        final m = Frames.decode(raw);
        final t = m['t'];
        if (t != FrameType.hello && t != FrameType.helloAck) { close(); return; }
        final pk = m['pk'] as Uint8List, epk = m['epk'] as Uint8List, sig = m['sig'] as Uint8List;
        if (!await CryptoService.verify(pk, epk, sig)) { close(); return; }
        _key = await CryptoService.deriveSessionKey(_eph!, epk, _ephPk!);
        remote = HelloInfo(m['id'] as String, m['name'] as String, m['platform'] as String? ?? 'unknown', pk);
        if (!_helloCompleter.isCompleted) _helloCompleter.complete(remote);
        _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) => send({'t': FrameType.ping}));
        return;
      }
      final clear = await CryptoService.decrypt(_key!, raw);
      final m = Frames.decode(clear);
      if (m['t'] == FrameType.ping) { send({'t': FrameType.pong}); return; }
      if (m['t'] == FrameType.pong) return;
      _incoming.add(m);
    } catch (_) {
      close();
    }
  }

  void _sendRaw(Uint8List payload) {
    if (_closed) return;
    try { socket.add(LengthPrefixedReader.wrap(payload)); } catch (_) { close(); }
  }

  /// Encrypt and send a frame. Safe to call before/after close (no-op).
  Future<void> send(Map<String, Object?> frame) async {
    if (_closed || _key == null) return;
    final ct = await CryptoService.encrypt(_key!, Frames.encode(frame));
    _sendRaw(ct);
    try { await socket.flush(); } catch (_) {}
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _pingTimer?.cancel();
    _sub?.cancel();
    try { socket.destroy(); } catch (_) {}
    if (!_helloCompleter.isCompleted) _helloCompleter.completeError(StateError('closed'));
    _incoming.close();
  }
}
