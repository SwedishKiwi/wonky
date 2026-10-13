import 'package:xml/xml.dart';

import '../../format/attributes.dart';
import '../../model/schema.dart';
import '../color/excel_colors.dart';
import '../ir/workbook_document.dart';
import '../numfmt/excel_number_formats.dart';
import 'ooxml.dart';

/// A font of `styles.xml`.
final class XlsxFont {
  /// Creates a font.
  const XlsxFont({
    this.name,
    this.size,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color,
  });

  final String? name;
  final double? size;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? color;
}

/// A resolved cell format (`cellXfs` entry).
final class XlsxXf {
  /// Creates an xf.
  const XlsxXf(this.format, this.numberFormat, this.warnings);

  /// The IR format (attributes + extras).
  final IrFormat format;

  /// Number format pattern (null = General).
  final String? numberFormat;

  /// Approximation warnings `(code, message)` counted per cell using this xf.
  final List<(String, String)> warnings;

  /// Whether values with this format are calendar dates (epoch conversion).
  bool get isDate => ExcelNumberFormats.isDatePattern(numberFormat);
}

/// Reader of `xl/styles.xml` (11 §5.2 fonts, fills, borders, alignment,
/// number formats, dxfs).
final class XlsxStylesReader {
  /// Parses [doc] (null = no styles part) with [colors].
  XlsxStylesReader(XmlDocument? doc, this.colors) {
    final root = doc?.rootElement;
    if (root == null) {
      xfs.add(XlsxXf(IrFormat.empty, null, const []));
      return;
    }
    for (final nf
        in root.child('numFmts')?.elems('numFmt') ?? const <XmlElement>[]) {
      final id = nf.intAttr('numFmtId');
      final code = nf.attr('formatCode');
      if (id != null && code != null) customNumFmts[id] = code;
    }
    for (final f
        in root.child('fonts')?.elems('font') ?? const <XmlElement>[]) {
      fonts.add(_font(f));
    }
    for (final f
        in root.child('fills')?.elems('fill') ?? const <XmlElement>[]) {
      fills.add(_fill(f));
    }
    for (final b
        in root.child('borders')?.elems('border') ?? const <XmlElement>[]) {
      borders.add(_border(b));
    }
    defaultFont = fonts.isEmpty ? null : fonts.first;
    for (final xf
        in root.child('cellXfs')?.elems('xf') ?? const <XmlElement>[]) {
      xfs.add(_xf(xf));
    }
    if (xfs.isEmpty) xfs.add(XlsxXf(IrFormat.empty, null, const []));
    for (final d in root.child('dxfs')?.elems('dxf') ?? const <XmlElement>[]) {
      dxfs.add(_dxf(d));
    }
  }

  final ColorResolver colors;
  final Map<int, String> customNumFmts = {};
  final List<XlsxFont> fonts = [];
  final List<(String?, List<(String, String)>)> fills = [];
  final List<(Map<FormatAttr, String>, List<(String, String)>)> borders = [];
  final List<XlsxXf> xfs = [];

  /// Differential formats: Wonky CF format map + extras.
  final List<(Map<String, Object?>, Map<String, Object?>)> dxfs = [];
  XlsxFont? defaultFont;
  final List<String> numberFormatWarnings = [];

  /// The xf at [index] (out of range → default).
  XlsxXf xf(int? index) => index != null && index >= 0 && index < xfs.length
      ? xfs[index]
      : xfs.first;

  String? _color(XmlElement? c) => c == null
      ? null
      : colors.resolve(
          rgb: c.attr('rgb'),
          theme: c.attr('theme'),
          indexed: c.attr('indexed'),
          auto: c.attr('auto'),
          tint: c.attr('tint'),
        );

  XlsxFont _font(XmlElement f) {
    bool flag(String n) {
      final e = f.child(n);
      if (e == null) return false;
      final v = e.attr('val');
      return v == null || v == '1' || v == 'true';
    }

    final u = f.child('u');
    return XlsxFont(
      name: f.child('name')?.attr('val'),
      size: f.child('sz')?.doubleAttr('val'),
      bold: flag('b'),
      italic: flag('i'),
      underline: u != null && u.attr('val') != 'none',
      strike: flag('strike'),
      color: _color(f.child('color')),
    );
  }

