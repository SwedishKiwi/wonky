import 'package:wonky_sheets_core/formula.dart' show ColumnLetters, GridRect;
import 'package:wonky_sheets_core/model.dart';

/// Kinds of cleanup suggestions (07 §12.3).
enum CleanupKind {
  numbersAsText,
  whitespace,
  duplicates,
  capitalization,
  emptyRows,
  mixedTypes,
}

/// One cleanup suggestion card (07 §12.3): what was found, a before/after
/// preview of up to three cells, and what *Apply* writes.
class CleanupSuggestion {
  const CleanupSuggestion({
    required this.kind,
    required this.range,
    required this.count,
    this.colId,
    this.column,
    this.preview = const [],
    this.cells = const [],
    this.rowIds = const [],
    this.hasHeader = false,
  });

  final CleanupKind kind;

  /// The data region (duplicates, empty rows) or the column's data cells.
  final GridRect range;

  /// Affected cells / rows.
  final int count;
  final String? colId;

  /// Column letter (`D`) for the card text.
  final String? column;

  /// Up to three `(before, after)` pairs.
  final List<(String, String)> preview;

  /// Cells to rewrite `(row, col, newText)` (numbers as text, case).
  final List<(int, int, String)> cells;

  /// Rows to delete (empty rows).
  final List<String> rowIds;
  final bool hasHeader;

  /// Stable id (dismissing, `sheets.cleanup.applySuggestion {id}`).
  String get id => colId == null ? kind.name : '${kind.name}:$colId';

  /// Whether *Apply* exists (mixed types only links to column stats).
  bool get applicable => kind != CleanupKind.mixedTypes;
}

/// Background detectors of 07 §12.3 over the data region of a sheet:
/// numbers/dates stored as text, leading/trailing/double spaces, duplicate
/// rows, inconsistent capitalization of categorical values, empty rows
/// inside the data and mixed types in a column. At most [maxRows] rows are
/// inspected.
abstract final class CleanupDetector {
  static const maxRows = 50000;

