import 'package:xml/xml.dart';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../color/excel_colors.dart';
import '../ir/import_warning.dart';
import '../ir/ir_chart_spec.dart';
import '../ir/ir_range.dart';
import '../ir/workbook_document.dart';
import 'ooxml.dart';

/// DrawingML chart namespace.
const String kChartNs =
    'http://schemas.openxmlformats.org/drawingml/2006/chart';

/// One series as stored in a DrawingML chart.
final class _Ser {
  _Ser({
    required this.valRef,
    required this.values,
    this.nameRef,
    this.name,
    this.key,
  });

  /// `Sheet!$B$2:$B$9`.
  final String valRef;
  final List<IrValue?> values;
  final String? nameRef;
  final String? name;

  /// IR series key (positional).
  final String? key;
}

/// Wonky chart types that map to DrawingML chart groups (11 §6.3).
const Set<String> _exportable = {
  'column',
  'bar',
  'line',
  'area',
  'combo',
  'pie',
  'scatter',
  'radar',
};

/// IR charts (`IrChartSpec` convention) ⇄ DrawingML chart parts (11 §5.2
/// "Charts", §6.3).
///
/// Supported: column/bar (clustered, stacked, 100 %), line (smooth), area,
/// combo (column/line/area series, right axis), pie and doughnut, scatter
/// and radar, with titles, legend position, axis titles/min/max/log
/// scale/number format, series colors, data labels and trendlines. Other
/// chart types are reported and skipped.
abstract final class XlsxCharts {
  /// Whether [spec] can be written as a DrawingML chart.
  static bool isExportable(Map<String, Object?> spec) =>
      _exportable.contains(spec['type'] ?? 'column');

  // ---------------------------------------------------------------------------
  // Export.

  /// The `c:chartSpace` part for [chart] (null when its data cannot be
  /// resolved). [excelSheet] maps IR sheet names to the names written in
  /// the file.
  static String? write(
    IrChart chart,
    WorkbookDocument doc, {
    required String Function(String sheetName) excelSheet,
  }) {
    final spec = chart.spec;
    final type = (spec['type'] as String?) ?? 'column';
    if (!_exportable.contains(type)) return null;
    final data = _map(spec['data']);
    final ranges = <(IrSheet, GridRect, String)>[];
    for (final r in (data['ranges'] as List?) ?? const []) {
      if (r is! String) return null;
      final parsed = IrRange.parseA1(r);
      if (parsed == null || parsed.$1 == null) return null;
      final sheet = doc.sheetByName(parsed.$1!);
      if (sheet == null) return null;
      final rect = parsed.$2.toRect(
        sheet.usedRows < 1 ? 1 : sheet.usedRows,
        sheet.usedColumns < 1 ? 1 : sheet.usedColumns,
      );
      ranges.add((sheet, rect, excelSheet(sheet.name)));
    }
    if (ranges.isEmpty) return null;
    final switched = data['switchRowsColumns'] == true;
    final lines = <(int, int)>[
      for (var i = 0; i < ranges.length; i++)
        for (
          var o = 0;
          o < (switched ? ranges[i].$2.rowCount : ranges[i].$2.colCount);
          o++
        )
          (i, o),
    ];
    int? headerCount = (data['headerCount'] as num?)?.toInt();
    headerCount ??= _detectHeader(ranges, lines, switched);

    // Domain and series lines.
    (int, int)? domain;
    final d = _map(data['domain'])['ref'];
    if (d is Map) {
      domain = (
        (d['range'] as num? ?? 0).toInt(),
        (d['offset'] as num? ?? 0).toInt(),
      );
    } else if (data['useFirstColumnAsLabels'] != false && lines.length > 1) {
      domain = lines.first;
    }
    final seriesLines = <((int, int), String?)>[];
    final refs = (data['seriesRefs'] as List?) ?? const [];
    for (final s in refs) {
      if (s is! Map || s['hidden'] == true) continue;
      final ref = _map(s['ref']);
      seriesLines.add((
        (
          (ref['range'] as num? ?? 0).toInt(),
          (ref['offset'] as num? ?? 0).toInt(),
        ),
        s['key'] as String?,
      ));
    }
    if (refs.isEmpty) {
      for (final l in lines) {
        if (l != domain) {
          seriesLines.add((l, IrChartSpec.positionalKey(l.$1, l.$2)));
        }
      }
    }
    if (seriesLines.isEmpty) return null;

    _Ser? line((int, int) l, String? key) {
      if (l.$1 >= ranges.length) return null;
      final (sheet, rect, name) = ranges[l.$1];
      final header = headerCount!;
      final GridRect values;
      final GridRect? head;
      if (switched) {
        final r = rect.top + l.$2;
        if (r > rect.bottom) return null;
        values = GridRect(r, rect.left + header, r, rect.right);
        head = header > 0 ? GridRect(r, rect.left, r, rect.left) : null;
      } else {
        final c = rect.left + l.$2;
        if (c > rect.right) return null;
        values = GridRect(rect.top + header, c, rect.bottom, c);
        head = header > 0 ? GridRect(rect.top, c, rect.top, c) : null;
      }
      if (values.bottom < values.top || values.right < values.left) {
        return null;
      }
      String ref(GridRect g) =>
          IrRange.rect(g).toA1(sheet: name, absolute: true);
      final vals = <IrValue?>[
        for (var r = values.top; r <= values.bottom; r++)
          for (var c = values.left; c <= values.right; c++)
            sheet.cells.get(r, c)?.value,
      ];
      return _Ser(
        valRef: ref(values),
        values: vals,
        nameRef: head == null ? null : ref(head),
        name: head == null
            ? null
            : sheet.cells.get(head.top, head.left)?.value?.plainText,
        key: key,
      );
    }

    final cat = domain == null ? null : line(domain, null);
    final series = <_Ser>[];
    for (final (l, key) in seriesLines) {
      final s = line(l, key);
      if (s != null) series.add(s);
    }
    if (series.isEmpty) return null;
    return _ChartWriter(spec, type, cat, series).build();
  }

