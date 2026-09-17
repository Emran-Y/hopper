import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../platform/clipboard_service.dart';
import '../theme.dart';
import '../widgets/tour_overlay.dart';
import 'devices_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Main scaffold: bottom navigation on phones, a sidebar on desktop.
/// Also hosts global toasts, the sensitive-content confirm sheet and the first-run tour.
class Shell extends StatefulWidget {
  final bool showTour;
  const Shell({super.key, this.showTour = false});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _navKeys = List.generate(4, (_) => GlobalKey());
  final _sendKey = GlobalKey();
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppController>();
    _subs.add(app.toasts.stream.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
    }));
    _subs.add(app.sensitivePrompts.stream.listen(_askSensitive));
    if (widget.showTour) WidgetsBinding.instance.addPostFrameCallback((_) => Future.delayed(const Duration(milliseconds: 400), _startTour));
  }

  void _startTour() {
    if (!mounted) return;
    final desktop = ClipboardService.isDesktop;
    TourOverlay.start(context, [
      TourStep(target: _sendKey, title: 'Nothing to tap',
          text: desktop
              ? 'This card tells you sync is live. Copy anything on this computer and it is on your phone a second later; copy on the phone and it is here. That is the whole app.'
              : Platform.isAndroid
                  ? 'This card tells you sync is live. Clips from your computer land on this phone even when Hopper is closed, and after a one-time setup, copying here sends automatically too.'
                  : 'This card tells you sync is live. Opening Hopper sends whatever is new on your clipboard; clips from your computer arrive while it is open.'),
      TourStep(target: _navKeys[1], title: 'History',
          text: 'Everything that passed through, newest first. Tap to copy again, long-press for Send to…, Pin or Delete.'),
      TourStep(target: _navKeys[2], title: 'Devices',
          text: 'Pair another device, and decide per device whether clips flow two-way, one way, or only when you send by hand.'),
      TourStep(target: _navKeys[3], title: 'Settings',
          text: 'Pause syncing, the sensitive-content guard (holds back passwords and codes and asks first), appearance, this device\'s name, and the connection log.'),
    ]);
  }

  Future<void> _askSensitive(SensitivePrompt p) async {
    if (!mounted) return;
    final app = context.read<AppController>();
    final t = HopperTheme.of(context);
    final send = await showModalBottomSheet<bool>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.priority_high, color: HopperColors.accent)),
            const SizedBox(width: 12),
            Expanded(child: Text('This looks like ${p.reason}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
          ]),
          const SizedBox(height: 12),
          const Text('Hopper held it back instead of sending automatically. Send it anyway? It stays encrypted and is not kept in History on the receiving device.',
              style: TextStyle(height: 1.45)),
          const SizedBox(height: 14),
          Container(width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
              child: Text(_mask(p.clip.text ?? ''), textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send once'))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Don't send"))),
        ]),
      )),
    );
    if (send == true) await app.sendHeldClip(p.clip.id);
  }

  String _mask(String s) {
    if (s.length <= 4) return '••••';
    return '${s.substring(0, 2)}${'•' * (s.length - 4).clamp(3, 12)}${s.substring(s.length - 2)}';
  }

  @override
  void dispose() { for (final s in _subs) { s.cancel(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    final pages = [HomeScreen(sendKey: _sendKey), const HistoryScreen(), const DevicesScreen(), const SettingsScreen()];
    final dests = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.history_rounded, Icons.history_rounded, 'History'),
      (Icons.devices_other_outlined, Icons.devices_other_rounded, 'Devices'),
      (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
    ];

    if (wide) {
      return Scaffold(
        body: Row(children: [
          _SideBar(
            selected: _tab, onSelect: (i) => setState(() => _tab = i),
            items: [for (final (i, d) in dests.indexed) _SideItem(d.$1, d.$2, d.$3, _navKeys[i])],
          ),
          Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: pages[_tab]))),
        ]),
      );
    }
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final (i, d) in dests.indexed)
            NavigationDestination(icon: Icon(d.$1, key: _navKeys[i]), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}

class _SideItem {
  final IconData icon, selectedIcon;
  final String label;
  final GlobalKey key;
  _SideItem(this.icon, this.selectedIcon, this.label, this.key);
}

/// Desktop sidebar: brand, four compact items with a soft pill on the active one, and a
/// small live-status footer. Replaces NavigationRail, whose tall indicator looked off.
class _SideBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final List<_SideItem> items;
  const _SideBar({required this.selected, required this.onSelect, required this.items});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final t = HopperTheme.of(context);
    final connected = app.peers.where((p) => app.isConnected(p.id)).length;
    return Container(
      width: 200,
      decoration: BoxDecoration(color: t.card, border: Border(right: BorderSide(color: t.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 16, 18),
          child: Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: HopperColors.accent, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.content_copy_rounded, size: 15, color: Colors.white)),
            const SizedBox(width: 10),
            Text('Hopper', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.4, color: t.text)),
          ]),
        ),
        for (final (i, it) in items.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Material(
              color: i == selected ? t.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Icon(i == selected ? it.selectedIcon : it.icon, key: it.key, size: 20,
                        color: i == selected ? HopperColors.accent : t.muted),
                    const SizedBox(width: 12),
                    Text(it.label, style: TextStyle(
                        fontSize: 14, fontWeight: i == selected ? FontWeight.w700 : FontWeight.w600,
                        color: i == selected ? HopperColors.accentDeep : t.text)),
                  ]),
                ),
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 20),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
                color: app.settings.paused ? t.muted : connected > 0 ? HopperColors.accent : t.line)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              app.settings.paused ? 'Paused' : connected == 0 ? 'No device in range' : '$connected device${connected == 1 ? '' : 's'} connected',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.muted), overflow: TextOverflow.ellipsis,
            )),
          ]),
        ),
      ]),
    );
  }
}
