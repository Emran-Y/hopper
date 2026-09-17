import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

/// A Hopper device seen on the local network.
class DiscoveredDevice {
  final String id;
  final String name;
  final String platform;
  final String fingerprint;
  final String host;
  final int port;
  final bool pairing;
  DiscoveredDevice({required this.id, required this.name, required this.platform, required this.fingerprint,
      required this.host, required this.port, required this.pairing});
}

/// mDNS / DNS-SD advertisement + browsing for `_hopper._tcp`.
class Discovery {
  static const serviceType = '_hopper._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  final devices = <String, DiscoveredDevice>{};
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  Future<void> advertise({
    required String id, required String name, required String platform,
    required String fingerprint, required int port, bool pairing = false,
  }) async {
    await stopAdvertising();
    final service = BonsoirService(
      name: 'Hopper-${id.substring(0, 8)}',
      type: serviceType,
      port: port,
      attributes: {'v': '1', 'id': id, 'n': name, 'p': platform, 'fp': fingerprint, 'pair': pairing ? '1' : '0'},
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
  }

  Future<void> stopAdvertising() async {
    try { await _broadcast?.stop(); } catch (_) {}
    _broadcast = null;
  }

  Future<void> startBrowsing() async {
    if (_discovery != null) return;
    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.ready;
    _discovery!.eventStream!.listen((event) {
      final s = event.service;
      if (s == null) return;
      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        s.resolve(_discovery!.serviceResolver);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        final a = s.attributes;
        final id = a['id'];
        final host = (s is ResolvedBonsoirService) ? s.host : null;
        if (id == null || host == null) return;
        devices[id] = DiscoveredDevice(
          id: id, name: a['n'] ?? s.name, platform: a['p'] ?? 'unknown', fingerprint: a['fp'] ?? '',
          host: host, port: s.port, pairing: a['pair'] == '1',
        );
        _changes.add(null);
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        final id = s.attributes['id'];
        if (id != null) { devices.remove(id); _changes.add(null); }
      }
    });
    await _discovery!.start();
  }

  Future<void> stop() async {
    await stopAdvertising();
    try { await _discovery?.stop(); } catch (_) {}
    _discovery = null;
  }
}