  static int _detectHeader(
    List<(IrSheet, GridRect, String)> ranges,
    List<(int, int)> lines,
    bool switched,
  ) {
    // A header row exists when the first cell of some numeric line is text.
    for (final (i, o) in lines) {
      final (sheet, rect, _) = ranges[i];
      final first = switched
          ? sheet.cells.get(rect.top + o, rect.left)
          : sheet.cells.get(rect.top, rect.left + o);
      final second = switched
          ? sheet.cells.get(rect.top + o, rect.left + 1)
          : sheet.cells.get(rect.top + 1, rect.left + o);
      if (first?.value is IrText && second?.value is IrNumber) return 1;
    }
    return 0;
  }

  static Map<String, Object?> _map(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};

  // ---------------------------------------------------------------------------
  // Import.

  /// Reads a `c:chartSpace` into an IR chart spec, or null (with a warning)
  /// when the chart type is not supported.
  static Map<String, Object?>? read(
    XmlElement chartSpace,
    ColorResolver colors,
    ImportWarnings warnings, {
    String? sheet,
  }) => _ChartReader(chartSpace, colors, warnings, sheet).read();
}

// -----------------------------------------------------------------------------
// Writer.

final class _ChartWriter {
  _ChartWriter(this.spec, this.type, this.cat, this.series);

  final Map<String, Object?> spec;
  final String type;
  final _Ser? cat;
  final List<_Ser> series;
  final StringBuffer b = StringBuffer();

  Map<String, Object?> _m(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};

  Map<String, Object?> _style(String? key) =>
      key == null ? const {} : _m(_m(spec['series'])[key]);

  String get _stacking => (spec['stacking'] as String?) ?? 'none';

  String build() {
    b.write(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<c:chartSpace xmlns:c="$kChartNs" xmlns:a="${Ooxml.drawingMl}" '
      'xmlns:r="${Ooxml.rel}"><c:roundedCorners val="0"/><c:chart>',
    );
    final title = _text(_m(spec['title'])['text']);
    if (title != null) {
      _title(title);
      b.write('<c:autoTitleDeleted val="0"/>');
    } else {
      b.write('<c:autoTitleDeleted val="1"/>');
    }
    b.write('<c:plotArea><c:layout/>');
    final axes = _groups();
    _axes(axes);
    b.write('</c:plotArea>');
    _legend();
    b.write('<c:plotVisOnly val="1"/><c:dispBlanksAs val="gap"/></c:chart>');
    b.write('</c:chartSpace>');
    return b.toString();
  }

