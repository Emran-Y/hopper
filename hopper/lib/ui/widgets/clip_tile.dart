import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/models/models.dart';
import '../theme.dart';
import 'common.dart';

class ClipTile extends StatelessWidget {
  final Clip clip;
  const ClipTile(this.clip, {super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final mine = clip.originId == app.identity.id;
    final subtitle = [
      mine ? 'This device' : 'From ${clip.originName}',
      timeAgo(clip.createdAt),
      if (clip.type == ClipType.image || clip.type == ClipType.file) Clip.fmtSize(clip.size),
      ..._deliverySummary(app),
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: clip.type == ClipType.image || clip.type == ClipType.file ? HopperTheme.of(context).blueSoft : HopperTheme.of(context).card2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(clipIcon(clip.type), color: clip.type == ClipType.image || clip.type == ClipType.file ? HopperColors.blue : HopperTheme.of(context).muted, size: 20),
      ),
      title: Row(children: [
        if (clip.pinned) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.push_pin, size: 14, color: HopperColors.mid)),
        Expanded(child: Text(clip.preview, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
      ]),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      onTap: () => app.copyToLocalClipboard(clip),
      onLongPress: () => showClipMenu(context, clip),
      trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () => showClipMenu(context, clip)),
    );
  }

  List<String> _deliverySummary(AppController app) {
    final sent = clip.delivery.entries.where((e) => e.value == 'sent' || e.value == 'delivered').length;
    if (sent == 0) return [];
    return ['sent to $sent'];
  }

  static void showClipMenu(BuildContext context, Clip clip) {
    final app = context.read<AppController>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(clip.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${clip.type.name} · ${timeAgo(clip.createdAt)}'),
          ),
          if (clip.type == ClipType.image)
            FutureBuilder(
              future: clip.bytes != null ? Future.value(clip.bytes) : app.store.loadImage(clip.blobPath),
              builder: (c, s) => s.data == null ? const SizedBox.shrink()
                  : Padding(padding: const EdgeInsets.all(12), child: ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.memory(s.data!, height: 160, fit: BoxFit.contain))),
            ),
          const Divider(height: 1),
          ListTile(leading: Icon(clip.type == ClipType.file ? Icons.download : Icons.copy),
              title: Text(clip.type == ClipType.file ? 'Save / put on clipboard' : 'Copy to this device'),
              onTap: () { Navigator.pop(ctx); app.copyToLocalClipboard(clip); }),
          ListTile(leading: const Icon(Icons.send), title: const Text('Send to…'),
              onTap: () { Navigator.pop(ctx); _pickPeer(context, clip); }),
          ListTile(leading: Icon(clip.pinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(clip.pinned ? 'Unpin' : 'Pin'),
              onTap: () { Navigator.pop(ctx); app.togglePin(clip); }),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); app.deleteClip(clip); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  static void _pickPeer(BuildContext context, Clip clip) {
    final app = context.read<AppController>();
    if (app.peers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No paired devices yet')));
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Send to', style: TextStyle(fontWeight: FontWeight.w800))),
          for (final p in app.peers)
            ListTile(
              leading: Icon(platformIcon(p.platform)),
              title: Text(p.name),
              subtitle: Text(app.isConnected(p.id) ? 'Connected' : 'Not in range'),
              enabled: app.isConnected(p.id),
              onTap: () async {
                Navigator.pop(ctx);
                await app.sendClipTo(clip, p, manual: true);
                app.toasts.add('Sent to ${p.name}');
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
