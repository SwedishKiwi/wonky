import 'package:wonky_core/wonky_core.dart';

import '../../features/editor_screen/deck_editor_controller.dart'
    show DeckSelectionKind;
import '../../l10n/slides_l10n.dart';
import 'slides_menu_spec.dart';

/// Ids of the Slides context menus (04 §11; MCP `ui.get_menu_tree {menu:
/// 'context.&lt;id&gt;'}` with SL-42).
abstract final class SlidesContextMenuIds {
  static const slide = 'context.slide';
  static const element = 'context.element';
  static const text = 'context.text';
  static const table = 'context.table';
  static const navigatorSlide = 'context.navigatorSlide';
  static const navigatorGroup = 'context.navigatorGroup';
  static const navigatorEmpty = 'context.navigatorEmpty';

  static const all = [
    slide,
    element,
    text,
    table,
    navigatorSlide,
    navigatorGroup,
    navigatorEmpty,
  ];
}

MenuCommand _c(
  String id, {
  String? label,
  Map<String, Object?> args = const {},
  String? menuId,
}) => MenuSpec.command(id, label: label, args: args, id: menuId);

/// Every Slides context menu as one tree (a submenu per menu, id =
/// `context.<name>`): rendered with the shell's `MenuResolver`, so the
/// items, states, reasons and shortcuts are the commands' (04 §11).
MenuRoot slidesContextMenus(SlidesLocalizations l) => MenuSpec.root([
  for (final id in SlidesContextMenuIds.all)
    MenuSpec.submenu(id, id, contextMenuItems(l, id)),
]);

/// The items of context menu [id] (`SlidesContextMenuIds`).
List<MenuSpec> contextMenuItems(SlidesLocalizations l, String id) =>
    switch (id) {
      SlidesContextMenuIds.slide => _slide(l),
      SlidesContextMenuIds.element => _element(l),
      SlidesContextMenuIds.text => _text(l),
      SlidesContextMenuIds.table => _table(l),
      SlidesContextMenuIds.navigatorSlide => _navigatorSlide(l),
      SlidesContextMenuIds.navigatorGroup => _navigatorGroup(l),
      SlidesContextMenuIds.navigatorEmpty => _navigatorEmpty(l),
      _ => const [],
    };

/// The items of context menu [id] for a selection of [kind]: the element
/// menu keeps only the kind additions of the selected kind (04 §11.2:
/// image, code, chart submenus; *Edit text*; *Enter group*).
List<MenuSpec> contextMenuFor(
  SlidesLocalizations l,
  String id,
  DeckSelectionKind kind,
) {
  final items = contextMenuItems(l, id);
  if (id != SlidesContextMenuIds.element) return items;
  bool keep(MenuSpec m) => switch (m.effectiveId) {
    'context.element.image' => kind == DeckSelectionKind.image,
    'context.element.code' => kind == DeckSelectionKind.code,
    'context.element.chart' => kind == DeckSelectionKind.chart,
    'context.element.enterGroup' => kind == DeckSelectionKind.group,
    'context.element.editText' =>
      kind == DeckSelectionKind.text || kind == DeckSelectionKind.shape,
    _ => true,
  };
  return [
    for (final m in items)
      if (keep(m)) m,
  ];
}

// §11.1 Canvas, empty slide area.
List<MenuSpec> _slide(SlidesLocalizations l) => [
  _c('shell.edit.paste', menuId: 'context.slide.paste'),
  _c('shell.edit.pasteWithoutFormatting', menuId: 'context.slide.pastePlain'),
  MenuSpec.separator(),
  _c('slides.slide.new', menuId: 'context.slide.new'),
  _c('slides.slide.duplicate', menuId: 'context.slide.duplicate'),
  _c('slides.slide.toggleSkip', menuId: 'context.slide.skip'),
  MenuSpec.separator(),
  MenuSpec.submenu('context.slide.applyLayout', l.menuApplyLayout, [
    MenuSpec.custom(SlidesMenuIds.applyLayouts),
  ]),
  _c(
    'slides.inspector.open',
    label: l.menuChangeBackground,
    args: const {'tab': 'slide', 'section': 'background'},
    menuId: 'context.slide.background',
  ),
  _c(
    'slides.panel.animate',
    label: l.menuTransition,
    args: const {'tab': 'transition'},
    menuId: 'context.slide.transition',
  ),
  MenuSpec.separator(),
  _c(
    'shell.comments.create',
    label: l.menuCommentOnSlide,
    args: const {'anchor': 'slide'},
    menuId: 'context.slide.comment',
  ),
  MenuSpec.separator(),
  _c(
    'slides.view.setMode',
    label: l.menuEditLayout,
    args: const {'mode': 'masters'},
    menuId: 'context.slide.editLayout',
  ),
  MenuSpec.submenu('context.slide.guides', l.menuGuides, [
    _c(
      'slides.guides.add',
      label: l.guidesAddVertical,
      args: const {'axis': 'vertical'},
      menuId: 'context.slide.guides.vertical',
    ),
    _c(
      'slides.guides.add',
      label: l.guidesAddHorizontal,
      args: const {'axis': 'horizontal'},
      menuId: 'context.slide.guides.horizontal',
    ),
    _c('slides.guides.clear', menuId: 'context.slide.guides.clear'),
  ]),
  _c('shell.edit.selectAll', menuId: 'context.slide.selectAll'),
];

