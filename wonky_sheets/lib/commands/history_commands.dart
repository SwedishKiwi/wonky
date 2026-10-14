import 'dart:async';

import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show CellPos;
import 'package:wonky_sheets_core/model.dart';
import 'package:shad/shad.dart' show LucideIcons;

import '../features/collab/sheets_collab.dart';
import '../features/history/sheets_version_view.dart';
import 'sheets_command.dart';

/// A Sheets command that also runs without an open spreadsheet editor (the
/// full-screen version history route).
class _GlobalSheetsCommand extends SheetsCommand {
  _GlobalSheetsCommand(
    super.id, {
    required super.label,
    required this.runGlobal,
    this.enabledGlobal,
    super.icon,
    super.categoryName,
    super.argsSchema,
    super.showInPalette,
  }) : super(run: _never, needsEditor: false);

  final Future<CommandResult> Function(CommandContext ctx, JsonArgs args)
  runGlobal;
  final bool Function(CommandContext ctx)? enabledGlobal;

  static CommandResult _never(CommandContext c, Object e, JsonArgs a) =>
      const CommandResult.failed('unreachable');

  @override
  Role get requiredRole => Role.viewer;

  @override
  bool isEnabled(CommandContext ctx, JsonArgs args) =>
      enabledGlobal?.call(ctx) ?? true;

  @override
  String? disabledReason(CommandContext ctx, JsonArgs args) => null;

  @override
  Future<CommandResult> execute(CommandContext ctx, JsonArgs args) =>
      runGlobal(ctx, args);
}

