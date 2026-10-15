import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';

import '../motion/render/motion_scenes.dart';
import '../stage/slide_renderer.dart';
import '../stage/slide_stage.dart';

/// Rasterized slides for snapshot transitions (06 §12.2, §14): each slide
/// is drawn once at device resolution in the frame it shows during the
/// transition, and the image is transformed/clipped/blended per frame —
/// constant cost however complex the slide. Images are kept in a small
/// LRU keyed by slide, render revision, frame and size, so the next
/// slide's snapshot can be prepared ahead ([prepare]).
class SlideSnapshots {
  SlideSnapshots(this.renderer) : scenes = MotionScenes(renderer);

  static final Expando<SlideSnapshots> _shared = Expando('slideSnapshots');

  /// The snapshot cache shared by every stage of [renderer] (present mode,
  /// the presenter view's previews).
  static SlideSnapshots of(SlideRenderer renderer) =>
      _shared[renderer] ??= SlideSnapshots(renderer);

  final SlideRenderer renderer;
  final MotionScenes scenes;

  /// Images kept.
  static const int capacity = 6;

  /// Longest side of a snapshot (device px).
  static const int maxSide = 4096;

  final LinkedHashMap<String, ui.Image> _images = LinkedHashMap();

  /// The snapshot of [slideId] in [frame] at [pxPerSu] device pixels per
  /// slide unit, or null when the slide doesn't exist.
  ui.Image? imageOf(
    String slideId,
    SlideFrame frame, {
    required double pxPerSu,
  }) {
    final size = renderer.slideSize;
    var k = pxPerSu;
    final longest = math.max(size.width, size.height) * k;
    if (longest > maxSide) k *= maxSide / longest;
    final w = math.max(1, (size.width * k).round());
    final h = math.max(1, (size.height * k).round());
    final key =
        '$slideId|${renderer.revision(slideId)}|${identityHashCode(frame)}|'
        '$w×$h';
    final hit = _images.remove(key);
    if (hit != null) return _images[key] = hit;
    final scene = renderer.scene(slideId, purpose: ScenePurpose.present);
    if (scene == null) return null;
    final shown = scenes.apply(scene, frame);
    final pic = recordScene(
      shown,
      scale: w / size.width,
      images: renderer.images,
      frame: frame,
    );
    final image = pic.toImageSync(w, h);
    pic.dispose();
    _images[key] = image;
    while (_images.length > capacity) {
      _images.remove(_images.keys.first)?.dispose();
    }
    return image;
  }

  /// Rasterizes [slideId] in [frame] ahead of its transition.
  ui.Image? prepare(
    String slideId,
    SlideFrame frame, {
    required double pxPerSu,
  }) => imageOf(slideId, frame, pxPerSu: pxPerSu);

  /// Releases every image.
  void clear() {
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
  }
}