  static String? _text(Object? t) =>
      t is String && t.trim().isNotEmpty ? t : null;

  void _title(String text) => b.write(
    '<c:title><c:tx><c:rich><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>'
    '${Ooxml.esc(text)}</a:t></a:r></a:p></c:rich></c:tx>'
    '<c:overlay val="0"/></c:title>',
  );

  /// Writes the chart groups; returns whether a secondary axis is used and
  /// whether the chart has category axes.
  ({bool secondary, bool cartesian, bool scatter}) _groups() {
    switch (type) {
      case 'pie':
        final hole = (_m(spec['typeOptions'])['pieHole'] as num?)?.toDouble();
        if (hole != null && hole > 0) {
          b.write('<c:doughnutChart><c:varyColors val="1"/>');
          _series(series, 'pie');
          b.write(
            '<c:firstSliceAng val="0"/><c:holeSize val="${(hole * 100).round().clamp(10, 90)}"/></c:doughnutChart>',
          );
        } else {
          b.write('<c:pieChart><c:varyColors val="1"/>');
          _series(series, 'pie');
          b.write('<c:firstSliceAng val="0"/></c:pieChart>');
        }
        return (secondary: false, cartesian: false, scatter: false);
      case 'scatter':
        b.write(
          '<c:scatterChart><c:scatterStyle val="lineMarker"/><c:varyColors val="0"/>',
        );
        _series(series, 'scatter');
        b.write('<c:axId val="1"/><c:axId val="2"/></c:scatterChart>');
        return (secondary: false, cartesian: true, scatter: true);
      case 'radar':
        b.write(
          '<c:radarChart><c:radarStyle val="marker"/><c:varyColors val="0"/>',
        );
        _series(series, 'radar');
        b.write('<c:axId val="1"/><c:axId val="2"/></c:radarChart>');
        return (secondary: false, cartesian: true, scatter: false);
    }
    // Cartesian groups by (type, axis).
    final groups = <(String, bool), List<_Ser>>{};
    for (final s in series) {
      final st = _style(s.key);
      var t = switch (type) {
        'combo' => (st['type'] as String?) ?? 'column',
        'bar' => 'bar',
        'line' => 'line',
        'area' => 'area',
        _ => 'column',
      };
      if (type != 'combo' && type != 'bar') t = type;
      final right = st['axis'] == 'right';
      (groups[(t, right)] ??= []).add(s);
    }
    var secondary = false;
    final order = groups.keys.toList()
      ..sort((a, b) => (a.$2 ? 1 : 0).compareTo(b.$2 ? 1 : 0));
    for (final key in order) {
      final (t, right) = key;
      if (right) secondary = true;
      final ax = right
          ? '<c:axId val="3"/><c:axId val="4"/>'
          : '<c:axId val="1"/><c:axId val="2"/>';
      final grouping = switch (_stacking) {
        'normal' => 'stacked',
        'percent' => 'percentStacked',
        _ => t == 'column' || t == 'bar' ? 'clustered' : 'standard',
      };
      switch (t) {
        case 'bar' || 'column':
          b.write(
            '<c:barChart><c:barDir val="${t == 'bar' ? 'bar' : 'col'}"/>'
            '<c:grouping val="$grouping"/><c:varyColors val="0"/>',
          );
          _series(groups[key]!, 'bar');
          b.write('<c:gapWidth val="150"/>');
          if (_stacking != 'none') b.write('<c:overlap val="100"/>');
          b.write('$ax</c:barChart>');
        case 'line':
          b.write(
            '<c:lineChart><c:grouping val="$grouping"/><c:varyColors val="0"/>',
          );
          _series(groups[key]!, 'line');
          b.write('<c:marker val="1"/>$ax</c:lineChart>');
        default:
          b.write(
            '<c:areaChart><c:grouping val="$grouping"/><c:varyColors val="0"/>',
          );
          _series(groups[key]!, 'area');
          b.write('$ax</c:areaChart>');
      }
    }
    return (secondary: secondary, cartesian: true, scatter: false);
  }

