import 'package:wonky_slides_core/scene.dart';

import '../../canvas/canvas_interactions.dart';
import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';

/// The live preview of an image adjustment slider (03 §6.5.5, SL-44):
/// while a slider of Inspector › Image is dragged, the stage draws the
/// image with the dragged value — the same `ImageAdjust` color matrix and
/// blur the scene builder uses — and nothing is written; the release writes
/// `slides.image.adjust` once (one undo step).
class ImageAdjustPreview extends CanvasInteraction {
  ImageAdjustPreview(super.c);

  /// The preview of [editor]'s canvas, or null without a canvas.
  static ImageAdjustPreview? of(DeckEditorController editor) {
    final c = SlideCanvasController.of(editor);
    return c == null ? null : CanvasInteractions.find<ImageAdjustPreview>(c);
  }

  String? _id;
  Map<String, Object?>? _adjust;

  /// The element being previewed, or null.
  String? get elementId => _id;

  /// The previewed `adjust` object (stored units), or null.
  Map<String, Object?>? get adjust => _adjust;

  /// Shows image [id] with adjustment [key] at the slider value [value]
  /// (−100…100; blur 0…40) over its stored adjustments.
  void show(String id, String key, Object value) {
    final e = c.elements?[id];
    if (e == null) return;
    final data = e.data ?? const <String, Object?>{};
    final stored = data['adjust'] is Map
        ? (data['adjust'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final v = value is num && key != 'blur' ? value / 100 : value;
    _id = id;
    _adjust = {...stored, key: v};
    c.refresh();
  }

  /// Ends the preview (the value was written or the drag cancelled).
  void clear() {
    if (_id == null) return;
    _id = null;
    _adjust = null;
    c.refresh();
  }

  @override
  SlideScene sceneFor(SlideScene scene) {
    final id = _id, adjust = _adjust;
    // Only while the image is still the selection (a drag interrupted by a
    // selection change shows nothing stale).
    if (id == null || adjust == null || !c.selection.ids.contains(id)) {
      return scene;
    }
    SceneNode swap(SceneNode n) => switch (n) {
      ImageNode() when n.elementId == id => ImageNode(
        elementId: n.elementId,
        image: n.image,
        src: n.src,
        dst: n.dst,
        colorMatrix: ImageAdjust.matrix(adjust),
        mask: n.mask,
        blurSigma: switch (adjust['blur']) {
          final num b when b > 0 => b.toDouble(),
          _ => 0,
        },
      ),
      GroupNode() => GroupNode(
        elementId: n.elementId,
        transform: n.transform,
        opacity: n.opacity,
        clip: n.clip,
        effects: n.effects,
        children: [for (final child in n.children) swap(child)],
      ),
      _ => n,
    };
    return SlideScene(
      slideId: scene.slideId,
      width: scene.width,
      height: scene.height,
      background: scene.background,
      nodes: [for (final n in scene.nodes) swap(n)],
      frames: scene.frames,
      routes: scene.routes,
    );
  }
}
