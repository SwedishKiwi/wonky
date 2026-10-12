import 'dart:math' as math;

import '../format/borders.dart';

/// Parsed border edge from CSS.
typedef CssBorder = ({double? widthPx, String? style, String? color, bool widthInPt});

/// Minimal, tolerant CSS helpers for clipboard HTML (03 §12.5).
abstract final class Css {
  /// Parses `a:b; c:d` into lower-case property → trimmed value (later
  /// declarations win; `!important` is dropped).
  static Map<String, String> parseDeclarations(String? style) {
    final out = <String, String>{};
    if (style == null || style.isEmpty) return out;
    var depth = 0;
    int? quote;
    var start = 0;
    void take(int end) {
      final decl = style.substring(start, end);
      final colon = decl.indexOf(':');
      if (colon > 0) {
        final k = decl.substring(0, colon).trim().toLowerCase();
        var v = decl.substring(colon + 1).trim();
        final imp = v.toLowerCase().lastIndexOf('!important');
        if (imp >= 0) v = v.substring(0, imp).trim();
        if (k.isNotEmpty) out[k] = v;
      }
    }

    for (var i = 0; i < style.length; i++) {
      final c = style.codeUnitAt(i);
      if (quote != null) {
        if (c == 0x5c) {
          i++;
        } else if (c == quote) {
          quote = null;
        }
        continue;
      }
      if (c == 0x22 || c == 0x27) {
        quote = c;
      } else if (c == 0x28) {
        depth++;
      } else if (c == 0x29) {
        depth = math.max(0, depth - 1);
      } else if (c == 0x3b && depth == 0) {
        take(i);
        start = i + 1;
      }
    }
    take(style.length);
    return out;
  }

  /// CSS string value: strips surrounding quotes and resolves escapes
  /// (`\0022` hex escapes and `\.`-style escapes, as Excel writes
  /// `mso-number-format:"0\.00"`).
  static String unescape(String v) {
    var s = v.trim();
    if (s.length >= 2 &&
        (s.startsWith('"') && s.endsWith('"') || s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1);
    }
    if (!s.contains(r'\')) return s;
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c != 0x5c || i + 1 >= s.length) {
        b.writeCharCode(c);
        i++;
        continue;
      }
      var j = i + 1;
      final hs = j;
      while (j < s.length && j - hs < 6 && _isHex(s.codeUnitAt(j))) {
        j++;
      }
      if (j > hs) {
        final cp = int.parse(s.substring(hs, j), radix: 16);
        b.writeCharCode(cp == 0 || cp > 0x10ffff ? 0xfffd : cp);
        if (j < s.length && s.codeUnitAt(j) == 0x20) j++;
        i = j;
      } else {
        b.writeCharCode(s.codeUnitAt(i + 1));
        i += 2;
      }
    }
    return b.toString();
  }

  static bool _isHex(int c) =>
      (c >= 0x30 && c <= 0x39) || ((c | 0x20) >= 0x61 && (c | 0x20) <= 0x66);

