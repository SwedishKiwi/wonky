import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/collab/sheets_collab.dart';
import '../features/history/conflict_review_dialog.dart';
import 'sheets_command.dart';

/// Overwritten offline edits (Sheets 10 §9, §11): the review dialog and
/// *Apply mine again* (one undo step).
List<Command<CommandArgs>> conflictCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.conflicts.review',
    label: (l) => l.cmdConflictsReview,
    icon: LucideIcons.gitCompareArrows,
    categoryName: (l) => l.categoryCollaboration,
    enabled: (ed, _) =>
        ed.roleCanEdit &&
        (SheetsCollab.of(ed)?.conflicts.open.isNotEmpty ?? false),
    run: (ctx, ed, a) async {
      final conflicts = SheetsCollab.of(ed)!.conflicts;
      final open = conflicts.open;
      final c = ctx.dialogContext;
      if (open.isEmpty || c == null) {
        return ok({'conflicts': open.length});
      }
      final choice = await showConflictReviewDialog(
        c,
        editor: ed,
        conflicts: open,
      );
      if (choice == null) return const CommandResult.cancelled();
      if (choice.action == 'dismiss') {
        await conflicts.dismiss();
        return ok({'dismissed': open.length});
      }
      if (choice.ids.isEmpty) return const CommandResult.cancelled();
      return ed
          .invokeCommand('sheets.conflicts.applyMine', {
            'conflictIds': choice.ids,
          })
          .then((done) => done ? ok() : const CommandResult.failed('Failed'));
    },
  ),
  SheetsCommand(
    'sheets.conflicts.applyMine',
    label: (l) => l.cmdConflictsApplyMine,
    icon: LucideIcons.undo2,
    categoryName: (l) => l.categoryCollaboration,
    mutates: true,
    showInPalette: false,
    undoLabelOf: (l, _) => l.undoApplyMine,
    argsSchema: const JsonSchema.object(
      properties: {
        'conflictIds': JsonSchema.array(JsonSchema.string(minLength: 1)),
      },
      required: ['conflictIds'],
    ),
    enabled: (ed, _) => SheetsCollab.of(ed) != null,
    run: (ctx, ed, a) async {
      final conflicts = SheetsCollab.of(ed)!.conflicts;
      final ids = [
        for (final x in (a.values['conflictIds'] as List?) ?? const []) '$x',
      ];
      final list = conflicts.byIds(ids);
      var applied = 0;
      final done = <String>[];
      for (final c in list) {
        if (!c.canApply) continue;
        final sheet = ed.model.sheet(c.sheetId);
        if (sheet == null ||
            !sheet.rows.contains(c.rowId) ||
            !sheet.columns.contains(c.colId)) {
          continue;
        }
        ed.apply(ctx, RestoreCellValue(c.sheetId, c.rowId, c.colId, c.myValue));
        applied++;
        done.add(c.id);
      }
      if (applied == 0) {
        return const CommandResult.failed('Nothing to apply');
      }
      await conflicts.dismiss(done);
      return ok({'applied': applied});
    },
  ),
];
