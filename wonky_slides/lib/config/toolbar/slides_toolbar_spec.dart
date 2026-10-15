import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart' show MenuCustomItems;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../features/editor_screen/deck_editor_controller.dart';
import '../../features/elements/style/style_toolbar.dart';
import '../../features/layouts/layout_gallery.dart';
import '../../features/elements/text/text_toolbar.dart';
import '../../features/elements/code/code_toolbar.dart';
import '../../features/elements/chart/chart_toolbar.dart';
import '../../features/toolbar/command_ui.dart';
import '../menus/slides_menu_spec.dart';
import '../slides_features.dart';

/// The contextual section of the toolbar (Slides 04 §6.2): the controls
/// that follow the selection, Google Slides style. Every control is bound
/// to a command; controls of features that are off ([SlidesFeatures]) are
/// left out until their work package builds them.
List<ToolbarGroup> contextualToolbarGroups(
  SlidesCommandUi ui,
  DeckEditorController ed,
) {
  final l = ui.l;
  final kind = ed.selectionKind;

  // The text controls are SL-13's (`elements/text/text_toolbar.dart`).
  List<ToolbarItem> textControls() => textToolbarItems(ui, ed);

  // Shape, line, icon and fill/border controls are SL-14's
  // (`elements/style/style_toolbar.dart`).
  final style = StyleToolbar(ui, ed);
  List<ToolbarItem> fillBorder() => style.fillBorder();

  final items = switch (kind) {
    DeckSelectionKind.none => [
      ui.button(
        'slides.inspector.open',
        args: const {'tab': 'slide', 'section': 'background'},
        icon: LucideIcons.wallpaper,
        label: l.toolbarBackground,
        keyName: 'background',
        priority: 3,
      ),
      ui.dropdown(
        'layout',
        label: l.toolbarLayout,
        icon: LucideIcons.layoutTemplate,
        priority: 3,
        enabled: ui.state('slides.slide.applyLayout').enabled,
        // The layout gallery with thumbnails (SL-17, 05 §4).
        items: () => [MenuSpec.custom(layoutGallerySlot)],
        custom: MenuCustomItems(
          widgets: {
            layoutGallerySlot: (context, close) => Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutGallery(
                editor: ed,
                columns: 4,
                onSelected: (layout) {
                  close();
                  ui.run('slides.slide.applyLayout', {'layoutId': layout.id});
                },
              ),
            ),
          },
        ),
      ),
      ui.button(
        'slides.panel.themes',
        label: l.toolbarTheme,
        keyName: 'theme',
        priority: 4,
      ),
      if (SlidesFeatures.isOn(SlidesFeature.animations))
        ui.button(
          'slides.panel.animate',
          args: const {'tab': 'transition'},
          icon: LucideIcons.squareStack,
          label: l.toolbarTransition,
          keyName: 'transition',
          priority: 4,
        ),
    ],
    DeckSelectionKind.text => textControls(),
    DeckSelectionKind.shape => [...style.shape(), ...textControls()],
    DeckSelectionKind.line => style.line(),
    DeckSelectionKind.image => [
      ui.button('slides.image.crop', priority: 2),
      ui.button(
        'slides.image.mask',
        icon: LucideIcons.squareDashed,
        priority: 3,
      ),
      ui.button('slides.image.replace', priority: 3),
      ui.button('slides.image.adjust', priority: 4),
      ui.button('slides.format.stroke', priority: 4),
      ui.button('slides.image.reset', priority: 5),
    ],
    DeckSelectionKind.table => [
      ui.button('slides.table.setCellFill', priority: 3),
      ui.button(
        'slides.table.setBorders',
        icon: LucideIcons.grid3x3,
        priority: 3,
      ),
      ui.button(
        'slides.table.setCellAlign',
        icon: LucideIcons.alignVerticalJustifyCenter,
        priority: 4,
      ),
      ...textControls(),
    ],
    // Chart controls (SL-32) are hidden while the feature is off.
    DeckSelectionKind.code
        when !SlidesFeatures.isOn(SlidesFeature.codeBlocks) =>
      const <ToolbarItem>[],
    DeckSelectionKind.chart when !SlidesFeatures.isOn(SlidesFeature.charts) =>
      const <ToolbarItem>[],
    DeckSelectionKind.code => [
      ui.button('slides.code.edit', icon: LucideIcons.squarePen, priority: 2),
      ui.button(
        'slides.code.setLanguage',
        icon: LucideIcons.codeXml,
        label: codeLanguageLabelOf(ed),
        priority: 2,
      ),
      ui.toggle(
        'slides.code.updateOptions',
        args: const {'toggle': 'lineNumbers'},
        icon: LucideIcons.listOrdered,
        keyName: 'code.lineNumbers',
        priority: 3,
      ),
      ui.button(
        'slides.code.setHighlightSteps',
        icon: LucideIcons.highlighter,
        priority: 3,
      ),
      ui.button('slides.code.addState', priority: 3),
      ui.button('slides.code.preview', priority: 4),
      ui.button('slides.code.copy', priority: 5),
    ],
    DeckSelectionKind.chart => chartToolbarItems(ui, l, ed),
    DeckSelectionKind.icon => style.icon(),
    DeckSelectionKind.group || DeckSelectionKind.multiple => [
      ...fillBorder(),
      ui.dropdown(
        'arrangeAlign',
        label: l.menuAlign,
        icon: LucideIcons.alignCenterHorizontal,
        priority: 3,
        enabled: ui.state('slides.arrange.align').enabled,
        items: () => [
          for (final (edge, label) in [
            ('left', l.alignLeft),
            ('center', l.alignCenter),
            ('right', l.alignRight),
            ('top', l.anchorTop),
            ('middle', l.anchorMiddle),
            ('bottom', l.anchorBottom),
          ])
            MenuSpec.command(
              'slides.arrange.align',
              label: label,
              args: {'edge': edge},
              id: 'toolbar.arrangeAlign.$edge',
            ),
          MenuSpec.separator(),
          MenuSpec.command(
            'slides.arrange.distribute',
            label: l.axisHorizontally,
            args: const {'axis': 'horizontal'},
            id: 'toolbar.distribute.horizontal',
          ),
          MenuSpec.command(
            'slides.arrange.distribute',
            label: l.axisVertically,
            args: const {'axis': 'vertical'},
            id: 'toolbar.distribute.vertical',
          ),
        ],
      ),
      ui.button('slides.arrange.group', priority: 3),
      ui.button('slides.arrange.ungroup', priority: 3),
      ui.dropdown(
        'order',
        label: l.menuOrder,
        icon: LucideIcons.bringToFront,
        priority: 4,
        enabled: ui.state('slides.arrange.order').enabled,
        items: () => orderItems(l, 'toolbar.order'),
      ),
    ],
  };
  return [ToolbarGroup(items, id: 'contextual.${kind.name}')];
}
