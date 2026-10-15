import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds [builder] on every animation frame while [active] says an
/// animation runs (a [SlidePlayer] transition or build, 06 §6), and when
/// [listenable] changes. Idle stages don't tick.
class MotionTicker extends StatefulWidget {
  const MotionTicker({
    super.key,
    required this.listenable,
    required this.active,
    required this.builder,
    this.onTick,
  });

  final Listenable listenable;

  /// Whether the next frame differs from this one.
  final bool Function() active;
  final WidgetBuilder builder;

  /// Called on every tick before the rebuild (frame-time bookkeeping).
  final VoidCallback? onTick;

  @override
  State<MotionTicker> createState() => _MotionTickerState();
}

class _MotionTickerState extends State<MotionTicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_changed);
    _sync();
  }

  @override
  void didUpdateWidget(MotionTicker old) {
    super.didUpdateWidget(old);
    if (!identical(old.listenable, widget.listenable)) {
      old.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
    _sync();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _sync();
  }

  void _sync() {
    final on = widget.active();
    if (on && !_ticker.isActive) {
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration _) {
    if (!mounted) return;
    widget.onTick?.call();
    setState(() {});
    // One more frame after the animation ends shows the settled frame.
    if (!widget.active()) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