  void _series(List<_Ser> list, String kind) {
    final smooth = _m(spec['style'])['smooth'] == true;
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      final idx = series.indexOf(s);
      final st = _style(s.key);
      b.write('<c:ser><c:idx val="$idx"/><c:order val="$idx"/>');
      final label = st['labelOverride'] as String?;
      if (s.nameRef != null && label == null) {
        b.write(
          '<c:tx><c:strRef><c:f>${Ooxml.esc(s.nameRef!)}</c:f><c:strCache>'
          '<c:ptCount val="1"/><c:pt idx="0"><c:v>${Ooxml.esc(s.name ?? '')}</c:v></c:pt>'
          '</c:strCache></c:strRef></c:tx>',
        );
      } else if (label != null) {
        b.write('<c:tx><c:v>${Ooxml.esc(label)}</c:v></c:tx>');
      }
      final color = _hex(st['color']);
      if (color != null && kind != 'pie') {
        if (kind == 'line' || kind == 'scatter' || kind == 'radar') {
          b.write(
            '<c:spPr><a:ln w="28575"><a:solidFill><a:srgbClr val="$color"/></a:solidFill></a:ln></c:spPr>',
          );
        } else {
          b.write(
            '<c:spPr><a:solidFill><a:srgbClr val="$color"/></a:solidFill></c:spPr>',
          );
        }
      }
      if (kind == 'bar') b.write('<c:invertIfNegative val="0"/>');
      if (kind == 'line' || kind == 'scatter' || kind == 'radar') {
        b.write('<c:marker><c:symbol val="none"/></c:marker>');
      }
      if (_m(st['dataLabels'])['show'] == true) {
        b.write(
          '<c:dLbls><c:showLegendKey val="0"/><c:showVal val="1"/>'
          '<c:showCatName val="0"/><c:showSerName val="0"/>'
          '<c:showPercent val="0"/><c:showBubbleSize val="0"/></c:dLbls>',
        );
      }
      if (kind != 'pie' && kind != 'radar') _trendline(_m(st['trendline']));
      final c = cat;
      if (kind == 'scatter') {
        if (c != null) _ref('c:xVal', c, numeric: true);
        _ref('c:yVal', s, numeric: true);
        b.write('<c:smooth val="${smooth ? 1 : 0}"/>');
      } else {
        if (c != null) {
          _ref('c:cat', c, numeric: c.values.every((v) => v is IrNumber?));
        }
        _ref('c:val', s, numeric: true);
        if (kind == 'line') b.write('<c:smooth val="${smooth ? 1 : 0}"/>');
      }
      b.write('</c:ser>');
    }
  }

  void _trendline(Map<String, Object?> t) {
    if (t.isEmpty) return;
    final type = switch (t['type']) {
      'exponential' => 'exp',
      'polynomial' => 'poly',
      'logarithmic' => 'log',
      'power' => 'power',
      'movingAverage' => 'movingAvg',
      _ => 'linear',
    };
    b.write('<c:trendline><c:trendlineType val="$type"/>');
    if (type == 'poly') {
      b.write(
        '<c:order val="${((t['degree'] as num?) ?? 2).toInt().clamp(2, 6)}"/>',
      );
    }
    if (type == 'movingAvg') {
      b.write(
        '<c:period val="${((t['period'] as num?) ?? 2).toInt().clamp(2, 255)}"/>',
      );
    }
    b.write(
      '<c:dispRSqr val="${t['showR2'] == true ? 1 : 0}"/>'
      '<c:dispEq val="${t['label'] == 'equation' ? 1 : 0}"/></c:trendline>',
    );
  }

  void _ref(String el, _Ser s, {required bool numeric}) {
    b.write('<$el>');
    if (numeric) {
      b.write(
        '<c:numRef><c:f>${Ooxml.esc(s.valRef)}</c:f><c:numCache>'
        '<c:formatCode>General</c:formatCode><c:ptCount val="${s.values.length}"/>',
      );
      for (var i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        if (v is IrNumber) {
          b.write(
            '<c:pt idx="$i"><c:v>${CellContent.formatNumber(v.number)}</c:v></c:pt>',
          );
        }
      }
      b.write('</c:numCache></c:numRef>');
    } else {
      b.write(
        '<c:strRef><c:f>${Ooxml.esc(s.valRef)}</c:f><c:strCache>'
        '<c:ptCount val="${s.values.length}"/>',
      );
      for (var i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        if (v != null) {
          b.write('<c:pt idx="$i"><c:v>${Ooxml.esc(v.plainText)}</c:v></c:pt>');
        }
      }
      b.write('</c:strCache></c:strRef>');
    }
    b.write('</$el>');
  }

  void _axes(({bool secondary, bool cartesian, bool scatter}) g) {
    if (!g.cartesian) return;
    final axes = _m(spec['axes']);
    final h = _m(axes['h']);
    final v = _m(axes['v']);
    final v2 = _m(axes['v2']);
    final horizontalBar = type == 'bar';
    final catPos = horizontalBar ? 'l' : 'b';
    final valPos = horizontalBar ? 'b' : 'l';
    if (g.scatter) {
      _valAx(1, 2, catPos, h, gridlines: false);
    } else {
      _catAx(1, 2, catPos, h);
    }
    _valAx(2, 1, valPos, v, gridlines: true);
    if (g.secondary) {
      b.write(
        '<c:catAx><c:axId val="3"/><c:scaling><c:orientation val="minMax"/></c:scaling>'
        '<c:delete val="1"/><c:axPos val="$catPos"/><c:crossAx val="4"/></c:catAx>',
      );
      _valAx(
        4,
        3,
        horizontalBar ? 't' : 'r',
        v2,
        gridlines: false,
        crossMax: true,
      );
    }
  }

  void _scaling(Map<String, Object?> a) {
    b.write('<c:scaling>');
    if (a['logScale'] == true) b.write('<c:logBase val="10"/>');
    b.write(
      '<c:orientation val="${a['reverse'] == true ? 'maxMin' : 'minMax'}"/>',
    );
    for (final k in const ['max', 'min']) {
      final v = a[k];
      if (v is num) {
        b.write('<c:$k val="${CellContent.formatNumber(v.toDouble())}"/>');
      }
    }
    b.write('</c:scaling>');
  }

  void _axisTitle(Map<String, Object?> a) {
    final t = _text(_m(a['title'])['text']);
    if (t != null) _title(t);
  }

  void _numFmt(Map<String, Object?> a) {
    final f = a['numberFormat'];
    if (f is String && f.isNotEmpty) {
      b.write('<c:numFmt formatCode="${Ooxml.attr(f)}" sourceLinked="0"/>');
    }
  }

  void _catAx(int id, int cross, String pos, Map<String, Object?> a) {
    b.write('<c:catAx><c:axId val="$id"/>');
    _scaling(a);
    b.write('<c:delete val="0"/><c:axPos val="$pos"/>');
    _axisTitle(a);
    _numFmt(a);
    b.write(
      '<c:majorTickMark val="none"/><c:minorTickMark val="none"/>'
      '<c:tickLblPos val="nextTo"/><c:crossAx val="$cross"/>'
      '<c:crosses val="autoZero"/><c:auto val="1"/><c:lblAlgn val="ctr"/>'
      '<c:lblOffset val="100"/></c:catAx>',
    );
  }

  void _valAx(
    int id,
    int cross,
    String pos,
    Map<String, Object?> a, {
    required bool gridlines,
    bool crossMax = false,
  }) {
    b.write('<c:valAx><c:axId val="$id"/>');
    _scaling(a);
    b.write('<c:delete val="0"/><c:axPos val="$pos"/>');
    if (gridlines) b.write('<c:majorGridlines/>');
    _axisTitle(a);
    _numFmt(a);
    b.write(
      '<c:majorTickMark val="none"/><c:minorTickMark val="none"/>'
      '<c:tickLblPos val="nextTo"/><c:crossAx val="$cross"/>'
      '<c:crosses val="${crossMax ? 'max' : 'autoZero'}"/>'
      '<c:crossBetween val="between"/></c:valAx>',
    );
  }

  void _legend() {
    final pos = _m(spec['legend'])['position'] as String? ?? 'auto';
    if (pos == 'none') return;
    final p = switch (pos) {
      'top' => 't',
      'bottom' => 'b',
      'left' => 'l',
      _ => 'r',
    };
    b.write(
      '<c:legend><c:legendPos val="$p"/><c:overlay val="${pos == 'inside' ? 1 : 0}"/></c:legend>',
    );
  }

  static String? _hex(Object? c) {
    if (c is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(c)) return null;
    return c.substring(1).toUpperCase();
  }
}