// §11.2 Element.
List<MenuSpec> _element(SlidesLocalizations l) => [
  _c('slides.element.activate', menuId: 'context.element.editText'),
  MenuSpec.submenu('context.element.image', l.menuImage, [
    _c('slides.image.crop', menuId: 'context.element.image.crop'),
    _c('slides.image.mask', menuId: 'context.element.image.mask'),
    _c('slides.image.replace', menuId: 'context.element.image.replace'),
    _c('slides.image.reset', menuId: 'context.element.image.reset'),
    _c(
      'slides.image.downloadOriginal',
      menuId: 'context.element.image.download',
    ),
  ]),
  MenuSpec.submenu('context.element.code', l.menuCode, [
    _c('slides.code.edit', menuId: 'context.element.code.edit'),
    _c('slides.code.setLanguage', menuId: 'context.element.code.language'),
    _c('slides.code.addState', menuId: 'context.element.code.addState'),
  ]),
  MenuSpec.submenu('context.element.chart', l.menuChart, [
    _c('slides.chart.update', menuId: 'context.element.chart.update'),
    _c('slides.chart.openSource', menuId: 'context.element.chart.source'),
    _c('slides.chart.unlink', menuId: 'context.element.chart.unlink'),
    _c('slides.chart.copyAsImage', menuId: 'context.element.chart.copyImage'),
  ]),
  _c('slides.select.enterGroup', menuId: 'context.element.enterGroup'),
  MenuSpec.separator(),
  _c('shell.edit.cut', menuId: 'context.element.cut'),
  _c('shell.edit.copy', menuId: 'context.element.copy'),
  _c('shell.edit.paste', menuId: 'context.element.paste'),
  _c('slides.edit.duplicate', menuId: 'context.element.duplicate'),
  _c('slides.edit.delete', menuId: 'context.element.delete'),
  _c('slides.format.copyStyle', menuId: 'context.element.copyStyle'),
  _c('slides.format.pasteStyle', menuId: 'context.element.pasteStyle'),
  MenuSpec.separator(),
  MenuSpec.submenu(
    'context.element.order',
    l.menuOrder,
    orderItems(l, 'context.element.order'),
  ),
  MenuSpec.submenu('context.element.align', l.menuAlign, [
    for (final (edge, label) in [
      ('left', l.alignLeft),
      ('center', l.alignCenter),
      ('right', l.alignRight),
      ('top', l.anchorTop),
      ('middle', l.anchorMiddle),
      ('bottom', l.anchorBottom),
    ])
      _c(
        'slides.arrange.align',
        label: label,
        args: {'edge': edge},
        menuId: 'context.element.align.$edge',
      ),
  ]),
  _c('slides.arrange.group', menuId: 'context.element.group'),
  _c('slides.arrange.ungroup', menuId: 'context.element.ungroup'),
  MenuSpec.submenu(
    'context.element.rotate',
    l.menuRotate,
    rotateItems(l, 'context.element.rotate'),
  ),
  _c('slides.element.toggleLock', menuId: 'context.element.lock'),
  _c('slides.element.hide', menuId: 'context.element.hide'),
  MenuSpec.separator(),
  MenuSpec.submenu('context.element.animate', l.menuAnimate, [
    for (final (kind, label) in [
      ('in', l.animateAddBuildIn),
      ('action', l.animateAddAction),
      ('out', l.animateAddBuildOut),
    ])
      _c(
        'slides.animate.addBuild',
        label: label,
        args: {'kind': kind},
        menuId: 'context.element.animate.$kind',
      ),
    MenuSpec.separator(),
    _c('slides.animate.copyBuilds', menuId: 'context.element.animate.copy'),
    _c('slides.animate.pasteBuilds', menuId: 'context.element.animate.paste'),
    _c('slides.animate.deleteBuilds', menuId: 'context.element.animate.remove'),
  ]),
  _c(
    'slides.inspector.open',
    label: l.menuMagicMoveId,
    args: const {'tab': 'format', 'section': 'arrange'},
    menuId: 'context.element.matchKey',
  ),
  _c('slides.element.setLink', menuId: 'context.element.link'),
  _c('slides.element.removeLink', menuId: 'context.element.removeLink'),
  _c('slides.element.editAltText', menuId: 'context.element.altText'),
  _c(
    'shell.comments.create',
    args: const {'anchor': 'element'},
    menuId: 'context.element.comment',
  ),
  _c('slides.element.resetPlaceholder', menuId: 'context.element.reset'),
  _c(
    'slides.inspector.open',
    label: l.menuFormatOptions,
    args: const {'tab': 'format'},
    menuId: 'context.element.formatOptions',
  ),
];

