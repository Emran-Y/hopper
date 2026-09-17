import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../platform/clipboard_service.dart';
import '../theme.dart';

/// First-run walkthrough: a few swipeable pages explaining the app, with Skip.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AppController>().settings.deviceName);
  }

  List<_Page> get _pages {
    final desktop = ClipboardService.isDesktop;
    return [
      _Page(
        icon: Icons.content_copy_rounded,
        title: 'One clipboard for all your devices',
        body: 'Copy on your phone, paste on your PC — or the other way round. '
            'Hopper moves your clipboard between devices over Wi-Fi.',
        note: 'No internet, no account, no server. Just your devices talking to each other.',
      ),
      _Page(
        icon: Icons.wifi_rounded,
        title: 'Works completely offline',
        body: 'Both devices only need to be on the same Wi-Fi network — a home router with the '
            'internet cable unplugged is enough. Your phone\'s hotspot works too.',
        note: 'Bluetooth fallback for when there is no Wi-Fi at all is coming in v1.0.',
      ),
      _Page(
        icon: Icons.lock_rounded,
        title: 'Private by design',
        body: 'You pair devices once by scanning a QR code in the same room. After that, every clip '
            'is end-to-end encrypted — only your paired devices can read it.',
        note: 'Hopper spots things that look like passwords or one-time codes and asks before sending them.',
      ),
      _Page(
        icon: Icons.bolt_rounded,
        title: 'Copy here, paste there',
        body: desktop
            ? 'Everything you copy on this computer appears on your phone. Everything you copy on the phone appears here. No button, no app to open.'
            : Platform.isAndroid
                ? 'Everything you copy on your computer lands on this phone, even when Hopper is closed. A one-time, two-minute setup makes copying on this phone automatic too.'
                : 'Clips from your computer arrive while Hopper is open. To send, just open Hopper — whatever is new on your clipboard goes out. For iPhone ↔ Mac, Apple\'s own Universal Clipboard works with Handoff on.',
        note: 'Per device you can still pick Two-way, one way only, or Manual from the Devices tab.',
      ),
      _Page(
        icon: Icons.badge_outlined,
        title: 'Name this device',
        body: 'This is how it will appear on your other devices.',
        isNameStep: true,
      ),
    ];
  }

  void _finish() async {
    final app = context.read<AppController>();
    await app.setDeviceName(_name.text);
    await app.completeOnboarding();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final last = _page == pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(onPressed: _finish, child: const Text('Skip')),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _PageView(page: pages[i], nameCtrl: _name),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(children: [
                  Row(children: List.generate(pages.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _page ? 22 : 8, height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? HopperColors.accent : HopperTheme.of(context).line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ))),
                  const Spacer(),
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _ctrl.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: last ? _finish : () => _ctrl.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                    child: Text(last ? 'Get started' : 'Next'),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Page {
  final IconData icon;
  final String title, body;
  final String? note;
  final bool isNameStep;
  _Page({required this.icon, required this.title, required this.body, this.note, this.isNameStep = false});
}

class _PageView extends StatelessWidget {
  final _Page page;
  final TextEditingController nameCtrl;
  const _PageView({required this.page, required this.nameCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(color: HopperColors.accentSoft, borderRadius: BorderRadius.circular(22)),
          child: Icon(page.icon, size: 38, color: HopperColors.accent),
        ),
        const SizedBox(height: 28),
        Text(page.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.15)),
        const SizedBox(height: 14),
        Text(page.body, style: TextStyle(fontSize: 16, height: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .8))),
        if (page.note != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: HopperTheme.of(context).card2, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 18, color: HopperColors.mid),
              const SizedBox(width: 10),
              Expanded(child: Text(page.note!, style: const TextStyle(fontSize: 13.5, height: 1.45, color: HopperColors.mid))),
            ]),
          ),
        ],
        if (page.isNameStep) ...[
          const SizedBox(height: 18),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Device name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.devices)),
            textInputAction: TextInputAction.done,
          ),
        ],
      ]),
    );
  }
}
