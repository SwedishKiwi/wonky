import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:shad/shad.dart' show LucideIcons;

import '../features/collab/sheets_collab.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

/// Sheets comment commands (Sheets 10 §3.4–3.5, §11). Creating, replying,
/// resolving and deleting threads are the suite's `shell.comments.*`
/// commands with the Sheets anchor provider.
List<Command<CommandArgs>> commentCommands(ShellServices s) {
  CommandResult step(SheetEditorController ed, {required bool forward}) {
    final c = SheetsCollab.of(ed);
    final next = c?.comments.neighbor(forward: forward);
    if (c == null || next == null) {
      return const CommandResult.failed('No comments');
    }
    c.comments.reveal(next.thread);
    c.comments.controller?.activate(next.thread.uuid.uuid);
    c.dockedDismissed.value = false;
    return ok({'threadUuid': next.thread.uuid.uuid});
  }

  bool hasThreads(SheetEditorController ed) {
    final c = SheetsCollab.of(ed);
    return c != null &&
        c.comments.visible &&
        c.comments.readingOrder.isNotEmpty;
  }

  return [
    SheetsCommand(
      'sheets.comments.openPanel',
      label: (l) => l.cmdCommentsOpenPanel,
      icon: LucideIcons.messageSquare,
      categoryName: (l) => l.categoryCollaboration,
      defaultBindings: const [
        KeyBinding('A', mod: true, alt: true, shift: true),
      ],
      argsSchema: const JsonSchema.object(
        properties: {
          'scope': JsonSchema.string(enumValues: ['sheet', 'all']),
        },
      ),
      enabled: (ed, _) => SheetsCollab.of(ed)?.comments.visible ?? false,
      run: (ctx, ed, a) {
        final scope = a.string('scope');
        final c = SheetsCollab.of(ed)?.comments.controller;
        if (scope != null) c?.setScope(scope);
        s.panels.open(ShellPanels.comments);
        return ok({'scope': ?c?.scope});
      },
    ),
    SheetsCommand(
      'sheets.comments.next',
      label: (l) => l.cmdCommentsNext,
      icon: LucideIcons.arrowDownToLine,
      categoryName: (l) => l.categoryCollaboration,
      defaultBindings: const [KeyBinding('N', mod: true, alt: true)],
      enabled: (ed, _) => hasThreads(ed),
      run: (ctx, ed, a) => step(ed, forward: true),
    ),
    SheetsCommand(
      'sheets.comments.previous',
      label: (l) => l.cmdCommentsPrevious,
      icon: LucideIcons.arrowUpToLine,
      categoryName: (l) => l.categoryCollaboration,
      defaultBindings: const [KeyBinding('P', mod: true, alt: true)],
      enabled: (ed, _) => hasThreads(ed),
      run: (ctx, ed, a) => step(ed, forward: false),
    ),
    SheetsCommand(
      'sheets.view.toggleCommentIndicators',
      label: (l) => l.cmdViewToggleCommentIndicators,
      categoryName: (l) => l.categoryCollaboration,
      checked: (ed, _) => !(SheetsCollab.of(ed)?.comments.indicatorsOn ?? true),
      run: (ctx, ed, a) {
        final c = SheetsCollab.of(ed);
        if (c == null) return const CommandResult.failed('Not available');
        c.comments.setIndicators(!c.comments.indicatorsOn);
        return ok();
      },
    ),
  ];
}
