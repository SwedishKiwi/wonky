/// Frames of a slide transition (06 §7, §12.2): how the outgoing and the
/// incoming slide are composited at one moment. Snapshot transitions (every
/// type but Magic Move) draw each slide as a whole — rasterized once — as
/// one or more **quads** with a slide-space transform (incl. perspective
/// for 3D types), opacity, clip, dissolve and shading; Magic Move frames
/// carry a `MagicMoveFrame` instead (live rendering of both scenes).
library;

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../theme/model/common.dart' show SuRect;
import '../magic_move/magic_move_plan.dart' show MagicMoveFrame;
import '../timeline/slide_frame.dart';

double _r(double v) => (v * 1e6).roundToDouble() / 1e6;

bool _isIdentity(Matrix4 m) {
  final s = m.storage;
  for (var i = 0; i < 16; i++) {
    if (s[i] != (i % 5 == 0 ? 1.0 : 0.0)) return false;
  }
  return true;
}

/// Which slide a quad draws.
enum TransitionLayer {
  /// The slide being left.
  outgoing,

  /// The slide being entered.
  incoming,
}

/// One quad of a transition frame: [layer]'s snapshot (or its [region])
/// drawn with [transform] (slide space, su; 3D types include the
/// perspective entry `(3, 2) = −1 / (2.2 × width)` and need the projective
/// divide), [opacity], [clip] (wipe/iris over the region, like
/// `ClipSpec` of builds), [dissolve] and [shade] (darkening toward black:
/// 3D faces turned away, *Cover*'s old slide).
final class TransitionQuad {
  /// Creates a quad.
  TransitionQuad({
    required this.layer,
    Matrix4? transform,
    this.opacity = 1,
    this.clip,
    this.dissolve,
    this.shade = 0,
    this.region,
    this.visible = true,
  }) : transform = transform ?? Matrix4.identity();

  final TransitionLayer layer;
  final Matrix4 transform;

  /// 0..1.
  final double opacity;
  final ClipSpec? clip;
  final DissolveState? dissolve;

  /// 0 = unchanged, 1 = black.
  final double shade;

  /// The part of the slide this quad draws (su), or null = the whole slide
  /// (doorway: the two halves of the outgoing slide).
  final SuRect? region;

  /// False when back-face culled or fully transparent.
  final bool visible;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'layer': layer.name,
    if (!visible) 'visible': false,
    if (!_isIdentity(transform))
      'transform': [for (final v in transform.storage) _r(v)],
    if (opacity != 1) 'opacity': _r(opacity),
    if (clip != null) 'clip': clip!.toJson(),
    if (dissolve != null) 'dissolve': dissolve!.toJson(),
    if (shade != 0) 'shade': _r(shade),
    if (region != null)
      'region': [
        _r(region!.x),
        _r(region!.y),
        _r(region!.width),
        _r(region!.height),
      ],
  };
}

/// One frame of a transition.
final class TransitionFrame {
  /// Creates a frame.
  const TransitionFrame({
    required this.progress,
    this.quads = const [],
    this.backdrop,
    this.magicMove,
  });

  /// Eased progress of the transition (0..1; forward direction).
  final double progress;

  /// Quads in paint order, back to front (snapshot transitions).
  final List<TransitionQuad> quads;

  /// ARGB drawn behind the quads (*Fade through* a color), or null = the
  /// letterbox/canvas color (06 §7.2: 3D transitions uncover it).
  final int? backdrop;

  /// The Magic Move frame (type `magicMove` with matches), else null.
  final MagicMoveFrame? magicMove;

  /// The visible quads of [layer].
  Iterable<TransitionQuad> quadsOf(TransitionLayer layer) =>
      quads.where((q) => q.layer == layer && q.visible);

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'progress': _r(progress),
    if (backdrop != null) 'backdrop': backdrop,
    if (quads.isNotEmpty) 'quads': [for (final q in quads) q.toJson()],
    if (magicMove != null) 'magicMove': magicMove!.toJson(),
  };
}
