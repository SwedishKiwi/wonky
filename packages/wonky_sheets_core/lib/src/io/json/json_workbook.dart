import 'dart:convert';
import 'dart:typed_data';
import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../content/cell_content.dart';
import '../../format/attributes.dart';
import '../ir/ir_formats.dart';
import '../ir/workbook_document.dart';

/// Thrown for JSON that isn't a workbook.
final class JsonWorkbookException implements Exception {
  /// Creates the exception.
  const JsonWorkbookException(this.message);

  final String message;

  @override
  String toString() => 'JsonWorkbookException: $message';
}

/// The developer JSON format (11 §6.7, P2):
///
/// ```json
/// {"title": "Budget", "locale": "en_US",
///  "sheets": [{"name": "Data",
///              "values": [["Item", "Price"], ["Apples", 1.5]],
///              "formulas": [[null, null], [null, "=B2*2"]],
///              "numberFormats": [[null, "0.00"]]}]}
/// ```
///
/// `values` are unformatted (numbers, strings, booleans, error literals such
/// as `"#N/A"`, null for empty cells; formula cells hold their cached
/// result); `formulas` and `numberFormats` are only present when a sheet
/// has any. Trailing empty rows and columns are trimmed.
///
/// The importer also reads a bare 2D array (one sheet) and an array of
/// objects (a header row from the keys, then one row per object).
abstract final class JsonWorkbook {
  /// The JSON map of [doc].
  static Map<String, Object?> toJson(WorkbookDocument doc) => {
    'title': ?doc.title,
    'locale': ?doc.locale,
    'sheets': [for (final s in doc.sheets) _sheet(doc, s)],
  };

