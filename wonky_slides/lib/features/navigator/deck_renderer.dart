import '../canvas/slide_canvas_controller.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../stage/slide_renderer.dart';
import '../uploads/slides_image_service.dart';

/// The `SlideRenderer` the navigator and grid view draw thumbnails with:
/// the canvas' renderer when a canvas is attached (one renderer per open
/// deck, 02 §11), else one shared by the thumbnail surfaces of the editor,
/// created on the first [acquire] and disposed on the last [release].
abstract final class DeckThumbnails {
  static final Expando<_Owned> _owned = Expando('slidesThumbnailRenderer');

  /// The renderer for [editor]; pair with [release].
  static SlideRenderer acquire(DeckEditorController editor) {
    final canvas = SlideCanvasController.of(editor);
    if (canvas != null) return canvas.renderer;
    final o = _owned[editor] ??= _Owned(
      SlideRenderer(model: editor.model, images: SlidesImageService.of(editor)),
    );
    o.refs++;
    return o.renderer;
  }

  /// Releases [renderer] acquired for [editor].
  static void release(DeckEditorController editor, SlideRenderer renderer) {
    final o = _owned[editor];
    if (o == null || !identical(o.renderer, renderer)) return;
    if (--o.refs > 0) return;
    _owned[editor] = null;
    o.renderer.dispose();
  }
}

class _Owned {
  _Owned(this.renderer);

  final SlideRenderer renderer;
  int refs = 0;
}
