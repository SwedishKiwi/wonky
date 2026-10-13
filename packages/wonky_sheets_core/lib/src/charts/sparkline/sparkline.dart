import 'dart:math' as math;
import 'dart:typed_data';

import '../../formula/values/fvalue.dart';
import '../data/data_algorithms.dart';
import '../scene/geometry.dart';
import '../scene/scene.dart';

/// `SPARKLINE` chart types (05 §17).
enum SparklineType { line, column, winloss, bar }

/// Invalid `SPARKLINE` option (the engine maps it to `#VALUE!`).
final class SparklineOptionException implements Exception {
  /// Creates the exception for option [option].
  const SparklineOptionException(this.option);

  final String option;

  /// The user-facing message (05 §17).
  String get message => 'Invalid option for SPARKLINE: $option';

  @override
  String toString() => message;
}

/// Normalized sparkline data: y values and optional x values (2-column data).
final class SparklineData {
  /// Creates data.
  const SparklineData(this.y, [this.x]);

  final Float64List y;
  final Float64List? x;

  int get length => y.length;
}

/// Parsed `SPARKLINE` options (05 §17). Colors are ARGB ints (null = default).
final class SparklineSpec {
  /// Creates a spec.
  const SparklineSpec({
    this.type = SparklineType.line,
    this.xmin,
    this.xmax,
    this.ymin,
    this.ymax,
    this.color,
    this.lowColor,
    this.highColor,
    this.firstColor,
    this.lastColor,
    this.negColor,
    this.emptyAsZero = false,
    this.nanAsZero = false,
    this.axis = false,
    this.axisColor,
    this.rtl = false,
    this.lineWidth = 1,
    this.max,
    this.color1,
    this.color2,
  });