  /// [doc] as UTF-8 JSON (indented).
  static Uint8List export(WorkbookDocument doc) => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(toJson(doc))),
  );

  static Object? _value(IrValue? v) => switch (v) {
    null => null,
    IrNumber(:final number) =>
      number == number.truncateToDouble() && number.abs() < 1e15
          ? number.toInt()
          : number,
    IrBool(:final value) => value,
    IrError(:final kind) => kind.literal,
    _ => v.plainText,
  };

  static Map<String, Object?> _sheet(WorkbookDocument doc, IrSheet s) {
    final rows = s.cells.maxRow + 1;
    final cols = s.cells.maxCol + 1;
    final values = [
      for (var r = 0; r < rows; r++) List<Object?>.filled(cols, null),
    ];
    final formulas = [
      for (var r = 0; r < rows; r++) List<Object?>.filled(cols, null),
    ];
    final formats = [
      for (var r = 0; r < rows; r++) List<Object?>.filled(cols, null),
    ];
    var anyFormula = false;
    var anyFormat = false;
    for (final (r, c, cell) in s.cells.entries) {
      values[r][c] = _value(cell.value);
      final f = cell.formulaA1;
      if (f != null) {
        formulas[r][c] = '=$f';
        anyFormula = true;
      }
      final nf = IrFormats.effective(
        doc,
        s,
        r,
        c,
        cell,
      )[FormatAttr.numberFormat];
      if (nf is String && nf != NumberFormatPresets.automatic) {
        formats[r][c] = nf;
        anyFormat = true;
      }
    }
    return {
      'name': s.name,
      if (s.hidden) 'hidden': true,
      'values': values,
      if (anyFormula) 'formulas': formulas,
      if (anyFormat) 'numberFormats': formats,
    };
  }

  /// Parses JSON [bytes] (UTF-8) into a document; [fileName] names the
  /// sheet of the bare-array forms.
  static WorkbookDocument import(Uint8List bytes, {String fileName = ''}) {
    Object? data;
    try {
      data = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException catch (e) {
      throw JsonWorkbookException('The file is not valid JSON: ${e.message}');
    }
    final doc = WorkbookDocument();
    final base = _baseName(fileName);
    switch (data) {
      case {'sheets': final List<Object?> sheets}:
        final m = data as Map;
        if (m['title'] is String) doc.title = m['title'] as String;
        if (m['locale'] is String) doc.locale = m['locale'] as String;
        var i = 0;
        for (final s in sheets) {
          i++;
          if (s is! Map) continue;
          final name = s['name'] is String && (s['name'] as String).isNotEmpty
              ? s['name'] as String
              : 'Sheet$i';
          final sheet = IrSheet(name)..hidden = s['hidden'] == true;
          _fill(doc, sheet, s['values'], s['formulas'], s['numberFormats']);
          doc.sheets.add(sheet);
        }
      case final List<Object?> list when list.every((e) => e is Map):
        final keys = <String>[];
        for (final e in list) {
          for (final k in (e as Map).keys) {
            if (!keys.contains('$k')) keys.add('$k');
          }
        }
        final rows = <List<Object?>>[
          keys,
          for (final e in list) [for (final k in keys) _scalar((e as Map)[k])],
        ];
        final sheet = IrSheet(base);
        _fill(doc, sheet, rows, null, null);
        doc.sheets.add(sheet);
      case final List<Object?> list:
        final sheet = IrSheet(base);
        _fill(
          doc,
          sheet,
          [
            for (final r in list) r is List ? r : [r],
          ],
          null,
          null,
        );
        doc.sheets.add(sheet);
      default:
        throw const JsonWorkbookException(
          'Expected {"sheets": [...]}, an array of rows or an array of '
          'objects.',
        );
    }
    if (doc.sheets.isEmpty) {
      throw const JsonWorkbookException('The file has no sheets.');
    }
    return doc;
  }

  /// Nested objects/arrays of the object form become their JSON text.
  static Object? _scalar(Object? v) =>
      v is Map || v is List ? jsonEncode(v) : v;

  static void _fill(
    WorkbookDocument doc,
    IrSheet sheet,
    Object? values,
    Object? formulas,
    Object? formats,
  ) {
    Object? at(Object? grid, int r, int c) {
      if (grid is! List || r >= grid.length) return null;
      final row = grid[r];
      if (row is! List || c >= row.length) return null;
      return row[c];
    }

    int rowsOf(Object? g) => g is List ? g.length : 0;
    int colsOf(Object? g) => g is List
        ? g.fold<int>(0, (n, r) => r is List && r.length > n ? r.length : n)
        : 0;
    final rows = [
      rowsOf(values),
      rowsOf(formulas),
    ].reduce((a, b) => a > b ? a : b);
    final cols = [
      colsOf(values),
      colsOf(formulas),
    ].reduce((a, b) => a > b ? a : b);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = _irValue(at(values, r, c));
        final f = at(formulas, r, c);
        final formula = f is String && f.startsWith('=') && f.length > 1
            ? f.substring(1)
            : null;
        final nf = at(formats, r, c);
        if (v == null && formula == null) continue;
        sheet.cells.set(
          r,
          c,
          IrCell(
            value: v,
            formulaA1: formula,
            format: nf is String && nf.isNotEmpty
                ? doc.formats.internAttrs(
                    CellFormat({FormatAttr.numberFormat: nf}),
                  )
                : 0,
          ),
        );
      }
    }
  }

  static IrValue? _irValue(Object? v) => switch (v) {
    null => null,
    num() => IrNumber(v.toDouble()),
    bool() => IrBool(v),
    String() when v.isEmpty => null,
    String() when v.startsWith('#') && CellErrorKind.tryParse(v) != null =>
      IrError(CellErrorKind.tryParse(v)!),
    String() => IrText(v),
    _ => IrText(jsonEncode(v)),
  };

  static String _baseName(String fileName) {
    var n = fileName.split(RegExp(r'[/\\]')).last;
    final dot = n.lastIndexOf('.');
    if (dot > 0) n = n.substring(0, dot);
    return n.trim().isEmpty ? 'Sheet1' : n.trim();
  }
}
