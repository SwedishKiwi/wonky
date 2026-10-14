import 'package:wonky_app/wonky_app.dart' show CommandContext;
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../grid/selection/grid_selection.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// Editing in a sorted filter view (07 §4.4): the rows on screen are a
/// display order over the model rows, so pasting and filling write to the
/// model rows shown, in display order — one model range per run of rows
/// that are adjacent in both orders, all in one undo step.
abstract final class ViewSortEditing {
  /// Whether display rows [d1]..[d2] of [ed]'s active sheet touch a sorted
  /// block.
  static bool _touches(ViewRowOrder o, int d1, int d2) =>
      d2 >= o.top && d1 <= o.bottom;

  /// Pastes [source] at the selection in display order, or returns null
  /// when no sorted view is involved (paste as usual).
  static MutationPlan? paste(
    CommandContext ctx,
    SheetEditorController ed,
    PasteSource source,
    PasteMode mode,
  ) {
    final o = ed.rowOrder;
    final s = ed.activeSheet;
    if (o == null || s == null || source.cells.isEmpty) return null;
    final sel = ed.selection.resolved;
    final shown = sel.activeRange.displayRect;
    final target = sel.activeRange.rect;
    final dTop = shown?.top ?? o.displayRow(target.top);
    final left = shown?.left ?? target.left;
    final n = source.cells.length;
    final width = source.cells.fold<int>(
      0,
      (w, r) => r.length > w ? r.length : w,
    );
    // A selection taller than the source and a multiple of it tiles it.
    final selRows = shown?.rowCount ?? target.rowCount;
    final rows = selRows > n && selRows % n == 0 ? selRows : n;
    final dBottom = (dTop + rows - 1).clamp(dTop, s.rows.length - 1);
    if (!_touches(o, dTop, dBottom)) return null;
    if (source.isCut) {
      throw PlanException(
        'invalid_argument',
        ed.l10n.viewSortCutPasteUnavailable,
      );
    }
    MutationPlan? last;
    var offset = 0;
    for (final (mt, mb) in o.modelRuns(dTop, dBottom)) {
      final k = mb - mt + 1;
      final idx = source.sourceRowIndices;
      final part = PasteSource(
        cells: [for (var i = 0; i < k; i++) source.cells[(offset + i) % n]],
        spreadsheetId: source.spreadsheetId,
        sheetId: source.sheetId,
        sourceRow: idx == null
            ? source.sourceRow + offset % n
            : idx[offset % n],
        sourceCol: source.sourceCol,
        columnWidths: source.columnWidths,
        internal: source.internal,
        sourceRowIndices: [
          for (var i = 0; i < k; i++)
            idx == null
                ? source.sourceRow + (offset + i) % n
                : idx[(offset + i) % n],
        ],
        sourceColIndices: source.sourceColIndices,
      );
      last = ed.apply(
        ctx,
        PasteClipboard(
          ResolvedRange(s.id, GridRect(mt, left, mb, left + width - 1)),
          part,
          mode: mode,
        ),
      );
      offset += k;
    }
    // The pasted rows stay selected, on screen.
    ed.selection.selectCell(o.modelRow(dTop), left);
    ed.selection.extendTo(o.modelRow(dBottom), left + width - 1);
    return last;
  }

  /// Fill down (Mod+D) of a range selected on screen in a sorted view: the
  /// top row on screen is copied to the rows below it on screen. Returns
  /// false when no sorted view is involved.
  static bool fillDown(CommandContext ctx, SheetEditorController ed) {
    final o = ed.rowOrder;
    final sel = ed.selection.resolved;
    final shown = sel.activeRange.displayRect;
    if (o == null || shown == null || sel.activeGroup.length < 2) {
      return false;
    }
    final sid = ed.activeSheetId;
    final top = o.modelRow(shown.top);
    final source = ed.clipboard.sourceOf(
      GridRect(top, shown.left, top, shown.right),
    );
    for (final r in sel.activeGroup) {
      for (final (mt, mb) in _without(r.rect.top, r.rect.bottom, top)) {
        ed.apply(
          ctx,
          PasteClipboard(
            ResolvedRange(sid, GridRect(mt, shown.left, mb, shown.right)),
            source,
          ),
        );
      }
    }
    return true;
  }

  /// [a]..[b] without row [x], as runs.
  static List<(int, int)> _without(int a, int b, int x) => [
    if (x < a || x > b)
      (a, b)
    else ...[
      if (x > a) (a, x - 1),
      if (x < b) (x + 1, b),
    ],
  ];

  /// Whether [sel] is one range on screen made of several model ranges.
  static bool isDisplayGroup(ResolvedSelection sel) =>
      sel.ranges.length > 1 &&
      sel.isSingleGroup &&
      sel.activeRange.displayRect != null;
}
