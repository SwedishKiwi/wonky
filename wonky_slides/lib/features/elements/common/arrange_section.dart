import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_ui/wonky_ui.dart';

import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../selection/reading_order.dart';
import '../style/style_sections.dart';

/// An icon button bound to a command (inspector rows).
Widget _iconCommand(
  StyleScope s,
  String id,
  IconData icon,
  String label, [
  Map<String, Object?> args = const {},
]) {
  final st = s.ui.state(id, args);
  return ShadTooltip(
    builder: (_) => Text(st.enabled ? label : (st.disabledReason ?? label)),
    child: ShadIconButton.ghost(
      key: ValueKey<String>('slides.arrange.$id.${args.values.join('.')}'),
      width: 30,
      height: 30,
      iconSize: 16,
      enabled: st.enabled,
      semanticLabel: label,
      icon: Icon(icon),
      onPressed: () => s.run(id, args),
    ),
  );
}

/// Inspector › Format › **Arrange** (04 §7.2): X, Y, W, H (su; top-level
/// objects), rotation, flip, align/distribute and order rows, lock, name;
/// *Edit inside group* for element groups.
Widget arrangeSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final l = s.l;
  final els = s.targets;
  final single = els.length == 1 ? els.single : null;
  final top =
      single != null && selectionOf(ed).elements?.parentOf(single.id) == null;
  final rec = single?.record;
  final frameOn =
      top &&
      rec != null &&
      rec.kind != ElementKind.line &&
      s.enabled('slides.element.resize', {
        'frames': [
          {'id': single.id},
        ],
      });
  Widget number(String key, String label, num? value, void Function(num) set) =>
      Expanded(
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(label, style: ShadTheme.of(context).textTheme.small),
            ),
            Expanded(
              child: WonkyNumberStepper(
                key: ValueKey<String>('slides.arrange.$key'),
                value: value,
                min: key == 'w' || key == 'h' ? 1 : -100000,
                max: 100000,
                dense: true,
                enabled: frameOn,
                semanticLabel: label,
                onChanged: set,
              ),
            ),
          ],
        ),
      );
  void frame(Map<String, Object?> v) => s.run('slides.element.resize', {
    'frames': [
      {'id': single!.id, ...v},
    ],
  });
  final f = single?.frame;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (single != null) ...[
        Row(
          children: [
            number('x', l.arrangeLabelX, f?.x.round(), (v) => frame({'x': v})),
            const SizedBox(width: 6),
            number('y', l.arrangeLabelY, f?.y.round(), (v) => frame({'y': v})),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            number(
              'w',
              l.arrangeLabelW,
              f?.width.round(),
              (v) => frame({'width': v}),
            ),
            const SizedBox(width: 6),
            number(
              'h',
              l.arrangeLabelH,
              f?.height.round(),
              (v) => frame({'height': v}),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InspectorRow(
          label: l.arrangeLabelRotation,
          child: WonkyNumberStepper(
            key: const ValueKey<String>('slides.arrange.rotation'),
            value: single.rotation.round(),
            min: -360,
            max: 360,
            dense: true,
            width: 110,
            suffix: '°',
            enabled: frameOn,
            semanticLabel: l.arrangeLabelRotation,
            onChanged: (v) => s.run('slides.element.resize', {
              'frames': [
                {'id': single.id, 'rotation': v.toDouble() % 360},
              ],
              'label': 'rotate',
            }),
          ),
        ),
      ],
      Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final (edge, icon, label) in [
            ('left', LucideIcons.alignStartVertical, l.alignLeft),
            ('center', LucideIcons.alignCenterVertical, l.alignCenter),
            ('right', LucideIcons.alignEndVertical, l.alignRight),
            ('top', LucideIcons.alignStartHorizontal, l.anchorTop),
            ('middle', LucideIcons.alignCenterHorizontal, l.anchorMiddle),
            ('bottom', LucideIcons.alignEndHorizontal, l.anchorBottom),
          ])
            _iconCommand(s, 'slides.arrange.align', icon, label, {
              'edge': edge,
            }),
          if (els.length > 2) ...[
            _iconCommand(
              s,
              'slides.arrange.distribute',
              LucideIcons.alignHorizontalSpaceAround,
              l.axisHorizontally,
              const {'axis': 'horizontal'},
            ),
            _iconCommand(
              s,
              'slides.arrange.distribute',
              LucideIcons.alignVerticalSpaceAround,
              l.axisVertically,
              const {'axis': 'vertical'},
            ),
          ],
        ],
      ),
      Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final (op, icon, label) in [
            ('front', LucideIcons.bringToFront, l.orderBringToFront),
            ('forward', LucideIcons.arrowUpToLine, l.orderBringForward),
            ('backward', LucideIcons.arrowDownToLine, l.orderSendBackward),
            ('back', LucideIcons.sendToBack, l.orderSendToBack),
          ])
            _iconCommand(s, 'slides.arrange.order', icon, label, {'op': op}),
          _iconCommand(
            s,
            'slides.arrange.flip',
            LucideIcons.flipHorizontal2,
            l.flipHorizontally,
            const {'axis': 'horizontal'},
          ),
          _iconCommand(
            s,
            'slides.arrange.flip',
            LucideIcons.flipVertical2,
            l.flipVertically,
            const {'axis': 'vertical'},
          ),
          _iconCommand(
            s,
            'slides.arrange.rotate',
            LucideIcons.rotateCw,
            l.rotateClockwise,
            const {'degrees': 90},
          ),
        ],
      ),
      const SizedBox(height: 8),
      InspectorRow(
        label: l.arrangeLocked,
        child: ShadSwitch(
          key: const ValueKey<String>('slides.arrange.locked'),
          value: els.isNotEmpty && els.every((e) => e.locked),
          enabled: s.enabled('slides.element.toggleLock'),
          onChanged: (_) => s.run('slides.element.toggleLock'),
        ),
      ),
      if (single != null)
        InspectorRow(
          label: l.arrangeLabelName,
          child: _CommitField(
            key: ValueKey<String>('slides.arrange.name.${single.id}'),
            fieldKey: 'slides.arrange.name',
            value: rec?.name ?? '',
            enabled: s.enabled('slides.element.rename', const {'name': ''}),
            onCommit: (v) => s.run('slides.element.rename', {'name': v}),
          ),
        ),
      if (single != null && rec?.kind == ElementKind.group)
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey<String>('slides.arrange.enterGroup'),
            size: ShadButtonSize.sm,
            enabled: s.enabled('slides.select.enterGroup'),
            onPressed: () => s.run('slides.select.enterGroup'),
            child: Flexible(
              child: Text(
                l.arrangeEditInsideGroup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
    ],
  );
}

