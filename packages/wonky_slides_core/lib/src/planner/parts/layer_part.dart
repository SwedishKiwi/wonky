part of '../slides_planner.dart';

/// Layers panel moves and the custom reading order (03 §8.1, §17.2;
/// SL-34).
extension _LayerPart on _Planner {
  String moveElementsZ(MoveElementsZ op) {
    final ids = unique(op.elementIds);
    if (ids.isEmpty) return 'Reorder';
    final els = [for (final id in ids) elementOf(id)];
    final owner = els.first.ownerId ?? notFound('Owner of', ids.first);
    final tree = ix.tree(owner);
    for (final e in els) {
      if (e.ownerId != owner) {
        invalid('Only objects of one slide can be moved together');
      }
    }
    final moving = ids.toSet();
    final anchor = op.aboveId ?? op.belowId;
    final String? parent;
    if (anchor != null) {
      if (moving.contains(anchor)) {
        invalid("An object can't move next to itself");
      }
      final a = elementOf(anchor);
      if (a.ownerId != owner) invalid('$anchor is not on the same slide');
      parent = tree.parentOf(anchor);
    } else {
      parent = op.intoGroupId;
    }
    if (parent != null) {
      final g = elementOf(parent);
      if (g.ownerId != owner || g.kind != ElementKind.group) {
        invalid('$parent is not an element group of $owner');
      }
      // No element may move into itself or one of its descendants.
      for (String? p = parent; p != null; p = tree.parentOf(p)) {
        if (moving.contains(p)) {
          invalid("A group can't move into itself");
        }
      }
      final depth = tree.depthOf(parent) + 1;
      for (final e in els) {
        if (e.placeholderType != null && tree.parentOf(e.id) != parent) {
          invalid("Placeholders can't be grouped");
        }
        if (depth + 1 + tree.heightOf(e.id) > limits.maxElementGroupDepth) {
          limit(
            'Groups can be nested at most '
            '${limits.maxElementGroupDepth} levels.',
          );
        }
      }
    }
    // The moved elements in their current painting order.
    final painting = {for (final (i, e) in tree.all.indexed) e.id: i};
    els.sort((a, c) => (painting[a.id] ?? 0).compareTo(painting[c.id] ?? 0));

    final sibs = zItems(owner, parent);
    var index = sibs.length;
    if (op.aboveId != null) {
      index = OrderKeys.indexFor(sibs, afterId: op.aboveId);
    } else if (op.belowId != null) {
      index = OrderKeys.indexFor(sibs, beforeId: op.belowId);
    }
    if (index < 0) notFound('Element', anchor!);
    final keys = OrderKeys.at(sibs, index, els.length, exclude: moving);

    final touchedGroups = <String>{};
    var reparented = false;
    for (final (i, e) in els.indexed) {
      final from = tree.parentOf(e.id);
      if (from == parent) {
        b.set(e, {ElementCols.zKey: keys[i]});
        continue;
      }
      reparented = true;
      // Up to the common ancestor (slide space at most), then down into
      // the new parent's child space (02 §6.9).
      var f = frameOf(e);
      var opacity = e.opacity;
      for (String? p = from; p != null; p = tree.parentOf(p)) {
        if (_isAncestorOrSelf(owner, p, parent)) break;
        final g = elementOf(p);
        f = GroupSpace.toParent(f, frameOf(g), _childSpace(g));
        final go = g.opacity;
        if (go != null && go != 1) opacity = (opacity ?? 1) * go;
      }
      final down = <String>[];
      for (String? p = parent; p != null; p = tree.parentOf(p)) {
        if (_isAncestorOrSelf(owner, p, from)) break;
        down.insert(0, p);
      }
      for (final p in down) {
        final g = elementOf(p);
        f = GroupSpace.toChild(f, frameOf(g), _childSpace(g));
      }
      if (from != null) touchedGroups.add(from);
      b.set(
        e,
        {
          SlidesCols.parentId: parent,
          ElementCols.zKey: keys[i],
          ElementCols.x: clampPos(f.x),
          ElementCols.y: clampPos(f.y),
          ElementCols.width: clampSide(f.width),
          ElementCols.height: clampSide(f.height),
          ElementCols.rotation: f.rotation == 0 && e.rotation == null
              ? null
              : f.rotation,
          ElementCols.flipH: f.flipH,
          ElementCols.flipV: f.flipV,
          if (opacity != e.opacity)
            ElementCols.opacity: (opacity ?? 1).clamp(0, 1).toDouble(),
        },
        together: const {
          SlidesCols.parentId,
          ElementCols.zKey,
          ElementCols.x,
          ElementCols.y,
          ElementCols.width,
          ElementCols.height,
          ElementCols.rotation,
          ElementCols.flipH,
          ElementCols.flipV,
        },
      );
    }
    if (reparented && parent != null) touchedGroups.add(parent);
    // Emptied groups are deleted, the others refitted (inner first, then
    // their ancestors).
    for (final g in touchedGroups) {
      _dropOrRefit(owner, g);
    }
    result['elementIds'] = [for (final e in els) e.id];
    return reparented ? 'Move to group' : 'Reorder';
  }

