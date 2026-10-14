import 'dart:math' as math;

import '../../addressing/grid_geometry.dart';
import '../ir/ir_range.dart';
import '../ir/workbook_document.dart';
import '../xlsx/xlsx_charts.dart' show IrChartLine, XlsxCharts;
import 'ods_styles.dart';

/// IR charts → ODF chart objects (11 §6.4, 08 §23): each chart is an
/// embedded `Object N/content.xml` (`office:chart`) shown by a `draw:frame`
/// in the sheet's `table:shapes`. 3D charts set `chart:three-dimensional`
/// (deep rows for 3D lines, unstacked areas and surfaces), the column shape
/// (`chart:solid-type`) and the view (`dr3d:transform`, `dr3d:projection`).
abstract final class OdsCharts {
  /// Media type of an embedded chart object.
  static const mediaType = 'application/vnd.oasis.opendocument.chart';

  static const _chartNs = 'urn:oasis:names:tc:opendocument:xmlns:chart:1.0';
  static const _dr3dNs = 'urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0';

  /// Wonky types that map to ODF chart classes.
  static const exportable = {
    'column',
    'bar',
    'line',
    'area',
    'combo',
    'pie',
    'scatter',
    'radar',
    'surface',
  };

  static Map<String, Object?> _m(Object? v) =>
      v is Map ? v.cast<String, Object?>() : const {};

  /// An ODF cell range address (`'My sheet'.B2:'My sheet'.B9`).
  static String rangeAddress(String sheet, GridRect r) {
    final q = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(sheet)
        ? sheet
        : "'${sheet.replaceAll("'", "''")}'";
    final a1 = IrRange.rect(r).toA1(absolute: true);
    final parts = a1.split(':');
    return parts.length == 1
        ? '$q.${parts[0]}'
        : '$q.${parts[0]}:$q.${parts[1]}';
  }

