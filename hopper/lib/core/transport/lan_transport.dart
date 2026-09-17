import 'dart:async';
import 'dart:io';

import '../identity.dart';
import 'peer_connection.dart';

/// Listens for incoming connections and dials peers on the local network.
class LanTransport {
  final Identity me;
  String Function() nameProvider;
  ServerSocket? _server;
  final _incoming = StreamController<PeerConnection>.broadcast();

  static const preferredPort = 47331;

  LanTransport(this.me, this.nameProvider);

  Stream<PeerConnection> get incoming => _incoming.stream;
  int get port => _server?.port ?? 0;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, preferredPort, shared: true);
    } on SocketException {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0, shared: true);
    }
    _server!.listen((socket) {
      _incoming.add(PeerConnection(socket, me, nameProvider(), isInitiator: false));
    });
  }

  Future<PeerConnection> connect(String host, int port, {Duration timeout = const Duration(seconds: 5)}) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    return PeerConnection(socket, me, nameProvider(), isInitiator: true);
  }

  /// Best-effort list of this machine's LAN IPv4 addresses.
  static Future<List<String>> localAddresses() async {
    final out = <String>[];
    try {
      for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false)) {
        for (final a in iface.addresses) {
          if (!a.isLoopback) out.add(a.address);
        }
      }
    } catch (_) {}
    // Prefer private ranges first.
    out.sort((a, b) {
      int rank(String s) => s.startsWith('192.168.') ? 0 : s.startsWith('10.') ? 1 : s.startsWith('172.') ? 2 : 3;
      return rank(a).compareTo(rank(b));
    });
    return out;
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}
