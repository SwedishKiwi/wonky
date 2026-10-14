import 'package:flutter/widgets.dart' hide BorderStyle;
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';

/// The border picker popover (04 §4.1): 10 presets, a color and a style.
/// Color and style persist for the session and apply to the next preset.
class BorderPicker extends StatefulWidget {
  const BorderPicker({super.key, required this.onApply});

  /// Called with `(preset, style, color)`.
  final void Function(BorderPreset preset, BorderStyle style, String color)
  onApply;

  static BorderStyle _style = BorderStyle.thin;
  static String _color = 'auto';

  @override
  State<BorderPicker> createState() => _BorderPickerState();
}

class _BorderPickerState extends State<BorderPicker> {
  bool _pickingColor = false;

  static IconData _icon(BorderPreset p) => switch (p) {
    BorderPreset.all => LucideIcons.grid2x2,
    BorderPreset.inner => LucideIcons.plus,
    BorderPreset.horizontal => LucideIcons.minus,
    BorderPreset.vertical => LucideIcons.separatorVertical,
    BorderPreset.outer => LucideIcons.square,
    BorderPreset.left => LucideIcons.panelLeft,
    BorderPreset.top => LucideIcons.panelTop,
    BorderPreset.right => LucideIcons.panelRight,
    BorderPreset.bottom => LucideIcons.panelBottom,
    BorderPreset.clear => LucideIcons.squareDashed,
  };

  static String _label(SheetsLocalizations l, BorderPreset p) => switch (p) {
    BorderPreset.all => l.borderAll,
    BorderPreset.inner => l.borderInner,
    BorderPreset.horizontal => l.borderHorizontal,
    BorderPreset.vertical => l.borderVertical,
    BorderPreset.outer => l.borderOuter,
    BorderPreset.left => l.borderLeft,
    BorderPreset.top => l.borderTop,
    BorderPreset.right => l.borderRight,
    BorderPreset.bottom => l.borderBottom,
    BorderPreset.clear => l.borderClear,
  };

  static String _styleLabel(SheetsLocalizations l, BorderStyle s) =>
      switch (s) {
        BorderStyle.thin => l.borderStyleThin,
        BorderStyle.medium => l.borderStyleMedium,
        BorderStyle.thick => l.borderStyleThick,
        BorderStyle.dashed => l.borderStyleDashed,
        BorderStyle.dotted => l.borderStyleDotted,
        BorderStyle.double => l.borderStyleDouble,
      };

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    if (_pickingColor) {
      return WonkyColorPicker(
        value: BorderPicker._color == 'auto'
            ? null
            : WonkyColor.tryParse(BorderPicker._color),
        resetLabel: l.colorAutomatic,
        onChanged: (c) => setState(() {
          BorderPicker._color = c == null ? 'auto' : c.hex.toUpperCase();
          _pickingColor = false;
        }),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 5 * 34,
            child: Wrap(
              children: [
                for (final p in BorderPreset.values)
                  ShadTooltip(
                    builder: (_) => Text(_label(l, p)),
                    child: ShadIconButton.ghost(
                      key: ValueKey<String>('sheets.border.${p.name}'),
                      width: 32,
                      height: 32,
                      icon: Icon(_icon(p), size: 16),
                      semanticLabel: _label(l, p),
                      onPressed: () => widget.onApply(
                        p,
                        BorderPicker._style,
                        BorderPicker._color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: theme.colorScheme.border,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShadButton.ghost(
                key: const ValueKey<String>('sheets.border.color'),
                size: ShadButtonSize.sm,
                leading: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: BorderPicker._color == 'auto'
                        ? theme.colorScheme.foreground
                        : WonkyColor.tryParse(BorderPicker._color)?.toColor(),
                    border: Border.all(color: theme.colorScheme.border),
                  ),
                ),
                onPressed: () => setState(() => _pickingColor = true),
                child: Text(l.borderColor),
              ),
              for (final s in BorderStyle.values)
                ShadButton.ghost(
                  key: ValueKey<String>('sheets.border.style.${s.name}'),
                  size: ShadButtonSize.sm,
                  leading: Icon(
                    s == BorderPicker._style
                        ? LucideIcons.check
                        : LucideIcons.minus,
                    size: 14,
                  ),
                  onPressed: () => setState(() => BorderPicker._style = s),
                  child: Text(_styleLabel(l, s)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
