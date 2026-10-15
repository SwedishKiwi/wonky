import 'package:flutter/rendering.dart';

import 'ink_stroke.dart';

/// Paints [InkStroke]s (Slides 10 §4.3, the board's screenshot editor):
/// round caps and joins, scaled by [scale] (stroke units → pixels) and
/// clipped to the canvas. The highlighter is drawn at [highlighterOpacity]
/// and multiplies on light backgrounds and screens on dark ones
/// ([darkBackground]), so text stays readable underneath.
class InkStrokePainter extends CustomPainter {
  InkStrokePainter({
    required this.strokes,
    this.scale = 1,
    this.darkBackground = false,
    this.highlighterOpacity = defaultHighlighterOpacity,
  });

  /// The highlighter's default opacity.
  static const defaultHighlighterOpacity = 0.4;

  final List<InkStroke> strokes;
  final double scale;
  final bool darkBackground;
  final double highlighterOpacity;

  /// Paints [strokes] onto [canvas] (also used to flatten ink into an
  /// image).
  static void paintStrokes(
    Canvas canvas,
    Iterable<InkStroke> strokes, {
    bool darkBackground = false,
    double highlighterOpacity = defaultHighlighterOpacity,
  }) {
    for (final s in strokes) {
      final hl = s.tool == InkTool.highlighter;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = Color(s.color).withValues(alpha: hl ? highlighterOpacity : 1);
      if (hl) {
        paint.blendMode = darkBackground
            ? BlendMode.screen
            : BlendMode.multiply;
      }
      canvas.drawPath(s.path(), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    paintStrokes(
      canvas,
      strokes,
      darkBackground: darkBackground,
      highlighterOpacity: highlighterOpacity,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(InkStrokePainter old) =>
      old.scale != scale ||
      old.darkBackground != darkBackground ||
      old.highlighterOpacity != highlighterOpacity ||
      old.strokes.length != strokes.length ||
      !_same(old.strokes, strokes);

  static bool _same(List<InkStroke> a, List<InkStroke> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}