// -----------------------------------------------------------------------------
// Reader.

final class _ChartReader {
  _ChartReader(this.root, this.colors, this.warnings, this.sheet);

  final XmlElement root;
  final ColorResolver colors;
  final ImportWarnings warnings;
  final String? sheet;

  void _skip(String what) => warnings.add(
    'chartSkipped',
    'Charts of type $what were not imported',
    sheet: sheet,
  );

  Map<String, Object?>? read() {
    final chart = root.child('chart');
    final plot = chart?.child('plotArea');
    if (chart == null || plot == null) return null;
    const groupNames = {
      'barChart',
      'bar3DChart',
      'lineChart',
      'line3DChart',
      'areaChart',
      'area3DChart',
      'pieChart',
      'pie3DChart',
      'doughnutChart',
      'scatterChart',
      'radarChart',
      'bubbleChart',
      'stockChart',
      'surfaceChart',
      'surface3DChart',
      'ofPieChart',
    };
    final groups = [
      for (final e in plot.childElements)
        if (groupNames.contains(e.localName)) e,
    ];
    if (groups.isEmpty) return null;
    for (final g in groups) {
      final n = g.localName;
      if (n == 'bubbleChart' ||
          n == 'stockChart' ||
          n.startsWith('surface') ||
          n == 'ofPieChart') {
        _skip(n.replaceAll('Chart', ''));
        return null;
      }
    }
    if (groups.any((g) => g.localName.contains('3D'))) {
      warnings.add(
        'chart3d',
        '3-D charts were imported as flat charts',
        severity: ImportSeverity.info,
        sheet: sheet,
      );
    }

    // Types.
    String kind(XmlElement g) => switch (g.localName) {
      'barChart' || 'bar3DChart' =>
        g.child('barDir')?.attr('val') == 'bar' ? 'bar' : 'column',
      'lineChart' || 'line3DChart' => 'line',
      'areaChart' || 'area3DChart' => 'area',
      'pieChart' || 'pie3DChart' || 'doughnutChart' => 'pie',
      'scatterChart' => 'scatter',
      _ => 'radar',
    };
    final kinds = [for (final g in groups) kind(g)];
    final type = kinds.toSet().length == 1 ? kinds.first : 'combo';
    if (type == 'combo' &&
        kinds.any((k) => k != 'column' && k != 'line' && k != 'area')) {
      _skip('combination');
      return null;
    }
    final spec = <String, Object?>{'v': 1, 'type': type};
    final grouping = groups.first.child('grouping')?.attr('val');
    if (grouping == 'stacked') spec['stacking'] = 'normal';
    if (grouping == 'percentStacked') spec['stacking'] = 'percent';

    // Series.
    final secondaryAxes = _secondaryAxes(plot);
    final ranges = <String>[];
    final seriesRefs = <Map<String, Object?>>[];
    final styles = <String, Object?>{};
    String? domainRef;
    var headers = true;
    var smooth = false;
    final entries = <(XmlElement, String, bool)>[];
    for (final g in groups) {
      final right = g
          .elems('axId')
          .any((a) => secondaryAxes.contains(a.attr('val')));
      for (final s in g.elems('ser')) {
        entries.add((s, kind(g), right));
      }
    }
    entries.sort(
      (a, b) => (a.$1.child('order')?.intAttr('val') ?? 0).compareTo(
        b.$1.child('order')?.intAttr('val') ?? 0,
      ),
    );
    final parsed =
        <
          (
            String val,
            String? name,
            String? label,
            XmlElement s,
            String kind,
            bool right,
          )
        >[];
    for (final (s, k, right) in entries) {
      final val = _f(s.child('val') ?? s.child('yVal'));
      if (val == null) continue;
      final cat = _f(s.child('cat') ?? s.child('xVal'));
      if (cat != null) domainRef ??= cat;
      final tx = s.child('tx');
      final nameRef = _f(tx);
      final literal = tx?.child('v')?.innerText;
      parsed.add((val, nameRef, literal, s, k, right));
    }
    if (parsed.isEmpty) return null;
    // Header rows: every series name is the cell right above its values.
    for (final p in parsed) {
      if (p.$2 == null || !_isAbove(p.$2!, p.$1)) headers = false;
    }
    if (domainRef != null && headers && _extendUp(domainRef) == null) {
      headers = false;
    }
    if (domainRef != null) {
      ranges.add(headers ? _extendUp(domainRef)! : domainRef);
    }
    for (final p in parsed) {
      final (val, name, literal, s, k, right) = p;
      final index = ranges.length;
      ranges.add(headers ? _extendUp(val)! : val);
      final key = IrChartSpec.positionalKey(index, 0);
      seriesRefs.add({
        'key': key,
        'ref': {'range': index, 'offset': 0},
      });
      final style = <String, Object?>{};
      if (type == 'combo') style['type'] = k;
      if (right) style['axis'] = 'right';
      final color = _seriesColor(s);
      if (color != null) style['color'] = color;
      if (!headers && (literal != null || name != null)) {
        final text = literal ?? _cacheText(s.child('tx'));
        if (text != null) style['labelOverride'] = text;
      }
      final dl = s.child('dLbls');
      if (dl?.child('showVal')?.attr('val') == '1') {
        style['dataLabels'] = {'show': true};
      }
      final tl = _trendline(s.child('trendline'));
      if (tl != null) style['trendline'] = tl;
      if (s.child('smooth')?.attr('val') == '1') smooth = true;
      if (style.isNotEmpty) styles[key] = style;
    }
    spec['data'] = {
      'ranges': ranges,
      'headerCount': headers ? 1 : 0,
      if (domainRef != null)
        'domain': {
          'ref': {'range': 0, 'offset': 0},
        },
      if (domainRef == null) 'useFirstColumnAsLabels': false,
      'seriesRefs': seriesRefs,
    };
    final style = <String, Object?>{if (smooth) 'smooth': true};
    if (style.isNotEmpty) spec['style'] = style;
    final title = _richText(chart.child('title'));
    if (title != null) spec['title'] = {'text': title};
    final axes = _axes(plot, secondaryAxes);
    if (axes.isNotEmpty) spec['axes'] = axes;
    final legend = chart.child('legend');
    String pos;
    if (legend == null) {
      pos = 'none';
    } else {
      pos = switch (legend.child('legendPos')?.attr('val')) {
        't' => 'top',
        'b' => 'bottom',
        'l' => 'left',
        _ => legend.child('overlay')?.attr('val') == '1' ? 'inside' : 'right',
      };
    }
    if (pos != 'right') spec['legend'] = {'position': pos};
    if (styles.isNotEmpty) spec['series'] = styles;
    final hole = groups.first.localName == 'doughnutChart'
        ? (groups.first.child('holeSize')?.intAttr('val') ?? 50)
        : null;
    if (hole != null) spec['typeOptions'] = {'pieHole': hole / 100};
    return spec;
  }

