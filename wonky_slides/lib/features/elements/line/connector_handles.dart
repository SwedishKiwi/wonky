import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';
import 'package:wonky_slides_core/scene.dart';

import '../../canvas/canvas_interactions.dart';
import '../../canvas/canvas_tokens.dart';
import '../../canvas/slide_canvas_controller.dart';

/// A connector's route as drawn: its routing and points (slide su;
/// curved: start, c1, c2, end).
typedef ConnectorPoints = ({LineRouting routing, List<SuPoint> points});

/// A route editing handle of a connector (03 §6.4, SL-44): the midpoint
/// of an elbow route's inner segment (dragging moves the segment across
/// its direction) or the bend point of a curved route (dragging bends the
/// curve through the pointer).
@immutable
class ConnectorHandle {
  const ConnectorHandle.segment(this.index, this.at, {required this.horizontal})
    : curved = false;

  const ConnectorHandle.bend(this.at)
    : index = -1,
      horizontal = false,
      curved = true;

  /// The segment (its first point's index in the route), -1 for a bend.
  final int index;

  /// Where the handle sits (slide su).
  final Offset at;

  /// An elbow segment that runs horizontally (it moves vertically).
  final bool horizontal;

  /// The bend point of a curved route.
  final bool curved;
}

/// Route editing of connectors (03 §6.4): the handles of a route and the
/// waypoints a drag produces (slide su; `slides.line.setWaypoints` stores
/// them normalized in the line's frame).
abstract final class ConnectorEdit {
  /// A route as the stage drew it (`SlideScene.routes`) with its routing.
  static ConnectorPoints pointsOf(LineRouting routing, List<SuPoint> points) =>
      (routing: routing, points: points);

  /// The editing handles of [route]: elbow inner segments' midpoints, a
  /// curved route's bend point; none for straight lines.
  static List<ConnectorHandle> handlesOf(ConnectorPoints route) {
    final p = route.points;
    switch (route.routing) {
      case LineRouting.curved:
        if (p.length != 4) return const [];
        final m = ConnectorRouter.curveMidpoint(p);
        return [ConnectorHandle.bend(Offset(m.x, m.y))];
      case LineRouting.elbow:
        return [
          for (var i = 1; i + 2 < p.length; i++)
            ConnectorHandle.segment(
              i,
              Offset((p[i].x + p[i + 1].x) / 2, (p[i].y + p[i + 1].y) / 2),
              horizontal: (p[i].y - p[i + 1].y).abs() < 1e-6,
            ),
        ];
      case LineRouting.straight:
        return const [];
    }
  }

  /// The waypoints after dragging [h] of [route] to slide point [to].
  static List<Offset> waypointsAfter(
    ConnectorPoints route,
    ConnectorHandle h,
    Offset to,
  ) {
    if (h.curved) return [to];
    final p = [for (final q in route.points) Offset(q.x, q.y)];
    final d = to - h.at;
    final shift = h.horizontal ? Offset(0, d.dy) : Offset(d.dx, 0);
    p[h.index] += shift;
    p[h.index + 1] += shift;
    return p.sublist(1, p.length - 1);
  }

  /// The polyline (elbow) or curve points (start, c1, c2, end) of [route]
  /// with [waypoints] (a preview while dragging; slide su).
  static List<Offset> previewPoints(
    ConnectorPoints route,
    ConnectorHandle h,
    List<Offset> waypoints,
  ) {
    final p = [for (final q in route.points) Offset(q.x, q.y)];
    if (!h.curved) return [p.first, ...waypoints, p.last];
    final m = ConnectorRouter.curveMidpoint(route.points);
    final b = waypoints.first;
    final d = Offset(b.dx - m.x, b.dy - m.y) * (4 / 3);
    return [p[0], p[1] + d, p[2] + d, p[3]];
  }
}

/// The route handles of a selected elbow or curved connector on the canvas
/// (03 §6.4, SL-44): small diamonds at the inner segments' midpoints (elbow)
/// or at the curve's middle (curved). Dragging one previews the new route
/// on the overlay; the release writes `slides.line.setWaypoints` (one undo
/// step). Endpoint handles keep priority (they are the selection chrome).
class ConnectorHandles extends CanvasInteraction {
  ConnectorHandles(super.c);

  /// Handle hit radius (viewport px).
  static const hitRadius = 8.0;