  static List<CleanupSuggestion> detect(
    SheetModel sheet, {
    required CellValue Function(int row, int col) value,
    String locale = 'en_US',
  }) {
    final used = sheet.usedRect();
    if (used == null || used.rowCount < 2) return const [];
    final region = GridRect(
      used.top,
      used.left,
      used.top + (used.rowCount > maxRows ? maxRows : used.rowCount) - 1,
      used.right,
    );
    final header = HeaderDetector.looksLikeHeader(value, region);
    final top = header ? region.top + 1 : region.top;
    if (top > region.bottom) return const [];
    final out = <CleanupSuggestion>[];
    final parser = InputParser.instance;

    // Empty rows inside the data.
    final empty = <String>[];
    var lastFilled = top;
    for (var r = top; r <= region.bottom; r++) {
      var blank = true;
      for (var c = region.left; c <= region.right; c++) {
        if (sheet.cellAt(r, c)?.decoded != null) {
          blank = false;
          break;
        }
      }
      if (blank) {
        empty.add(sheet.rows.idAt(r));
      } else {
        lastFilled = r;
      }
    }
    // Only rows between data count (trailing blanks don't).
    final inside = [
      for (final id in empty)
        if (sheet.rows.indexOf(id) < lastFilled) id,
    ];
    if (inside.isNotEmpty) {
      out.add(
        CleanupSuggestion(
          kind: CleanupKind.emptyRows,
          range: region,
          count: inside.length,
          rowIds: inside,
          preview: [
            for (final id in inside.take(3))
              ('${sheet.rows.indexOf(id) + 1}', ''),
          ],
        ),
      );
    }

    // Duplicate rows (all columns, first kept).
    final seen = <String>{};
    var dups = 0;
    final dupPreview = <(String, String)>[];
    for (var r = top; r <= region.bottom; r++) {
      final b = StringBuffer();
      var any = false;
      for (var c = region.left; c <= region.right; c++) {
        final v = value(r, c);
        if (!v.isBlank()) any = true;
        b
          ..write(v.runtimeType)
          ..write('\u0001')
          ..write(v)
          ..write('\u0002');
      }
      if (!any) continue;
      if (!seen.add(b.toString())) {
        dups++;
        if (dupPreview.length < 3) dupPreview.add(('${r + 1}', ''));
      }
    }
    if (dups > 0) {
      out.add(
        CleanupSuggestion(
          kind: CleanupKind.duplicates,
          range: region,
          count: dups,
          hasHeader: header,
          preview: dupPreview,
        ),
      );
    }

    for (var c = region.left; c <= region.right; c++) {
      final colId = sheet.columns.idAt(c);
      final letter = ColumnLetters.fromIndex(c);
      final colRect = GridRect(top, c, region.bottom, c);
      final asText = <(int, int, String)>[];
      final asTextPreview = <(String, String)>[];
      var spaces = 0;
      final spacePreview = <(String, String)>[];
      final variants = <String, Map<String, int>>{};
      var numbers = 0;
      var texts = 0;
      var nonBlank = 0;
      for (var r = top; r <= region.bottom; r++) {
        final content = sheet.cellAt(r, c)?.decoded;
        if (content == null) continue;
        nonBlank++;
        switch (content) {
          case TextContent(:final text):
            texts++;
            final t = text.trim();
            if (t.isNotEmpty) {
              final parsed = parser.parseValue(t, locale: locale);
              if (parsed != null) {
                asText.add((r, c, t));
                if (asTextPreview.length < 3) {
                  asTextPreview.add((text, t));
                }
              }
            }
            final collapsed = t.replaceAll(RegExp(r'[  ]{2,}'), ' ');
            if (collapsed != text) {
              spaces++;
              if (spacePreview.length < 3) {
                spacePreview.add(('"$text"', '"$collapsed"'));
              }
            }
            if (t.isNotEmpty && t.length <= 40) {
              final m = variants.putIfAbsent(t.toLowerCase(), () => {});
              m[t] = (m[t] ?? 0) + 1;
            }
          case NumberContent():
            numbers++;
          default:
            break;
        }
      }
      if (asText.isNotEmpty) {
        out.add(
          CleanupSuggestion(
            kind: CleanupKind.numbersAsText,
            range: colRect,
            count: asText.length,
            colId: colId,
            column: letter,
            preview: asTextPreview,
            cells: asText,
          ),
        );
      }
      if (spaces > 0) {
        out.add(
          CleanupSuggestion(
            kind: CleanupKind.whitespace,
            range: colRect,
            count: spaces,
            colId: colId,
            column: letter,
            preview: spacePreview,
          ),
        );
      }
      // Categorical column: few distinct values, some differing by case.
      final mixedCase = {
        for (final e in variants.entries)
          if (e.value.length > 1) e.key: e.value,
      };
      if (mixedCase.isNotEmpty && variants.length <= 50 && texts >= 4) {
        final rewrites = <(int, int, String)>[];
        final preview = <(String, String)>[];
        final canonical = {
          for (final e in mixedCase.entries)
            e.key:
                (e.value.entries.toList()..sort((a, b) {
                      final d = b.value.compareTo(a.value);
                      return d != 0 ? d : a.key.compareTo(b.key);
                    }))
                    .first
                    .key,
        };
        for (var r = top; r <= region.bottom; r++) {
          final content = sheet.cellAt(r, c)?.decoded;
          if (content is! TextContent) continue;
          final t = content.text.trim();
          final target = canonical[t.toLowerCase()];
          if (target != null && target != t) {
            rewrites.add((r, c, target));
            if (preview.length < 3) preview.add((t, target));
          }
        }
        if (rewrites.isNotEmpty) {
          out.add(
            CleanupSuggestion(
              kind: CleanupKind.capitalization,
              range: colRect,
              count: rewrites.length,
              colId: colId,
              column: letter,
              preview: preview,
              cells: rewrites,
            ),
          );
        }
      }
      // Mixed types: a numeric column with some text (besides numbers
      // stored as text, reported above).
      final realTexts = texts - asText.length;
      if (nonBlank >= 4 &&
          numbers > 0 &&
          realTexts > 0 &&
          numbers >= nonBlank * 0.6) {
        out.add(
          CleanupSuggestion(
            kind: CleanupKind.mixedTypes,
            range: colRect,
            count: realTexts,
            colId: colId,
            column: letter,
          ),
        );
      }
    }
    return out;
  }
}
