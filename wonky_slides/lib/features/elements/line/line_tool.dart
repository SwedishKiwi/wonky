import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/model.dart' show ElementKind;
import 'package:wonky_slides_core/ops.dart' show ElementSpec;
import 'package:wonky_slides_core/schema.dart' show ElementCols;
import 'package:wonky_slides_core/snapping.dart' show SnapSite;
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../../canvas/canvas_tools.dart';
import '../../editor_screen/deck_editor_controller.dart';

/// Line routings (02 §6.3).
const lineRoutings = ['straight', 'elbow', 'curved'];

/// Arrowhead styles of `strokeJson.startArrow` / `endArrow` (02 §5.3).
const arrowStyles = [
  'none',
  'triangle',
  'open',
  'stealth',
  'circle',
  'diamond',
  'bar',
];

/// Arrowhead sizes (02 §5.3).
const arrowSizes = ['s', 'm', 'l'];

/// Which ends of a new line get an arrowhead (Insert › Line ▸).
const lineArrowEnds = ['none', 'end', 'start', 'both'];

/// An endpoint of a new or edited line in slide space, optionally glued to
/// [site] of element [elementId] (03 §6.4).
class LineEnd {
  const LineEnd(this.x, this.y, {this.elementId, this.site});

  /// From command args `{x, y, elementId?, site?}`.
  static LineEnd? fromJson(Object? v) {
    if (v is! Map) return null;
    final x = v['x'], y = v['y'];
    if (x is! num || y is! num) return null;
    final el = v['elementId'];
    return LineEnd(
      x.toDouble(),
      y.toDouble(),
      elementId: el is String && el.isNotEmpty ? el : null,
      site: v['site'] == null ? null : '${v['site']}',
    );
  }

  final double x;
  final double y;
  final String? elementId;
  final String? site;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'elementId': ?elementId,
    'site': ?site,
  };
}

/// Builds new lines and the armed line tool (`line:<routing>:<arrows>`,
/// 03 §6.4): drag from start to end (Shift 45°), endpoints glue to
/// connection sites, a click inserts a 400 su horizontal line.
abstract final class LineInsert {
  /// The default length of a clicked line (su).
  static const clickLength = 400.0;

  /// The armed-tool name.
  static String toolName(String routing, String arrows) =>
      'line:$routing:$arrows';

  /// `(routing, arrows)` of an armed line tool, or null.
  static (String, String)? parse(String? armed) {
    if (armed == null || !armed.startsWith('line:')) return null;
    final parts = armed.split(':');
    final routing = parts.length > 1 && lineRoutings.contains(parts[1])
        ? parts[1]
        : 'straight';
    final arrows = parts.length > 2 && lineArrowEnds.contains(parts[2])
        ? parts[2]
        : 'none';
    return (routing, arrows);
  }

  /// The `strokeJson` of a new line with [arrows] (null: the theme's line
  /// style without arrowheads).
  static Map<String, Object?>? strokeFor(String arrows) => switch (arrows) {
    'end' => {'v': 1, 'endArrow': 'triangle'},
    'start' => {'v': 1, 'startArrow': 'triangle'},
    'both' => {'v': 1, 'startArrow': 'triangle', 'endArrow': 'triangle'},
    _ => null,
  };

  /// The element spec of a line from [start] to [end]: the frame is the
  /// endpoints' box, endpoints normalized to it with their glue (base-62
  /// element ids).
  static ElementSpec spec(
    LineEnd start,
    LineEnd end, {
    String routing = 'straight',
    String arrows = 'none',
  }) {
    final x = math.min(start.x, end.x), y = math.min(start.y, end.y);
    final w = (start.x - end.x).abs(), h = (start.y - end.y).abs();
    Map<String, Object?> endpoint(LineEnd p) => {
      'x': w == 0 ? 0 : _round((p.x - x) / w),
      'y': h == 0 ? 0 : _round((p.y - y) / h),
      'connect': p.elementId == null
          ? null
          : {
              'elementId': Base62Uuid.encode(p.elementId!),
              'site': p.site ?? 'center',
            },
    };
    final stroke = strokeFor(arrows);
    return ElementSpec(
      kind: ElementKind.line,
      x: x,
      y: y,
      width: w,
      height: h,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'routing': routing,
          'start': endpoint(start),
          'end': endpoint(end),
          'waypoints': const <Object?>[],
        }),
        if (stroke != null) ElementCols.strokeJson: jsonEncode(stroke),
      },
    );
  }

  static double _round(double v) => (v * 1e6).roundToDouble() / 1e6;
}

/// The armed line tool.
class LineInsertTool extends CanvasTool {
  const LineInsertTool(this.routing, this.arrows);

  final String routing;
  final String arrows;

  @override
  CanvasToolGesture get gesture => CanvasToolGesture.line;

  @override
  Future<void> commit(
    DeckEditorController ed,
    CanvasToolStroke stroke,
    BuildContext context,
  ) async {
    LineEnd end(Offset p, SnapSite? site) => LineEnd(
      _r(p.dx),
      _r(p.dy),
      elementId: site?.elementId,
      site: site?.site,
    );
    final start = end(stroke.start, stroke.startSite);
    final finish = stroke.dragged && (stroke.end - stroke.start).distance >= 4
        ? end(stroke.end, stroke.endSite)
        : LineEnd(_r(stroke.start.dx + LineInsert.clickLength), start.y);
    await ed.invokeCommand(
      'slides.insert.line',
      {
        'routing': routing,
        'arrows': arrows,
        'start': start.toJson(),
        'end': finish.toJson(),
      },
      InvocationSource.ui,
      context.mounted ? context : null,
    );
  }
}

double _r(double v) => (v * 100).roundToDouble() / 100;

/// The [CanvasTools] factory of line tools.
CanvasTool? lineToolFactory(DeckEditorController ed, String armed) {
  final p = LineInsert.parse(armed);
  return p == null ? null : LineInsertTool(p.$1, p.$2);
}
