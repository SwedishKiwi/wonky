import 'dart:typed_data';

import '../formula/model/workbook_view.dart';
import '../model/records.dart';
import '../model/schema.dart';
import '../model/workbook_model.dart';
import 'data/chart_data.dart';
import 'data/chart_data_resolver.dart';
import 'data/value_formatter.dart';
import 'layout/chart_layout_engine.dart';
import 'layout/chart_theme.dart';
import 'layout/text_measurer.dart';
import 'render/pdf/pdf_chart_renderer.dart';
import 'render/raster/raster_chart_renderer.dart';
import 'render/raster/raster_text_measurer.dart';
import 'render/svg/svg_chart_renderer.dart';
import 'scene/geometry.dart';
import 'scene/scene.dart';
import 'spec/chart_spec.dart';

/// A chart resolved and laid out: the data, the paintable scene and every warning for the
/// chart editor.
final class ChartBuild {
  /// Creates a result.
  const ChartBuild(this.data, this.scene, this.layoutWarnings);

  /// The resolved data (also the source of the "View data as table" dialog, 08 §14).
  final ChartData data;

  /// The renderer-independent scene: Flutter paints it with its scene painter, the exports
  /// render it to SVG, PDF or PNG.
  final ChartScene scene;

  /// Warnings found while laying out (log values skipped, downsampled, …).
  final List<ChartWarning> layoutWarnings;

  /// Data and layout warnings, for the chart editor.
  List<ChartWarning> get warnings => [...data.warnings, ...layoutWarnings];
}

/// The entry points of the chart engine (08 §4, §6, §13): spec + workbook → [ChartData] →
/// [ChartScene] → SVG / PDF / PNG.
///
/// The app keeps one [ChartData] per chart and re-resolves it when its source cells change
/// (`ChartData.dataVersion` tells whether anything did), and lays the scene out again when
/// the size, zoom, theme or spec changes:
///
/// ```dart
/// final built = ChartPipeline.build(
///   spec: ChartSpec.fromJson(object.specJson),
///   model: model,
///   values: cellSource,               // engine values, number formats, hidden state
///   size: ChartSize(anchor.width * zoom, anchor.height * zoom),
///   theme: ChartTheme.from(model.theme, dark: isDark),
///   measurer: flutterTextMeasurer,    // TextPainter-backed in the app
/// );
/// paintScene(canvas, built.scene);
/// ```
abstract final class ChartPipeline {
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

  /// Lays out [spec] with already resolved [data] at [size] (logical px; multiply by the zoom
  /// for crisp text, 08 §9.1). [options] carry editor-only state (legend highlight, table page,
  /// accessibility patterns).
  static ChartLayout layout(
    ChartSpec spec,
    ChartData data, {
    required ChartSize size,
    required ChartTheme theme,
    required TextMeasurer measurer,
    String locale = 'en_US',
    ChartValueFormatter? formatter,
    ChartLayoutOptions options = const ChartLayoutOptions(),
  }) => ChartLayoutEngine.layoutDetailed(
    spec,
    data,
    size,
    theme,
    measurer,
    fmt: formatter ?? DefaultChartValueFormatter(locale: locale),
    options: options,
  );

  /// [resolve] and [layout] in one call.
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
    final layout = ChartLayoutEngine.layoutDetailed(
      spec,
      data,
      size,
      theme,
      measurer,
      fmt: fmt,
      options: options,
    );
    return ChartBuild(data, layout.scene, layout.warnings);
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
  }) => renderer.render(
    build(
      spec: spec,
      model: model,
      values: values,
      size: size,
      theme: exportTheme(model, dark: dark),
      measurer: measurer,
    ).scene,
  );

  /// PDF download of a chart (08 §13): one page of the chart's size plus 0.5 in margins,
  /// laid out with the metrics of the PDF's Helvetica font.
  static Future<Uint8List> exportPdf({
    required ChartSpec spec,
    required WorkbookModel model,
    required CellSource values,
    required ChartSize size,
    bool dark = false,
  }) => const PdfChartRenderer().renderDocument(
    build(
      spec: spec,
      model: model,
      values: values,
      size: size,
      theme: exportTheme(model, dark: dark),
      measurer: PdfTextMeasurer(),
    ).scene,
  );

  /// PNG of a chart rendered without Flutter (server exports, MCP `export_chart_png`; 08 §13)
  /// at `size × scale` px.
  static Uint8List exportPng({
    required ChartSpec spec,
    required WorkbookModel model,
    required CellSource values,
    required ChartSize size,
    double scale = 1,
    bool dark = false,
  }) => const RasterChartRenderer().render(
    build(
      spec: spec,
      model: model,
      values: values,
      size: size,
      theme: exportTheme(model, dark: dark),
      measurer: const RasterTextMeasurer(),
    ).scene,
    scale: scale,
  );

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
