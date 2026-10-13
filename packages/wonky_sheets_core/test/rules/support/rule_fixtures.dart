import 'core.dart';

/// Id-based range JSON for indices [r1]..[r2] × [c1]..[c2] of the current sheet of [b].
GridRange gridRange(
  WorkbookBuilder b,
  String sheetId,
  int r1,
  int c1,
  int r2,
  int c2,
) => GridRange(
  sheetId: sheetId,
  r1: b.rowId(r1),
  r2: b.rowId(r2),
  c1: b.colId(c1),
  c2: b.colId(c2),
);

/// Adds a CF rule row.
void addCfRule(
  WorkbookBuilder b,
  String sheetId,
  String id,
  String sortKey,
  List<GridRange> ranges,
  String ruleJson, {
  bool enabled = true,
}) => b.row(SheetsTables.conditionalFormatRule, id, {
  Cols.sheetId: sheetId,
  Cols.sortKey: sortKey,
  Cols.rangesJson: GridRange.encodeList(ranges),
  'ruleJson': ruleJson,
  'enabled': enabled,
});

/// Adds a DV rule row.
void addDvRule(
  WorkbookBuilder b,
  String sheetId,
  String id,
  List<GridRange> ranges,
  String criteriaJson, {
  bool strict = false,
  String? helpText,
  DateTime? createdAt,
}) => b.row(SheetsTables.dataValidationRule, id, {
  Cols.sheetId: sheetId,
  Cols.rangesJson: GridRange.encodeList(ranges),
  'criteriaJson': criteriaJson,
  'strict': strict,
  'showDropdown': true,
  'helpText': helpText,
  Cols.createdAt: createdAt ?? DateTime.utc(2026),
});

/// Deterministic UUID-like rule id for fixtures (distinct from builder ids).
String fid(int n) =>
    'ffffffff-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';
