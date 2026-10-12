import 'dart:math' as math;
import 'dart:typed_data';

/// Receives the coverage (0..1) of one pixel row: `coverage[x]` for `x0 <= x < x1`.
typedef CoverageSink = void Function(int y, int x0, int x1, Float32List coverage);

/// An anti-aliased scanline polygon rasterizer.
///
/// Edges are accumulated with [addEdge] / [addPolygon] and converted by [fill] into per-pixel
/// coverage: every pixel row is sampled on several sub-scanlines; on each sub-scanline the
/// exact crossings of the active edges are sorted, the fill rule (non-zero or even-odd)
/// yields covered spans, and the spans are accumulated with exact fractional horizontal
/// coverage. A clip rectangle (device px) is applied while rasterizing.
final class CoverageRasterizer {
  /// Creates a rasterizer for a [width] × [height] px target.
  CoverageRasterizer(this.width, this.height)
    : _cov = Float32List(width + 2),
      _diff = Float32List(width + 2),
      _out = Float32List(width + 2);

  /// Target width in px.
  final int width;

  /// Target height in px.
  final int height;

  Float64List _edges = Float64List(4 * 64);
  Int8List _dirs = Int8List(64);
  int _count = 0;
  double _minX = double.infinity, _maxX = -double.infinity;
  double _minY = double.infinity, _maxY = -double.infinity;

  final Float32List _cov;
  final Float32List _diff;
  final Float32List _out;
  Float64List _slope = Float64List(64);
  Int32List _active = Int32List(64);
  Float64List _activeX = Float64List(64);
  Int32List _pending = Int32List(64);
  Int32List _next = Int32List(64);

  /// Number of edges added since the last [clear].
  int get edgeCount => _count;

  /// Removes all edges.
  void clear() {
    _count = 0;
    _minX = _minY = double.infinity;
    _maxX = _maxY = -double.infinity;
  }

  /// Adds the edge (x0, y0) → (x1, y1); [sign] (±1) flips its winding direction.
  void addEdge(double x0, double y0, double x1, double y1, [int sign = 1]) {
    if (y0 == y1) return;
    if (!x0.isFinite || !y0.isFinite || !x1.isFinite || !y1.isFinite) return;
    var dir = sign;
    if (y0 > y1) {
      final tx = x0, ty = y0;
      x0 = x1;
      y0 = y1;
      x1 = tx;
      y1 = ty;
      dir = -dir;
    }
    if (_count == _dirs.length) _grow();
    final i = _count * 4;
    _edges[i] = x0;
    _edges[i + 1] = y0;
    _edges[i + 2] = x1;
    _edges[i + 3] = y1;
    _dirs[_count] = dir;
    _count++;
    if (y0 < _minY) _minY = y0;
    if (y1 > _maxY) _maxY = y1;
    final lx = x0 < x1 ? x0 : x1, rx = x0 < x1 ? x1 : x0;
    if (lx < _minX) _minX = lx;
    if (rx > _maxX) _maxX = rx;
  }

  void _grow() {
    final n = _dirs.length * 2;
    _edges = Float64List(4 * n)..setRange(0, _count * 4, _edges);
    _dirs = Int8List(n)..setRange(0, _count, _dirs);
  }

  /// Adds the closed polygon through the [count] points of [xy] (`x, y` pairs) starting at
  /// point [start]. With [positive] the edges are oriented so the polygon's signed area is
  /// positive; polygons added that way union correctly under the non-zero rule.
  void addPolygon(List<double> xy, {int start = 0, int? count, bool positive = false}) {
    final n = count ?? (xy.length ~/ 2 - start);
    if (n < 2) return;
    final o = start * 2;
    var sign = 1;
    if (positive) {
      var area = 0.0;
      for (var i = 0; i < n; i++) {
        final j = i + 1 == n ? 0 : i + 1;
        area += xy[o + 2 * i] * xy[o + 2 * j + 1] - xy[o + 2 * j] * xy[o + 2 * i + 1];
      }
      if (area == 0) return;
      sign = area > 0 ? 1 : -1;
    }
    for (var i = 0; i < n; i++) {
      final j = i + 1 == n ? 0 : i + 1;
      addEdge(xy[o + 2 * i], xy[o + 2 * i + 1], xy[o + 2 * j], xy[o + 2 * j + 1], sign);
    }
  }