// §11.3 Text editing.
List<MenuSpec> _text(SlidesLocalizations l) => [
  _c('shell.edit.cut', menuId: 'context.text.cut'),
  _c('shell.edit.copy', menuId: 'context.text.copy'),
  _c('shell.edit.paste', menuId: 'context.text.paste'),
  _c('shell.edit.pasteWithoutFormatting', menuId: 'context.text.pastePlain'),
  MenuSpec.separator(),
  _c('slides.insert.link', menuId: 'context.text.link'),
  _c('shell.comments.create', menuId: 'context.text.comment'),
  MenuSpec.separator(),
  MenuSpec.submenu('context.text.style', l.menuTextStyle, [
    for (final key in textStyleKeys)
      _c(
        'slides.format.textStyle',
        label: textStyleLabel(l, key),
        args: {'key': key},
        menuId: 'context.text.style.$key',
      ),
  ]),
  MenuSpec.submenu('context.text.lists', l.menuLists, [
    for (final (v, label) in [
      ('bullet', l.listBulleted),
      ('number', l.listNumbered),
      ('check', l.listChecklist),
    ])
      _c(
        'slides.format.list',
        label: label,
        args: {'type': v},
        menuId: 'context.text.lists.$v',
      ),
  ]),
  _c('slides.format.clear', menuId: 'context.text.clear'),
  MenuSpec.separator(),
  MenuSpec.submenu('context.text.ai', l.menuAi, [
    for (final (mode, label) in [
      ('shorter', l.rewriteShorter),
      ('longer', l.rewriteLonger),
      ('clearer', l.rewriteClearer),
      ('formal', l.rewriteFormal),
      ('grammar', l.rewriteGrammar),
    ])
      _c(
        'slides.ai.rewrite',
        label: label,
        args: {'mode': mode},
        menuId: 'context.text.ai.$mode',
      ),
  ]),
];

// §11.4 Table cells.
List<MenuSpec> _table(SlidesLocalizations l) => [
  _c('shell.edit.cut', menuId: 'context.table.cut'),
  _c('shell.edit.copy', menuId: 'context.table.copy'),
  _c('shell.edit.paste', menuId: 'context.table.paste'),
  MenuSpec.separator(),
  ...tableItems(l, 'context.table'),
  _c('slides.table.delete', menuId: 'context.table.delete'),
  MenuSpec.separator(),
  _c('slides.table.setCellFill', menuId: 'context.table.fill'),
  _c('slides.table.setBorders', menuId: 'context.table.borders'),
  _c('slides.table.setCellAlign', menuId: 'context.table.align'),
];