/// Inspector › Format › **Accessibility** (04 §7.2): alt text,
/// *Decorative*, reading order position.
Widget accessibilitySection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final l = s.l;
  final theme = ShadTheme.of(context);
  final single = s.targets.length == 1 ? s.targets.single : null;
  final on = s.enabled('slides.element.editAltText', const {'altText': ''});
  final sel = selectionOf(ed);
  final slide = sel.slide;
  final order = slide == null
      ? const <ResolvedElement>[]
      : ReadingOrder.of(sel.scope, slideHeight: slide.bounds.height);
  final pos = single == null ? -1 : order.indexWhere((e) => e.id == single.id);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (single != null) ...[
        Text(l.accessibilityAltText, style: theme.textTheme.small),
        const SizedBox(height: 4),
        _CommitField(
          key: ValueKey<String>('slides.a11y.altText.${single.id}'),
          fieldKey: 'slides.a11y.altText',
          value: single.record.altText ?? '',
          multiline: true,
          placeholder: l.accessibilityAltTextHint,
          enabled: on && !single.record.decorative,
          onCommit: (v) => s.run('slides.element.editAltText', {'altText': v}),
        ),
        const SizedBox(height: 8),
      ],
      InspectorRow(
        label: l.accessibilityDecorative,
        child: ShadSwitch(
          key: const ValueKey<String>('slides.a11y.decorative'),
          value:
              s.targets.isNotEmpty &&
              s.targets.every((e) => e.record.decorative),
          enabled: on,
          onChanged: (v) =>
              s.run('slides.element.editAltText', {'decorative': v}),
        ),
      ),
      if (pos >= 0)
        Text(
          l.accessibilityReadingOrder(pos + 1, order.length),
          style: theme.textTheme.muted,
        ),
    ],
  );
}

/// A text field that commits on Enter (single line) or when it loses
/// focus, only when the text changed.
class _CommitField extends StatefulWidget {
  const _CommitField({
    super.key,
    required this.fieldKey,
    required this.value,
    required this.onCommit,
    this.enabled = true,
    this.multiline = false,
    this.placeholder,
  });

  final String fieldKey;
  final String value;
  final ValueChanged<String> onCommit;
  final bool enabled;
  final bool multiline;
  final String? placeholder;

  @override
  State<_CommitField> createState() => _CommitFieldState();
}

class _CommitFieldState extends State<_CommitField> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_CommitField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focus.hasFocus) _c.text = widget.value;
  }

  void _commit() {
    final v = _c.text.trim();
    if (v != widget.value.trim()) widget.onCommit(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadInput(
    key: ValueKey<String>(widget.fieldKey),
    controller: _c,
    focusNode: _focus,
    enabled: widget.enabled,
    placeholder: widget.placeholder == null ? null : Text(widget.placeholder!),
    maxLines: widget.multiline ? 4 : 1,
    minLines: widget.multiline ? 2 : 1,
    onSubmitted: widget.multiline ? null : (_) => _commit(),
  );
}
