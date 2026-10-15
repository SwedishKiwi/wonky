import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../features/editor_screen/deck_editor_controller.dart';
import '../../features/editor_screen/slide_labels.dart';
import '../../features/toolbar/command_ui.dart';
import '../menus/slides_menu_spec.dart';

/// The contextual section of the toolbar (Slides 04 §6.2): the controls
/// that follow the selection, Google Slides style. Every control is bound
/// to a command; features that are not built yet show their (disabled)
/// placeholder commands, so the toolbar is complete from the start and the
/// work package that builds a feature only fills in the handler (or swaps a
/// button for a richer control here, e.g. the font picker of SL-13).
List<ToolbarGroup> contextualToolbarGroups(
  SlidesCommandUi ui,
  DeckEditorController ed,
) {
  final l = ui.l;
  final kind = ed.selectionKind;

  List<ToolbarItem> textControls() => [
    ui.dropdown(
      'textStyle',
      label: l.menuTextStyle,
      priority: 2,
      enabled: ui.state('slides.format.textStyle').enabled,
      items: () => [
        for (final key in textStyleKeys)
          MenuSpec.command(
            'slides.format.textStyle',
            label: textStyleLabel(l, key),
            args: {'key': key},
            id: 'toolbar.textStyle.$key',
          ),
      ],
    ),
    ui.button('slides.format.font', priority: 3),
    ui.button('slides.format.decreaseFontSize', priority: 3),
    ui.button('slides.format.increaseFontSize', priority: 3),
    ui.toggle('slides.format.bold', priority: 2),
    ui.toggle('slides.format.italic', priority: 2),
    ui.toggle('slides.format.underline', priority: 3),
    ui.button('slides.format.textColor', priority: 3),
    ui.button('slides.format.highlight', priority: 4),
    ui.button('slides.insert.link', priority: 4),
    ui.dropdown(
      'align',
      label: l.toolbarAlign,
      icon: LucideIcons.alignLeft,
      priority: 4,
      enabled: ui.state('slides.format.align').enabled,
      items: () => [
        for (final (v, label) in [
          ('left', l.alignLeft),
          ('center', l.alignCenter),
          ('right', l.alignRight),
          ('justify', l.alignJustify),
        ])
          MenuSpec.command(
            'slides.format.align',
            label: label,
            args: {'value': v},
            id: 'toolbar.align.$v',
          ),
        MenuSpec.separator(),
        for (final (v, label) in [
          ('top', l.anchorTop),
          ('middle', l.anchorMiddle),
          ('bottom', l.anchorBottom),
        ])
          MenuSpec.command(
            'slides.format.anchor',
            label: label,
            args: {'value': v},
            id: 'toolbar.anchor.$v',
          ),
      ],
    ),
    ui.dropdown(
      'lists',
      label: l.menuLists,
      icon: LucideIcons.list,
      priority: 4,
      enabled: ui.state('slides.format.list').enabled,
      items: () => [
        for (final (v, label) in [
          ('bullet', l.listBulleted),
          ('number', l.listNumbered),
          ('check', l.listChecklist),
        ])
          MenuSpec.command(
            'slides.format.list',
            label: label,
            args: {'type': v},
            id: 'toolbar.lists.$v',
          ),
      ],
    ),
    ui.button('slides.format.lineHeight', priority: 5),
    ui.button('slides.format.outdent', priority: 5),
    ui.button('slides.format.indent', priority: 5),
    ui.button('slides.format.clear', priority: 5),
  ];

  List<ToolbarItem> fillBorder() => [
    ui.button('slides.format.fill', priority: 3),
    ui.button('slides.format.stroke', priority: 3),
  ];

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
        items: () => [
          for (final layout in SlideLabels.layouts(ed.model))
            MenuSpec.command(
              'slides.slide.applyLayout',
              label: layout.name,
              args: {'layoutId': layout.id},
              id: 'toolbar.layout.${layout.id}',
            ),
        ],
      ),
      ui.button(
        'slides.panel.themes',
        label: l.toolbarTheme,
        keyName: 'theme',
        priority: 4,
      ),
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
    DeckSelectionKind.shape => [
      ...fillBorder(),
      ui.button(
        'slides.shape.applyQuickStyle',
        icon: LucideIcons.palette,
        priority: 4,
      ),
      ui.button('slides.shape.change', icon: LucideIcons.shapes, priority: 4),
      ...textControls(),
    ],
    DeckSelectionKind.line => [
      ui.button('slides.format.stroke', priority: 3),
      ui.button('slides.line.setArrow', priority: 3),
      ui.button('slides.line.setRouting', priority: 4),
    ],
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
    DeckSelectionKind.code => [
      ui.button(
        'slides.code.setLanguage',
        icon: LucideIcons.codeXml,
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
    ],
    DeckSelectionKind.chart => [
      ui.button('slides.chart.update', priority: 2),
      ui.button('slides.chart.openSource', priority: 3),
    ],
    DeckSelectionKind.icon => [
      ui.button('slides.format.fill', priority: 3),
      ui.button('slides.format.stroke', priority: 4),
    ],
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
