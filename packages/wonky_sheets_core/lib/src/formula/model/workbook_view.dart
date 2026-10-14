import '../../addressing/grid_geometry.dart';
import '../values/errors.dart';
import '../values/fvalue.dart';

/// Former name of [EngineCellInput] (clashes with the model's `CellInput` mutation input in
/// the package barrel, so it is hidden from `formula.dart`).
@Deprecated('Use EngineCellInput')
typedef CellInput = EngineCellInput;

/// Raw content of a non-empty cell as the engine sees it: a stored-form formula or a literal
/// value (02 §2 content encoding).
final class EngineCellInput {
  /// Stored-form formula text **without** the leading `=`, or null for literal values.
  final String? formula;

  /// Literal value; [FEmpty.instance] for formulas.
  final FValue value;

  /// Engine-private cache slot (the engine attaches its node here). Models must create a new
  /// [EngineCellInput] whenever the content changes and keep the instance otherwise.
  Object? engineData;

  EngineCellInput.formula(String stored)
    : formula = stored.startsWith('=') ? stored.substring(1) : stored,
      value = FEmpty.instance;

  EngineCellInput.value(this.value) : formula = null;

  bool get isFormula => formula != null;

  /// Parses the synced content encoding (`=…`, `n:`, `s:`, `b:`, `e:`, `r:`). Returns null for
  /// null/empty content.
  static EngineCellInput? fromContent(String? content) {
    if (content == null || content.isEmpty) return null;
    if (content.startsWith('=')) {
      return EngineCellInput.formula(content.substring(1));
    }
    if (content.length >= 2 && content.codeUnitAt(1) == 0x3a) {
      final body = content.substring(2);
      switch (content.codeUnitAt(0)) {
        case 0x6e: // n
          final v = double.tryParse(body);
          return EngineCellInput.value(v == null ? FText(body) : FNumber(v));
        case 0x73: // s
          return EngineCellInput.value(FText(body));
        case 0x62: // b
          return EngineCellInput.value(
            FBool(body == '1' || body.toLowerCase() == 'true'),
          );
        case 0x65: // e
          final k = ErrorKind.fromLiteral(body);
          return EngineCellInput.value(k == null ? FText(body) : FError(k));
        case 0x72: // r: rich text JSON {"t": "...", "runs": [...]}
          return EngineCellInput.value(FText(_richPlainText(body)));
      }
    }
    return EngineCellInput.value(FText(content));
  }

  static String _richPlainText(String json) {
    final m = RegExp(r'"t"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(json);
    if (m == null) return '';
    return m.group(1)!.replaceAllMapped(RegExp(r'\\(u[0-9a-fA-F]{4}|.)'), (x) {
      final e = x.group(1)!;
      if (e.startsWith('u') && e.length == 5) {
        return String.fromCharCode(int.parse(e.substring(1), radix: 16));
      }
      return switch (e) {
        'n' => '\n',
        't' => '\t',
        'r' => '\r',
        _ => e,
      };
    });
  }

  /// Inverse of [fromContent] for literal values and formulas.
  String toContent() {
    if (formula != null) return '=$formula';
    return switch (value) {
      FNumber(:final v) => 'n:$v',
      FText(:final v) => 's:$v',
      FBool(:final v) => v ? 'b:1' : 'b:0',
      FError(:final kind) => 'e:${kind.literal}',
      _ => '',
    };
  }

  @override
  String toString() => formula != null
      ? 'EngineCellInput(=$formula)'
      : 'EngineCellInput(${value.debugText})';
}

/// Ordered ids of one axis (rows or columns) of a sheet (02 §6 `AxisIndex`).
abstract interface class AxisView {
  /// Number of rows/columns.
  int get length;

  /// Id at the current [index] (0-based).
  String idAt(int index);

  /// Current index of [id], or -1 when the row/column does not exist (deleted).
  int indexOf(String id);

  /// The fractional-index sort key at [index].
  String sortKeyAt(int index);

  /// Number of entries ordered before `(sortKey, id)` in the axis order (sort key, then id).
  /// Used to place deleted range endpoints (05 §5.4).
  int lowerBound(String sortKey, String id);

  /// Whether the row/column at [index] is hidden by the user or a collapsed group.
  bool isHidden(int index);
}

/// One grid sheet as seen by the engine.
abstract interface class SheetView {
  String get id;

  /// Current display name.
  String get name;

  AxisView get rows;
  AxisView get columns;

  /// Content of the cell at current indices, or null when empty.
  EngineCellInput? inputAt(int row, int col);

  /// Visits the non-empty cells inside [rect] (clamped to the grid) in row-major order.
  void forEachInput(
    GridRect rect,
    void Function(int row, int col, EngineCellInput input) visit,
  );

  /// Number of rows up to the last row with content (0 when empty).
  int get usedRowCount;

  /// Number of columns up to the last column with content.
  int get usedColumnCount;

  /// Explicit number format pattern (or `preset:*` id) of the cell, null = Automatic.
  String? numberFormatAt(int row, int col);

  /// Whether the row is hidden by the basic filter or a slicer (not filter views).
  bool isRowFilterHidden(int row);

  /// Column width in pixels at 100 % zoom (for `CELL("width")`).
  double columnWidthAt(int col);
}

/// An id-based range (`GridRange` JSON of 02 §2 plus the `K` sort-key hints of 05 §24 F1).
final class IdRange {
  final String sheetId;
  final String? rowStart;
  final String? rowEnd;
  final String? colStart;
  final String? colEnd;
  final String? rowStartKey;
  final String? rowEndKey;
  final String? colStartKey;
  final String? colEndKey;

