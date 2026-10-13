import 'dart:async';

import 'package:flutter/widgets.dart';

/// The chrome behaviour of focus mode (Write 04 §30): while [enabled], the
/// window chrome (title row, menubar, toolbar, status bar) is hidden through
/// [setChromeHidden]; moving the pointer to the top 8 px of the canvas shows
/// it again, and it hides once the pointer is back in the document.
class FocusModeChrome extends StatefulWidget {
  const FocusModeChrome({
    super.key,
    required this.enabled,
    required this.setChromeHidden,
    required this.child,
    this.rehideDelay = const Duration(milliseconds: 700),
  });

  final bool enabled;

  /// Hides (`true`) or shows the chrome (e.g. the shell's full-screen state).
  final ValueChanged<bool> setChromeHidden;
  final Widget child;
  final Duration rehideDelay;

  static const revealKey = ValueKey<String>('write.focusMode.reveal');

  @override
  State<FocusModeChrome> createState() => _FocusModeChromeState();
}

class _FocusModeChromeState extends State<FocusModeChrome> {
  bool _revealed = false;
  Timer? _rehide;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _schedule(() => widget.setChromeHidden(true));
  }

  @override
  void didUpdateWidget(FocusModeChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _revealed = false;
      _rehide?.cancel();
      final hide = widget.enabled;
      _schedule(() => widget.setChromeHidden(hide));
    }
  }

  @override
  void dispose() {
    _rehide?.cancel();
    if (widget.enabled) widget.setChromeHidden(false);
    super.dispose();
  }

  /// Chrome changes rebuild ancestors: never during this build.
  void _schedule(VoidCallback action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) action();
      });

  void _reveal() {
    if (!widget.enabled || _revealed) return;
    _rehide?.cancel();
    setState(() => _revealed = true);
    widget.setChromeHidden(false);
  }

  void _onCanvasHover(PointerEvent event) {
    if (!widget.enabled || !_revealed || event.localPosition.dy < 48) return;
    _rehide ??= Timer(widget.rehideDelay, () {
      _rehide = null;
      if (!mounted || !widget.enabled) return;
      setState(() => _revealed = false);
      widget.setChromeHidden(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The same tree in both states, so the canvas keeps its state.
    return Stack(
      children: [
        Positioned.fill(
          child: MouseRegion(
            onHover: _onCanvasHover,
            onEnter: _onCanvasHover,
            onExit: (_) {
              _rehide?.cancel();
              _rehide = null;
            },
            child: widget.child,
          ),
        ),
        if (widget.enabled && !_revealed)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 8,
            child: MouseRegion(
              key: FocusModeChrome.revealKey,
              opaque: false,
              onEnter: (_) => _reveal(),
            ),
          ),
      ],
    );
  }
}
