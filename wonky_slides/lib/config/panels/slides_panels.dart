import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../features/editor_screen/deck_editor_controller.dart';
import '../../features/themes/themes_panel.dart';

/// Panel ids of the Slides side panels (04 §12), hosted by the shell's
/// panel host next to the docked inspector. `slides.panel.animate` is not
/// a side panel: it opens the inspector's Animate tab (Q21).
abstract final class SlidesPanels {
  static const layers = 'slides.panel.layers';
  static const themes = 'slides.panel.themes';
  static const accessibility = 'slides.panel.accessibility';
  static const linkedObjects = 'slides.panel.linkedObjects';
}

/// The Slides side panel registry (04 §12): the work package that builds a
/// panel adds its `SidePanelSpec` here (one line, Slides 12 §2) and makes
/// its `slides.panel.*` command open it with `shell.panels.open`. The shell
/// adds Comments, Details and History; the Assistant comes with SL-43.
/// SL-17: Themes.
List<SidePanelSpec> slidesPanelSpecs(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) => [themesPanelSpec(context, services, editor)];
