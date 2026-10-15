import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/model.dart' show ElementKind;
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/snapping.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../editor_screen/deck_editor_controller.dart';
import '../selection/slide_elements.dart';
import '../selection/transform_session.dart' show TransformModifiers;
import '../settings/slides_user_defaults.dart';
import '../stage/scene_painter.dart';
import 'canvas_tokens.dart';
import 'slide_canvas_controller.dart';

/// What the drag of an armed canvas tool draws (03 §6.3, §6.4, §9).
enum CanvasToolGesture {
  /// A box (shapes, text boxes): click inserts at the default size, drag
  /// sizes it (Shift 1:1, Alt from the center).
  box,

  /// A line from the press to the release point (Shift: 45° steps);
  /// endpoints glue to connection sites.
  line,

  /// A click on an element (format painter).
  pick,
}

/// A finished tool gesture in slide space (su).
class CanvasToolStroke {
  const CanvasToolStroke({
    required this.start,
    required this.end,
    required this.dragged,
    this.startSite,
    this.endSite,
    this.pickedId,
    this.modifiers = TransformModifiers.none,
  });

  /// Press point (snapped).
  final Offset start;

  /// Release point (snapped; for boxes the opposite corner).
  final Offset end;

  /// Whether the pointer moved (else a click).
  final bool dragged;

  /// Connection sites the line endpoints glued to.
  final SnapSite? startSite;
  final SnapSite? endSite;

  /// The element clicked by a [CanvasToolGesture.pick] tool.
  final String? pickedId;
  final TransformModifiers modifiers;

  /// The box of a box gesture.
  SuRect get box => SuRect(
    math.min(start.dx, end.dx),
    math.min(start.dy, end.dy),
    (start.dx - end.dx).abs(),
    (start.dy - end.dy).abs(),
  );
}

/// An insert tool or a pick tool the canvas runs while armed
/// (`DeckEditorController.armedTool`): the canvas draws its gesture live
/// (crosshair, rubber band or line with glued sites) and calls [commit] on
/// release, which invokes a command (one undo step).
abstract class CanvasTool {
  const CanvasTool();

  CanvasToolGesture get gesture;

  /// The pointer over the canvas while armed.
  MouseCursor get cursor => SystemMouseCursors.precise;

  /// The outline previewed for box [r] (element-local su), or null for a
  /// plain rectangle.
  ScenePath? previewPath(double w, double h) => null;

  /// Commits [stroke] (invokes a command).
  Future<void> commit(
    DeckEditorController ed,
    CanvasToolStroke stroke,
    BuildContext context,
  );
}

/// Resolves the tool of an armed tool name (`shape:roundRect`,
/// `line:elbow:end`, `paintFormat`), or null when it isn't this factory's.
typedef CanvasToolFactory =
    CanvasTool? Function(DeckEditorController ed, String armed);

/// The registry of canvas tools: element work packages register a factory
/// for their armed-tool names (`registerAll` is idempotent per factory).
abstract final class CanvasTools {
  static final List<CanvasToolFactory> _factories = [];

  /// Registers [factory] once.
  static void register(CanvasToolFactory factory) {
    if (!_factories.contains(factory)) _factories.add(factory);
  }

  /// The tool of [ed]'s armed tool, or null (Select).
  static CanvasTool? of(DeckEditorController ed) {
    final armed = ed.armedTool;
    if (armed == null) return null;
    for (final f in _factories) {
      final t = f(ed, armed);
      if (t != null) return t;
    }
    return null;
  }
}

/// The live gesture of an armed tool (painted by [paintToolPreview]).
class ToolPreview {
  const ToolPreview(
    this.tool,
    this.start,
    this.end, {
    this.startSite,
    this.endSite,
    this.guides = const [],
  });

  final CanvasTool tool;
  final Offset start;
  final Offset end;
  final SnapSite? startSite;
  final SnapSite? endSite;
  final List<SnapGuide> guides;
}

/// Runs the gesture of an armed [tool] on the canvas [c] (snapping and
/// modifiers), keeping the preview on the controller.
class CanvasToolDrag {
  CanvasToolDrag(this.c, this.tool, Offset downSu, this.mods) {
    final prefs = c.editor.defaults;
    final objects =
        prefs.flag(SlidesUserDefaults.keySnapObjects) &&
        prefs.flag(SlidesUserDefaults.keySmartGuides);
    _targets = c.snapTargets(
      const {},
      objects: objects,
      guides: prefs.flag(SlidesUserDefaults.keySnapGuides),
      userGuides: UserGuides.decode(c.editor.model.deck?.guidesJson),
      sites: tool.gesture == CanvasToolGesture.line,
    );
    final s = _snap(downSu, mods);
    _start = Offset(s.x, s.y);
    _startSite = s.site;
    _end = _start;
    _downSu = downSu;
    c.toolPreview = ToolPreview(tool, _start, _end, startSite: _startSite);
  }

  final SlideCanvasController c;
  final CanvasTool tool;
  TransformModifiers mods;
  late final SnapTargets _targets;
  late Offset _start;
  late Offset _end;
  late Offset _downSu;
  SnapSite? _startSite;
  SnapSite? _endSite;
  bool _dragged = false;

  double get _threshold => SnapEngine.thresholdFor(c.viewport.scale);

  SnapPointResult _snap(Offset su, TransformModifiers m) => m.mod
      ? SnapPointResult(su.dx, su.dy)
      : SnapEngine.snapPoint(
          su.dx,
          su.dy,
          _targets,
          _threshold,
          glue: tool.gesture == CanvasToolGesture.line,
        );