  /// Parses options from an `{option, value}` 2-column array ([FArray]), a single row/column
  /// pair list, or a map. Throws [SparklineOptionException] for unknown options or values.
  factory SparklineSpec.fromOptions(Object? options) {
    final pairs = <(String, Object?)>[];
    switch (options) {
      case null || FEmpty() || FOmitted():
        break;
      case FArray a:
        if (a.cols == 2) {
          for (var r = 0; r < a.rows; r++) {
            pairs.add((_text(a.at(r, 0)), _plain(a.at(r, 1))));
          }
        } else if (a.rows == 2 && a.cols != 2) {
          for (var col = 0; col < a.cols; col++) {
            pairs.add((_text(a.at(0, col)), _plain(a.at(1, col))));
          }
        } else if (a.length == 0) {
          break;
        } else {
          throw SparklineOptionException(_text(a.topLeft));
        }
      case Map<Object?, Object?> m:
        for (final e in m.entries) {
          pairs.add((
            '${e.key}',
            e.value is FValue ? _plain(e.value! as FValue) : e.value,
          ));
        }
      default:
        throw SparklineOptionException('$options');
    }
    var type = SparklineType.line;
    for (final (k, v) in pairs) {
      if (k.toLowerCase() == 'charttype') {
        type = switch ('$v'.toLowerCase()) {
          'line' => SparklineType.line,
          'column' => SparklineType.column,
          'winloss' => SparklineType.winloss,
          'bar' => SparklineType.bar,
          _ => throw SparklineOptionException('charttype'),
        };
      }
    }
    double? xmin, xmax, ymin, ymax, max;
    int? color, low, high, first, last, neg, axisColor, c1, c2;
    var emptyZero = false, nanZero = false, axis = false, rtl = false;
    var lw = 1.0;
    const common = {'charttype', 'empty', 'nan', 'rtl'};
    final allowed = switch (type) {
      SparklineType.line => {
        ...common,
        'xmin',
        'xmax',
        'ymin',
        'ymax',
        'color',
        'linewidth',
      },
      SparklineType.column || SparklineType.winloss => {
        ...common,
        'color',
        'lowcolor',
        'highcolor',
        'firstcolor',
        'lastcolor',
        'negcolor',
        'axis',
        'axiscolor',
        'ymin',
        'ymax',
      },
      SparklineType.bar => {...common, 'max', 'color1', 'color2'},
    };
    for (final (rawKey, v) in pairs) {
      final k = rawKey.toLowerCase().trim();
      if (k.isEmpty && v == null) continue;
      if (!allowed.contains(k)) throw SparklineOptionException(rawKey);
      double number() {
        if (v is num) return v.toDouble();
        final d = double.tryParse('$v');
        if (d == null) throw SparklineOptionException(rawKey);
        return d;
      }

      int col() => parseColor(v) ?? (throw SparklineOptionException(rawKey));
      bool flag() {
        if (v is bool) return v;
        if (v is num) return v != 0;
        final s = '$v'.toLowerCase();
        if (s == 'true') return true;
        if (s == 'false') return false;
        throw SparklineOptionException(rawKey);
      }

      switch (k) {
        case 'charttype':
          break;
        case 'xmin':
          xmin = number();
        case 'xmax':
          xmax = number();
        case 'ymin':
          ymin = number();
        case 'ymax':
          ymax = number();
        case 'max':
          max = number();
        case 'color':
          color = col();
        case 'lowcolor':
          low = col();
        case 'highcolor':
          high = col();
        case 'firstcolor':
          first = col();
        case 'lastcolor':
          last = col();
        case 'negcolor':
          neg = col();
        case 'axiscolor':
          axisColor = col();
        case 'color1':
          c1 = col();
        case 'color2':
          c2 = col();
        case 'axis':
          axis = flag();
        case 'rtl':
          rtl = flag();
        case 'linewidth':
          lw = number();
          if (lw < 0) throw SparklineOptionException(rawKey);
        case 'empty':
          final s = '$v'.toLowerCase();
          if (s != 'zero' && s != 'ignore') {
            throw SparklineOptionException(rawKey);
          }
          emptyZero = s == 'zero';
        case 'nan':
          final s = '$v'.toLowerCase();
          if (s != 'convert' && s != 'ignore') {
            throw SparklineOptionException(rawKey);
          }
          nanZero = s == 'convert';
      }
    }
    return SparklineSpec(
      type: type,
      xmin: xmin,
      xmax: xmax,
      ymin: ymin,
      ymax: ymax,
      color: color,
      lowColor: low,
      highColor: high,
      firstColor: first,
      lastColor: last,
      negColor: neg,
      emptyAsZero: emptyZero,
      nanAsZero: nanZero,
      axis: axis,
      axisColor: axisColor,
      rtl: rtl,
      lineWidth: lw,
      max: max,
      color1: c1,
      color2: c2,
    );
  }

  final SparklineType type;
  final double? xmin;
  final double? xmax;
  final double? ymin;
  final double? ymax;
  final int? color;
  final int? lowColor;
  final int? highColor;
  final int? firstColor;
  final int? lastColor;
  final int? negColor;

  /// `empty`: zero (true) or ignore.
  final bool emptyAsZero;

  /// `nan`: convert to zero (true) or ignore.
  final bool nanAsZero;
  final bool axis;
  final int? axisColor;
  final bool rtl;
  final double lineWidth;

  /// Bar: maximum of the horizontal axis.
  final double? max;
  final int? color1;
  final int? color2;

  /// Normalizes the `data` argument: a row/column of values, or 2 columns (x, y) for line
  /// sparklines. Empty cells and non-numeric values follow `empty` / `nan` (ignored → NaN).
  SparklineData normalize(FValue data) {
    final a = data is FArray ? data : FArray(1, 1, [data]);
    double conv(FValue v) {
      final s = v is FRich ? v.scalar : v;
      if (s is FNumber) return s.v;
      if (s is FEmpty) return emptyAsZero ? 0 : double.nan;
      return nanAsZero ? 0 : double.nan;
    }

    if (type == SparklineType.line && a.cols == 2 && a.rows > 2) {
      final x = Float64List(a.rows), y = Float64List(a.rows);
      for (var r = 0; r < a.rows; r++) {
        x[r] = conv(a.at(r, 0));
        y[r] = conv(a.at(r, 1));
      }
      return SparklineData(y, x);
    }
    final out = Float64List(a.length);
    var k = 0;
    for (final v in a.elements) {
      out[k++] = conv(v);
    }
    return SparklineData(out);
  }

