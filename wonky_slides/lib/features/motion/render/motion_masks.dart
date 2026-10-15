import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:wonky_slides_core/motion.dart';

/// Wipe, iris and dissolve masks of the stage (Slides 06 §12.1): a
/// [ClipSpec] or a [DissolveState] over a box (the element's unrotated
/// box, a text part's bounds, a transition quad's region).
///
/// Hard edges clip ([MotionMask.clip]); feathered wipes and dissolves need
/// a layer: the content is drawn into it and [MotionMask.paintMask]
/// multiplies it with the mask (`BlendMode.dstIn`).
final class MotionMask {
  MotionMask._(this.box, {this.clipPath, this.shader, this.dissolve});

  /// The box the mask is laid out in.
  final Rect box;

  /// A hard clip, or null.
  final Path? clipPath;

  /// A feathered edge (gradient alpha), or null.
  final Shader? shader;

  /// A dissolve, or null.
  final DissolveState? dissolve;

  /// Whether nothing of the content is visible.
  bool get hidesAll => _empty;
  bool _empty = false;

  /// Whether drawing needs a layer ([paintMask]).
  bool get needsLayer => shader != null || dissolve != null;

  /// The mask of [clip] and/or [dissolve] over [box]; null when neither
  /// hides anything.
  static MotionMask? of(Rect box, {ClipSpec? clip, DissolveState? dissolve}) {
    Path? path;
    Shader? shader;
    var empty = false;
    if (clip != null) {
      final p = clip.progress;
      if (p <= 0) {
        empty = true;
      } else if (p < 1) {
        if (clip.kind == 'iris') {
          path = irisPath(box, clip);
        } else if (clip.softness > 0) {
          shader = wipeShader(box, clip);
        } else {
          path = wipePath(box, clip);
        }
      }
    }
    DissolveState? d;
    if (dissolve != null) {
      if (dissolve.amount <= 0) {
        empty = true;
      } else if (dissolve.amount < 1) {
        d = dissolve;
      }
    }
    if (!empty && path == null && shader == null && d == null) return null;
    return MotionMask._(box, clipPath: path, shader: shader, dissolve: d)
      .._empty = empty;
  }

  /// Applies the hard clip (call before drawing the content).
  void clip(Canvas canvas) {
    final p = clipPath;
    if (p != null) canvas.clipPath(p);
  }

  /// Bounds of the layer to draw the content into ([needsLayer]).
  Rect get layerBounds => box.inflate(2);

  /// Multiplies the layer's content with the feathered edge / dissolve.
  void paintMask(Canvas canvas) {
    final s = shader;
    if (s != null) {
      canvas.drawRect(
        layerBounds.inflate(1e4),
        Paint()
          ..shader = s
          ..blendMode = BlendMode.dstIn,
      );
    }
    final d = dissolve;
    if (d != null) DissolveNoise.paint(canvas, box, d);
  }

  // ------------------------------------------------------------------
  // Geometry

  static String _norm(String dir) => switch (dir) {
    'up' => 'top',
    'down' => 'bottom',
    _ => dir,
  };

  /// The unit vector the reveal moves along in box-normalized space and
  /// where it starts: `left` = from the left edge to the right.
  static (double, double, double, double) _axis(String dir) =>
      switch (_norm(dir)) {
        'right' => (1, 0, -1, 0),
        'top' => (0, 0, 0, 1),
        'bottom' => (0, 1, 0, -1),
        'topLeft' => (0, 0, 1, 1),
        'topRight' => (1, 0, -1, 1),
        'bottomLeft' => (0, 1, 1, -1),
        'bottomRight' => (1, 1, -1, -1),
        _ => (0, 0, 1, 0),
      };

