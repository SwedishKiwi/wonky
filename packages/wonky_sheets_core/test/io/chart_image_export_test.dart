import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

import '../charts/support/chart_test_support.dart';

/// [model] with one chart object of [type] anchored at B2 (400 × 250 px).
void _addChart(WorkbookModel model, ChartType type) {
  final sheet = model.sheets.first;
  final spec = specFor(model, 'A1:D13').copyWith(type: type);
  final anchor = ObjectAnchor(
    rowId: sheet.rows.idAt(1),
    colId: sheet.columns.idAt(1),
    width: 400,
    height: 250,
  );
  model.applyChanges([
    RowChange.insert(SheetsTables.embeddedObject, 'chart-1', {
      Cols.sheetId: sheet.id,
      'kind': EmbeddedObjectKind.chart.name,
      'anchorJson': jsonEncode(anchor.toJson()),
      'specJson': spec.encode(),
      'zIndex': 0,
    }),
  ]);
}

void main() {
  group('Given a chart without an Excel equivalent', () {
    test('when exporting XLSX then it becomes a PNG picture at its anchor '
        'and the report says so', () {
      final model = monthlyRevenue();
      _addChart(model, ChartType.waterfall);
      final source = ModelCellSource(model);

      final doc = SheetsWorkbookExporter.toDocument(model, chartSource: source);

      final sheet = doc.sheets.first;
      expect(sheet.charts, isEmpty);
      final image = sheet.images.single;
      expect(image.mimeType, 'image/png');
      expect(image.bytes!.sublist(1, 4), utf8.encode('PNG'));
      expect(image.anchor.width, 400);
      expect(
        doc.warnings.where((w) => w.code == 'chartsAsImages'),
        hasLength(1),
      );

      final (bytes, warnings) = SheetsWorkbookExporter.writeDocument(
        doc,
        SheetsExportFormat.xlsx,
      );
      final zip = ZipDecoder().decodeBytes(bytes);
      expect(
        zip.files.where((f) => f.name.startsWith('xl/media/')),
        hasLength(1),
      );
      expect(warnings.any((w) => w.code == 'chartsNotExported'), isFalse);
    });

    test('when the chart maps to an Excel chart then it stays a chart', () {
      final model = monthlyRevenue();
      _addChart(model, ChartType.column);

      final doc = SheetsWorkbookExporter.toDocument(
        model,
        chartSource: ModelCellSource(model),
      );

      expect(doc.sheets.first.charts, hasLength(1));
      expect(doc.sheets.first.images, isEmpty);
    });

    test('when no chart source is passed then it is reported as before', () {
      final model = monthlyRevenue();
      _addChart(model, ChartType.waterfall);

      final doc = SheetsWorkbookExporter.toDocument(model);

      expect(doc.sheets.first.charts, hasLength(1));
      expect(doc.sheets.first.images, isEmpty);
    });
  });
}