  static String _text(FValue v) => switch (v) {
    FText(v: final t) => t,
    FNumber() => v.debugText,
    FBool(v: final b) => b ? 'TRUE' : 'FALSE',
    _ => '',
  };

  static Object? _plain(FValue v) => switch (v) {
    FText(v: final t) => t,
    FNumber(v: final n) => n,
    FBool(v: final b) => b,
    FRich(:final scalar) => _plain(scalar),
    _ => null,
  };

  /// Parses `#RRGGBB`, `#RGB` or a CSS color name to opaque ARGB.
  static int? parseColor(Object? v) {
    if (v is! String) return null;
    final s = v.trim().toLowerCase();
    if (s.startsWith('#')) {
      var hex = s.substring(1);
      if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
      if (hex.length != 6) return null;
      final n = int.tryParse(hex, radix: 16);
      return n == null ? null : 0xFF000000 | n;
    }
    final named = _css[s];
    return named == null ? null : 0xFF000000 | named;
  }

  static const _css = <String, int>{
    'black': 0x000000,
    'white': 0xFFFFFF,
    'red': 0xFF0000,
    'green': 0x008000,
    'blue': 0x0000FF,
    'yellow': 0xFFFF00,
    'orange': 0xFFA500,
    'purple': 0x800080,
    'pink': 0xFFC0CB,
    'brown': 0xA52A2A,
    'gray': 0x808080,
    'grey': 0x808080,
    'cyan': 0x00FFFF,
    'aqua': 0x00FFFF,
    'magenta': 0xFF00FF,
    'fuchsia': 0xFF00FF,
    'lime': 0x00FF00,
    'navy': 0x000080,
    'teal': 0x008080,
    'maroon': 0x800000,
    'olive': 0x808000,
    'silver': 0xC0C0C0,
    'gold': 0xFFD700,
    'indigo': 0x4B0082,
    'violet': 0xEE82EE,
    'darkgreen': 0x006400,
    'darkblue': 0x00008B,
    'darkred': 0x8B0000,
    'darkgray': 0xA9A9A9,
    'darkgrey': 0xA9A9A9,
    'lightgray': 0xD3D3D3,
    'lightgrey': 0xD3D3D3,
    'lightblue': 0xADD8E6,
    'lightgreen': 0x90EE90,
    'coral': 0xFF7F50,
    'salmon': 0xFA8072,
    'tomato': 0xFF6347,
    'crimson': 0xDC143C,
    'turquoise': 0x40E0D0,
    'skyblue': 0x87CEEB,
    'steelblue': 0x4682B4,
    'royalblue': 0x4169E1,
    'tan': 0xD2B48C,
    'khaki': 0xF0E68C,
    'beige': 0xF5F5DC,
    'chocolate': 0xD2691E,
    'orchid': 0xDA70D6,
    'plum': 0xDDA0DD,
    'slategray': 0x708090,
    'forestgreen': 0x228B22,
    'seagreen': 0x2E8B57,
    'firebrick': 0xB22222,
  };
}

/// Lays out sparklines into scenes (no axes or labels; 08 §2).
abstract final class SparklineRenderer {
  /// Data beyond this many points is downsampled (min/max per pixel bucket, 05 §17).
  static const maxPoints = 10000;

  /// Lays out [values] at [width] × [height] px. [defaultColor] is the theme `chart1` token.
  static ChartScene layout(
    SparklineSpec spec,
    SparklineData values,
    double width,
    double height, {
    int defaultColor = 0xFF4285F4,
    int background = 0x00000000,
    double padding = 2,
  }) {
    final prims = <ScenePrimitive>[];
    final r = ChartRect(
      padding,
      padding,
      math.max(0, width - 2 * padding),
      math.max(0, height - 2 * padding),
    );
    if (!r.isEmpty && values.length > 0) {
      switch (spec.type) {
        case SparklineType.line:
          _line(spec, values, r, defaultColor, prims);
        case SparklineType.column || SparklineType.winloss:
          _columns(spec, values.y, r, defaultColor, prims);
        case SparklineType.bar:
          _bar(spec, values.y, r, defaultColor, prims);
      }
    }
    return ChartScene(
      width: width,
      height: height,
      background: background,
      primitives: prims,
      plotArea: r,
    );
  }

