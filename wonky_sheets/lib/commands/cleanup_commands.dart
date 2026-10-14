import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/data_tools/cleanup_suggestions.dart';
import '../features/data_tools/cleanup_suggestions_panel.dart'
    show cleanupSuggestionsOf;
import '../features/data_tools/data_job.dart';
import '../features/data_tools/data_tools.dart';
import '../features/data_tools/remove_duplicates_dialog.dart';
import '../features/grid/selection/grid_selection.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';
import 'sort_commands.dart' show columnLabels, dataRangeFor, looksLikeHeader;

String _data(SheetsLocalizations l) => l.categoryData;

/// Panel id of column stats (04 §10).
const columnStatsPanelId = 'sheets.panel.columnStats';

/// Panel id of cleanup suggestions (07 §12.3).
const cleanupSuggestionsPanelId = 'sheets.panel.cleanupSuggestions';

/// The single source column of a split (07 §13): a one-column selection, or
/// the active cell's column within its data region.
GridRect? _splitSource(SheetEditorController ed) {
  final s = ed.activeSheet;
  if (s == null) return null;
  final sel = ed.selection.resolved;
  final r = sel.activeRange.rect;
  if (r.colCount != 1) return null;
  if (r.rowCount > 1) {
    final used = s.usedRect();
    final bottom = used == null ? r.bottom : r.bottom.clamp(0, used.bottom);
    return GridRect(r.top, r.left, bottom < r.top ? r.top : bottom, r.left);
  }
  final region = ed.edgeFinder().region(sel.activeRow, sel.activeCol);
  if (region == null) return r;
  return GridRect(region.top, r.left, region.bottom, r.left);
}

