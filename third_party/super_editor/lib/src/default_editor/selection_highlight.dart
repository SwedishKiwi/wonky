// WONKY PATCH SE-8: a selection highlight that paints each pixel once.
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:super_text_layout/super_text_layout.dart';

/// Like `TextLayoutSelectionHighlight`, but the selection boxes are painted
/// as one path. The boxes are expanded vertically (by
/// [selectionHighlightBoxVerticalExpansion]), so boxes of adjacent lines and
/// of adjacent styled runs overlap; painted one by one with a translucent
/// color, the overlaps showed as darker bands (most visibly in code blocks).
class NonOverlappingSelectionHighlight extends StatelessWidget {
  const NonOverlappingSelectionHighlight({
    super.key,
    required this.textLayout,
    required this.style,
    required this.selection,
  });

  final TextLayout? textLayout;
  final SelectionHighlightStyle style;
  final TextSelection? selection;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: NonOverlappingSelectionPainter(
        textLayout: textLayout,
        color: style.color,
        borderRadius: style.borderRadius,
        selection: selection,
      ),
    );
  }
}

/// Paints the selection boxes of [selection] as the union of their
/// (expanded, rounded) rectangles.
class NonOverlappingSelectionPainter extends CustomPainter {
  NonOverlappingSelectionPainter({
    required this.textLayout,
    required this.color,
    required this.borderRadius,
    required this.selection,
  });

  final TextLayout? textLayout;
  final Color color;
  final BorderRadius borderRadius;
  final TextSelection? selection;

  /// The path that is filled (exposed for tests).
  Path? selectionPath() {
    final layout = textLayout;
    final s = selection;
    if (layout == null || s == null || !s.isValid) return null;
    final path = Path();
    var any = false;
    for (final box
        in layout.getBoxesForSelection(s, boxHeightStyle: BoxHeightStyle.max)) {
      final raw = box.toRect();
      final rect = Rect.fromLTWH(
        raw.left,
        raw.top - selectionHighlightBoxVerticalExpansion,
        // An empty line gets a sliver so it shows as selected.
        raw.width > 0 ? raw.width : 5,
        raw.height + selectionHighlightBoxVerticalExpansion * 2,
      );
      path.addRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: borderRadius.topLeft,
          topRight: borderRadius.topRight,
          bottomLeft: borderRadius.bottomLeft,
          bottomRight: borderRadius.bottomRight,
        ),
      );
      any = true;
    }
    return any ? path : null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = selectionPath();
    if (path == null) return;
    // All boxes wind the same way, so the non-zero fill paints their union
    // once.
    canvas.drawPath(
        path..fillType = PathFillType.nonZero, Paint()..color = color);
  }

  @override
  bool shouldRepaint(NonOverlappingSelectionPainter oldDelegate) =>
      textLayout != oldDelegate.textLayout ||
      selection != oldDelegate.selection ||
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius;
}