  static void _line(
    SparklineSpec spec,
    SparklineData d,
    ChartRect r,
    int color,
    List<ScenePrimitive> out,
  ) {
    var ys = d.y;
    var xs = d.x;
    final n = ys.length;
    if (xs == null) {
      xs = Float64List(n);
      for (var i = 0; i < n; i++) {
        xs[i] = i.toDouble();
      }
    }
    var idx = Int32List.fromList([for (var i = 0; i < n; i++) i]);
    if (n > maxPoints) idx = Lttb.minMax(ys, math.max(1, r.width.ceil()));
    var x0 = spec.xmin ?? double.infinity, x1 = spec.xmax ?? -double.infinity;
    var y0 = spec.ymin ?? double.infinity, y1 = spec.ymax ?? -double.infinity;
    for (final i in idx) {
      if (ys[i].isNaN || xs[i].isNaN) continue;
      if (spec.xmin == null) x0 = math.min(x0, xs[i]);
      if (spec.xmax == null) x1 = math.max(x1, xs[i]);
      if (spec.ymin == null) y0 = math.min(y0, ys[i]);
      if (spec.ymax == null) y1 = math.max(y1, ys[i]);
    }
    if (!x0.isFinite || !y0.isFinite) return;
    if (x1 <= x0) x1 = x0 + 1;
    if (y1 <= y0) {
      y0 -= 0.5;
      y1 += 0.5;
    }
    double px(double x) {
      final t = (x - x0) / (x1 - x0);
      return spec.rtl ? r.right - t * r.width : r.left + t * r.width;
    }

    double py(double y) =>
        r.bottom - ((y.clamp(y0, y1) - y0) / (y1 - y0)) * r.height;
    final stroke = SStroke(
      spec.color ?? color,
      width: spec.lineWidth,
      cap: SStrokeCap.round,
      join: SStrokeJoin.round,
    );
    final run = <double>[];
    final runIdx = <int>[];
    final children = <ScenePrimitive>[];
    void flush() {
      if (run.length >= 4) {
        children.add(
          SPolyline(
            Float64List.fromList(run),
            stroke,
            indices: Int32List.fromList(runIdx),
            tag: const SceneTag(SceneRole.series),
          ),
        );
      } else if (run.length == 2) {
        children.add(
          SMarkers(
            Float64List.fromList(run),
            MarkerShape.circle,
            math.max(2, spec.lineWidth * 2),
            fill: spec.color ?? color,
            indices: Int32List.fromList(runIdx),
            tag: const SceneTag(SceneRole.point),
          ),
        );
      }
      run.clear();
      runIdx.clear();
    }

    for (final i in idx) {
      if (ys[i].isNaN || xs[i].isNaN) {
        continue; // ignored values are connected over
      }
      run
        ..add(px(xs[i]))
        ..add(py(ys[i]));
      runIdx.add(i);
    }
    flush();
    if (spec.lineWidth > 0) out.add(SClip(r.inflate(spec.lineWidth), children));
  }

