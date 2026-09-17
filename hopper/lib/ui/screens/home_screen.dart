import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/models/models.dart';
import '../../platform/android_bridge.dart';
import '../../platform/clipboard_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/setup_card.dart';
import 'pair_screen.dart';

/// Home: is sync running, what came in last, what went out last, and the devices.
/// There is nothing to tap in normal use — sending is automatic; a manual
/// "Send clipboard now" lives in the ⋮ menu as a fallback.
class HomeScreen extends StatefulWidget {
  final GlobalKey? sendKey, devicesKey;
  const HomeScreen({super.key, this.sendKey, this.devicesKey});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _androidAuto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSetup();
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSetup();
  }

  Future<void> _refreshSetup() async {
    if (!Platform.isAndroid) return;
    final s = await AndroidBridge.setupStatus();
    final ok = s['readLogs'] == true && s['overlay'] == true && s['watcher'] == true;
    if (mounted && ok != _androidAuto) setState(() => _androidAuto = ok);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final connected = app.peers.where((p) => app.isConnected(p.id)).toList();
    final lastReceived = app.history.cast<Clip?>().firstWhere((c) => c!.originId != app.identity.id, orElse: () => null);
    final lastSent = app.history.cast<Clip?>().firstWhere(
        (c) => c!.originId == app.identity.id && c.delivery.values.any((v) => v == 'sent' || v == 'delivered'),
        orElse: () => null);
    final desktop = ClipboardService.isDesktop;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hopper'),
        actions: [
          if (app.settings.paused)
            const Padding(padding: EdgeInsets.only(right: 4), child: Center(child: Pill.accent('Paused'))),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'send': app.sendCurrentClipboard();
                case 'pair': PairScreen.open(context);
                case 'pause': app.setPaused(!app.settings.paused);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'send', child: ListTile(dense: true, leading: Icon(Icons.send_rounded), title: Text('Send clipboard now'))),
              PopupMenuItem(value: 'pause', child: ListTile(dense: true, leading: Icon(app.settings.paused ? Icons.play_arrow : Icons.pause),
                  title: Text(app.settings.paused ? 'Resume syncing' : 'Pause syncing'))),
              const PopupMenuItem(value: 'pair', child: ListTile(dense: true, leading: Icon(Icons.add_link), title: Text('Pair a device'))),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await _refreshSetup(); setState(() {}); },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          if (app.peers.isEmpty)
            _EmptyPairCard(onPair: () => PairScreen.open(context))
          else
            _StatusHero(key: widget.sendKey, connected: connected, paused: app.settings.paused,
                desktop: desktop, androidAuto: _androidAuto),
          const SizedBox(height: 12),

          if (!desktop && app.peers.isNotEmpty) ...[const SetupCard(), const SizedBox(height: 12)],

          if (lastReceived != null) ...[
            _ClipCard(
              clip: lastReceived, dark: true,
              label: 'Last received · ${lastReceived.originName} · ${timeAgo(lastReceived.createdAt)}',
              action: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                onPressed: () => app.copyToLocalClipboard(lastReceived),
                icon: Icon(lastReceived.type == ClipType.file ? Icons.download : Icons.copy, size: 18),
                label: Text(lastReceived.type == ClipType.file ? 'Save again' : 'Copy again'),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (lastSent != null) ...[
            _ClipCard(
              clip: lastSent, dark: false,
              label: 'Last sent · ${timeAgo(lastSent.createdAt)}',
              trailing: Wrap(spacing: 6, children: [
                for (final e in lastSent.delivery.entries)
                  if (app.peerById(e.key) != null)
                    Pill.ok('${app.peerById(e.key)!.name} ✓'),
              ]),
            ),
            const SizedBox(height: 4),
          ],

          if (app.peers.isNotEmpty) ...[
            SectionTitle('Devices', trailing: TextButton.icon(
                onPressed: () => PairScreen.open(context), icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
            Card(
              key: widget.devicesKey,
              child: Column(children: [
                for (final (i, p) in app.peers.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(platformIcon(p.platform)),
                    title: Row(children: [
                      StatusDot(app.isConnected(p.id)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                    ]),
                    subtitle: Text('${p.rules.direction.label} · ${[
                      if (p.rules.allowText) 'text', if (p.rules.allowLinks) 'links', if (p.rules.allowImages) 'images', if (p.rules.allowFiles) 'files'
                    ].join(', ')}'),
                    trailing: app.isConnected(p.id) ? const Pill.ok('connected') : const Pill('not in range'),
                  ),
                ],
              ]),
            ),
          ],

          if (app.lastError != null) ...[
            const SizedBox(height: 12),
            Card(color: HopperColors.accentSoft, child: Padding(padding: const EdgeInsets.all(12),
                child: Text(app.lastError!, style: const TextStyle(color: Color(0xFFB8401A))))),
          ],
        ]),
      ),
    );
  }
}