  /// Ids of value axes that cross at the maximum (secondary axes) and their
  /// category axes.
  Set<String> _secondaryAxes(XmlElement plot) {
    final out = <String>{};
    for (final v in plot.elems('valAx')) {
      if (v.child('crosses')?.attr('val') == 'max') {
        final id = v.child('axId')?.attr('val');
        final cross = v.child('crossAx')?.attr('val');
        if (id != null) out.add(id);
        if (cross != null) out.add(cross);
      }
    }
    return out;
  }

  Map<String, Object?> _axes(XmlElement plot, Set<String> secondary) {
    final out = <String, Object?>{};
    Map<String, Object?> axis(XmlElement a) {
      final m = <String, Object?>{};
      final t = _richText(a.child('title'));
      if (t != null) m['title'] = {'text': t};
      final sc = a.child('scaling');
      if (sc?.child('logBase') != null) m['logScale'] = true;
      if (sc?.child('orientation')?.attr('val') == 'maxMin') {
        m['reverse'] = true;
      }
      final mn = sc?.child('min')?.doubleAttr('val');
      final mx = sc?.child('max')?.doubleAttr('val');
      if (mn != null) m['min'] = _num(mn);
      if (mx != null) m['max'] = _num(mx);
      final nf = a.child('numFmt');
      if (nf != null && nf.attr('sourceLinked') != '1') {
        final code = nf.attr('formatCode');
        if (code != null && code != 'General') m['numberFormat'] = code;
      }
      return m;
    }

    final cats = [...plot.elems('catAx'), ...plot.elems('dateAx')];
    final vals = plot.elems('valAx').toList();
    final scatter = plot.child('scatterChart') != null;
    // Scatter charts have two value axes: the first is horizontal.
    XmlElement? h = cats
        .where((a) => !secondary.contains(a.child('axId')?.attr('val')))
        .firstOrNull;
    if (scatter && vals.isNotEmpty) h = vals.first;
    final v = vals
        .where(
          (a) => a != h && !secondary.contains(a.child('axId')?.attr('val')),
        )
        .firstOrNull;
    final v2 = vals
        .where((a) => secondary.contains(a.child('axId')?.attr('val')))
        .firstOrNull;
    if (h != null && axis(h).isNotEmpty) out['h'] = axis(h);
    if (v != null && axis(v).isNotEmpty) out['v'] = axis(v);
    if (v2 != null && axis(v2).isNotEmpty) out['v2'] = axis(v2);
    return out;
  }

