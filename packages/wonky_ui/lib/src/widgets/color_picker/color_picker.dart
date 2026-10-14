import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';
import 'custom_color_panel.dart';
import 'wonky_color.dart';

/// A named theme color offered in the "Theme colors" row.
class WonkyThemeSwatch {
  const WonkyThemeSwatch({required this.color, required this.name});

  final WonkyColor color;
  final String name;
}

/// Color picker popover content (suite 02 §4.4): reset button, 10×8 palette,
/// theme colors, recent/custom colors and an inline custom-color panel.
///
/// Keyboard: arrows move over the swatches, Enter/Space selects. Each swatch
/// has an accessible name ("light red 2"). [onChanged] receives null for
/// reset (Automatic / None).
class WonkyColorPicker extends StatefulWidget {
  const WonkyColorPicker({
    super.key,
    required this.onChanged,
    this.value,
    this.themeColors = const [],
    this.themeColorsLabel,
    this.recentColors = const [],
    this.resetLabel,
    this.resetIcon = LucideIcons.eraser,
    this.allowAlpha = false,
    this.onEyedropper,
    this.onCustomColorAdded,
  });

  final WonkyColor? value;
  final ValueChanged<WonkyColor?> onChanged;
  final List<WonkyThemeSwatch> themeColors;

  /// Heading of the [themeColors] row (default "Theme colors").
  final String? themeColorsLabel;
  final List<WonkyColor> recentColors;

  /// "Automatic" / "None"; null hides the reset button.
  final String? resetLabel;
  final IconData resetIcon;
  final bool allowAlpha;

  /// Desktop eyedropper; null hides the button.
  final Future<Color?> Function()? onEyedropper;

  /// Called when a custom color is confirmed (to store it in recents).
  final ValueChanged<WonkyColor>? onCustomColorAdded;

  @override
  State<WonkyColorPicker> createState() => _WonkyColorPickerState();
}

class _Swatch {
  const _Swatch(this.color, this.name);
  final WonkyColor color;
  final String name;
}

class _WonkyColorPickerState extends State<WonkyColorPicker> {
  final _focus = FocusNode(debugLabel: 'WonkyColorPicker');
  int _row = 0;
  int _col = 0;
  bool _keyboardActive = false;
  bool _custom = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<List<_Swatch>> _rows(WonkyUiLocalizations l10n) {
    final hues = [
      l10n.hueRedBerry,
      l10n.hueRed,
      l10n.hueOrange,
      l10n.hueYellow,
      l10n.hueGreen,
      l10n.hueCyan,
      l10n.hueCornflowerBlue,
      l10n.hueBlue,
      l10n.huePurple,
      l10n.hueMagenta,
    ];
    final grays = [
      l10n.colorBlack,
      l10n.colorDarkGray(4),
      l10n.colorDarkGray(3),
      l10n.colorDarkGray(2),
      l10n.colorDarkGray(1),
      l10n.colorGray,
      l10n.colorLightGray(1),
      l10n.colorLightGray(2),
      l10n.colorLightGray(3),
      l10n.colorWhite,
    ];
    String name(int r, int c) => switch (r) {
      0 => grays[c],
      1 => hues[c],
      2 => l10n.colorLight(hues[c], 3),
      3 => l10n.colorLight(hues[c], 2),
      4 => l10n.colorLight(hues[c], 1),
      5 => l10n.colorDark(hues[c], 1),
      6 => l10n.colorDark(hues[c], 2),
      _ => l10n.colorDark(hues[c], 3),
    };
    return [
      for (var r = 0; r < WonkyColorPalette.rows.length; r++)
        [
          for (var c = 0; c < 10; c++)
            _Swatch(WonkyColorPalette.at(r, c), name(r, c)),
        ],
      if (widget.themeColors.isNotEmpty)
        [for (final t in widget.themeColors.take(10)) _Swatch(t.color, t.name)],
      if (widget.recentColors.isNotEmpty)
        [
          for (final c in widget.recentColors.take(10))
            _Swatch(c, c.hex.toUpperCase()),
        ],
    ];
  }

