import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/scene.dart' show ScenePurpose;

import '../stage/slide_renderer.dart';
import '../stage/slide_stage.dart';
import '../transitions/gpu/gpu_transitions.dart';
import '../transitions/magic_move_code.dart';
import '../transitions/magic_move_painter.dart';
import '../transitions/slide_snapshots.dart';
import '../transitions/transition_painter.dart';
import 'player/slide_player.dart';

/// Draws a [PlayerView] (06 §12): a slide in a timeline frame through the
/// [SlideStage] (code and chart nodes recomposed for the frame), a
/// snapshot transition as quads, a Magic Move live from both scenes, or
/// the degraded crossfade. Fills its box; the slide sits at [origin]
/// scaled by [scale] (px per su).
class PlayerStage extends StatelessWidget {
  const PlayerStage({
    super.key,
    required this.view,
    required this.renderer,
    required this.snapshots,
    required this.origin,
    required this.scale,
    this.semanticLabel,
    this.reducedMotion = false,
  });

  final PlayerView view;
  final SlideRenderer renderer;
  final SlideSnapshots snapshots;
  final Offset origin;
  final double scale;
  final String? semanticLabel;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final size = renderer.slideSize;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final px = scale * dpr;
    final v = view;
    Widget child;
    switch (v) {
      case SlidePlayerView():
        final scene = renderer.scene(v.slideId, purpose: ScenePurpose.present);
        if (scene == null) return const SizedBox.expand();
        return Stack(
          children: [
            Positioned(
              left: origin.dx,
              top: origin.dy,
              width: size.width * scale,
              height: size.height * scale,
              child: SlideStage(
                key: const ValueKey<String>('slides.motion.stage'),
                scene: snapshots.scenes.apply(
                  scene,
                  v.frame,
                  reducedMotion: reducedMotion,
                ),
                frame: v.frame,
                images: renderer.images,
                scale: scale,
                semanticLabel: semanticLabel,
              ),
            ),
          ],
        );
      case TransitionPlayerView():
        final mm = v.frame.magicMove;
        if (mm != null) {
          final from = renderer.scene(
            v.fromSlideId,
            purpose: ScenePurpose.present,
          );
          final to = renderer.scene(v.slideId, purpose: ScenePurpose.present);
          if (from == null || to == null) return const SizedBox.expand();
          var frame = mm;
          var toScene = snapshots.scenes.apply(to, mm.incoming);
          final fromScene = snapshots.scenes.apply(from, mm.outgoing);
          final plan = v.plan.magicMove;
          if (plan != null) {
            (frame, toScene) = MagicMoveCharts.apply(
              plan,
              frame,
              fromScene,
              toScene,
            );
            (frame, toScene) = MagicMoveCodeMorphs.apply(
              plan,
              frame,
              toScene,
              renderer.model,
              renderer.resolver.resolve(v.slideId),
            );
          }
          child = CustomPaint(
            key: const ValueKey<String>('slides.motion.magicMove'),
            painter: MagicMovePainter(
              frame: frame,
              from: fromScene,
              to: MagicMoveScenes.refine(toScene, frame),
              origin: origin,
              scale: scale,
              images: renderer.images,
              devicePixelRatio: dpr,
            ),
          );
        } else {
          child = CustomPaint(
            key: const ValueKey<String>('slides.motion.transition'),
            painter: TransitionPainter(
              frame: v.frame,
              outgoing: snapshots.imageOf(
                v.fromSlideId,
                v.fromFrame,
                pxPerSu: px,
              ),
              incoming: snapshots.imageOf(v.slideId, v.toFrame, pxPerSu: px),
              slideWidth: size.width,
              slideHeight: size.height,
              origin: origin,
              scale: scale,
              gpu: GpuTransitions.types.contains(v.plan.type),
              pixelRatio: dpr,
            ),
          );
        }
      case CrossfadePlayerView():
        child = CustomPaint(
          key: const ValueKey<String>('slides.motion.crossfade'),
          painter: CrossfadePainter(
            from: snapshots.imageOf(v.fromSlideId, v.fromFrame, pxPerSu: px),
            to: snapshots.imageOf(v.slideId, v.toFrame, pxPerSu: px),
            mix: v.mix,
            slideWidth: size.width,
            slideHeight: size.height,
            origin: origin,
            scale: scale,
          ),
        );
    }
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox.expand(child: child),
    );
  }
}
