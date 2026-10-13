import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

/// A small daily bar chart (activity dashboard, suite 07 §6). One bar per
/// [points] entry, oldest first; hovering a bar shows its day and count.
/// The whole chart is one semantics node with [semanticLabel].
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.semanticLabel,
    this.color,
    this.height = 120,
  });

  final List<ActivityTrendPoint> points;
  final String semanticLabel;

  /// Bar color; the theme's primary color by default.
  final Color? color;
  final double height;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final points = widget.points;
    final maxCount = points.fold<int>(0, (m, p) => math.max(m, p.count));
    final color = widget.color ?? theme.colorScheme.primary;
    final muted = theme.textTheme.muted.copyWith(fontSize: 11);
    final day = intl.DateFormat.MMMd();
    final hovered = _hover == null ? null : points[_hover!];
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      image: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 16,
            child: hovered == null
                ? Text('$maxCount', style: muted)
                : Text(
                    '${day.format(hovered.day.toLocal())} · ${hovered.count}',
                    style: muted.copyWith(color: theme.colorScheme.foreground),
                  ),
          ),
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, box) {
                final n = math.max(points.length, 1);
                final slot = box.maxWidth / n;
                return MouseRegion(
                  onHover: (e) => setState(
                    () => _hover = (e.localPosition.dx / slot).floor().clamp(
                      0,
                      n - 1,
                    ),
                  ),
                  onExit: (_) => setState(() => _hover = null),
                  child: CustomPaint(
                    size: Size(box.maxWidth, widget.height),
                    painter: _BarsPainter(
                      counts: [for (final p in points) p.count],
                      maxCount: maxCount,
                      color: color,
                      hoverColor: color.withValues(alpha: 0.7),
                      baseline: theme.colorScheme.border,
                      hover: _hover,
                    ),
                  ),
                );
              },
            ),
          ),
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(day.format(points.first.day.toLocal()), style: muted),
                  const Spacer(),
                  Text(day.format(points.last.day.toLocal()), style: muted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.counts,
    required this.maxCount,
    required this.color,
    required this.hoverColor,
    required this.baseline,
    required this.hover,
  });

  final List<int> counts;
  final int maxCount;
  final Color color;
  final Color hoverColor;
  final Color baseline;
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
    if (counts.isEmpty || maxCount == 0) return;
    final slot = size.width / counts.length;
    final gap = math.min(4.0, slot * 0.25);
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final h = math.max(2.0, (size.height - 1) * counts[i] / maxCount);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(i * slot + gap / 2, size.height - 1 - h, slot - gap, h),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = i == hover ? hoverColor : color);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.counts != counts ||
      old.maxCount != maxCount ||
      old.color != color ||
      old.hover != hover ||
      old.baseline != baseline;
}
