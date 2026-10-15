import 'package:wonky_sync_models/ids.dart' show FractionalIndex;

import '../api/deck_reader.dart';
import '../api/kinds.dart';
import '../api/records.dart';

/// The element tree of one owner (slide, layout or master; 02 §11
/// `ElementTree`): children by effective parent, back to front by
/// `(zKey, id)`, with the render-time rules of 02 §10 applied:
///
/// - a child whose parent belongs to another owner is top-level
///   ([foreignParent]);
/// - a child whose parent is missing or is not an element group is
///   top-level ([missingParent]);
/// - in a parent cycle the member with the smallest id is top-level
///   ([cycleBreakers]);
/// - an element group without children is not drawn ([emptyGroups]).
final class ElementTree {
  ElementTree._(
    this.ownerId,
    this._elements,
    this._children,
    this._parent,
    this.foreignParent,
    this.missingParent,
    this.cycleBreakers,
  );

  /// Builds the tree of [ownerId].
  factory ElementTree.of(DeckReader deck, String ownerId) {
    final elements = {for (final e in deck.allElementsOf(ownerId)) e.id: e};
    final foreign = <String>{};
    final missing = <String>{};
    final parent = <String, String?>{};
    for (final e in elements.values) {
      final p = e.parentId;
      if (p == null) {
        parent[e.id] = null;
        continue;
      }
      final pe = elements[p];
      if (pe == null) {
        if (deck.element(p) != null) {
          foreign.add(e.id);
        } else {
          missing.add(e.id);
        }
        parent[e.id] = null;
      } else if (pe.kind != ElementKind.group) {
        missing.add(e.id);
        parent[e.id] = null;
      } else {
        parent[e.id] = p;
      }
    }
    // Cycles: walk each chain; a revisited node closes a loop whose member
    // with the smallest id becomes top-level (02 §10).
    final breakers = <String>{};
    final done = <String>{};
    for (final start in (elements.keys.toList()..sort())) {
      if (done.contains(start)) continue;
      final path = <String>[];
      final onPath = <String>{};
      String? cur = start;
      while (cur != null && !done.contains(cur)) {
        if (onPath.contains(cur)) {
          final loop = path.sublist(path.indexOf(cur));
          final min = (loop.toList()..sort()).first;
          breakers.add(min);
          parent[min] = null;
          break;
        }
        onPath.add(cur);
        path.add(cur);
        cur = parent[cur];
      }
      done.addAll(path);
    }
    final children = <String, List<SlideElementRec>>{};
    for (final e in elements.values) {
      (children[parent[e.id] ?? ''] ??= []).add(e);
    }
    for (final list in children.values) {
      list.sort((a, b) => FractionalIndex.compare(a.zKey, a.id, b.zKey, b.id));
    }
    return ElementTree._(
      ownerId,
      elements,
      children,
      parent,
      foreign,
      missing,
      breakers,
    );
  }

  /// The owner (slide, layout or master id).
  final String ownerId;

  final Map<String, SlideElementRec> _elements;
  final Map<String, List<SlideElementRec>> _children;
  final Map<String, String?> _parent;

  /// Children whose `parentId` is an element of another owner.
  final Set<String> foreignParent;

  /// Children whose `parentId` is missing or not an element group.
  final Set<String> missingParent;

  /// Members of parent cycles treated as top-level.
  final Set<String> cycleBreakers;

  /// Number of elements (all depths).
  int get length => _elements.length;

  /// The element [id] of this owner, or null.
  SlideElementRec? operator [](String id) => _elements[id];

  /// Whether [id] belongs to this owner.
  bool contains(String id) => _elements.containsKey(id);

  /// Top-level elements, back to front.
  List<SlideElementRec> get roots => _children[''] ?? const [];

  /// Children of group [id], back to front.
  List<SlideElementRec> childrenOf(String? id) =>
      _children[id ?? ''] ?? const [];

  /// The effective parent of [id] (null = top level).
  String? parentOf(String id) => _parent[id];

  /// Depth of [id] (0 = top level).
  int depthOf(String id) {
    var d = 0;
    var p = _parent[id];
    while (p != null && d < 64) {
      d++;
      p = _parent[p];
    }
    return d;
  }

  /// The nesting height below [id] (0 = no children).
  int heightOf(String id) {
    var h = 0;
    for (final c in childrenOf(id)) {
      final ch = 1 + heightOf(c.id);
      if (ch > h) h = ch;
    }
    return h;
  }

  /// Every descendant of [id] (depth first, back to front).
  List<SlideElementRec> descendantsOf(String id) {
    final out = <SlideElementRec>[];
    void walk(String p) {
      for (final c in childrenOf(p)) {
        out.add(c);
        walk(c.id);
      }
    }

    walk(id);
    return out;
  }

  /// Every element depth first, back to front (painting order).
  List<SlideElementRec> get all {
    final out = <SlideElementRec>[];
    void walk(String? p) {
      for (final c in childrenOf(p)) {
        out.add(c);
        walk(c.id);
      }
    }

    walk(null);
    return out;
  }

  /// Element groups without children (not drawn, 02 §10).
  List<SlideElementRec> get emptyGroups => [
    for (final e in _elements.values)
      if (e.kind == ElementKind.group && childrenOf(e.id).isEmpty) e,
  ];
}
