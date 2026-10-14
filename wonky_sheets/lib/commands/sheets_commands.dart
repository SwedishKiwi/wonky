import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import 'ai_commands.dart';
import 'banding_commands.dart';
import 'cell_commands.dart';
import 'cf_commands.dart';
import 'chart_commands.dart';
import 'chip_commands.dart';
import 'cleanup_commands.dart';
import 'collab_commands.dart';
import 'comment_commands.dart';
import 'data_commands.dart';
import 'dv_commands.dart';
import 'editing_commands.dart';
import 'file_io_commands.dart';
import 'filter_commands.dart';
import 'find_commands.dart';
import 'format_commands.dart';
import 'format_extra_commands.dart';
import 'group_commands.dart';
import 'history_commands.dart';
import 'conflict_commands.dart';
import 'image_commands.dart';
import 'link_commands.dart';
import 'macro_commands.dart';
import 'named_commands.dart';
import 'nav_commands.dart';
import 'note_commands.dart';
import 'object_commands.dart';
import 'pivot_commands.dart';
import 'print_commands.dart';
import 'protection_commands.dart';
import 'script_commands.dart';
import 'sheet_commands.dart';
import 'slicer_commands.dart';
import 'sort_commands.dart';
import 'structure_commands.dart';
import 'theme_commands.dart';
import 'view_commands.dart';

/// Every `sheets.*` command (03 §19, 04 — the canonical id registry).
///
/// Order matters for contextual key bindings (suite 08 §1.2): within a
/// scope, the first enabled command bound to a chord runs, so the formula
/// autocomplete/point-mode commands come before the editor commit commands.
List<Command<CommandArgs>> sheetsCommands(ShellServices s) => [
  // Objects first: Mod+V in the grid pastes copied objects while they are
  // the newest copy (08 §9.5), before `sheets.edit.paste`.
  ...objectCommands(s),
  ...chartCommands(s),
  ...imageCommands(s),
  ...cellCommands(s),
  ...navCommands(s),
  ...editingCommands(s),
  ...formatCommands(s),
  ...formatExtraCommands(s),
  ...cfCommands(s),
  ...bandingCommands(s),
  ...themeCommands(s),
  ...structureCommands(s),
  ...sheetCommands(s),
  ...viewCommands(s),
  ...dataCommands(s),
  ...sortCommands(s),
  ...filterCommands(s),
  ...findCommands(s),
  ...cleanupCommands(s),
  ...slicerCommands(s),
  ...namedCommands(s),
  ...groupCommands(s),
  ...pivotCommands(s),
  ...aiCommands(s),
  ...collabCommands(s),
  ...commentCommands(s),
  ...historyCommands(s),
  ...conflictCommands(s),
  ...dvCommands(s),
  ...protectionCommands(s),
  ...linkCommands(s),
  ...chipCommands(s),
  ...noteCommands(s),
  ...fileIoCommands(s),
  ...printCommands(s),
  ...scriptCommands(s),
  ...macroCommands(s),
  ...placeholderCommands(s),
];
