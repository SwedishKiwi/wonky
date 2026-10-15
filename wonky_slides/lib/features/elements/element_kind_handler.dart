import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';

/// An extra handle of an element beyond the 8 resize handles and the
/// rotation handle (adjust handles, line endpoints, crop edges; 03 §3).
final class HandleSpec {
  const HandleSpec({
    required this.id,
    required this.x,
    required this.y,
    this.cursor = SystemMouseCursors.precise,
  });

  /// Handle id passed back to the handler on drag (`adjust:radius`,
  /// `start`, `end`, `crop:l`).
  final String id;

  /// Position in element-local su.
  final double x;
  final double y;
  final MouseCursor cursor;
}

/// Kinds of snap points an element offers (03 §4).
enum SnapPointKind { edge, center, connectionSite }

/// A snap point an element offers to the snap engine (element-local su).
final class SnapPoint {
  const SnapPoint(this.x, this.y, {this.kind = SnapPointKind.edge, this.site});

  final double x;
  final double y;
  final SnapPointKind kind;

  /// Connection site name/index for connectors (`top`, `right`, `3`).
  final String? site;
}

/// What double-click / Enter does on an element (03 §1.3).
enum ElementActivation {
  /// Nothing.
  none,

  /// Edit its text body.
  editText,

  /// Enter the element group.
  enterGroup,

  /// Crop the image.
  crop,

  /// Edit table cells.
  editTable,

  /// Open the code editor (07).
  editCode,

  /// Open the chart editor (08).
  editChart,
}

/// What is being edited in an editing overlay.
final class EditingTarget {
  const EditingTarget(this.element, {this.cellId, this.codeStateId});

  final ResolvedElement element;

  /// The table cell being edited, or null.
  final String? cellId;

  /// The code state being edited, or null.
  final String? codeStateId;
}

/// Per-kind behavior of slide elements (03 §1.3, 12 §5.4): every
/// `features/elements/<kind>/` folder registers one handler; the canvas,
/// thumbnails, present mode and PDF never switch on the kind.
///
/// Contract (SL-3). [buildScene] delegates to the core scene builder
/// (SL-10); inspector section ids refer to SL-11's section registry.
abstract class ElementKindHandler {
  const ElementKindHandler();

  ElementKind get kind;

  /// Scene node for a resolved element (pure; canvas, thumbnails, present,
  /// PDF via core).
  SceneNode buildScene(ResolvedElement e, SceneContext ctx);

  /// Precise hit test in element-local coordinates (su).
  bool hitTest(
    ResolvedElement e,
    Offset localSu, {
    required double tolerancePx,
  });

  /// Extra handles beyond the 8 resize handles and the rotation handle.
  List<HandleSpec> extraHandles(ResolvedElement e) => const [];

  /// Snap points offered to the snap engine (edges, centers, sites).
  List<SnapPoint> snapPoints(ResolvedElement e) {
    final f = e.frame;
    return [
      SnapPoint(0, 0),
      SnapPoint(f.width, f.height),
      SnapPoint(f.width / 2, f.height / 2, kind: SnapPointKind.center),
    ];
  }

  /// What double-click / Enter does.
  ElementActivation activation(ResolvedElement e) => ElementActivation.none;

  /// Ids of the inspector sections of the Format tab for [selection]
  /// (04 §7.2; resolved by SL-11's inspector section registry).
  List<String> inspectorSections(List<ResolvedElement> selection) => const [];

  /// Overlay widget while the element is being edited (text editor, code
  /// editor, crop UI…), or null.
  Widget? editingOverlay(BuildContext context, EditingTarget target) => null;
}

/// The handlers by kind (03 §1.1 `ElementKindRegistry`).
class ElementKindRegistry {
  ElementKindRegistry([Iterable<ElementKindHandler> handlers = const []]) {
    handlers.forEach(register);
  }

  final Map<ElementKind, ElementKindHandler> _handlers = {};

  /// Registers [handler] (one per kind; a second one replaces the first
  /// only with [replace]).
  void register(ElementKindHandler handler, {bool replace = false}) {
    if (!replace && _handlers.containsKey(handler.kind)) {
      throw StateError('A handler for ${handler.kind.name} is registered');
    }
    _handlers[handler.kind] = handler;
  }

  /// The handler of [kind], or null while that kind isn't built yet.
  ElementKindHandler? operator [](ElementKind kind) => _handlers[kind];

  /// The handler of [e]'s kind, or null.
  ElementKindHandler? of(ResolvedElement e) => _handlers[e.record.kind];

  /// Registered kinds.
  Iterable<ElementKind> get kinds => _handlers.keys;
}