  /// Writes the waypoints (`slides.line.setWaypoints`); set by the
  /// command registration.
  static Future<void> Function(
    SlideCanvasController c,
    String lineId,
    List<Offset> waypoints,
  )?
  commit;

  ConnectorHandle? _drag;
  Offset? _to;
  String? _lineId;

  /// The line whose handles show, its route and handles; null when the
  /// selection is not one editable elbow or curved connector.
  (String, ConnectorPoints, List<ConnectorHandle>)? get target {
    if (!c.canTransform || !c.singleLine) return null;
    final id = c.selection.ids.single;
    final e = c.elements?[id];
    if (e == null || e.parentId != null) return null;
    final points = c.scene?.routes[id];
    if (points == null) return null;
    final route = ConnectorEdit.pointsOf(
      LineRouting.fromName(e.data?['routing']),
      points,
    );
    final handles = ConnectorEdit.handlesOf(route);
    if (handles.isEmpty) return null;
    return (id, route, handles);
  }

  ConnectorHandle? _handleAt(Offset su) {
    final t = target;
    if (t == null) return null;
    final px = c.viewport.toViewport(su);
    for (final h in t.$3) {
      if ((c.viewport.toViewport(h.at) - px).distance <= hitRadius) return h;
    }
    return null;
  }

  @override
  bool down(CanvasPointer p) {
    final h = _handleAt(p.su);
    if (h == null) return false;
    _drag = h;
    _to = h.at;
    _lineId = target?.$1;
    c.refresh();
    return true;
  }

  @override
  void move(CanvasPointer p) {
    if (_drag == null) return;
    _to = p.su;
    c.refresh();
  }

  @override
  void up(CanvasPointer p) {
    final h = _drag, id = _lineId;
    final t = target;
    _drag = null;
    _lineId = null;
    final to = p.su;
    _to = null;
    c.refresh();
    if (h == null || id == null || t == null || t.$1 != id) return;
    if ((c.viewport.toViewport(to) - c.viewport.toViewport(h.at)).distance <
        1) {
      return;
    }
    commit?.call(c, id, ConnectorEdit.waypointsAfter(t.$2, h, to));
  }

  @override
  void cancel() {
    _drag = null;
    _to = null;
    _lineId = null;
    c.refresh();
  }

  @override
  MouseCursor? cursorAt(Offset su) {
    final h = _handleAt(su);
    if (h == null) return null;
    if (h.curved) return SystemMouseCursors.move;
    return h.horizontal
        ? SystemMouseCursors.resizeUpDown
        : SystemMouseCursors.resizeLeftRight;
  }

  @override
  void paint(Canvas canvas, CanvasTokens tokens) {
    final t = target;
    if (t == null) return;
    final (_, route, handles) = t;
    final v = c.viewport;
    final drag = _drag, to = _to;
    if (drag != null && to != null) {
      final pts = ConnectorEdit.previewPoints(
        route,
        drag,
        ConnectorEdit.waypointsAfter(route, drag, to),
      );
      final path = ui.Path();
      final first = v.toViewport(pts.first);
      path.moveTo(first.dx, first.dy);
      if (drag.curved) {
        final a = v.toViewport(pts[1]), b = v.toViewport(pts[2]);
        final e = v.toViewport(pts[3]);
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
      } else {
        for (final q in pts.skip(1)) {
          final x = v.toViewport(q);
          path.lineTo(x.dx, x.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = tokens.selection,
      );
    }
    for (final h in handles) {
      final at = drag != null && to != null && identical(h, drag)
          ? v.toViewport(_dragged(h, to))
          : v.toViewport(h.at);
      _diamond(canvas, at, tokens);
    }
  }

  /// Where a dragged handle shows (elbow handles move across only).
  static Offset _dragged(ConnectorHandle h, Offset to) => h.curved
      ? to
      : h.horizontal
      ? Offset(h.at.dx, to.dy)
      : Offset(to.dx, h.at.dy);

  static void _diamond(Canvas canvas, Offset at, CanvasTokens tokens) {
    const r = 5.0;
    final path = ui.Path()
      ..moveTo(at.dx, at.dy - r)
      ..lineTo(at.dx + r, at.dy)
      ..lineTo(at.dx, at.dy + r)
      ..lineTo(at.dx - r, at.dy)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = tokens.adjustHandle)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = tokens.handleFill,
      );
  }
}
