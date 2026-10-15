import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/themes.dart' show SlideAppearance;

import '../../l10n/slides_l10n.dart';
import '../motion/motion_ticker.dart';
import '../motion/player/slide_player.dart';
import '../motion/render/motion_masks.dart';
import '../motion/player_stage.dart';
import '../stage/slide_renderer.dart';
import '../transitions/gpu/gpu_transitions.dart';
import '../transitions/slide_snapshots.dart';
import 'present_controller.dart';
import 'present_ink.dart';
import 'present_sequence.dart';
import 'tools/code_copy_overlay.dart';

/// The audience rendering of a presentation (Slides 10 §8): the current
/// slide's frame, scaled to fit and centered on the letterbox color, with
/// the ink and laser layers, the black/white screen and the end screen.
///
/// [interactive] stages take pointer input (10 §2.1): with the arrow a
/// click or a tap on the right two-thirds advances, a tap on the left
/// third goes back, the wheel steps (when `wheelAdvance`), swipes navigate;
/// the laser follows the pointer (also while `Mod` is held) and the pen,
/// highlighter and eraser draw on the slide. The presenter view's current
/// slide is an interactive stage too: its pointer tools are mirrored to
/// the audience.
class PresentStage extends StatelessWidget {
  const PresentStage({
    super.key,
    required this.controller,
    required this.renderer,
    this.position,
    this.interactive = true,
    this.showOverlays = true,
    this.letterbox,
    this.onSecondaryTap,
    this.reduceMotion = false,
  });

  final PresentController controller;
  final SlideRenderer renderer;

  /// The slide to show (default: the controller's position) — the
  /// presenter view's *Next* preview passes the next position.
  final PresentPosition? position;
  final bool interactive;

  /// Ink, laser, black/white and the end screen (off for previews).
  final bool showOverlays;

  /// Color around the slide (default: the deck's letterbox color).
  final Color? letterbox;

  /// Right-click / two-finger tap (the present context menu).
  final void Function(Offset global)? onSecondaryTap;

  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => MotionTicker(
    listenable: Listenable.merge([controller, renderer]),
    // Previews of a fixed position are settled; the live stage ticks while
    // a transition or build runs (06 §6).
    active: () => position == null && controller.animating,
    onTick: position == null ? controller.animationFrame : null,
    builder: (context) {
      final c = controller;
      final p = position ?? c.position;
      final bg = letterbox ?? Color(c.settings.letterboxColor);
      final size = renderer.slideSize;
      return ColoredBox(
        color: bg,
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = math.min(
              box.maxWidth / size.width,
              box.maxHeight / size.height,
            );
            final w = size.width * scale, h = size.height * scale;
            final origin = Offset(
              (box.maxWidth - w) / 2,
              (box.maxHeight - h) / 2,
            );
            Offset toSu(Offset local) => (local - origin) / scale;
            final PlayerView? view = p == null
                ? null
                : position == null
                ? c.playerView
                : SlidePlayerView(
                    p.slideId,
                    p.step,
                    c.timelineOf(p.slideId).endOfStep(p.step),
                  );
            final dark = c.model.deck?.appearance == SlideAppearance.dark;
            final snapshots = SlideSnapshots.of(renderer);
            if (position == null && view is SlidePlayerView) {
              _prepareNext(context, snapshots, scale);
            }
            Widget stack = Stack(
              children: [
                if (view != null)
                  Positioned.fill(
                    child: PlayerStage(
                      view: view,
                      renderer: renderer,
                      snapshots: snapshots,
                      origin: origin,
                      scale: scale,
                      semanticLabel: _slideLabel(context, p!),
                      reducedMotion: reduceMotion,
                    ),
                  ),
                if (showOverlays && p != null)
                  Positioned(
                    left: origin.dx,
                    top: origin.dy,
                    width: w,
                    height: h,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _InkPainter(
                          strokes: [...c.ink.strokesOf(p.slideId), ?c.drawing],
                          scale: scale,
                          darkSlide: dark,
                        ),
                      ),
                    ),
                  ),
                if (showOverlays && c.laser != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LaserPainter(
                          trail: c.laserTrail,
                          origin: origin,
                          scale: scale,
                          color: Color(c.settings.laserArgb),
                        ),
                      ),
                    ),
                  ),
                if (showOverlays)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        key: const ValueKey<String>('slides.present.blank'),
                        opacity: c.blank == PresentBlank.none ? 0 : 1,
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: ColoredBox(
                          color: c.blank == PresentBlank.white
                              ? const Color(0xffffffff)
                              : const Color(0xff000000),
                        ),
                      ),
                    ),
                  ),
                if (showOverlays && c.endScreen)
                  const Positioned.fill(child: _EndScreen()),
                if (showOverlays && c.catchingUp)
                  const Positioned.fill(child: _CatchingUp()),
              ],
            );
            if (!interactive) return stack;
            final input = _PointerInput(
              controller: c,
              toSu: toSu,
              width: box.maxWidth,
              onSecondaryTap: onSecondaryTap,
              child: stack,
            );
            // Code copy buttons (07 §3.7) above the pointer input.
            final slide =
                view is SlidePlayerView &&
                    showOverlays &&
                    c.tool == PresentTool.arrow &&
                    !c.endScreen &&
                    c.blank == PresentBlank.none
                ? renderer.resolver.resolve(view.slideId)
                : null;
            if (slide == null || CodeCopyOverlay.targets(slide).isEmpty) {
              return input;
            }
            return Stack(
              children: [
                Positioned.fill(child: input),
                Positioned.fill(
                  child: CodeCopyOverlay(
                    model: c.model,
                    slide: slide,
                    frame: (view! as SlidePlayerView).frame,
                    origin: origin,
                    scale: scale,
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  /// Rasterizes the snapshots of the next slide's transition once the
  /// current slide has settled (06 §14: ready within 200 ms).
  void _prepareNext(
    BuildContext context,
    SlideSnapshots snapshots,
    double scale,
  ) {
    if (controller.animating) return;
    final r = controller.upcomingTransition;
    if (r == null) return;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final key =
        '${r.key}|${renderer.revision(r.fromSlideId)}|'
        '${renderer.revision(r.toSlideId)}|$scale|$dpr';
    if (_prepared[snapshots] == key) return;
    _prepared[snapshots] = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_prepared[snapshots] != key) return;
      final plan = controller.planOf(r);
      if (plan.isCut || plan.magicMove != null) return;
      final a = snapshots.prepare(
        r.fromSlideId,
        r.fromFrame,
        pxPerSu: scale * dpr,
      );
      final b = snapshots.prepare(r.toSlideId, r.toFrame, pxPerSu: scale * dpr);
      // Dissolve noise of the transition (06 §14: no first-frame work).
      for (final q in plan.frameAt(plan.durationMs ~/ 2).quads) {
        final d = q.dissolve;
        if (d != null) {
          DissolveNoise.prepare(Offset.zero & renderer.slideSize, d);
        }
      }
      if (GpuTransitions.types.contains(plan.type)) {
        // Upload both snapshots as textures for the 3D renderer.
        final gpu = GpuTransitions.instance;
        unawaited(
          gpu.ensureStarted().then((_) {
            if (a != null) gpu.prepare(a);
            if (b != null) gpu.prepare(b);
          }),
        );
      }
    });
  }

  static final Expando<String> _prepared = Expando('preparedTransition');

  String _slideLabel(BuildContext context, PresentPosition p) {
    final l = slidesL10n(context);
    final e = controller.sequence.order.entry(p.slideId);
    return l.presentSlideLabel(
      (e?.index ?? 0) + 1,
      controller.sequence.order.length,
    );
  }
}

