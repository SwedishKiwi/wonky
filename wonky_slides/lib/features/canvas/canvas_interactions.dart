import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart' show KeyScope;
import 'package:wonky_slides_core/scene.dart' show SlideScene;

import '../selection/transform_session.dart' show TransformModifiers;
import 'canvas_tokens.dart';
import 'slide_canvas_controller.dart';

/// One pointer event of the canvas, in viewport px, slide su and global
/// coordinates.
@immutable
class CanvasPointer {
  const CanvasPointer({
    required this.px,
    required this.su,
    required this.global,
    required this.modifiers,
    this.buttons = 0,
  });

  final Offset px;
  final Offset su;
  final Offset global;
  final TransformModifiers modifiers;
  final int buttons;
}

/// A canvas mode of an element kind (SL-15: image crop mode, table cell
/// selection and border dragging): it may take presses before the default
/// selection gestures, preview its gesture on the overlay, replace the
/// stage's scene (crop mode hides the image it draws itself), add widgets
/// on the canvas (the crop bar) and key scopes (`slidesCrop`,
/// `slidesTable`, 03 §1.2).
///
/// Interactions are created per canvas by the factories registered with
/// [CanvasInteractions.register] (element work packages register theirs at
/// command registration, like `CanvasTools`).
abstract class CanvasInteraction {
  CanvasInteraction(this.c);

  final SlideCanvasController c;

  /// Whether the mode takes every press first (crop mode: a press outside
  /// commits it). Only consulted while [active].
  bool get modal => false;

  /// Whether the mode is on (modal modes; others are always asked).
  bool get active => true;

  /// Whether the selection handles are hidden (crop mode draws its own).
  bool get hidesSelectionChrome => false;

  /// Handles a press; returns whether it took the gesture (then [move],
  /// [up] or [cancel] follow).
  bool down(CanvasPointer p) => false;

  void move(CanvasPointer p) {}

  void up(CanvasPointer p) {}

  void cancel() {}

  /// The cursor over slide point [su], or null for the default.
  MouseCursor? cursorAt(Offset su) => null;

  /// The context menu id for a right-click at [su] (after the canvas
  /// selected the element under it), or null for the default.
  String? contextMenuAt(Offset su) => null;

  /// The scene the stage draws.
  SlideScene sceneFor(SlideScene scene) => scene;

  /// Paints the mode's chrome on the overlay (viewport px).
  void paint(Canvas canvas, CanvasTokens tokens) {}

  /// Widgets on top of the canvas (positioned in viewport px; wrap
  /// pointer-taking widgets in [CanvasChrome]).
  List<Widget> overlays(BuildContext context) => const [];

  /// Extra key scopes tried before `slidesCanvas`, most specific first.
  List<KeyScope> get keyScopes => const [];

  /// Releases resources.
  void dispose() {}
}

/// Creates an interaction for a canvas.
typedef CanvasInteractionFactory =
    CanvasInteraction Function(SlideCanvasController c);

/// The registry of canvas interactions (one instance per factory and
/// canvas).
abstract final class CanvasInteractions {
  static final List<CanvasInteractionFactory> _factories = [];
  static final Expando<List<CanvasInteraction>> _instances = Expando(
    'slidesCanvasInteractions',
  );

  /// Registers [factory] once.
  static void register(CanvasInteractionFactory factory) {
    if (!_factories.contains(factory)) _factories.add(factory);
  }

  /// The interactions of canvas [c].
  static List<CanvasInteraction> of(SlideCanvasController c) {
    final list = _instances[c];
    if (list != null && list.length == _factories.length) return list;
    final next = [
      ...?list,
      for (final f in _factories.skip(list?.length ?? 0)) f(c),
    ];
    _instances[c] = next;
    return next;
  }

  /// The interaction of type [T] of canvas [c], or null.
  static T? find<T extends CanvasInteraction>(SlideCanvasController c) {
    for (final i in of(c)) {
      if (i is T) return i;
    }
    return null;
  }

  /// Disposes the interactions of [c] (the canvas controller is disposed).
  static void disposeOf(SlideCanvasController c) {
    final list = _instances[c];
    _instances[c] = null;
    for (final i in list ?? const <CanvasInteraction>[]) {
      i.dispose();
    }
  }
}

/// Marks widgets on the canvas that handle their own pointer events (the
/// crop bar, upload badges): the canvas ignores presses on them.
class CanvasChrome extends StatelessWidget {
  const CanvasChrome({super.key, required this.child});

  final Widget child;

  /// The metadata tag the canvas looks for.
  static const tag = 'slides.canvas.chrome';

  @override
  Widget build(BuildContext context) =>
      MetaData(metaData: tag, behavior: HitTestBehavior.opaque, child: child);

  /// Whether global point [p] is over a [CanvasChrome] in [context]'s view.
  static bool hits(BuildContext context, Offset p) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, p, View.of(context).viewId);
    for (final e in result.path) {
      final t = e.target;
      if (t is RenderMetaData && t.metaData == tag) return true;
    }
    return false;
  }
}