  /// Parses a CSS color to `#RRGGBB`; null for `transparent`, fully
  /// transparent colors, `inherit` and unparseable values. Excel's
  /// `windowtext` / `auto` map to black.
  static String? color(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'windowtext' || v == 'auto' || v == 'currentcolor' || v == 'black') return '#000000';
    if (v.startsWith('#')) {
      final h = v.substring(1);
      if (!RegExp(r'^[0-9a-f]+$').hasMatch(h)) return null;
      switch (h.length) {
        case 3:
        case 4:
          if (h.length == 4 && h[3] == '0') return null;
          return '#${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}'.toUpperCase();
        case 6:
          return '#$h'.toUpperCase();
        case 8:
          if (h.substring(6) == '00') return null;
          return '#${h.substring(0, 6)}'.toUpperCase();
      }
      return null;
    }
    final fn = RegExp(r'^(rgba?|hsla?)\((.*)\)$').firstMatch(v);
    if (fn != null) {
      final parts = fn
          .group(2)!
          .split(RegExp(r'[\s,/]+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length < 3) return null;
      if (parts.length >= 4) {
        final a = _component(parts[3], 1);
        if (a != null && a <= 0) return null;
      }
      if (fn.group(1)!.startsWith('rgb')) {
        final r = _component(parts[0], 255);
        final g = _component(parts[1], 255);
        final b = _component(parts[2], 255);
        if (r == null || g == null || b == null) return null;
        return _hex(r, g, b);
      }
      final h = double.tryParse(parts[0].replaceAll('deg', ''));
      final s = _component(parts[1], 1);
      final l = _component(parts[2], 1);
      if (h == null || s == null || l == null) return null;
      return _hsl(h, s, l);
    }
    final named = _named[v];
    if (named != null) return '#$named';
    return null;
  }

  static double? _component(String p, double max) {
    if (p.endsWith('%')) {
      final d = double.tryParse(p.substring(0, p.length - 1));
      return d == null ? null : (d / 100 * max).clamp(0, max).toDouble();
    }
    final d = double.tryParse(p);
    return d?.clamp(0, max).toDouble();
  }

  static String _hex(double r, double g, double b) {
    String h(double x) => x.round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${h(r)}${h(g)}${h(b)}'.toUpperCase();
  }

  static String _hsl(double h, double s, double l) {
    final hh = ((h % 360) + 360) % 360 / 360;
    double f(double t) {
      var x = t;
      if (x < 0) x += 1;
      if (x > 1) x -= 1;
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      if (x < 1 / 6) return p + (q - p) * 6 * x;
      if (x < 1 / 2) return q;
      if (x < 2 / 3) return p + (q - p) * (2 / 3 - x) * 6;
      return p;
    }

    if (s == 0) return _hex(l * 255, l * 255, l * 255);
    return _hex(f(hh + 1 / 3) * 255, f(hh) * 255, f(hh - 1 / 3) * 255);
  }

  /// A CSS length in px (`px`, `pt`, `pc`, `in`, `cm`, `mm`, `em`, unitless =
  /// px). Null when unparseable.
  static double? lengthPx(String? value, {double emPx = 13.333}) {
    if (value == null) return null;
    final m = RegExp(r'^\s*(-?\d*\.?\d+)\s*([a-z%]*)\s*$').firstMatch(value.toLowerCase());
    if (m == null) return null;
    final n = double.parse(m.group(1)!);
    return switch (m.group(2)!) {
      '' || 'px' => n,
      'pt' => n * 4 / 3,
      'pc' => n * 16,
      'in' => n * 96,
      'cm' => n * 96 / 2.54,
      'mm' => n * 96 / 25.4,
      'em' || 'rem' => n * emPx,
      '%' => n / 100 * emPx,
      _ => null,
    };
  }

  /// A CSS `font-size` in points (keywords and relative units relative to
  /// 10 pt). Clamped to 1–400.
  static double? fontSizePt(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    const keywords = {
      'xx-small': 7.0,
      'x-small': 7.5,
      'small': 10.0,
      'medium': 12.0,
      'large': 13.5,
      'x-large': 18.0,
      'xx-large': 24.0,
      'xxx-large': 36.0,
    };
    final k = keywords[v];
    if (k != null) return k;
    final px = lengthPx(v, emPx: 10 * 4 / 3);
    if (px == null || px <= 0) return null;
    final pt = (px * 0.75 * 10).round() / 10;
    return pt.clamp(1, 400).toDouble();
  }

  /// `<font size="N">` (1–7, or relative `+1`) in points.
  static double? fontTagSizePt(String? size) {
    if (size == null) return null;
    final s = size.trim();
    var n = int.tryParse(s.replaceAll('+', ''));
    if (n == null) return null;
    if (s.startsWith('+') || s.startsWith('-')) n = 3 + n;
    const table = [7.5, 7.5, 10.0, 12.0, 13.5, 18.0, 24.0, 36.0];
    return table[n.clamp(1, 7)];
  }

  /// Parses a border shorthand (`1px solid #000`, `.5pt solid windowtext`,
  /// `none`).
  static CssBorder border(String value) {
    double? width;
    String? style;
    String? color;
    var inPt = false;
    for (final raw in _splitTokens(value)) {
      final t = raw.toLowerCase();
      if (_borderStyles.contains(t)) {
        style = t;
      } else if (t == 'thin' || t == 'medium' || t == 'thick') {
        width = switch (t) {
          'thin' => 1.0,
          'medium' => 3.0,
          _ => 5.0,
        };
      } else if (lengthPx(t) != null) {
        width = lengthPx(t);
        inPt = t.endsWith('pt');
      } else {
        color = Css.color(t) ?? color;
      }
    }
    return (widthPx: width, style: style, color: color, widthInPt: inPt);
  }

  static const _borderStyles = {
    'none',
    'hidden',
    'solid',
    'dashed',
    'dotted',
    'double',
    'groove',
    'ridge',
    'inset',
    'outset',
  };

  /// Splits on whitespace outside parentheses (`rgb(0, 0, 0)` stays one token).
  static List<String> _splitTokens(String v) {
    final out = <String>[];
    final b = StringBuffer();
    var depth = 0;
    for (final c in v.trim().runes) {
      if (c == 0x28) depth++;
      if (c == 0x29) depth = math.max(0, depth - 1);
      if ((c == 0x20 || c == 0x09) && depth == 0) {
        if (b.isNotEmpty) out.add(b.toString());
        b.clear();
      } else {
        b.writeCharCode(c);
      }
    }
    if (b.isNotEmpty) out.add(b.toString());
    return out;
  }

  /// Expands 1–4 value box shorthands (`border-width: 1px 2px`) to
  /// (top, right, bottom, left).
  static List<String> box(String v) {
    final p = _splitTokens(v);
    return switch (p.length) {
      0 => const ['', '', '', ''],
      1 => [p[0], p[0], p[0], p[0]],
      2 => [p[0], p[1], p[0], p[1]],
      3 => [p[0], p[1], p[2], p[1]],
      _ => [p[0], p[1], p[2], p[3]],
    };
  }

  /// Maps a CSS border to the nearest [BorderSpec]; `none`/zero width →
  /// [BorderSpec.none]; null when nothing is specified. Widths: px < 1.5 thin,
  /// < 2.5 medium, else thick; in pt (Excel) < 0.75 thin, < 1.25 medium, else
  /// thick.
  static BorderSpec? borderSpec(CssBorder b) {
    if (b.style == null && b.widthPx == null && b.color == null) return null;
    final style = b.style ?? 'solid';
    if (style == 'none' || style == 'hidden') return BorderSpec.none;
    final w = b.widthPx ?? 1.0;
    if (w <= 0) return BorderSpec.none;
    final color = b.color ?? 'auto';
    final colorOut = color == '#000000' ? 'auto' : color;
    switch (style) {
      case 'dashed':
        return BorderSpec(BorderStyle.dashed, colorOut);
      case 'dotted':
        return BorderSpec(BorderStyle.dotted, colorOut);
      case 'double':
        return BorderSpec(BorderStyle.double, colorOut);
    }
    final BorderStyle s;
    if (b.widthInPt) {
      final pt = w * 0.75;
      s = pt < 0.75
          ? BorderStyle.thin
          : pt < 1.25
          ? BorderStyle.medium
          : BorderStyle.thick;
    } else {
      s = w < 1.5
          ? BorderStyle.thin
          : w < 2.5
          ? BorderStyle.medium
          : BorderStyle.thick;
    }
    return BorderSpec(s, colorOut);
  }

  static const Map<String, String> _named = {
    'aliceblue': 'F0F8FF', 'antiquewhite': 'FAEBD7', 'aqua': '00FFFF', 'aquamarine': '7FFFD4',
    'azure': 'F0FFFF', 'beige': 'F5F5DC', 'bisque': 'FFE4C4', 'blanchedalmond': 'FFEBCD',
    'blue': '0000FF', 'blueviolet': '8A2BE2', 'brown': 'A52A2A', 'burlywood': 'DEB887',
    'cadetblue': '5F9EA0', 'chartreuse': '7FFF00', 'chocolate': 'D2691E', 'coral': 'FF7F50',
    'cornflowerblue': '6495ED', 'cornsilk': 'FFF8DC', 'crimson': 'DC143C', 'cyan': '00FFFF',
    'darkblue': '00008B', 'darkcyan': '008B8B', 'darkgoldenrod': 'B8860B', 'darkgray': 'A9A9A9',
    'darkgreen': '006400', 'darkgrey': 'A9A9A9', 'darkkhaki': 'BDB76B', 'darkmagenta': '8B008B',
    'darkolivegreen': '556B2F', 'darkorange': 'FF8C00', 'darkorchid': '9932CC', 'darkred': '8B0000',
    'darksalmon': 'E9967A', 'darkseagreen': '8FBC8F', 'darkslateblue': '483D8B',
    'darkslategray': '2F4F4F', 'darkslategrey': '2F4F4F', 'darkturquoise': '00CED1',
    'darkviolet': '9400D3', 'deeppink': 'FF1493', 'deepskyblue': '00BFFF', 'dimgray': '696969',
    'dimgrey': '696969', 'dodgerblue': '1E90FF', 'firebrick': 'B22222', 'floralwhite': 'FFFAF0',
    'forestgreen': '228B22', 'fuchsia': 'FF00FF', 'gainsboro': 'DCDCDC', 'ghostwhite': 'F8F8FF',
    'gold': 'FFD700', 'goldenrod': 'DAA520', 'gray': '808080', 'green': '008000',
    'greenyellow': 'ADFF2F', 'grey': '808080', 'honeydew': 'F0FFF0', 'hotpink': 'FF69B4',
    'indianred': 'CD5C5C', 'indigo': '4B0082', 'ivory': 'FFFFF0', 'khaki': 'F0E68C',
    'lavender': 'E6E6FA', 'lavenderblush': 'FFF0F5', 'lawngreen': '7CFC00', 'lemonchiffon': 'FFFACD',
    'lightblue': 'ADD8E6', 'lightcoral': 'F08080', 'lightcyan': 'E0FFFF',
    'lightgoldenrodyellow': 'FAFAD2', 'lightgray': 'D3D3D3', 'lightgreen': '90EE90',
    'lightgrey': 'D3D3D3', 'lightpink': 'FFB6C1', 'lightsalmon': 'FFA07A',
    'lightseagreen': '20B2AA', 'lightskyblue': '87CEFA', 'lightslategray': '778899',
    'lightslategrey': '778899', 'lightsteelblue': 'B0C4DE', 'lightyellow': 'FFFFE0',
    'lime': '00FF00', 'limegreen': '32CD32', 'linen': 'FAF0E6', 'magenta': 'FF00FF',
    'maroon': '800000', 'mediumaquamarine': '66CDAA', 'mediumblue': '0000CD',
    'mediumorchid': 'BA55D3', 'mediumpurple': '9370DB', 'mediumseagreen': '3CB371',
    'mediumslateblue': '7B68EE', 'mediumspringgreen': '00FA9A', 'mediumturquoise': '48D1CC',
    'mediumvioletred': 'C71585', 'midnightblue': '191970', 'mintcream': 'F5FFFA',
    'mistyrose': 'FFE4E1', 'moccasin': 'FFE4B5', 'navajowhite': 'FFDEAD', 'navy': '000080',
    'oldlace': 'FDF5E6', 'olive': '808000', 'olivedrab': '6B8E23', 'orange': 'FFA500',
    'orangered': 'FF4500', 'orchid': 'DA70D6', 'palegoldenrod': 'EEE8AA', 'palegreen': '98FB98',
    'paleturquoise': 'AFEEEE', 'palevioletred': 'DB7093', 'papayawhip': 'FFEFD5',
    'peachpuff': 'FFDAB9', 'peru': 'CD853F', 'pink': 'FFC0CB', 'plum': 'DDA0DD',
    'powderblue': 'B0E0E6', 'purple': '800080', 'rebeccapurple': '663399', 'red': 'FF0000',
    'rosybrown': 'BC8F8F', 'royalblue': '4169E1', 'saddlebrown': '8B4513', 'salmon': 'FA8072',
    'sandybrown': 'F4A460', 'seagreen': '2E8B57', 'seashell': 'FFF5EE', 'sienna': 'A0522D',
    'silver': 'C0C0C0', 'skyblue': '87CEEB', 'slateblue': '6A5ACD', 'slategray': '708090',
    'slategrey': '708090', 'snow': 'FFFAFA', 'springgreen': '00FF7F', 'steelblue': '4682B4',
    'tan': 'D2B48C', 'teal': '008080', 'thistle': 'D8BFD8', 'tomato': 'FF6347',
    'turquoise': '40E0D0', 'violet': 'EE82EE', 'wheat': 'F5DEB3', 'white': 'FFFFFF',
    'whitesmoke': 'F5F5F5', 'yellow': 'FFFF00', 'yellowgreen': '9ACD32',
  };
}

/// A parsed `<style>` sheet supporting simple selectors (`td`, `.xl65`,
/// `td.xl65`, comma lists) as used by Excel and LibreOffice clipboard HTML.
final class CssStyleSheet {
  CssStyleSheet._(this._rules);

