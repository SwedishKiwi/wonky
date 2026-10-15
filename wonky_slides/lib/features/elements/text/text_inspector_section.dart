import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../commands/text_commands.dart'
    show fontOptions, listStyleKeys, listStyleLabel;
import '../../../config/menus/slides_menu_spec.dart'
    show textStyleKeys, textStyleLabel;
import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../text_editing/text_editing_host.dart';
import '../../text_editing/text_format.dart';
import '../../toolbar/command_ui.dart';

/// Inspector › Format › **Text** (04 §7.2): style, font, size, B/I/U/S,
/// caps, letter spacing, alignment, anchor, line spacing, space
/// before/after, lists, auto-fit and insets of the selection (the body
/// being edited, or the selected text boxes). Values mirror
/// [TextFormatState]; every control commits through a `slides.format.*`
/// command (one undo step).
Widget textInspectorSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) => ListenableBuilder(
  listenable: textEditingOf(ed),
  builder: (context, _) => _TextSection(services: services, ed: ed),
);

class _TextSection extends StatelessWidget {
  const _TextSection({required this.services, required this.ed});

  final ShellServices services;
  final DeckEditorController ed;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final ui = SlidesCommandUi(context, services);
    final st = TextFormatState.of(TextFormatScope.of(ed));
    final enabled = ui.state('slides.format.bold').enabled;

