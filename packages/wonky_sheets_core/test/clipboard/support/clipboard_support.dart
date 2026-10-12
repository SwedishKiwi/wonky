import 'dart:io';

import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

/// Formula hooks for tests where stored formulas are plain A1 text: `toA1`
/// and `toStored` are the identity; the other operations are no-ops.
final class IdentityFormulaHooks implements FormulaHooks {
  const IdentityFormulaHooks();

  @override
  String toStored(String a1Formula, {required String sheetId, required int row, required int col, String locale = 'en_US'}) =>
      a1Formula;

  @override
  String toA1(String stored, {required String sheetId, required int row, required int col, String locale = 'en_US'}) =>
      stored;

  @override
  String translate(
    String stored, {
    required String fromSheetId,
    required int fromRow,
    required int fromCol,
    required String toSheetId,
    required int toRow,
    required int toCol,
  }) => stored;

  @override
  String? repairBoundaries(String stored, {required Set<String> deletedRowIds, required Set<String> deletedColIds}) =>
      null;

  @override
  String? remap(
    String stored, {
    required String hostSheetId,
    required String sourceSheetId,
    required GridRect source,
    required String destSheetId,
    required GridRect dest,
  }) => null;

  @override
  String? repinRows(
    String stored, {
    required String hostSheetId,
    required String sheetId,
    required int blockTop,
    required int blockBottom,
    required String Function(int position) newRowIdAt,
    required int Function(String rowId) oldIndexOf,
  }) => null;

  @override
  String renameName(String stored, String oldName, String newName) => stored;

  @override
  bool references(String stored, {required String hostSheetId, required String sheetId, required GridRect rect}) =>
      false;

  @override
  FValue evaluateRelative(
    String stored, {
    required String sheetId,
    required int anchorRow,
    required int anchorCol,
    required int row,
    required int col,
  }) => FEmpty.instance;
}

/// Adds a merge over [a1] (e.g. `B2:C3`) on the current sheet of [b].
void addMerge(WorkbookBuilder b, String sheet, String a1, {String? id}) {
  final area = A1Area.tryParse(a1)!;
  final sid = b.sheetId(sheet);
  b.row(SheetsTables.mergedRange, id ?? 'merge-$sheet-$a1', {
    Cols.sheetId: sid,
    Cols.rangeJson: GridRange(
      sheetId: sid,
      r1: b.rowId(area.row1!, sheet: sheet),
      r2: b.rowId(area.row2!, sheet: sheet),
      c1: b.colId(area.col1!, sheet: sheet),
      c2: b.colId(area.col2!, sheet: sheet),
    ).encode(),
  });
}

/// A [ModelCellSource] whose formula cells evaluate to [values] (by A1 on the
/// first sheet).
ModelCellSource sourceWith(WorkbookModel m, [Map<String, Object> values = const {}]) {
  final byPos = <(int, int), FValue>{};
  values.forEach((a1, v) {
    final a = A1Area.tryParse(a1)!;
    byPos[(a.row1!, a.col1!)] = switch (v) {
      final num n => FNumber(n.toDouble()),
      final bool b => FBool(b),
      _ => FText(v.toString()),
    };
  });
  return ModelCellSource(m, computed: (s, r, c) => byPos[(r, c)]);
}

/// Reads a fixture from `test/fixtures/<area>/<name>`.
String readFixture(String area, String name) =>
    File('test/fixtures/$area/$name').readAsStringSync();
