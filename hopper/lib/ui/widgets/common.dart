import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../theme.dart';

enum PillStyle { neutral, ok, blue, accent }

/// Small rounded label. "ok" and "accent" are the orange family; "blue" is informational.
class Pill extends StatelessWidget {
  final String text;
  final PillStyle style;
  const Pill(this.text, {super.key}) : style = PillStyle.neutral;
  const Pill.ok(this.text, {super.key}) : style = PillStyle.ok;
  const Pill.blue(this.text, {super.key}) : style = PillStyle.blue;
  const Pill.accent(this.text, {super.key}) : style = PillStyle.accent;

  @override
  Widget build(BuildContext context) {
    final t = HopperTheme.of(context);
    final (bg, fg) = switch (style) {
      PillStyle.neutral => (t.card2, t.muted),
      PillStyle.ok || PillStyle.accent => (t.accentSoft, t.dark ? const Color(0xFFFFA184) : HopperColors.accentDeep),
      PillStyle.blue => (t.blueSoft, t.dark ? const Color(0xFF9DB6FF) : const Color(0xFF2A55C9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class StatusDot extends StatelessWidget {
  final bool on;
  final Color? color;
  const StatusDot(this.on, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final t = HopperTheme.of(context);
    return Container(
      width: 9, height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? (color ?? HopperColors.accent) : t.line,
        boxShadow: on ? [BoxShadow(color: (color ?? HopperColors.accent).withValues(alpha: .45), blurRadius: 6, spreadRadius: 1)] : null,
      ),
    );
  }
}

IconData platformIcon(String p) => switch (p) {
      'android' => Icons.phone_android,
      'ios' => Icons.phone_iphone,
      'macos' => Icons.laptop_mac,
      'windows' => Icons.laptop_windows,
      'linux' => Icons.computer,
      _ => Icons.devices,
    };

IconData clipIcon(ClipType t) => switch (t) {
      ClipType.text => Icons.notes,
      ClipType.link => Icons.link,
      ClipType.image => Icons.image_outlined,
      ClipType.file => Icons.insert_drive_file_outlined,
    };

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays} days ago';
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text.toUpperCase(), style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 0.8, color: HopperTheme.of(context).muted))),
          if (trailing != null) trailing!,
        ]),
      );
}