  /// The pointer moved to [su] ([px] from the press in viewport px).
  void update(Offset su, TransformModifiers m, double px) {
    mods = m;
    if (px >= 3) _dragged = true;
    if (!_dragged) return;
    var guides = const <SnapGuide>[];
    switch (tool.gesture) {
      case CanvasToolGesture.line:
        if (m.shift) {
          final d = su - _start;
          final a =
              (math.atan2(d.dy, d.dx) / (math.pi / 4)).round() * (math.pi / 4);
          final len = d.distance;
          _end = _start + Offset(math.cos(a) * len, math.sin(a) * len);
          _endSite = null;
        } else {
          final s = _snap(su, m);
          _end = Offset(s.x, s.y);
          _endSite = s.site;
          guides = s.guides;
        }
      case CanvasToolGesture.box:
        final s = _snap(su, m);
        var end = Offset(s.x, s.y);
        guides = s.guides;
        var d = end - _start;
        if (m.shift) {
          final side = math.max(d.dx.abs(), d.dy.abs());
          d = Offset(
            d.dx.isNegative ? -side : side,
            d.dy.isNegative ? -side : side,
          );
          end = _start + d;
        }
        _end = end;
      case CanvasToolGesture.pick:
        _end = su;
    }
    c.toolPreview = ToolPreview(
      tool,
      _boxStart,
      _end,
      startSite: _startSite,
      endSite: _endSite,
      guides: guides,
    );
  }

  /// Alt draws boxes from the center: the press point is the center.
  Offset get _boxStart => tool.gesture == CanvasToolGesture.box && mods.alt
      ? _start - (_end - _start)
      : _start;

  /// The finished gesture.
  CanvasToolStroke finish() => CanvasToolStroke(
    start: _dragged ? _boxStart : _start,
    end: _end,
    dragged: _dragged,
    startSite: _startSite,
    endSite: _dragged ? _endSite : null,
    pickedId: tool.gesture == CanvasToolGesture.pick && !_dragged
        ? c.pick(_downSu, deep: mods.mod)?.$1
        : null,
    modifiers: mods,
  );
}

/// Paints the armed tool's preview and, for line tools, the connection
/// sites of the shape under the pointer (03 §6.4) on the canvas overlay.
void paintToolPreview(
  Canvas canvas,
  SlideCanvasController c,
  CanvasTokens tokens,
) {
  final v = c.viewport;
  final p = c.toolPreview;
  final hover = c.toolHover;
  final tool = p?.tool ?? CanvasTools.of(c.editor);
  if (tool == null) return;
  if (tool.gesture == CanvasToolGesture.line) {
    final at = p?.end ?? hover;
    if (at != null) _sites(canvas, c, tokens, at, p?.endSite ?? p?.startSite);
  }
  if (p == null) return;
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = tokens.selection;
  switch (tool.gesture) {
    case CanvasToolGesture.line:
      canvas.drawLine(v.toViewport(p.start), v.toViewport(p.end), stroke);
    case CanvasToolGesture.box:
      final a = v.toViewport(p.start), b = v.toViewport(p.end);
      final r = Rect.fromPoints(a, b);
      if (r.width < 1 && r.height < 1) return;
      final path = tool.previewPath(
        (p.end.dx - p.start.dx).abs(),
        (p.end.dy - p.start.dy).abs(),
      );
      canvas.drawRect(r, Paint()..color = tokens.marqueeFill);
      if (path == null) {
        canvas.drawRect(r, stroke);
      } else {
        canvas.save();
        canvas.translate(r.left, r.top);
        canvas.scale(v.scale);
        canvas.drawPath(
          SlideScenePainter.pathOf(path),
          stroke..strokeWidth = 1.5 / math.max(v.scale, 1e-3),
        );
        canvas.restore();
      }
    case CanvasToolGesture.pick:
      break;
  }
  final guide = Paint()
    ..color = tokens.guide
    ..strokeWidth = 1;
  for (final g in p.guides) {
    if (g.axis == SnapAxis.x) {
      canvas.drawLine(
        v.toViewport(Offset(g.at, g.from)),
        v.toViewport(Offset(g.at, g.to)),
        guide,
      );
    } else {
      canvas.drawLine(
        v.toViewport(Offset(g.from, g.at)),
        v.toViewport(Offset(g.to, g.at)),
        guide,
      );
    }
  }
}

void _sites(
  Canvas canvas,
  SlideCanvasController c,
  CanvasTokens tokens,
  Offset at,
  SnapSite? glued,
) {
  final els = c.elements;
  if (els == null) return;
  final path = c.hitPath(at, tolerancePx: 12);
  final v = c.viewport;
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = tokens.guide;
  final fill = Paint()..color = tokens.handleFill;
  for (final id in path.take(1)) {
    final e = els[id];
    if (e == null ||
        e.record.kind == ElementKind.line ||
        e.record.kind == ElementKind.group) {
      continue;
    }
    for (final (_, pt) in ConnectorRouter.slideSites(e)) {
      final o = v.toViewport(Offset(pt.x, pt.y));
      canvas.drawCircle(o, 4, fill);
      canvas.drawCircle(o, 4, ring);
    }
  }
  if (glued != null) {
    final o = v.toViewport(Offset(glued.x, glued.y));
    canvas.drawCircle(
      o,
      7,
      Paint()..color = tokens.guide.withValues(alpha: .25),
    );
    canvas.drawCircle(o, 4, Paint()..color = tokens.guide);
  }
}

/// Whether [e] is a selectable element on the current slide (format
/// painter targets).
bool canvasPickable(SlideCanvasController c, String id) {
  final e = c.elements?[id];
  return e != null && SlideElements.selectable(e);
}