  static Object _num(double d) => d == d.truncateToDouble() ? d.toInt() : d;

  static String? _f(XmlElement? e) {
    if (e == null) return null;
    for (final x in e.descendantElements) {
      if (x.localName == 'f') {
        final t = x.innerText.trim();
        if (t.isEmpty) return null;
        final p = IrRange.parseA1(t.startsWith('(') ? t.substring(1) : t);
        if (p == null || p.$1 == null || !p.$2.isBounded) return null;
        return p.$2.toA1(sheet: p.$1, absolute: true);
      }
    }
    return null;
  }

  static String? _cacheText(XmlElement? e) {
    if (e == null) return null;
    for (final x in e.descendantElements) {
      if (x.localName == 'v') return x.innerText;
    }
    return null;
  }

  /// Whether the single cell [name] is directly above the first cell of
  /// [values] (same sheet).
  static bool _isAbove(String name, String values) {
    final n = IrRange.parseA1(name);
    final v = IrRange.parseA1(values);
    if (n == null || v == null || n.$1 != v.$1) return false;
    final a = n.$2, b = v.$2;
    return a.r1 == a.r2 &&
        a.c1 == a.c2 &&
        a.c1 == b.c1 &&
        b.c1 == b.c2 &&
        a.r1! + 1 == b.r1;
  }

