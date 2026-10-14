import 'dart:convert';
import 'dart:typed_data';

import '../addressing/grid_geometry.dart';
import '../charts/chart_pipeline.dart';
import '../charts/render/svg/svg_chart_renderer.dart';
import '../charts/scene/geometry.dart' show ChartSize;
import '../charts/spec/chart_spec.dart';
import '../charts/spec/image_spec.dart';
import '../formula/model/workbook_view.dart';
import '../model/records.dart';
import '../model/schema.dart' show EmbeddedObjectKind;
import '../model/workbook_model.dart';
import 'csv/csv_exporter.dart';
import 'html/html_exporter.dart';
import 'ir/import_warning.dart';
import 'ir/workbook_document.dart';
import 'json/json_workbook.dart';
import 'ods/ods_exporter.dart';
import 'print/cell_display.dart';
import 'print/paginator.dart';
import 'print/pdf_fonts.dart';
import 'print/pdf_renderer.dart';
import 'read/model_to_ir.dart';
import 'xlsx/xlsx_charts.dart';
import 'xlsx/xlsx_exporter.dart';

/// Download formats of a spreadsheet (11 §6.1, *File › Download*,
/// `drive.export`).
enum SheetsExportFormat {
  xlsx(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  ods('ods', 'application/vnd.oasis.opendocument.spreadsheet'),
  pdf('pdf', 'application/pdf'),
  html('zip', 'application/zip'),
  csv('csv', 'text/csv'),
  tsv('tsv', 'text/tab-separated-values'),
  json('json', 'application/json');

  const SheetsExportFormat(this.extension, this.mimeType);

  /// File extension of the result (`zip` for zipped HTML).
  final String extension;
  final String mimeType;

  /// Whether the format goes through the IR (`ModelToIr` + a file writer).
  bool get viaIr => this == xlsx || this == ods || this == json;

  /// Whether only one sheet is exported (CSV/TSV, Google parity).
  bool get singleSheet => this == csv || this == tsv;

  /// By name (`xlsx`, …); null when unknown.
  static SheetsExportFormat? tryParse(String? name) {
    final n = name?.toLowerCase().trim();
    for (final f in values) {
      if (f.name == n) return f;
    }
    return null;
  }
}

/// A produced file.
final class SheetsExportArtifact {
  /// Creates an artifact.
  const SheetsExportArtifact({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.pageCount,
    this.warnings = const [],
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  /// PDF page count.
  final int? pageCount;

  /// The export report: features the format can't hold (11 §6.2).
  final List<ImportWarning> warnings;
}

/// Spreadsheet exports shared by the app and the server (11 §6): the same
/// inputs give the same bytes on both sides.
///
/// XLSX/ODS are two phases so callers can run the file writer off the UI
/// thread: [toDocument] (needs the live model and engine) and [writeDocument]
/// (pure IR → bytes, isolate-safe).
abstract final class SheetsWorkbookExporter {
  /// File names without `/\:*?"<>|`, at most 120 characters; empty →
  /// "Untitled spreadsheet".
  static String sanitizeFileName(String title) {
    var s = title.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), ' ').trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) s = 'Untitled spreadsheet';
    return s.length > 120 ? s.substring(0, 120).trim() : s;
  }

  /// `<title>.<ext>`, or `<title> - <sheet>.<ext>` for single-sheet
  /// formats (11 §7.7).
  static String fileNameFor(
    String title,
    SheetsExportFormat format, {
    String? sheetName,
  }) {
    final base = sheetName == null || sheetName.isEmpty
        ? sanitizeFileName(title)
        : sanitizeFileName('$title - $sheetName');
    return '$base.${format.extension}';
  }

  /// The IR of [model] for XLSX/ODS/JSON (computed values from [values]);
  /// image objects get their bytes from [imageBytes]. With [chartSource]
  /// (the engine) charts without an XLSX equivalent become PNG pictures at
  /// their anchor (11 §6.3; pass it for XLSX only).
  static WorkbookDocument toDocument(
    WorkbookModel model, {
    IrValueSource? values,
    Uint8List? Function(String fileUuid)? imageBytes,
    CellSource? chartSource,
  }) => ModelToIr.convert(
    model,
    values: values,
    imageBytes: imageBytes,
    chartImage: chartSource == null
        ? null
        : (chart, width, height) =>
              chartPng(model, chartSource, chart, width, height),
  );