/// Pointer input of an interactive stage.
class _PointerInput extends StatefulWidget {
  const _PointerInput({
    required this.controller,
    required this.toSu,
    required this.width,
    required this.child,
    this.onSecondaryTap,
  });

  final PresentController controller;
  final Offset Function(Offset local) toSu;
  final double width;
  final Widget child;
  final void Function(Offset global)? onSecondaryTap;

  @override
  State<_PointerInput> createState() => _PointerInputState();
}

class _PointerInputState extends State<_PointerInput> {
  Offset? _down;
  int? _downButtons;
  PointerDeviceKind? _kind;
  bool _moved = false;
  DateTime _downAt = DateTime.now();

  PresentController get c => widget.controller;

  bool get _modHeld {
    final k = HardwareKeyboard.instance;
    return k.isMetaPressed || k.isControlPressed;
  }

  void _onDown(PointerDownEvent e) {
    if (CodeCopyOverlay.claims(e.pointer)) {
      _down = null;
      _downButtons = null;
      return;
    }
    _down = e.localPosition;
    _downButtons = e.buttons;
    _kind = e.kind;
    _moved = false;
    _downAt = DateTime.now();
    if (e.buttons == kSecondaryMouseButton) return;
    if (c.tool != PresentTool.arrow) {
      c.pointerDown(widget.toSu(e.localPosition));
    }
  }

  void _onMove(PointerMoveEvent e) {
    final d = _down;
    if (d != null && (e.localPosition - d).distance > 8) _moved = true;
    if (c.tool != PresentTool.arrow || c.laserActive) {
      c.pointerMove(widget.toSu(e.localPosition));
    } else if (_kind == PointerDeviceKind.touch &&
        DateTime.now().difference(_downAt).inMilliseconds > 500 &&
        !_moved) {
      // Long-press = laser on touch (10 §2.1).
      c.setTemporaryLaser(true);
      c.pointerMove(widget.toSu(e.localPosition));
    }
  }

