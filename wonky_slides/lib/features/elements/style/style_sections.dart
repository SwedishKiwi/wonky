import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../toolbar/command_ui.dart';
import 'element_style.dart';

/// Dash styles of borders and lines (02 §5.3).
const dashStyles = ['solid', 'dash', 'dot', 'dashDot', 'longDash'];

/// Weights offered by the weight menus (su).
const strokeWeights = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0];

/// A labelled row of an inspector section.
class InspectorRow extends StatelessWidget {
  const InspectorRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
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
          const SizedBox(width: 8),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ],
      ),
    );
  }
}

/// A color button opening the color picker (theme colors row, reset to
/// [resetLabel]); reports the stored `ColorRef` (null = reset).
class StyleColorButton extends StatefulWidget {
  const StyleColorButton({
    super.key,
    required this.keyName,
    required this.label,
    required this.onChanged,
    this.value,
    this.swatch,
    this.theme,
    this.resetLabel,
    this.enabled = true,
  });

  /// Widget key suffix (`slides.style.color.<keyName>`).
  final String keyName;
  final String label;

  /// The stored color (`theme:accent1`, `#RRGGBB`), or null.
  final String? value;

  /// The displayed color (effective; null = none / mixed).
  final Color? swatch;
  final ResolvedTheme? theme;
  final String? resetLabel;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  State<StyleColorButton> createState() => _StyleColorButtonState();
}

