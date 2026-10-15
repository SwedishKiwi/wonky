/// The transition compiler (06 §7–§9.5, §13): compiles a slide's entry
/// transition (`Slide.transitionJson`, or the deck default) into a
/// [TransitionPlan] — the effective type after fallbacks (unknown and P2
/// types play as `fade`; Magic Move without matches plays as a crossfade;
/// reduced motion turns everything into a 300 ms fade), the duration, the
/// easing, the Magic Move plan, and deterministic frame evaluation for the
/// player (SL-29) and the Transition tab previews (SL-30).
///
/// **Directions.** `from` is always the slide being left and `to` the
/// slide being entered. Going back with `reverseOnBack` (06 §6) plays the
/// *left* slide's transition reversed: pass that slide's transition with
/// [TransitionOptions.reverse]; snapshot types then play mirrored (push
/// left becomes push right; the frames are the forward frames walked
/// backwards with the easing applied forwards), Magic Move morphs from the
/// left slide to the entered one.
library;

import '../../model/api/deck_model.dart';
import '../../model/api/deck_reader.dart';
import '../../model/resolve/slide_resolver.dart';
import '../../scene/nodes/scene_nodes.dart' show SlideScene;
import '../../scene/nodes/text_layout.dart' show TextLayoutEngine;
import '../builds/transition_spec.dart';
import '../easing/motion_easing.dart';
import '../magic_move/chart_camera.dart';
import '../magic_move/magic_move_plan.dart';
import '../magic_move/magic_move_slide.dart';
import '../timeline/motion_input.dart' show MotionColorResolver;
import '../timeline/slide_frame.dart';
import '../timeline/slide_timeline.dart' show TimelineWarning;
import '../util/seeded_random.dart';
import 'transition_frame.dart';
import 'transition_programs.dart';

/// Options of [TransitionCompiler.compile].
final class TransitionOptions {
  /// Creates options.
  const TransitionOptions({
    this.slideWidth = 1920,
    this.slideHeight = 1080,
    this.reducedMotion = false,
    this.reverse = false,
    this.seedKey = '',
    this.resolveColor,
    this.cameraLerp = ChartCameraView.lerp,
  });

  /// Slide size (su).
  final double slideWidth, slideHeight;

  /// 06 §13: every transition becomes a 300 ms fade (Magic Move a 300 ms
  /// crossfade).
  final bool reducedMotion;

  /// Plays the transition backwards (navigating back, 06 §6).
  final bool reverse;

  /// Seeds the dissolve noise (`hash("transition:<seedKey>")`; use the
  /// entered slide's id so every client draws the same noise).
  final String seedKey;

  /// Resolves `fade.through` theme colors (`theme:<key>`); hex colors,
  /// `black` and `white` need none.
  final MotionColorResolver? resolveColor;

  /// Camera interpolation of 3D charts in Magic Move (the SL-27 seam).
  final ChartCameraLerp cameraLerp;
}

/// Length of every reduced-motion transition (06 §13).
const int reducedMotionMs = 300;

/// The compiled transition between two slides (06 §9.5).
final class TransitionPlan {
  TransitionPlan._({
    required this.requestedType,
    required this.type,
    required this.spec,
    required this.durationMs,
    required this.curve,
    required this.reverse,
    required this.width,
    required this.height,
    required this.from,
    required this.to,
    this.magicMove,
    this.throughColor,
    this.seed = 0,
    this.warnings = const [],
  });

  /// A cut (no animation; `type: none`).
  static final cut = TransitionPlan._(
    requestedType: 'none',
    type: 'none',
    spec: TransitionSpec.none,
    durationMs: 0,
    curve: MotionEasing.linear,
    reverse: false,
    width: 1920,
    height: 1080,
    from: SlideFrame.edit,
    to: SlideFrame.edit,
  );

  /// The type of the transition JSON.
  final String requestedType;

  /// The type played (after fallbacks and reduced motion).
  final String type;

  /// The transition (decoded, with its parameters).
  final TransitionSpec spec;