  KeyEventResult _onKey(
    FocusNode node,
    KeyEvent event,
    List<List<_Swatch>> rows,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    int r = _row, c = _col;
    if (key == LogicalKeyboardKey.arrowRight) {
      c++;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      c--;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      r++;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      r--;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.numpadEnter) {
      widget.onChanged(rows[_row][_col].color);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.home) {
      c = 0;
    } else if (key == LogicalKeyboardKey.end) {
      c = rows[r].length - 1;
    } else {
      return KeyEventResult.ignored;
    }
    r = r.clamp(0, rows.length - 1);
    c = c.clamp(0, rows[r].length - 1);
    setState(() {
      _row = r;
      _col = c;
      _keyboardActive = true;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = WonkyUiLocalizations.of(context);
    final theme = ShadTheme.of(context);
    if (_custom) {
      return CustomColorPanel(
        initial: widget.value?.toColor() ?? const Color(0xff1a73e8),
        allowAlpha: widget.allowAlpha,
        onEyedropper: widget.onEyedropper,
        onCancel: () => setState(() => _custom = false),
        onApply: (color) {
          final c = WonkyColor.fromColor(color);
          widget.onCustomColorAdded?.call(c);
          widget.onChanged(c);
          setState(() => _custom = false);
        },
      );
    }
    final rows = _rows(l10n);
    final paletteRows = WonkyColorPalette.rows.length;
    final themeRow = widget.themeColors.isNotEmpty ? paletteRows : null;
    final recentRow = widget.recentColors.isNotEmpty
        ? paletteRows + (themeRow == null ? 0 : 1)
        : null;

    Widget rowWidget(int r) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var c = 0; c < rows[r].length; c++)
          _SwatchCell(
            key: ValueKey<String>('colorPicker.swatch.$r.$c'),
            swatch: rows[r][c],
            selected:
                widget.value?.hex == rows[r][c].color.hex &&
                widget.value?.themeRef == rows[r][c].color.themeRef,
            highlighted:
                _keyboardActive && _focus.hasFocus && _row == r && _col == c,
            onTap: () => widget.onChanged(rows[r][c].color),
          ),
      ],
    );

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.small.copyWith(
          fontSize: 12,
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(node, event, rows),
      onFocusChange: (_) => setState(() {}),
      child: SizedBox(
        width: 10 * 22.0 + 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.resetLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ShadButton.ghost(
                  key: const ValueKey<String>('colorPicker.reset'),
                  height: 30,
                  leading: Icon(widget.resetIcon, size: 16),
                  mainAxisAlignment: MainAxisAlignment.start,
                  onPressed: () => widget.onChanged(null),
                  child: Text(widget.resetLabel!),
                ),
              ),
            rowWidget(0),
            const SizedBox(height: 6),
            rowWidget(1),
            const SizedBox(height: 6),
            for (var r = 2; r < paletteRows; r++) rowWidget(r),
            if (themeRow != null) ...[
              sectionLabel(widget.themeColorsLabel ?? l10n.colorThemeColors),
              rowWidget(themeRow),
            ],
            sectionLabel(l10n.colorRecentColors),
            Row(
              children: [
                if (recentRow != null) Flexible(child: rowWidget(recentRow)),
                ShadIconButton.ghost(
                  key: const ValueKey<String>('colorPicker.custom'),
                  width: 22,
                  height: 22,
                  iconSize: 14,
                  semanticLabel: l10n.colorCustom,
                  icon: const Icon(LucideIcons.plus),
                  onPressed: () => setState(() => _custom = true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwatchCell extends StatefulWidget {
  const _SwatchCell({
    super.key,
    required this.swatch,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final _Swatch swatch;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_SwatchCell> createState() => _SwatchCellState();
}

class _SwatchCellState extends State<_SwatchCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = widget.swatch.color.toColor();
    final light = color.computeLuminance() > 0.6;
    final ring = widget.highlighted || _hover;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.swatch.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: ShadTooltip(
            builder: (_) => Text(widget.swatch.name),
            child: Container(
              width: 22,
              height: 22,
              padding: const EdgeInsets.all(2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ring
                        ? theme.colorScheme.ring
                        : light
                        ? theme.colorScheme.border
                        : color,
                    width: ring ? 2 : 1,
                  ),
                ),
                child: widget.selected
                    ? Icon(
                        LucideIcons.check,
                        size: 12,
                        color: light
                            ? const Color(0xff18181b)
                            : const Color(0xffffffff),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