class _StyleColorButtonState extends State<StyleColorButton> {
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return ShadPopover(
      controller: _popover,
      popover: (context) => WonkyColorPicker(
        value: ElementStyle.pickerValueOf(widget.value, widget.theme),
        themeColors: ElementStyle.swatches(widget.theme, l),
        resetLabel: widget.resetLabel,
        allowAlpha: true,
        onChanged: (c) {
          _popover.hide();
          widget.onChanged(c == null ? null : ElementStyle.colorRefOf(c));
        },
      ),
      child: Semantics(
        label: widget.label,
        button: true,
        child: ShadButton.outline(
          key: ValueKey<String>('slides.style.color.${widget.keyName}'),
          size: ShadButtonSize.sm,
          enabled: widget.enabled,
          onPressed: _popover.toggle,
          leading: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: widget.swatch,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: widget.swatch == null
                ? Icon(
                    LucideIcons.ban,
                    size: 12,
                    color: theme.colorScheme.mutedForeground,
                  )
                : null,
          ),
          trailing: const Icon(LucideIcons.chevronDown, size: 14),
          child: Flexible(
            child: Text(
              _describe(widget.value, l),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  String _describe(String? ref, SlidesLocalizations l) {
    if (ref == null) {
      return widget.swatch == null ? l.colorNone : l.colorThemeDefault;
    }
    if (ref.startsWith('theme:')) {
      final key = ref.substring(6).split('/').first;
      return ElementStyle.themeColorLabel(l, key);
    }
    return ref.toUpperCase();
  }
}

/// A select bound to a value list (rebuilt when [value] changes).
class StyleSelect<T> extends StatelessWidget {
  const StyleSelect({
    super.key,
    required this.keyName,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    this.placeholder,
  });

  final String keyName;
  final T? value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final String? placeholder;

  @override
  Widget build(BuildContext context) => ShadSelect<T>(
    key: ValueKey<String>('slides.style.select.$keyName.$value'),
    initialValue: value,
    enabled: enabled,
    minWidth: 120,
    placeholder: placeholder == null ? null : Text(placeholder!),
    options: [
      for (final o in options) ShadOption<T>(value: o, child: Text(label(o))),
    ],
    selectedOptionBuilder: (_, v) => Text(label(v)),
    onChanged: (v) {
      if (v != null && v != value) onChanged(v);
    },
  );
}

/// An opacity slider (0–100 %) that commits once on release (one undo
/// step per drag, 04 §7.1).
class OpacitySlider extends StatefulWidget {
  const OpacitySlider({
    super.key,
    required this.value,
    required this.onCommit,
    this.enabled = true,
  });

  /// 0..1, null when mixed.
  final double? value;
  final ValueChanged<double> onCommit;
  final bool enabled;

  @override
  State<OpacitySlider> createState() => _OpacitySliderState();
}

class _OpacitySliderState extends State<OpacitySlider> {
  double? _live;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final v = _live ?? widget.value ?? 1;
    return Row(
      children: [
        Expanded(
          child: ShadSlider(
            key: const ValueKey<String>('slides.style.opacity'),
            initialValue: v,
            min: 0,
            max: 1,
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
                : '${(v * 100).round()} %',
            style: theme.textTheme.small,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// Shared state of the style sections: the targets, the theme and the
/// command runner.
class StyleScope {
  StyleScope(this.context, this.services, this.ed)
    : ui = SlidesCommandUi(context, services),
      l = slidesL10n(context),
      theme = ElementStyle.themeOf(ed),
      targets = ElementStyle.targets(ed);

  final BuildContext context;
  final ShellServices services;
  final DeckEditorController ed;
  final SlidesCommandUi ui;
  final SlidesLocalizations l;
  final ResolvedTheme? theme;
  final List<ResolvedElement> targets;

  void run(String id, [Map<String, Object?> args = const {}]) =>
      ui.run(id, args, InvocationSource.ui);

  bool enabled(String id, [Map<String, Object?> args = const {}]) =>
      ui.state(id, args).enabled;

  /// The shared stored value of a style column key, or null.
  String? storedColor(
    Iterable<ResolvedElement> els,
    Map<String, Object?>? Function(ResolvedElement) json,
    String key,
  ) => ElementStyle.common(els, (e) {
    final v = json(e)?[key];
    return v is String ? v : null;
  });
}

// ---------------------------------------------------------------- sections

/// Inspector › Format › **Fill** (04 §7.2): color (theme colors, *Theme
/// default*), *No fill*.
Widget fillSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final els = [
    for (final e in s.targets)
      if (ElementStyle.hasFill(e.record.kind)) e,
  ];
  final theme = s.theme;
  final argb = theme == null
      ? null
      : ElementStyle.common(els, (e) => ElementStyle.fillArgb(e, theme));
  final on = s.enabled('slides.format.fill', const {'none': true});
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorRow(
        label: s.l.styleLabelColor,
        child: StyleColorButton(
          keyName: 'fill',
          label: s.l.menuFillColor,
          value: s.storedColor(els, (e) => e.fill, 'color'),
          swatch: argb == null ? null : Color(argb),
          theme: theme,
          resetLabel: s.l.colorThemeDefault,
          enabled: on,
          onChanged: (c) => s.run('slides.format.fill', {'color': c}),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: ShadButton.ghost(
          key: const ValueKey<String>('slides.style.fill.none'),
          size: ShadButtonSize.sm,
          enabled: on,
          leading: const Icon(LucideIcons.ban, size: 14),
          onPressed: () => s.run('slides.format.fill', const {'none': true}),
          child: Text(s.l.styleLabelNoFill),
        ),
      ),
    ],
  );
}

/// Inspector › Format › **Border** (04 §7.2): color, weight, dash, *No
/// border*.
Widget borderSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final els = [
    for (final e in s.targets)
      if (ElementStyle.hasStroke(e.record.kind)) e,
  ];
  return strokeControls(s, els, keyName: 'border');
}

/// Color, weight, dash (and for lines cap) of [els]' strokes.
Widget strokeControls(
  StyleScope s,
  List<ResolvedElement> els, {
  required String keyName,
  bool line = false,
}) {
  final theme = s.theme;
  final on = s.enabled('slides.format.stroke', const {'reset': true});
  final argb = theme == null
      ? null
      : ElementStyle.common(els, (e) => ElementStyle.strokeArgb(e, theme));
  SlideStroke? eff(ResolvedElement e) =>
      theme == null ? null : ElementStyle.effectiveStroke(e, theme);
  final width = ElementStyle.common(els, (e) {
    final st = eff(e);
    return st == null || st.isNone ? 0.0 : (st.width ?? 2);
  });
  final dash = ElementStyle.common(els, (e) => eff(e)?.dash ?? 'solid');
  final cap = ElementStyle.common(els, (e) => eff(e)?.cap ?? 'butt');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorRow(
        label: s.l.styleLabelColor,
        child: StyleColorButton(
          keyName: keyName,
          label: line ? s.l.menuLineColor : s.l.menuBorderColor,
          value: s.storedColor(els, (e) => e.stroke, 'color'),
          swatch: argb == null ? null : Color(argb),
          theme: theme,
          resetLabel: s.l.colorThemeDefault,
          enabled: on,
          onChanged: (c) => s.run(
            'slides.format.stroke',
            c == null ? const {'reset': true} : {'color': c},
          ),
        ),
      ),
      InspectorRow(
        label: s.l.styleLabelWeight,
        child: WonkyNumberStepper(
          key: ValueKey<String>('slides.style.$keyName.width'),
          value: width,
          min: 0,
          max: 100,
          step: 0.5,
          fractionDigits: 1,
          dense: true,
          width: 110,
          enabled: on,
          semanticLabel: s.l.styleLabelWeight,
          onChanged: (v) => s.run(
            'slides.format.stroke',
            v == 0 ? const {'none': true} : {'width': v.toDouble()},
          ),
        ),
      ),
      InspectorRow(
        label: s.l.styleLabelDash,
        child: StyleSelect<String>(
          keyName: '$keyName.dash',
          value: dash,
          options: dashStyles,
          label: (d) => s.l.dashName(d),
          enabled: on,
          placeholder: s.l.styleMixed,
          onChanged: (d) => s.run('slides.format.stroke', {'dash': d}),
        ),
      ),
      if (line)
        InspectorRow(
          label: s.l.styleLabelCap,
          child: StyleSelect<String>(
            keyName: '$keyName.cap',
            value: cap,
            options: const ['butt', 'round', 'square'],
            label: (c) => s.l.capName(c),
            enabled: on,
            placeholder: s.l.styleMixed,
            onChanged: (c) => s.run('slides.format.stroke', {'cap': c}),
          ),
        ),
      if (!line)
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.ghost(
            key: ValueKey<String>('slides.style.$keyName.none'),
            size: ShadButtonSize.sm,
            enabled: on,
            leading: const Icon(LucideIcons.ban, size: 14),
            onPressed: () =>
                s.run('slides.format.stroke', const {'none': true}),
            child: Text(s.l.styleLabelNoBorder),
          ),
        ),
    ],
  );
}

/// Inspector › Format › **Effects** (04 §7.2): shadow, glow, opacity.
Widget effectsSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final els = s.targets;
  final on = s.enabled('slides.format.effects', const {'reset': true});
  final shadow = ElementStyle.common(els, (e) => e.effects?['shadow'] is Map);
  final glow = ElementStyle.common(els, (e) => e.effects?['glow'] is Map);
  final opacity = ElementStyle.common(els, (e) => e.record.opacity ?? 1.0);
  Widget toggle(String key, String label, bool? value) => InspectorRow(
    label: label,
    child: ShadSwitch(
      key: ValueKey<String>('slides.style.effects.$key'),
      value: value ?? false,
      enabled: on,
      onChanged: (v) => s.run('slides.format.effects', {key: v}),
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      toggle('shadow', s.l.styleLabelShadow, shadow),
      toggle('glow', s.l.styleLabelGlow, glow),
      InspectorRow(
        label: s.l.styleLabelOpacity,
        child: OpacitySlider(
          key: ValueKey<String>(
            'slides.style.opacity.${els.map((e) => e.id).join()}',
          ),
          value: opacity,
          enabled: s.enabled('slides.format.opacity', const {'value': 1}),
          onCommit: (v) => s.run('slides.format.opacity', {'value': v}),
        ),
      ),
    ],
  );
}
