import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/data_tools/data_job.dart';
import '../features/data_tools/sort_dialog.dart';
import '../features/grid/selection/grid_selection.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _data(SheetsLocalizations l) => l.categoryData;

/// The range a sort/cleanup works on (07 §2.1): the active range clipped to
/// the used area, or the data region of a single active cell.
GridRect? dataRangeFor(SheetEditorController ed) {
  final s = ed.activeSheet;
  if (s == null || s.rows.length == 0) return null;
  final sel = ed.selection.resolved;
  final r = sel.activeRange.rect;
  if (r.cellCount > 1) {
    final used = s.usedRect();
    final grid = GridRect(0, 0, s.rows.length - 1, s.columns.length - 1);
    final clipped = r.intersection(grid);
    if (clipped == null) return null;
    if (used == null) return clipped;
    // Whole rows/columns: limit to the used area.
    return GridRect(
      clipped.top,
      clipped.left,
      clipped.bottom > used.bottom && clipped.top <= used.bottom
          ? used.bottom
          : clipped.bottom,
      clipped.right > used.right && clipped.left <= used.right
          ? used.right
          : clipped.right,
    );
  }
  return ed.edgeFinder().region(sel.activeRow, sel.activeCol);
}

/// Applies a row-permuting [op] (sort, randomize) keeping the selection where
/// it was on screen. The selection is stored by row ids, so it would
/// otherwise follow the moved rows (sorting A1:C5 would leave e.g. A1:C3
/// selected).
MutationPlan applyKeepingSelection(
  CommandContext? ctx,
  SheetEditorController ed,
  SheetsOperation op,
) {
  final before = ed.selection.resolved;
  final plan = ed.apply(ctx, op);
  ed.selection.setRanges(
    [for (final x in before.ranges) (x.kind, x.rect)],
    activeIndex: before.activeRangeIndex,
    activeRow: before.activeRow,
    activeCol: before.activeCol,
    anchorRow: before.anchorRow,
    anchorCol: before.anchorCol,
  );
  return plan;
}

/// Whether the first row of [rect] looks like a header (07 §2.6).
bool looksLikeHeader(SheetEditorController ed, GridRect rect) {
  final sid = ed.activeSheetId;
  return HeaderDetector.looksLikeHeader(
    (r, c) => ed.engine.valueAt(sid, r, c).toCellValue(),
    rect,
  );
}

/// Column letters and header texts of [rect]'s columns.
({Map<String, String> letters, Map<String, String> headers}) columnLabels(
  SheetEditorController ed,
  GridRect rect,
) {
  final s = ed.activeSheet!;
  final letters = <String, String>{};
  final headers = <String, String>{};
  for (var c = rect.left; c <= rect.right; c++) {
    final id = s.columns.idAt(c);
    letters[id] = ColumnLetters.fromIndex(c);
    headers[id] = ed.cells.displayAt(s.id, rect.top, c)?.text ?? '';
  }
  return (letters: letters, headers: headers);
}

/// Sort commands beyond the quick sorts in `data_commands.dart` (07 §2).
List<Command<CommandArgs>> sortCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.data.openSortDialog',
    label: (l) => l.cmdDataOpenSortDialog,
    icon: LucideIcons.arrowDownWideNarrow,
    categoryName: _data,
    mutates: true,
    enabled: (ed, a) => ed.selection.resolved.ranges.length == 1,
    run: (ctx, ed, a) async {
      final rect = dataRangeFor(ed);
      if (rect == null || rect.rowCount < 2) {
        return CommandResult.failed(ed.l10n.sortNeedsRows);
      }
      final context = ctx.dialogContext;
      if (context == null) return const CommandResult.cancelled();
      final labels = columnLabels(ed, rect);
      final r = await showSortRangeDialog(
        context,
        rangeA1: rect.a1,
        columns: labels.letters,
        headers: labels.headers,
        hasHeader: looksLikeHeader(ed, rect),
      );
      if (r == null) return const CommandResult.cancelled();
      ed.selection.setRanges([(SelectionKind.cells, rect)]);
      final op = SortRange(ResolvedRange(ed.activeSheetId, rect), [
        for (final k in r.keys) SortKeySpec(k.colId, ascending: k.ascending),
      ], hasHeader: r.hasHeader);
      await DataJobs.run(
        ed,
        rows: rect.rowCount,
        label: ed.l10n.dataJobSorting(rect.rowCount),
        op: op,
        work: () => applyKeepingSelection(ctx, ed, op),
      );
      return ok({
        'range': rect.a1,
        'specs': [for (final k in r.keys) k.toJson()],
      });
    },
  ),
];
