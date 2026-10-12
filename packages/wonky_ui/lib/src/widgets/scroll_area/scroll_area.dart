import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../theme/wonky_theme.dart';

/// Thin, auto-hiding scrollbars in shad colors plus top/bottom "scroll
/// shadows" (suite 02 §4.12). [child] must be a scrollable that uses
/// [controller].
class WonkyScrollArea extends StatefulWidget {
  const WonkyScrollArea({
    super.key,
    required this.controller,
    required this.child,
    this.axis = Axis.vertical,
    this.showShadows = true,
    this.alwaysShowScrollbar = false,
  });

  final ScrollController controller;
  final Widget child;
  final Axis axis;
  final bool showShadows;
  final bool alwaysShowScrollbar;

  @override
  State<WonkyScrollArea> createState() => _WonkyScrollAreaState();
}

class _WonkyScrollAreaState extends State<WonkyScrollArea> {
  bool _before = false;
  bool _after = false;

  bool _onMetrics(ScrollMetrics m) {
    final before = m.extentBefore > 0.5;
    final after = m.extentAfter > 0.5;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ext = WonkyThemeScope.of(context);
    final vertical = widget.axis == Axis.vertical;
    final shadow = theme.brightness == Brightness.dark
        ? const Color(0x66000000)
        : const Color(0x1f000000);
    Widget edge(bool start) => IgnorePointer(
      child: AnimatedOpacity(
        opacity: (start ? _before : _after) ? 1 : 0,
        duration: ext.motion(context, 150),
        child: Container(
          width: vertical ? null : 8,
          height: vertical ? 8 : null,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: vertical
                  ? (start ? Alignment.topCenter : Alignment.bottomCenter)
                  : (start ? Alignment.centerLeft : Alignment.centerRight),
              end: vertical
                  ? (start ? Alignment.bottomCenter : Alignment.topCenter)
                  : (start ? Alignment.centerRight : Alignment.centerLeft),
              colors: [shadow, shadow.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: Stack(
          children: [
            RawScrollbar(
              controller: widget.controller,
              thumbVisibility: widget.alwaysShowScrollbar,
              thickness: ext.scrollbarThickness - 2,
              radius: const Radius.circular(8),
              thumbColor: theme.colorScheme.border,
              fadeDuration: ext.motion(context, 300),
              timeToFade: const Duration(milliseconds: 900),
              interactive: true,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: widget.child,
              ),
            ),
            if (widget.showShadows) ...[
              if (vertical) ...[
                Positioned(top: 0, left: 0, right: 0, child: edge(true)),
                Positioned(bottom: 0, left: 0, right: 0, child: edge(false)),
              ] else ...[
                Positioned(top: 0, bottom: 0, left: 0, child: edge(true)),
                Positioned(top: 0, bottom: 0, right: 0, child: edge(false)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
