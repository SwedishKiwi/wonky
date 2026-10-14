import '../addressing/grid_geometry.dart';
import 'attributes.dart';

/// Border line styles (06 §8.1) with their conflict weights.
enum BorderStyle {
  thin(1, 2),
  medium(2, 4),
  thick(3, 6),
  dashed(1, 3),
  dotted(1, 1),
  double(3, 5);

  const BorderStyle(this.widthPx, this.weight);

  /// Width at 100 % zoom.
  final int widthPx;

  /// Conflict weight (higher wins).
  final int weight;

  /// Parses a style name; null if unknown.
  static BorderStyle? tryParse(String s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

/// One cell edge value: `"<style>|<color>"` or `"none"` (06 §8.2).
final class BorderSpec {
  /// Creates a visible border.
  const BorderSpec(this.style, [this.color = 'auto']);

  /// The explicit "no border" value (stops inheritance).
  static const BorderSpec none = BorderSpec._none();

  const BorderSpec._none() : style = null, color = 'auto';

  /// Style; null for [none].
  final BorderStyle? style;

  /// `#RRGGBB`, `theme:<key>` or `auto`.
  final String color;

  /// Whether this is the explicit no-border value.
  bool get isNone => style == null;

  /// Conflict weight (`none` = 0).
  int get weight => style?.weight ?? 0;

  /// Parses a stored edge value; null for null or malformed input.
  static BorderSpec? tryParse(String? s) {
    if (s == null) return null;
    if (s == 'none') return none;
    final bar = s.indexOf('|');
    final styleName = bar < 0 ? s : s.substring(0, bar);
    final style = BorderStyle.tryParse(styleName);
    if (style == null) return null;
    final color = bar < 0 || bar == s.length - 1
        ? 'auto'
        : s.substring(bar + 1);
    return BorderSpec(style, color);
  }

  /// Stored representation.
  String encode() => isNone ? 'none' : '${style!.name}|$color';

  /// Resolves the shared edge between the top/left cell's [first] edge and the
  /// bottom/right cell's [second] edge (06 §8.4): heavier style wins; equal
  /// weight → [first]; `none`/null lose against any visible style.
  static BorderSpec? resolveShared(BorderSpec? first, BorderSpec? second) {
    final a = first == null || first.isNone ? null : first;
    final b = second == null || second.isNone ? null : second;
    if (a == null) return b;
    if (b == null) return a;
    return b.weight > a.weight ? b : a;
  }

  @override
  bool operator ==(Object other) =>
      other is BorderSpec && other.style == style && other.color == color;

  @override
  int get hashCode => Object.hash(style, color);

  @override
  String toString() => encode();
}

/// Border picker presets (06 §8.3).
enum BorderPreset {
  all,
  inner,
  horizontal,
  vertical,
  outer,
  top,
  bottom,
  left,
  right,
  clear,
}

/// One planned edge write: set [attr] of the cell at ([row], [col]) to [value]
/// (encoded edge or null).
typedef EdgeWrite = ({int row, int col, FormatAttr attr, String? value});

/// Maps a border preset on an index rectangle to edge writes (06 §8.3),
/// including canonical edge ownership (inner lines on the upper/left cell)
/// and facing-edge clearing.
abstract final class BorderPresetPlanner {
  /// Edge writes for [preset] with [spec] over [rect]. [rowCount]/[colCount]
  /// bound the sheet so neighbours outside the grid are skipped.
  static List<EdgeWrite> plan(
    BorderPreset preset,
    GridRect rect,
    BorderSpec spec, {
    required int rowCount,
    required int colCount,
  }) {
    final v = spec.encode();
    final writes = <(int, int, FormatAttr), String?>{};

    void set(int r, int c, FormatAttr a, String? value) {
      if (r < 0 || c < 0 || r >= rowCount || c >= colCount) return;
      writes[(r, c, a)] = value;
    }

    // Writes an edge and clears the facing edge of the neighbour.
    void edge(int r, int c, FormatAttr a, String? value) {
      set(r, c, a, value);
      switch (a) {
        case FormatAttr.borderTop:
          if (!writes.containsKey((r - 1, c, FormatAttr.borderBottom))) {
            set(r - 1, c, FormatAttr.borderBottom, null);
          }
        case FormatAttr.borderBottom:
          if (!writes.containsKey((r + 1, c, FormatAttr.borderTop))) {
            set(r + 1, c, FormatAttr.borderTop, null);
          }
        case FormatAttr.borderLeft:
          if (!writes.containsKey((r, c - 1, FormatAttr.borderRight))) {
            set(r, c - 1, FormatAttr.borderRight, null);
          }
        case FormatAttr.borderRight:
          if (!writes.containsKey((r, c + 1, FormatAttr.borderLeft))) {
            set(r, c + 1, FormatAttr.borderLeft, null);
          }
        default:
          break;
      }
    }

    void top() {
      for (var c = rect.left; c <= rect.right; c++) {
        edge(rect.top, c, FormatAttr.borderTop, v);
      }
    }

    void bottom() {
      for (var c = rect.left; c <= rect.right; c++) {
        edge(rect.bottom, c, FormatAttr.borderBottom, v);
      }
    }

    void left() {
      for (var r = rect.top; r <= rect.bottom; r++) {
        edge(r, rect.left, FormatAttr.borderLeft, v);
      }
    }

    void right() {
      for (var r = rect.top; r <= rect.bottom; r++) {
        edge(r, rect.right, FormatAttr.borderRight, v);
      }
    }

    void innerH() {
      for (var r = rect.top; r < rect.bottom; r++) {
        for (var c = rect.left; c <= rect.right; c++) {
          edge(r, c, FormatAttr.borderBottom, v);
        }
      }
    }

    void innerV() {
      for (var r = rect.top; r <= rect.bottom; r++) {
        for (var c = rect.left; c < rect.right; c++) {
          edge(r, c, FormatAttr.borderRight, v);
        }
      }
    }

    switch (preset) {
      case BorderPreset.all:
        top();
        bottom();
        left();
        right();
        innerH();
        innerV();
      case BorderPreset.inner:
        innerH();
        innerV();
      case BorderPreset.horizontal:
        innerH();
      case BorderPreset.vertical:
        innerV();
      case BorderPreset.outer:
        top();
        bottom();
        left();
        right();
      case BorderPreset.top:
        top();
      case BorderPreset.bottom:
        bottom();
      case BorderPreset.left:
        left();
      case BorderPreset.right:
        right();
      case BorderPreset.clear:
        for (var r = rect.top; r <= rect.bottom; r++) {
          for (var c = rect.left; c <= rect.right; c++) {
            for (final a in FormatAttr.borders) {
              set(r, c, a, null);
            }
          }
        }
        for (var c = rect.left; c <= rect.right; c++) {
          set(rect.top - 1, c, FormatAttr.borderBottom, null);
          set(rect.bottom + 1, c, FormatAttr.borderTop, null);
        }
        for (var r = rect.top; r <= rect.bottom; r++) {
          set(r, rect.left - 1, FormatAttr.borderRight, null);
          set(r, rect.right + 1, FormatAttr.borderLeft, null);
        }
    }

    // Inner lines live on the upper/left cell (bottom/right edges); `edge`
    // already cleared the facing top/left edges of the cells below/right.
    return [
      for (final e in writes.entries)
        (row: e.key.$1, col: e.key.$2, attr: e.key.$3, value: e.value),
    ];
  }
}
