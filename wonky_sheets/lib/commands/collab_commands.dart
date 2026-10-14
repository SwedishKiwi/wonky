import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:shad/shad.dart' show LucideIcons;

import '../features/collab/sheets_collab.dart';
import 'sheets_command.dart';

const _session = JsonSchema.object(
  properties: {
    'sessionId': JsonSchema.string(
      minLength: 1,
      description: 'Presence session id of the participant.',
    ),
  },
  required: ['sessionId'],
);

/// Presence commands (Sheets 10 §1, §11): jump to and follow collaborators.
List<Command<CommandArgs>> collabCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.presence.jumpTo',
    label: (l) => l.cmdPresenceJumpTo,
    icon: LucideIcons.locateFixed,
    categoryName: (l) => l.categoryCollaboration,
    argsSchema: _session,
    showInPalette: false,
    run: (ctx, ed, a) {
      final c = SheetsCollab.of(ed);
      if (c == null || !c.presence.jumpTo(a.requireString('sessionId'))) {
        return const CommandResult.failed('Participant not found');
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.presence.follow',
    label: (l) => l.cmdPresenceFollow,
    icon: LucideIcons.eye,
    categoryName: (l) => l.categoryCollaboration,
    argsSchema: _session,
    showInPalette: false,
    run: (ctx, ed, a) {
      final c = SheetsCollab.of(ed);
      if (c == null || !c.presence.follow(a.requireString('sessionId'))) {
        return const CommandResult.failed('Participant not found');
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.presence.unfollow',
    label: (l) => l.cmdPresenceUnfollow,
    icon: LucideIcons.eyeOff,
    categoryName: (l) => l.categoryCollaboration,
    enabled: (ed, _) => SheetsCollab.of(ed)?.presence.following.value != null,
    run: (ctx, ed, a) {
      SheetsCollab.of(ed)?.presence.unfollow();
      return ok();
    },
  ),
];
