import 'package:flutter/widgets.dart' show IconData;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect, ColumnLetters;
import 'package:wonky_sheets_core/model.dart';

import '../features/cell_editor/cell_editor_controller.dart';
import '../features/data_tools/data_job.dart';
import 'sheets_command.dart';
import 'sort_commands.dart' show applyKeepingSelection, looksLikeHeader;

String _data(SheetsLocalizations l) => l.categoryData;

/// Commands of 04 §3.4–3.6 / §9 backed by existing planner operations:
/// sort, randomize, trim, checkboxes, insert function, named ranges.
List<Command<CommandArgs>> dataCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.data.sortSheet',
    label: (l) => l.cmdDataSortSheet,
    icon: LucideIcons.arrowDownAZ,
    categoryName: _data,
    mutates: true,
    dynamicLabel: (l, ed) => l.cmdDataSortSheetBy(
      ColumnLetters.fromIndex(ed.selection.resolved.activeCol),
    ),
    argsSchema: const JsonSchema.object(
      properties: {
        'colId': JsonSchema.string(),
        'ascending': JsonSchema.boolean(),
        'freezeHeader': JsonSchema.boolean(
          description: 'Freeze row 1 first and sort below it (07 §2.6).',
        ),
      },
    ),
    run: (ctx, ed, a) async {
      final sheet = ed.activeSheet!;
      final colId =
          a.string('colId') ??
          sheet.columns.idAt(ed.selection.resolved.activeCol);
      final asc = a.boolean('ascending') ?? true;
      final freeze = a.boolean('freezeHeader') ?? false;
      if (freeze && (sheet.record?.frozenRows ?? 0) == 0) {
        ed.apply(ctx, SetFrozen(sheet.id, rows: 1));
      }
      final fr = sheet.record?.frozenRows ?? 0;
      final used = sheet.usedRect(includeFormatOnly: true);
      if (used == null || used.bottom < fr) {
        return const CommandResult.cancelled();
      }
      final rect = GridRect(fr, 0, used.bottom, sheet.columns.length - 1);
      // Row 1 looks like a header but isn't frozen: offer to fix (07 §2.6).
      final header = fr == 0 && rect.rowCount > 2 && looksLikeHeader(ed, rect);
      final op = SortRange(ResolvedRange(sheet.id, rect, wholeRows: true), [
        SortKeySpec(colId, ascending: asc),
      ]);
      await DataJobs.run(
        ed,
        rows: rect.rowCount,
        label: ed.l10n.dataJobSorting(rect.rowCount),
        op: op,
        work: () => applyKeepingSelection(ctx, ed, op),
      );
      if (header && ctx.source != InvocationSource.mcp) {
        final l = ed.l10n;
        ed.services.toasts.show(
          l.sortHeaderToastTitle,
          description: l.sortHeaderToastBody,
          actionLabel: l.sortHeaderToastAction,
          onAction: () async {
            // Undo this sort, then freeze + sort again as one step.
            final undo = ed.services.undo;
            if (!undo.canUndo.value) return;
            await undo.undo();
            await ed.invokeCommand('sheets.data.sortSheet', {
              'colId': colId,
              'ascending': asc,
              'freezeHeader': true,
            });
          },
        );
      }
      return ok({'headerSuggested': header});
    },
  ),
  SheetsCommand(
    'sheets.data.sortRange',
    label: (l) => l.cmdDataSortRange,
    icon: LucideIcons.arrowDownAZ,
    categoryName: _data,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'range': JsonSchema.string(),
        'colId': JsonSchema.string(),
        'ascending': JsonSchema.boolean(),
        'hasHeader': JsonSchema.boolean(),
        // 07 §2.1: multi-key sorts (`[{colId, ascending}]`, P2 colors).
        'specs': JsonSchema.array(
          JsonSchema.object(additionalProperties: true),
        ),
      },
    ),
    enabled: (ed, a) =>
        a.string('range') != null ||
        ed.selection.resolved.ranges.length == 1 &&
            ed.selection.resolved.activeRange.rect.rowCount > 1,
    run: (ctx, ed, a) async {
      final range = rangeArg(ed, a);
      final sheet = ed.model.sheet(range.sheetId)!;
      final colId =
          a.string('colId') ??
          sheet.columns.idAt(ed.selection.resolved.activeCol);
      final specs = a.values['specs'];
      final op = SortRange(
        range,
        specs is List && specs.isNotEmpty
            ? [
                for (final e in specs)
                  if (e is Map && e['colId'] is String)
                    SortKeySpec(
                      e['colId'] as String,
                      ascending: e['ascending'] != false,
                      fillColor: e['fillColor'] as String?,
                      textColor: e['textColor'] as String?,
                    ),
              ]
            : [SortKeySpec(colId, ascending: a.boolean('ascending') ?? true)],
        hasHeader: a.boolean('hasHeader') ?? false,
      );
      await DataJobs.run(
        ed,
        rows: range.rect.rowCount,
        label: ed.l10n.dataJobSorting(range.rect.rowCount),
        op: op,
        work: () => applyKeepingSelection(ctx, ed, op),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.data.randomizeRange',
    label: (l) => l.cmdDataRandomizeRange,
    icon: LucideIcons.shuffle,
    categoryName: _data,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {'range': JsonSchema.string()},
    ),
    enabled: (ed, a) => ed.selection.resolved.ranges.length == 1,
    run: (ctx, ed, a) async {
      final range = rangeArg(ed, a);
      final op = RandomizeRange(range);
      await DataJobs.run(
        ed,
        rows: range.rect.rowCount,
        label: ed.l10n.dataJobRandomizing(range.rect.rowCount),
        op: op,
        work: () => applyKeepingSelection(ctx, ed, op),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.cleanup.trimWhitespace',
    label: (l) => l.cmdCleanupTrimWhitespace,
    categoryName: _data,
    mutates: true,
    argsSchema: Schemas.ranges,
    run: (ctx, ed, a) async {
      final ranges = rangesArg(ed, a);
      final rows = ranges.fold<int>(0, (n, r) => n + r.rect.rowCount);
      final plan = await DataJobs.run(
        ed,
        rows: rows,
        label: ed.l10n.dataJobTrimming(rows),
        work: () => ed.apply(ctx, TrimWhitespace(ranges)),
      );
      final n = plan.result['cells'] ?? plan.result['trimmed'] ?? 0;
      s.toasts.show(ed.l10n.toastTrimmed(n is int ? n : 0));
      return ok();
    },
  ),
  // Checkboxes and dropdowns: dv_commands.dart.
  SheetsCommand(
    'sheets.insert.function',
    label: (l) => l.cmdInsertFunction,
    icon: LucideIcons.sigma,
    categoryName: (l) => l.categoryInsert,
    argsSchema: const JsonSchema.object(
      properties: {'name': JsonSchema.string()},
      required: ['name'],
    ),
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      final name = a.requireString('name').toUpperCase();
      final sel = ed.selection.resolved;
      // Σ on a single cell suggests the numbers above it (Google behavior).
      var arg = '';
      if (sel.isSingleCell && sel.activeRow > 0) {
        final sheet = ed.activeSheet!;
        var top = sel.activeRow - 1;
        if (sheet.cellAt(top, sel.activeCol)?.content != null) {
          while (top > 0 &&
              sheet.cellAt(top - 1, sel.activeCol)?.content != null) {
            top--;
          }
          arg = GridRect(
            top,
            sel.activeCol,
            sel.activeRow - 1,
            sel.activeCol,
          ).a1;
        }
      } else if (!sel.isSingleCell) {
        arg = sel.activeRange.rect.a1;
      }
      final text = '=$name($arg';
      if (ed.editor.isEditing) {
        ed.editor.appendTyped('$name(');
      } else {
        ed.editor.begin(initialText: text, mode: EditMode.enter);
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.namedRanges.createFromSelection',
    label: (l) => l.cmdNamedRangesCreateFromSelection,
    categoryName: _data,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {'name': JsonSchema.string()},
      required: ['name'],
    ),
    run: (ctx, ed, a) {
      final name = a.requireString('name').trim();
      ed.apply(ctx, AddNamedRange(name, range: ed.activeRange));
      s.toasts.show(ed.l10n.toastNamedRangeCreated(name));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.edit.undoHistory',
    label: (l) => l.cmdEditUndoHistory,
    categoryName: (l) => l.categoryEditing,
    showInPalette: false,
    enabled: (ed, a) => s.undo.canUndo.value,
    run: (ctx, ed, a) => s.dispatcher.invoke(
      'shell.edit.undoHistory',
      source: ctx.source,
      context: ctx.buildContext,
    ),
  ),
];

/// Placeholder commands of features that are not built yet (charts, pivots,
/// conditional formatting, data validation, filters, scripts, import/export,
/// comments panels, history …). They appear in menus disabled; the feature
/// that implements one replaces its registration with a real handler.
List<Command<CommandArgs>> placeholderCommands(ShellServices s) => [
  for (final (id, label, icon, mutates)
      in <(String, SheetsText, IconData?, bool)>[
        ('sheets.drawing.insert', (l) => l.cmdDrawingInsert, null, true),
        (
          'sheets.insert.emoji',
          (l) => l.cmdInsertEmoji,
          LucideIcons.smile,
          true,
        ),
        (
          'sheets.help.functionList',
          (l) => l.cmdHelpFunctionList,
          LucideIcons.squareFunction,
          false,
        ),
        (
          'sheets.format.convertToTable',
          (l) => l.cmdFormatConvertToTable,
          null,
          true,
        ),
        ('sheets.data.extraction', (l) => l.cmdDataExtraction, null, true),
        ('sheets.tools.spellCheck', (l) => l.cmdToolsSpellCheck, null, true),
        (
          'sheets.tools.personalDictionary',
          (l) => l.cmdToolsPersonalDictionary,
          null,
          false,
        ),
        (
          'sheets.tools.toggleFormulaSuggestions',
          (l) => l.cmdToolsToggleFormulaSuggestions,
          null,
          false,
        ),
        (
          'sheets.notifications.openSettings',
          (l) => l.cmdNotificationsOpenSettings,
          null,
          false,
        ),
        (
          'sheets.notifications.openRules',
          (l) => l.cmdNotificationsOpenRules,
          null,
          false,
        ),
        ('sheets.sheet.copyToNew', (l) => l.cmdSheetCopyToNew, null, false),
        (
          'sheets.sheet.copyToExisting',
          (l) => l.cmdSheetCopyToExisting,
          null,
          false,
        ),
        (
          'sheets.sheet.setRightToLeft',
          (l) => l.cmdSheetSetRightToLeft,
          null,
          true,
        ),
        (
          'sheets.structure.openDeleteDialog',
          (l) => l.cmdStructureOpenDeleteDialog,
          null,
          true,
        ),
      ])
    SheetsCommand.placeholder(id, label: label, icon: icon, mutates: mutates),
];
