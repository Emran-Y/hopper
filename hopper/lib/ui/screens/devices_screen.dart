import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pair_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final nearby = app.discovery.devices.values.where((d) => d.id != app.identity.id && app.peerById(d.id) == null).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PairScreen.open(context),
        backgroundColor: HopperColors.accent, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Pair device'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
        if (app.peers.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Text(
              'No paired devices. Tap "Pair device" to connect your phone and PC.',
              textAlign: TextAlign.center, style: TextStyle(color: HopperColors.mid, height: 1.5))),
        for (final p in app.peers) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              leading: Icon(platformIcon(p.platform), size: 28),
              title: Row(children: [
                StatusDot(app.isConnected(p.id)),
                const SizedBox(width: 8),
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${p.rules.direction.label}\n${app.isConnected(p.id)
                    ? 'Connected · ${app.connections[p.id]!.remoteAddress}'
                    : p.lastSeenAt != null ? 'Last seen ${timeAgo(p.lastSeenAt!)}' : 'Never connected'}'),
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceDetailScreen(peerId: p.id))),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (nearby.isNotEmpty) ...[
          const SectionTitle('Nearby, not paired'),
          Card(child: Column(children: [
            for (final d in nearby)
              ListTile(
                leading: Icon(platformIcon(d.platform), color: HopperColors.mid),
                title: Text(d.name),
                subtitle: Text('${d.host} · ${d.pairing ? 'in pairing mode' : 'running Hopper'}'),
                trailing: d.pairing
                    ? TextButton(onPressed: () => PairScreen.open(context, joinDevice: d), child: const Text('Pair'))
                    : null,
              ),
          ])),
        ],
        const SectionTitle('This device'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app.settings.deviceName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Fingerprint ${Peer.fingerprintOf(app.identity.publicKey)} · port ${app.transport.port}',
              style: const TextStyle(color: HopperColors.mid, fontSize: 12)),
          FutureBuilder(future: Future.value(app.discovery.devices.length), builder: (_, __) => const SizedBox.shrink()),
        ]))),
      ]),
    );
  }
}

class DeviceDetailScreen extends StatelessWidget {
  final String peerId;
  const DeviceDetailScreen({super.key, required this.peerId});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final p = app.peerById(peerId);
    if (p == null) return const Scaffold(body: Center(child: Text('Device removed')));
    final r = p.rules;

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        Row(children: [
          StatusDot(app.isConnected(p.id)),
          const SizedBox(width: 8),
          Text(app.isConnected(p.id) ? 'Connected over Wi-Fi' : 'Not in range',
              style: const TextStyle(color: HopperColors.mid, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${p.platform} · paired ${timeAgo(p.pairedAt)}', style: const TextStyle(color: HopperColors.mid, fontSize: 12)),
        ]),

        const SectionTitle('Sync direction'),
        Card(child: Column(children: [
          for (final d in SyncDirection.values)
            RadioListTile<SyncDirection>(
              value: d, groupValue: r.direction, activeColor: HopperColors.accent,
              title: Text(_dirLabel(d, p), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_dirDesc(d, p)),
              onChanged: (v) => app.updateRules(p, (r) => r.direction = v!),
            ),
        ])),

        const SectionTitle('What to sync'),
        Card(child: Column(children: [
          SwitchListTile(title: const Text('Text'), value: r.allowText, onChanged: (v) => app.updateRules(p, (r) => r.allowText = v)),
          const Divider(height: 1),
          SwitchListTile(title: const Text('Links'), value: r.allowLinks, onChanged: (v) => app.updateRules(p, (r) => r.allowLinks = v)),
          const Divider(height: 1),
          SwitchListTile(title: const Text('Images'), subtitle: Text('Up to ${Clip.fmtSize(r.maxSizeBytes)}'),
              value: r.allowImages, onChanged: (v) => app.updateRules(p, (r) => r.allowImages = v)),
          const Divider(height: 1),
          ListTile(
            title: const Text('Image size limit'),
            trailing: DropdownButton<int>(
              value: r.maxSizeBytes, underline: const SizedBox.shrink(),
              items: [5, 10, 25, 50, 100].map((m) => DropdownMenuItem(value: m * 1024 * 1024, child: Text('$m MB'))).toList(),
              onChanged: (v) => app.updateRules(p, (r) => r.maxSizeBytes = v!),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(title: const Text('Files'), subtitle: Text('Copied in Finder / shared from the phone · up to ${Clip.fmtSize(r.maxFileBytes)}'),
              value: r.allowFiles, onChanged: (v) => app.updateRules(p, (r) => r.allowFiles = v)),
          const Divider(height: 1),
          ListTile(
            title: const Text('File size limit'),
            trailing: DropdownButton<int>(
              value: r.maxFileBytes, underline: const SizedBox.shrink(),
              items: [10, 25, 50, 100].map((m) => DropdownMenuItem(value: m * 1024 * 1024, child: Text('$m MB'))).toList(),
              onChanged: (v) => app.updateRules(p, (r) => r.maxFileBytes = v!),
            ),
          ),
        ])),

        const SectionTitle('Notifications'),
        Card(child: SwitchListTile(title: const Text('Notify when I receive a clip'), value: r.notify,
            onChanged: (v) => app.updateRules(p, (r) => r.notify = v))),

        const SectionTitle('Security'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Verification emoji', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(app.emojiCheckFor(p), style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          const Text('Open this screen on both devices — the four emoji must match.', style: TextStyle(color: HopperColors.mid, fontSize: 12.5)),
          const SizedBox(height: 10),
          Text('Key fingerprint ${p.fingerprint}', style: const TextStyle(color: HopperColors.mid, fontSize: 12)),
        ]))),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => _confirmUnpair(context, app, p),
          icon: const Icon(Icons.link_off), label: const Text('Unpair this device'),
        ),
      ]),
    );
  }

  String _dirLabel(SyncDirection d, Peer p) => switch (d) {
        SyncDirection.twoWay => 'Two-way',
        SyncDirection.toPeer => 'This device → ${p.name}',
        SyncDirection.fromPeer => '${p.name} → this device',
        SyncDirection.manual => 'Manual',
      };
  String _dirDesc(SyncDirection d, Peer p) => switch (d) {
        SyncDirection.twoWay => 'Clips flow both ways automatically.',
        SyncDirection.toPeer => 'Only what you copy here goes to ${p.name}.',
        SyncDirection.fromPeer => 'Only what ${p.name} copies arrives here.',
        SyncDirection.manual => 'Nothing automatic. Use Send or "Send to…" in History.',
      };

  void _confirmUnpair(BuildContext context, AppController app, Peer p) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Unpair ${p.name}?'),
      content: const Text('The device\'s key is deleted and it will no longer be able to connect. You can pair again any time.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async { Navigator.pop(ctx); await app.unpair(p); if (context.mounted) Navigator.pop(context); },
            child: const Text('Unpair')),
      ],
    ));
  }
}