  void _onHover(PointerHoverEvent e) {
    c.setTemporaryLaser(_modHeld);
    if (c.laserActive) c.pointerMove(widget.toSu(e.localPosition));
  }

  void _onUp(PointerUpEvent e) {
    if (CodeCopyOverlay.claims(e.pointer)) return;
    final d = _down;
    final buttons = _downButtons;
    _down = null;
    if (buttons == kSecondaryMouseButton) {
      widget.onSecondaryTap?.call(e.position);
      return;
    }
    if (c.tool != PresentTool.arrow) {
      c.pointerUp();
      return;
    }
    if (_kind == PointerDeviceKind.touch && c.laserActive) {
      c.setTemporaryLaser(false);
      return;
    }
    if (d == null) return;
    final delta = e.localPosition - d;
    if (_moved && _kind != PointerDeviceKind.mouse) {
      // Swipe left = next, right = previous.
      if (delta.dx.abs() > 40 && delta.dx.abs() > delta.dy.abs()) {
        delta.dx < 0 ? c.next() : c.previous();
      }
      return;
    }
    if (_moved) return;
    if (_kind == PointerDeviceKind.mouse) {
      c.next();
    } else if (d.dx < widget.width / 3) {
      c.previous();
    } else {
      c.next();
    }
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !c.settings.wheelAdvance) return;
    if (e.scrollDelta.dy.abs() < 4) return;
    e.scrollDelta.dy > 0 ? c.next() : c.previous();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: _onHover,
    onExit: (_) {
      if (c.laserActive) c.setLaser(null);
    },
    cursor: c.tool == PresentTool.arrow
        ? MouseCursor.defer
        : SystemMouseCursors.precise,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerSignal: _onSignal,
      child: widget.child,
    ),
  );
}

class _InkPainter extends CustomPainter {
  _InkPainter({
    required this.strokes,
    required this.scale,
    required this.darkSlide,
  });

  final List<InkStroke> strokes;
  final double scale;
  final bool darkSlide;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    for (final s in strokes) {
      final hl = s.tool == PresentTool.highlighter;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = Color(
          s.color,
        ).withValues(alpha: hl ? InkColors.highlighterOpacity : 1);
      // The highlighter multiplies on light slides and screens on dark
      // ones (10 §4.3), so text stays readable underneath.
      if (hl) {
        paint.blendMode = darkSlide ? BlendMode.screen : BlendMode.multiply;
      }
      canvas.drawPath(s.path(), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InkPainter old) =>
      old.scale != scale ||
      old.darkSlide != darkSlide ||
      old.strokes.length != strokes.length ||
      !_same(old.strokes, strokes);

  static bool _same(List<InkStroke> a, List<InkStroke> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }
}

class _LaserPainter extends CustomPainter {
  _LaserPainter({
    required this.trail,
    required this.origin,
    required this.scale,
    required this.color,
  });

  /// Positions in su with their age (ms), newest last.
  final List<(Offset, int)> trail;
  final Offset origin;
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.isEmpty) return;
    Offset at(Offset su) => origin + su * scale;
    // A short fading trail (last 300 ms), then the dot: 12 su core with a
    // 40 su glow (10 §4.2), never smaller than a few pixels.
    for (var i = 0; i + 1 < trail.length; i++) {
      final age = trail[i].$2;
      final a = (1 - age / 300).clamp(0.0, 1.0) * 0.5;
      canvas.drawLine(
        at(trail[i].$1),
        at(trail[i + 1].$1),
        Paint()
          ..color = color.withValues(alpha: a)
          ..strokeWidth = math.max(3, 8 * scale)
          ..strokeCap = StrokeCap.round,
      );
    }
    final p = at(trail.last.$1);
    final core = math.max(4.0, 6 * scale);
    final glow = math.max(10.0, 20 * scale);
    canvas.drawCircle(
      p,
      glow,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow / 2),
    );
    canvas.drawCircle(p, core, Paint()..color = color);
    canvas.drawCircle(p, core * 0.45, Paint()..color = const Color(0xccffffff));
  }

  @override
  bool shouldRepaint(_LaserPainter old) => true;
}

class _EndScreen extends StatelessWidget {
  const _EndScreen();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey<String>('slides.present.endScreen'),
    color: const Color(0xff000000),
    child: Center(
      child: Text(
        slidesL10n(context).presentEndScreen,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xff9ca3af), fontSize: 18),
      ),
    ),
  );
}

class _CatchingUp extends StatelessWidget {
  const _CatchingUp();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey<String>('slides.present.catchingUp'),
    color: const Color(0xcc000000),
    child: Center(
      child: Semantics(
        liveRegion: true,
        child: Text(
          slidesL10n(context).presentCatchingUp,
          style: const TextStyle(color: Color(0xffe5e7eb), fontSize: 18),
        ),
      ),
    ),
  );
}
