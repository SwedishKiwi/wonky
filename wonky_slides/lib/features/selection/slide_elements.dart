import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

/// Index of a resolved slide's own elements (not master/layout
/// decorations) for selection and transforms: lookup by id, parents,
/// sibling lists and slide-space frames. Resolved frames of group children
/// are already in slide space (02 §6.9). Cached per [ResolvedSlide]
/// instance (the resolver memoizes per slide revision).
class SlideElements {
  SlideElements._(this.slide) {
    void walk(List<ResolvedElement> list, ResolvedElement? parent) {
      for (final e in list) {
        _byId[e.id] = e;
        if (parent != null) _parent[e.id] = parent;
        walk(e.children, e);
      }
    }

    walk(slide.elements, null);
  }

  static final Expando<SlideElements> _cache = Expando('slideElements');

  /// The index of [slide].
  factory SlideElements.of(ResolvedSlide slide) =>
      _cache[slide] ??= SlideElements._(slide);

  final ResolvedSlide slide;
  final Map<String, ResolvedElement> _byId = {};
  final Map<String, ResolvedElement> _parent = {};

  /// Every element of the slide (any depth).
  Iterable<ResolvedElement> get all => _byId.values;

  /// The element [id] of this slide, or null.
  ResolvedElement? operator [](String id) => _byId[id];

  /// Whether [id] is an element of this slide.
  bool contains(String id) => _byId.containsKey(id);

  /// The element group containing [id], or null at the top level.
  ResolvedElement? parentOf(String id) => _parent[id];

  /// The ids of [id]'s ancestors, outermost first.
  List<String> ancestorsOf(String id) {
    final out = <String>[];
    var p = _parent[id];
    while (p != null) {
      out.insert(0, p.id);
      p = _parent[p.id];
    }
    return out;
  }

  /// The children of group [groupId], or the top-level elements.
  List<ResolvedElement> siblings(String? groupId) =>
      groupId == null ? slide.elements : (_byId[groupId]?.children ?? const []);

  /// Whether [e] can be selected on the canvas (visible, unlocked, 03 §8.2).
  static bool selectable(ResolvedElement e) => !e.hidden && !e.locked;

  /// The slide-space frame of [e]; with [scene], derived frames of
  /// auto-sized text and grown tables (03 §6.1).
  static ElementFrame frameOf(ResolvedElement e, [SlideScene? scene]) =>
      ElementFrame.of(
        scene?.frameOf(e) ?? e.frame,
        rotation: e.rotation,
        flipH: e.flipH,
        flipV: e.flipV,
      );

  /// The child space of group [g] (`dataJson.childBounds`, else its own
  /// stored frame — identity at creation).
  static SuRect childBoundsOf(ResolvedElement g) =>
      SlideResolver.childBoundsOf(g.data) ?? g.record.frame ?? g.frame;
}