  /// [ref] extended one row up (null at the first row).
  static String? _extendUp(String ref) {
    final p = IrRange.parseA1(ref);
    if (p == null || p.$2.r1 == null || p.$2.r1 == 0) return null;
    final r = p.$2;
    return IrRange(
      r.r1! - 1,
      r.c1,
      r.r2,
      r.c2,
    ).toA1(sheet: p.$1, absolute: true);
  }

  String? _seriesColor(XmlElement s) {
    final sp = s.child('spPr');
    if (sp == null) return null;
    XmlElement? fill = sp.child('solidFill');
    fill ??= sp.child('ln')?.child('solidFill');
    final c = fill?.childElements.firstOrNull;
    if (c == null) return null;
    final v = c.attr('val');
    if (c.localName == 'srgbClr' && v != null && v.length == 6) {
      return '#${v.toUpperCase()}';
    }
    if (c.localName == 'schemeClr' && v != null) {
      final hex = colors.theme[v];
      return hex;
    }
    return null;
  }

  static Map<String, Object?>? _trendline(XmlElement? t) {
    if (t == null) return null;
    final type = switch (t.child('trendlineType')?.attr('val')) {
      'exp' => 'exponential',
      'poly' => 'polynomial',
      'log' => 'logarithmic',
      'power' => 'power',
      'movingAvg' => 'movingAverage',
      _ => 'linear',
    };
    return {
      'type': type,
      if (type == 'polynomial') 'degree': t.child('order')?.intAttr('val') ?? 2,
      if (type == 'movingAverage')
        'period': t.child('period')?.intAttr('val') ?? 2,
      if (t.child('dispRSqr')?.attr('val') == '1') 'showR2': true,
      if (t.child('dispEq')?.attr('val') == '1') 'label': 'equation',
    };
  }

  static String? _richText(XmlElement? title) {
    if (title == null) return null;
    final b = StringBuffer();
    for (final p in title.descendantElements.where((e) => e.localName == 'p')) {
      if (b.isNotEmpty) b.write('\n');
      for (final t in p.descendantElements.where((e) => e.localName == 't')) {
        b.write(t.innerText);
      }
    }
    final s = b.toString();
    return s.trim().isEmpty ? null : s;
  }
}
