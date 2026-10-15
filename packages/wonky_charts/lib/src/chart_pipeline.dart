import 'dart:typed_data';

import 'data/chart_data.dart';
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

/// A chart laid out: the data, the paintable scene and every warning for the chart editor.
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

/// The entry points of the chart engine over resolved data (08 §6, §13): spec + [ChartData]
/// → [ChartScene] → SVG / PDF / PNG.
///
/// [ChartData] is the engine's only data input: Wonky Sheets resolves it from cells
/// (`SheetsChartPipeline` in `wonky_sheets_core`), Wonky Slides from a snapshot or a native
/// table. Lay the scene out again when the size, zoom, theme or spec changes:
///
/// ```dart
/// final layout = ChartPipeline.layout(
///   spec,
///   data,
///   size: ChartSize(width * zoom, height * zoom),
///   theme: ChartTheme.from(documentTheme, dark: isDark),
///   measurer: flutterTextMeasurer,    // TextPainter-backed in the apps
/// );
/// paintChartScene(canvas, layout.scene);
/// ```
abstract final class ChartPipeline {
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

  /// [layout] as a [ChartBuild] (data, scene and warnings).
  static ChartBuild build(
    ChartSpec spec,
    ChartData data, {
    required ChartSize size,
    required ChartTheme theme,
    required TextMeasurer measurer,
    String locale = 'en_US',
    ChartValueFormatter? formatter,
    ChartLayoutOptions options = const ChartLayoutOptions(),
  }) {
    final l = layout(
      spec,
      data,
      size: size,
      theme: theme,
      measurer: measurer,
      locale: locale,
      formatter: formatter,
      options: options,
    );
    return ChartBuild(data, l.scene, l.warnings);
  }

  /// SVG of a chart (08 §13): laid out with [measurer] (default: the deterministic approximate
  /// metrics; text is emitted as `<text>` with font fallbacks). [theme] is usually an export
  /// theme (`ChartTheme.from(…, export: true)`).
  static String exportSvg(
    ChartSpec spec,
    ChartData data, {
    required ChartSize size,
    required ChartTheme theme,
    String locale = 'en_US',
    ChartValueFormatter? formatter,
    TextMeasurer measurer = const ApproxTextMeasurer(),
    SvgChartRenderer renderer = const SvgChartRenderer(),
  }) => renderer.render(
    layout(
      spec,
      data,
      size: size,
      theme: theme,
      measurer: measurer,
      locale: locale,
      formatter: formatter,
    ).scene,
  );

  /// PDF of a chart (08 §13): one page of the chart's size plus 0.5 in margins, laid out with
  /// the metrics of the PDF's Helvetica font.
  static Future<Uint8List> exportPdf(
    ChartSpec spec,
    ChartData data, {
    required ChartSize size,
    required ChartTheme theme,
    String locale = 'en_US',
    ChartValueFormatter? formatter,
  }) => const PdfChartRenderer().renderDocument(
    layout(
      spec,
      data,
      size: size,
      theme: theme,
      measurer: PdfTextMeasurer(),
      locale: locale,
      formatter: formatter,
    ).scene,
  );

  /// PNG of a chart rendered without Flutter (server exports; 08 §13) at `size × scale` px.
  static Uint8List exportPng(
    ChartSpec spec,
    ChartData data, {
    required ChartSize size,
    required ChartTheme theme,
    double scale = 1,
    String locale = 'en_US',
    ChartValueFormatter? formatter,
  }) => const RasterChartRenderer().render(
    layout(
      spec,
      data,
      size: size,
      theme: theme,
      measurer: const RasterTextMeasurer(),
      locale: locale,
      formatter: formatter,
    ).scene,
    scale: scale,
  );
}
