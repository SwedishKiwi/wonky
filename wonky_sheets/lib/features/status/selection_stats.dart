import 'dart:math' as math;

import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// The aggregates of the selection stats button (04 §7).
enum SelectionStat { sum, average, min, max, count, countNumbers }

/// Aggregates of the current selection.
class SelectionStats {
  const SelectionStats({
    required this.sum,
    required this.min,
    required this.max,
    required this.count,
    required this.countNumbers,
    this.numberFormat,
  });

  static const empty = SelectionStats(
    sum: 0,
    min: 0,
    max: 0,
    count: 0,
    countNumbers: 0,
  );

  final double sum;
  final double min;
  final double max;

  /// Non-empty cells.
  final int count;
  final int countNumbers;

  /// The shared number format of the numbers (null when mixed).
  final String? numberFormat;

  double get average => countNumbers == 0 ? 0 : sum / countNumbers;

  double valueOf(SelectionStat s) => switch (s) {
    SelectionStat.sum => sum,
    SelectionStat.average => average,
    SelectionStat.min => min,
    SelectionStat.max => max,
    SelectionStat.count => count.toDouble(),
    SelectionStat.countNumbers => countNumbers.toDouble(),
  };

  /// The default shown aggregate: Sum with numbers, else Count.
  SelectionStat get defaultStat =>
      countNumbers > 0 ? SelectionStat.sum : SelectionStat.count;

  /// Computes the stats of [ed]'s selection (stored cells only; at most
  /// [cap] cells are visited).
  static SelectionStats of(SheetEditorController ed, {int cap = 5000000}) {
    final sheet = ed.activeSheet;
    if (sheet == null) return empty;
    final grid = sheet.gridRect;
    if (grid == null) return empty;
    var sum = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;
    var count = 0;
    var numbers = 0;
    var visited = 0;
    String? format;
    var mixed = false;
    final seen = <(int, int)>{};
    for (final range in ed.selection.resolved.ranges) {
      final rect = range.rect.intersection(grid);
      if (rect == null) continue;
      for (final (r, c, _) in sheet.cellsIn(rect, contentOnly: true)) {
        if (++visited > cap) break;
        if (ed.selection.resolved.ranges.length > 1 && !seen.add((r, c))) {
          continue;
        }
        final v = ed.engine.valueAt(sheet.id, r, c).toCellValue();
        if (v.isBlank()) continue;
        count++;
        if (v is NumberValue) {
          numbers++;
          sum += v.number;
          min = math.min(min, v.number);
          max = math.max(max, v.number);
          final f = ed.cells.displayAt(sheet.id, r, c)?.numberFormat;
          if (format == null && !mixed) {
            format = f;
          } else if (f != format) {
            mixed = true;
          }
        }
      }
    }
    return SelectionStats(
      sum: sum,
      min: numbers == 0 ? 0 : min,
      max: numbers == 0 ? 0 : max,
      count: count,
      countNumbers: numbers,
      numberFormat: mixed ? null : format,
    );
  }
}

/// Whether the selection is more than one cell (the button is hidden for a
/// single cell).
bool selectionIsMulti(SheetEditorController ed) {
  final r = ed.selection.resolved;
  if (r.ranges.length > 1) return true;
  final rect = r.ranges.first.rect;
  final m = ed.activeSheet?.mergeAt(rect.top, rect.left);
  return rect.cellCount > 1 && rect != m;
}

/// A cell rectangle helper for tests.
GridRect statsRect(int r1, int c1, int r2, int c2) => GridRect(r1, c1, r2, c2);
