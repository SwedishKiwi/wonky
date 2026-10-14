import 'dart:convert';

import 'package:xml/xml.dart';

import '../../content/rich_text.dart';
import '../../format/attributes.dart';
import '../../format/borders.dart';
import '../../format/number_format/presets.dart';
import '../../format/theme.dart';
import '../../model/schema.dart';
import '../ir/workbook_document.dart';
import '../xlsx/ooxml.dart' show XmlElementX;
import 'ods_number_styles.dart';

/// ODF namespaces used by the ODS reader and writer (11 §5.5, §6.4).
abstract final class OdsNs {
  static const office = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  static const style = 'urn:oasis:names:tc:opendocument:xmlns:style:1.0';
  static const text = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  static const table = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
  static const draw = 'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0';
  static const fo =
      'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0';
  static const xlink = 'http://www.w3.org/1999/xlink';
  static const dc = 'http://purl.org/dc/elements/1.1/';
  static const meta = 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0';
  static const number = 'urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0';
  static const svg = 'urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0';
  static const of = 'urn:oasis:names:tc:opendocument:xmlns:of:1.2';
  static const config = 'urn:oasis:names:tc:opendocument:xmlns:config:1.0';
  static const manifest = 'urn:oasis:names:tc:opendocument:xmlns:manifest:1.0';
  static const calcext =
      'urn:org:documentfoundation:names:experimental:calc:xmlns:calcext:1.0';
  static const tableooo = 'http://openoffice.org/2009/table';

  /// Namespace of Wonky's own attributes (round-trip fidelity; other
  /// readers ignore them).
  static const wonky = kWonkyOdfNamespace;

  /// The ODS media type (`mimetype` entry).
  static const mimeType = 'application/vnd.oasis.opendocument.spreadsheet';

  /// `xmlns:*` declarations for the root of a document part.
  static const String declarations =
      'xmlns:office="$office" xmlns:style="$style" xmlns:text="$text" '
      'xmlns:table="$table" xmlns:draw="$draw" xmlns:fo="$fo" '
      'xmlns:xlink="$xlink" xmlns:dc="$dc" xmlns:meta="$meta" '
      'xmlns:number="$number" xmlns:svg="$svg" xmlns:of="$of" '
      'xmlns:calcext="$calcext" xmlns:tableooo="$tableooo" '
      'xmlns:wonky="$wonky"';
}

/// XML escaping for ODF parts (no OOXML `_xHHHH_` escapes: characters not
/// allowed in XML 1.0 are dropped).
abstract final class OdsXml {
  static String _clean(String s) {
    var ok = true;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if ((c < 0x20 && c != 0x09 && c != 0x0a && c != 0x0d) ||
          c == 0xfffe ||
          c == 0xffff ||
          (c >= 0xd800 && c <= 0xdfff)) {
        ok = false;
        break;
      }
    }
    if (ok) return s;
    final b = StringBuffer();
    for (final r in s.runes) {
      if ((r < 0x20 && r != 0x09 && r != 0x0a && r != 0x0d) ||
          r == 0xfffe ||
          r == 0xffff ||
          (r >= 0xd800 && r <= 0xdfff)) {
        continue;
      }
      b.writeCharCode(r);
    }
    return b.toString();
  }

  /// Escapes text content.
  static String esc(String s) {
    final t = _clean(s);
    if (!t.contains(RegExp(r'[&<>]'))) return t;
    return t
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Escapes an attribute value (double quotes).
  static String attr(String s) => _clean(s)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll('\n', '&#10;')
      .replaceAll('\r', '&#13;')
      .replaceAll('\t', '&#9;');
}

/// ODF lengths (`0.889in`, `2.258cm`, `12pt`) ⇄ points and grid px.
abstract final class OdsUnits {
  static final RegExp _length = RegExp(
    r'^\s*(-?\d*\.?\d+(?:[eE][-+]?\d+)?)\s*(in|cm|mm|pt|pc|px)?\s*$',
  );

  /// Points of an ODF length; null when malformed.
  static double? toPt(String? length) {
    if (length == null) return null;
    final m = _length.firstMatch(length);
    if (m == null) return null;
    final v = double.tryParse(m.group(1)!);
    if (v == null || !v.isFinite) return null;
    return switch (m.group(2)) {
      'in' => v * 72,
      'cm' => v * 72 / 2.54,
      'mm' => v * 72 / 25.4,
      'pc' => v * 12,
      'px' => v * 0.75,
      _ => v,
    };
  }