  /// An empty sheet.
  static final CssStyleSheet empty = CssStyleSheet._(const []);

  final List<_CssRule> _rules;

  /// Whether the sheet has no rules.
  bool get isEmpty => _rules.isEmpty;

  /// Parses CSS text (comments, `<!-- -->` wrappers and at-rules skipped).
  static CssStyleSheet parse(String css) {
    final text = css
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll('<!--', '')
        .replaceAll('-->', '');
    final rules = <_CssRule>[];
    var i = 0;
    var order = 0;
    while (i < text.length) {
      final open = text.indexOf('{', i);
      if (open < 0) break;
      final selector = text.substring(i, open).trim();
      // Find the matching close brace (nested blocks of at-rules).
      var depth = 1;
      var j = open + 1;
      while (j < text.length && depth > 0) {
        final c = text.codeUnitAt(j);
        if (c == 0x7b) depth++;
        if (c == 0x7d) depth--;
        j++;
      }
      final body = text.substring(open + 1, math.max(open + 1, j - 1));
      i = j;
      if (selector.startsWith('@')) continue;
      final decls = Css.parseDeclarations(body);
      for (final sel in selector.split(',')) {
        final s = sel.trim().toLowerCase();
        final m = RegExp(r'^([a-z][a-z0-9]*)?((?:\.[a-z0-9_-]+)*)$').firstMatch(s);
        if (m == null) continue;
        final tag = m.group(1);
        final classes = m.group(2)!.split('.').where((c) => c.isNotEmpty).toList();
        if (tag == null && classes.isEmpty) continue;
        rules.add(_CssRule(tag, classes, decls, order++));
      }
    }
    return CssStyleSheet._(rules);
  }

  /// Merged declarations matching an element (tag rules < class rules <
  /// tag.class rules, then source order). With [includeTagOnly] false,
  /// rules with only a tag selector are skipped.
  Map<String, String> declarationsFor(
    String tag,
    List<String> classes, {
    bool includeTagOnly = true,
  }) {
    if (_rules.isEmpty) return const {};
    final lower = classes.map((c) => c.toLowerCase()).toSet();
    final matched = <_CssRule>[
      for (final r in _rules)
        if ((r.tag == null || r.tag == tag) &&
            r.classes.every(lower.contains) &&
            (includeTagOnly || r.classes.isNotEmpty))
          r,
    ]..sort((a, b) {
      final s = a.specificity.compareTo(b.specificity);
      return s != 0 ? s : a.order.compareTo(b.order);
    });
    final out = <String, String>{};
    for (final r in matched) {
      out.addAll(r.declarations);
    }
    return out;
  }
}

final class _CssRule {
  _CssRule(this.tag, this.classes, this.declarations, this.order);

  final String? tag;
  final List<String> classes;
  final Map<String, String> declarations;
  final int order;

  int get specificity => classes.length * 10 + (tag == null ? 0 : 1);
}
