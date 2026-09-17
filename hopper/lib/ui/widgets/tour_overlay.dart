import 'package:flutter/material.dart';

import '../theme.dart';

class TourStep {
  final GlobalKey target;
  final String title, text;
  TourStep({required this.target, required this.title, required this.text});
}

/// A lightweight "coach marks" tour: dims the screen, cuts a hole around the
/// highlighted widget and shows a card with Next / Skip.
class TourOverlay {
  static OverlayEntry? _entry;

  static void start(BuildContext context, List<TourStep> steps, {VoidCallback? onDone}) {
    if (_entry != null || steps.isEmpty) return;
    var index = 0;
    void close() { _entry?.remove(); _entry = null; onDone?.call(); }
    _entry = OverlayEntry(builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final step = steps[index];
        final box = step.target.currentContext?.findRenderObject() as RenderBox?;
        final size = MediaQuery.of(ctx).size;
        final rect = box != null && box.hasSize
            ? (box.localToGlobal(Offset.zero) & box.size).inflate(8)
            : Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
        final cardBelow = rect.center.dy < size.height / 2;
        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: CustomPaint(painter: _HolePainter(rect)),
            ),
          ),
          Positioned(
            left: 20, right: 20,
            top: cardBelow ? rect.bottom + 16 : null,
            bottom: cardBelow ? null : size.height - rect.top + 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Material(
                  color: Theme.of(ctx).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Expanded(child: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                        Text('${index + 1}/${steps.length}', style: const TextStyle(color: HopperColors.mid, fontSize: 12)),
                      ]),
                      const SizedBox(height: 8),
                      Text(step.text, style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 14),
                      Row(children: [
                        TextButton(onPressed: close, child: const Text('Skip tour')),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            if (index == steps.length - 1) { close(); } else { setState(() => index++); }
                          },
                          child: Text(index == steps.length - 1 ? 'Done' : 'Next'),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]);
      });
    });
    Overlay.of(context).insert(_entry!);
  }
}

class _HolePainter extends CustomPainter {
  final Rect hole;
  _HolePainter(this.hole);
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final cut = Path()..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(14)));
    canvas.drawPath(Path.combine(PathOperation.difference, full, cut), Paint()..color = const Color(0xB3101826));
    canvas.drawRRect(RRect.fromRectAndRadius(hole, const Radius.circular(14)),
        Paint()..color = HopperColors.accent..style = PaintingStyle.stroke..strokeWidth = 2);
  }
  @override
  bool shouldRepaint(covariant _HolePainter old) => old.hole != hole;
}
