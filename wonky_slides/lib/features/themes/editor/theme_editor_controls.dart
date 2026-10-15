import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/fonts.dart' show AssetFontRegistry;
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../elements/style/element_style.dart';
import '../../elements/style/style_sections.dart' show StyleColorButton;

/// A labelled row of the theme editor: label (fixed width), control.
class ThemeEditorRow extends StatelessWidget {
  const ThemeEditorRow({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
    this.labelWidth = 92,
  });

  final String label;
  final Widget child;
  final Widget? trailing;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(builder: (context, c) => _row(theme, c.maxWidth)),
    );
  }

  Widget _row(ShadThemeData theme, double width) => Row(
    children: [
      SizedBox(
        // Narrow inspectors (360 px panels) give the control the room.
        width: width.isFinite
            ? labelWidth.clamp(56.0, width * 0.34)
            : labelWidth,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.small.copyWith(fontSize: 13),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
      if (trailing != null) ...[const SizedBox(width: 4), trailing!],
    ],
  );
}

/// A sub-heading inside a section ("Custom colors", "Lists").
class ThemeEditorSubTitle extends StatelessWidget {
  const ThemeEditorSubTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.small.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.mutedForeground,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// An explicit hex color (theme schemes, custom colors: 05 §2.2 holds hex
/// values only): a swatch button with the hex code opening
/// `WonkyColorPicker` (alpha allowed).
class ThemeHexColorButton extends StatefulWidget {
  const ThemeHexColorButton({
    super.key,
    required this.keyName,
    required this.label,
    required this.argb,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  /// Key suffix (`slides.theme.color.<keyName>`).
  final String keyName;

  /// Semantic label ("Accent 1").
  final String label;
  final int argb;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// Only the swatch (no hex text).
  final bool compact;

  @override
  State<ThemeHexColorButton> createState() => _ThemeHexColorButtonState();
}

class _ThemeHexColorButtonState extends State<ThemeHexColorButton> {
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hex = ColorRef.formatHex(widget.argb);
    final swatch = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Color(widget.argb),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: theme.colorScheme.border),
      ),
    );
    return ShadPopover(
      controller: _popover,
      popover: (context) => WonkyColorPicker(
        value: WonkyColor.tryParse(hex),
        allowAlpha: true,
        onChanged: (c) {
          _popover.hide();
          if (c == null) return;
          widget.onChanged(ColorRef.parseHexArgb(c.hex));
        },
      ),
      child: Semantics(
        label: '${widget.label}: $hex',
        button: true,
        child: widget.compact
            ? ShadIconButton.outline(
                key: ValueKey<String>('slides.theme.color.${widget.keyName}'),
                width: 28,
                height: 28,
                enabled: widget.enabled,
                onPressed: _popover.toggle,
                icon: swatch,
              )
            : ShadButton.outline(
                key: ValueKey<String>('slides.theme.color.${widget.keyName}'),
                size: ShadButtonSize.sm,
                enabled: widget.enabled,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: _popover.toggle,
                leading: swatch,
                child: Flexible(
                  child: Text(
                    hex,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A color that may reference the theme (`theme:accent1`) or be explicit:
/// the Slides color button with the theme's swatches first (05 §1 P1).
class ThemeRefColorButton extends StatelessWidget {
  const ThemeRefColorButton({
    super.key,
    required this.keyName,
    required this.label,
    required this.value,
    required this.theme,
    required this.onChanged,
    this.enabled = true,
    this.resetLabel,
  });

  final String keyName;
  final String label;

  /// The stored ref, or null.
  final String? value;
  final ResolvedTheme theme;

  /// Null = reset (only with [resetLabel]).
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? resetLabel;

  @override
  Widget build(BuildContext context) {
    final ref = ColorRef.tryParse(value);
    return StyleColorButton(
      keyName: 'theme.$keyName',
      label: label,
      value: value,
      swatch: ref == null ? null : Color(theme.color(ref)),
      theme: theme,
      resetLabel: resetLabel,
      enabled: enabled,
      onChanged: (c) {
        if (c == null && resetLabel == null) return;
        onChanged(c);
      },
    );
  }
}

/// A WCAG contrast badge ("7.4:1", red when below [required]).
class ContrastBadge extends StatelessWidget {
  const ContrastBadge({
    super.key,
    required this.ratio,
    required this.required,
    required this.pair,
  });

  final double ratio;
  final double required;

  /// "Text 1 on Background 1".
  final String pair;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final passes = ratio + 1e-9 >= required;
    final text = '${ratio.toStringAsFixed(1)}:1';
    final color = passes
        ? theme.colorScheme.mutedForeground
        : theme.colorScheme.destructive;
    return ShadTooltip(
      builder: (_) => Text(
        passes
            ? l.themeContrastPasses(pair, text, required.toStringAsFixed(1))
            : l.themeContrastFails(pair, text, required.toStringAsFixed(1)),
      ),
      child: Semantics(
        label: passes
            ? l.themeContrastPasses(pair, text, required.toStringAsFixed(1))
            : l.themeContrastFails(pair, text, required.toStringAsFixed(1)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!passes) ...[
                Icon(LucideIcons.triangleAlert, size: 10, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                text,
                style: theme.textTheme.small.copyWith(
                  fontSize: 10,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A select of string values (rebuilt with its value).
class ThemeSelect extends StatelessWidget {
  const ThemeSelect({
    super.key,
    required this.keyName,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelOf,
    this.styleOf,
    this.enabled = true,
    this.minWidth = 120,
    this.placeholder,
  });

  /// Shown while nothing is selected.
  final String? placeholder;

  final String keyName;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String Function(String v)? labelOf;

  /// The text style of an option (fonts preview in their own face).
  final TextStyle? Function(String v)? styleOf;
  final bool enabled;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    Widget label(String v) => Text(
      labelOf?.call(v) ?? v,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: styleOf?.call(v),
    );
    return ShadSelect<String>(
      key: ValueKey<String>('slides.theme.select.$keyName.$value'),
      initialValue: value,
      enabled: enabled,
      minWidth: minWidth,
      maxHeight: 320,
      placeholder: placeholder == null ? null : Text(placeholder!),
      options: [
        for (final o in options) ShadOption<String>(value: o, child: label(o)),
      ],
      selectedOptionBuilder: (_, v) => label(v),
      onChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
    );
  }
}

/// A number with − / + (each step is one change).
class ThemeNumber extends StatelessWidget {
  const ThemeNumber({
    super.key,
    required this.keyName,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.digits = 0,
    this.enabled = true,
    this.semanticLabel,
  });

  final String keyName;
  final num? value;
  final ValueChanged<num> onChanged;
  final num min;
  final num max;
  final num step;
  final int digits;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => WonkyNumberStepper(
    key: ValueKey<String>('slides.theme.number.$keyName'),
    value: value,
    min: min,
    max: max,
    step: step,
    fractionDigits: digits,
    dense: true,
    width: 56,
    enabled: enabled,
    semanticLabel: semanticLabel,
    onChanged: (v) {
      final n = double.parse(v.toStringAsFixed(digits));
      if (n != value) onChanged(digits == 0 ? n.round() : n);
    },
  );
}

/// A text field that commits on Enter or when it loses focus.
class ThemeCommitField extends StatefulWidget {
  const ThemeCommitField({
    super.key,
    required this.keyName,
    required this.value,
    required this.onCommit,
    this.enabled = true,
    this.semanticLabel,
    this.maxLength = 100,
  });

  final String keyName;
  final String value;
  final ValueChanged<String> onCommit;
  final bool enabled;
  final String? semanticLabel;
  final int maxLength;

  @override
  State<ThemeCommitField> createState() => _ThemeCommitFieldState();
}

class _ThemeCommitFieldState extends State<ThemeCommitField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(ThemeCommitField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final v = _controller.text.trim();
    if (v.isEmpty) {
      _controller.text = widget.value;
      return;
    }
    if (v != widget.value) widget.onCommit(v);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    textField: true,
    child: ShadInput(
      key: ValueKey<String>('slides.theme.field.${widget.keyName}'),
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      onSubmitted: (_) => _commit(),
    ),
  );
}

/// The face of bundled [family] when it is loaded (font pickers preview
/// families in their own face, 05 §3.4), else null.
TextStyle? fontPreviewStyle(String family) =>
    AssetFontRegistry.instance.isLoaded(family)
    ? TextStyle(fontFamily: family)
    : null;

/// "Accent 1", "Background 2", … of a scheme key.
String schemeKeyLabel(SlidesLocalizations l, String key) =>
    ElementStyle.themeColorLabel(l, key);