  /// The PNG fallback of a chart Excel can't hold (null for exportable
  /// types or when it can't be drawn), rendered at 2× without Flutter.
  static Uint8List? chartPng(
    WorkbookModel model,
    CellSource source,
    EmbeddedObjectRecord chart,
    double width,
    double height,
  ) {
    if (!(width > 0) || !(height > 0)) return null;
    Object? json;
    try {
      json = jsonDecode(chart.specJson);
    } on FormatException {
      return null;
    }
    if (json is! Map || XlsxCharts.isExportable(json.cast<String, Object?>())) {
      return null;
    }
    try {
      return ChartPipeline.exportPng(
        spec: ChartSpec.fromJson(chart.specJson),
        model: model,
        values: source,
        size: ChartSize(width, height),
        scale: 2,
      );
    } on Object {
      return null;
    }
  }

  /// Writes [doc] as XLSX or ODS. Returns the bytes and the export report
  /// (the document's warnings plus the writer's).
  static (Uint8List, List<ImportWarning>) writeDocument(
    WorkbookDocument doc,
    SheetsExportFormat format, {
    DateTime? modified,
  }) {
    final report = ImportWarnings()..addAll(doc.warnings);
    final bytes = switch (format) {
      SheetsExportFormat.xlsx => XlsxExporter.export(
        doc,
        XlsxExportOptions(modified: modified),
        report,
      ),
      SheetsExportFormat.ods => OdsExporter.export(
        doc,
        OdsExportOptions(modified: modified),
        report,
      ),
      SheetsExportFormat.json => JsonWorkbook.export(doc),
      _ => throw ArgumentError.value(format, 'format', 'Not an IR format'),
    };
    return (bytes, report.toList());
  }

  /// CSV/TSV of one sheet (displayed values; [range] optional).
  static Uint8List delimited(
    WorkbookModel model,
    CellSource source, {
    required String sheetId,
    required SheetsExportFormat format,
    GridRect? range,
  }) => CsvExporter.export(
    model,
    source,
    sheetId: sheetId,
    range: range,
    options: format == SheetsExportFormat.tsv
        ? const CsvExportOptions.tsv()
        : const CsvExportOptions(),
  );

  /// Zipped HTML: charts as SVG, images from [imageBytes].
  static Uint8List html(
    WorkbookModel model,
    CellSource source, {
    Uint8List? Function(String fileUuid)? imageBytes,
    ConditionalOverlayProvider? conditional,
    DateTime? modified,
  }) => HtmlExporter.export(
    model,
    source,
    modified: modified,
    conditional: conditional,
    charts: (chart, w, h) {
      try {
        return const SvgChartRenderer().render(
          ChartPipeline.printSceneFor(model, source)(chart, w, h)!,
        );
      } on Object {
        return null;
      }
    },
    images: imageBytes == null
        ? null
        : (o) {
            final spec = ImageSpec.fromJson(o.specJson);
            final b = imageBytes(spec.fileUuid);
            return b == null ? null : HtmlImage(b, spec.mime);
          },
  );

  /// Paginates [job] with the PDF font metrics (the same row auto-fit as the
  /// renderer).
  static PaginationResult paginate(
    WorkbookModel model,
    CellSource source,
    PrintJob job, {
    PdfFontProvider fonts = const BuiltInPdfFontProvider(),
  }) => Paginator.paginate(
    model,
    job,
    source: source,
    measurer: PdfFontMeasurer(fonts),
  );

  /// The PDF of [pagination] (charts as vector scenes, images from
  /// [imageBytes]).
  static Future<Uint8List> pdf(
    WorkbookModel model,
    CellSource source,
    PaginationResult pagination, {
    required DateTime now,
    String? author,
    String? title,
    Uint8List? Function(String fileUuid)? imageBytes,
    ConditionalOverlayProvider? conditional,
    PdfFontProvider fonts = const BuiltInPdfFontProvider(),
    bool darkTheme = false,
  }) => SheetsPdfRenderer.render(
    model,
    source,
    pagination,
    now: now,
    fonts: fonts,
    darkTheme: darkTheme,
    author: author,
    title: title,
    conditional: conditional,
    charts: SceneChartPdfDrawer(
      ChartPipeline.printSceneFor(model, source, dark: darkTheme),
    ),
    images: imageBytes == null
        ? null
        : (EmbeddedObjectRecord o) {
            final b = imageBytes(ImageSpec.fromJson(o.specJson).fileUuid);
            return b == null ? null : PrintImage(b);
          },
  );

  /// File UUIDs of the image objects of [model] (to prefetch their bytes).
  static Set<String> imageFiles(WorkbookModel model) => {
    for (final s in model.sheets)
      for (final o in s.objects.values)
        if (o.kind == EmbeddedObjectKind.image)
          ImageSpec.fromJson(o.specJson).fileUuid,
  }..remove('');
}