  /// Rasterizes the edges with the non-zero (default) or [evenOdd] rule, restricted to the
  /// clip rectangle, and passes the coverage of each touched row to [sink]. [subsamples] is
  /// the number of sub-scanlines per pixel row (default: 16 for simple shapes, fewer for
  /// complex ones).
  void fill(
    CoverageSink sink, {
    bool evenOdd = false,
    double clipLeft = 0,
    double clipTop = 0,
    double clipRight = double.infinity,
    double clipBottom = double.infinity,
    int? subsamples,
  }) {
    final count = _count;
    if (count == 0) return;
    final cl = math.max(0.0, clipLeft);
    final ct = math.max(0.0, clipTop);
    final cr = math.min(width.toDouble(), clipRight);
    final cb = math.min(height.toDouble(), clipBottom);
    if (!(cr > cl) || !(cb > ct)) return;
    // Shapes entirely outside the clip cover nothing inside it.
    if (_maxX <= cl || _minX >= cr || _maxY <= ct || _minY >= cb) return;
    final n = subsamples ?? (count <= 256 ? 16 : (count <= 8192 ? 8 : 4));
    final w = 1.0 / n;
    final rowStart = math.max(ct.floor(), _minY.floor());
    final rowEnd = math.min(cb.ceil(), _maxY.ceil());
    final rows = rowEnd - rowStart;
    if (rows <= 0) return;

    if (_slope.length < count) {
      final cap = math.max(count, _slope.length * 2);
      _slope = Float64List(cap);
      _active = Int32List(cap);
      _activeX = Float64List(cap);
      _pending = Int32List(cap);
      _next = Int32List(cap);
    }
    final edges = _edges, dirs = _dirs, slope = _slope;
    final active = _active, activeX = _activeX, pending = _pending, next = _next;
    final head = Int32List(rows)..fillRange(0, rows, -1);
    for (var e = 0; e < count; e++) {
      final y0 = edges[4 * e + 1], y1 = edges[4 * e + 3];
      slope[e] = (edges[4 * e + 2] - edges[4 * e]) / (y1 - y0);
      if (y1 <= rowStart) continue;
      var r = y0.floor() - rowStart;
      if (r < 0) r = 0;
      if (r >= rows) continue;
      next[e] = head[r];
      head[r] = e;
    }

    final cov = _cov, diff = _diff, out = _out;
    var nActive = 0, nPending = 0;
    for (var row = 0; row < rows; row++) {
      final y = rowStart + row;
      for (var e = head[row]; e >= 0; e = next[e]) {
        pending[nPending++] = e;
      }
      var rowMin = width + 1, rowMax = -1;
      for (var k = 0; k < n; k++) {
        final ys = y + (k + 0.5) * w;
        if (ys < ct || ys >= cb) continue;
        // Activate pending edges that start at or above this sub-scanline.
        var j = 0;
        for (var i = 0; i < nPending; i++) {
          final e = pending[i];
          if (edges[4 * e + 1] <= ys) {
            if (edges[4 * e + 3] > ys) active[nActive++] = e;
          } else {
            pending[j++] = e;
          }
        }
        nPending = j;
        // Advance active edges, dropping finished ones.
        j = 0;
        for (var i = 0; i < nActive; i++) {
          final e = active[i];
          if (edges[4 * e + 3] <= ys) continue;
          active[j] = e;
          activeX[j] = edges[4 * e] + (ys - edges[4 * e + 1]) * slope[e];
          j++;
        }
        nActive = j;
        // Insertion sort by x (orders are coherent between sub-scanlines).
        for (var i = 1; i < nActive; i++) {
          final x = activeX[i];
          final e = active[i];
          var m = i - 1;
          while (m >= 0 && activeX[m] > x) {
            activeX[m + 1] = activeX[m];
            active[m + 1] = active[m];
            m--;
          }
          activeX[m + 1] = x;
          active[m + 1] = e;
        }
        // Walk crossings and accumulate covered spans.
        var wind = 0;
        var xa = 0.0;
        for (var i = 0; i < nActive; i++) {
          final wasIn = evenOdd ? (wind & 1) != 0 : wind != 0;
          wind += dirs[active[i]];
          final isIn = evenOdd ? (wind & 1) != 0 : wind != 0;
          if (!wasIn && isIn) {
            xa = activeX[i];
          } else if (wasIn && !isIn) {
            final a = xa < cl ? cl : xa;
            var b = activeX[i];
            if (b > cr) b = cr;
            if (b <= a) continue;
            final ia = a.floor(), ib = b.floor();
            if (ia == ib) {
              cov[ia] += (b - a) * w;
            } else {
              cov[ia] += (ia + 1 - a) * w;
              diff[ia + 1] += w;
              diff[ib] -= w;
              cov[ib] += (b - ib) * w;
            }
            if (ia < rowMin) rowMin = ia;
            if (ib > rowMax) rowMax = ib;
          }
        }
      }
      if (rowMax >= rowMin) {
        var running = 0.0;
        var lo = -1, hi = -1;
        for (var x = rowMin; x <= rowMax; x++) {
          running += diff[x];
          final c = cov[x] + running;
          diff[x] = 0;
          cov[x] = 0;
          if (x >= width) continue;
          final v = c >= 1 ? 1.0 : (c <= 0 ? 0.0 : c);
          out[x] = v;
          if (v > 0) {
            if (lo < 0) lo = x;
            hi = x;
          }
        }
        if (lo >= 0) sink(y, lo, hi + 1, out);
      }
    }
  }
}