  /// A hard wipe: the part of [box] the reveal has crossed.
  static Path wipePath(Rect box, ClipSpec c) {
    final p = c.progress.clamp(0.0, 1.0);
    final w = box.width, h = box.height;
    final (sx, sy, dx, dy) = _axis(c.direction);
    if (dy == 0) {
      // Horizontal.
      final x0 = sx == 0 ? box.left : box.right - p * w;
      return Path()..addRect(Rect.fromLTWH(x0, box.top, p * w, h));
    }
    if (dx == 0) {
      final y0 = sy == 0 ? box.top : box.bottom - p * h;
      return Path()..addRect(Rect.fromLTWH(box.left, y0, w, p * h));
    }
    // Diagonal: normalized distance from the start corner
    // (u = (x' + y') / 2 with x', y' measured from the corner).
    final t = 2 * p;
    final cx = box.left + sx * w, cy = box.top + sy * h;
    final ex = cx + dx * w, ey = cy + dy * h;
    final poly = <Offset>[];
    // Polygon of the triangle/pentagon x' + y' ≤ t clipped to the box.
    if (t <= 1) {
      poly
        ..add(Offset(cx, cy))
        ..add(Offset(cx + dx * w * t, cy))
        ..add(Offset(cx, cy + dy * h * t));
    } else {
      final r = t - 1;
      poly
        ..add(Offset(cx, cy))
        ..add(Offset(ex, cy))
        ..add(Offset(ex, cy + dy * h * r))
        ..add(Offset(cx + dx * w * r, ey))
        ..add(Offset(cx, ey));
    }
    return Path()..addPolygon(poly, true);
  }

  /// A feathered wipe: alpha 1 behind the edge, 0 ahead of it, over a
  /// band of `softness` × the box (the band starts outside the box and
  /// ends past it, so progress 0/1 are fully hidden/shown).
  static Shader wipeShader(Rect box, ClipSpec c) {
    final s = c.softness.clamp(0.0, 1.0);
    final p = c.progress.clamp(0.0, 1.0);
    final b = p * (1 + s);
    final a = b - s;
    final w = box.width, h = box.height;
    final (sx, sy, dx, dy) = _axis(c.direction);
    Offset at(double u) {
      if (dy == 0) return Offset(box.left + sx * w + dx * u * w, box.center.dy);
      if (dx == 0) return Offset(box.center.dx, box.top + sy * h + dy * u * h);
      // Diagonal: along the isoline normal (1/w, 1/h) from the corner.
      final k = 2 * u / (1 / (w * w) + 1 / (h * h));
      return Offset(
        box.left + sx * w + dx * k / w,
        box.top + sy * h + dy * k / h,
      );
    }

    return ui.Gradient.linear(at(a), at(b), const [
      Color(0xff000000),
      Color(0x00000000),
    ]);
  }

  /// An iris: circle, rect or diamond around the origin growing with the
  /// progress up to the farthest corner.
  static Path irisPath(Rect box, ClipSpec c) {
    final p = c.progress.clamp(0.0, 1.0);
    final o = Offset(
      box.left + c.originX * box.width,
      box.top + c.originY * box.height,
    );
    final ax = math.max(o.dx - box.left, box.right - o.dx);
    final ay = math.max(o.dy - box.top, box.bottom - o.dy);
    switch (c.shape) {
      case 'rect':
        return Path()..addRect(
          Rect.fromCenter(center: o, width: 2 * ax * p, height: 2 * ay * p),
        );
      case 'diamond':
        // |dx| + |dy| ≤ r reaches the farthest corner at progress 1.
        final r = (ax + ay) * p;
        return Path()..addPolygon([
          Offset(o.dx, o.dy - r),
          Offset(o.dx + r, o.dy),
          Offset(o.dx, o.dy + r),
          Offset(o.dx - r, o.dy),
        ], true);
      default:
        final r = math.sqrt(ax * ax + ay * ay) * p;
        return Path()..addOval(Rect.fromCircle(center: o, radius: r));
    }
  }
}

/// Seeded dissolve noise (06 §3.1 `dissolve`, §7.2): the box is divided
/// into cells of `cell` su; each cell gets a deterministic threshold from
/// the seed and shows once the amount passes it. The thresholds are drawn
/// once per (seed, grid) into a tiny gray image; each frame scales it over
/// the box and turns gray into alpha with a steep color matrix (one image
/// draw per frame however many cells).
abstract final class DissolveNoise {
  static final Map<String, ui.Image> _images = {};

  /// Maximum cells per side (larger grids use larger cells).
  static const maxCells = 512;

