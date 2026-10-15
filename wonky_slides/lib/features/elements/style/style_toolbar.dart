import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_core/wonky_core.dart' show InvocationSource, MenuSpec;
import 'package:wonky_slides_core/icons.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/themes.dart' show ResolvedTheme;
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../toolbar/command_ui.dart';
import '../line/line_tool.dart';
import '../shape/shape_gallery.dart';
import 'element_style.dart';
import 'style_sections.dart' show dashStyles, strokeWeights;

/// The contextual toolbar controls of shapes, lines, icons and
/// multi-selections (Slides 04 §6.2): fill and border split buttons with
/// the color picker, weight and dash menus, quick styles, *Change shape*
/// (gallery), arrowheads and routing, icon color / stroke width / replace.
class StyleToolbar {
  StyleToolbar(this.ui, this.ed);

  final SlidesCommandUi ui;
  final DeckEditorController ed;

  String _fmt(double w) => w == w.roundToDouble() ? '${w.toInt()}' : '$w';

  List<ResolvedElement> get _targets => ElementStyle.targets(ed);

  void _run(String id, Map<String, Object?> args) =>
      ui.run(id, args, InvocationSource.toolbar);

  /// Fill split button: the button applies the theme default… the last
  /// picked color; the chevron opens the picker.
  ToolbarItem fill({int priority = 3}) {
    final l = ui.l;
    final theme = ElementStyle.themeOf(ed);
    final els = [
      for (final e in _targets)
        if (ElementStyle.hasFill(e.record.kind)) e,
    ];
    final argb = theme == null
        ? null
        : ElementStyle.common(els, (e) => ElementStyle.fillArgb(e, theme));
    final st = ui.state('slides.format.fill', const {'none': true});
    return ToolbarSplitButton(
      id: 'slides.toolbar.fill',
      priority: priority,
      icon: LucideIcons.paintBucket,
      label: l.menuFillColor,
      indicatorColor: argb == null ? null : Color(argb),
      enabled: st.enabled,
      onPressed: () => _run('slides.format.fill', {'color': _lastFill}),
      entries: () => [
        WonkyMenuCustom(
          label: l.menuFillColor,
          builder: (context, close) => WonkyColorPicker(
            themeColors: ElementStyle.swatches(theme, l),
            resetLabel: l.colorThemeDefault,
            allowAlpha: true,
            onChanged: (c) {
              close();
              final ref = c == null ? null : ElementStyle.colorRefOf(c);
              if (ref != null) _lastFill = ref;
              _run('slides.format.fill', {'color': ref});
            },
          ),
        ),
        const WonkyMenuSeparator(),
        ui.item(
          'slides.format.fill',
          args: const {'none': true},
          label: l.styleLabelNoFill,
          keyName: 'toolbar.fill.none',
        ),
      ],
    );
  }

  /// Border (or line / icon) color split button.
  ToolbarItem strokeColor({
    required String keyName,
    required String label,
    IconData icon = LucideIcons.squareDashed,
    bool noneItem = true,
    int priority = 3,
  }) {
    final l = ui.l;
    final theme = ElementStyle.themeOf(ed);
    final els = [
      for (final e in _targets)
        if (ElementStyle.hasStroke(e.record.kind)) e,
    ];
    final argb = theme == null
        ? null
        : ElementStyle.common(els, (e) => ElementStyle.strokeArgb(e, theme));
    final st = ui.state('slides.format.stroke', const {'reset': true});
    return ToolbarSplitButton(
      id: 'slides.toolbar.$keyName',
      priority: priority,
      icon: icon,
      label: label,
      indicatorColor: argb == null ? null : Color(argb),
      enabled: st.enabled,
      onPressed: () => _run('slides.format.stroke', {'color': _lastStroke}),
      entries: () => [
        WonkyMenuCustom(
          label: label,
          builder: (context, close) => WonkyColorPicker(
            themeColors: ElementStyle.swatches(theme, l),
            resetLabel: l.colorThemeDefault,
            allowAlpha: true,
            onChanged: (c) {
              close();
              if (c == null) {
                _run('slides.format.stroke', const {'reset': true});
                return;
              }
              _lastStroke = ElementStyle.colorRefOf(c);
              _run('slides.format.stroke', {'color': _lastStroke});
            },
          ),
        ),
        if (noneItem) ...[
          const WonkyMenuSeparator(),
          ui.item(
            'slides.format.stroke',
            args: const {'none': true},
            label: l.styleLabelNoBorder,
            keyName: 'toolbar.$keyName.none',
          ),
        ],
      ],
    );
  }

  /// Weight menu.
  ToolbarItem weight({int priority = 4}) => ui.dropdown(
    'strokeWeight',
    label: ui.l.menuWeight,
    icon: LucideIcons.minus,
    priority: priority,
    enabled: ui.state('slides.format.stroke', const {'width': 2}).enabled,
    items: () => [
      for (final w in strokeWeights)
        MenuSpec.command(
          'slides.format.stroke',
          label: ui.l.strokeWidthLabel(_fmt(w)),
          args: {'width': w},
          id: 'toolbar.strokeWeight.${_fmt(w)}',
        ),
    ],
  );

  /// Dash menu.
  ToolbarItem dash({int priority = 4}) => ui.dropdown(
    'strokeDash',
    label: ui.l.menuDash,
    icon: LucideIcons.ellipsis,
    priority: priority,
    enabled: ui.state('slides.format.stroke', const {'dash': 'solid'}).enabled,
    items: () => [
      for (final d in dashStyles)
        MenuSpec.command(
          'slides.format.stroke',
          label: ui.l.dashName(d),
          args: {'dash': d},
          id: 'toolbar.strokeDash.$d',
        ),
    ],
  );

