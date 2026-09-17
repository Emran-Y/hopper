import 'dart:io';

import 'package:flutter/material.dart';

import '../../platform/android_bridge.dart';
import '../theme.dart';

/// Phone-only card on the Home tab that walks through what automatic sync needs.
class SetupCard extends StatefulWidget {
  const SetupCard({super.key});
  @override
  State<SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends State<SetupCard> with WidgetsBindingObserver {
  Map<String, dynamic> _s = {};

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _refresh(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _refresh(); }

  Future<void> _refresh() async {
    if (!Platform.isAndroid) return;
    final s = await AndroidBridge.setupStatus();
    if (mounted) setState(() => _s = s);
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) return _iosCard(context);
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final notif = _s['notifications'] == true, battery = _s['battery'] == true,
        overlay = _s['overlay'] == true, logs = _s['readLogs'] == true, watcher = _s['watcher'] == true;
    final allDone = notif && battery && overlay && logs && watcher;
    if (allDone) {
      return const SizedBox.shrink(); // the status hero on Home already says sync is on
    }
    return Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Finish automatic sync setup', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const SizedBox(height: 4),
      const Text('Android blocks apps from reading the clipboard in the background. These four steps let Hopper do it anyway — once.',
          style: TextStyle(color: HopperColors.mid, fontSize: 12.5, height: 1.4)),
      const SizedBox(height: 6),
      _row(notif, 'Notifications', 'Shows the small "syncing" notice that keeps Hopper alive.',
          TextButton(onPressed: () async { await AndroidBridge.requestNotifications(); _refresh(); }, child: const Text('Allow'))),
      _row(battery, 'Battery: unrestricted', 'Stops One UI from killing Hopper in the background.',
          TextButton(onPressed: () async { await AndroidBridge.requestBattery(); }, child: const Text('Fix'))),
      _row(overlay, 'Appear on top', 'Lets Hopper grab the clipboard for a split second after you copy.',
          TextButton(onPressed: () async { await AndroidBridge.openOverlaySettings(); }, child: const Text('Open'))),
      _row(logs, 'One-time USB step', 'Plug the phone into your Mac (USB debugging on) and run  tool/android-setup.sh  in the Hopper folder. Also works over Wireless debugging.',
          null),
      if (logs) _row(watcher, 'Allow log access (each time the phone restarts)', 'A few seconds after Hopper opens, Android asks "Allow Hopper to access all device logs?" — tap Allow one-time access. That is what lets Hopper notice when you copy. If you missed it, tap Enable.',
          TextButton(onPressed: () async {
            await AndroidBridge.startWatcher();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 8), content: Text(
                'Android should now ask "Allow Hopper to access all device logs?" — tap Allow one-time access. '
                'If nothing appears, Android is still holding an earlier unanswered request: leave Hopper, wait about 7 minutes, then open it again.')));
            }
            await Future.delayed(const Duration(seconds: 3));
            _refresh();
          }, child: const Text('Enable'))),
    ])));
  }

  Widget _row(bool ok, String title, String sub, Widget? action) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: ok ? HopperColors.accent : HopperColors.mid)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: ok ? HopperColors.mid : null, decoration: ok ? TextDecoration.lineThrough : null)),
            if (!ok) Text(sub, style: const TextStyle(color: HopperColors.mid, fontSize: 12, height: 1.35)),
          ])),
          if (!ok && action != null) action,
        ]),
      );

  Widget _iosCard(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('How sync works on iPhone', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        SizedBox(height: 6),
        Text('• iPhone ↔ Mac: turn on Handoff (Settings → General → AirPlay & Continuity) on both. Apple\'s Universal Clipboard then syncs the clipboard with zero taps, and Hopper on the Mac passes it on to your other devices.\n'
            '• iPhone → other devices directly: copy, then open Hopper — whatever is new on the clipboard is sent the moment the app appears. Add "Open Hopper" to Back Tap for a no-look gesture.\n'
            '• Receiving: clips arrive while Hopper is open. iOS does not allow more than that for any app.\n'
            '• To stop the "Allow paste?" prompt: Settings → Hopper → Paste from Other Apps → Allow.',
            style: TextStyle(color: HopperColors.mid, fontSize: 12.5, height: 1.45)),
      ])));
}
