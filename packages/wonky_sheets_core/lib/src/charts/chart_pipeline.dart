import 'dart:typed_data';

import 'package:wonky_charts/wonky_charts.dart';

import '../formula/model/workbook_view.dart';
import '../model/records.dart';
import '../model/schema.dart';
import '../model/workbook_model.dart';
import 'data/chart_data_resolver.dart';

/// The Sheets entry points of the chart engine (08 §4, §6, §13): spec + workbook →
/// [ChartData] → [ChartScene] → SVG / PDF / PNG. Resolving cells is Sheets' part; layout and
/// rendering are the generic [ChartPipeline] of `wonky_charts`.
///
/// The app keeps one [ChartData] per chart and re-resolves it when its source cells change
/// (`ChartData.dataVersion` tells whether anything did), and lays the scene out again when
/// the size, zoom, theme or spec changes:
///
/// ```dart
/// final built = SheetsChartPipeline.build(
///   spec: ChartSpec.fromJson(object.specJson),
///   model: model,
///   values: cellSource,               // engine values, number formats, hidden state
///   size: ChartSize(anchor.width * zoom, anchor.height * zoom),
///   theme: ChartTheme.from(model.theme, dark: isDark),
///   measurer: flutterTextMeasurer,    // TextPainter-backed in the app
/// );
/// paintChartScene(canvas, built.scene);
/// ```
abstract final class SheetsChartPipeline {
  /// Resolves the data of [spec] from [model] with the computed values, number formats and
  /// hidden state of [values] (08 §4). [locale] (default: the spreadsheet's) formats labels.
  static ChartData resolve(
    ChartSpec spec,
    WorkbookModel model,
    CellSource values, {
    String? locale,
    ChartValueFormatter? formatter,
  }) => ChartDataResolver.resolve(
    spec,
    model,
    values,
    fmt: formatter ?? _formatter(model, locale),
  );

  /// [resolve] and [ChartPipeline.layout] in one call.
  static ChartBuild build({
    required ChartSpec spec,
    required WorkbookModel model,
    required CellSource values,
    required ChartSize size,
    required ChartTheme theme,
    required TextMeasurer measurer,
    String? locale,
    ChartValueFormatter? formatter,
    ChartLayoutOptions options = const ChartLayoutOptions(),
  }) {
    final fmt = formatter ?? _formatter(model, locale);
    final data = ChartDataResolver.resolve(spec, model, values, fmt: fmt);
    return ChartPipeline.build(
      spec,
      data,
      size: size,
      theme: theme,
      measurer: measurer,
      formatter: fmt,
      options: options,
    );
  }

  /// The export theme of [model]'s spreadsheet theme: white background and print colors, or
  /// the dark editor colors when [dark] ("Export with dark theme", 08 §6.4).
  static ChartTheme exportTheme(WorkbookModel model, {bool dark = false}) =>
      ChartTheme.from(model.theme, dark: dark, export: true);

  /// SVG download of a chart (08 §13): laid out with [measurer] (default: the deterministic
  /// approximate metrics; text is emitted as `<text>` with font fallbacks).
  static String exportSvg({
    required ChartSpec spec,
    required WorkbookModel model,
    required CellSource values,
    required ChartSize size,
    bool dark = false,
    TextMeasurer measurer = const ApproxTextMeasurer(),
    SvgChartRenderer renderer = const SvgChartRenderer(),
  }) {
    final fmt = _formatter(model, null);
    return ChartPipeline.exportSvg(
      spec,
      ChartDataResolver.resolve(spec, model, values, fmt: fmt),
      size: size,
      theme: exportTheme(model, dark: dark),
      formatter: fmt,
      measurer: measurer,
      renderer: renderer,
    );
  }

  /// PDF download of a chart (08 §13): one page of the chart's size plus 0.5 in margins,
  /// laid out with the metrics of the PDF's Helvetica font.
  static Future<Uint8List> exportPdf({
    required ChartSpec spec,
    required WorkbookModel model,
    required CellSource values,
    required ChartSize size,
    bool dark = false,
  }) {
    final fmt = _formatter(model, null);
    return ChartPipeline.exportPdf(
      spec,
      ChartDataResolver.resolve(spec, model, values, fmt: fmt),
      size: size,
      theme: exportTheme(model, dark: dark),
      formatter: fmt,
    );
  }

  /// PNG of a chart rendered without Flutter (server exports, MCP `export_chart_png`; 08 §13)
  /// at `size × scale` px.
  static Uint8List exportPng({
    required ChartSpec spec,
    required WorkbookModel model,
    required CellSource values,
    required ChartSize size,
    double scale = 1,
    bool dark = false,
  }) {
    final fmt = _formatter(model, null);
    return ChartPipeline.exportPng(
      spec,
      ChartDataResolver.resolve(spec, model, values, fmt: fmt),
      size: size,
      theme: exportTheme(model, dark: dark),
      formatter: fmt,
      scale: scale,
    );
  }

  /// The `sceneFor` callback of the print renderer's `SceneChartPdfDrawer` (11 §6.3, 08 §13):
  /// lays out chart objects of [model] at the printed size (1 px = 1 pt) with the export
  /// theme and the metrics of the PDF's Helvetica font. Other objects give null (skipped).
  static ChartScene? Function(EmbeddedObjectRecord, double, double)
  printSceneFor(WorkbookModel model, CellSource values, {bool dark = false}) {
    final theme = exportTheme(model, dark: dark);
    final measurer = PdfTextMeasurer();
    return (object, width, height) {
      if (object.kind != EmbeddedObjectKind.chart ||
          !(width > 0) ||
          !(height > 0)) {
        return null;
      }
      return build(
        spec: ChartSpec.fromJson(object.specJson),
        model: model,
        values: values,
        size: ChartSize(width, height),
        theme: theme,
        measurer: measurer,
      ).scene;
    };
  }

  static ChartValueFormatter _formatter(WorkbookModel model, String? locale) =>
      DefaultChartValueFormatter(locale: locale ?? model.spreadsheet.locale);
}
