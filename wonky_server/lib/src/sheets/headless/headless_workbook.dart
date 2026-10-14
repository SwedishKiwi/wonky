import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput;

/// A server-side, in-memory workbook of one spreadsheet space (Sheets 12
/// §2.1): the shared core [WorkbookModel] plus a lazily evaluating formula
/// engine bound to it ([ModelEngineBinding]). Built by
/// `HeadlessWorkbookProvider` from the synced tables and patched in place
/// after merges and tool writes.
class HeadlessWorkbook {
  HeadlessWorkbook({
    required this.space,
    required this.model,
    required this.watermark,
    required this.estimatedBytes,
  }) : binding = ModelEngineBinding.create(model),
       loadedAt = clock.now(),
       lastUsed = clock.now(),
       lastChecked = clock.now();

  /// The spreadsheet (space) uuid.
  final UuidValue space;

  final WorkbookModel model;
  final ModelEngineBinding binding;

  /// The oldest transaction id that may not have been visible when the
  /// model was last loaded or patched (`txid_snapshot_xmin`): tuples whose
  /// `xmin` is at or after it are re-read by the next patch.
  int watermark;

  /// Rough memory footprint (cache budget).
  int estimatedBytes;

  final DateTime loadedAt;
  DateTime lastUsed;

  /// When the model was last brought up to date with the database.
  DateTime lastChecked;

  /// Set by merge signals: the next open patches first.
  bool stale = false;

  /// Number of incremental patches applied (tests, diagnostics).
  int patches = 0;

  FormulaEngine get engine => binding.engine;

  /// The spreadsheet locale (display and input parsing).
  String get locale => model.spreadsheet.locale;

  /// Formula codec hooks over the engine (planner, A1 ⇄ stored).
  late final EngineFormulaHooks hooks = EngineFormulaHooks(
    model,
    engine: engine,
    view: binding.view,
  );

  /// Display text formatting in the spreadsheet locale.
  FormatterDisplayText get display => FormatterDisplayText(locale: locale);

  /// Computed values (formula results evaluated on demand).
  CellSource get values => engine;

  /// The computed value of a cell as a model [CellValue].
  CellValue valueAt(String sheetId, int row, int col) =>
      engine.valueAt(sheetId, row, col).toCellValue();

  /// The number format of a cell (explicit, or the result's format hint).
  String? numberFormatAt(String sheetId, int row, int col) =>
      engine.numberFormatAt(sheetId, row, col);

  /// The display text of a cell as the app shows it.
  String displayAt(String sheetId, int row, int col) => display.displayText(
    valueAt(sheetId, row, col),
    numberFormatAt(sheetId, row, col),
  );

  /// The A1 formula (English syntax, with `=`) of a formula cell, or null.
  String? formulaAt(String sheetId, int row, int col) {
    final content = model.cellAt(sheetId, row, col)?.decoded;
    if (content is! FormulaContent) return null;
    return hooks.toA1(
      content.text,
      sheetId: sheetId,
      row: row,
      col: col,
      locale: 'en_US',
    );
  }

  /// Applies row changes (tool write-through or a patch).
  void apply(Iterable<RowChange> changes) {
    model.applyChanges(changes);
    lastUsed = clock.now();
  }

  /// Releases the engine binding.
  void dispose() {
    binding.dispose();
    engine.dispose();
  }

  /// Estimates the memory of a workbook from its row counts (≈120 bytes
  /// per cell, 200 per other row, 2 KB per formula AST budgeted as 10 %).
  static int estimate(Map<String, int> counts) {
    var bytes = 64 * 1024;
    counts.forEach((table, n) {
      bytes += table == SheetsTables.cell ? n * 160 : n * 200;
    });
    return bytes;
  }
}