  /// Whether [a] is [b] or one of its ancestors ([b] null = never).
  bool _isAncestorOrSelf(String owner, String a, String? b) {
    final tree = ix.tree(owner);
    for (String? p = b; p != null; p = tree.parentOf(p)) {
      if (p == a) return true;
    }
    return false;
  }

  SuRect _childSpace(SlideElementRec g) =>
      SlideResolver.childBoundsOf(decodeMap(g.dataJson)) ?? frameOf(g).rect;

  /// Deletes group [groupId] when the plan left it without children, else
  /// refits it; then its parent group the same way.
  void _dropOrRefit(String owner, String groupId) {
    final g = b.rec(SlidesTables.slideElement, groupId) as SlideElementRec?;
    if (g == null || g.kind != ElementKind.group) return;
    final up = g.parentId;
    final children = zItems(owner, groupId);
    if (children.isEmpty) {
      deleteElementTree(g);
    } else {
      _refitGroup(g, children);
    }
    if (up != null) _dropOrRefit(owner, up);
  }

  /// Refits an unrotated, unflipped group to the union of its children
  /// (child space and frame together, so nothing moves on the slide).
  void _refitGroup(SlideElementRec g, List<KeyedItem> children) {
    final gf = frameOf(g);
    if (normalizeRotation(gf.rotation) != 0 || gf.flipH || gf.flipV) return;
    final cb = _childSpace(g);
    final boxes = [
      for (final (_, id) in children)
        if (b.rec(SlidesTables.slideElement, id) case final SlideElementRec c)
          frameOf(c).bounds,
    ];
    final u = unionRects(boxes);
    if (u == null || u.width <= 0 || u.height <= 0) return;
    if ((u.x - cb.x).abs() < 1e-6 &&
        (u.y - cb.y).abs() < 1e-6 &&
        (u.width - cb.width).abs() < 1e-6 &&
        (u.height - cb.height).abs() < 1e-6) {
      return;
    }
    final sx = cb.width == 0 ? 1.0 : gf.width / cb.width;
    final sy = cb.height == 0 ? 1.0 : gf.height / cb.height;
    final data = mergePatch(decodeMap(g.dataJson), {
      'v': 1,
      'childBounds': {'x': u.x, 'y': u.y, 'w': u.width, 'h': u.height},
    });
    b.set(
      g,
      {
        ElementCols.x: clampPos(gf.x + (u.x - cb.x) * sx),
        ElementCols.y: clampPos(gf.y + (u.y - cb.y) * sy),
        ElementCols.width: clampSide(u.width * sx),
        ElementCols.height: clampSide(u.height * sy),
        ElementCols.dataJson: jsonEncode(data),
      },
      together: const {
        ElementCols.x,
        ElementCols.y,
        ElementCols.width,
        ElementCols.height,
        ElementCols.dataJson,
      },
    );
  }

  String setReadingOrder(SetReadingOrder op) {
    final owner = op.ownerId;
    if (deck.slide(owner) == null &&
        deck.layout(owner) == null &&
        deck.master(owner) == null) {
      notFound('Slide', owner);
    }
    final ids = unique(op.elementIds);
    for (final id in ids) {
      if (elementOf(id).ownerId != owner) {
        invalid('$id is not an element of $owner');
      }
    }
    final keys = OrderKeys.between(null, null, ids.length);
    final keyOf = {for (final (i, id) in ids.indexed) id: keys[i]};
    for (final e in deck.allElementsOf(owner)) {
      final k = keyOf[e.id];
      if (e.readingKey != k) b.set(e, {ElementCols.readingKey: k});
    }
    return 'Reading order';
  }
}
