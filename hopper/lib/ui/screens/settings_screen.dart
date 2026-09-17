import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../platform/clipboard_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = app.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        const SectionTitle('Sync'),
        Card(child: Column(children: [
          SwitchListTile(
            title: const Text('Pause all syncing'),
            subtitle: const Text('Nothing is sent or received while paused.'),
            value: s.paused, onChanged: app.setPaused,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Sensitive-content guard'),
            subtitle: const Text('Ask before sending things that look like passwords, one-time codes or card numbers.'),
            value: s.sensitiveGuard, onChanged: (v) { s.sensitiveGuard = v; app.saveSettings(); },
          ),
        ])),

        const SectionTitle('History'),
        Card(child: ListTile(
          title: const Text('Keep the last'),
          trailing: DropdownButton<int>(
            value: s.historyLimit, underline: const SizedBox.shrink(),
            items: [50, 100, 200, 500].map((n) => DropdownMenuItem(value: n, child: Text('$n clips'))).toList(),
            onChanged: (v) { s.historyLimit = v!; app.saveSettings(); },
          ),
        )),

        const SectionTitle('Appearance'),
        Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'system', label: Text('System'), icon: Icon(Icons.brightness_auto, size: 16)),
              ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(Icons.light_mode, size: 16)),
              ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(Icons.dark_mode, size: 16)),
            ],
            selected: {s.theme},
            onSelectionChanged: (v) { s.theme = v.first; app.saveSettings(); },
          )),
        ]))),

        const SectionTitle('General'),
        Card(child: Column(children: [
          ListTile(
            title: const Text('Device name'),
            subtitle: Text(s.deviceName),
            trailing: const Icon(Icons.edit, size: 18),
            onTap: () => _editName(context, app),
          ),
          if (ClipboardService.isDesktop) ...[
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Start minimized to tray'),
              subtitle: const Text('Hopper keeps running in the system tray when you close the window.'),
              value: s.startMinimized, onChanged: (v) { s.startMinimized = v; app.saveSettings(); },
            ),
          ],
          const Divider(height: 1),
          ListTile(
            title: const Text('Show the welcome tour again'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => OnboardingScreen(onDone: () => Navigator.pop(context)))),
          ),
        ])),

        const SectionTitle('Diagnostics'),
        Card(child: ListTile(
          title: const Text('Connection log'),
          subtitle: Text('Port ${app.transport.port} · ${app.discovery.devices.length} device(s) seen on this network'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _LogScreen())),
        )),

        const SizedBox(height: 24),
        const Center(child: Text('Hopper 0.1.0 · offline clipboard · no servers involved',
            style: TextStyle(color: HopperColors.mid, fontSize: 12))),
      ]),
    );
  }

  void _editName(BuildContext context, AppController app) {
    final c = TextEditingController(text: app.settings.deviceName);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Device name'),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { Navigator.pop(ctx); app.setDeviceName(c.text); }, child: const Text('Save')),
      ],
    ));
  }
}

class _LogScreen extends StatelessWidget {
  const _LogScreen();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Connection log')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: app.log.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(app.log[i], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      ),
    );
  }
}