  /// Grid px (96 dpi) of an ODF length, rounded to 0.01 px.
  static double? toPx(String? length) {
    final pt = toPt(length);
    if (pt == null) return null;
    return (pt * 4 / 3 * 100).roundToDouble() / 100;
  }

  /// `12.5pt` (at most 4 decimals).
  static String pt(double pt) {
    var s = pt.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    if (s == '-0') s = '0';
    return '${s}pt';
  }

  /// px as a point length.
  static String pxAsPt(double px) => pt(px * 0.75);
}

/// ODF border values (`0.74pt solid #000000`) ⇄ Wonky edge values
/// (`thin|#000000`, 06 §8).
abstract final class OdsBorders {
  /// Wonky value of an ODF border; null for `none`/`hidden`/malformed.
  static String? toWonky(String? odf) {
    if (odf == null) return null;
    final parts = odf.trim().toLowerCase().split(RegExp(r'\s+'));
    double? width;
    String? style;
    String? color;
    for (final p in parts) {
      if (p.startsWith('#')) {
        color = _hex(p);
      } else if (OdsUnits.toPt(p) case final double w) {
        width = w;
      } else if (const {'thin', 'medium', 'thick'}.contains(p)) {
        width = switch (p) {
          'thin' => 0.75,
          'medium' => 1.75,
          _ => 2.5,
        };
      } else {
        style = p;
      }
    }
    final w = width ?? 0.75;
    final st = switch (style ?? 'solid') {
      'none' || 'hidden' => null,
      'double' || 'double-thin' => BorderStyle.double,
      'dotted' => BorderStyle.dotted,
      'dashed' ||
      'fine-dashed' ||
      'dash-dot' ||
      'dash-dot-dot' ||
      'dot-dash' ||
      'dot-dot-dash' => BorderStyle.dashed,
      _ =>
        w < 1.0
            ? BorderStyle.thin
            : w < 2.0
            ? BorderStyle.medium
            : BorderStyle.thick,
    };
    if (st == null || w <= 0) return null;
    return '${st.name}|${color ?? 'auto'}';
  }

  /// ODF value of a Wonky edge; null for none/malformed. `auto` and theme
  /// colors resolve with [theme] (black when unresolved).
  static String? toOdf(String? wonky, SpreadsheetTheme theme) {
    final spec = BorderSpec.tryParse(wonky);
    if (spec == null || spec.isNone) return null;
    final color = (theme.resolveColor(spec.color) ?? '#000000').toLowerCase();
    final (width, style) = switch (spec.style!) {
      BorderStyle.thin => ('0.75pt', 'solid'),
      BorderStyle.medium => ('1.75pt', 'solid'),
      BorderStyle.thick => ('2.5pt', 'solid'),
      BorderStyle.dashed => ('0.75pt', 'dashed'),
      BorderStyle.dotted => ('0.75pt', 'dotted'),
      BorderStyle.double => ('2.5pt', 'double'),
    };
    return '$width $style $color';
  }

  static String? _hex(String s) {
    final t = s.trim();
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(t)) return t.toUpperCase();
    if (RegExp(r'^#[0-9a-fA-F]{3}$').hasMatch(t)) {
      return '#${t[1]}${t[1]}${t[2]}${t[2]}${t[3]}${t[3]}'.toUpperCase();
    }
    return null;
  }

  /// `#RRGGBB` of an ODF color (`#rrggbb`, `#rgb`); null otherwise.
  static String? color(String? s) => s == null ? null : _hex(s);
}

/// Cell properties of an ODF style chain (parents applied).
final class _CellProps {
  String? fontFamily;
  double? fontSize;
  bool? bold;
  bool? italic;
  bool? underline;
  bool? strike;
  String? color;
  String? background;
  final List<String?> borders = List.filled(4, null);
  String? wrapOption;
  String? vAlign;
  String? rotationAngle;
  String? direction;
  String? textAlign;
  String? textAlignSource;
  String? dataStyleName;
  String? wonkyFormat;

  _CellProps copy() {
    final c = _CellProps()
      ..fontFamily = fontFamily
      ..fontSize = fontSize
      ..bold = bold
      ..italic = italic
      ..underline = underline
      ..strike = strike
      ..color = color
      ..background = background
      ..wrapOption = wrapOption
      ..vAlign = vAlign
      ..rotationAngle = rotationAngle
      ..direction = direction
      ..textAlign = textAlign
      ..textAlignSource = textAlignSource
      ..dataStyleName = dataStyleName;
    for (var i = 0; i < 4; i++) {
      c.borders[i] = borders[i];
    }
    return c;
  }
}

