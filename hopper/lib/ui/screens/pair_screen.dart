import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_controller.dart';
import '../../core/transport/discovery.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pairing: either *show* a code on this device, or *join* another device
/// by scanning its QR / picking it from the list and typing its code.
class PairScreen extends StatefulWidget {
  final DiscoveredDevice? joinDevice;
  const PairScreen({super.key, this.joinDevice});

  static void open(BuildContext context, {DiscoveredDevice? joinDevice}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PairScreen(joinDevice: joinDevice)));

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static bool get _canScan => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    // Phones default to "Join" (scan); PCs default to "Show code".
    final startOnJoin = widget.joinDevice != null || Platform.isAndroid || Platform.isIOS;
    _tabs = TabController(length: 2, vsync: this, initialIndex: startOnJoin ? 1 : 0);
  }

  late final AppController _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = context.read<AppController>();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _app.stopPairing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair a device'),
        bottom: TabBar(controller: _tabs, indicatorColor: HopperColors.accent, labelColor: HopperColors.accent,
            tabs: const [Tab(text: 'Show code'), Tab(text: 'Join a device')]),
      ),
      body: TabBarView(controller: _tabs, children: [
        const _HostTab(),
        _JoinTab(initialDevice: widget.joinDevice, canScan: _canScan),
      ]),
    );
  }
}

// ---------------------------------------------------------------- HOST
class _HostTab extends StatefulWidget {
  const _HostTab();
  @override
  State<_HostTab> createState() => _HostTabState();
}

class _HostTabState extends State<_HostTab> {
  Timer? _tick;
  int _left = 60;
  int _peersAtStart = 0;

  @override
  void initState() {
    super.initState();
    _peersAtStart = context.read<AppController>().peers.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final p = context.read<AppController>().activePairing;
      if (mounted) setState(() => _left = p == null ? 0 : p.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 60));
    });
  }

  Future<void> _start() async => context.read<AppController>().startPairing();

  @override
  void dispose() { _tick?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final p = app.activePairing;
    if (p == null) {
      // Pairing ended: either a device just paired (show it), or we are still starting up.
      if (app.peers.length > _peersAtStart) {
        final peer = app.peers.last;
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: HopperTheme.of(context).accentSoft, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.check_rounded, color: HopperColors.accent, size: 36)),
            const SizedBox(height: 18),
            Text('Paired with ${peer.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('Check that these four emoji match on the other device:', textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(app.emojiCheckFor(peer), style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 22),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            TextButton(onPressed: () { setState(() => _peersAtStart = app.peers.length); _start(); }, child: const Text('Pair another device')),
          ]),
        )));
      }
      return const Center(child: CircularProgressIndicator());
    }
    final code = '${p.code.substring(0, 3)} ${p.code.substring(3)}';
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('On your other device open Hopper → Pair a device → Join, then scan this code or type the 6 digits.',
          style: TextStyle(color: HopperColors.mid, height: 1.5)),
      const SizedBox(height: 20),
      Center(child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HopperTheme.of(context).line)),
        child: QrImageView(data: p.toQrPayload(), size: 230, backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: HopperColors.ink),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: HopperColors.ink)),
      )),
      const SizedBox(height: 20),
      Center(child: Text(code, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 6))),
      const SizedBox(height: 6),
      Center(child: Text('Code changes in $_left s · works only once', style: const TextStyle(color: HopperColors.mid, fontSize: 12))),
      const SizedBox(height: 24),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const StatusDot(true), const SizedBox(width: 8),
            Text('Listening on ${p.hosts.isEmpty ? '(no Wi-Fi address found)' : p.hosts.join(', ')} · port ${p.port}',
                style: const TextStyle(fontSize: 12.5))]),
        const SizedBox(height: 6),
        const Row(children: [StatusDot(false), SizedBox(width: 8), Text('Waiting for the other device…', style: TextStyle(fontSize: 12.5))]),
      ]))),
      const SizedBox(height: 12),
      const Text('Both devices must be on the same Wi-Fi. If you see no address above, connect this device to Wi-Fi first.',
          style: TextStyle(color: HopperColors.mid, fontSize: 12.5, height: 1.4)),
    ]);
  }
}

// ---------------------------------------------------------------- JOIN
class _JoinTab extends StatefulWidget {
  final DiscoveredDevice? initialDevice;
  final bool canScan;
  const _JoinTab({this.initialDevice, required this.canScan});
  @override
  State<_JoinTab> createState() => _JoinTabState();
}