  /// Quick styles menu (03 §6.3).
  ToolbarItem quickStyles({int priority = 4}) => ui.dropdown(
    'quickStyles',
    label: ui.l.menuQuickStyles,
    icon: LucideIcons.palette,
    priority: priority,
    enabled: ui.state('slides.shape.applyQuickStyle', const {
      'index': 0,
    }).enabled,
    items: () => quickStyleItems(ui.l, ElementStyle.themeOf(ed), 'toolbar'),
  );

  /// *Change shape* with the gallery.
  ToolbarItem changeShape({int priority = 4}) {
    final l = ui.l;
    final shapes = [
      for (final e in _targets)
        if (e.record.kind == ElementKind.shape) e,
    ];
    final current = ElementStyle.common(
      shapes,
      (e) => e.data?['geometry'] as String?,
    );
    return ToolbarDropdownButton(
      id: 'slides.toolbar.changeShape',
      priority: priority,
      label: l.menuChangeShape,
      icon: LucideIcons.shapes,
      enabled: ui.state('slides.shape.change', const {
        'geometry': 'rect',
      }).enabled,
      entries: () => [
        WonkyMenuCustom(
          label: l.menuChangeShape,
          builder: (context, close) => ShapeGallery(
            selected: current,
            onSelected: (g) {
              close();
              _run('slides.shape.change', {'geometry': g});
            },
          ),
        ),
      ],
    );
  }

  /// Start / end arrow menus.
  ToolbarItem arrow(String end, {int priority = 3}) {
    final l = ui.l;
    return ui.dropdown(
      '${end}Arrow',
      label: end == 'start' ? l.lineStartArrow : l.lineEndArrow,
      icon: end == 'start' ? LucideIcons.arrowLeft : LucideIcons.arrowRight,
      priority: priority,
      enabled: ui.state('slides.line.setArrow', {
        'end': end,
        'style': 'none',
      }).enabled,
      items: () => arrowItems(l, end, 'toolbar'),
    );
  }

  /// Routing menu.
  ToolbarItem routing({int priority = 4}) => ui.dropdown(
    'routing',
    label: ui.l.menuRouting,
    icon: LucideIcons.spline,
    priority: priority,
    enabled: ui.state('slides.line.setRouting', const {
      'routing': 'straight',
    }).enabled,
    items: () => routingItems(ui.l, 'toolbar'),
  );

  /// Icon stroke width menu.
  ToolbarItem iconStroke({int priority = 4}) => ui.dropdown(
    'iconStroke',
    label: ui.l.styleLabelStrokeWidth,
    icon: LucideIcons.penLine,
    priority: priority,
    enabled: ui.state('slides.icon.setStrokeWidth', const {'value': 2}).enabled,
    items: () => [
      for (final w in LucideGlyphs.strokeWidths)
        MenuSpec.command(
          'slides.icon.setStrokeWidth',
          label: _fmt(w),
          args: {'value': w},
          id: 'toolbar.iconStroke.${_fmt(w)}',
          radio: true,
        ),
    ],
  );

  /// The controls of a shape selection (before the text controls).
  List<ToolbarItem> shape() => [
    fill(),
    strokeColor(keyName: 'border', label: ui.l.menuBorderColor),
    weight(),
    dash(priority: 5),
    quickStyles(),
    changeShape(),
  ];

  /// The controls of a line selection.
  List<ToolbarItem> line() => [
    strokeColor(
      keyName: 'lineColor',
      label: ui.l.menuLineColor,
      icon: LucideIcons.pencilLine,
      noneItem: false,
    ),
    weight(priority: 3),
    dash(),
    arrow('start'),
    arrow('end'),
    routing(),
  ];

  /// The controls of an icon selection.
  List<ToolbarItem> icon() => [
    strokeColor(
      keyName: 'iconColor',
      label: ui.l.menuIconColor,
      icon: LucideIcons.palette,
      noneItem: false,
    ),
    iconStroke(),
    ui.button('slides.icon.replace', priority: 3),
  ];

  /// Fill and border of a multi-selection.
  List<ToolbarItem> fillBorder() => [
    fill(),
    strokeColor(keyName: 'border', label: ui.l.menuBorderColor),
  ];

  static String _lastFill = 'theme:accent1';
  static String _lastStroke = 'theme:text1';
}

/// Quick style menu items (Format › Shape › Quick styles ▸, toolbar).
List<MenuSpec> quickStyleItems(
  SlidesLocalizations l,
  ResolvedTheme? theme,
  String prefix,
) => [
  for (var i = 0; i < ElementStyle.quickStyles(theme).length; i++)
    MenuSpec.command(
      'slides.shape.applyQuickStyle',
      label: l.quickStyleName('$i'),
      args: {'index': i},
      id: '$prefix.quickStyle.$i',
    ),
];

/// Arrowhead items of one line end (menus, toolbar).
List<MenuSpec> arrowItems(SlidesLocalizations l, String end, String prefix) => [
  for (final style in arrowStyles)
    MenuSpec.command(
      'slides.line.setArrow',
      label: l.arrowStyleName(style),
      args: {'end': end, 'style': style},
      id: '$prefix.arrow.$end.$style',
    ),
];

/// Routing items (menus, toolbar).
List<MenuSpec> routingItems(SlidesLocalizations l, String prefix) => [
  for (final r in lineRoutings)
    MenuSpec.command(
      'slides.line.setRouting',
      label: l.routingName(r),
      args: {'routing': r},
      id: '$prefix.routing.$r',
      radio: true,
    ),
];
