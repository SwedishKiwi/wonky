import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';

/// The "Theme colors" row of the Sheets color pickers (06 §6.3, §13.1):
/// accent 1–6, text, background and link; picking one stores
/// `theme:<key>` so the color follows theme changes.
List<WonkyThemeSwatch> sheetsThemeSwatches(
  SpreadsheetTheme theme,
  SheetsLocalizations l,
) => [
  for (final key in const [
    'text',
    'background',
    'accent1',
    'accent2',
    'accent3',
    'accent4',
    'accent5',
    'accent6',
    'link',
  ])
    WonkyThemeSwatch(
      color: WonkyColor(
        (theme.resolveColor('theme:$key') ?? '#000000').toLowerCase(),
        themeRef: 'theme:$key',
      ),
      name: themeColorLabel(l, key),
    ),
];

/// Localized name of a theme color key.
String themeColorLabel(SheetsLocalizations l, String key) => switch (key) {
  'text' => l.themeColorText,
  'background' => l.themeColorBackground,
  'link' => l.themeColorLink,
  _ when key.startsWith('accent') => l.themeColorAccent(
    int.tryParse(key.substring(6)) ?? 1,
  ),
  _ => key,
};

/// The stored color string of a picked color: `theme:<key>` for theme
/// swatches, else `#RRGGBB`.
String storedColorOf(WonkyColor c) {
  final ref = c.themeRef;
  if (ref != null && ref.startsWith('theme:')) return ref;
  final hex = c.hex.toUpperCase();
  return hex.length > 7 ? hex.substring(0, 7) : hex;
}

/// A picker value for a stored color (`#RRGGBB` or `theme:*`).
WonkyColor? pickerValueOf(String? stored, SpreadsheetTheme theme) {
  if (stored == null) return null;
  final hex = theme.resolveColor(stored);
  if (hex == null) return null;
  return WonkyColor(
    hex.toLowerCase(),
    themeRef: stored.startsWith('theme:') ? stored : null,
  );
}

/// A button showing a color swatch that opens a [WonkyColorPicker] with the
/// spreadsheet's theme colors (panels: CF formats, banding, theme editor).
class SheetsColorButton extends StatefulWidget {
  const SheetsColorButton({
    super.key,
    required this.value,
    required this.theme,
    required this.onChanged,
    this.label,
    this.resetLabel,
    this.withThemeColors = true,
    this.enabled = true,
    this.icon,
    this.compact = false,
  });

  /// The stored color (`#RRGGBB`, `theme:*`) or null (automatic / none).
  final String? value;
  final SpreadsheetTheme theme;
  final ValueChanged<String?> onChanged;

  /// Accessible name (and visible text unless [compact]).
  final String? label;

  /// Shows a reset button (null = none).
  final String? resetLabel;
  final bool withThemeColors;
  final bool enabled;

  /// Icon drawn above the color bar in [compact] mode (text/fill color).
  final IconData? icon;
  final bool compact;

  @override
  State<SheetsColorButton> createState() => _SheetsColorButtonState();
}

class _SheetsColorButtonState extends State<SheetsColorButton> {
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final shad = ShadTheme.of(context);
    final hex = widget.theme.resolveColor(widget.value);
    final color = hexToColor(hex);
    final swatch = Container(
      width: widget.compact ? 16 : 14,
      height: widget.compact ? 4 : 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(widget.compact ? 1 : 3),
        border: Border.all(color: shad.colorScheme.border),
      ),
    );
    final name = widget.label ?? '';
    final valueText = widget.value == null
        ? (widget.resetLabel ?? '')
        : widget.value!.startsWith('theme:')
        ? themeColorLabel(l, widget.value!.substring(6))
        : hex ?? '';
    return ShadPopover(
      controller: _popover,
      popover: (context) => WonkyColorPicker(
        value: pickerValueOf(widget.value, widget.theme),
        themeColors: widget.withThemeColors
            ? sheetsThemeSwatches(widget.theme, l)
            : const [],
        resetLabel: widget.resetLabel,
        onChanged: (c) {
          _popover.hide();
          widget.onChanged(c == null ? null : storedColorOf(c));
        },
      ),
      child: Semantics(
        button: true,
        label: name.isEmpty ? valueText : '$name: $valueText',
        child: ShadTooltip(
          builder: (_) => Text(name.isEmpty ? valueText : name),
          child: widget.compact
              ? ShadIconButton.ghost(
                  width: 30,
                  height: 30,
                  enabled: widget.enabled,
                  onPressed: _popover.toggle,
                  icon: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon ?? LucideIcons.palette, size: 14),
                      const SizedBox(height: 2),
                      swatch,
                    ],
                  ),
                )
              : ShadButton.outline(
                  size: ShadButtonSize.sm,
                  enabled: widget.enabled,
                  mainAxisAlignment: MainAxisAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: _popover.toggle,
                  leading: swatch,
                  child: Flexible(
                    child: Text(
                      valueText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