class _JoinTabState extends State<_JoinTab> {
  bool _busy = false;
  bool _scanning = true;
  String? _error;
  DiscoveredDevice? _picked;
  final _code = TextEditingController();
  MobileScannerController? _scanner;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialDevice;
    if (widget.canScan && _picked == null) _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  }

  @override
  void dispose() { _scanner?.dispose(); _code.dispose(); super.dispose(); }

  Future<void> _onScan(BarcodeCapture cap) async {
    if (_busy) return;
    final raw = cap.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    final info = PairingInfo.parse(raw);
    if (info == null) { setState(() => _error = 'That is not a Hopper pairing code.'); return; }
    await _scanner?.stop();
    await _pair(hosts: info.hosts, port: info.port, code: info.code, expectedPk: info.hostPk, name: info.hostName);
  }

  Future<void> _pairWithCode() async {
    final d = _picked;
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    if (d == null) { setState(() => _error = 'Pick the device you want to pair with.'); return; }
    if (code.length != 6) { setState(() => _error = 'Enter the 6-digit code shown on the other device.'); return; }
    await _pair(hosts: [d.host], port: d.port, code: code, name: d.name);
  }

  Future<void> _pair({required List<String> hosts, required int port, required String code, dynamic expectedPk, required String name}) async {
    setState(() { _busy = true; _error = null; });
    final app = context.read<AppController>();
    try {
      final peer = await app.pairWith(hosts: hosts, port: port, code: code, expectedPk: expectedPk);
      if (!mounted) return;
      await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text('Paired with ${peer.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Check that these four emoji match on both devices:'),
          const SizedBox(height: 12),
          Center(child: Text(app.emojiCheckFor(peer), style: const TextStyle(fontSize: 34))),
          const SizedBox(height: 12),
          const Text('You can change the sync direction any time from the Devices tab.',
              style: TextStyle(color: HopperColors.mid, fontSize: 13)),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Bad state: ', ''); _busy = false; });
      _scanner?.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final candidates = app.discovery.devices.values
        .where((d) => d.id != app.identity.id && app.peerById(d.id) == null).toList()
      ..sort((a, b) => (b.pairing ? 1 : 0) - (a.pairing ? 1 : 0));

    return ListView(padding: const EdgeInsets.all(20), children: [
      if (widget.canScan && _picked == null) ...[
        Row(children: [
          const Expanded(child: Text('Scan the QR code shown on the other device', style: TextStyle(fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => setState(() => _scanning = !_scanning), child: Text(_scanning ? 'Hide camera' : 'Show camera')),
        ]),
        if (_scanning) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 260, child: Stack(fit: StackFit.expand, children: [
              MobileScanner(controller: _scanner, onDetect: _onScan,
                  errorBuilder: (ctx, err, _) => Container(color: HopperColors.soft, alignment: Alignment.center,
                      padding: const EdgeInsets.all(16),
                      child: Text('Camera unavailable (${err.errorCode.name}). Use the code below instead.',
                          textAlign: TextAlign.center, style: const TextStyle(color: HopperColors.mid)))),
              IgnorePointer(child: Center(child: Container(width: 190, height: 190,
                  decoration: BoxDecoration(border: Border.all(color: HopperColors.accent, width: 3), borderRadius: BorderRadius.circular(18))))),
            ])),
          ),
        ],
        const SizedBox(height: 22),
        const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or use the 6-digit code', style: TextStyle(color: HopperColors.mid, fontSize: 12))), Expanded(child: Divider())]),
        const SizedBox(height: 14),
      ],

      const Text('1. Pick the device', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (candidates.isEmpty)
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: const [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(child: Text('Looking for Hopper devices on this Wi-Fi… Open "Show code" on the other device.',
              style: TextStyle(color: HopperColors.mid, height: 1.4))),
        ]))),
      Card(child: Column(children: [
        for (final d in candidates)
          RadioListTile<String>(
            value: d.id, groupValue: _picked?.id, activeColor: HopperColors.accent,
            title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${d.platform} · ${d.host}${d.pairing ? ' · showing a code now' : ''}'),
            secondary: Icon(platformIcon(d.platform)),
            onChanged: (_) => setState(() => _picked = d),
          ),
      ])),
      const SizedBox(height: 18),
      const Text('2. Type the code it shows', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextField(
        controller: _code, keyboardType: TextInputType.number, maxLength: 7,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 6),
        decoration: const InputDecoration(hintText: '000 000', border: OutlineInputBorder(), counterText: ''),
        textAlign: TextAlign.center,
        onSubmitted: (_) => _pairWithCode(),
      ),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _busy ? null : _pairWithCode,
        icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.link),
        label: Text(_busy ? 'Pairing…' : 'Pair'),
      )),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: HopperColors.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFB8401A)))),
      ],
    ]);
  }
}
