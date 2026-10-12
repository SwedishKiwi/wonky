import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sync_models/ids.dart';

/// Deterministic UUID for entry [i] of namespace [ns].
String testUuid(int ns, int i) =>
    '00000000-0000-4000-8000-${ns.toRadixString(16).padLeft(4, '0')}'
    '${i.toRadixString(16).padLeft(8, '0')}';

/// An axis with one entry per [sizes] element (null = [defaultSize]) and the
/// entries at [hidden] user-hidden.
AxisIndex testAxis(
  List<double?> sizes, {
  double defaultSize = 21,
  Set<int> hidden = const {},
  int ns = 1,
}) {
  final keys = sizes.isEmpty
      ? const <String>[]
      : FractionalIndex.nBetween(null, null, sizes.length);
  return AxisIndex(defaultSize: defaultSize)..load([
    for (var i = 0; i < sizes.length; i++) (testUuid(ns, i), keys[i], sizes[i], hidden.contains(i)),
  ]);
}

/// Inserts [count] rows of [height] px right before row [index] of [sheetId].
void insertRowsBefore(WorkbookModel m, String sheetId, int index, int count, {double? height}) {
  final rows = m.sheet(sheetId)!.rows;
  final before = index == 0 ? null : rows.sortKeyAt(index - 1);
  final after = index >= rows.length ? null : rows.sortKeyAt(index);
  final keys = FractionalIndex.nBetween(before, after, count);
  m.applyChanges([
    for (var i = 0; i < count; i++)
      RowChange.insert(SheetsTables.sheetRow, testUuid(0xbeef, i), {
        Cols.sheetId: sheetId,
        Cols.sortKey: keys[i],
        Cols.hidden: false,
        DimCols.height: ?height,
      }),
  ]);
}

/// Adds an embedded object row with [anchor] to the builder's current sheet.
void addObject(WorkbookBuilder b, String sheetId, String id, String anchorJson, {int zIndex = 0}) =>
    b.row(SheetsTables.embeddedObject, id, {
      Cols.sheetId: sheetId,
      'kind': EmbeddedObjectKind.chart.name,
      'anchorJson': anchorJson,
      'specJson': '{"v":1}',
      'zIndex': zIndex,
    });