/// Text properties shared by cell and span styles.
typedef _TextProps = ({
  String? family,
  double? size,
  bool? bold,
  bool? italic,
  bool? underline,
  bool? strike,
  String? color,
});

/// Row, column or table properties read from automatic styles.
final class OdsDimStyle {
  /// Creates properties.
  const OdsDimStyle({
    this.sizePx,
    this.optimal = false,
    this.breakBefore = false,
  });

  /// Column width / row height in px.
  final double? sizePx;

  /// Row height is automatic (`use-optimal-row-height`).
  final bool optimal;

  /// `fo:break-before="page"`.
  final bool breakBefore;
}

/// Sheet properties of a table style.
final class OdsTableStyle {
  /// Creates properties.
  const OdsTableStyle({
    this.hidden = false,
    this.rtl = false,
    this.tabColor,
    this.defaultRowHeight,
    this.defaultColumnWidth,
    this.wonkyDefaults = false,
  });

  /// Whether the default sizes come from Wonky's own attributes (null
  /// values then mean "Wonky defaults", not "infer from the columns").
  final bool wonkyDefaults;

  final bool hidden;
  final bool rtl;
  final String? tabColor;
  final double? defaultRowHeight;
  final double? defaultColumnWidth;
}

/// Reads the styles of an ODS package (`styles.xml` and the automatic styles
/// of `content.xml`) into Wonky formats.
final class OdsStyleReader {
  /// Creates a reader; [warn] receives `(code, message)` warnings.
  OdsStyleReader({required this.formats, this.warn});

  /// The document's format table (cell formats are interned here).
  final IrFormatTable formats;
  final void Function(String code, String message)? warn;

  final Map<String, String> _fontFaces = {};
  final Map<String, XmlElement> _namedCell = {};
  final Map<String, XmlElement> _autoCell = {};
  final Map<String, XmlElement> _autoText = {};
  final Map<String, XmlElement> _autoColumn = {};
  final Map<String, XmlElement> _autoRow = {};
  final Map<String, XmlElement> _autoTable = {};
  final Map<String, XmlElement> _dataStyles = {};
  XmlElement? _defaultCell;

  final Map<String, int> _cellFormatCache = {};
  final Map<String, Map<String, Object?>> _textCache = {};
  final Map<String, String?> _patternCache = {};
  final Map<String, _CellProps> _propsCache = {};
  _CellProps? _defaults;

  /// Registers `style:font-face` declarations.
  void addFontFaces(XmlElement decls) {
    for (final f in decls.elems('font-face')) {
      final name = f.attr('name');
      if (name == null) continue;
      _fontFaces[name] = _unquoteFamily(f.attr('font-family') ?? name);
    }
  }

  /// Registers the styles of `office:styles` / `office:automatic-styles`.
  /// [automatic] marks the automatic styles of `content.xml`.
  void addStyles(XmlElement container, {required bool automatic}) {
    for (final s in container.childElements) {
      final name = s.attr('name');
      switch (s.localName) {
        case 'default-style':
          if (s.attr('family') == 'table-cell') _defaultCell = s;
        case 'style':
          if (name == null) continue;
          switch (s.attr('family')) {
            case 'table-cell':
              (automatic ? _autoCell : _namedCell)[name] = s;
            case 'text':
              _autoText[name] = s;
            case 'table-column':
              _autoColumn[name] = s;
            case 'table-row':
              _autoRow[name] = s;
            case 'table':
              _autoTable[name] = s;
          }
        case 'number-style' ||
            'currency-style' ||
            'percentage-style' ||
            'date-style' ||
            'time-style' ||
            'boolean-style' ||
            'text-style':
          if (name != null) _dataStyles[name] = s;
      }
    }
    _defaults = null;
    _propsCache.clear();
    _cellFormatCache.clear();
  }

  static String _unquoteFamily(String f) {
    var s = f.trim();
    final comma = s.indexOf(',');
    if (comma > 0 && !s.startsWith("'") && !s.startsWith('"')) {
      s = s.substring(0, comma).trim();
    }
    if (s.length >= 2 &&
        ((s.startsWith("'") && s.endsWith("'")) ||
            (s.startsWith('"') && s.endsWith('"')))) {
      s = s.substring(1, s.length - 1);
    }
    return s;
  }

  // ---------------------------------------------------------------------------
  // Cell styles.

  _CellProps get _defaultProps =>
      _defaults ??= _resolve('Default', named: true, depth: 0);

  /// Document default font family (`Default` cell style).
  String? get defaultFontFamily => _defaultProps.fontFamily;

  /// Document default font size in pt.
  double? get defaultFontSize => _defaultProps.fontSize;

