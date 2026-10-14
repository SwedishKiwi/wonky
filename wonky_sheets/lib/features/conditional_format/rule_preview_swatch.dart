import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../theme/sheets_tokens.dart';
import 'cf_paint.dart';

/// `RulePreviewSwatch` (04 §13, 06 §15.9): a small preview of a CF rule —
/// "123" with the single-color format, a gradient for color scales, a bar
/// for data bars and the icons of an icon set.
class RulePreviewSwatch extends StatelessWidget {
  const RulePreviewSwatch({
    super.key,
    required this.rule,
    required this.theme,
    this.width = 44,
    this.height = 26,
    this.text = '123',
  });

  final CfRule rule;
  final SpreadsheetTheme theme;
  final double width;
  final double height;
  final String text;

  Color? _c(String? c) => hexToColor(theme.resolveColor(c));

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final tokens = GridPaintTokens.ofContext(context);
    final border = Border.all(color: shad.colorScheme.border);
    final radius = BorderRadius.circular(4);
    Widget box({Color? color, Gradient? gradient, Widget? child}) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? (gradient == null ? tokens.sheetBackground : null),
        gradient: gradient,
        borderRadius: radius,
        border: border,
      ),
      child: child,
    );
    switch (rule) {
      case CfBooleanRule(:final format):
        final decorations = [
          if (format[FormatAttr.underline] == true) TextDecoration.underline,
          if (format[FormatAttr.strikethrough] == true)
            TextDecoration.lineThrough,
        ];
        return box(
          color: _c(format[FormatAttr.fillColor] as String?),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color:
                  _c(format[FormatAttr.textColor] as String?) ??
                  (format[FormatAttr.fillColor] != null
                      ? const Color(0xFF000000)
                      : tokens.autoText),
              fontWeight: format[FormatAttr.bold] == true
                  ? FontWeight.w700
                  : FontWeight.w400,
              fontStyle: format[FormatAttr.italic] == true
                  ? FontStyle.italic
                  : FontStyle.normal,
              decoration: decorations.isEmpty
                  ? null
                  : TextDecoration.combine(decorations),
            ),
          ),
        );
      case CfColorScaleRule(:final points):
        final colors = [
          for (final p in points) _c(p.color) ?? const Color(0xFFFFFFFF),
        ];
        return box(
          gradient: LinearGradient(
            colors: colors.length == 1 ? [colors.first, colors.first] : colors,
          ),
        );
      case CfDataBarRule(:final color, :final gradient):
        final c = _c(color) ?? const Color(0xFF638EC6);
        return box(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(3),
              width: width * 0.62,
              decoration: BoxDecoration(
                color: gradient ? null : c,
                gradient: gradient
                    ? LinearGradient(colors: [c, c.withValues(alpha: 0.1)])
                    : null,
                border: Border.all(color: c),
              ),
            ),
          ),
        );
      case CfIconSetRule(:final set):
        return box(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < set.iconCount && i < 3; i++)
                CfIconView(setId: set.id, index: i, size: 11),
            ],
          ),
        );
      case CfUnknownRule():
        return box(child: const Icon(LucideIcons.circleHelp, size: 14));
    }
  }
}