  static void _columns(
    SparklineSpec spec,
    Float64List ys,
    ChartRect r,
    int color,
    List<ScenePrimitive> out,
  ) {
    final n = ys.length;
    final winloss = spec.type == SparklineType.winloss;
    var lo = spec.ymin ?? double.infinity, hi = spec.ymax ?? -double.infinity;
    var minI = -1, maxI = -1, firstI = -1, lastI = -1;
    for (var i = 0; i < n; i++) {
      final v = ys[i];
      if (v.isNaN) continue;
      if (firstI < 0) firstI = i;
      lastI = i;
      if (minI < 0 || v < ys[minI]) minI = i;
      if (maxI < 0 || v > ys[maxI]) maxI = i;
      if (spec.ymin == null) lo = math.min(lo, v);
      if (spec.ymax == null) hi = math.max(hi, v);
    }
    if (firstI < 0) return;
    if (winloss) {
      lo = -1;
      hi = 1;
    } else {
      if (spec.ymin == null) lo = math.min(lo, 0);
      if (spec.ymax == null) hi = math.max(hi, 0);
      if (hi <= lo) hi = lo + 1;
    }
    final step = r.width / n;
    final gap = step > 3 ? math.max(1.0, step * 0.15) : 0.0;
    double py(double v) =>
        r.bottom - (v.clamp(lo, hi) - lo) / (hi - lo) * r.height;
    final zero = py(0);
    for (var i = 0; i < n; i++) {
      final v = ys[i];
      if (v.isNaN) continue;
      final slot = spec.rtl ? n - 1 - i : i;
      final x = r.left + slot * step + gap / 2;
      var c = spec.color ?? color;
      if (i == firstI && spec.firstColor != null) c = spec.firstColor!;
      if (i == lastI && spec.lastColor != null) c = spec.lastColor!;
      if (i == minI && spec.lowColor != null) c = spec.lowColor!;
      if (i == maxI && spec.highColor != null) c = spec.highColor!;
      if (v < 0 && spec.negColor != null) c = spec.negColor!;
      double top, bottom;
      if (winloss) {
        if (v == 0) continue;
        top = v > 0 ? r.top : r.centerY;
        bottom = v > 0 ? r.centerY : r.bottom;
      } else {
        final y = py(v);
        top = math.min(y, zero);
        bottom = math.max(y, zero);
        if (bottom - top < 0.5) bottom = top + 0.5;
      }
      out.add(
        SRect(
          ChartRect(x, top, math.max(0.5, step - gap), bottom - top),
          fill: c,
          tag: SceneTag(SceneRole.point, pointIndex: i),
        ),
      );
    }
    if (spec.axis) {
      final y = winloss ? r.centerY : zero;
      out.add(
        SPolyline(
          Float64List.fromList([r.left, y, r.right, y]),
          SStroke(spec.axisColor ?? 0xFF000000),
          tag: const SceneTag(SceneRole.axisLine),
        ),
      );
    }
  }

  static void _bar(
    SparklineSpec spec,
    Float64List ys,
    ChartRect r,
    int color,
    List<ScenePrimitive> out,
  ) {
    final a = ys.isNotEmpty && !ys[0].isNaN ? math.max(0.0, ys[0]) : 0.0;
    final b = ys.length > 1 && !ys[1].isNaN ? math.max(0.0, ys[1]) : 0.0;
    final max = spec.max ?? (a + b);
    if (!(max > 0)) return;
    final c1 = spec.color1 ?? color;
    final c2 = spec.color2 ?? Argb.lerp(color, 0xFFFFFFFF, 0.55);
    final w1 = r.width * (a / max).clamp(0.0, 1.0);
    final w2 = r.width * (b / max).clamp(0.0, 1.0 - (a / max).clamp(0.0, 1.0));
    if (spec.rtl) {
      out.add(
        SRect(
          ChartRect(r.right - w1, r.top, w1, r.height),
          fill: c1,
          tag: const SceneTag(SceneRole.point, pointIndex: 0),
        ),
      );
      if (w2 > 0) {
        out.add(
          SRect(
            ChartRect(r.right - w1 - w2, r.top, w2, r.height),
            fill: c2,
            tag: const SceneTag(SceneRole.point, pointIndex: 1),
          ),
        );
      }
    } else {
      out.add(
        SRect(
          ChartRect(r.left, r.top, w1, r.height),
          fill: c1,
          tag: const SceneTag(SceneRole.point, pointIndex: 0),
        ),
      );
      if (w2 > 0) {
        out.add(
          SRect(
            ChartRect(r.left + w1, r.top, w2, r.height),
            fill: c2,
            tag: const SceneTag(SceneRole.point, pointIndex: 1),
          ),
        );
      }
    }
  }
}
