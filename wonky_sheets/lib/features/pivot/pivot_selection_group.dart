import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import 'pivot_overlay_service.dart';

/// Row or column item labels selected in a pivot's output (07 §7.3 manual
/// groups): the field's source column and the selected item texts.
typedef PivotLabelSelection = ({String colId, List<String> items});

/// The labels of one Rows/Columns field selected by [rects] in [o], or null
/// when the selection holds no item labels, mixes fields, or the field is
/// grouped by date or histogram. [labelText] formats a label value.
PivotLabelSelection? pivotLabelSelection(
  PivotOutput o,
  List<GridRect> rects,
  String Function(CellValue value, String? numberFormat) labelText,
) {
  final result = o.result;
  final grid = o.grid;
  if (result == null || grid == null || !o.hasOutput) return null;
  final rowFields = result.rowFields;
  final colFields = result.columnFields;
  final fieldRow = colFields.isEmpty ? 0 : 1;
  String? colId;
  final items = <String>[];
  final seen = <String>{};
  for (final r in rects) {
    final i = r.intersection(o.rect);
    if (i == null) continue;
    if (i.cellCount > 5000) return null;
    for (var row = i.top; row <= i.bottom; row++) {
      for (var col = i.left; col <= i.right; col++) {
        final y = row - o.anchorRow;
        final x = col - o.anchorCol;
        final cell = grid.cellAt(y, x);
        if (cell == null || cell.value.isBlank()) continue;
        PivotFieldInfo? field;
        if (cell.role == PivotCellRole.rowLabel && x < rowFields.length) {
          field = rowFields[x];
        } else if (cell.role == PivotCellRole.header &&
            x >= grid.labelColumns &&
            y >= fieldRow &&
            y < fieldRow + colFields.length) {
          field = colFields[y - fieldRow];
        }
        if (field == null) continue;
        final text = labelText(cell.value, cell.numberFormat);
        if (cell.role == PivotCellRole.header &&
            (text == 'Grand Total' || text.endsWith(' Total'))) {
          continue;
        }
        final id = field.spec.source;
        if (colId != null && colId != id) return null;
        colId = id;
        final g = field.spec.group;
        if (g != null && g is! PivotManualGrouping) return null;
        if (seen.add(text.toLowerCase())) items.add(text);
      }
    }
  }
  if (colId == null || items.isEmpty) return null;
  return (colId: colId, items: items);
}

/// The manual grouping of [current] with a new group [name] holding
/// [labels]: labels naming existing groups bring their items along (and
/// those groups go away); the items leave the other groups.
PivotManualGrouping groupLabels(
  PivotGrouping? current,
  String name,
  List<String> labels,
) {
  final existing = current is PivotManualGrouping
      ? current.groups
      : const <PivotManualGroup>[];
  final byName = {for (final g in existing) g.name.toLowerCase(): g};
  final items = <String>[];
  final taken = <String>{};
  final absorbed = <String>{};
  for (final l in labels) {
    final g = byName[l.toLowerCase()];
    final add = g == null ? [l] : g.items;
    if (g != null) absorbed.add(g.name.toLowerCase());
    for (final i in add) {
      if (taken.add(i.toLowerCase())) items.add(i);
    }
  }
  final groups = <PivotManualGroup>[
    for (final g in existing)
      if (!absorbed.contains(g.name.toLowerCase()))
        if ([
              for (final i in g.items)
                if (!taken.contains(i.toLowerCase())) i,
            ]
            case final rest when rest.isNotEmpty)
          PivotManualGroup(g.name, rest),
  ];
  // Replacing a group of the same name.
  groups.removeWhere((g) => g.name.toLowerCase() == name.toLowerCase());
  groups.add(PivotManualGroup(name, items));
  return PivotManualGrouping(
    groups,
    ungrouped: current is PivotManualGrouping ? current.ungrouped : null,
  );
}

/// A default name for a new manual group ("Group 1", "Group 2"…).
String nextGroupName(PivotGrouping? current, String prefix) {
  final names = current is PivotManualGrouping
      ? {for (final g in current.groups) g.name.toLowerCase()}
      : const <String>{};
  for (var n = 1; ; n++) {
    final name = '$prefix $n';
    if (!names.contains(name.toLowerCase())) return name;
  }
}
