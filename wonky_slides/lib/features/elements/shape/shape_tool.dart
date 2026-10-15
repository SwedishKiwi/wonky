import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../canvas/canvas_tools.dart';
import '../../editor_screen/deck_editor_controller.dart';

/// Insert sizes and the canvas tool of shapes (03 §6.3): a click inserts
/// the default size centered on the click, a drag sizes the shape (Shift
/// 1:1, Alt from the center), Esc cancels the armed tool.
abstract final class ShapeInsert {
  /// The armed-tool name of [geometry] (`shape:roundRect`).
  static String toolName(String geometry) => 'shape:$geometry';

  /// The geometry of an armed shape tool, or null.
  static String? geometryOf(String? armedTool) =>
      armedTool != null && armedTool.startsWith('shape:')
      ? armedTool.substring(6)
      : null;

  /// The default size of [geometry]: 240 × 240 su, shapes with a natural
  /// aspect (arrows 2:1 → 320 × 160) with their long side ≤ 480 su.
  static Size sizeOf(String geometry) {
    final a = ShapeLibrary.of(geometry)?.aspect;
    if (a == null || a == 1) return const Size(240, 240);
    if (a > 1) {
      final w = math.min(160 * a, 480.0);
      return Size(w, w / a);
    }
    final h = math.min(160 / a, 480.0);
    return Size(h * a, h);
  }

  /// The default box of [geometry] centered on [center].
  static SuRect boxAt(String geometry, Offset center) {
    final s = sizeOf(geometry);
    return SuRect(
      center.dx - s.width / 2,
      center.dy - s.height / 2,
      s.width,
      s.height,
    );
  }
}

/// The armed shape tool (`shape:<geometry>`).
class ShapeInsertTool extends CanvasTool {
  const ShapeInsertTool(this.geometry);

  final String geometry;

  @override
  CanvasToolGesture get gesture => CanvasToolGesture.box;

  @override
  ScenePath? previewPath(double w, double h) =>
      ShapeLibrary.resolve(geometry).outline(w, h).mainPath;

  @override
  Future<void> commit(
    DeckEditorController ed,
    CanvasToolStroke stroke,
    BuildContext context,
  ) async {
    final b = stroke.box;
    final r = stroke.dragged && (b.width >= 4 || b.height >= 4)
        ? SuRect(b.x, b.y, math.max(b.width, 1), math.max(b.height, 1))
        : ShapeInsert.boxAt(geometry, stroke.start);
    await ed.invokeCommand(
      'slides.insert.shape',
      {
        'geometry': geometry,
        'x': _r(r.x),
        'y': _r(r.y),
        'width': _r(r.width),
        'height': _r(r.height),
      },
      InvocationSource.ui,
      context.mounted ? context : null,
    );
  }
}

double _r(double v) => (v * 100).roundToDouble() / 100;

/// The [CanvasTools] factory of shape tools.
CanvasTool? shapeToolFactory(DeckEditorController ed, String armed) {
  final g = ShapeInsert.geometryOf(armed);
  return g == null ? null : ShapeInsertTool(g);
}
