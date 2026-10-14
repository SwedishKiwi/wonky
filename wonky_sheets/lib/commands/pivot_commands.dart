import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/pivot/pivot_controller.dart';
import '../features/pivot/pivot_overlay_service.dart';
import '../features/pivot/pivot_ranges.dart';
import '../features/pivot/pivot_selection_group.dart';
import '../features/pivot/pivot_spec_edit.dart' show PivotSpecEdit;
import '../features/pivot/ui/create_pivot_dialog.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

SheetsText get _cat =>
    (l) => l.categoryData;

const _pivotId = JsonSchema.string(
  description: 'Pivot table id (default: the pivot at the active cell).',
);

/// Drill-downs above this many rows ask first (07 §7.9).
const int drillDownConfirmRows = 100000;

PivotOutput? _pivotOf(SheetEditorController ed, JsonArgs a) =>
    PivotController.of(ed).resolve(a.string('pivotId'));

CommandResult _noPivot(SheetEditorController ed) =>
    CommandResult.failed(ed.l10n.reasonNoPivot);

bool _hasPivot(SheetEditorController ed, JsonArgs a) =>
    PivotController.of(ed).resolve(a.string('pivotId')) != null;

/// The pivot table commands (07 §7.12).
List<Command<CommandArgs>> pivotCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.insert.pivotTable',
    label: (l) => l.cmdInsertPivotTable,
    icon: LucideIcons.table2,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'range': JsonSchema.string(
          description:
              'Source range with its header row, e.g. Sheet1!A1:F500 '
              '(default: the data region of the selection).',
        ),
        'destination': JsonSchema.string(
          enumValues: ['newSheet', 'existingSheet'],
          description: 'Where to put the pivot (default newSheet).',
        ),
        'location': JsonSchema.string(
          description: 'Anchor cell for existingSheet, e.g. Sheet2!H1.',
        ),
      },
    ),
    run: (ctx, ed, a) async {
      var range = a.string('range');
      var destination = PivotDestination.byId(a.string('destination'));
      var location = a.string('location') ?? '';
      final c = ctx.dialogContext;
      if (range == null && c != null) {
        final r = ed.selection.resolved;
        final region = ed.activeRange.rect.isSingleCell
            ? ed.edgeFinder().region(r.activeRow, r.activeCol)
            : ed.activeRange.rect;
        final initial = region == null
            ? ''
            : rangeToA1(ed.model, ResolvedRange(ed.activeSheetId, region));
        final choice = await showCreatePivotDialog(
          c,
          model: ed.model,
          contextSheetId: ed.activeSheetId,
          range: initial,
        );
        if (choice == null) return const CommandResult.cancelled();
        range = choice.range;
        destination = choice.destination;
        location = choice.location;
      }
      final ResolvedRange source;
      if (range == null || range.trim().isEmpty) {
        final r = ed.selection.resolved;
        final region = ed.activeRange.rect.isSingleCell
            ? ed.edgeFinder().region(r.activeRow, r.activeCol)
            : ed.activeRange.rect;
        if (region == null) {
          return CommandResult.failed(ed.l10n.pivotNoData);
        }
        source = ResolvedRange(ed.activeSheetId, region);
      } else {
        source = ed.model.parseA1(range, contextSheetId: ed.activeSheetId);
      }
      final spec = const PivotSpec().encode();
      final String sheetId;
      final int row;
      final int col;
      if (destination == PivotDestination.existingSheet &&
          location.isNotEmpty) {
        final at = ed.model.parseA1(location, contextSheetId: ed.activeSheetId);
        sheetId = at.sheetId;
        row = at.rect.top;
        col = at.rect.left;
      } else if (destination == PivotDestination.existingSheet) {
        final r = ed.selection.resolved;
        sheetId = ed.activeSheetId;
        row = r.activeRow;
        col = r.activeCol;
      } else {
        final all = ed.model.sheets;
        final i = all.indexWhere((x) => x.id == source.sheetId);
        final plan = await ed.applyConfirmed(
          ctx,
          AddSheet(
            name: nextSheetName(ed.model, ed.l10n.pivotSheetPrefix),
            index: i < 0 ? null : i + 1,
          ),
        );
        sheetId = plan.result['sheetId']! as String;
        row = 0;
        col = 0;
      }
      final plan = await ed.applyConfirmed(
        ctx,
        AddPivotTable(sheetId, row, col, source, spec),
      );
      final id = plan.result['pivotId']! as String;
      if (sheetId != ed.activeSheetId) ed.activateSheet(sheetId);
      ed.selection.selectCell(row, col);
      ed.revealCell(row, col);
      PivotController.of(ed).openEditor(id);
      return ok({
        'pivotId': id,
        'sheet': ed.model.sheet(sheetId)?.name,
        'anchor': GridRect.cell(row, col).a1,
      });
    },
  ),
  SheetsCommand(
    'sheets.pivot.openEditor',
    label: (l) => l.cmdPivotOpenEditor,
    icon: LucideIcons.pencil,
    categoryName: _cat,
    argsSchema: const JsonSchema.object(properties: {'pivotId': _pivotId}),
    enabled: _hasPivot,
    run: (ctx, ed, a) {
      final o = _pivotOf(ed, a);
      if (o == null) return _noPivot(ed);
      PivotController.of(ed).openEditor(o.id);
      return ok({'pivotId': o.id});
    },
  ),
  SheetsCommand(
    'sheets.pivot.update',
    label: (l) => l.cmdPivotUpdate,
    icon: LucideIcons.table2,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'pivotId': _pivotId,
        'spec': JsonSchema.any(
          description: 'The PivotSpec v1 (07 §7.1) as an object or JSON text.',
        ),
        'sourceRange': JsonSchema.string(
          description: 'New source range with its header row (A1).',
        ),
      },
    ),
    enabled: _hasPivot,
    run: (ctx, ed, a) {
      final o = _pivotOf(ed, a);
      if (o == null) return _noPivot(ed);
      final raw = a.values['spec'];
      String? specJson;
      if (raw != null) {
        final spec = PivotSpec.parse(raw is String ? raw : jsonEncode(raw));
        specJson = spec.encode();
        if (specJson == PivotSpec.parse(o.record.specJson).encode()) {
          specJson = null;
        }
      }
      final rangeText = a.string('sourceRange');
      ResolvedRange? source;
      if (rangeText != null && rangeText.trim().isNotEmpty) {
        source = ed.model.parseA1(rangeText, contextSheetId: ed.activeSheetId);
        if (source == o.source) source = null;
      }
      if (specJson == null && source == null) return ok({'pivotId': o.id});
      ed.apply(ctx, UpdatePivotTable(o.id, specJson: specJson, source: source));
      return ok({'pivotId': o.id});
    },
  ),
  SheetsCommand(
    'sheets.pivot.delete',
    label: (l) => l.cmdPivotDelete,
    icon: LucideIcons.trash2,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(properties: {'pivotId': _pivotId}),
    enabled: _hasPivot,
    run: (ctx, ed, a) {
      final o = _pivotOf(ed, a);
      if (o == null) return _noPivot(ed);
      ed.apply(ctx, DeletePivotTable(o.id));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.pivot.refresh',
    label: (l) => l.cmdPivotRefresh,
    icon: LucideIcons.refreshCw,
    categoryName: _cat,
    argsSchema: const JsonSchema.object(properties: {'pivotId': _pivotId}),
    enabled: _hasPivot,
    run: (ctx, ed, a) {
      final o = _pivotOf(ed, a);
      if (o == null) return _noPivot(ed);
      PivotController.of(ed).service.refresh(o.id);
      return ok({'pivotId': o.id});
    },
  ),
  SheetsCommand(
    'sheets.pivot.expandGrid',
    label: (l) => l.cmdPivotExpandGrid,
    icon: LucideIcons.rows3,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(properties: {'pivotId': _pivotId}),
    enabled: (ed, a) {
      final o = PivotController.of(ed).resolve(a.string('pivotId'));
      return o != null && (o.missingRows > 0 || o.missingColumns > 0);
    },
    run: (ctx, ed, a) {
      final o = _pivotOf(ed, a);
      if (o == null) return _noPivot(ed);
      final sheet = ed.model.sheet(o.sheetId);
      if (sheet == null) return _noPivot(ed);
      if (o.missingRows > 0) {
        ed.apply(
          ctx,
          InsertDimension(
            o.sheetId,
            Dimension.rows,
            sheet.rows.length,
            o.missingRows,
          ),
        );
      }
      if (o.missingColumns > 0) {
        ed.apply(
          ctx,
          InsertDimension(
            o.sheetId,
            Dimension.columns,
            sheet.columns.length,
            o.missingColumns,
          ),
        );
      }
      return ok({'pivotId': o.id});
    },
  ),
  SheetsCommand(
    'sheets.pivot.drillDown',
    label: (l) => l.cmdPivotDrillDown,
    icon: LucideIcons.tableProperties,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'pivotId': _pivotId,
        'cell': JsonSchema.string(
          description: 'A value cell of the pivot output (default: active).',
        ),
      },
    ),
    enabled: (ed, a) {
      final o = PivotController.of(ed).resolve(a.string('pivotId'));
      if (o == null) return false;
      if (a.string('cell') != null) return true;
      final r = ed.selection.resolved;
      return o.cellAt(r.activeRow, r.activeCol)?.isValue ?? false;
    },
    run: (ctx, ed, a) async {
      final o = _pivotOf(ed, a);
      if (o == null) return _noPivot(ed);
      final cellText = a.string('cell');
      final int row;
      final int col;
      if (cellText != null) {
        final rr = ed.model.parseA1(cellText, contextSheetId: o.sheetId);
        row = rr.rect.top;
        col = rr.rect.left;
      } else {
        final r = ed.selection.resolved;
        row = r.activeRow;
        col = r.activeCol;
      }
      final ref = o.cellAt(row, col)?.ref;
      final result = o.result;
      if (ref == null || result == null) {
        return CommandResult.failed(ed.l10n.pivotNotAValueCell);
      }
      final table = result.drillDownTable(ref.row, ref.column);
      final count = table.length - 1;
      final c = ctx.dialogContext;
      if (count > drillDownConfirmRows && c != null) {
        final go = await confirmDialog(
          c,
          title: ed.l10n.pivotDrillDownConfirmTitle(count),
          description: ed.l10n.pivotDrillDownConfirmBody,
          confirmLabel: ed.l10n.cmdPivotDrillDown,
        );
        if (!go) return const CommandResult.cancelled();
      }
      final all = ed.model.sheets;
      final i = all.indexWhere((x) => x.id == o.sheetId);
      final width = table.first.length;
      final plan = await ed.applyConfirmed(
        ctx,
        AddSheet(
          name: nextSheetName(ed.model, ed.l10n.pivotDetailsSheetPrefix),
          index: i < 0 ? null : i + 1,
          rows: table.length + 1 > 1000 ? table.length + 1 : 1000,
          columns: width > 26 ? width : 26,
        ),
      );
      final sheetId = plan.result['sheetId']! as String;
      await ed.applyConfirmed(
        ctx,
        SetCellInputs(
          sheetId: sheetId,
          row: 0,
          col: 0,
          inputs: [
            for (final r in table) [for (final v in r) CellInput.raw(v)],
          ],
          label: ed.l10n.cmdPivotDrillDown,
        ),
      );
      // Number formats of the source columns (values only, formats copied).
      final cols = result.source.columns;
      for (var k = 0; k < cols.length; k++) {
        final f = cols[k].numberFormat;
        if (f == null || count == 0) continue;
        await ed.applyConfirmed(
          ctx,
          SetFormat(
            [ResolvedRange(sheetId, GridRect(1, k, count, k))],
            {FormatAttr.numberFormat: f},
          ),
        );
      }
      await ed.applyConfirmed(
        ctx,
        SetFormat(
          [ResolvedRange(sheetId, GridRect(0, 0, 0, width - 1))],
          {FormatAttr.bold: true},
        ),
      );
      ed.activateSheet(sheetId);
      ed.selection.selectCell(0, 0);
      // The details sheet has no pivot: the editor panel closes.
      final pivots = PivotController.of(ed);
      if (ed.services.panels.isOpen(PivotController.panelId)) {
        ed.services.panels.close(PivotController.panelId);
      }
      pivots.editing.value = null;
      return ok({'sheet': ed.model.sheet(sheetId)?.name, 'rows': count});
    },
  ),
  pivotGroupSelectionCommand(),
  SheetsCommand(
    'sheets.pivot.createGroup',
    label: (l) => l.cmdPivotCreateGroup,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'pivotId': _pivotId,
        'field': JsonSchema.string(
          description: 'Source column id or header of a Rows/Columns field.',
        ),
        'group': JsonSchema.any(
          description:
              'Grouping: {"kind":"date","unit":"yearMonth"}, '
              '{"kind":"histogram","size":10,"min":0,"max":100}, '
              '{"kind":"manual","groups":[{"name":"East","items":["NY"]}]} '
              'or null to remove.',
        ),
      },
      required: ['field'],
    ),
    enabled: _hasPivot,
    run: (ctx, ed, a) {
      final o = _pivotOf(ed, a);
      if (o == null) return _noPivot(ed);
      final field = a.requireString('field');
      var colId = field;
      final src = o.result?.source;
      if (src != null && src.column(field) == null) {
        final match = src.columns.where(
          (c) => c.header.toLowerCase() == field.toLowerCase(),
        );
        if (match.isNotEmpty) colId = match.first.colId;
      }
      final rawGroup = a.values['group'];
      final group = rawGroup == null ? null : PivotGrouping.tryParse(rawGroup);
      if (rawGroup != null && group == null) {
        return CommandResult.failed(ed.l10n.pivotInvalidGroup);
      }
      final (spec, found) = PivotSpec.parse(
        o.record.specJson,
      ).withGrouping(colId, group);
      if (!found) return CommandResult.failed(ed.l10n.pivotFieldNotInRows);
      ed.apply(ctx, UpdatePivotTable(o.id, specJson: spec.encode()));
      return ok({'pivotId': o.id});
    },
  ),
];

