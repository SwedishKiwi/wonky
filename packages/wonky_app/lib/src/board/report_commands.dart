import 'dart:ui' as ui;

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../commands/command.dart';
import '../commands/shell_commands/general_commands.dart' show bugReportUrl;
import '../commands/shell_commands/shell_command_base.dart';
import '../shell/dialogs.dart';
import '../shell/shell_services.dart';
import 'report/board_report_dialog.dart';
import 'report/board_report_services.dart';

/// The board page route (specs/16 §4.3).
const boardRoute = '/improvements';

/// The tabs of the board page (`shell.board.open {tab}`).
const boardTabs = [
  'improvements',
  'bugs',
  'tasks',
  'done',
  'review',
  'contribute',
];

/// The report entry commands of Bugs & Improvements (specs/16 §4.1, §14):
/// `shell.board.report {kind?}` opens the report dialog (screenshot
/// captured first), `shell.board.open {tab?}` the board page, and the old
/// ids `shell.help.reportBug` (kind Bug) and `shell.help.feedback` (the
/// kind chosen in the dialog) are aliases (ids never change, 08 §6).
List<Command<CommandArgs>> boardReportCommands(ShellServices s) => [
  shellCommand(
    'shell.board.report',
    title: (l) => l.cmdBoardReport,
    icon: LucideIcons.messageSquarePlus,
    category: (l) => l.categoryHelp,
    args: const JsonSchema.object(
      properties: {
        'kind': JsonSchema.string(
          enumValues: ['bug', 'idea'],
          description: 'Bug report or improvement idea; default: the draft.',
        ),
        'includeError': JsonSchema.boolean(
          description: 'Tick "Include the last error" (the error card).',
        ),
      },
    ),
    run: (ctx, a) => openBoardReport(
      s,
      ctx,
      kind: switch (a.string('kind')) {
        'bug' => BoardPostKind.bug,
        'idea' => BoardPostKind.idea,
        _ => null,
      },
      includeError: a.boolean('includeError') ?? false,
    ),
  ),
  shellCommand(
    'shell.board.open',
    title: (l) => l.cmdBoardOpen,
    icon: LucideIcons.messagesSquare,
    category: (l) => l.categoryHelp,
    args: const JsonSchema.object(
      properties: {
        'tab': JsonSchema.string(
          enumValues: boardTabs,
          description: 'The board tab; default: Improvements.',
        ),
      },
    ),
    enabled: (ctx, a) => s.urls.board,
    run: (ctx, a) async {
      final tab = a.string('tab');
      final path = tab == null || tab == 'improvements'
          ? boardRoute
          : '$boardRoute/$tab';
      s.router.go(path);
      return CommandResult.ok({'route': path});
    },
  ),
  // Aliases of `shell.board.report` (specs/16 §4.1).
  shellCommand(
    'shell.help.reportBug',
    title: (l) => l.cmdReportBug,
    icon: LucideIcons.bug,
    category: (l) => l.categoryHelp,
    palette: false,
    run: (ctx, a) => openBoardReport(s, ctx, kind: BoardPostKind.bug),
  ),
  shellCommand(
    'shell.help.feedback',
    title: (l) => l.cmdReportProblem,
    icon: LucideIcons.messageCircleWarning,
    category: (l) => l.categoryHelp,
    palette: false,
    run: (ctx, a) => openBoardReport(s, ctx),
  ),
];

/// Runs `shell.board.report` (specs/16 §4.1, §4.2, §5.1):
///
/// - board disabled (`config.json` `board: false`): the GitHub new-issue
///   link (`BugReportLink`) behind the external-link confirm;
/// - signed out: the board page (it shows *Sign in to post*);
/// - otherwise the app is captured **before** the dialog opens, then the
///   report dialog shows with [kind] (null: the draft's) and, with
///   [includeError], *Include the last error* ticked.
Future<CommandResult> openBoardReport(
  ShellServices s,
  CommandContext ctx, {
  BoardPostKind? kind,
  bool includeError = false,
}) async {
  if (!s.urls.board) return _githubFallback(s, ctx);
  if (!s.auth.isSignedIn) {
    s.router.go(boardRoute);
    return const CommandResult.ok({'signedIn': false, 'route': boardRoute});
  }
  if (ctx.dialogContext == null) return const CommandResult.cancelled();
  ui.Image? image;
  try {
    image = await BoardReportServices.of(s).capture();
  } catch (_) {
    image = null;
  }
  final c = ctx.dialogContext;
  if (c == null || !c.mounted) {
    image?.dispose();
    return const CommandResult.cancelled();
  }
  final r = await showBoardReportDialog(
    c,
    s,
    kind: kind,
    screenshot: image,
    screenshotFailed: image == null,
    includeLastError: includeError,
  );
  if (r == null) return const CommandResult.cancelled();
  return CommandResult.ok({
    'outcome': r.outcome.name,
    if (r.post != null) 'postNumber': r.post!.number,
  });
}

/// The GitHub *Report a bug* link (suite 03 §3.4), kept for a server
/// without the board.
Future<CommandResult> _githubFallback(
  ShellServices s,
  CommandContext ctx,
) async {
  final c = ctx.dialogContext;
  if (c == null || !c.mounted) return const CommandResult.cancelled();
  final url = bugReportUrl(s);
  final choice = await confirmExternalLink(
    c,
    s,
    url: url,
    note: l10nOf(c).reportBugNote,
  );
  if (choice == ExternalLinkChoice.cancel) {
    return const CommandResult.cancelled();
  }
  return CommandResult.ok({'url': url, 'action': choice.name});
}
