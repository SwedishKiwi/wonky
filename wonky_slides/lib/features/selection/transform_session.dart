import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Matrix4, Offset;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/snapping.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

/// Modifier keys of a gesture (03 §5.4): Shift constrains / keeps aspect /
/// snaps rotation to 15°; Alt duplicates on drop / resizes from the
/// center; Mod disables snapping.
class TransformModifiers {
  const TransformModifiers({
    this.shift = false,
    this.alt = false,
    this.mod = false,
  });

  static const none = TransformModifiers();

  final bool shift;
  final bool alt;
  final bool mod;
}

/// What a [TransformSession] does.
enum TransformKind { move, resize, rotate }

/// The live state of one move / resize / rotate drag (03 §1.1
/// `TransformSession`, §4): the start frames of the moving elements (slide
/// space), the live frames after each pointer move — snapped by the
/// [SnapEngine] — and the guides to draw. Nothing is written while
/// dragging: the canvas previews [liveFrames] as transforms on the stage
/// and writes **one** plan on drop from [delta] (move) or [liveFrames].
class TransformSession {
  TransformSession._(
    this.kind,
    this.frames,
    this.start, {
    required this.targets,
    required this.threshold,
    this.handle,
    this.keepAspect = false,
    this.minSize = 1,
    this.snapping = true,
  }) : startBox =
           FrameTransforms.boundsOf(frames.values) ?? const SuRect(0, 0, 0, 0),
       _live = Map.of(frames);

  /// A move of [frames] starting at slide point [start].
  factory TransformSession.move(
    Map<String, ElementFrame> frames,
    Offset start, {
    required SnapTargets targets,
    required double threshold,
    bool snapping = true,
  }) => TransformSession._(
    TransformKind.move,
    frames,
    start,
    targets: targets,
    threshold: threshold,
    snapping: snapping,
  );

  /// A resize by [handle]. [keepAspect] is the kinds' default (images,
  /// icons, groups); Shift inverts it. [minSize] 0 for lines.
  factory TransformSession.resize(
    Map<String, ElementFrame> frames,
    Offset start,
    ResizeHandle handle, {
    required SnapTargets targets,
    required double threshold,
    bool keepAspect = false,
    double minSize = 1,
    bool snapping = true,
  }) => TransformSession._(
    TransformKind.resize,
    frames,
    start,
    targets: targets,
    threshold: threshold,
    handle: handle,
    keepAspect: keepAspect,
    minSize: minSize,
    snapping: snapping,
  );

  /// A rotation about the selection center.
  factory TransformSession.rotate(
    Map<String, ElementFrame> frames,
    Offset start,
  ) => TransformSession._(
    TransformKind.rotate,
    frames,
    start,
    targets: SnapTargets(slide: const SuRect(0, 0, 0, 0), objects: false),
    threshold: 0,
  );

  final TransformKind kind;

  /// Start frames (slide space) by element id.
  final Map<String, ElementFrame> frames;

  /// The pointer's start (slide space).
  final Offset start;

  /// Bounds of [frames] at the start.
  final SuRect startBox;
  final SnapTargets targets;
  final double threshold;
  final ResizeHandle? handle;
  final bool keepAspect;
  final double minSize;

  /// Smart guides / snapping preferences allow snapping at all.
  final bool snapping;

  Map<String, ElementFrame> _live;
  Offset _delta = Offset.zero;
  double _angle = 0;
  bool _duplicate = false;
  SnapResult _snap = SnapResult.none;
  List<SnapGuide> _resizeGuides = const [];
  List<SizeMatch> _sizes = const [];

  /// Live frames (slide space) by element id.
  Map<String, ElementFrame> get liveFrames => _live;

  /// The move's delta (su) after snapping.
  Offset get delta => _delta;

  /// The rotation's delta (degrees).
  double get angle => _angle;

  /// Alt was held at the last update of a move (duplicate on drop).
  bool get duplicate => _duplicate;

  /// Alignment guides to draw.
  List<SnapGuide> get guides =>
      kind == TransformKind.resize ? _resizeGuides : _snap.guides;

  /// Equal spacing indicators to draw.
  List<SpacingGuide> get spacings => _snap.spacings;

  /// Equal size matches to draw (resize).
  List<SizeMatch> get sizes => _sizes;

  /// Bounds of the live frames.
  SuRect get liveBox => FrameTransforms.boundsOf(_live.values) ?? startBox;

  /// Whether anything changed from the start.
  bool get changed => switch (kind) {
    TransformKind.move => _delta != Offset.zero,
    TransformKind.rotate => _angle != 0,
    TransformKind.resize => _live.entries.any((e) => e.value != frames[e.key]),
  };

  /// Applies the pointer at slide point [p].
  void update(Offset p, [TransformModifiers m = TransformModifiers.none]) {
    switch (kind) {
      case TransformKind.move:
        _move(p, m);
      case TransformKind.resize:
        _resize(p, m);
      case TransformKind.rotate:
        _rotate(p, m);
    }
  }