  static const Map<String, double> _patternDensity = {
    'gray0625': 0.0625,
    'gray125': 0.125,
    'lightGray': 0.25,
    'mediumGray': 0.5,
    'darkGray': 0.75,
    'darkHorizontal': 0.5,
    'darkVertical': 0.5,
    'darkDown': 0.5,
    'darkUp': 0.5,
    'darkGrid': 0.5,
    'darkTrellis': 0.75,
    'lightHorizontal': 0.25,
    'lightVertical': 0.25,
    'lightDown': 0.25,
    'lightUp': 0.25,
    'lightGrid': 0.25,
    'lightTrellis': 0.25,
  };

  (String?, List<(String, String)>) _fill(XmlElement f) {
    final p = f.child('patternFill');
    if (p != null) {
      final type =
          p.attr('patternType') ??
          (p.child('fgColor') != null ? 'solid' : 'none');
      if (type == 'none') return (null, const []);
      final fg = _color(p.child('fgColor'));
      final bg = _color(p.child('bgColor'));
      if (type == 'solid') return (fg ?? bg ?? '#000000', const []);
      final density = _patternDensity[type] ?? 0.5;
      final c = density >= 0.5 ? (fg ?? '#000000') : bg;
      return (
        c,
        const [('patternFill', 'Pattern fill approximated as solid color')],
      );
    }
    final g = f.child('gradientFill');
    if (g != null) {
      final stop = g.elems('stop').firstOrNull;
      return (
        _color(stop?.child('color')),
        const [
          ('gradientFill', 'Gradient fill approximated by its first color'),
        ],
      );
    }
    return (null, const []);
  }

  static String? borderStyle(String? s) => switch (s) {
    'thin' || 'hair' => 'thin',
    'medium' => 'medium',
    'thick' => 'thick',
    'dashed' ||
    'mediumDashed' ||
    'dashDot' ||
    'mediumDashDot' ||
    'dashDotDot' ||
    'mediumDashDotDot' ||
    'slantDashDot' => 'dashed',
    'dotted' => 'dotted',
    'double' => 'double',
    _ => null,
  };

  (Map<FormatAttr, String>, List<(String, String)>) _border(XmlElement b) {
    final out = <FormatAttr, String>{};
    void edge(String name, FormatAttr a) {
      final e =
          b.child(name) ??
          (name == 'left'
              ? b.child('start')
              : name == 'right'
              ? b.child('end')
              : null);
      final st = borderStyle(e?.attr('style'));
      if (e == null || st == null) return;
      out[a] = '$st|${_color(e.child('color')) ?? 'auto'}';
    }

    edge('top', FormatAttr.borderTop);
    edge('right', FormatAttr.borderRight);
    edge('bottom', FormatAttr.borderBottom);
    edge('left', FormatAttr.borderLeft);
    final diag = b.child('diagonal');
    final hasDiag =
        (b.boolAttr('diagonalUp') ?? false) ||
        (b.boolAttr('diagonalDown') ?? false);
    final warnings = hasDiag && borderStyle(diag?.attr('style')) != null
        ? const [('diagonalBorder', 'Diagonal borders were not imported')]
        : const <(String, String)>[];
    return (out, warnings);
  }