  /// The cell size used for [box]: [cell] su, larger when the grid would
  /// exceed [maxCells] per side.
  static double cellOf(Rect box, double cell) =>
      math.max(math.max(0.5, cell), math.max(box.width, box.height) / maxCells);

  /// The (cols, rows) grid of [box] with [cell] su cells.
  static (int, int) grid(Rect box, double cell) {
    final c = cellOf(box, cell);
    return (
      math.max(1, (box.width / c).ceil()),
      math.max(1, (box.height / c).ceil()),
    );
  }

  /// The threshold (0..1) of cell ([col], [row]) for [seed].
  static double threshold(int seed, int col, int row) {
    var h = 0x811c9dc5 ^ seed;
    for (final v in [col, row]) {
      h ^= v & 0xffff;
      h = (h * 0x01000193) & 0xffffffff;
      h ^= v >> 16;
      h = (h * 0x01000193) & 0xffffffff;
    }
    // Mulberry-like finalizer.
    h ^= h >> 15;
    h = (h * 0x2c1b3c6d) & 0xffffffff;
    h ^= h >> 12;
    h = (h * 0x297a2d39) & 0xffffffff;
    h ^= h >> 15;
    return (h & 0xffffff) / 0x1000000;
  }

  static ui.Image _image(int seed, int cols, int rows) {
    final key = '$seed|$cols|$rows';
    final hit = _images[key];
    if (hit != null) return hit;
    // One gray pixel per cell, drawn as one vertex list (two triangles per
    // cell) — a single draw call however many cells.
    final n = cols * rows;
    final positions = Float32List(n * 12);
    final colors = Int32List(n * 6);
    var i = 0, j = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final g = (threshold(seed, x, y) * 255).round();
        final argb = 0xff000000 | (g << 16) | (g << 8) | g;
        final x0 = x.toDouble(), y0 = y.toDouble();
        final x1 = x0 + 1, y1 = y0 + 1;
        positions
          ..[i++] = x0
          ..[i++] = y0
          ..[i++] = x1
          ..[i++] = y0
          ..[i++] = x1
          ..[i++] = y1
          ..[i++] = x0
          ..[i++] = y0
          ..[i++] = x1
          ..[i++] = y1
          ..[i++] = x0
          ..[i++] = y1;
        for (var k = 0; k < 6; k++) {
          colors[j++] = argb.toSigned(32);
        }
      }
    }
    final rec = ui.PictureRecorder();
    Canvas(rec).drawVertices(
      ui.Vertices.raw(ui.VertexMode.triangles, positions, colors: colors),
      BlendMode.dst,
      Paint(),
    );
    final pic = rec.endRecording();
    final img = pic.toImageSync(cols, rows);
    pic.dispose();
    if (_images.length > 24) {
      final old = _images.keys.first;
      _images.remove(old)?.dispose();
    }
    return _images[key] = img;
  }

  /// Creates the noise image of [d] over [box] ahead of time (transition
  /// prefetch).
  static void prepare(Rect box, DissolveState d) {
    final (cols, rows) = grid(box, d.cell);
    _image(d.seed, cols, rows);
  }

  /// Steepness of the gray → alpha step (cells fade over 1/k).
  static const _k = 24.0;

  /// Paints the dissolve mask of [d] over [box] with `BlendMode.dstIn`.
  static void paint(Canvas canvas, Rect box, DissolveState d) {
    final (cols, rows) = grid(box, d.cell);
    final cell = cellOf(box, d.cell);
    final img = _image(d.seed, cols, rows);
    // alpha' = k · (amount · (1 + 1/k) − gray): the cell shows when the
    // amount passes its threshold (fully at amount 1).
    final a = d.amount.clamp(0.0, 1.0) * (1 + 1 / _k);
    final matrix = Float32List.fromList([
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      -_k, 0, 0, 0, _k * a * 255, //
    ]);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, cols.toDouble(), rows.toDouble()),
      Rect.fromLTWH(box.left, box.top, cols * cell, rows * cell),
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.matrix(matrix)
        ..blendMode = BlendMode.dstIn,
    );
  }

  /// Drops the cached noise images (tests).
  static void clear() {
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
  }
}
