import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../features/formatting/sheets_user_defaults.dart';
import 'sheets_command.dart';

String _editing(SheetsLocalizations l) => l.categoryEditing;

/// Per-user editing preferences as commands (03 §8.5, 04 §3 Tools menu):
/// the same values as Settings › Sheets.
List<Command<CommandArgs>> editingCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.tools.toggleAutocomplete',
    label: (l) => l.cmdToolsToggleAutocomplete,
    icon: LucideIcons.textCursorInput,
    categoryName: _editing,
    checked: (ed, a) => SheetsUserDefaults.of(ed.services).columnAutocomplete,
    run: (ctx, ed, a) async {
      final d = SheetsUserDefaults.of(ed.services);
      await d.set(
        SheetsUserDefaults.keyColumnAutocomplete,
        !d.columnAutocomplete,
      );
      return ok();
    },
  ),
];