// §11.5 Navigator slide.
List<MenuSpec> _navigatorSlide(SlidesLocalizations l) => [
  _c('slides.slide.new', menuId: 'context.nav.new'),
  _c('slides.slide.duplicate', menuId: 'context.nav.duplicate'),
  _c('slides.slide.delete', menuId: 'context.nav.delete'),
  _c('slides.slide.toggleSkip', menuId: 'context.nav.skip'),
  MenuSpec.separator(),
  _c('shell.edit.cut', menuId: 'context.nav.cut'),
  _c('shell.edit.copy', menuId: 'context.nav.copy'),
  _c('shell.edit.paste', menuId: 'context.nav.paste'),
  MenuSpec.separator(),
  _c('slides.group.create', menuId: 'context.nav.group'),
  MenuSpec.submenu('context.nav.addToGroup', l.menuAddToGroup, [
    MenuSpec.custom(SlidesMenuIds.addToGroup),
  ]),
  _c('slides.group.removeSlides', menuId: 'context.nav.ungroupSlides'),
  MenuSpec.separator(),
  _c(
    'slides.slide.move',
    label: l.moveToBeginning,
    args: const {'to': 'start'},
    menuId: 'context.nav.moveStart',
  ),
  _c(
    'slides.slide.move',
    label: l.moveToEnd,
    args: const {'to': 'end'},
    menuId: 'context.nav.moveEnd',
  ),
  MenuSpec.separator(),
  MenuSpec.submenu('context.nav.applyLayout', l.menuApplyLayout, [
    MenuSpec.custom(SlidesMenuIds.applyLayouts),
  ]),
  _c(
    'slides.inspector.open',
    label: l.menuChangeBackground,
    args: const {'tab': 'slide', 'section': 'background'},
    menuId: 'context.nav.background',
  ),
  _c(
    'slides.panel.animate',
    label: l.menuTransition,
    args: const {'tab': 'transition'},
    menuId: 'context.nav.transition',
  ),
  MenuSpec.separator(),
  _c(
    'shell.comments.create',
    label: l.menuCommentOnSlide,
    args: const {'anchor': 'slide'},
    menuId: 'context.nav.comment',
  ),
  _c('slides.present.fromSlide', menuId: 'context.nav.present'),
];

// §11.6 Navigator group header.
List<MenuSpec> _navigatorGroup(SlidesLocalizations l) => [
  _c('slides.group.startRename', menuId: 'context.group.rename'),
  MenuSpec.submenu('context.group.color', l.menuGroupColor, [
    for (final color in slideGroupColors)
      _c(
        'slides.group.setColor',
        label: groupColorLabel(l, color),
        args: {'color': color},
        menuId: 'context.group.color.$color',
      ),
    _c(
      'slides.group.setColor',
      label: l.colorNone,
      args: const {'color': null},
      menuId: 'context.group.color.none',
    ),
  ]),
  _c('slides.group.collapse', menuId: 'context.group.collapse'),
  _c('slides.group.expand', menuId: 'context.group.expand'),
  _c('slides.group.collapseAll', menuId: 'context.group.collapseAll'),
  _c('slides.group.expandAll', menuId: 'context.group.expandAll'),
  MenuSpec.separator(),
  _c(
    'slides.slide.new',
    label: l.menuNewSlideInGroup,
    args: const {'inGroup': true},
    menuId: 'context.group.newSlide',
  ),
  _c('slides.group.selectSlides', menuId: 'context.group.select'),
  _c('slides.group.duplicate', menuId: 'context.group.duplicate'),
  _c('shell.edit.cut', menuId: 'context.group.cut'),
  _c('shell.edit.copy', menuId: 'context.group.copy'),
  _c('shell.edit.paste', menuId: 'context.group.paste'),
  _c('slides.group.toggleSkip', menuId: 'context.group.skip'),
  MenuSpec.separator(),
  _c('slides.group.ungroup', menuId: 'context.group.ungroup'),
  _c('slides.group.delete', menuId: 'context.group.delete'),
  MenuSpec.separator(),
  _c(
    'slides.present.fromSlide',
    label: l.menuPresentFromGroup,
    menuId: 'context.group.present',
  ),
];

// §11.7 Navigator empty area.
List<MenuSpec> _navigatorEmpty(SlidesLocalizations l) => [
  _c('slides.slide.new', menuId: 'context.navEmpty.new'),
  _c('shell.edit.paste', menuId: 'context.navEmpty.paste'),
  _c(
    'slides.group.create',
    label: l.menuNewGroup,
    args: const {'slideIds': <String>[]},
    menuId: 'context.navEmpty.newGroup',
  ),
  _c('slides.group.collapseAll', menuId: 'context.navEmpty.collapseAll'),
  _c('slides.group.expandAll', menuId: 'context.navEmpty.expandAll'),
];
