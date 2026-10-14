import '../../format/attributes.dart';
import '../../format/borders.dart';
import '../../model/schema.dart';
import '../color/excel_colors.dart';
import '../ir/import_warning.dart';
import '../ir/workbook_document.dart';
import '../numfmt/excel_number_formats.dart';
import 'ooxml.dart';

/// Builds a deduplicated `styles.xml` (numFmts with custom ids ≥ 164, fonts,
/// fills, borders, cellXfs, dxfs).
final class XlsxStyleWriter {
  /// Creates a writer with the workbook default font.
  XlsxStyleWriter({
    required this.defaultFont,
    required this.defaultSize,
    required this.locale,
    this.warnings,
  }) {
    _font(null, null, false, false, false, false, null);
    _fills
      ..add('<fill><patternFill patternType="none"/></fill>')
      ..add('<fill><patternFill patternType="gray125"/></fill>');
    _fillIndex['none'] = 0;
    _borders.add('<border><left/><right/><top/><bottom/><diagonal/></border>');
    _borderIndex[_borders.first] = 0;
    _xfs.add('<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>');
    _xfIndex[_xfs.first] = 0;
  }

  final String defaultFont;
  final double defaultSize;
  final String locale;
  final ImportWarnings? warnings;

  final Map<String, int> _numFmtIds = {};
  final List<(int, String)> _numFmts = [];
  final List<String> _fonts = [];
  final Map<String, int> _fontIndex = {};
  final List<String> _fills = [];
  final Map<String, int> _fillIndex = {};
  final List<String> _borders = [];
  final Map<String, int> _borderIndex = {};
  final List<String> _xfs = [];
  final Map<String, int> _xfIndex = {};
  final Map<IrFormat, int> _formatXf = {};
  final List<String> _dxfs = [];
  final Map<String, int> _dxfIndex = {};
  final Set<int> _dateXfs = {};

  /// Whether xf [index] has a date number format.
  bool isDateXf(int index) => _dateXfs.contains(index);

