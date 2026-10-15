import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../config/slides_features.dart';
import '../features/settings/slides_settings.dart' show slidesSettingsCommands;
import 'accessibility_commands.dart';
import 'animate_commands.dart';
import 'canvas_commands.dart';
import 'chart_commands.dart';
import 'chrome_commands.dart';
import 'clipboard_commands.dart';
import 'code_commands.dart';
import 'connector_commands.dart';
import 'find_commands.dart';
import 'history_commands.dart';
import 'collab_commands.dart';
import 'comment_commands.dart';
import 'image_commands.dart';
import 'layers_commands.dart';
import 'master_commands.dart';
import 'navigator_commands.dart';
import 'object_commands.dart';
import 'outline_commands.dart';
import 'placeholder_commands.dart';
import 'present_commands.dart';
import 'spelling_commands.dart';
import 'print_commands.dart';
import 'style_commands.dart';
import 'table_commands.dart';
import 'text_commands.dart';
import 'theme_commands.dart';

/// Every `slides.*` command — the registration index of Wonky Slides
/// (Slides 04 §4 is the canonical id registry; Slides 12 §2: SL-11 owns
/// this file, the other work packages add one line for their
/// `commands/<area>_commands.dart`).
///
/// Order matters for contextual key bindings (suite 08 §1.2): within a
/// scope the first enabled command bound to a chord runs. Real commands
/// come first; [placeholderCommands] fills in every menu-bound id that has
/// no real registration yet, so a work package implements a command by
/// registering it here — its placeholder drops out automatically.
///
/// Commands of features that are off ([SlidesFeatures], SL-23) are not
/// registered at all — real or placeholder — so nothing offers unbuilt
/// work; placeholders of features that are on stay disabled ("Not
/// available yet") until their handler exists.
List<Command<CommandArgs>> slidesCommands(ShellServices s) {
  final real = <Command<CommandArgs>>[
    // First: its Escape (leave masters mode) wins over the canvas' Escape
    // while nothing is selected in masters mode (SL-28).
    ...masterCommands(s),
    ...chromeCommands(s),
    ...textCommands(s),
    ...canvasCommands(s),
    ...navigatorCommands(s),
    ...outlineCommands(s),
    ...layersCommands(s),
    ...accessibilityCommands(s),
    ...objectCommands(s),
    ...connectorCommands(s),
    ...styleCommands(s),
    ...imageCommands(s),
    ...tableCommands(s),
    ...codeCommands(s),
    ...animateCommands(s),
    ...chartCommands(s),
    ...printCommands(s),
    ...presentCommands(s),
    ...themeCommands(s),
    ...clipboardCommands(s),
    ...findCommands(s),
    ...spellingCommands(s),
    ...collabCommands(s),
    ...commentCommands(s),
    ...historyCommands(s),
    ...slidesSettingsCommands(s),
  ];
  final ids = {for (final c in real) c.id.value};
  return [
    for (final c in real)
      if (SlidesFeatures.registers(c.id.value)) c,
    for (final c in placeholderCommands(s))
      if (!ids.contains(c.id.value) && SlidesFeatures.registers(c.id.value)) c,
  ];
}