/// The pivot labels selected on the grid, with their pivot.
(PivotOutput, PivotLabelSelection)? _selectedLabels(SheetEditorController ed) {
  final o = PivotController.maybeOf(ed)?.activeOutput;
  if (o == null) return null;
  final display = FormatterDisplayText(locale: ed.locale);
  final sel = pivotLabelSelection(o, [
    for (final r in ed.selectedRanges) r.rect,
  ], display.displayText);
  return sel == null ? null : (o, sel);
}

/// `sheets.pivot.groupSelection` (07 §7.3): selected row/column labels of a
/// pivot become a named manual group (one step).
SheetsCommand pivotGroupSelectionCommand() => SheetsCommand(
  'sheets.pivot.groupSelection',
  label: (l) => l.cmdPivotGroupSelection,
  icon: LucideIcons.group,
  categoryName: _cat,
  mutates: true,
  argsSchema: const JsonSchema.object(
    properties: {
      'name': JsonSchema.string(
        description: 'Name of the new group (default: asked, "Group N").',
      ),
    },
  ),
  enabled: (ed, a) => _selectedLabels(ed) != null,
  run: (ctx, ed, a) async {
    final hit = _selectedLabels(ed);
    if (hit == null) {
      return CommandResult.failed(ed.l10n.pivotSelectLabels);
    }
    final (o, sel) = hit;
    final spec = PivotSpec.parse(o.record.specJson);
    final field = [
      ...spec.rows,
      ...spec.columns,
    ].firstWhere((g) => g.source == sel.colId);
    var name = a.string('name');
    if (name == null) {
      final c = ctx.dialogContext;
      if (c == null || !c.mounted) return const CommandResult.cancelled();
      final l = ed.l10n;
      name = await showTextInputDialog(
        c,
        title: l.cmdPivotGroupSelection,
        label: l.pivotGroupName,
        confirmLabel: l.pivotGroupCreate,
        initial: nextGroupName(field.group, l.pivotGroupPrefix),
        dialogKey: 'dialog.pivotGroupName',
        validator: (t) => t.trim().isEmpty ? l.pivotGroupNameEmpty : null,
      );
      if (name == null) return const CommandResult.cancelled();
    }
    final grouping = groupLabels(field.group, name.trim(), sel.items);
    final (next, found) = spec.withGrouping(sel.colId, grouping);
    if (!found) return CommandResult.failed(ed.l10n.pivotFieldNotInRows);
    await ed.applyConfirmed(
      ctx,
      UpdatePivotTable(o.id, specJson: next.encode()),
    );
    return ok({'pivotId': o.id, 'group': name.trim(), 'items': sel.items});
  },
);

/// Builds the args of `sheets.pivot.update` for [spec].
Map<String, Object?> pivotUpdateArgs(String pivotId, PivotSpec spec) => {
  'pivotId': pivotId,
  'spec': spec.toJson(),
};

/// Invokes `sheets.pivot.update` from the editor panel.
Future<bool> updatePivotSpec(
  SheetEditorController ed,
  String pivotId,
  PivotSpec spec,
) => ed.invokeCommand('sheets.pivot.update', pivotUpdateArgs(pivotId, spec));