  /// `content.xml` of [chart]'s object, or null when it can't be written
  /// (unsupported type, unresolvable data). [odsSheet] maps IR sheet names
  /// to the names written in the file.
  static String? objectContent(
    IrChart chart,
    WorkbookDocument doc, {
    required String Function(String sheetName) odsSheet,
  }) {
    final spec = chart.spec;
    final type = (spec['type'] as String?) ?? 'column';
    if (!exportable.contains(type)) return null;
    final lines = XlsxCharts.lines(chart, doc);
    if (lines == null) return null;
    String addr(IrChartLine l, GridRect r) =>
        rangeAddress(odsSheet(l.sheet.name), r);

    final t3 = _m(spec['threeD']);
    final threeD =
        type == 'surface' ||
        (t3['enabled'] == true &&
            const {'column', 'bar', 'line', 'area', 'pie'}.contains(type));
    final stacking = (spec['stacking'] as String?) ?? 'none';
    final pieHole = (_m(spec['typeOptions'])['pieHole'] as num?)?.toDouble();
    final cls = switch (type) {
      'line' => 'chart:line',
      'area' => 'chart:area',
      'pie' => (pieHole ?? 0) > 0 ? 'chart:ring' : 'chart:circle',
      'scatter' => 'chart:scatter',
      'radar' => 'chart:radar',
      'surface' => 'chart:surface',
      _ => 'chart:bar',
    };
    final deep =
        threeD &&
        (type == 'line' ||
            type == 'surface' ||
            (type == 'area' && stacking == 'none'));
    final shape = switch (t3['shape']) {
      'cylinder' => 'cylinder',
      'cone' => 'cone',
      'pyramid' => 'pyramid',
      _ => 'cuboid',
    };
    final smooth = _m(spec['style'])['smooth'] == true;

    final styles = StringBuffer()
      ..write(
        '<style:style style:name="ch1" style:family="chart">'
        '<style:graphic-properties draw:stroke="none"/></style:style>',
      )
      ..write(
        '<style:style style:name="pa1" style:family="chart">'
        '<style:chart-properties'
        '${type == 'bar' ? ' chart:vertical="true"' : ''}'
        '${stacking == 'normal' ? ' chart:stacked="true"' : ''}'
        '${stacking == 'percent' ? ' chart:percentage="true"' : ''}'
        '${smooth ? ' chart:interpolation="cubic-spline"' : ''}'
        '${threeD ? ' chart:three-dimensional="true"' : ''}'
        '${deep ? ' chart:deep="true"' : ''}'
        '${threeD && (type == 'column' || type == 'bar') ? ' chart:solid-type="$shape"' : ''}'
        '/></style:style>',
      );
    final seriesStyles = _m(spec['series']);
    final series = StringBuffer();
    for (var i = 0; i < lines.series.length; i++) {
      final s = lines.series[i];
      final st = _m(seriesStyles[s.key]);
      final color = st['color'];
      final seriesType = type == 'combo'
          ? switch (st['type']) {
              'line' => 'chart:line',
              'area' => 'chart:area',
              _ => 'chart:bar',
            }
          : cls;
      if (color is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
        styles.write(
          '<style:style style:name="s$i" style:family="chart">'
          '<style:graphic-properties draw:fill-color="$color" '
          'svg:stroke-color="$color"/></style:style>',
        );
      }
      series.write(
        '<chart:series${color is String ? ' chart:style-name="s$i"' : ''} '
        'chart:class="$seriesType" '
        'chart:values-cell-range-address="${OdsXml.attr(addr(s, s.values))}"'
        '${s.header == null ? '' : ' chart:label-cell-address="${OdsXml.attr(addr(s, s.header!))}"'}'
        '${st['axis'] == 'right' && !threeD ? ' chart:attached-axis="secondary-y"' : ''}'
        '/>',
      );
    }

    final title = (_m(spec['title'])['text'] as String?)?.trim() ?? '';
    final legendPos = _m(spec['legend'])['position'];
    final legend = legendPos == 'none'
        ? ''
        : '<chart:legend chart:legend-position="${switch (legendPos) {
            'top' => 'top',
            'bottom' => 'bottom',
            'left' => 'start',
            _ => 'end',
          }}" style:legend-expansion="high"/>';
    final cat = lines.category;
    final pie = type == 'pie';
    final axes = pie
        ? ''
        : '<chart:axis chart:dimension="x" chart:name="primary-x">'
              '${cat == null ? '' : '<chart:categories table:cell-range-address="${OdsXml.attr(addr(cat, cat.values))}"/>'}'
              '</chart:axis>'
              '<chart:axis chart:dimension="y" chart:name="primary-y">'
              '<chart:grid chart:class="major"/></chart:axis>'
              '${deep ? '<chart:axis chart:dimension="z" chart:name="primary-z"/>' : ''}';
    final view = threeD ? _view3D(t3, pie: pie) : '';
    final w = chart.anchor.width * 0.75;
    final h = chart.anchor.height * 0.75;
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content ${OdsNs.declarations} '
        'xmlns:chart="$_chartNs" xmlns:dr3d="$_dr3dNs" office:version="1.2">'
        '<office:automatic-styles>$styles</office:automatic-styles>'
        '<office:body><office:chart>'
        '<chart:chart svg:width="${_n(w)}pt" svg:height="${_n(h)}pt" '
        'chart:class="$cls" chart:style-name="ch1">'
        '${title.isEmpty ? '' : '<chart:title><text:p>${OdsXml.esc(title)}</text:p></chart:title>'}'
        '$legend'
        '<chart:plot-area chart:style-name="pa1" '
        'chart:data-source-has-labels="both"$view>'
        '$axes$series'
        '${threeD && !pie ? '<chart:wall/><chart:floor/>' : ''}'
        '</chart:plot-area></chart:chart></office:chart></office:body>'
        '</office:document-content>';
  }

  /// The 3D view of the plot area: rotation from the spec's azimuth and
  /// elevation (radians), perspective or parallel projection.
  static String _view3D(Map<String, Object?> t3, {required bool pie}) {
    final az =
        ((t3['azimuth'] as num?)?.toDouble() ?? (pie ? 0 : 20)) * math.pi / 180;
    final el =
        ((t3['elevation'] as num?)?.toDouble() ?? (pie ? 40 : 20)) *
        math.pi /
        180;
    final persp = (t3['perspective'] as num?)?.toDouble() ?? 15;
    return ' dr3d:projection="${persp > 0 ? 'perspective' : 'parallel'}" '
        'dr3d:transform="rotatey(${_n(-az)}) rotatex(${_n(el)})" '
        'dr3d:shade-mode="${t3['lighting'] == 'flat' ? 'flat' : 'gouraud'}"';
  }

  /// The `draw:frame` showing object [href] (`./Object 1`) at [chart]'s
  /// anchor on [sheet] (absolute position in pt).
  static String frame(IrChart chart, IrSheet sheet, String href, int id) {
    final a = chart.anchor;
    final cw = sheet.defaultColumnWidth ?? 100;
    final rh = sheet.defaultRowHeight ?? 21;
    var x = a.dx;
    for (var c = 0; c < a.col; c++) {
      x += sheet.columns[c]?.size ?? cw;
    }
    var y = a.dy;
    for (var r = 0; r < a.row; r++) {
      y += sheet.rows[r]?.size ?? rh;
    }
    final name = chart.title ?? 'Chart $id';
    return '<draw:frame draw:name="${OdsXml.attr(name)}" draw:z-index="$id" '
        'svg:x="${_n(x * 0.75)}pt" svg:y="${_n(y * 0.75)}pt" '
        'svg:width="${_n(a.width * 0.75)}pt" '
        'svg:height="${_n(a.height * 0.75)}pt">'
        '<draw:object xlink:href="${OdsXml.attr(href)}" xlink:type="simple" '
        'xlink:show="embed" xlink:actuate="onLoad"/>'
        '${chart.altText == null || chart.altText!.isEmpty ? '' : '<svg:desc>${OdsXml.esc(chart.altText!)}</svg:desc>'}'
        '</draw:frame>';
  }

  static String _n(double v) {
    final r = (v * 1000).round() / 1000;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }
}
