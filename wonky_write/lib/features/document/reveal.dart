import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/rendering.dart';
import 'package:super_editor/super_editor.dart' show DocumentLayout;

import '../editor/layers/document_geometry.dart';
import '../editor/mapping/document_mirror.dart';

/// Scrolls Delta range `[start, end)` of a laid-out document into view.
///
/// The document layout may live in a sliver, so the request goes through the
/// render box of the component that contains [start] (any ancestor
/// scrollable reveals it).
void revealDocumentRange(
  DocumentLayout? layout,
  DocumentMirror mirror,
  int start,
  int end, {
  double margin = 48,
}) {
  if (layout == null || mirror.length == 0) return;
  final max = mirror.length - 1;
  final s = start.clamp(0, max);
  final e = (end <= start ? start + 1 : end).clamp(0, max + 1);
  final rects = DocumentGeometry.rectsForRange(
    layout,
    mirror,
    s,
    e,
    maxRects: 2,
  );
  final rect = rects.isNotEmpty
      ? rects.first
      : DocumentGeometry.caretRect(layout, mirror, s);
  final position = mirror.positionAt(s);
  if (rect == null || position == null) return;
  final component = layout.getComponentByNodeId(position.nodeId);
  final box = component?.context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return;
  final global = layout.getGlobalOffsetFromDocumentOffset(rect.topLeft);
  final local = box.globalToLocal(global) & rect.size;
  box.showOnScreen(
    rect: local.inflate(margin),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );
}

/// The global position of document offset [documentOffset]'s top-left
/// corner of Delta [offset] (margin cards, popovers); null when not laid
/// out.
Offset? globalTopOfOffset(
  DocumentLayout? layout,
  DocumentMirror mirror,
  int offset,
) {
  if (layout == null || mirror.length == 0) return null;
  final rect = DocumentGeometry.caretRect(
    layout,
    mirror,
    offset.clamp(0, mirror.length - 1),
  );
  if (rect == null) return null;
  return layout.getGlobalOffsetFromDocumentOffset(rect.topLeft);
}
