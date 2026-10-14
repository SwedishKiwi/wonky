import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    show CellContent, NumberContent, TextContent;
import 'package:wonky_sync_models/ids.dart';

import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/drive/templates/builtin_templates.dart';
import '../sync/sync_db.dart';
import 'template_formulas.dart';

/// Creates spreadsheet content server-side in a space (Sheets 02 §3): the
/// Spreadsheet row (id = space), sheets with 1,000 × 26 row/column entities
/// and template cells. Used by `drive.createSpreadsheet`, templates and the
/// welcome spreadsheet.
abstract final class SpreadsheetFactory {
  static const defaultRows = 1000;
  static const defaultColumns = 26;
  static const defaultThemeJson =
      '{"v":1,"name":"Default","fonts":{"text":"Inter"},"colors":{}}';

  /// The text font of a new spreadsheet with default font [fontFamily].
  static String themeFont(String? fontFamily) {
    final f = fontFamily?.trim();
    return f == null || f.isEmpty ? 'Inter' : f;
  }

  /// [defaultThemeJson] with [fontFamily] as the text font.
  static String themeJsonFor(String? fontFamily) {
    final f = themeFont(fontFamily);
    if (f == 'Inter') return defaultThemeJson;
    return jsonEncode({
      'v': 1,
      'name': 'Default',
      'fonts': {'text': f},
      'colors': <String, Object?>{},
    });
  }

  /// Writes a new spreadsheet into [spaceUuid] as [authorUuid] (who must be a
  /// readWrite member). [sheets] empty = one blank "Sheet1".
  static Future<void> write(
    Session session, {
    required UuidValue spaceUuid,
    required UuidValue authorUuid,
    required String title,
    String locale = 'en_US',
    String timeZone = 'UTC',
    String? fontFamily,
    double? fontSize,
    List<TemplateSheet> sheets = const [],
    IdGenerator ids = const UuidV7IdGenerator(),
  }) async {
    final db = syncSessionOf(session);
    final now = nowUtc();
    final seeds = sheets.isEmpty
        ? const [
            TemplateSheet(
              name: 'Sheet1',
              rows: [],
              boldRows: {},
              frozenRows: 0,
            ),
          ]
        : sheets;
    final sheetKeys = FractionalIndex.nBetween(null, null, seeds.length);
    final rowKeys = FractionalIndex.nBetween(null, null, defaultRows);
    final columnKeys = FractionalIndex.nBetween(null, null, defaultColumns);

    await db.offlineSyncDb.transactionForUser(
      authorUuid,
      (tx) async {
        await Spreadsheet.db.insertRow(
          db,
          Spreadsheet(
            id: spaceUuid,
            title: title,
            locale: locale,
            timeZone: timeZone,
            defaultFontFamily: themeFont(fontFamily),
            defaultFontSize: fontSize ?? 10.0,
            themeJson: themeJsonFor(fontFamily),
            createdBy: authorUuid,
            createdAt: now,
          ),
          transaction: tx,
        );
        for (var s = 0; s < seeds.length; s++) {
          final seed = seeds[s];
          final sheetId = UuidValue.fromString(ids.newId());
          final rowCount = seed.rows.length > defaultRows
              ? seed.rows.length
              : defaultRows;
          final rowIds = [
            for (var i = 0; i < rowCount; i++)
              UuidValue.fromString(ids.newId()),
          ];
          final colIds = [
            for (var i = 0; i < defaultColumns; i++)
              UuidValue.fromString(ids.newId()),
          ];
          final keys = rowCount == defaultRows
              ? rowKeys
              : FractionalIndex.nBetween(null, null, rowCount);
          await Sheet.db.insertRow(
            db,
            Sheet(
              id: sheetId,
              spreadsheetId: spaceUuid,
              name: seed.name,
              sortKey: sheetKeys[s],
              frozenRows: seed.frozenRows,
              createdAt: now,
            ),
            transaction: tx,
          );
          await SheetRow.db.insert(
            db,
            [
              for (var r = 0; r < rowCount; r++)
                SheetRow(
                  id: rowIds[r],
                  sheetId: sheetId,
                  sortKey: keys[r],
                  createdAt: now,
                ),
            ],
            transaction: tx,
          );
          await SheetColumn.db.insert(
            db,
            [
              for (var c = 0; c < defaultColumns; c++)
                SheetColumn(
                  id: colIds[c],
                  sheetId: sheetId,
                  sortKey: columnKeys[c],
                  width: seed.columnWidths[c],
                  createdAt: now,
                ),
            ],
            transaction: tx,
          );
          final formulas = TemplateFormulas(
            sheetId: sheetId.uuid,
            sheetName: seed.name,
            rowIds: [for (final r in rowIds) r.uuid],
            rowKeys: keys,
            columnIds: [for (final c in colIds) c.uuid],
            columnKeys: columnKeys,
          );
          final cells = <Cell>[];
          for (var r = 0; r < seed.rows.length; r++) {
            final row = seed.rows[r];
            for (var c = 0; c < row.length && c < defaultColumns; c++) {
              final input = row[c];
              final bold = seed.boldRows.contains(r) ? true : null;
              final format = r >= seed.frozenRows
                  ? seed.numberFormats[c]
                  : null;
              if ((input == null || input.isEmpty) && bold == null) continue;
              cells.add(
                Cell(
                  id: SheetsIds.cellUuid(
                    sheetId.uuid,
                    rowIds[r].uuid,
                    colIds[c].uuid,
                  ),
                  sheetId: sheetId,
                  rowId: rowIds[r],
                  columnId: colIds[c],
                  content: input == null || input.isEmpty
                      ? null
                      : encodeInput(input, r, c, formulas),
                  bold: bold,
                  numberFormat: format,
                  createdAt: now,
                ),
              );
            }
          }
          if (cells.isNotEmpty) {
            await Cell.db.insert(db, cells, transaction: tx);
          }
        }
      },
      spaceId: spaceUuid,
    );
  }

  /// Encodes template input as stored cell content (en_US input rules:
  /// numbers, `=` formulas, a leading `'` forces text, everything else
  /// text).
  static String encodeInput(
    String input,
    int row,
    int col,
    TemplateFormulas formulas,
  ) {
    if (input.startsWith("'")) return TextContent(input.substring(1)).encode();
    if (input.startsWith('=') && input.length > 1) {
      return formulas.toStored(input, row, col);
    }
    final number = double.tryParse(input.trim());
    if (number != null && number.isFinite && !input.contains(':')) {
      return NumberContent(number).encode();
    }
    return TextContent(input).encode();
  }

  /// Visible row counts of the synced tables of [spaceUuid] (admin read).
  static Future<Map<String, int>> rowCounts(
    Session session,
    UuidValue spaceUuid,
  ) async {
    final space = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(spaceUuid),
    );
    if (space == null) return {};
    final result = await session.db.unsafeQuery(
      r'''
      SELECT t.name, count(*) FROM crdt_data_rows r
      JOIN crdt_schema_tables t ON t.id = r."tblId"
      WHERE r."spaceId" = @space AND r.visibility <= 2
      GROUP BY t.name
      ''',
      parameters: QueryParameters.named({'space': space.id}),
    );
    return {for (final row in result) row[0] as String: row[1] as int};
  }

  static CellContent? decode(String? content) => CellContent.decode(content);
}
