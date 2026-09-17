import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_controller.dart';
import '../../core/models/models.dart';
import '../theme.dart';
import '../widgets/clip_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _q = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    var items = app.history.where((c) {
      if (_filter == 'pinned' && !c.pinned) return false;
      if (_filter == 'text' && c.type == ClipType.image) return false;
      if (_filter == 'images' && c.type != ClipType.image) return false;
      if (_q.isNotEmpty && !(c.text ?? '').toLowerCase().contains(_q.toLowerCase())) return false;
      return true;
    }).toList();
    items.sort((a, b) => a.pinned == b.pinned ? b.createdAt.compareTo(a.createdAt) : (a.pinned ? -1 : 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'clear') _confirmClear(context, app); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Clear history (keeps pinned)'))],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'Search clips', prefixIcon: Icon(Icons.search), isDense: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'text', label: Text('Text')),
                ButtonSegment(value: 'images', label: Text('Images')),
                ButtonSegment(value: 'pinned', label: Text('Pinned')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(32),
                  child: Text('Nothing here yet.\nClips you copy or receive will show up in this list.',
                      textAlign: TextAlign.center, style: TextStyle(color: HopperColors.mid, height: 1.5))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                  itemBuilder: (_, i) => ClipTile(items[i]),
                ),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context, AppController app) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Clear history?'),
      content: const Text('All clips except pinned ones will be deleted from this device.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () { Navigator.pop(ctx); app.clearHistory(); }, child: const Text('Clear')),
      ],
    ));
  }
}