  _CellProps _resolve(String name, {required bool named, required int depth}) {
    final key = '${named ? 'n' : 'a'}:$name';
    final cached = _propsCache[key];
    if (cached != null) return cached;
    final el = named ? _namedCell[name] : (_autoCell[name] ?? _namedCell[name]);
    _CellProps base;
    if (el == null || depth > 12) {
      base = _CellProps();
      final d = _defaultCell;
      if (d != null) _apply(base, d);
    } else {
      final parent = el.attr('parent-style-name');
      if (parent != null && parent != name) {
        base = _resolve(parent, named: true, depth: depth + 1).copy();
      } else {
        base = _CellProps();
        final d = _defaultCell;
        if (d != null) _apply(base, d);
      }
      _apply(base, el);
      base.wonkyFormat = el.attr('format') != null && _isWonky(el, 'format')
          ? el.attr('format')
          : null;
    }
    _propsCache[key] = base;
    return base;
  }

  static bool _isWonky(XmlElement el, String local) {
    for (final a in el.attributes) {
      if (a.localName == local) {
        return a.namespaceUri == OdsNs.wonky || a.name.prefix == 'wonky';
      }
    }
    return false;
  }

  void _apply(_CellProps p, XmlElement style) {
    final ds = style.attr('data-style-name');
    if (ds != null) p.dataStyleName = ds;
    final cell = style.child('table-cell-properties');
    if (cell != null) {
      final bg = cell.attr('background-color');
      if (bg != null) p.background = bg;
      final all = cell.attr('border');
      if (all != null) {
        for (var i = 0; i < 4; i++) {
          p.borders[i] = all;
        }
      }
      const sides = ['border-top', 'border-right', 'border-bottom'];
      for (var i = 0; i < 3; i++) {
        final v = cell.attr(sides[i]);
        if (v != null) p.borders[i] = v;
      }
      final left = cell.attr('border-left');
      if (left != null) p.borders[3] = left;
      final wrap = cell.attr('wrap-option');
      if (wrap != null) p.wrapOption = wrap;
      final va = cell.attr('vertical-align');
      if (va != null) p.vAlign = va;
      final rot = cell.attr('rotation-angle');
      if (rot != null) p.rotationAngle = rot;
      final dir = cell.attr('direction');
      if (dir != null) p.direction = dir;
      final src = cell.attr('text-align-source');
      if (src != null) p.textAlignSource = src;
    }
    final para = style.child('paragraph-properties');
    final ta = para?.attr('text-align');
    if (ta != null) p.textAlign = ta;
    final tp = style.child('text-properties');
    if (tp != null) {
      final t = _textProps(tp);
      if (t.family != null) p.fontFamily = t.family;
      if (t.size != null) p.fontSize = t.size;
      if (t.bold != null) p.bold = t.bold;
      if (t.italic != null) p.italic = t.italic;
      if (t.underline != null) p.underline = t.underline;
      if (t.strike != null) p.strike = t.strike;
      if (t.color != null) p.color = t.color;
    }
  }

  _TextProps _textProps(XmlElement tp) {
    final fontName = tp.attr('font-name');
    final family = fontName != null
        ? (_fontFaces[fontName] ?? fontName)
        : (tp.attr('font-family') == null
              ? null
              : _unquoteFamily(tp.attr('font-family')!));
    final sizeAttr = tp.attr('font-size');
    final size = sizeAttr == null || sizeAttr.endsWith('%')
        ? null
        : OdsUnits.toPt(sizeAttr);
    final weight = tp.attr('font-weight');
    final bold = weight == null
        ? null
        : (weight == 'bold' || (int.tryParse(weight) ?? 400) >= 600);
    final style = tp.attr('font-style');
    final italic = style == null
        ? null
        : (style == 'italic' || style == 'oblique');
    final ul = tp.attr('text-underline-style');
    final underline = ul == null ? null : ul != 'none';
    final lt = tp.attr('text-line-through-style');
    final strike = lt == null ? null : lt != 'none';
    final color = tp.attr('color');
    return (
      family: family,
      size: size == null ? null : (size * 100).roundToDouble() / 100,
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
      color: color == null ? null : OdsBorders.color(color),
    );
  }

  /// The format index (into [formats]) of cell style [name] (null = the
  /// `Default` style → 0).
  int cellFormat(String? name) {
    if (name == null || name.isEmpty) return 0;
    final cached = _cellFormatCache[name];
    if (cached != null) return cached;
    final f = _cellFormatOf(name);
    final i = formats.intern(f);
    _cellFormatCache[name] = i;
    return i;
  }