  void _move(Offset p, TransformModifiers m) {
    var (dx, dy) = (p.dx - start.dx, p.dy - start.dy);
    if (m.shift) (dx, dy) = FrameTransforms.constrain(dx, dy);
    _duplicate = m.alt;
    if (snapping && !m.mod) {
      _snap = SnapEngine.snapMove(
        startBox.translate(dx, dy),
        targets,
        threshold,
        lockX: m.shift && dx == 0,
        lockY: m.shift && dy == 0,
      );
      dx += _snap.dx;
      dy += _snap.dy;
    } else {
      _snap = SnapResult.none;
    }
    _delta = Offset(dx, dy);
    _live = {
      for (final MapEntry(:key, :value) in frames.entries)
        key: ElementFrame(
          value.x + dx,
          value.y + dy,
          value.width,
          value.height,
          rotation: value.rotation,
          flipH: value.flipH,
          flipV: value.flipV,
        ),
    };
  }

  void _resize(Offset p, TransformModifiers m) {
    final h = handle!;
    final aspect = keepAspect != m.shift;
    final single = frames.length == 1;
    final base = single ? frames.values.single : ElementFrame.of(startBox);
    var next = FrameTransforms.resize(
      base,
      h,
      p.dx,
      p.dy,
      keepAspect: aspect,
      fromCenter: m.alt,
      minSize: minSize,
    );
    _resizeGuides = const [];
    _sizes = const [];
    if (snapping && !m.mod && !m.alt && normalizeRotation(base.rotation) == 0) {
      // Edges that follow the pointer, on screen (a flipped box swaps).
      final r = SnapEngine.snapResize(
        next.rect,
        targets,
        threshold,
        left: h.sx != 0 && (h.sx < 0) != (next.flipH != base.flipH),
        right: h.sx != 0 && (h.sx > 0) != (next.flipH != base.flipH),
        top: h.sy != 0 && (h.sy < 0) != (next.flipV != base.flipV),
        bottom: h.sy != 0 && (h.sy > 0) != (next.flipV != base.flipV),
      );
      if (r.snappedX || r.snappedY) {
        if (aspect) {
          // Re-derive the kept aspect from the snapped edge's pointer.
          final dx = r.rect.x - next.rect.x + r.rect.right - next.rect.right;
          final dy = r.rect.y - next.rect.y + r.rect.bottom - next.rect.bottom;
          next = FrameTransforms.resize(
            base,
            h,
            p.dx + (r.snappedX ? dx : 0),
            p.dy + (r.snappedY && !r.snappedX ? dy : 0),
            keepAspect: true,
            minSize: minSize,
          );
        } else {
          next = ElementFrame.of(
            r.rect,
            rotation: next.rotation,
            flipH: next.flipH,
            flipV: next.flipV,
          );
        }
        _resizeGuides = r.guides;
        _sizes = r.sizes;
      }
    }
    if (single) {
      _live = {frames.keys.single: next};
    } else {
      _live = {
        for (final MapEntry(:key, :value) in frames.entries)
          key: FrameTransforms.scaleInBox(value, startBox, next),
      };
    }
  }

  void _rotate(Offset p, TransformModifiers m) {
    final cx = startBox.x + startBox.width / 2;
    final cy = startBox.y + startBox.height / 2;
    final a0 = FrameTransforms.angleOf(cx, cy, start.dx, start.dy);
    final a1 = FrameTransforms.angleOf(cx, cy, p.dx, p.dy);
    var d = a1 - a0;
    if (frames.length == 1) {
      final f = frames.values.single;
      final target = SnapEngine.snapAngle(
        f.rotation + d,
        shift: m.shift,
        free: m.mod,
      );
      d = target - f.rotation;
    } else {
      d = SnapEngine.snapAngle(d, shift: m.shift, free: m.mod);
    }
    d = normalizeRotation(d);
    if (d > 180) d -= 360;
    _angle = d;
    _live = {
      for (final MapEntry(:key, :value) in frames.entries)
        key: FrameTransforms.rotateAbout(value, cx, cy, d),
    };
  }

  /// The slide-space transform that maps [from] onto [to] (the live
  /// preview of one element: the stage applies it as the element's visual
  /// state, without relayout, 03 §2.4).
  static Matrix4 frameMatrix(ElementFrame from, ElementFrame to) {
    final sx = from.width == 0 ? 1.0 : to.width / from.width;
    final sy = from.height == 0 ? 1.0 : to.height / from.height;
    final fx = to.flipH != from.flipH ? -1.0 : 1.0;
    final fy = to.flipV != from.flipV ? -1.0 : 1.0;
    final r0 = from.rotation * math.pi / 180;
    final r1 = to.rotation * math.pi / 180;
    return Matrix4.identity()
      ..translateByDouble(to.cx, to.cy, 0, 1)
      ..rotateZ(r1)
      ..scaleByDouble(sx * fx, sy * fy, 1, 1)
      ..rotateZ(-r0)
      ..translateByDouble(-from.cx, -from.cy, 0, 1);
  }
}
