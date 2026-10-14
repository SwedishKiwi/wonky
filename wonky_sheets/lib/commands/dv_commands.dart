import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show CellPos, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/data_validation/dv_controller.dart';
import '../features/data_validation/dv_draft.dart';
import '../features/data_validation/dv_panel_state.dart';
import '../features/in_cell/in_cell_controller.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _data(SheetsLocalizations l) => l.categoryData;

/// Data validation (07 §6.8, 03 §14.1–14.2): panel, rules, checkboxes and
/// dropdowns. Mutations are one undo step each.
List<Command<CommandArgs>> dvCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.dv.openPanel',
    label: (l) => l.cmdDvOpenPanel,
    icon: LucideIcons.listChecks,
    categoryName: _data,
    argsSchema: const JsonSchema.object(
      properties: {
        'ruleId': JsonSchema.string(description: 'Edit this rule.'),
        'range': JsonSchema.string(description: 'New rule for this range.'),
        'list': JsonSchema.boolean(description: 'Show the rule list.'),
      },
    ),
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      final panel = DvPanelState.of(ed);
      final ruleId = a.string('ruleId');
      final range = a.string('range');
      if (ruleId != null) {
        final sheet = _sheetOfRule(ed, ruleId);
        if (sheet == null || !panel.edit(sheet.id, ruleId)) {
          return const CommandResult.failed('Unknown rule');
        }
      } else if (a.boolean('list') ?? false) {
        panel.close();
      } else if (range != null) {
        panel.startNew(rangesText: range);
      } else {
        // The rule of the active cell, else a new rule for the selection.
        final sel = ed.selection.resolved;
        final rule = DataValidationController.of(
          ed,
        ).ruleAt(ed.activeSheetId, sel.activeRow, sel.activeCol);
        if (rule == null || !panel.edit(ed.activeSheetId, rule.id)) {
          panel.startNew();
        }
      }
      s.panels.open(dvPanelId);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.dv.saveRule',
    label: (l) => l.cmdDvSaveRule,
    icon: LucideIcons.listChecks,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'ruleId': JsonSchema.string(description: 'Rule to update.'),
        'ranges': JsonSchema.array(
          JsonSchema.string(),
          description: 'A1 ranges on one sheet.',
        ),
        'criteria': JsonSchema.any(
          description:
              'criteriaJson (07 §6.1): {"type": "oneOfList", "options": '
              '[{"value": "Open", "bg": "#D4EDBC", "fg": "#11734B"}]}, '
              '{"type": "checkbox"}, {"type": "numberBetween", "values": '
              '[{"v": "1"}, {"v": "10"}]} …',
        ),
        'strict': JsonSchema.boolean(description: 'Reject invalid input.'),
        'displayStyle': JsonSchema.string(
          enumValues: ['chip', 'arrow', 'plainText'],
        ),
        'helpText': JsonSchema.string(),
      },
      required: ['criteria'],
    ),
    run: (ctx, ed, a) {
      final raw = a.values['criteria'];
      final criteria = DvCriteria.tryParse(raw);
      if (criteria == null) {
        return const CommandResult.failed('Invalid criteria');
      }
      final ranges = rangesArg(ed, a);
      if (ranges.isEmpty) return const CommandResult.failed('No range');
      final sheetId = ranges.first.sheetId;
      if (ranges.any((r) => r.sheetId != sheetId)) {
        return const CommandResult.failed(
          'A rule\'s ranges must be on one sheet',
        );
      }
      final grid = ed.model.sheet(sheetId)?.gridRect;
      final rects = [
        for (final r in ranges)
          if (grid == null) r.rect else (r.rect.intersection(grid) ?? r.rect),
      ];
      final ruleId = a.string('ruleId');
      final plan = ed.apply(
        ctx,
        SetDataValidation(
          sheetId,
          rects,
          raw is String ? raw : jsonEncode(raw),
          strict: a.boolean('strict') ?? false,
          displayStyle: a.string('displayStyle'),
          helpText: _blankToNull(a.string('helpText')),
          ruleId: ruleId,
        ),
      );
      if (plan.warnings.isNotEmpty) s.toasts.show(ed.l10n.dvCapped);
      return ok({'ruleId': plan.result['ruleId']});
    },
  ),
  SheetsCommand(
    'sheets.dv.deleteRule',
    label: (l) => l.cmdDvDeleteRule,
    icon: LucideIcons.trash2,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'ruleId': JsonSchema.string()},
      required: ['ruleId'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('ruleId');
      if (_sheetOfRule(ed, id) == null) {
        return const CommandResult.failed('Unknown rule');
      }
      ed.apply(ctx, DeleteDvRule(id));
      final panel = DvPanelState.of(ed);
      if (panel.draft?.ruleId == id) panel.close();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.dv.clearRange',
    label: (l) => l.cmdDvClearRange,
    icon: LucideIcons.listX,
    categoryName: _data,
    mutates: true,
    argsSchema: Schemas.object({'range': const JsonSchema.string()}),
    run: (ctx, ed, a) {
      final ranges = rangesArg(ed, a);
      final bySheet = <String, List<GridRect>>{};
      for (final r in ranges) {
        final grid = ed.model.sheet(r.sheetId)?.gridRect;
        bySheet
            .putIfAbsent(r.sheetId, () => [])
            .add(grid == null ? r.rect : (r.rect.intersection(grid) ?? r.rect));
      }
      for (final MapEntry(key: sid, value: rects) in bySheet.entries) {
        if (ed.model.sheet(sid)?.dvRules.isEmpty ?? true) continue;
        ed.apply(ctx, SetDataValidation(sid, rects, null));
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.dv.toggleCheckbox',
    label: (l) => l.cmdDvToggleCheckbox,
    icon: LucideIcons.squareCheck,
    categoryName: _data,
    mutates: true,
    defaultBindings: const [KeyBinding(Keys.space)],
    argsSchema: const JsonSchema.object(
      properties: {
        'cells': JsonSchema.array(
          JsonSchema.string(),
          description: 'A1 cells/ranges (default: the selection).',
        ),
      },
    ),
    enabled: (ed, a) =>
        a.strings('cells').isNotEmpty ||
        DataValidationController.of(ed).evaluator.checkboxAt(
              ed.activeSheetId,
              ed.selection.resolved.activeRow,
              ed.selection.resolved.activeCol,
            ) !=
            null,
    run: (ctx, ed, a) => _toggleCheckboxes(ctx, ed, a),
  ),
  SheetsCommand(
    'sheets.dv.openDropdown',
    label: (l) => l.cmdDvOpenDropdown,
    icon: LucideIcons.squareChevronDown,
    categoryName: _data,
    defaultBindings: const [KeyBinding(Keys.arrowDown, alt: true)],
    enabled: (ed, a) {
      final sel = ed.selection.resolved;
      return InCellController.of(
            ed,
          ).popupKindAt(ed.activeSheetId, sel.activeRow, sel.activeCol) !=
          null;
    },
    run: (ctx, ed, a) {
      if (!ed.canEdit) return const CommandResult.cancelled();
      final sel = ed.selection.resolved;
      final opened = InCellController.of(
        ed,
      ).openDropdown(ed.activeSheetId, sel.activeRow, sel.activeCol);
      return opened ? ok() : const CommandResult.cancelled();
    },
  ),
  SheetsCommand(
    'sheets.insert.dropdown',
    label: (l) => l.cmdInsertDropdown,
    icon: LucideIcons.squareChevronDown,
    categoryName: (l) => l.categoryInsert,
    mutates: true,
    argsSchema: Schemas.object({
      'fromValues': const JsonSchema.boolean(
        description:
            'Build the items from the distinct values of the selection '
            '(Convert to dropdown).',
      ),
    }),
    run: (ctx, ed, a) {
      final ranges = rangesArg(ed, a);
      final sheetId = ranges.first.sheetId;
      final sheet = ed.model.sheet(sheetId)!;
      final grid = sheet.gridRect!;
      final rects = [
        for (final r in ranges)
          if (r.sheetId == sheetId) r.rect.intersection(grid) ?? r.rect,
      ];
      final List<DvOption> options;
      if (a.boolean('fromValues') ?? false) {
        final values = _distinctValues(ed, sheetId, rects, limit: 500);
        if (values == null) {
          s.toasts.show(ed.l10n.dvTooManyValues);
          return const CommandResult.cancelled();
        }
        options = [
          for (var i = 0; i < values.length; i++)
            DvOption(values[i], colors: DvChipPalette.at(i)),
        ];
      } else {
        options = const [];
      }
      final plan = ed.apply(
        ctx,
        SetDataValidation(
          sheetId,
          rects,
          DvListCriteria(options).encode(),
          displayStyle: 'chip',
        ),
      );
      final ruleId = plan.result['ruleId'] as String?;
      if (ruleId != null && ctx.source != InvocationSource.mcp) {
        final panel = DvPanelState.of(ed);
        if (panel.edit(sheetId, ruleId, focusFirstItem: true) &&
            options.isEmpty) {
          panel.draft = panel.draft!.copyWith(
            options: const [DvOptionDraft(''), DvOptionDraft('')],
          );
        }
        s.panels.open(dvPanelId);
      }
      return ok({'ruleId': ruleId});
    },
  ),
  SheetsCommand(
    'sheets.insert.checkbox',
    label: (l) => l.cmdInsertCheckbox,
    icon: LucideIcons.squareCheck,
    categoryName: (l) => l.categoryInsert,
    mutates: true,
    argsSchema: Schemas.object({
      'checked': const JsonSchema.string(description: 'Custom checked value.'),
      'unchecked': const JsonSchema.string(
        description: 'Custom unchecked value.',
      ),
    }),
    run: (ctx, ed, a) {
      final ranges = rangesArg(ed, a);
      final sheetId = ranges.first.sheetId;
      final grid = ed.model.sheet(sheetId)!.gridRect!;
      ed.apply(
        ctx,
        InsertCheckboxes(
          sheetId,
          [
            for (final r in ranges)
              if (r.sheetId == sheetId) r.rect.intersection(grid) ?? r.rect,
          ],
          checked: _blankToNull(a.string('checked')),
          unchecked: _blankToNull(a.string('unchecked')),
        ),
      );
      return ok();
    },
  ),
];

String? _blankToNull(String? s) => s == null || s.isEmpty ? null : s;

SheetModel? _sheetOfRule(SheetEditorController ed, String ruleId) {
  for (final s in ed.model.sheets) {
    if (s.dvRules.containsKey(ruleId)) return s;
  }
  return null;
}

/// Distinct non-empty display values of [rects] in order, or null when
/// there are more than [limit].
List<String>? _distinctValues(
  SheetEditorController ed,
  String sheetId,
  List<GridRect> rects, {
  required int limit,
}) {
  final sheet = ed.model.sheet(sheetId)!;
  final out = <String>{};
  for (final rect in rects) {
    final used = sheet.usedRect();
    final r = used == null ? null : rect.intersection(used);
    if (r == null) continue;
    for (var row = r.top; row <= r.bottom; row++) {
      for (var col = r.left; col <= r.right; col++) {
        final t = ed.cells.displayAt(sheetId, row, col)?.text ?? '';
        if (t.isEmpty) continue;
        out.add(t);
        if (out.length > limit) return null;
      }
    }
  }
  return out.toList();
}

/// Space / click on checkboxes (03 §14.1): if any is unchecked, check all,
/// else uncheck all — one undo step.
CommandResult _toggleCheckboxes(
  CommandContext ctx,
  SheetEditorController ed,
  JsonArgs a,
) {
  final dv = DataValidationController.of(ed);
  final cells = a.strings('cells');
  final ranges = cells.isEmpty
      ? ed.selectedRanges
      : [
          for (final t in cells)
            for (final part in t.split(','))
              if (part.trim().isNotEmpty)
                ed.model.parseA1(part.trim(), contextSheetId: ed.activeSheetId),
        ];
  final boxes = <(String, int, int, CheckboxValues, bool?)>[];
  for (final r in ranges) {
    final sheet = ed.model.sheet(r.sheetId);
    final grid = sheet?.gridRect;
    if (sheet == null || grid == null || sheet.dvRules.isEmpty) continue;
    final rect = r.rect.intersection(grid);
    if (rect == null || rect.cellCount > 100000) continue;
    for (var row = rect.top; row <= rect.bottom; row++) {
      for (var col = rect.left; col <= rect.right; col++) {
        final values = dv.evaluator.checkboxAt(sheet.id, row, col);
        if (values == null) continue;
        final state = values.stateOf(
          dv.evaluator.reader.valueAt(sheet.id, row, col),
        );
        boxes.add((sheet.id, row, col, values, state));
      }
    }
  }
  if (boxes.isEmpty) return const CommandResult.cancelled();
  final check = CheckboxValues.toggleAllTarget([for (final b in boxes) b.$5]);
  // One SetCellInputs per row run of consecutive checkbox cells.
  final byRow = <(String, int), List<(int, CellContent)>>{};
  for (final (sid, row, col, values, _) in boxes) {
    byRow.putIfAbsent((sid, row), () => []).add((
      col,
      check ? values.checked : values.unchecked,
    ));
  }
  for (final MapEntry(key: (sid, row), value: list) in byRow.entries) {
    list.sort((x, y) => x.$1.compareTo(y.$1));
    var start = 0;
    while (start < list.length) {
      var end = start;
      while (end + 1 < list.length && list[end + 1].$1 == list[end].$1 + 1) {
        end++;
      }
      ed.apply(
        ctx,
        SetCellInputs(
          sheetId: sid,
          row: row,
          col: list[start].$1,
          inputs: [
            [for (var i = start; i <= end; i++) ContentCellInput(list[i].$2)],
          ],
        ),
      );
      start = end + 1;
    }
  }
  return ok({
    'checked': check,
    'cells': [for (final b in boxes) CellPos(b.$2, b.$3).a1],
  });
}