/// Data cleanup, split, randomize and column stats commands (07 §12–15).
List<Command<CommandArgs>> cleanupCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.cleanup.openRemoveDuplicates',
    label: (l) => l.cmdCleanupOpenRemoveDuplicates,
    icon: LucideIcons.copyMinus,
    categoryName: _data,
    mutates: true,
    enabled: (ed, a) => ed.selection.resolved.ranges.length == 1,
    run: (ctx, ed, a) async {
      final rect = dataRangeFor(ed);
      if (rect == null) return CommandResult.failed(ed.l10n.dedupeNoData);
      final context = ctx.dialogContext;
      if (context == null) return const CommandResult.cancelled();
      final labels = columnLabels(ed, rect);
      ed.selection.setRanges([(SelectionKind.cells, rect)]);
      final choice = await showRemoveDuplicatesDialog(
        context,
        rangeA1: rect.a1,
        letters: labels.letters,
        headers: labels.headers,
        hasHeader: looksLikeHeader(ed, rect),
      );
      if (choice == null) return const CommandResult.cancelled();
      return s.dispatcher.invoke(
        'sheets.cleanup.removeDuplicates',
        args: {
          'range': rect.a1,
          'hasHeader': choice.hasHeader,
          'colIds': choice.colIds,
        },
        source: ctx.source,
        context: ctx.buildContext,
      );
    },
  ),
  SheetsCommand(
    'sheets.cleanup.removeDuplicates',
    label: (l) => l.dedupeTitle,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'range': JsonSchema.string(),
        'hasHeader': JsonSchema.boolean(),
        'colIds': JsonSchema.array(JsonSchema.string()),
      },
    ),
    run: (ctx, ed, a) async {
      final range = a.string('range') == null
          ? ResolvedRange(ed.activeSheetId, dataRangeFor(ed)!)
          : rangeArg(ed, a);
      final ids = a.strings('colIds');
      final plan = await DataJobs.run(
        ed,
        rows: range.rect.rowCount,
        label: ed.l10n.dataJobDeduping(range.rect.rowCount),
        work: () => ed.apply(
          ctx,
          RemoveDuplicates(
            range,
            hasHeader: a.boolean('hasHeader') ?? false,
            colIds: ids.isEmpty ? null : ids,
          ),
        ),
      );
      final msg = plan.result['message'] as String? ?? '';
      final context = ctx.dialogContext;
      if (context != null && context.mounted && !ctx.source.isAgent) {
        final la = WonkyAppLocalizations.of(context);
        await showWonkyFormDialog(
          context,
          WonkyDialogSpec(
            title: ed.l10n.dedupeTitle,
            description: msg,
            dialogKey: 'dialog.removeDuplicatesResult',
            fields: const [],
            buttons: [
              DialogButtonSpec(id: 'ok', label: la.actionOk, primary: true),
            ],
          ),
        );
      }
      return ok({
        'duplicatesRemoved': plan.result['duplicatesRemoved'],
        'uniqueRemaining': plan.result['uniqueRemaining'],
        'message': msg,
      });
    },
  ),
  SheetsCommand(
    'sheets.data.splitTextToColumns',
    label: (l) => l.cmdDataSplitTextToColumns,
    icon: LucideIcons.columns3,
    categoryName: _data,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'range': JsonSchema.string(description: 'A single column range.'),
        'separator': JsonSchema.string(
          description: 'Separator (default: detect automatically).',
        ),
        'force': JsonSchema.boolean(
          description: 'Replace data to the right without asking.',
        ),
      },
    ),
    run: (ctx, ed, a) async {
      final GridRect? rect = a.string('range') != null
          ? rangeArg(ed, a).rect
          : _splitSource(ed);
      if (rect == null || rect.colCount != 1) {
        return CommandResult.failed(ed.l10n.splitSingleColumn);
      }
      final sep = a.string('separator');
      final range = ResolvedRange(ed.activeSheetId, rect);
      MutationPlan plan;
      try {
        plan = await DataJobs.run(
          ed,
          rows: rect.rowCount,
          label: ed.l10n.dataJobSplitting(rect.rowCount),
          work: () => ed.apply(
            ctx,
            SplitTextToColumns(
              range,
              separator: sep,
              force: a.boolean('force') ?? false,
            ),
          ),
        );
      } on PlanException catch (e) {
        if (e.code == 'confirm_overwrite') {
          final context = ctx.dialogContext;
          if (context == null || !context.mounted || ctx.source.isAgent) {
            return CommandResult.failed(e.message);
          }
          final yes = await confirmDialog(
            context,
            title: ed.l10n.splitReplaceTitle,
            description: ed.l10n.splitReplaceBody,
            confirmLabel: ed.l10n.splitReplace,
          );
          if (!yes) return const CommandResult.cancelled();
          plan = await ed.applyConfirmed(
            ctx,
            SplitTextToColumns(range, separator: sep, force: true),
          );
        } else if (e.code == 'no_separator') {
          DataTools.of(ed).splitChip.value = SplitChipState(
            ed.activeSheetId,
            rect,
            null,
            failed: true,
          );
          return CommandResult.failed(ed.l10n.splitNoSeparator);
        } else {
          rethrow;
        }
      }
      ed.selection.setRanges([(SelectionKind.cells, rect)]);
      DataTools.of(ed).splitChip.value = SplitChipState(
        ed.activeSheetId,
        rect,
        sep,
        detected: plan.result['separator'] as String?,
      );
      return ok({
        'separator': plan.result['separator'],
        'columns': plan.result['columns'],
        'cells': plan.result['cells'],
      });
    },
  ),
  SheetsCommand(
    'sheets.data.columnStats',
    label: (l) => l.cmdDataColumnStats,
    icon: LucideIcons.chartNoAxesColumn,
    categoryName: _data,
    argsSchema: const JsonSchema.object(
      properties: {'colId': JsonSchema.string()},
    ),
    run: (ctx, ed, a) {
      DataTools.of(ed).statsColumn.value = a.string('colId');
      s.panels.open(columnStatsPanelId);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.columnStats.selectColumn',
    label: (l) => l.cmdColumnStatsSelectColumn,
    categoryName: _data,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'colId': JsonSchema.string()},
      required: ['colId'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('colId');
      final col = ed.activeSheet?.columns.indexOf(id) ?? -1;
      if (col < 0) return const CommandResult.failed('Column not found');
      DataTools.of(ed).statsColumn.value = id;
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.cleanup.openSuggestions',
    label: (l) => l.cmdCleanupOpenSuggestions,
    icon: LucideIcons.sparkles,
    categoryName: _data,
    run: (ctx, ed, a) {
      s.panels.open(cleanupSuggestionsPanelId);
      return ok({
        'suggestions': [
          for (final x in cleanupSuggestionsOf(ed))
            {'id': x.id, 'kind': x.kind.name, 'count': x.count},
        ],
      });
    },
  ),
  SheetsCommand(
    'sheets.cleanup.applySuggestion',
    label: (l) => l.cmdCleanupApplySuggestion,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'id': JsonSchema.string(
          description: 'Suggestion id from sheets.cleanup.openSuggestions.',
        ),
      },
      required: ['id'],
    ),
    undoLabelOf: (l, a) => l.cmdCleanupApplySuggestion,
    run: (ctx, ed, a) async {
      final id = a.requireString('id');
      final sug = cleanupSuggestionsOf(ed).where((x) => x.id == id).firstOrNull;
      if (sug == null || !sug.applicable) {
        return CommandResult.failed(ed.l10n.cleanupGone);
      }
      final sid = ed.activeSheetId;
      final rows = sug.range.rowCount;
      await DataJobs.run(
        ed,
        rows: rows,
        label: ed.l10n.dataJobCleaning(rows),
        work: () {
          switch (sug.kind) {
            case CleanupKind.numbersAsText:
            case CleanupKind.capitalization:
              final asNumbers = sug.kind == CleanupKind.numbersAsText;
              for (final (r, c, text) in sug.cells) {
                ed.apply(
                  ctx,
                  SetCellInputs(
                    sheetId: sid,
                    row: r,
                    col: c,
                    inputs: [
                      [asNumbers ? CellInput.user(text) : CellInput.raw(text)],
                    ],
                  ),
                );
              }
            case CleanupKind.whitespace:
              ed.apply(ctx, TrimWhitespace([ResolvedRange(sid, sug.range)]));
            case CleanupKind.duplicates:
              ed.apply(
                ctx,
                RemoveDuplicates(
                  ResolvedRange(sid, sug.range),
                  hasHeader: sug.hasHeader,
                ),
              );
            case CleanupKind.emptyRows:
              ed.apply(ctx, DeleteDimension(sid, Dimension.rows, sug.rowIds));
            case CleanupKind.mixedTypes:
              break;
          }
        },
      );
      return ok({'applied': id, 'count': sug.count});
    },
  ),
];
