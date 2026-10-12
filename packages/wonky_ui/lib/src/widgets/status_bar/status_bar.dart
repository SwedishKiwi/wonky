import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../theme/wonky_theme.dart';

/// The 24 px bottom bar of editor screens (suite 02 §4.13): [left] (word
/// count / selection stats), [center] (sync status), [right] (zoom, view
/// toggles).
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    this.left = const [],
    this.center = const [],
    this.right = const [],
  });

  final List<Widget> left;
  final List<Widget> center;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ext = WonkyThemeScope.of(context);
    Widget group(List<Widget> items, MainAxisAlignment align) => Row(
      mainAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          items[i],
        ],
      ],
    );
    return Semantics(
      container: true,
      liveRegion: false,
      child: Container(
        height: ext.statusBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          border: Border(top: BorderSide(color: theme.colorScheme.border)),
        ),
        child: DefaultTextStyle.merge(
          style: theme.textTheme.muted.copyWith(fontSize: 12, height: 1),
          child: IconTheme.merge(
            data: IconThemeData(
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ClipRect(
                      child: group(left, MainAxisAlignment.start),
                    ),
                  ),
                ),
                group(center, MainAxisAlignment.center),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ClipRect(child: group(right, MainAxisAlignment.end)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small text button for the status bar ("Sum: 1,234 ▾", "100 %").
class StatusBarButton extends StatelessWidget {
  const StatusBarButton({
    super.key,
    required this.child,
    this.onPressed,
    this.tooltip,
    this.icon,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ext = WonkyThemeScope.of(context);
    Widget b = ShadButton.ghost(
      height: ext.statusBarHeight - 4,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: onPressed,
      leading: icon == null ? null : Icon(icon, size: 14),
      textStyle: theme.textTheme.muted.copyWith(fontSize: 12),
      child: child,
    );
    if (tooltip != null) {
      b = ShadTooltip(builder: (_) => Text(tooltip!), child: b);
    }
    return b;
  }
}
