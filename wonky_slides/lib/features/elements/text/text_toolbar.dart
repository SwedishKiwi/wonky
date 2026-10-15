import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' show ResolvedSlide;
import 'package:wonky_slides_core/themes.dart' show ResolvedTheme;
import 'package:wonky_ui/wonky_ui.dart';

import '../../../commands/text_commands.dart'
    show fontOptions, listStyleKeys, listStyleLabel;
import '../../../config/menus/slides_menu_spec.dart'
    show textStyleKeys, textStyleLabel;
import '../../editor_screen/deck_editor_controller.dart';
import '../../text_editing/text_format.dart';
import '../../toolbar/command_ui.dart';
import '../style/element_style.dart';

/// The last colors applied from the split buttons (repeat on click).
String _lastText = 'theme:accent1';
String _lastHighlight = '#FFF59D';

/// The text controls of the contextual toolbar (04 §6.2, *Text*): text
/// style, font, size, **B** *I* U, text color, highlight, link, alignment,
/// lists, line spacing, indent and clear formatting. Values mirror the
/// selection ([TextFormatState]); every control invokes a command.
List<ToolbarItem> textToolbarItems(
  SlidesCommandUi ui,
  DeckEditorController ed,
) {
  final l = ui.l;
  final scope = TextFormatScope.of(ed);
  final st = TextFormatState.of(scope);
  final ResolvedSlide? slide = scope.isEmpty ? null : scope.targets.first.slide;
  final theme = slide?.theme;
  final fonts = fontOptions(l);
  return [
    ui.dropdown(
      'textStyle',
      label: st.styleKey == null
          ? l.menuTextStyle
          : textStyleLabel(l, st.styleKey!),
      tooltip: l.menuTextStyle,
      priority: 2,
      minWidth: 72,
      enabled: ui.state('slides.format.textStyle').enabled,
      items: () => [
        for (final key in textStyleKeys)
          MenuSpec.command(
            'slides.format.textStyle',
            label: textStyleLabel(l, key),
            args: {'key': key},
            id: 'toolbar.textStyle.$key',
            radio: true,
          ),
      ],
    ),
    ui.dropdown(
      'font',
      label: st.fontRef != null && fonts.containsKey(st.fontRef)
          ? fonts[st.fontRef]!
          : (st.font ?? l.cmdFormatFont),
      tooltip: l.cmdFormatFont,
      priority: 3,
      minWidth: 64,
      enabled: ui.state('slides.format.font').enabled,
      items: () => [
        for (final MapEntry(:key, :value) in fonts.entries) ...[
          MenuSpec.command(
            'slides.format.font',
            label: value,
            args: {'family': key},
            id: 'toolbar.font.$key',
          ),
          if (key == '@mono') MenuSpec.separator(),
        ],
      ],
    ),
    ToolbarNumberField(
      id: 'slides.toolbar.fontSize',
      enabled: ui.state('slides.format.fontSize').enabled,
      priority: 2,
      label: l.fontSizeLabel,
      value: st.size?.round(),
      min: 6,
      max: 800,
      onChanged: (v) =>
          ui.run('slides.format.fontSize', {'size': v.toDouble()}),
    ),
    ui.toggle('slides.format.bold', priority: 1),
    ui.toggle('slides.format.italic', priority: 1),
    ui.toggle('slides.format.underline', priority: 2),
    _colorButton(
      ui,
      id: 'slides.format.textColor',
      key: 'textColor',
      icon: LucideIcons.baseline,
      label: l.cmdFormatTextColor,
      current: st.colorRef,
      indicator: st.color == null ? null : Color(st.color!),
      reset: l.colorAutomatic,
      theme: theme,
      last: () => _lastText,
      remember: (c) => _lastText = c,
    ),
    _colorButton(
      ui,
      id: 'slides.format.highlight',
      key: 'highlight',
      icon: LucideIcons.highlighter,
      label: l.cmdFormatHighlight,
      current: st.highlight,
      indicator: st.highlight == null || theme == null
          ? null
          : Color(theme.colorString(st.highlight)),
      reset: l.colorNone,
      theme: theme,
      last: () => _lastHighlight,
      remember: (c) => _lastHighlight = c,
    ),
    ui.button('slides.insert.link', priority: 4),
    ui.dropdown(
      'align',
      label: l.toolbarAlign,
      icon: switch (st.align) {
        'center' => LucideIcons.alignCenter,
        'right' => LucideIcons.alignRight,
        'justify' => LucideIcons.alignJustify,
        _ => LucideIcons.alignLeft,
      },
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
            radio: true,
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
            radio: true,
          ),
      ],
    ),
    ui.dropdown(
      'lists',
      label: l.menuLists,
      icon: st.list == 'ordered'
          ? LucideIcons.listOrdered
          : (st.list == 'check' ? LucideIcons.listChecks : LucideIcons.list),
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
            radio: true,
          ),
        MenuSpec.separator(),
        for (final k in listStyleKeys)
          MenuSpec.command(
            'slides.format.listStyle',
            label: listStyleLabel(l, k),
            args: {'style': k},
            id: 'toolbar.listStyle.$k',
          ),
        MenuSpec.separator(),
        MenuSpec.command('slides.format.listStart', id: 'toolbar.listStart'),
      ],
    ),
    ui.dropdown(
      'lineHeight',
      label: l.cmdFormatLineHeight,
      icon: LucideIcons.listCollapse,
      priority: 5,
      enabled: ui.state('slides.format.lineHeight').enabled,
      items: () => [
        for (final (v, label) in [
          (1.0, l.spacingSingle),
          (1.15, '1.15'),
          (1.5, '1.5'),
          (2.0, l.spacingDouble),
        ])
          MenuSpec.command(
            'slides.format.lineHeight',
            label: label,
            args: {'value': v},
            id: 'toolbar.lineHeight.$v',
            radio: true,
          ),
        MenuSpec.command(
          'slides.format.lineHeight',
          label: l.spacingCustom,
          id: 'toolbar.lineHeight.custom',
        ),
        MenuSpec.separator(),
        MenuSpec.command(
          'slides.format.paragraphSpacing',
          label: l.spacingAddBefore,
          args: const {'before': true},
          id: 'toolbar.spacing.before',
        ),
        MenuSpec.command(
          'slides.format.paragraphSpacing',
          label: l.spacingAddAfter,
          args: const {'after': true},
          id: 'toolbar.spacing.after',
        ),
      ],
    ),
    ui.button('slides.format.outdent', priority: 5),
    ui.button('slides.format.indent', priority: 5),
    ui.button('slides.format.clear', priority: 5),
  ];
}

ToolbarItem _colorButton(
  SlidesCommandUi ui, {
  required String id,
  required String key,
  required IconData icon,
  required String label,
  required String? current,
  required Color? indicator,
  required String reset,
  required ResolvedTheme? theme,
  required String Function() last,
  required void Function(String) remember,
}) => ToolbarSplitButton(
  id: 'slides.toolbar.$key',
  enabled: ui.state(id).enabled,
  priority: 3,
  icon: icon,
  label: label,
  indicatorColor: indicator,
  onPressed: () => ui.run(id, {'color': last()}),
  entries: () => [
    WonkyMenuCustom(
      label: label,
      builder: (context, close) => WonkyColorPicker(
        value: ElementStyle.pickerValueOf(current, theme),
        themeColors: ElementStyle.swatches(theme, ui.l),
        resetLabel: reset,
        onChanged: (c) {
          close();
          final ref = c == null ? null : ElementStyle.colorRefOf(c);
          if (ref != null) remember(ref);
          ui.run(id, {'color': ref});
        },
      ),
    ),
  ],
);
