import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../stage/slide_renderer.dart';
import '../transitions/slide_snapshots.dart';
import 'motion_ticker.dart';
import 'player/slide_player.dart';
import 'player_stage.dart';

/// Renders any [PlayerView] (a slide in a timeline frame, a snapshot or
/// Magic Move transition, the degraded crossfade) fitted into its box
/// (or at [scale] px per su), centered on [letterbox] (06 §12). Shared by
/// present mode, the presenter view and the Animate tab's previews.
class MotionStage extends StatefulWidget {
  const MotionStage({
    super.key,
    required this.view,
    required this.renderer,
    this.scale,
    this.letterbox,
    this.reducedMotion = false,
    this.semanticLabel,
    this.snapshots,
  });

  /// What to draw (null = only the letterbox).
  final PlayerView? view;
  final SlideRenderer renderer;

  /// Logical px per su; null fits the slide into the box.
  final double? scale;

  /// Color around the slide (null = transparent).
  final Color? letterbox;
  final bool reducedMotion;
  final String? semanticLabel;

  /// Snapshot cache to share (null = one owned by this stage).
  final SlideSnapshots? snapshots;

  @override
  State<MotionStage> createState() => _MotionStageState();
}

class _MotionStageState extends State<MotionStage> {
  SlideSnapshots? _own;

  SlideSnapshots get _snapshots =>
      widget.snapshots ?? (_own ??= SlideSnapshots(widget.renderer));

  @override
  void didUpdateWidget(MotionStage old) {
    super.didUpdateWidget(old);
    if (!identical(old.renderer, widget.renderer)) {
      _own?.clear();
      _own = null;
    }
  }

  @override
  void dispose() {
    _own?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.renderer.slideSize;
    final view = widget.view;
    Widget content = LayoutBuilder(
      builder: (context, box) {
        final scale =
            widget.scale ??
            math.min(box.maxWidth / size.width, box.maxHeight / size.height);
        final w = size.width * scale, h = size.height * scale;
        final origin = Offset(
          box.maxWidth.isFinite ? (box.maxWidth - w) / 2 : 0,
          box.maxHeight.isFinite ? (box.maxHeight - h) / 2 : 0,
        );
        if (view == null) return const SizedBox.expand();
        return PlayerStage(
          view: view,
          renderer: widget.renderer,
          snapshots: _snapshots,
          origin: origin,
          scale: scale,
          semanticLabel: widget.semanticLabel,
          reducedMotion: widget.reducedMotion,
        );
      },
    );
    final bg = widget.letterbox;
    if (bg != null) content = ColoredBox(color: bg, child: content);
    return ClipRect(child: content);
  }
}

/// A [SlidePlayer] on a clock for previews (06 §5.5: one build, from
/// here, the whole slide with its transition; transition tiles): call the
/// player's methods with [now], then [changed]; [SlidePlaybackStage]
/// ticks while something runs.
class SlidePlayback extends ChangeNotifier {
  SlidePlayback({required this.player, int Function()? now}) : _clock = now;

  final SlidePlayer player;
  final int Function()? _clock;
  final Stopwatch _watch = Stopwatch()..start();

  /// The playback clock (ms; injectable for tests).
  int now() => _clock?.call() ?? _watch.elapsedMilliseconds;

  /// The view at [now].
  PlayerView? get view => player.viewAt(now());

  /// Whether a transition, build or loop is running.
  bool get animating => player.needsTicks(now());

  /// Notifies the stage after driving [player].
  void changed() => notifyListeners();
}

/// Draws a [SlidePlayback] with a [MotionStage], ticking while it runs.
class SlidePlaybackStage extends StatelessWidget {
  const SlidePlaybackStage({
    super.key,
    required this.playback,
    required this.renderer,
    this.scale,
    this.letterbox,
    this.reducedMotion = false,
    this.semanticLabel,
    this.snapshots,
  });

  final SlidePlayback playback;
  final SlideRenderer renderer;
  final double? scale;
  final Color? letterbox;
  final bool reducedMotion;
  final String? semanticLabel;
  final SlideSnapshots? snapshots;

  @override
  Widget build(BuildContext context) => MotionTicker(
    listenable: playback,
    active: () => playback.animating,
    builder: (context) => MotionStage(
      view: playback.view,
      renderer: renderer,
      scale: scale,
      letterbox: letterbox,
      reducedMotion: reducedMotion,
      semanticLabel: semanticLabel,
      snapshots: snapshots,
    ),
  );
}