  /// OOXML color element body attributes for a Wonky color.
  static String colorAttrs(String? color) {
    if (color == null || color == 'auto') return 'auto="1"';
    if (color.startsWith('theme:')) {
      final slot = ExcelColors.slotOfWonkyKey(color.substring(6));
      final idx = slot == null ? null : ExcelColors.themeIndexOf(slot);
      if (idx != null) return 'theme="$idx"';
      return 'auto="1"';
    }
    final hex = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)
        ? color
        : '#000000';
    return 'rgb="${ExcelColors.toArgb(hex)}"';
  }

  int numFmtId(String? pattern) {
    final e = ExcelNumberFormats.export(pattern, locale: locale);
    if (e.id != null) return e.id!;
    return _numFmtIds.putIfAbsent(e.code, () {
      final id = 164 + _numFmts.length;
      _numFmts.add((id, e.code));
      return id;
    });
  }

  int _font(
    String? name,
    double? size,
    bool b,
    bool i,
    bool u,
    bool s,
    String? color,
  ) {
    final x = StringBuffer('<font>');
    if (b) x.write('<b/>');
    if (i) x.write('<i/>');
    if (s) x.write('<strike/>');
    if (u) x.write('<u/>');
    x.write('<sz val="${_n(size ?? defaultSize)}"/>');
    x.write(
      color == null ? '<color theme="1"/>' : '<color ${colorAttrs(color)}/>',
    );
    x.write(
      '<name val="${Ooxml.attr(name ?? defaultFont)}"/><family val="2"/>',
    );
    x.write('</font>');
    final key = x.toString();
    return _fontIndex.putIfAbsent(key, () {
      _fonts.add(key);
      return _fonts.length - 1;
    });
  }

  int _fill(String? color) {
    // `theme:background` is the explicit "no fill" of the IR.
    if (color == null || color == 'theme:background') return 0;
    final key =
        '<fill><patternFill patternType="solid"><fgColor ${colorAttrs(color)}/><bgColor indexed="64"/></patternFill></fill>';
    return _fillIndex.putIfAbsent(key, () {
      _fills.add(key);
      return _fills.length - 1;
    });
  }

  static String _edge(String el, String? v) {
    final spec = BorderSpec.tryParse(v);
    if (spec == null || spec.isNone) return '<$el/>';
    final style = switch (spec.style!) {
      BorderStyle.thin => 'thin',
      BorderStyle.medium => 'medium',
      BorderStyle.thick => 'thick',
      BorderStyle.dashed => 'dashed',
      BorderStyle.dotted => 'dotted',
      BorderStyle.double => 'double',
    };
    return '<$el style="$style"><color ${colorAttrs(spec.color)}/></$el>';
  }

  /// `<border>` XML from edge values.
  static String borderXml(Map<String, Object?> edges) =>
      '<border>'
      '${_edge('left', edges['borderLeft'] as String?)}${_edge('right', edges['borderRight'] as String?)}'
      '${_edge('top', edges['borderTop'] as String?)}${_edge('bottom', edges['borderBottom'] as String?)}<diagonal/></border>';

  int _border(CellFormat f) {
    final key = borderXml({for (final a in FormatAttr.borders) a.column: f[a]});
    return _borderIndex.putIfAbsent(key, () {
      _borders.add(key);
      return _borders.length - 1;
    });
  }

  /// The cellXfs index of [f].
  int xf(IrFormat f) {
    if (f.isEmpty) return 0;
    final cached = _formatXf[f];
    if (cached != null) return cached;
    final a = f.attrs;
    final pattern = a[FormatAttr.numberFormat] as String?;
    final nf = numFmtId(pattern);
    final font = _font(
      a[FormatAttr.fontFamily] as String?,
      a[FormatAttr.fontSize] as double?,
      a[FormatAttr.bold] == true,
      a[FormatAttr.italic] == true,
      a[FormatAttr.underline] == true,
      a[FormatAttr.strikethrough] == true,
      a[FormatAttr.textColor] as String?,
    );
    final fill = _fill(a[FormatAttr.fillColor] as String?);
    final border = _border(a);
    final al = StringBuffer();
    switch (a[FormatAttr.hAlign]) {
      case HorizontalAlign.left:
        al.write(' horizontal="left"');
      case HorizontalAlign.center:
        al.write(' horizontal="center"');
      case HorizontalAlign.right:
        al.write(' horizontal="right"');
    }
    switch (a[FormatAttr.vAlign]) {
      case VerticalAlign.top:
        al.write(' vertical="top"');
      case VerticalAlign.middle:
        al.write(' vertical="center"');
    }
    final rot = a[FormatAttr.rotation] as int?;
    if (rot != null && rot != 0) {
      al.write(
        ' textRotation="${rot == 255 ? 255 : (rot < 0 ? 90 - rot : rot.clamp(0, 90))}"',
      );
    }
    if (a[FormatAttr.wrap] == WrapStrategy.wrap) al.write(' wrapText="1"');
    if (a[FormatAttr.wrap] == WrapStrategy.clip) {
      warnings?.add(
        'clipWrap',
        'Clip wrapping is not available in Excel (overflow used)',
        severity: ImportSeverity.info,
      );
    }
    final indent = f.extras['indent'];
    if (indent is num && indent > 0) al.write(' indent="${indent.toInt()}"');
    if (f.extras['shrinkToFit'] == true) al.write(' shrinkToFit="1"');
    final prot = StringBuffer();
    if (f.extras['locked'] == false) prot.write(' locked="0"');
    if (f.extras['formulaHidden'] == true) prot.write(' hidden="1"');
    final x = StringBuffer(
      '<xf numFmtId="$nf" fontId="$font" fillId="$fill" borderId="$border" xfId="0"',
    );
    if (nf != 0) x.write(' applyNumberFormat="1"');
    if (font != 0) x.write(' applyFont="1"');
    if (fill != 0) x.write(' applyFill="1"');
    if (border != 0) x.write(' applyBorder="1"');
    if (al.isNotEmpty) x.write(' applyAlignment="1"');
    if (prot.isNotEmpty) x.write(' applyProtection="1"');
    if (al.isEmpty && prot.isEmpty) {
      x.write('/>');
    } else {
      x.write('>');
      if (al.isNotEmpty) x.write('<alignment$al/>');
      if (prot.isNotEmpty) x.write('<protection$prot/>');
      x.write('</xf>');
    }
    final key = x.toString();
    final idx = _xfIndex.putIfAbsent(key, () {
      _xfs.add(key);
      return _xfs.length - 1;
    });
    if (ExcelNumberFormats.isDatePattern(pattern)) _dateXfs.add(idx);
    _formatXf[f] = idx;
    return idx;
  }

  /// The dxf index of a CF format map (+ XLSX extras such as numberFormat
  /// and borders).
  int dxf(Map<String, Object?> format, Map<String, Object?> extras) {
    final b = StringBuffer('<dxf>');
    final font = StringBuffer();
    if (format['bold'] == true) font.write('<b/>');
    if (format['bold'] == false) font.write('<b val="0"/>');
    if (format['italic'] == true) font.write('<i/>');
    if (format['italic'] == false) font.write('<i val="0"/>');
    if (format['strikethrough'] == true) font.write('<strike/>');
    if (format['underline'] == true) font.write('<u/>');
    if (format['textColor'] is String) {
      font.write('<color ${colorAttrs(format['textColor'] as String)}/>');
    }
    if (font.isNotEmpty) b.write('<font>$font</font>');
    final nf = extras['numberFormat'];
    if (nf is String) {
      b.write(
        '<numFmt numFmtId="${numFmtId(nf)}" formatCode="${Ooxml.attr(nf)}"/>',
      );
    }
    if (format['fillColor'] is String) {
      b.write(
        '<fill><patternFill><bgColor ${colorAttrs(format['fillColor'] as String)}/></patternFill></fill>',
      );
    }
    final borders = extras['borders'];
    if (borders is Map) b.write(borderXml(borders.cast<String, Object?>()));
    b.write('</dxf>');
    final key = b.toString();
    return _dxfIndex.putIfAbsent(key, () {
      _dxfs.add(key);
      return _dxfs.length - 1;
    });
  }

  /// The `styles.xml` part.
  String build() {
    final b = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<styleSheet xmlns="${Ooxml.main}">',
    );
    if (_numFmts.isNotEmpty) {
      b.write('<numFmts count="${_numFmts.length}">');
      for (final (id, code) in _numFmts) {
        b.write('<numFmt numFmtId="$id" formatCode="${Ooxml.attr(code)}"/>');
      }
      b.write('</numFmts>');
    }
    b.write('<fonts count="${_fonts.length}">${_fonts.join()}</fonts>');
    b.write('<fills count="${_fills.length}">${_fills.join()}</fills>');
    b.write('<borders count="${_borders.length}">${_borders.join()}</borders>');
    b.write(
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>',
    );
    b.write('<cellXfs count="${_xfs.length}">${_xfs.join()}</cellXfs>');
    b.write(
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>',
    );
    b.write('<dxfs count="${_dxfs.length}">${_dxfs.join()}</dxfs>');
    b.write(
      '<tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>',
    );
    b.write('</styleSheet>');
    return b.toString();
  }

  static String _n(double d) =>
      d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
}