/// The big "is it working?" card.
class _StatusHero extends StatelessWidget {
  final List<Peer> connected;
  final bool paused, desktop, androidAuto;
  const _StatusHero({super.key, required this.connected, required this.paused, required this.desktop, required this.androidAuto});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final on = connected.isNotEmpty && !paused;
    final names = connected.map((p) => p.name).join(', ');
    final String title, body;
    final IconData icon;
    if (paused) {
      title = 'Paused'; icon = Icons.pause_circle_outline;
      body = 'Nothing is sent or received. Resume from the ⋮ menu or Settings.';
    } else if (connected.isEmpty) {
      title = 'Waiting for a device'; icon = Icons.wifi_find;
      body = 'None of your paired devices is in range. Both need to be on the same Wi‑Fi and running Hopper.';
    } else if (desktop) {
      title = 'Syncing automatically'; icon = Icons.sync;
      body = 'Everything you copy here goes to $names, and whatever they copy lands on your clipboard. ⌘V and go.';
    } else if (Platform.isAndroid) {
      title = androidAuto ? 'Syncing automatically' : 'Receiving from $names'; icon = androidAuto ? Icons.sync : Icons.download_done;
      body = androidAuto
          ? 'Copy anywhere on this phone — it is on $names a second later. Clips from there land here even when Hopper is closed.'
          : 'Clips from $names arrive here automatically. Finish the setup below so copying on this phone sends automatically too.';
    } else {
      title = 'Connected to $names'; icon = Icons.sync;
      body = 'Opening Hopper sends whatever is new on the clipboard. Clips from $names arrive while Hopper is open.';
    }
    final bg = on ? HopperTheme.of(context).accentSoft : null;
    final fg = on ? HopperColors.accent : HopperColors.mid;
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: on ? HopperColors.accent : HopperTheme.of(context).card2, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: on ? Colors.white : HopperColors.mid),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatusDot(on),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: on ? fg : null))),
            ]),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(height: 1.45, fontSize: 13.5, color: dark ? Colors.white70 : HopperColors.ink2)),
          ])),
        ]),
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  final Clip clip;
  final bool dark;
  final String label;
  final Widget? action, trailing;
  const _ClipCard({required this.clip, required this.dark, required this.label, this.action, this.trailing});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : null;
    final sub = dark ? Colors.white70 : HopperColors.mid;
    return Card(
      color: dark ? HopperColors.ink : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(clipIcon(clip.type), size: 14, color: sub), const SizedBox(width: 6),
            Expanded(child: Text(label, style: TextStyle(color: sub, fontSize: 12), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          Text(clip.preview, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16, height: 1.3)),
          if (action != null || trailing != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (action != null) action!,
              if (trailing != null) Expanded(child: trailing!),
              if (action != null) ...[
                const Spacer(),
                Icon(Icons.lock, size: 14, color: sub), const SizedBox(width: 4),
                Text('encrypted', style: TextStyle(color: sub, fontSize: 12)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

class _EmptyPairCard extends StatelessWidget {
  final VoidCallback onPair;
  const _EmptyPairCard({required this.onPair});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: HopperColors.accentSoft, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.qr_code_2, color: HopperColors.accent),
            ),
            const SizedBox(height: 14),
            const Text('Pair your first device', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Install Hopper on your other device, make sure both are on the same Wi-Fi, then pair with a QR code or a 6-digit code. After that, copying on one device is pasting on the other.',
                style: TextStyle(color: HopperColors.mid, height: 1.45)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onPair, icon: const Icon(Icons.add_link), label: const Text('Pair a device')),
          ]),
        ),
      );
}
