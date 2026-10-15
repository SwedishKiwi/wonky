import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../features/settings/slides_settings.dart' show slidesSettingsCommands;
import 'chrome_commands.dart';
import 'placeholder_commands.dart';

/// Every `slides.*` command — the registration index of Wonky Slides
/// (Slides 04 §4 is the canonical id registry; Slides 12 §2: SL-11 owns
/// this file, the other work packages add one line for their
/// `commands/<area>_commands.dart`).
///
/// Order matters for contextual key bindings (suite 08 §1.2): within a
/// scope the first enabled command bound to a chord runs. Real commands
/// come first; [placeholderCommands] fills in every menu-bound id that has
/// no real registration yet (disabled, "Not available yet"), so a work
/// package implements a command by registering it here — its placeholder
/// drops out automatically.
List<Command<CommandArgs>> slidesCommands(ShellServices s) {
  final real = <Command<CommandArgs>>[
    ...chromeCommands(s),
    ...slidesSettingsCommands(s),
  ];
  final ids = {for (final c in real) c.id.value};
  return [
    ...real,
    for (final c in placeholderCommands(s))
      if (!ids.contains(c.id.value)) c,
  ];
}
