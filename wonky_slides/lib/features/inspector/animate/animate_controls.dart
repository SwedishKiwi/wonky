import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/themes.dart' show ResolvedTheme;
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../builds/build_labels.dart';
import '../../elements/style/style_sections.dart';

/// A small heading inside the Animate tab ("Timing", "Delivery").
class AnimateHeading extends StatelessWidget {
  const AnimateHeading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Seconds with one decimal (`0.6 s`), stored as integer milliseconds.
class SecondsField extends StatelessWidget {
  const SecondsField({
    super.key,
    required this.ms,
    required this.onChanged,
    this.maxMs = 20000,
    this.minMs = 0,
    this.step = 0.1,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The value (null = mixed).
  final int? ms;
  final int minMs, maxMs;
  final double step;
  final bool enabled;
  final String? semanticLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => WonkyNumberStepper(
    value: ms == null ? null : ms! / 1000,
    min: minMs / 1000,
    max: maxMs / 1000,
    step: step,
    fractionDigits: step < 1 ? (step < 0.1 ? 2 : 1) : 0,
    enabled: enabled,
    suffix: 's',
    semanticLabel: semanticLabel,
    onChanged: (v) => onChanged((v * 1000).round()),
  );
}

/// A row of toggle buttons for a few choices (segmented control).
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.keyName,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    this.icon,
  });

