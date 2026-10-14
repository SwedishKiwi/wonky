import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// Commands that work on cells and are disabled while a chart sheet is
/// active (08 §11: a chart sheet has no grid; the formula bar, the toolbar's
/// formatting buttons and grid commands are unavailable there).
abstract final class ChartSheetRules {
  /// Command groups (`sheets.<group>.*`) that need a grid.
  static const gridGroups = {
    'banding',
    'cell',
    'cells',
    'cf',
    'cleanup',
    'cols',
    'columnStats',
    'data',
    'dv',
    'fill',
    'filter',
    'filterView',
    'find',
    'format',
    'formula',
    'formulaBar',
    'group',
    'insert',
    'link',
    'nav',
    'notes',
    'pivot',
    'rows',
    'select',
    'slicer',
    'stats',
    'structure',
  };

  /// Single grid commands of otherwise available groups.
  static const gridCommands = {
    'sheets.edit.copy',
    'sheets.edit.cut',
    'sheets.edit.paste',
    'sheets.edit.pasteSpecial',
    'sheets.edit.pasteSpecialDialog',
    'sheets.edit.clearAll',
    'sheets.edit.clearValues',
    'sheets.edit.repeatLast',
    'sheets.view.freezeRows',
    'sheets.view.freezeColumns',
    'sheets.view.toggleGridlines',
    'sheets.view.toggleFormulas',
    'sheets.view.toggleProtectedRanges',
    'sheets.view.toggleFormulaBar',
    'sheets.image.insertInCell',
    'sheets.image.insertOverCells',
    'sheets.image.placeOverCells',
    'sheets.protect.add',
    'sheets.comments.next',
    'sheets.comments.previous',
    'sheets.chart.insert',
    'sheets.drawing.insert',
  };

  /// Whether [commandId] needs a grid.
  static bool needsGrid(String commandId) {
    if (gridCommands.contains(commandId)) return true;
    if (!commandId.startsWith('sheets.')) return false;
    final rest = commandId.substring(7);
    final dot = rest.indexOf('.');
    if (dot < 0) return false;
    return gridGroups.contains(rest.substring(0, dot));
  }

  /// Whether [ed]'s active sheet is a chart sheet.
  static bool onChartSheet(SheetEditorController ed) =>
      ed.activeSheet?.record?.kind == SheetKind.chart;

  /// Whether [commandId] is disabled on [ed]'s active sheet.
  static bool blocks(SheetEditorController ed, String commandId) =>
      onChartSheet(ed) && needsGrid(commandId);
}
