import 'dart:typed_data';

import '../../mutations/row_change.dart';
import '../ir/import_warning.dart';

/// One imported sheet of an [ImportReport].
final class ImportSheetReport {
  /// Creates a sheet entry.
  const ImportSheetReport({
    required this.name,
    required this.sheetId,
    required this.rows,
    required this.columns,
    required this.cells,
  });

  /// Final sheet name (after conflict renames).
  final String name;

  /// Target sheet id.
  final String sheetId;

  /// Grid size after the import.
  final int rows;
  final int columns;

  /// Number of cells written with content (values or formulas).
  final int cells;

  /// JSON map.
  Map<String, Object?> toJson() => {
    'name': name,
    'sheetId': sheetId,
    'rows': rows,
    'columns': columns,
    'cells': cells,
  };
}

/// The import summary (11 §2.3): counts per sheet and the warnings of the
/// parser and the planner.
final class ImportReport {
  /// Creates a report.
  ImportReport({
    required List<ImportSheetReport> sheets,
    required Iterable<ImportWarning> warnings,
    this.fileName,
  }) : sheets = List.unmodifiable(sheets),
       warnings = List.unmodifiable(warnings);

  /// Imported sheets.
  final List<ImportSheetReport> sheets;

  /// Warnings (merged repeats carry a count).
  final List<ImportWarning> warnings;

  /// Source file name, if known.
  final String? fileName;

  /// Total cells written.
  int get cellCount => sheets.fold(0, (s, e) => s + e.cells);

  /// Number of warnings (merged entries, not occurrences).
  int get warningCount => warnings.length;

  /// Toast text: `Imported 3 sheets, 182,113 cells — 4 warnings`.
  String get summary {
    final n = sheets.length;
    final b = StringBuffer(
      'Imported $n ${n == 1 ? 'sheet' : 'sheets'}, '
      '${_grouped(cellCount)} ${cellCount == 1 ? 'cell' : 'cells'}',
    );
    if (warnings.isNotEmpty) {
      b.write(
        ' — ${warnings.length} ${warnings.length == 1 ? 'warning' : 'warnings'}',
      );
    }
    return b.toString();
  }

  /// The warnings table as TSV (*Copy report*): severity, sheet, range,
  /// message, count.
  String toTsv() {
    String clean(String? s) => (s ?? '').replaceAll(RegExp('[\t\r\n]+'), ' ');
    final b = StringBuffer('Severity\tSheet\tRange\tMessage\tCount\n');
    for (final w in warnings) {
      b.write(
        '${w.severity.name}\t${clean(w.sheet)}\t${clean(w.range)}\t'
        '${clean(w.message)}\t${w.count}\n',
      );
    }
    return b.toString();
  }

  /// JSON (stored as the report `StoredFile`).
  Map<String, Object?> toJson() => {
    'fileName': ?fileName,
    'summary': summary,
    'cells': cellCount,
    'sheets': [for (final s in sheets) s.toJson()],
    'warnings': [for (final w in warnings) w.toJson()],
  };

  static String _grouped(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

/// An image that must be stored before (or while) the import plan is
/// written: the plan's `EmbeddedObject` references [fileUuid].
final class IrImageUpload {
  /// Creates an upload.
  const IrImageUpload({
    required this.fileUuid,
    required this.bytes,
    required this.mimeType,
    this.name,
  });

  /// The `StoredFile` UUID used in the image spec.
  final String fileUuid;
  final Uint8List bytes;
  final String mimeType;

  /// Original file name.
  final String? name;
}

/// The grid size an import would produce (11 §3.4), for the dialog's limit
/// check before planning.
final class ImportSizeEstimate {
  /// Creates an estimate.
  const ImportSizeEstimate({
    required this.cells,
    required this.limit,
    required this.sheets,
  });

  /// Total grid cells of the spreadsheet after the import (rows × columns,
  /// summed over all sheets, including the kept ones).
  final int cells;

  /// `sheets.maxCellsPerSpreadsheet`.
  final int limit;

  /// Imported sheets `(name, rows, columns)`.
  final List<(String name, int rows, int columns)> sheets;

  /// Whether the import exceeds the limit.
  bool get exceedsLimit => cells > limit;

  /// Dialog message when the limit is exceeded.
  String get message =>
      'This import would make the spreadsheet ${_millions(cells)} cells; '
      'the limit is ${_millions(limit)}.';

  static String _millions(int n) {
    if (n >= 1000000) {
      final m = n / 1000000;
      final t = m == m.roundToDouble()
          ? m.toInt().toString()
          : m.toStringAsFixed(1);
      return '$t million';
    }
    return ImportReport._grouped(n);
  }
}

/// Result of `IrToRowsPlanner.plan`.
final class IrImportResult {
  /// Creates a result.
  const IrImportResult({
    required this.plan,
    required this.report,
    required this.sheetIds,
    this.imageUploads = const [],
  });

  /// The row changes (one undo step for imports into an existing
  /// spreadsheet). Apply with `model.applyPlan(plan)`; writers chunk it with
  /// [MutationPlan.chunks].
  final MutationPlan plan;

  /// The import summary.
  final ImportReport report;

  /// Ids of the created or written sheets, in tab order.
  final List<String> sheetIds;

  /// Images to store (the plan references their UUIDs).
  final List<IrImageUpload> imageUploads;
}