    Widget row(String label, Widget control) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.small,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: control),
          ),
        ],
      ),
    );

    Widget select(
      String key,
      String? value,
      Map<String, String> options,
      void Function(String v) onChanged,
    ) => ShadSelect<String>(
      key: ValueKey<String>('slides.inspector.text.$key.$value'),
      enabled: enabled,
      initialValue: options.containsKey(value) ? value : null,
      placeholder: Text(l.inspectorMixed, style: theme.textTheme.muted),
      minWidth: 150,
      maxHeight: 320,
      options: [
        for (final e in options.entries)
          ShadOption(value: e.key, child: Text(e.value)),
      ],
      selectedOptionBuilder: (context, v) =>
          Text(options[v] ?? v, maxLines: 1, overflow: TextOverflow.ellipsis),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );

    Widget toggle(
      String id,
      IconData icon,
      bool on, {
      Map<String, Object?> args = const {},
    }) {
      final s = ui.state(id, args);
      return Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Semantics(
          selected: on,
          child: ShadTooltip(
            builder: (_) => Text(s.disabledReason ?? ui.title(id)),
            child: ShadIconButton.ghost(
              key: ValueKey<String>(
                'slides.inspector.text.$id.${args.values.join('.')}',
              ),
              width: 28,
              height: 28,
              iconSize: 15,
              enabled: s.enabled,
              backgroundColor: on ? theme.colorScheme.muted : null,
              semanticLabel: ui.title(id),
              icon: Icon(icon),
              onPressed: () => ui.run(id, args, InvocationSource.ui),
            ),
          ),
        ),
      );
    }

    Widget stepper(
      String key,
      num? value,
      void Function(num v) onChanged, {
      num min = 0,
      num max = 400,
      num step = 1,
      int fractionDigits = 0,
      double width = 96,
    }) => WonkyNumberStepper(
      key: ValueKey<String>('slides.inspector.text.$key'),
      value: value,
      min: min,
      max: max,
      step: step,
      fractionDigits: fractionDigits,
      enabled: enabled,
      dense: true,
      width: width,
      semanticLabel: key,
      onChanged: onChanged,
    );

    void run(String id, Map<String, Object?> args) =>
        ui.run(id, args, InvocationSource.ui);

    final fonts = fontOptions(l);
    final insets = st.insets ?? const [8, 16, 8, 16];
    return Column(
      key: const ValueKey<String>('slides.inspector.text'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          l.menuTextStyle,
          select('style', st.styleKey, {
            for (final k in textStyleKeys) k: textStyleLabel(l, k),
          }, (v) => run('slides.format.textStyle', {'key': v})),
        ),
        row(
          l.fontLabel,
          select('font', st.fontRef ?? st.font, {
            ...fonts,
            if (st.fontRef == null && st.font != null) st.font!: st.font!,
          }, (v) => run('slides.format.font', {'family': v})),
        ),
        row(
          l.fontSizeLabel,
          stepper(
            'size',
            st.size?.round(),
            (v) => run('slides.format.fontSize', {'size': v.toDouble()}),
            min: 6,
            max: 800,
          ),
        ),
        row(
          '',
          Wrap(
            children: [
              toggle('slides.format.bold', LucideIcons.bold, st.bold),
              toggle('slides.format.italic', LucideIcons.italic, st.italic),
              toggle(
                'slides.format.underline',
                LucideIcons.underline,
                st.underline,
              ),
              toggle(
                'slides.format.strikethrough',
                LucideIcons.strikethrough,
                st.strike,
              ),
              toggle(
                'slides.format.script',
                LucideIcons.superscript,
                st.script == 'super',
                args: const {'value': 'super'},
              ),
              toggle(
                'slides.format.script',
                LucideIcons.subscript,
                st.script == 'sub',
                args: const {'value': 'sub'},
              ),
            ],
          ),
        ),
        row(
          l.menuCapitalization,
          select(
            'caps',
            switch (st.caps) {
              'all' => 'upper',
              'small' => 'smallCaps',
              'title' => 'title',
              _ => 'none',
            },
            {
              'none': l.capsNone,
              'upper': l.capsUpper,
              'smallCaps': l.capsSmallCaps,
              'title': l.capsTitle,
            },
            (v) => run('slides.format.caps', {'value': v}),
          ),
        ),
        row(
          l.cmdFormatLetterSpacing,
          stepper(
            'letterSpacing',
            st.letterSpacing,
            (v) => run('slides.format.letterSpacing', {'value': v}),
            min: -0.2,
            max: 1,
            step: 0.01,
            fractionDigits: 2,
          ),
        ),
        row(
          l.toolbarAlign,
          Wrap(
            children: [
              for (final (v, icon) in [
                ('left', LucideIcons.alignLeft),
                ('center', LucideIcons.alignCenter),
                ('right', LucideIcons.alignRight),
                ('justify', LucideIcons.alignJustify),
              ])
                toggle(
                  'slides.format.align',
                  icon,
                  st.align == v,
                  args: {'value': v},
                ),
            ],
          ),
        ),
        row(
          l.cmdFormatAnchor,
          Wrap(
            children: [
              for (final (v, icon) in [
                ('top', LucideIcons.alignVerticalJustifyStart),
                ('middle', LucideIcons.alignVerticalJustifyCenter),
                ('bottom', LucideIcons.alignVerticalJustifyEnd),
              ])
                toggle(
                  'slides.format.anchor',
                  icon,
                  st.anchor == v,
                  args: {'value': v},
                ),
            ],
          ),
        ),
        row(
          l.lineHeightLabel,
          stepper(
            'lineHeight',
            st.lineHeight,
            (v) => run('slides.format.lineHeight', {'value': v}),
            min: 0.7,
            max: 3,
            step: 0.05,
            fractionDigits: 2,
          ),
        ),
        row(
          l.spacingBeforeLabel,
          stepper(
            'spaceBefore',
            st.spaceBefore?.round(),
            (v) => run('slides.format.paragraphSpacing', {'before': v}),
          ),
        ),
        row(
          l.spacingAfterLabel,
          stepper(
            'spaceAfter',
            st.spaceAfter?.round(),
            (v) => run('slides.format.paragraphSpacing', {'after': v}),
          ),
        ),
        row(
          l.menuLists,
          Wrap(
            children: [
              for (final (v, icon) in [
                ('bullet', LucideIcons.list),
                ('number', LucideIcons.listOrdered),
                ('check', LucideIcons.listChecks),
              ])
                toggle(
                  'slides.format.list',
                  icon,
                  st.list == (v == 'number' ? 'ordered' : v),
                  args: {'type': v},
                ),
              toggle(
                'slides.format.outdent',
                LucideIcons.indentDecrease,
                false,
              ),
              toggle('slides.format.indent', LucideIcons.indentIncrease, false),
            ],
          ),
        ),
        if (st.list != null && st.list != 'check')
          row(
            l.listStyleLabel,
            select('listStyle', null, {
              for (final k in listStyleKeys) k: listStyleLabel(l, k),
            }, (v) => run('slides.format.listStyle', {'style': v})),
          ),
        row(
          l.menuTextFitting,
          select('autofit', st.autofit, {
            'none': l.autofitNone,
            'shrink': l.autofitShrink,
            'resize': l.autofitResize,
          }, (v) => run('slides.format.autofit', {'mode': v})),
        ),
        row(
          l.cmdFormatInsets,
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (i, k) in const [
                (0, 't'),
                (1, 'r'),
                (2, 'b'),
                (3, 'l'),
              ])
                stepper(
                  'inset.$k',
                  insets[i].round(),
                  (v) => run('slides.format.insets', {k: v}),
                  max: 2000,
                  width: 72,
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey<String>('slides.inspector.text.clear'),
            size: ShadButtonSize.sm,
            enabled: ui.state('slides.format.clear').enabled,
            leading: const Icon(LucideIcons.removeFormatting, size: 14),
            onPressed: () => run('slides.format.clear', const {}),
            child: Flexible(
              child: Text(
                ui.title('slides.format.clear'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
