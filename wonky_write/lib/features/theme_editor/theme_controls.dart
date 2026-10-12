import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write_core/wonky_write_core.dart'
    show
        ColorRef,
        ColorRefKind,
        FontCategory,
        FontRegistry,
        Length,
        LengthKind,
        LengthUnit,
        PaletteKey,
        argbToHex;

import '../themes/write_fonts.dart';
import 'theme_editor_model.dart';

/// Layout of one inspector property row (Write 06 §10.2): label, control
/// and a reset ⟲ when the value is set at this level. The tooltip of an
/// inherited value names its source ("Inherited from Body: 11pt").
class ThemePropRow extends StatelessWidget {
  const ThemePropRow({
    super.key,
    required this.label,
    required this.child,
    this.isSet = false,
    this.inherited,
    this.onReset,
    this.enabled = true,
    this.wide = false,
  });

  final String label;
  final Widget child;
  final bool isSet;
  final InheritedValue? inherited;
  final VoidCallback? onReset;
  final bool enabled;

  /// Control below the label (lists, edges).
  final bool wide;

  String? get _inheritedText {
    final i = inherited;
    if (i == null || i.value == null) return null;
    return 'Inherited from ${i.source}: ${describeValue(i.value)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final labelStyle = theme.textTheme.small.copyWith(
      fontSize: 13,
      fontWeight: isSet ? FontWeight.w600 : FontWeight.w400,
      color: isSet
          ? theme.colorScheme.foreground
          : theme.colorScheme.mutedForeground,
    );
    Widget labelWidget = Text(
      label,
      style: labelStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final tip = isSet ? null : _inheritedText;
    if (tip != null) {
      labelWidget = ShadTooltip(builder: (_) => Text(tip), child: labelWidget);
    }
    final reset = SizedBox(
      width: 28,
      child: isSet && enabled && onReset != null
          ? ShadTooltip(
              builder: (_) => Text(
                _inheritedText == null
                    ? 'Reset'
                    : 'Reset — ${_inheritedText!.replaceFirst('Inherited from ', 'inherit from ')}',
              ),
              child: ShadIconButton.ghost(
                width: 26,
                height: 26,
                iconSize: 14,
                semanticLabel: 'Reset $label',
                icon: const Icon(LucideIcons.rotateCcw),
                onPressed: onReset,
              ),
            )
          : null,
    );
    if (wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: labelWidget),
                reset,
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 96, child: labelWidget),
          const SizedBox(width: 8),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
          reset,
        ],
      ),
    );
  }
}

/// A short human form of a raw theme JSON value.
String describeValue(Object? v) {
  if (v == null) return '—';
  if (v is bool) return v ? 'On' : 'Off';
  if (v is num) return _number(v);
  if (v is String) {
    if (v.startsWith('@')) {
      final key = PaletteKey.fromJsonName(v.substring(1));
      if (key != null) return paletteLabel(key);
      return switch (v) {
        '@body' => 'Body font',
        '@heading' => 'Heading font',
        '@mono' => 'Code font',
        _ => v,
      };
    }
    return v.isEmpty ? '“”' : enumLabelOrRaw(v);
  }
  if (v is List) return v.join(' ');
  if (v is Map) {
    if (v.containsKey('width') || v.containsKey('style')) {
      return [
        v['width'],
        v['style'],
        v['color'],
      ].whereType<Object>().map(describeValue).join(' ');
    }
    return v.entries
        .map((e) => '${e.key} ${describeValue(e.value)}')
        .join(', ');
  }
  return '$v';
}

String _number(num v) {
  final s = v.toStringAsFixed(2);
  return s.contains('.')
      ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : s;
}

/// [enumLabel] for known enum values, else the raw text.
String enumLabelOrRaw(String v) {
  if (Length.tryParse(v) != null || v.startsWith('#')) return v;
  return enumLabel(v);
}

/// A length: number + unit (`11pt`, `1.2em`, `40%`). Converting units keeps
/// the visual value (Write 06 §10.3).
class ThemeLengthField extends StatelessWidget {
  const ThemeLengthField({
    super.key,
    required this.value,
    required this.kind,
    required this.onChanged,
    this.enabled = true,
    this.emBasePt = 11,
  });

  /// The effective length text (own or inherited); null = unset.
  final String? value;
  final LengthKind kind;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Font size `em` is relative to (unit conversion).
  final double emBasePt;