  IrFormat _cellFormatOf(String name) {
    final p = _resolve(name, named: false, depth: 0);
    final w = p.wonkyFormat;
    if (w != null) {
      final f = _decodeWonkyFormat(w);
      if (f != null) return f;
    }
    final d = _defaultProps;
    final attrs = <FormatAttr, Object?>{};
    final extras = <String, Object?>{};
    if (p.fontFamily != null && p.fontFamily != d.fontFamily) {
      attrs[FormatAttr.fontFamily] = p.fontFamily;
    }
    if (p.fontSize != null && p.fontSize != d.fontSize) {
      attrs[FormatAttr.fontSize] = p.fontSize;
    }
    if (p.bold == true && d.bold != true) attrs[FormatAttr.bold] = true;
    if (p.italic == true && d.italic != true) attrs[FormatAttr.italic] = true;
    if (p.underline == true && d.underline != true) {
      attrs[FormatAttr.underline] = true;
    }
    if (p.strike == true && d.strike != true) {
      attrs[FormatAttr.strikethrough] = true;
    }
    if (p.color != null && p.color != (d.color ?? '#000000')) {
      attrs[FormatAttr.textColor] = p.color;
    }
    final bg = OdsBorders.color(p.background);
    if (bg != null && bg != OdsBorders.color(d.background)) {
      attrs[FormatAttr.fillColor] = bg;
    }
    const sides = [
      FormatAttr.borderTop,
      FormatAttr.borderRight,
      FormatAttr.borderBottom,
      FormatAttr.borderLeft,
    ];
    for (var i = 0; i < 4; i++) {
      final b = OdsBorders.toWonky(p.borders[i]);
      if (b != null) attrs[sides[i]] = b;
    }
    if (p.wrapOption == 'wrap') attrs[FormatAttr.wrap] = WrapStrategy.wrap;
    switch (p.vAlign) {
      case 'top':
        attrs[FormatAttr.vAlign] = VerticalAlign.top;
      case 'middle':
        attrs[FormatAttr.vAlign] = VerticalAlign.middle;
    }
    if (p.textAlignSource != 'value-type') {
      switch (p.textAlign) {
        case 'start' || 'left':
          attrs[FormatAttr.hAlign] = HorizontalAlign.left;
        case 'center':
          attrs[FormatAttr.hAlign] = HorizontalAlign.center;
        case 'end' || 'right':
          attrs[FormatAttr.hAlign] = HorizontalAlign.right;
        case 'justify':
          attrs[FormatAttr.hAlign] = HorizontalAlign.left;
          warn?.call('alignment', 'Alignment "justify" approximated');
      }
    }
    if (p.direction == 'ttb') {
      attrs[FormatAttr.rotation] = 255;
    } else if (p.rotationAngle != null) {
      final r = _rotation(p.rotationAngle!);
      if (r != null && r != 0) attrs[FormatAttr.rotation] = r;
    }
    final nf = numberPattern(p.dataStyleName);
    if (nf != null) attrs[FormatAttr.numberFormat] = nf;
    return IrFormat(CellFormat(attrs), extras);
  }

  int? _rotation(String angle) {
    final t = angle.trim();
    double? deg;
    if (t.endsWith('rad')) {
      final v = double.tryParse(t.substring(0, t.length - 3));
      if (v != null) deg = v * 180 / 3.141592653589793;
    } else if (t.endsWith('grad')) {
      final v = double.tryParse(t.substring(0, t.length - 4));
      if (v != null) deg = v * 0.9;
    } else {
      deg = double.tryParse(
        t.endsWith('deg') ? t.substring(0, t.length - 3) : t,
      );
    }
    if (deg == null || !deg.isFinite) return null;
    var a = deg.round() % 360;
    if (a < 0) a += 360;
    if (a <= 90) return a;
    if (a >= 270) return a - 360;
    warn?.call('rotation', 'Text rotation of $a° approximated');
    return a <= 180 ? 90 : -90;
  }

  static IrFormat? _decodeWonkyFormat(String json) {
    try {
      final m = jsonDecode(json);
      if (m is! Map) return null;
      final a = m['a'];
      final x = m['x'];
      return IrFormat(
        a is Map
            ? CellFormat.fromMap(a.cast<String, Object?>())
            : CellFormat.empty,
        x is Map ? x.cast<String, Object?>() : const {},
      );
    } on FormatException {
      return null;
    }
  }