  final String keyName;
  final T? value;
  final List<T> options;
  final String Function(T) label;
  final IconData Function(T)? icon;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        for (final o in options)
          Semantics(
            selected: o == value,
            button: true,
            child: ShadButton.ghost(
              key: ValueKey<String>('slides.animate.$keyName.$o'),
              size: ShadButtonSize.sm,
              enabled: enabled,
              backgroundColor: o == value ? theme.colorScheme.muted : null,
              leading: icon == null ? null : Icon(icon!(o), size: 14),
              onPressed: () {
                if (o != value) onChanged(o);
              },
              child: Text(
                label(o),
                style: theme.textTheme.small.copyWith(
                  fontWeight: o == value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// An 8-way (or 4-way) arrow pad for `direction` parameters (06 §5.2).
class DirectionPad extends StatelessWidget {
  const DirectionPad({
    super.key,
    required this.keyName,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String keyName;
  final List<String> choices;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  static const _grid = [
    ['topLeft', 'top|up', 'topRight'],
    ['left', '', 'right'],
    ['bottomLeft', 'bottom|down', 'bottomRight'],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    Widget cell(String names) {
      String? d;
      for (final n in names.split('|')) {
        if (choices.contains(n)) d = n;
      }
      if (d == null) return const SizedBox(width: 28, height: 28);
      final dir = d;
      final selected = dir == value;
      return Semantics(
        selected: selected,
        button: true,
        label: BuildLabels.choice(l, dir),
        child: ShadTooltip(
          builder: (_) => Text(BuildLabels.choice(l, dir)),
          child: ShadIconButton.ghost(
            key: ValueKey<String>('slides.animate.$keyName.$dir'),
            width: 28,
            height: 28,
            iconSize: 14,
            enabled: enabled,
            backgroundColor: selected ? theme.colorScheme.primary : null,
            foregroundColor: selected
                ? theme.colorScheme.primaryForeground
                : null,
            icon: Icon(BuildLabels.directionIcon(dir)),
            onPressed: () => onChanged(dir),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in _grid)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final c in row) cell(c)],
              ),
          ],
        ),
      ),
    );
  }
}

/// A switch row.
class AnimateSwitch extends StatelessWidget {
  const AnimateSwitch({
    super.key,
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String keyName;
  final String label;
  final bool? value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.small)),
          ShadSwitch(
            key: ValueKey<String>('slides.animate.$keyName'),
            value: value ?? false,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A slider 0..1 (or [min]..[max]) that commits once on release, with the
/// value as a percentage.
class CommitSlider extends StatefulWidget {
  const CommitSlider({
    super.key,
    required this.value,
    required this.onCommit,
    this.min = 0,
    this.max = 1,
    this.percent = true,
    this.enabled = true,
  });

  final double? value;
  final double min, max;
  final bool percent;
  final bool enabled;
  final ValueChanged<double> onCommit;

  @override
  State<CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<CommitSlider> {
  double? _live;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final v = (_live ?? widget.value ?? widget.min).clamp(
      widget.min,
      widget.max,
    );
    return Row(
      children: [
        Expanded(
          child: ShadSlider(
            initialValue: v,
            min: widget.min,
            max: widget.max,
            enabled: widget.enabled,
            onChanged: (x) => setState(() => _live = x),
            onChangeEnd: (x) {
              setState(() => _live = null);
              widget.onCommit((x * 100).roundToDouble() / 100);
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            widget.value == null && _live == null
                ? '—'
                : widget.percent
                ? '${(v * 100).round()} %'
                : v.toStringAsFixed(1),
            style: theme.textTheme.small,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// The control of one effect/transition parameter rendered from its
/// [ParamSpec] (06 §5.2): direction pads, selects, switches, numeric
/// steppers, colors, distances (number or *Off slide*). Objects, paths and
/// free text have their own controls (motion paths, transform targets) and
/// return null here.
Widget? paramControl(
  BuildContext context, {
  required ParamSpec spec,
  required Object? value,
  required ValueChanged<Object?> onChanged,
  required String keyPrefix,
  ResolvedTheme? theme,
  bool enabled = true,
}) {
  final l = slidesL10n(context);
  final key = '$keyPrefix.${spec.key}';
  final v = value ?? spec.defaultValue;
  switch (spec.type) {
    case ParamType.choice:
      if (spec.key == 'direction' && spec.choices.every(_isDirection)) {
        return DirectionPad(
          keyName: key,
          choices: spec.choices,
          value: v as String?,
          enabled: enabled,
          onChanged: onChanged,
        );
      }
      if (spec.choices.length <= 3 &&
          spec.choices.every((c) => BuildLabels.choice(l, c).length <= 9)) {
        return SegmentedChoice<String>(
          keyName: key,
          value: v as String?,
          options: spec.choices,
          enabled: enabled,
          label: (c) => BuildLabels.choice(l, c),
          onChanged: onChanged,
        );
      }
      return StyleSelect<String>(
        keyName: key,
        value: v as String?,
        options: spec.choices,
        enabled: enabled,
        label: (c) => BuildLabels.choice(l, c),
        onChanged: onChanged,
      );
    case ParamType.boolean:
      return ShadSwitch(
        key: ValueKey<String>('slides.animate.$key'),
        value: v == true,
        enabled: enabled,
        onChanged: onChanged,
      );
    case ParamType.number || ParamType.integer || ParamType.optionalNumber:
      final min = spec.min ?? -100000, max = spec.max ?? 100000;
      final span = max - min;
      final integer = spec.type == ParamType.integer;
      final step = integer
          ? 1
          : span <= 1.01
          ? 0.05
          : span <= 10
          ? 0.1
          : span <= 100
          ? 1
          : 10;
      return WonkyNumberStepper(
        key: ValueKey<String>('slides.animate.$key'),
        value: v is num ? v : null,
        min: min,
        max: max,
        step: step,
        fractionDigits: step >= 1 ? 0 : (step < 0.1 ? 2 : 1),
        enabled: enabled,
        semanticLabel: BuildLabels.param(l, spec.key),
        onChanged: (n) => onChanged(integer ? n.round() : n),
      );
    case ParamType.distance:
      final off = v == 'offSlide';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: WonkyNumberStepper(
              key: ValueKey<String>('slides.animate.$key'),
              value: v is num ? v : null,
              min: spec.min ?? 0,
              max: spec.max ?? 10000,
              step: 10,
              enabled: enabled && !off,
              semanticLabel: BuildLabels.param(l, spec.key),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 6),
          ShadTooltip(
            builder: (_) => Text(l.animateOffSlide),
            child: ShadIconButton.ghost(
              key: ValueKey<String>('slides.animate.$key.offSlide'),
              width: 28,
              height: 28,
              iconSize: 14,
              enabled: enabled,
              backgroundColor: off
                  ? ShadTheme.of(context).colorScheme.muted
                  : null,
              icon: const Icon(LucideIcons.maximize2),
              onPressed: () => onChanged(off ? 400 : 'offSlide'),
            ),
          ),
        ],
      );
    case ParamType.color:
      return StyleColorButton(
        keyName: 'animate.$key',
        label: BuildLabels.param(l, spec.key),
        value: v as String?,
        swatch: v is String && theme != null
            ? Color(theme.colorString(v, fallback: 0xFF000000))
            : null,
        theme: theme,
        resetLabel: spec.defaultValue == null ? l.colorNone : null,
        enabled: enabled,
        onChanged: onChanged,
      );
    case ParamType.path || ParamType.object || ParamType.string:
      return null;
  }
}

bool _isDirection(String c) => const {
  'left',
  'right',
  'top',
  'bottom',
  'up',
  'down',
  'topLeft',
  'topRight',
  'bottomLeft',
  'bottomRight',
}.contains(c);

/// Handles ↑/↓/←/→ among [count] focusable items laid out in [columns]
/// (effect grids, 06 §17): moves focus to the neighbor.
KeyEventResult gridArrowKey(
  KeyEvent event, {
  required int index,
  required int count,
  required int columns,
  required void Function(int index) focus,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  final k = event.logicalKey;
  int? next;
  if (k == LogicalKeyboardKey.arrowRight) next = index + 1;
  if (k == LogicalKeyboardKey.arrowLeft) next = index - 1;
  if (k == LogicalKeyboardKey.arrowDown) next = index + columns;
  if (k == LogicalKeyboardKey.arrowUp) next = index - columns;
  if (k == LogicalKeyboardKey.home) next = 0;
  if (k == LogicalKeyboardKey.end) next = count - 1;
  if (next == null || next < 0 || next >= count) {
    return next == null ? KeyEventResult.ignored : KeyEventResult.handled;
  }
  focus(next);
  return KeyEventResult.handled;
}