  /// Length (ms; springs: their settle time; Magic Move: incl. stagger).
  final int durationMs;

  /// The easing (applied to the forward progress).
  final MotionEasing curve;

  /// Played backwards (06 §6).
  final bool reverse;

  /// Slide size (su).
  final double width, height;

  /// The outgoing slide's frame (its final frame) and the incoming slide's
  /// (its initial frame): snapshot transitions rasterize these.
  final SlideFrame from, to;

  /// The Magic Move plan when [type] is `magicMove`.
  final MagicMovePlan? magicMove;

  /// `fade.through` color (ARGB), or null.
  final int? throughColor;

  /// Dissolve seed.
  final int seed;

  /// Fallbacks taken (`unknownTransition`, `unavailableTransition`,
  /// `reducedMotion`, `magicMoveNoMatches`, `magicMoveNoSlides`).
  final List<TimelineWarning> warnings;

  /// Whether this is a cut.
  bool get isCut => type == 'none' || durationMs <= 0;

  /// Whether the type is drawn with 3D perspective (06 §7.2).
  bool get is3d => TransitionCatalog.byId(type)?.is3d ?? false;

  /// Ids leaving with the outgoing slide (Magic Move: unmatched elements).
  List<String> get outgoing => magicMove?.outgoingIds ?? const [];

  /// Ids arriving with the incoming slide (Magic Move: unmatched elements).
  List<String> get incoming => magicMove?.incomingIds ?? const [];

  /// The frame at [ms] since the transition started (clamped to
  /// `[0, durationMs]`; `≥ durationMs` = the incoming slide alone).
  TransitionFrame frameAt(int ms) {
    final t = durationMs <= 0 ? 1.0 : (ms / durationMs).clamp(0.0, 1.0);
    return at(t);
  }

  /// The frame at linear progress [t] (0..1) — previews, scrubbing.
  TransitionFrame at(double t) {
    final lin = t.clamp(0.0, 1.0);
    final e = durationMs <= 0 || lin >= 1 ? 1.0 : curve.transform(lin);
    final mm = magicMove;
    if (mm != null) {
      return TransitionFrame(
        progress: e,
        magicMove: mm.frameAt((lin * mm.durationMs).round()),
      );
    }
    // Snapshot types: the forward frame at p; reversed playback walks the
    // forward frames backwards with the layers swapped.
    final p = reverse ? 1 - e : e;
    final (quads, backdrop) = snapshotQuads(
      type,
      spec.params,
      p,
      width,
      height,
      seed: seed,
      throughColor: throughColor,
    );
    return TransitionFrame(
      progress: e,
      quads: reverse
          ? [
              for (final q in quads)
                TransitionQuad(
                  layer: q.layer == TransitionLayer.outgoing
                      ? TransitionLayer.incoming
                      : TransitionLayer.outgoing,
                  transform: q.transform,
                  opacity: q.opacity,
                  clip: q.clip,
                  dissolve: q.dissolve,
                  shade: q.shade,
                  region: q.region,
                  visible: q.visible,
                ),
            ]
          : quads,
      backdrop: backdrop,
    );
  }

  /// [count] frames evenly spaced from start to end (tile previews,
  /// contact sheets); [count] ≥ 2.
  List<TransitionFrame> sample(int count) => [
    for (var i = 0; i < count; i++) at(count <= 1 ? 1 : i / (count - 1)),
  ];

  /// Summary for UIs and MCP.
  Map<String, Object?> describe() => {
    'type': type,
    if (type != requestedType) 'requested': requestedType,
    'durationMs': durationMs,
    if (is3d) '3d': true,
    if (reverse) 'reverse': true,
    if (magicMove != null) 'pairs': magicMove!.pairs.length,
    if (warnings.isNotEmpty) 'warnings': [for (final w in warnings) w.code],
  };