  /// The Wonky pattern of data style [name] (null = Automatic).
  String? numberPattern(String? name) {
    if (name == null) return null;
    return _patternCache.putIfAbsent(name, () {
      final el = _dataStyles[name];
      if (el == null) return null;
      final p = OdsNumberStyles.toPattern(el, (n) => _dataStyles[n]);
      if (p == null || NumberFormatPresets.isAutomatic(p)) return null;
      return p;
    });
  }

  // ---------------------------------------------------------------------------
  // Text (span) styles.

  /// Rich run format (06 §11 keys) of text style [name].
  Map<String, Object?> textFormat(String? name) {
    if (name == null) return const {};
    return _textCache.putIfAbsent(name, () {
      final el = _autoText[name];
      if (el == null) return const {};
      final w = el.attr('format');
      if (w != null && _isWonky(el, 'format')) {
        try {
          final m = jsonDecode(w);
          if (m is Map) return Map.unmodifiable(m.cast<String, Object?>());
        } on FormatException {
          // Fall back to the ODF properties.
        }
      }
      final tp = el.child('text-properties');
      if (tp == null) return const {};
      final t = _textProps(tp);
      return Map.unmodifiable({
        if (t.family != null) RichRunKeys.fontFamily: t.family,
        if (t.size != null) RichRunKeys.fontSize: t.size,
        if (t.bold != null) RichRunKeys.bold: t.bold,
        if (t.italic != null) RichRunKeys.italic: t.italic,
        if (t.underline != null) RichRunKeys.underline: t.underline,
        if (t.strike != null) RichRunKeys.strikethrough: t.strike,
        if (t.color != null) RichRunKeys.textColor: t.color,
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Columns, rows, tables.

  /// Column style [name].
  OdsDimStyle column(String? name) {
    final p = name == null
        ? null
        : _autoColumn[name]?.child('table-column-properties');
    if (p == null) return const OdsDimStyle();
    return OdsDimStyle(
      sizePx: OdsUnits.toPx(p.attr('column-width')),
      breakBefore: p.attr('break-before') == 'page',
    );
  }

  /// Row style [name].
  OdsDimStyle row(String? name) {
    final p = name == null
        ? null
        : _autoRow[name]?.child('table-row-properties');
    if (p == null) return const OdsDimStyle(optimal: true);
    final h = OdsUnits.toPx(p.attr('row-height') ?? p.attr('min-row-height'));
    return OdsDimStyle(
      sizePx: h,
      optimal: p.boolAttr('use-optimal-row-height') ?? h == null,
      breakBefore: p.attr('break-before') == 'page',
    );
  }

  /// Table style [name].
  OdsTableStyle table(String? name) {
    final p = name == null ? null : _autoTable[name]?.child('table-properties');
    if (p == null) return const OdsTableStyle();
    return OdsTableStyle(
      hidden: p.attr('display') == 'false',
      rtl: (p.attr('writing-mode') ?? '').startsWith('rl'),
      tabColor: OdsBorders.color(p.attr('tab-color')),
      defaultRowHeight: double.tryParse(p.attr('default-row-height') ?? ''),
      defaultColumnWidth: double.tryParse(p.attr('default-column-width') ?? ''),
      wonkyDefaults:
          p.attr('default-row-height') != null ||
          p.attr('default-column-width') != null,
    );
  }
}

/// Writes deduplicated automatic styles for an ODS export.
final class OdsStyleWriter {
  /// Creates a writer.
  OdsStyleWriter({
    required this.theme,
    required this.defaultFont,
    required this.defaultSize,
    required this.locale,
    this.wonkyExtensions = true,
  });

  final SpreadsheetTheme theme;
  final String defaultFont;
  final double defaultSize;
  final String locale;

  /// Whether `wonky:*` attributes are written for lossless re-import.
  final bool wonkyExtensions;

  final Map<IrFormat, String> _cell = {};
  final Map<String, String> _data = {};
  final Map<String, String> _text = {};
  final Map<String, String> _column = {};
  final Map<String, String> _row = {};
  final Map<String, String> _table = {};
  final StringBuffer _dataXml = StringBuffer();
  final StringBuffer _stylesXml = StringBuffer();

  /// Font families referenced by styles (font-face declarations).
  final Set<String> fontFamilies = {};

  /// Cell style name for [f]; null for the empty format.
  String? cellStyle(IrFormat f) {
    if (f.isEmpty) return null;
    final existing = _cell[f];
    if (existing != null) return existing;
    final name = 'ce${_cell.length + 1}';
    _cell[f] = name;
    final a = f.attrs;
    final dataName = _dataStyle(a[FormatAttr.numberFormat] as String?);
    final b = StringBuffer(
      '<style:style style:name="$name" style:family="table-cell" '
      'style:parent-style-name="Default"',
    );
    if (dataName != null) b.write(' style:data-style-name="$dataName"');
    if (wonkyExtensions) {
      final json = jsonEncode({
        'a': a.toMap(),
        if (f.extras.isNotEmpty) 'x': f.extras,
      });
      b.write(' wonky:format="${OdsXml.attr(json)}"');
    }
    b.write('>');
    final cell = StringBuffer();
    final fill = theme.resolveColor(a[FormatAttr.fillColor] as String?);
    if (fill != null) {
      cell.write(' fo:background-color="${fill.toLowerCase()}"');
    }
    const sides = [
      ('top', FormatAttr.borderTop),
      ('right', FormatAttr.borderRight),
      ('bottom', FormatAttr.borderBottom),
      ('left', FormatAttr.borderLeft),
    ];
    for (final (side, attr) in sides) {
      final v = OdsBorders.toOdf(a[attr] as String?, theme);
      if (v == null) continue;
      cell.write(' fo:border-$side="$v"');
      if (v.contains('double')) {
        cell.write(' style:border-line-width-$side="0.03cm 0.03cm 0.03cm"');
      }
    }
    if (a[FormatAttr.wrap] == WrapStrategy.wrap) {
      cell.write(' fo:wrap-option="wrap"');
    }
    switch (a[FormatAttr.vAlign]) {
      case VerticalAlign.top:
        cell.write(' style:vertical-align="top"');
      case VerticalAlign.middle:
        cell.write(' style:vertical-align="middle"');
      case VerticalAlign.bottom:
        cell.write(' style:vertical-align="bottom"');
    }
    final rot = a[FormatAttr.rotation] as int?;
    if (rot == 255) {
      cell.write(' style:direction="ttb"');
    } else if (rot != null && rot != 0) {
      cell.write(
        ' style:rotation-angle="${rot < 0 ? 360 + rot : rot}" '
        'style:rotation-align="none"',
      );
    }
    final hAlign = a[FormatAttr.hAlign] as HorizontalAlign?;
    if (hAlign != null) cell.write(' style:text-align-source="fix"');
    if (cell.isNotEmpty) b.write('<style:table-cell-properties$cell/>');
    if (hAlign != null) {
      final v = switch (hAlign) {
        HorizontalAlign.left => 'start',
        HorizontalAlign.center => 'center',
        HorizontalAlign.right => 'end',
      };
      b.write('<style:paragraph-properties fo:text-align="$v"/>');
    }
    final text = _textXml(
      family: a[FormatAttr.fontFamily] as String?,
      size: (a[FormatAttr.fontSize] as num?)?.toDouble(),
      bold: a[FormatAttr.bold] as bool?,
      italic: a[FormatAttr.italic] as bool?,
      underline: a[FormatAttr.underline] as bool?,
      strike: a[FormatAttr.strikethrough] as bool?,
      color: a[FormatAttr.textColor] as String?,
    );
    if (text.isNotEmpty) b.write('<style:text-properties$text/>');
    b.write('</style:style>');
    _stylesXml.write(b);
    return name;
  }

  String? _dataStyle(String? pattern) {
    if (pattern == null || NumberFormatPresets.isAutomatic(pattern)) {
      return null;
    }
    final existing = _data[pattern];
    if (existing != null) return existing;
    final name = 'N${_data.length + 100}';
    _data[pattern] = name;
    var xml = OdsNumberStyles.toXml(pattern, name, locale: locale);
    if (!wonkyExtensions) {
      xml = xml.replaceAll(RegExp(r' wonky:pattern="[^"]*"'), '');
    }
    _dataXml.write(xml);
    return name;
  }

  String _textXml({
    String? family,
    double? size,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    String? color,
  }) {
    final t = StringBuffer();
    if (family != null && family.isNotEmpty) {
      fontFamilies.add(family);
      t.write(' style:font-name="${OdsXml.attr(family)}"');
    }
    if (size != null) t.write(' fo:font-size="${OdsUnits.pt(size)}"');
    if (bold != null) t.write(' fo:font-weight="${bold ? 'bold' : 'normal'}"');
    if (italic != null) {
      t.write(' fo:font-style="${italic ? 'italic' : 'normal'}"');
    }
    if (underline != null) {
      t.write(
        underline
            ? ' style:text-underline-style="solid" '
                  'style:text-underline-width="auto" '
                  'style:text-underline-color="font-color"'
            : ' style:text-underline-style="none"',
      );
    }
    if (strike != null) {
      t.write(' style:text-line-through-style="${strike ? 'solid' : 'none'}"');
    }
    final c = theme.resolveColor(color);
    if (c != null) t.write(' fo:color="${c.toLowerCase()}"');
    return t.toString();
  }

  /// Text (span) style name for a rich run format.
  String? textStyle(Map<String, Object?> run) {
    final f = Map.of(run)..remove(RichRunKeys.link);
    f.removeWhere((_, v) => v == null);
    if (f.isEmpty) return null;
    final key = jsonEncode(
      Map.fromEntries(
        f.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );
    final existing = _text[key];
    if (existing != null) return existing;
    final name = 'T${_text.length + 1}';
    _text[key] = name;
    final props = _textXml(
      family: f[RichRunKeys.fontFamily] as String?,
      size: (f[RichRunKeys.fontSize] as num?)?.toDouble(),
      bold: f[RichRunKeys.bold] as bool?,
      italic: f[RichRunKeys.italic] as bool?,
      underline: f[RichRunKeys.underline] as bool?,
      strike: f[RichRunKeys.strikethrough] as bool?,
      color: f[RichRunKeys.textColor] as String?,
    );
    _stylesXml.write(
      '<style:style style:name="$name" style:family="text"'
      '${wonkyExtensions ? ' wonky:format="${OdsXml.attr(key)}"' : ''}>'
      '<style:text-properties$props/></style:style>',
    );
    return name;
  }

  /// Column style for a width in px.
  String columnStyle(double widthPx, {bool breakBefore = false}) {
    final key = '$widthPx|$breakBefore';
    return _column.putIfAbsent(key, () {
      final name = 'co${_column.length + 1}';
      _stylesXml.write(
        '<style:style style:name="$name" style:family="table-column">'
        '<style:table-column-properties fo:break-before="${breakBefore ? 'page' : 'auto'}" '
        'style:column-width="${OdsUnits.pxAsPt(widthPx)}"/></style:style>',
      );
      return name;
    });
  }

  /// Row style: [heightPx] with [optimal] (automatic) height.
  String rowStyle(
    double heightPx, {
    bool optimal = true,
    bool breakBefore = false,
  }) {
    final key = '$heightPx|$optimal|$breakBefore';
    return _row.putIfAbsent(key, () {
      final name = 'ro${_row.length + 1}';
      _stylesXml.write(
        '<style:style style:name="$name" style:family="table-row">'
        '<style:table-row-properties style:row-height="${OdsUnits.pxAsPt(heightPx)}" '
        'fo:break-before="${breakBefore ? 'page' : 'auto'}" '
        'style:use-optimal-row-height="$optimal"/></style:style>',
      );
      return name;
    });
  }

  /// Table style.
  String tableStyle({
    bool hidden = false,
    bool rtl = false,
    String? tabColor,
    double? defaultRowHeight,
    double? defaultColumnWidth,
  }) {
    final color = theme.resolveColor(tabColor)?.toLowerCase();
    final props = StringBuffer(
      ' table:display="${hidden ? 'false' : 'true'}" '
      'style:writing-mode="${rtl ? 'rl-tb' : 'lr-tb'}"',
    );
    if (color != null) props.write(' tableooo:tab-color="$color"');
    if (wonkyExtensions) {
      props
        ..write(' wonky:default-row-height="${defaultRowHeight ?? ''}"')
        ..write(' wonky:default-column-width="${defaultColumnWidth ?? ''}"');
    }
    final key = props.toString();
    return _table.putIfAbsent(key, () {
      final name = 'ta${_table.length + 1}';
      _stylesXml.write(
        '<style:style style:name="$name" style:family="table" '
        'style:master-page-name="Default"><style:table-properties$props/>'
        '</style:style>',
      );
      return name;
    });
  }

  /// `<office:automatic-styles>` of `content.xml`.
  String automaticStylesXml() =>
      '<office:automatic-styles>$_dataXml$_stylesXml</office:automatic-styles>';

  /// `<office:font-face-decls>` for [fontFamilies] plus [extra].
  String fontFaceDeclsXml([Iterable<String> extra = const []]) {
    final all = {...extra, ...fontFamilies}.toList()..sort();
    final b = StringBuffer('<office:font-face-decls>');
    for (final f in all) {
      final quoted = f.contains(RegExp(r'[\s,]')) ? "'$f'" : f;
      b.write(
        '<style:font-face style:name="${OdsXml.attr(f)}" '
        'svg:font-family="${OdsXml.attr(quoted)}"/>',
      );
    }
    b.write('</office:font-face-decls>');
    return b.toString();
  }
}
