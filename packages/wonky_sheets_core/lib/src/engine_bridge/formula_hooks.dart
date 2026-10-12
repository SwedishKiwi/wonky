import '../addressing/grid_geometry.dart';
import '../formula/values/fvalue.dart';

/// The formula services the model-side code (mutation planner, import,
/// clipboard, find & replace, CF/DV/filter evaluation) needs from the formula
/// engine (05 §5 `FormulaCodec` / `ReferenceRewriter`, §7.1 `compileRelative`).
///
/// Model code depends only on this interface; `EngineFormulaHooks` adapts the
/// engine's codec and the app/server inject it. Positions are current
/// zero-based indices of the formula's host cell (or the rule anchor).
///
/// All stored formulas passed in and returned include the leading `=`.
abstract interface class FormulaHooks {
  /// User A1 text (with `=`; [locale] separators) → stored-reference form.
  /// Unparseable formulas are still converted as far as possible (05 §5.3).
  String toStored(
    String a1Formula, {
    required String sheetId,
    required int row,
    required int col,
    String locale = 'en_US',
  });

  /// Stored form → A1 text in [locale]. Missing ids render `#REF!`.
  String toA1(
    String stored, {
    required String sheetId,
    required int row,
    required int col,
    String locale = 'en_US',
  });

  /// Copy/fill/paste: shifts relative parts by the host delta (05 §5.5).
  /// Cross-sheet pastes re-resolve same-sheet refs on [toSheetId].
  String translate(
    String stored, {
    required String fromSheetId,
    required int fromRow,
    required int fromCol,
    required String toSheetId,
    required int toRow,
    required int toCol,
  });

  /// Row/column delete repair (05 §5.4): range endpoints on deleted ids move
  /// inward, single refs become `#REF!`. Returns null when unchanged.
  String? repairBoundaries(
    String stored, {
    required Set<String> deletedRowIds,
    required Set<String> deletedColIds,
  });

  /// Cut/paste, drag-move: references (single cells, and ranges entirely
  /// inside) to [source] on [sourceSheetId] are retargeted to the same
  /// relative cells of [dest] on [destSheetId] (05 §5.5). Null when unchanged.
  String? remap(
    String stored, {
    required String hostSheetId,
    required String sourceSheetId,
    required GridRect source,
    required String destSheetId,
    required GridRect dest,
  });

  /// Full-row sort: references and range endpoints pointing into rows
  /// [block] of [sheetId] are re-pinned to the ids now at the same positions;
  /// [newRowIdAt] maps a position to the row id at it after the sort and
  /// [oldIndexOf] maps a row id to its position before the sort. Null when
  /// unchanged.
  String? repinRows(
    String stored, {
    required String hostSheetId,
    required String sheetId,
    required int blockTop,
    required int blockBottom,
    required String Function(int position) newRowIdAt,
    required int Function(String rowId) oldIndexOf,
  });

  /// Rename of a named range/function (case-insensitive name tokens only).
  String renameName(String stored, String oldName, String newName);

  /// Whether [stored] references (single cell or range) any cell of [rect] on
  /// [sheetId] (used to find dependents without the graph).
  bool references(String stored, {required String hostSheetId, required String sheetId, required GridRect rect});

  /// Evaluates a rule formula (CF/DV/filter custom formula or `=` value)
  /// written relative to ([anchorRow], [anchorCol]) for the cell ([row], [col])
  /// (05 §7.1 `compileRelative`).
  FValue evaluateRelative(
    String stored, {
    required String sheetId,
    required int anchorRow,
    required int anchorCol,
    required int row,
    required int col,
  });
}