/// Version and cell history commands (Sheets 10 §5–6, §11). The suite's
/// `shell.versions.*` commands do the work; these are the Sheets ids of 04
/// and the history-route specifics.
List<Command<CommandArgs>> historyCommands(ShellServices s) {
  bool canHistory() =>
      (s.currentItem.value?.myRole.canViewHistory ?? false) &&
      s.connectivity.online;
  SheetsVersionViewState? view() => SheetsVersionView.current.value;

  Future<CommandResult> delegate(
    CommandContext ctx,
    String id, [
    Map<String, Object?> args = const {},
  ]) => s.dispatcher.invoke(
    id,
    args: args,
    source: ctx.source,
    context: ctx.dialogContext,
  );

  return [
    _GlobalSheetsCommand(
      'sheets.history.open',
      label: (l) => l.cmdHistoryOpen,
      icon: LucideIcons.history,
      categoryName: (l) => l.categoryCollaboration,
      enabledGlobal: (_) => canHistory(),
      runGlobal: (ctx, a) => delegate(ctx, 'shell.versions.open'),
    ),
    _GlobalSheetsCommand(
      'sheets.history.nameCurrentVersion',
      label: (l) => l.cmdHistoryNameCurrentVersion,
      icon: LucideIcons.bookmarkPlus,
      categoryName: (l) => l.categoryCollaboration,
      argsSchema: const JsonSchema.object(
        properties: {'name': JsonSchema.string(minLength: 1, maxLength: 200)},
      ),
      enabledGlobal: (_) =>
          canHistory() && (s.currentItem.value?.canEdit ?? false),
      runGlobal: (ctx, a) => delegate(ctx, 'shell.versions.nameCurrent', {
        if (a.string('name') != null) 'name': a.string('name'),
      }),
    ),
    _GlobalSheetsCommand(
      'sheets.history.restoreVersion',
      label: (l) => l.cmdHistoryRestoreVersion,
      icon: LucideIcons.archiveRestore,
      categoryName: (l) => l.categoryCollaboration,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'versionId': JsonSchema.integer(),
          'confirmed': JsonSchema.boolean(),
        },
        required: ['versionId'],
      ),
      enabledGlobal: (_) =>
          canHistory() && (s.currentItem.value?.canEdit ?? false),
      // The shell command records the `sheets.serverChange` undo entry
      // through `SheetsVersionRenderer.restoreUndoEntry`.
      runGlobal: (ctx, a) => delegate(ctx, 'shell.versions.restore', {
        'versionId': a.integer('versionId'),
        if (a.boolean('confirmed') != null) 'confirmed': a.boolean('confirmed'),
      }),
    ),
    _GlobalSheetsCommand(
      'sheets.history.makeCopy',
      label: (l) => l.cmdHistoryMakeCopy,
      icon: LucideIcons.copy,
      categoryName: (l) => l.categoryCollaboration,
      argsSchema: const JsonSchema.object(
        properties: {'name': JsonSchema.string(minLength: 1, maxLength: 255)},
      ),
      enabledGlobal: (_) => view()?.rows != null,
      runGlobal: (ctx, a) async {
        final v = view();
        if (v == null) {
          return const CommandResult.failed('Open a version first');
        }
        final id = await v.makeCopy(name: a.string('name'));
        return id == null
            ? const CommandResult.failed('Copy failed')
            : CommandResult.ok({'itemUuid': id.uuid});
      },
    ),
    _GlobalSheetsCommand(
      'sheets.history.nextChange',
      label: (l) => l.cmdHistoryNextChange,
      icon: LucideIcons.chevronDown,
      categoryName: (l) => l.categoryCollaboration,
      enabledGlobal: (_) => (view()?.changes.isNotEmpty ?? false),
      runGlobal: (ctx, a) async {
        view()?.step(forward: true);
        return ok();
      },
    ),
    _GlobalSheetsCommand(
      'sheets.history.previousChange',
      label: (l) => l.cmdHistoryPreviousChange,
      icon: LucideIcons.chevronUp,
      categoryName: (l) => l.categoryCollaboration,
      enabledGlobal: (_) => (view()?.changes.isNotEmpty ?? false),
      runGlobal: (ctx, a) async {
        view()?.step(forward: false);
        return ok();
      },
    ),
    SheetsCommand(
      'sheets.history.showCellHistory',
      label: (l) => l.cmdHistoryShowCellHistory,
      icon: LucideIcons.history,
      categoryName: (l) => l.categoryCollaboration,
      argsSchema: const JsonSchema.object(
        properties: {
          'cell': JsonSchema.string(description: 'A1 cell (default: active).'),
        },
      ),
      enabled: (ed, _) => ed.roleCanEdit && SheetsCollab.of(ed) != null,
      run: (ctx, ed, a) {
        final collab = SheetsCollab.of(ed)!;
        final cell = a.string('cell');
        if (cell != null) {
          final r = ed.model.parseA1(cell, contextSheetId: ed.activeSheetId);
          if (r.sheetId != ed.activeSheetId) ed.activateSheet(r.sheetId);
          ed.selection.selectCell(r.rect.top, r.rect.left);
          ed.revealCell(r.rect.top, r.rect.left);
        }
        return collab.showCellHistory()
            ? ok()
            : const CommandResult.failed('No cell');
      },
    ),
    SheetsCommand(
      'sheets.history.restoreCellValue',
      label: (l) => l.cmdHistoryRestoreCellValue,
      icon: LucideIcons.undo2,
      categoryName: (l) => l.categoryCollaboration,
      mutates: true,
      showInPalette: false,
      undoLabelOf: (l, _) => l.undoRestoreValue,
      argsSchema: const JsonSchema.object(
        properties: {
          'sheetId': JsonSchema.string(minLength: 1),
          'rowId': JsonSchema.string(minLength: 1),
          'colId': JsonSchema.string(minLength: 1),
          'changeLogId': JsonSchema.string(minLength: 1),
          'content': JsonSchema.string(
            description:
                'The stored content to restore (default: the "before" '
                'value of the change in the open history).',
          ),
        },
        required: ['sheetId', 'rowId', 'colId', 'changeLogId'],
      ),
      run: (ctx, ed, a) {
        final sheetId = a.requireString('sheetId');
        final sheet = ed.model.sheet(sheetId);
        final row = sheet?.rows.indexOf(a.requireString('rowId')) ?? -1;
        final col = sheet?.columns.indexOf(a.requireString('colId')) ?? -1;
        if (sheet == null || row < 0 || col < 0) {
          return const CommandResult.failed('The cell no longer exists');
        }
        String? content;
        if (a.values.containsKey('content')) {
          content = a.string('content');
        } else {
          final h = SheetsCollab.of(ed)?.cellHistory.value;
          final id = a.requireString('changeLogId');
          final e = h?.items.where((x) => x.changeLogId == id).firstOrNull;
          if (e == null || e.bulk) {
            return const CommandResult.failed('Unknown history entry');
          }
          content = e.before;
        }
        ed.apply(
          ctx,
          RestoreCellValue(
            sheetId,
            a.requireString('rowId'),
            a.requireString('colId'),
            content,
          ),
        );
        // The popover shows the new entry once the change log row exists.
        final h = SheetsCollab.of(ed)?.cellHistory.value;
        if (h != null) {
          unawaited(
            Future<void>.delayed(const Duration(milliseconds: 300), h.load),
          );
        }
        return ok({'cell': CellPos(row, col).a1});
      },
    ),
  ];
}