  static const _order = [
    LengthUnit.pt,
    LengthUnit.px,
    LengthUnit.em,
    LengthUnit.mm,
    LengthUnit.inch,
    LengthUnit.percent,
  ];

  static (num, num, num, int) _range(LengthKind kind, LengthUnit unit) {
    switch (unit) {
      case LengthUnit.em:
        return (kind.minEm, kind.maxEm == 0 ? 20 : kind.maxEm, 0.05, 2);
      case LengthUnit.percent:
        return (0, 100, 1, 0);
      case LengthUnit.inch:
        return (kind.minPt / 72, kind.maxPt / 72, 0.05, 2);
      case LengthUnit.mm:
        return (kind.minPt / 72 * 25.4, kind.maxPt / 72 * 25.4, 1, 1);
      case LengthUnit.px:
        return (kind.minPt * 4 / 3, kind.maxPt * 4 / 3, 1, 1);
      case LengthUnit.pt:
        return (
          kind.minPt,
          kind.maxPt,
          kind == LengthKind.stroke ? 0.25 : 1,
          2,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = value == null ? null : Length.tryParse(value!);
    final unit = parsed?.unit ?? LengthUnit.pt;
    final (min, max, step, digits) = _range(kind, unit);
    final units = [
      for (final u in _order)
        if (kind.units.contains(u)) u,
    ];
    String fmt(num v, LengthUnit u) => Length(v.toDouble(), u).toJson();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WonkyNumberStepper(
          value: parsed?.value,
          min: min,
          max: max,
          step: step,
          fractionDigits: digits,
          dense: true,
          width: 48,
          enabled: enabled,
          onChanged: (v) => onChanged(fmt(v, unit)),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          child: ShadSelect<LengthUnit>(
            key: ValueKey<String>('unit.${unit.json}'),
            enabled: enabled && units.length > 1,
            initialValue: unit,
            minWidth: 60,
            options: [
              for (final u in units) ShadOption(value: u, child: Text(u.json)),
            ],
            selectedOptionBuilder: (context, u) => Text(u.json),
            onChanged: (u) {
              if (u == null || u == unit || parsed == null) return;
              onChanged(fmt(_convert(parsed, u), u));
            },
          ),
        ),
      ],
    );
  }

  num _convert(Length l, LengthUnit to) {
    if (to == LengthUnit.percent || l.unit == LengthUnit.percent) {
      return l.value;
    }
    final pt = l.unit == LengthUnit.em ? l.value * emBasePt : l.toPt();
    final v = switch (to) {
      LengthUnit.pt => pt,
      LengthUnit.px => pt * 4 / 3,
      LengthUnit.em => pt / emBasePt,
      LengthUnit.mm => pt / 72 * 25.4,
      LengthUnit.inch => pt / 72,
      LengthUnit.percent => l.value,
    };
    return double.parse(v.toStringAsFixed(2));
  }
}

/// A color reference: a swatch button opening `WonkyColorPicker` with the
/// theme palette as *Theme colors* (`"@key"` refs), reset to inherit.
class ThemeColorField extends StatefulWidget {
  const ThemeColorField({
    super.key,
    required this.value,
    required this.palette,
    required this.onChanged,
    this.enabled = true,
    this.allowReset = true,
    this.allowTransparent = false,
    this.semanticLabel,
    this.width,
  });

  /// Fixed button width (aligned columns, e.g. the palette).
  final double? width;

  /// The effective color reference (own or inherited).
  final String? value;

  /// Resolved palette of the edited variant (swatches, `@ref` display).
  final Map<PaletteKey, int> palette;

  /// Null = reset to inherit.
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool allowReset;
  final bool allowTransparent;
  final String? semanticLabel;

  @override
  State<ThemeColorField> createState() => _ThemeColorFieldState();
}

class _ThemeColorFieldState extends State<ThemeColorField> {
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  /// ARGB of [ref] in the palette (null for unknown / unset).
  int? _argb(String? ref) {
    if (ref == null) return null;
    final c = ColorRef.tryParse(ref);
    if (c == null) return null;
    return switch (c.kind) {
      ColorRefKind.rgb => c.argb,
      ColorRefKind.transparent => 0,
      ColorRefKind.palette => widget.palette[c.paletteKey!],
    };
  }

