import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The kiosk exit gesture (Slides 10 §9): with `exitGesture: holdEsc`,
/// holding `Esc` for [holdMs] ends the presentation while a progress ring
/// fills; releasing it earlier cancels. With `esc`, one press ends it.
class KioskExitGesture extends ChangeNotifier {
  KioskExitGesture({required this.onExit, int Function()? nowMs})
    : _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// How long `Esc` must be held.
  static const int holdMs = 2000;

  final VoidCallback onExit;
  final int Function() _now;

  int? _since;
  Timer? _timer;

  /// Whether `Esc` is held.
  bool get holding => _since != null;

  /// 0..1 while holding.
  double get progress {
    final s = _since;
    if (s == null) return 0;
    return ((_now() - s) / holdMs).clamp(0.0, 1.0);
  }

  /// `Esc` went down ([hold]: the hold gesture; else exit at once).
  void down({required bool hold}) {
    if (!hold) {
      onExit();
      return;
    }
    if (_since != null) return;
    _since = _now();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _check());
    notifyListeners();
  }

  void _check() {
    if (progress >= 1) {
      cancel();
      onExit();
    } else {
      notifyListeners();
    }
  }

  /// `Esc` went up (or the gesture was interrupted).
  void cancel() {
    _timer?.cancel();
    _timer = null;
    if (_since == null) return;
    _since = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// The progress ring of [KioskExitGesture] (shown only while `Esc` is
/// held).
class KioskExitRing extends StatelessWidget {
  const KioskExitRing({super.key, required this.gesture, required this.label});

  final KioskExitGesture gesture;
  final String label;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: gesture,
    builder: (context, _) {
      if (!gesture.holding) return const SizedBox.shrink();
      return Semantics(
        liveRegion: true,
        label: label,
        child: Column(
          key: const ValueKey<String>('slides.present.kioskExit'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 56,
              child: CustomPaint(painter: _RingPainter(gesture.progress)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xffe5e7eb), fontSize: 14),
            ),
          ],
        ),
      );
    },
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    canvas.drawOval(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x40ffffff),
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xffffffff),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