  XlsxXf _xf(XmlElement xf) {
    final attrs = <FormatAttr, Object?>{};
    final extras = <String, Object?>{};
    final warnings = <(String, String)>[];
    final nfId = xf.intAttr('numFmtId') ?? 0;
    final nf = ExcelNumberFormats.importId(
      nfId,
      customNumFmts,
      warn: numberFormatWarnings.add,
    );
    if (nf != null) attrs[FormatAttr.numberFormat] = nf;
    final font = _at(fonts, xf.intAttr('fontId'));
    if (font != null) _fontAttrs(font, attrs);
    final fill = _at(fills, xf.intAttr('fillId'));
    if (fill != null) {
      if (fill.$1 != null) attrs[FormatAttr.fillColor] = fill.$1;
      warnings.addAll(fill.$2);
    }
    final border = _at(borders, xf.intAttr('borderId'));
    if (border != null) {
      attrs.addAll(border.$1);
      warnings.addAll(border.$2);
    }
    final al = xf.child('alignment');
    if (al != null) {
      switch (al.attr('horizontal')) {
        case 'left':
          attrs[FormatAttr.hAlign] = HorizontalAlign.left;
        case 'center':
          attrs[FormatAttr.hAlign] = HorizontalAlign.center;
        case 'right':
          attrs[FormatAttr.hAlign] = HorizontalAlign.right;
        case 'fill' || 'justify':
          attrs[FormatAttr.hAlign] = HorizontalAlign.left;
          warnings.add((
            'alignment',
            'Alignment "${al.attr('horizontal')}" approximated',
          ));
        case 'distributed' || 'centerContinuous':
          attrs[FormatAttr.hAlign] = HorizontalAlign.center;
          warnings.add((
            'alignment',
            'Alignment "${al.attr('horizontal')}" approximated',
          ));
      }
      switch (al.attr('vertical')) {
        case 'top':
          attrs[FormatAttr.vAlign] = VerticalAlign.top;
        case 'center':
          attrs[FormatAttr.vAlign] = VerticalAlign.middle;
        case 'justify' || 'distributed':
          attrs[FormatAttr.vAlign] = VerticalAlign.middle;
          warnings.add((
            'alignment',
            'Vertical alignment "${al.attr('vertical')}" approximated',
          ));
      }
      if (al.boolAttr('wrapText') ?? false) {
        attrs[FormatAttr.wrap] = WrapStrategy.wrap;
      }
      final rot = al.intAttr('textRotation');
      if (rot != null && rot != 0) {
        attrs[FormatAttr.rotation] = rot == 255
            ? 255
            : (rot > 90 ? -(rot - 90) : rot);
      }
      final indent = al.intAttr('indent');
      if (indent != null && indent > 0) extras['indent'] = indent;
      if (al.boolAttr('shrinkToFit') ?? false) extras['shrinkToFit'] = true;
    }
    final prot = xf.child('protection');
    if (prot != null) {
      if (prot.boolAttr('locked') == false) extras['locked'] = false;
      if (prot.boolAttr('hidden') == true) extras['formulaHidden'] = true;
    }
    return XlsxXf(IrFormat(CellFormat(attrs), extras), nf, warnings);
  }

  /// Adds the attributes of [font] that differ from the workbook default.
  void _fontAttrs(XlsxFont font, Map<FormatAttr, Object?> attrs) {
    final d = defaultFont;
    if (font.name != null && font.name != d?.name) {
      attrs[FormatAttr.fontFamily] = font.name;
    }
    if (font.size != null && font.size != d?.size) {
      attrs[FormatAttr.fontSize] = font.size;
    }
    if (font.bold) attrs[FormatAttr.bold] = true;
    if (font.italic) attrs[FormatAttr.italic] = true;
    if (font.underline) attrs[FormatAttr.underline] = true;
    if (font.strike) attrs[FormatAttr.strikethrough] = true;
    if (font.color != null &&
        font.color != d?.color &&
        font.color != 'theme:text') {
      attrs[FormatAttr.textColor] = font.color;
    }
  }

  (Map<String, Object?>, Map<String, Object?>) _dxf(XmlElement d) {
    final f = <String, Object?>{};
    final extras = <String, Object?>{};
    final font = d.child('font');
    if (font != null) {
      final x = _font(font);
      if (x.bold) f['bold'] = true;
      if (x.italic) f['italic'] = true;
      if (x.underline) f['underline'] = true;
      if (x.strike) f['strikethrough'] = true;
      if (font.child('b')?.attr('val') == '0') f['bold'] = false;
      if (font.child('i')?.attr('val') == '0') f['italic'] = false;
      if (x.color != null) f['textColor'] = x.color;
    }
    final p = d.child('fill')?.child('patternFill');
    if (p != null) {
      final c = _color(p.child('bgColor')) ?? _color(p.child('fgColor'));
      if (c != null && p.attr('patternType') != 'none') f['fillColor'] = c;
    }
    final nf = d.child('numFmt');
    if (nf != null && nf.attr('formatCode') != null) {
      extras['numberFormat'] = nf.attr('formatCode');
    }
    final b = d.child('border');
    if (b != null) {
      final m = _border(b).$1;
      if (m.isNotEmpty) {
        extras['borders'] = {for (final e in m.entries) e.key.column: e.value};
      }
    }
    return (f, extras);
  }

  static T? _at<T>(List<T> l, int? i) =>
      i != null && i >= 0 && i < l.length ? l[i] : null;
}