  String _label(String? ref) {
    if (ref == null) return 'Automatic';
    if (ref == 'transparent') return 'None';
    if (ref.startsWith('@')) {
      final k = PaletteKey.fromJsonName(ref.substring(1));
      return k == null ? ref : paletteLabel(k);
    }
    return ref.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final argb = _argb(widget.value);
    final swatches = [
      for (final k in PaletteKey.values)
        if (widget.palette[k] case final c?)
          WonkyThemeSwatch(
            color: WonkyColor(
              argbToHex(c).toUpperCase(),
              themeRef: '@${k.name}',
            ),
            name: paletteLabel(k),
          ),
    ];
    final current = widget.value == null
        ? null
        : WonkyColor(
            argb == null ? '#000000' : argbToHex(argb).toUpperCase(),
            themeRef: widget.value!.startsWith('@') ? widget.value : null,
          );
    return ShadPopover(
      controller: _popover,
      popover: (context) => IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WonkyColorPicker(
              value: current,
              themeColors: swatches,
              resetLabel: widget.allowReset ? 'Automatic (inherit)' : null,
              allowAlpha: true,
              onChanged: (c) {
                _popover.hide();
                if (c == null) {
                  widget.onChanged(null);
                  return;
                }
                final ref = c.themeRef;
                widget.onChanged(
                  ref != null && ref.startsWith('@')
                      ? ref
                      : c.hex.toLowerCase(),
                );
              },
            ),
            if (widget.allowTransparent)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  leading: const Icon(LucideIcons.ban, size: 14),
                  onPressed: () {
                    _popover.hide();
                    widget.onChanged('transparent');
                  },
                  child: const Text('No color'),
                ),
              ),
          ],
        ),
      ),
      child: Semantics(
        button: true,
        label: '${widget.semanticLabel ?? 'Color'}: ${_label(widget.value)}',
        child: ShadButton.outline(
          width: widget.width,
          mainAxisAlignment: MainAxisAlignment.start,
          size: ShadButtonSize.sm,
          enabled: widget.enabled,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: _popover.toggle,
          leading: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: argb == null ? null : Color(argb),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.colorScheme.border),
            ),
            child: argb == 0 || argb == null
                ? Icon(
                    LucideIcons.slash,
                    size: 12,
                    color: theme.colorScheme.mutedForeground,
                  )
                : null,
          ),
          child: Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                _label(widget.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A font reference: theme roles (`@body`…) and the curated families by
/// category, each previewed in its own face (Write 06 §10.3).
class ThemeFontField extends StatelessWidget {
  const ThemeFontField({
    super.key,
    required this.value,
    required this.roles,
    required this.onChanged,
    this.enabled = true,
    this.allowRoles = true,
  });

  final String? value;

  /// `(@role, family)` of the theme.
  final List<(String, String)> roles;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool allowRoles;

  static String _roleName(String ref) => switch (ref) {
    '@body' => 'Body',
    '@heading' => 'Heading',
    '@mono' => 'Code',
    _ => ref,
  };

  TextStyle _face(String family) => TextStyle(
    fontFamily: WriteFonts.screenFamilyFor(family),
    fontFamilyFallback: WriteFonts.screenFallbackFor(family),
  );

  String _familyOf(String v) {
    for (final (ref, family) in roles) {
      if (ref == v) return family;
    }
    return v;
  }

  Widget _optionLabel(BuildContext context, String v) {
    if (v.startsWith('@')) {
      final family = _familyOf(v);
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${_roleName(v)} font · '),
            TextSpan(text: family, style: _face(family)),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(v, style: _face(v), overflow: TextOverflow.ellipsis);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Text(
        text,
        style: theme.textTheme.muted.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final families = FontRegistry.families.where((f) => !f.isFallback);
    List<String> of(FontCategory c, {bool display = false}) => [
      for (final f in families)
        if (f.category == c && f.isDisplay == display) f.family,
    ];
    final sections = <(String, List<String>)>[
      if (allowRoles) ('Theme fonts', [for (final (r, _) in roles) r]),
      ('Sans serif', of(FontCategory.sans)),
      ('Serif', of(FontCategory.serif)),
      ('Monospace', of(FontCategory.mono)),
      (
        'Display',
        [
          ...of(FontCategory.sans, display: true),
          ...of(FontCategory.serif, display: true),
        ],
      ),
    ];
    return ShadSelect<String>(
      key: ValueKey<String>('font.$value'),
      enabled: enabled,
      initialValue: value,
      minWidth: 180,
      maxHeight: 360,
      placeholder: const Text('Choose a font'),
      selectedOptionBuilder: _optionLabel,
      onChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
      options: [
        for (final (title, fonts) in sections)
          if (fonts.isNotEmpty) ...[
            header(title),
            for (final f in fonts)
              ShadOption<String>(value: f, child: _optionLabel(context, f)),
          ],
      ],
    );
  }
}

/// One of a few values: a segmented toggle for up to 4 short options, a
/// select otherwise.
class ThemeEnumField extends StatelessWidget {
  const ThemeEnumField({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.labelOf = enumLabel,
  });

  final List<String> values;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String Function(String) labelOf;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final short =
        values.length <= 4 && values.every((v) => labelOf(v).length <= 9);
    if (!short) return _select();
    final style = theme.textTheme.small.copyWith(fontSize: 12);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    var needed = 4.0;
    for (final v in values) {
      final p = TextPainter(
        text: TextSpan(text: labelOf(v), style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      needed += p.width + 18;
      p.dispose();
    }
    return LayoutBuilder(
      builder: (context, box) =>
          needed > box.maxWidth ? _select() : _toggle(theme, style),
    );
  }

  Widget _toggle(ShadThemeData theme, TextStyle style) {
    {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: ShadButton.raw(
                  variant: v == value
                      ? ShadButtonVariant.outline
                      : ShadButtonVariant.ghost,
                  size: ShadButtonSize.sm,
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: v == value
                      ? theme.colorScheme.background
                      : null,
                  enabled: enabled,
                  onPressed: () {
                    if (v != value) onChanged(v);
                  },
                  child: Semantics(
                    selected: v == value,
                    child: Text(labelOf(v), style: style),
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _select() {
    return ShadSelect<String>(
      key: ValueKey<String>('enum.$value'),
      enabled: enabled,
      initialValue: value,
      minWidth: 150,
      placeholder: const Text('—'),
      selectedOptionBuilder: (context, v) => Text(labelOf(v)),
      onChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
      options: [
        for (final v in values) ShadOption(value: v, child: Text(labelOf(v))),
      ],
    );
  }
}

/// A number with a slider (line height, opacity, ratios).
class ThemeNumberField extends StatelessWidget {
  const ThemeNumberField({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.step = 0.05,
    this.digits = 2,
    this.enabled = true,
    this.slider = true,
  });

  final num? value;
  final num min;
  final num max;
  final num step;
  final int digits;
  final bool enabled;
  final bool slider;
  final ValueChanged<num> onChanged;
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final stepper = WonkyNumberStepper(
      value: value,
      min: min,
      max: max,
      step: step,
      fractionDigits: digits,
      dense: true,
      width: 96,
      enabled: enabled,
      onChanged: onChanged,
    );
    if (!slider) return stepper;
    return Row(
      children: [
        Expanded(
          child: ShadSlider(
            key: ValueKey<String>('slider.$value'),
            initialValue: (value ?? min).toDouble().clamp(
              min.toDouble(),
              max.toDouble(),
            ),
            min: min.toDouble(),
            max: max.toDouble(),
            enabled: enabled,
            onChanged: (v) {
              final p = digits == 0 ? 1 : (digits == 1 ? 10 : 100);
              onChanged((v * p).round() / p);
            },
            onChangeEnd: (_) => onChangeEnd?.call(),
          ),
        ),
        const SizedBox(width: 8),
        stepper,
      ],
    );
  }
}

/// A short free text (suffix, ornament, description) committed on Enter
/// or blur.
class ThemeTextField extends StatefulWidget {
  const ThemeTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.placeholder,
    this.maxLength = 80,
    this.width,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? placeholder;
  final int maxLength;
  final double? width;

  @override
  State<ThemeTextField> createState() => _ThemeTextFieldState();
}

class _ThemeTextFieldState extends State<ThemeTextField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value ?? '',
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(ThemeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _text.text = widget.value ?? '';
    }
  }

  void _commit() {
    if (_text.text != (widget.value ?? '')) widget.onChanged(_text.text);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: ShadInput(
      controller: _text,
      focusNode: _focus,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      placeholder: widget.placeholder == null
          ? null
          : Text(widget.placeholder!),
      onSubmitted: (_) => _commit(),
    ),
  );
}
