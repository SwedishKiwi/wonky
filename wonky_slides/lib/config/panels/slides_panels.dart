import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../features/accessibility/accessibility_panel.dart';
import '../../features/ai/design_ideas_panel.dart';
import '../../features/assistant/slides_assistant_panel.dart';
import '../../features/editor_screen/deck_editor_controller.dart';
import '../../features/elements/chart/linked_charts_panel.dart';
import '../../features/layers/layers_panel.dart';
import '../../features/themes/themes_panel.dart';
import '../slides_features.dart';

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
/// adds Comments, Details and History. SL-43: the Assistant (the shell's
/// panel with the Slides adapter) and Design ideas.
/// SL-17: Themes. SL-32: Linked charts. SL-34: Layers, Accessibility.
List<SidePanelSpec> slidesPanelSpecs(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) => [
  if (SlidesFeatures.isOn(SlidesFeature.layers))
    layersPanelSpec(context, services, editor),
  themesPanelSpec(context, services, editor),
  if (SlidesFeatures.isOn(SlidesFeature.accessibilityChecker))
    accessibilityPanelSpec(context, services, editor),
  if (SlidesFeatures.isOn(SlidesFeature.charts))
    linkedChartsPanelSpec(context, services, editor),
  if (SlidesFeatures.isOn(SlidesFeature.assistant)) ...[
    designIdeasPanelSpec(context, services, editor),
    ?slidesAssistantPanelSpec(context, services, editor),
  ],
];