  /// Canonical JSON (determinism tests).
  Map<String, Object?> toJson() => {
    ...describe(),
    'easing': curve.expression,
    if (spec.params.isNotEmpty) 'params': spec.params,
    if (throughColor != null) 'through': throughColor,
    if (seed != 0) 'seed': seed,
    if (magicMove != null) 'magicMove': magicMove!.toJson(),
  };
}

/// Compiles transitions (06 §9.1 item 3).
abstract final class TransitionCompiler {
  /// The plan of the transition from the slide shown as [from] (its final
  /// frame) to the slide entered as [to] (its initial frame).
  ///
  /// The transition is [spec], else [transitionJson] decoded (null = none).
  /// Magic Move needs both slides as [fromSlide] / [toSlide]
  /// (`MagicMoveSlide.fromDeck`; or use [between]); without them, or
  /// without any match, it plays as a crossfade (06 §8.5).
  static TransitionPlan compile({
    required SlideFrame from,
    required SlideFrame to,
    String? transitionJson,
    TransitionSpec? spec,
    TransitionOptions options = const TransitionOptions(),
    MagicMoveSlide? fromSlide,
    MagicMoveSlide? toSlide,
  }) {
    final s = spec ?? TransitionSpec.decode(transitionJson).value;
    final warnings = <TimelineWarning>[];
    final requested = s.type;
    var type = requested;
    var durationMs = s.durationMs;
    var curve = s.curve;
    final known = TransitionCatalog.byId(type);
    if (known == null) {
      warnings.add(
        TimelineWarning(
          'unknownTransition',
          'Unknown transition "$type" plays as fade',
        ),
      );
      type = 'fade';
    } else if (!known.available) {
      warnings.add(
        TimelineWarning(
          'unavailableTransition',
          '"${known.name}" is not available yet and plays as fade',
        ),
      );
      type = 'fade';
    }
    if (type == 'none' || durationMs <= 0) {
      return TransitionPlan._(
        requestedType: requested,
        type: 'none',
        spec: s,
        durationMs: 0,
        curve: MotionEasing.linear,
        reverse: options.reverse,
        width: options.slideWidth,
        height: options.slideHeight,
        from: from,
        to: to,
      );
    }
    if (options.reducedMotion) {
      if (type != 'fade' || durationMs != reducedMotionMs) {
        warnings.add(
          const TimelineWarning(
            'reducedMotion',
            'Reduce motion: plays as a 300 ms fade',
          ),
        );
      }
      type = 'fade';
      durationMs = reducedMotionMs;
      curve = MotionEasing.parse('easeInOut');
    }

    MagicMovePlan? magic;
    if (type == 'magicMove') {
      if (fromSlide == null || toSlide == null) {
        warnings.add(
          const TimelineWarning(
            'magicMoveNoSlides',
            'Magic Move without slide geometry plays as a crossfade',
          ),
        );
        type = 'fade';
      } else {
        magic = MagicMovePlan.compile(
          fromSlide,
          toSlide,
          spec: s,
          reverse: options.reverse,
          cameraLerp: options.cameraLerp,
        );
        if (!magic.hasMatches) {
          warnings.add(
            const TimelineWarning(
              'magicMoveNoMatches',
              'No objects match: Magic Move plays as a crossfade',
            ),
          );
          magic = null;
          type = 'fade';
        }
      }
    }
    final bound = curve.bind(durationMs);
    int? through;
    final throughRef = s.params['through'];
    if (type == 'fade' && requested == 'fade' && throughRef is String) {
      through = _color(throughRef, options.resolveColor);
    }
    return TransitionPlan._(
      requestedType: requested,
      type: type,
      spec: s,
      durationMs: magic?.durationMs ?? bound.durationMs,
      curve: bound.easing,
      reverse: options.reverse,
      width: options.slideWidth,
      height: options.slideHeight,
      from: from,
      to: to,
      magicMove: magic,
      throughColor: through,
      seed: type == 'dissolve'
          ? stableHash('transition:${options.seedKey}')
          : 0,
      warnings: List.unmodifiable(warnings),
    );
  }

