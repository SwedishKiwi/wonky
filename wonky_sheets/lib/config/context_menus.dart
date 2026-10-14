import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart' show CellWidgetKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../features/dialogs/sheets_dialogs.dart' show PasteSpecialMode;
import '../features/grid/grid_area.dart' show GridMenuKind;
import '../features/pivot/pivot_controller.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import '../features/toolbar/command_ui.dart';

const _cm = InvocationSource.contextMenu;

List<WonkyMenuEntry> _clipboard(CommandUi ui) => [
  ui.item('sheets.edit.cut', source: _cm),
  ui.item('sheets.edit.copy', source: _cm),
  ui.item('sheets.edit.paste', source: _cm),
  WonkyMenuSubmenu(
    label: ui.l.menuPasteSpecial,
    children: [
      for (final m in PasteSpecialMode.values)
        ui.item(
          'sheets.edit.pasteSpecial',
          args: {'mode': m.id},
          label: m.label(ui.l),
          keyName: 'context.pasteSpecial.${m.id}',
          source: _cm,
        ),
    ],
  ),
];

/// The context menus of the grid (04 §9), built from command ids.
List<WonkyMenuEntry> gridContextMenu(
  CommandUi ui,
  SheetEditorController ed,
  GridMenuKind kind,
) {
  final l = ui.l;
  switch (kind) {
    case GridMenuKind.cell:
      final d = ed.activeDisplay();
      final pivot = PivotController.maybeOf(ed)?.activeOutput;
      return [
        if (pivot != null) ...[
          ui.item('sheets.pivot.openEditor', source: _cm),
          ui.item('sheets.pivot.refresh', source: _cm),
          if (pivot.cellAt(
                ed.selection.resolved.activeRow,
                ed.selection.resolved.activeCol,
              )?.isValue ??
              false)
            ui.item('sheets.pivot.drillDown', source: _cm),
          if (ui.state('sheets.pivot.groupSelection').enabled)
            ui.item('sheets.pivot.groupSelection', source: _cm),
          ui.item('sheets.pivot.delete', source: _cm),
          const WonkyMenuSeparator(),
        ],
        // In-cell image (08 §10.2).
        if (ui.state('sheets.image.placeOverCells').enabled) ...[
          ui.item('sheets.image.placeOverCells', source: _cm),
          const WonkyMenuSeparator(),
        ],
        if (d?.linkUrl != null) ...[
          ui.item('sheets.link.open', source: _cm),
          ui.item(
            'sheets.insert.link',
            label: l.contextEditLink,
            keyName: 'context.editLink',
            source: _cm,
          ),
          ui.item('sheets.link.remove', source: _cm),
          const WonkyMenuSeparator(),
        ],
        if (d?.widget.kind == CellWidgetKind.dropdownChip ||
            d?.widget.kind == CellWidgetKind.dropdownArrow) ...[
          ui.item(
            'sheets.dv.openPanel',
            label: l.contextEditDropdown,
            keyName: 'context.editDropdown',
            source: _cm,
          ),
          const WonkyMenuSeparator(),
        ],
        ..._clipboard(ui),
        const WonkyMenuSeparator(),
        ui.item('sheets.rows.insertAbove', source: _cm),
        ui.item('sheets.cols.insertLeft', source: _cm),
        WonkyMenuSubmenu(
          label: l.contextInsertCells,
          children: [
            ui.item('sheets.cells.insertShiftRight', source: _cm),
            ui.item('sheets.cells.insertShiftDown', source: _cm),
          ],
        ),
        ui.item('sheets.rows.delete', source: _cm),
        ui.item('sheets.cols.delete', source: _cm),
        WonkyMenuSubmenu(
          label: l.contextDeleteCells,
          children: [
            ui.item('sheets.cells.deleteShiftLeft', source: _cm),
            ui.item('sheets.cells.deleteShiftUp', source: _cm),
          ],
        ),
        const WonkyMenuSeparator(),
        ui.item('sheets.filter.toggle', source: _cm),
        ui.item('sheets.filter.byCellValue', source: _cm),
        const WonkyMenuSeparator(),
        ui.item('sheets.cf.openPanel', source: _cm),
        ui.item('sheets.dv.openPanel', source: _cm),
        const WonkyMenuSeparator(),
        WonkyMenuSubmenu(
          label: l.contextMoreCellActions,
          children: [
            ui.item('shell.comments.create', source: _cm),
            ui.item('sheets.notes.insert', source: _cm),
            ui.item('sheets.insert.link', source: _cm),
            ui.item('sheets.insert.smartChip', source: _cm),
            ui.item('sheets.ai.explainFormula', source: _cm),
            ui.item('sheets.protect.openPanel', source: _cm),
            ui.item('sheets.namedRanges.openPanel', source: _cm),
            ui.item('sheets.cell.copyLink', source: _cm),
            ui.item('sheets.data.randomizeRange', source: _cm),
            ui.item('sheets.history.showCellHistory', source: _cm),
            ui.item('sheets.notes.clear', source: _cm),
          ],
        ),
      ];
    case GridMenuKind.rowHeader:
      final row = ed.selection.resolved.activeRow;
      return [
        ..._clipboard(ui),
        const WonkyMenuSeparator(),
        ui.item('sheets.rows.insertAbove', source: _cm),
        ui.item('sheets.rows.insertBelow', source: _cm),
        ui.item('sheets.rows.delete', source: _cm),
        ui.item('sheets.edit.clearAll', source: _cm),
        ui.item('sheets.rows.hide', source: _cm),
        ui.item('sheets.rows.openResizeDialog', source: _cm),
        const WonkyMenuSeparator(),
        ui.item('sheets.group.groupRows', source: _cm),
        ui.item('sheets.group.ungroupRows', source: _cm),
        ui.item('sheets.filter.toggle', source: _cm),
        ui.item('sheets.cf.openPanel', source: _cm),
        ui.item('sheets.dv.openPanel', source: _cm),
        const WonkyMenuSeparator(),
        WonkyMenuSubmenu(
          label: l.contextMoreRowActions,
          children: [
            ui.item(
              'sheets.view.freezeRows',
              args: {'count': row + 1},
              label: l.freezeUpToRow(row + 1),
              keyName: 'context.freezeUpToRow',
              source: _cm,
            ),
            ui.item('sheets.rows.moveUp', source: _cm),
            ui.item('sheets.rows.moveDown', source: _cm),
            ui.item('sheets.cell.copyLink', source: _cm),
            ui.item('sheets.namedRanges.openPanel', source: _cm),
            ui.item('sheets.protect.openPanel', source: _cm),
            ui.item('sheets.rows.autoFit', source: _cm),
          ],
        ),
      ];
    case GridMenuKind.columnHeader:
      final col = ed.selection.resolved.activeCol;
      return [
        ..._clipboard(ui),
        const WonkyMenuSeparator(),
        ui.item('sheets.cols.insertLeft', source: _cm),
        ui.item('sheets.cols.insertRight', source: _cm),
        ui.item('sheets.cols.delete', source: _cm),
        ui.item('sheets.edit.clearAll', source: _cm),
        ui.item('sheets.cols.hide', source: _cm),
        ui.item('sheets.cols.openResizeDialog', source: _cm),
        const WonkyMenuSeparator(),
        ui.item('sheets.filter.toggle', source: _cm),
        ui.item(
          'sheets.data.sortSheet',
          args: {'ascending': true},
          label: l.sortSheetAtoZ,
          keyName: 'context.sortSheet.asc',
          source: _cm,
        ),
        ui.item(
          'sheets.data.sortSheet',
          args: {'ascending': false},
          label: l.sortSheetZtoA,
          keyName: 'context.sortSheet.desc',
          source: _cm,
        ),
        const WonkyMenuSeparator(),
        ui.item('sheets.cf.openPanel', source: _cm),
        ui.item('sheets.dv.openPanel', source: _cm),
        ui.item('sheets.data.columnStats', source: _cm),
        ui.item('sheets.insert.dropdown', source: _cm),
        ui.item('sheets.insert.smartChip', source: _cm),
        const WonkyMenuSeparator(),
        WonkyMenuSubmenu(
          label: l.contextMoreColumnActions,
          children: [
            ui.item(
              'sheets.view.freezeColumns',
              args: {'count': col + 1},
              label: l.freezeUpToColumn(ed.columnLabel(col)),
              keyName: 'context.freezeUpToColumn',
              source: _cm,
            ),
            ui.item('sheets.group.groupColumns', source: _cm),
            ui.item('sheets.group.ungroupColumns', source: _cm),
            ui.item('sheets.cols.moveLeft', source: _cm),
            ui.item('sheets.cols.moveRight', source: _cm),
            ui.item('sheets.data.randomizeRange', source: _cm),
            ui.item('sheets.cell.copyLink', source: _cm),
            ui.item('sheets.namedRanges.openPanel', source: _cm),
            ui.item('sheets.protect.openPanel', source: _cm),
            ui.item('sheets.cols.autoFit', source: _cm),
          ],
        ),
      ];
    case GridMenuKind.corner:
      return [
        ui.item('sheets.edit.paste', source: _cm),
        WonkyMenuSubmenu(
          label: l.menuPasteSpecial,
          children: [
            for (final m in PasteSpecialMode.values)
              ui.item(
                'sheets.edit.pasteSpecial',
                args: {'mode': m.id},
                label: m.label(l),
                keyName: 'context.corner.pasteSpecial.${m.id}',
                source: _cm,
              ),
          ],
        ),
        ui.item('sheets.format.clear', source: _cm),
        ui.item(
          'sheets.cols.autoFit',
          label: l.contextFitAllColumns,
          keyName: 'context.fitAllColumns',
          source: _cm,
        ),
        ui.item(
          'sheets.rows.unhide',
          label: l.contextUnhideAllRows,
          keyName: 'context.unhideRows',
          source: _cm,
        ),
        ui.item(
          'sheets.cols.unhide',
          label: l.contextUnhideAllColumns,
          keyName: 'context.unhideCols',
          source: _cm,
        ),
      ];
  }
}