  const IdRange(
    this.sheetId, {
    this.rowStart,
    this.rowEnd,
    this.colStart,
    this.colEnd,
    this.rowStartKey,
    this.rowEndKey,
    this.colStartKey,
    this.colEndKey,
  });

  /// From the GridRange JSON map `{"s","r1","r2","c1","c2","r1k","r2k","c1k","c2k"}`.
  factory IdRange.fromJson(Map<String, Object?> json) => IdRange(
    json['s'] as String,
    rowStart: json['r1'] as String?,
    rowEnd: json['r2'] as String?,
    colStart: json['c1'] as String?,
    colEnd: json['c2'] as String?,
    rowStartKey: json['r1k'] as String?,
    rowEndKey: json['r2k'] as String?,
    colStartKey: json['c1k'] as String?,
    colEndKey: json['c2k'] as String?,
  );

  Map<String, Object?> toJson() => {
    's': sheetId,
    'r1': ?rowStart,
    'r2': ?rowEnd,
    'c1': ?colStart,
    'c2': ?colEnd,
    'r1k': ?rowStartKey,
    'r2k': ?rowEndKey,
    'c1k': ?colStartKey,
    'c2k': ?colEndKey,
  };

  @override
  bool operator ==(Object other) =>
      other is IdRange &&
      other.sheetId == sheetId &&
      other.rowStart == rowStart &&
      other.rowEnd == rowEnd &&
      other.colStart == colStart &&
      other.colEnd == colEnd;

  @override
  int get hashCode => Object.hash(sheetId, rowStart, rowEnd, colStart, colEnd);
}

/// A named range or named function (02 §3.4 `NamedRange`).
abstract interface class NamedRangeView {
  String get id;
  String get name;

  /// Target range (named ranges), or null for named functions/formulas.
  IdRange? get range;

  /// Stored-form formula (named functions: `=LAMBDA(…)`), or null.
  String? get formula;

  /// `NamedRange.comment` (description).
  String? get comment;

  /// `NamedRange.metaJson` (05 §24 F3).
  String? get metaJson;
}

/// Recalculation mode (02 §3.1 `Spreadsheet.recalcMode`).
enum RecalcMode { onChange, onChangeAndEveryMinute, onChangeAndEveryHour }

/// Calculation-relevant spreadsheet settings.
final class CalcSettings {
  final String locale;
  final String timeZone;
  final RecalcMode recalcMode;
  final bool iterativeCalc;
  final int maxIterations;
  final double convergenceThreshold;

  /// Display language of function names and booleans in A1 text (null =
  /// English; `Spreadsheet.displayLanguage`). Never affects results.
  final String? displayLanguage;

  const CalcSettings({
    this.locale = 'en_US',
    this.timeZone = 'UTC',
    this.recalcMode = RecalcMode.onChange,
    this.iterativeCalc = false,
    this.maxIterations = 50,
    this.convergenceThreshold = 0.05,
    this.displayLanguage,
  });

  CalcSettings copyWith({
    String? locale,
    String? timeZone,
    RecalcMode? recalcMode,
    bool? iterativeCalc,
    int? maxIterations,
    double? convergenceThreshold,
    String? displayLanguage,
  }) => CalcSettings(
    locale: locale ?? this.locale,
    timeZone: timeZone ?? this.timeZone,
    recalcMode: recalcMode ?? this.recalcMode,
    iterativeCalc: iterativeCalc ?? this.iterativeCalc,
    maxIterations: maxIterations ?? this.maxIterations,
    convergenceThreshold: convergenceThreshold ?? this.convergenceThreshold,
    displayLanguage: displayLanguage ?? this.displayLanguage,
  );

  @override
  bool operator ==(Object other) =>
      other is CalcSettings &&
      other.locale == locale &&
      other.timeZone == timeZone &&
      other.recalcMode == recalcMode &&
      other.iterativeCalc == iterativeCalc &&
      other.maxIterations == maxIterations &&
      other.convergenceThreshold == convergenceThreshold &&
      other.displayLanguage == displayLanguage;

  @override
  int get hashCode => Object.hash(
    locale,
    timeZone,
    recalcMode,
    iterativeCalc,
    maxIterations,
    convergenceThreshold,
    displayLanguage,
  );
}

/// The workbook interface the engine reads (05 §2.1 `WorkbookView`). Implemented by the
/// workbook model (client), the server's headless workbook and [MemoryWorkbook] (tests).
abstract interface class WorkbookView {
  /// Spreadsheet (space) id; part of the RAND seed.
  String get spreadsheetId;

  /// Grid sheets in tab order.
  List<SheetView> get sheets;

  SheetView? sheetById(String id);

  /// Case-insensitive lookup by display name.
  SheetView? sheetByName(String name);

  /// All named ranges and named functions.
  Iterable<NamedRangeView> get namedRanges;

  CalcSettings get settings;
}

/// Read interface over **computed** cell values (13 §4.2) used by charts, exporters, CF/DV and
/// pivots. [FormulaEngine] implements it; models may wrap it.
abstract interface class CellSource {
  /// Computed value at current indices: literal values, formula results, spill overlay values.
  FValue valueAt(String sheetId, int row, int col);

  /// Explicit number format of the cell, or the formula result's format hint pattern.
  String? numberFormatAt(String sheetId, int row, int col);

  /// Whether the row/column is hidden (user, group or, when [includeFilter], filter).
  bool isHidden(
    String sheetId,
    GridDimension dimension,
    int index, {
    bool includeFilter = true,
  });
}
