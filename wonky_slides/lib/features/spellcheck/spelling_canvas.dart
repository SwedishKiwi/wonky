import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/model.dart' show DeckModelIndexes;
import 'package:wonky_slides_core/scene.dart';

import '../../config/slides_features.dart';
import '../canvas/canvas_interactions.dart';
import '../canvas/canvas_tokens.dart';

import '../stage/flutter_text_layout_engine.dart';
import '../text_editing/text_editing_host.dart';
import 'slides_spelling.dart';

/// The spelling squiggles of the canvas (Slides 03 §14): with *Underline
/// errors* on, misspelled words of the current slide's visible text —
/// text boxes, shapes, placeholders and table cells — are underlined with
/// the `spellingError` token on the overlay, from the stage scene's own
/// text layouts (the glyph boxes the stage drew). The body being edited
/// gets its squiggles from the text overlay instead; nothing is drawn while
/// objects are dragged (the stage previews transforms).
class SpellingCanvasLayer extends CanvasInteraction {
  SpellingCanvasLayer(super.c) {
    _spelling = SlidesSpelling.of(c.editor)..addListener(c.refresh);
  }

  late final SlidesSpelling _spelling;

  /// Squiggle wave amplitude and period (viewport px).
  static const amplitude = 1.5;
  static const period = 4.0;

  @override
  void paint(Canvas canvas, CanvasTokens tokens) {
    if (!SlidesFeatures.isOn(SlidesFeature.spelling)) return;
    if (c.transform != null || c.lineEnd != null || c.adjust != null) return;
    final sp = _spelling;
    if (!sp.underline || !sp.isReady) return;
    final scene = c.scene;
    if (scene == null) return;
    final editing = textEditingOf(c.editor).active;
    final paint = Paint()
      ..color = tokens.spellingError
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;
    for (final (from, to) in squiggles(
      scene,
      skipElementId: editing?.elementId,
      skipPartId: editing?.cellPartId,
    )) {
      _wave(
        canvas,
        c.viewport.toViewport(from),
        c.viewport.toViewport(to),
        paint,
      );
    }
  }

  /// The underline segments (slide su, start → end along the baseline
  /// side of each glyph box) of the misspelled words of [scene]; the body
  /// [skipElementId] (with [skipPartId], a table cell) is left out.
  List<(Offset, Offset)> squiggles(
    SlideScene scene, {
    String? skipElementId,
    String? skipPartId,
  }) {
    final out = <(Offset, Offset)>[];
    void visit(SceneNode n, Matrix4 m) {
      switch (n) {
        case GroupNode():
          final inner = m.multiplied(n.transform);
          for (final child in n.children) {
            visit(child, inner);
          }
        case TextNode():
          final id = n.elementId;
          if (id == null) return;
          if (id == skipElementId &&
              (skipPartId == null || n.partId == skipPartId)) {
            return;
          }
          _text(n, m, out);
        default:
          break;
      }
    }

    for (final n in scene.nodes) {
      visit(n, Matrix4.identity());
    }
    return out;
  }

  void _text(TextNode n, Matrix4 m, List<(Offset, Offset)> out) {
    final json = _bodyOf(n.elementId!, n.partId);
    if (json == null) return;
    final ranges = _spelling.checkBody(json);
    if (ranges.isEmpty) return;
    final placed = FlutterTextLayoutEngine.paragraphsOf(n.layout)?.paragraphs;
    if (placed == null) return;
    for (final r in ranges) {
      for (final p in placed) {
        if (p.marker || r.start < p.start || r.end > p.start + p.length) {
          continue;
        }
        for (final b in p.paragraph.getBoxesForRange(
          r.start - p.start,
          r.end - p.start,
          boxHeightStyle: ui.BoxHeightStyle.max,
        )) {
          final dx = n.originX + p.dx, dy = n.originY + p.dy;
          out.add((
            MatrixUtils.transformPoint(m, Offset(dx + b.left, dy + b.bottom)),
            MatrixUtils.transformPoint(m, Offset(dx + b.right, dy + b.bottom)),
          ));
        }
        break;
      }
    }
  }

  /// The stored body of element [id] (or of its table cell [partId]).
  String? _bodyOf(String id, String? partId) {
    if (partId == null) return c.elements?[id]?.text;
    final i = partId.indexOf('|');
    if (i < 0) return null;
    return c.editor.model.indexes
        .table(id)
        .cell(partId.substring(0, i), partId.substring(i + 1))
        ?.text;
  }

  /// A zigzag from [a] to [b] (viewport px).
  static void _wave(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = b - a;
    final len = d.distance;
    if (len < 1) return;
    final u = d / len;
    final nrm = Offset(-u.dy, u.dx);
    final path = Path()..moveTo(a.dx, a.dy);
    final steps = math.max(2, (len / (period / 2)).round());
    for (var i = 1; i <= steps; i++) {
      final t = len * i / steps;
      final off = (i.isOdd ? amplitude : -amplitude);
      final p = a + u * t + nrm * (i == steps ? 0 : off);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void dispose() => _spelling.removeListener(c.refresh);
}