  /// The plan of entering [toSlideId] from [fromSlideId] in [deck]: the
  /// transition of [toSlideId] (or, with [TransitionOptions.reverse], the
  /// one of [fromSlideId] played backwards), slide size from the deck, the
  /// dissolve seed from the entered slide, and — for Magic Move — both
  /// slides read with `MagicMoveSlide.fromDeck` in [fromFrame] (the left
  /// slide's final frame) and [toFrame] (the entered slide's initial
  /// frame). Pass the slides' [fromScene]/[toScene] when at hand (else
  /// they are built with [textLayout]).
  static TransitionPlan between(
    DeckReader deck, {
    required String fromSlideId,
    required String toSlideId,
    SlideFrame fromFrame = SlideFrame.edit,
    SlideFrame toFrame = SlideFrame.edit,
    TransitionOptions options = const TransitionOptions(),
    SlideScene? fromScene,
    SlideScene? toScene,
    TextLayoutEngine? textLayout,
  }) {
    final owner = options.reverse ? fromSlideId : toSlideId;
    final spec = TransitionSpec.effective(
      deck.slide(owner)?.transitionJson,
      deck.deck?.defaultsJson,
    );
    final opts = TransitionOptions(
      slideWidth: deck.deck?.width ?? options.slideWidth,
      slideHeight: deck.deck?.height ?? options.slideHeight,
      reducedMotion: options.reducedMotion,
      reverse: options.reverse,
      seedKey: options.seedKey.isEmpty ? toSlideId : options.seedKey,
      resolveColor: options.resolveColor ?? _themeColors(deck, toSlideId),
      cameraLerp: options.cameraLerp,
    );
    MagicMoveSlide? a, b;
    if (spec.type == 'magicMove' && !options.reducedMotion) {
      a = MagicMoveSlide.fromDeck(
        deck,
        fromSlideId,
        frame: fromFrame,
        scene: fromScene,
        textLayout: textLayout,
      );
      b = MagicMoveSlide.fromDeck(
        deck,
        toSlideId,
        frame: toFrame,
        scene: toScene,
        textLayout: textLayout,
      );
    }
    return compile(
      from: fromFrame,
      to: toFrame,
      spec: spec,
      options: opts,
      fromSlide: a,
      toSlide: b,
    );
  }

  /// A preview of [spec] (Transition tab tiles, 06 §5.1): snapshot frames
  /// of two generic slides (Magic Move previews need [fromSlide] /
  /// [toSlide], else they show a crossfade).
  static TransitionPlan preview(
    TransitionSpec spec, {
    double width = 1920,
    double height = 1080,
    bool reducedMotion = false,
    MagicMoveSlide? fromSlide,
    MagicMoveSlide? toSlide,
  }) => compile(
    from: fromSlide?.frame ?? SlideFrame.edit,
    to: toSlide?.frame ?? SlideFrame.edit,
    spec: spec,
    options: TransitionOptions(
      slideWidth: width,
      slideHeight: height,
      reducedMotion: reducedMotion,
      seedKey: 'preview',
    ),
    fromSlide: fromSlide,
    toSlide: toSlide,
  );

  static MotionColorResolver? _themeColors(DeckReader deck, String slideId) {
    if (deck is! DeckModel) return null;
    final theme = SlideResolver(deck).resolve(slideId)?.theme;
    return theme == null ? null : (c) => theme.colorString(c, fallback: 0);
  }

  static int? _color(String ref, MotionColorResolver? resolve) {
    switch (ref) {
      case 'black':
        return 0xFF000000;
      case 'white':
        return 0xFFFFFFFF;
    }
    final r = resolve?.call(ref);
    if (r != null && r != 0) return r;
    if (ref.startsWith('#')) {
      final hex = ref.substring(1);
      final v = int.tryParse(hex, radix: 16);
      if (v == null) return null;
      if (hex.length == 6) return 0xFF000000 | v;
      if (hex.length == 8) return ((v & 0xFF) << 24) | (v >> 8);
    }
    return null;
  }
}
