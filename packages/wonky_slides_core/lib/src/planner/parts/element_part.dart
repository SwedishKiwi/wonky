part of '../slides_planner.dart';

/// Columns an `ElementSpec` may not set (the planner owns them).
const _plannerOwnedElementColumns = {
  SlidesCols.id,
  SlidesCols.slideId,
  ElementCols.layoutId,
  ElementCols.masterId,
  SlidesCols.parentId,
  SlidesCols.kind,
  ElementCols.zKey,
  SlidesCols.createdAt,
};

/// JSON object columns of `slide_element`.
const _elementJsonColumns = {
  ElementCols.textStyleJson,
  ElementCols.fillJson,
  ElementCols.strokeJson,
  ElementCols.effectsJson,
  ElementCols.dataJson,
  ElementCols.linkJson,
};

extension _ElementPart on _Planner {
  /// Checks that owner [ownerId] of [kind] exists.
  void _checkOwner(String ownerId, ElementOwnerKind kind) {
    switch (kind) {
      case ElementOwnerKind.slide:
        slideOf(ownerId);
      case ElementOwnerKind.layout:
        layoutOf(ownerId);
      case ElementOwnerKind.master:
        masterOf(ownerId);
    }
  }

  void _checkUnlocked(SlideElementRec e) {
    if (e.locked) {
      throw PlanException(
        PlanException.locked,
        'This object is locked.',
        details: {'id': e.id},
      );
    }
  }

  static int _specCount(List<ElementSpec> specs) =>
      specs.fold(0, (n, s) => n + 1 + _specCount(s.children));

  static int _specDepth(List<ElementSpec> specs) => specs.fold(
    0,
    (d, s) => math.max(d, s.children.isEmpty ? 0 : 1 + _specDepth(s.children)),
  );

  /// Cleans the extra columns of an element spec (text normalized, JSON
  /// validated, planner-owned columns refused).
  Map<String, Object?> _specColumns(Map<String, Object?> columns) {
    final known = SlidesTables.columns[SlidesTables.slideElement]!;
    final out = <String, Object?>{};
    for (final MapEntry(:key, :value) in columns.entries) {
      if (!known.contains(key) || _plannerOwnedElementColumns.contains(key)) {
        invalid('Column $key can\'t be set on a new element', {'column': key});
      }
      if (key == SlidesCols.text) {
        out[key] = _body(value as String?);
      } else if (_elementJsonColumns.contains(key)) {
        out[key] = jsonObject(value as String?, key);
      } else if (key == ElementCols.opacity && value is num) {
        out[key] = value.toDouble().clamp(0, 1).toDouble();
      } else {
        out[key] = value;
      }
    }
    return out;
  }

  String insertElements(InsertElements op) {
    _checkOwner(op.ownerId, op.ownerKind);
    if (op.elements.isEmpty) return 'Insert';
    final parentId = op.parentId;
    var depth = 0;
    if (parentId != null) {
      final p = elementOf(parentId);
      if (p.ownerId != op.ownerId || p.kind != ElementKind.group) {
        invalid('$parentId is not an element group of ${op.ownerId}');
      }
      depth = ix.tree(op.ownerId).depthOf(parentId) + 1;
    }
    if (depth + _specDepth(op.elements) > limits.maxElementGroupDepth) {
      limit(
        'Groups can be nested at most ${limits.maxElementGroupDepth} levels.',
      );
    }
    checkElementLimit(op.ownerId, _specCount(op.elements));
    final sibs = zItems(op.ownerId, parentId);
    var index = sibs.length;
    if (op.aboveId != null) {
      index = OrderKeys.indexFor(sibs, afterId: op.aboveId);
      if (index < 0) notFound('Element', op.aboveId!);
    }
    final keys = OrderKeys.at(sibs, index, op.elements.length);
    final owner = _Planner.ownerColumn(op.ownerKind);
    final ids = <String>[];

    void add(ElementSpec e, String? parent, String zKey) {
      final id = e.id ?? newId();
      if (b.exists(SlidesTables.slideElement, id)) {
        invalid('Element $id already exists');
      }
      ids.add(id);
      final cols = _specColumns(e.columns);
      insertElement({
        SlidesCols.id: id,
        owner: op.ownerId,
        SlidesCols.parentId: parent,
        SlidesCols.kind: e.kind.name,
        ElementCols.x: clampPos(e.x),
        ElementCols.y: clampPos(e.y),
        ElementCols.width: clampSide(e.width),
        ElementCols.height: clampSide(e.height),
        ElementCols.rotation: e.rotation == null
            ? null
            : normalizeRotation(e.rotation!),
        ElementCols.zKey: zKey,
        ElementCols.matchKey: newMatchKey(),
        ...cols,
      });
      switch (e.kind) {
        case ElementKind.table:
          _newTableAxes(id, e.tableRows ?? 2, e.tableColumns ?? 2);
        case ElementKind.code:
          final states = e.codeStates.isEmpty
              ? const [
                  <String, Object?>{CodeStateCols.code: ''},
                ]
              : e.codeStates;
          if (states.length > limits.maxCodeStates) {
            limit(
              'A code block can have at most ${limits.maxCodeStates} states.',
            );
          }
          final sk = OrderKeys.between(null, null, states.length);
          for (final (i, s) in states.indexed) {
            insertCodeState(id, sk[i], s);
          }
        default:
          break;
      }
      final childKeys = OrderKeys.between(null, null, e.children.length);
      for (final (i, c) in e.children.indexed) {
        add(c, id, childKeys[i]);
      }
    }

    for (final (i, e) in op.elements.indexed) {
      add(e, parentId, keys[i]);
    }
    result['elementIds'] = ids;
    return 'Insert';
  }

  /// Writes a frame change of [e] (02 P4, 05 §5.2): moving writes `x,y`
  /// together; resizing — or moving an element whose frame is inherited —
  /// writes all four frame columns.
  void writeFrame(
    SlideElementRec e, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? flipH,
    bool? flipV,
  }) {
    final cur = frameOf(e);
    final moving = x != null || y != null;
    final sizing = width != null || height != null;
    final after = <String, Object?>{};
    final together = <String>{};
    if (moving || sizing) {
      after[ElementCols.x] = clampPos(x ?? cur.x);
      after[ElementCols.y] = clampPos(y ?? cur.y);
      together.addAll({ElementCols.x, ElementCols.y});
      if (sizing || e.frame == null) {
        after[ElementCols.width] = clampSide(width ?? cur.width);
        after[ElementCols.height] = clampSide(height ?? cur.height);
        together.addAll({ElementCols.width, ElementCols.height});
      }
    }
    if (rotation != null) {
      after[ElementCols.rotation] = normalizeRotation(rotation);
    }
    if (flipH != null) after[ElementCols.flipH] = flipH;
    if (flipV != null) after[ElementCols.flipV] = flipV;
    b.set(e, after, together: together);
  }

  String updateFrames(UpdateFrames op) {
    for (final u in op.updates) {
      final e = elementOf(u.elementId);
      _checkUnlocked(e);
      writeFrame(
        e,
        x: u.x,
        y: u.y,
        width: u.width,
        height: u.height,
        rotation: u.rotation,
        flipH: u.flipH,
        flipV: u.flipV,
      );
    }
    if (op.label != null) return op.label!;
    final u = op.updates;
    if (u.any((f) => f.width != null || f.height != null)) return 'Resize';
    if (u.any((f) => f.rotation != null)) return 'Rotate';
    if (u.any((f) => f.flipH != null || f.flipV != null)) return 'Flip';
    return 'Move';
  }

  String setElementProps(SetElementProps op) {
    String? text(Patch<String?>? p, int max, String what) {
      final v = p?.value?.trim();
      if (v == null || v.isEmpty) return null;
      if (v.length > max) invalid('$what can have at most $max characters');
      return v;
    }

    final matchKey = op.matchKey?.trim();
    if (matchKey != null && (matchKey.isEmpty || matchKey.length > 64)) {
      invalid('A Magic Move ID has 1–64 characters');
    }
    final readingKey = op.readingKey?.value;
    if (readingKey != null && !FractionalIndex.isValid(readingKey)) {
      invalid('Invalid reading key $readingKey');
    }
    for (final id in unique(op.elementIds)) {
      final e = elementOf(id);
      b.set(e, {
        if (op.fillJson != null)
          ElementCols.fillJson: jsonObject(
            op.fillJson!.value,
            ElementCols.fillJson,
          ),
        if (op.strokeJson != null)
          ElementCols.strokeJson: jsonObject(
            op.strokeJson!.value,
            ElementCols.strokeJson,
          ),
        if (op.effectsJson != null)
          ElementCols.effectsJson: jsonObject(
            op.effectsJson!.value,
            ElementCols.effectsJson,
          ),
        if (op.opacity != null)
          ElementCols.opacity: op.opacity!.value?.clamp(0, 1).toDouble(),
        ElementCols.locked: ?op.locked,
        SlidesCols.hidden: ?op.hidden,
        if (op.elementName != null)
          SlidesCols.name: text(op.elementName, 100, 'A name'),
        if (op.altText != null)
          ElementCols.altText: text(op.altText, 2000, 'Alt text'),
        ElementCols.decorative: ?op.decorative,
        if (op.linkJson != null)
          ElementCols.linkJson: jsonObject(
            op.linkJson!.value,
            ElementCols.linkJson,
          ),
        ElementCols.matchKey: ?matchKey,
        if (op.readingKey != null) ElementCols.readingKey: readingKey,
      });
    }
    if (op.locked != null) return op.locked! ? 'Lock' : 'Unlock';
    if (op.hidden != null) return op.hidden! ? 'Hide' : 'Show';
    if (op.elementName != null) return 'Rename';
    if (op.altText != null || op.decorative != null) return 'Alt text';
    if (op.matchKey != null) return 'Set Magic Move ID';
    if (op.readingKey != null) return 'Reading order';
    if (op.linkJson != null) return 'Link';
    return 'Format';
  }

  String deleteElements(DeleteElements op) {
    final ids = unique(op.elementIds);
    final parents = <String>{};
    for (final id in ids) {
      final e = elementOf(id);
      _checkUnlocked(e);
      final owner = e.ownerId;
      final p = owner == null ? null : ix.tree(owner).parentOf(e.id);
      if (p != null) parents.add(p);
      deleteElementTree(e);
    }
    // A group whose children are all deleted goes too (02 §10).
    for (final p in parents) {
      _deleteIfEmptyGroup(p);
    }
    return 'Delete';
  }

  void _deleteIfEmptyGroup(String groupId) {
    final g = b.rec(SlidesTables.slideElement, groupId) as SlideElementRec?;
    if (g == null || g.kind != ElementKind.group) return;
    final owner = g.ownerId;
    if (owner == null) return;
    final alive = ix
        .tree(owner)
        .childrenOf(groupId)
        .any((c) => b.exists(SlidesTables.slideElement, c.id));
    if (alive) return;
    final up = ix.tree(owner).parentOf(groupId);
    deleteElementTree(g);
    if (up != null) _deleteIfEmptyGroup(up);
  }

  String reorderZ(ReorderZ op) {
    final spaces = <(String, String?), Set<String>>{};
    for (final id in unique(op.elementIds)) {
      final e = elementOf(id);
      final owner = e.ownerId ?? notFound('Owner of', id);
      final parent = ix.tree(owner).parentOf(id);
      (spaces[(owner, parent)] ??= {}).add(id);
    }
    for (final MapEntry(key: (owner, parent), value: ids) in spaces.entries) {
      final sibs = zItems(owner, parent);
      final selected = [
        for (final (i, s) in sibs.indexed)
          if (ids.contains(s.$2)) i,
      ];
      final n = selected.length;
      int? at;
      switch (op.op) {
        case ZOrderOp.toFront:
          final already =
              selected.last == sibs.length - 1 &&
              selected.first == sibs.length - n;
          if (!already) at = sibs.length;
        case ZOrderOp.toBack:
          final already = selected.first == 0 && selected.last == n - 1;
          if (!already) at = 0;
        case ZOrderOp.forward:
          final j = _neighbor(owner, sibs, ids, selected.last, up: true);
          if (j != null) at = j + 1;
        case ZOrderOp.backward:
          final j = _neighbor(owner, sibs, ids, selected.first, up: false);
          if (j != null) at = j;
      }
      if (at == null) continue;
      final keys = OrderKeys.at(sibs, at, n, exclude: ids);
      for (final (k, i) in selected.indexed) {
        b.update(SlidesTables.slideElement, sibs[i].$2, {
          ElementCols.zKey: keys[k],
        });
      }
    }
    return switch (op.op) {
      ZOrderOp.toFront => 'Bring to front',
      ZOrderOp.forward => 'Bring forward',
      ZOrderOp.backward => 'Send backward',
      ZOrderOp.toBack => 'Send to back',
    };
  }

  /// The index of the next non-selected sibling above ([up]) or below
  /// [from] that overlaps a selected element (03 §8.3), else the adjacent
  /// non-selected sibling; null when there is none.
  int? _neighbor(
    String owner,
    List<KeyedItem> sibs,
    Set<String> ids,
    int from, {
    required bool up,
  }) {
    final boxes = [for (final id in ids) frameOf(elementOf(id)).bounds];
    int? adjacent;
    for (
      var i = up ? from + 1 : from - 1;
      up ? i < sibs.length : i >= 0;
      i += up ? 1 : -1
    ) {
      if (ids.contains(sibs[i].$2)) continue;
      adjacent ??= i;
      final box = frameOf(elementOf(sibs[i].$2)).bounds;
      if (boxes.any((x) => rectsOverlap(x, box))) return i;
    }
    return adjacent;
  }

  String alignDistribute(AlignDistribute op) {
    final els = [for (final id in unique(op.elementIds)) elementOf(id)];
    if (els.isEmpty) return 'Align';
    for (final e in els) {
      _checkUnlocked(e);
    }
    final boxes = [for (final e in els) frameOf(e).bounds];
    final distribute =
        op.mode == AlignMode.distributeH || op.mode == AlignMode.distributeV;
    if (distribute) {
      if (els.length < 3) return 'Distribute';
      final horizontal = op.mode == AlignMode.distributeH;
      final order = [for (var i = 0; i < els.length; i++) i]
        ..sort((a, c) {
          final ka = horizontal ? boxes[a].x : boxes[a].y;
          final kc = horizontal ? boxes[c].x : boxes[c].y;
          final d = ka.compareTo(kc);
          return d != 0 ? d : els[a].id.compareTo(els[c].id);
        });
      final first = boxes[order.first], last = boxes[order.last];
      final span = horizontal ? last.right - first.x : last.bottom - first.y;
      final total = order.fold<double>(
        0,
        (s, i) => s + (horizontal ? boxes[i].width : boxes[i].height),
      );
      final gap = (span - total) / (els.length - 1);
      var pos = horizontal ? first.x : first.y;
      for (final i in order) {
        final box = boxes[i];
        final d = pos - (horizontal ? box.x : box.y);
        _shift(els[i], horizontal ? d : 0, horizontal ? 0 : d);
        pos += (horizontal ? box.width : box.height) + gap;
      }
      return 'Distribute';
    }
    final SuRect ref = switch (op.reference) {
      AlignReference.slide => bounds,
      AlignReference.keyObject => boxes.first,
      AlignReference.selection => els.length == 1 ? bounds : unionRects(boxes)!,
    };
    for (final (i, e) in els.indexed) {
      final box = boxes[i];
      final (dx, dy) = switch (op.mode) {
        AlignMode.left => (ref.x - box.x, 0.0),
        AlignMode.centerH => (
          ref.x + ref.width / 2 - (box.x + box.width / 2),
          0.0,
        ),
        AlignMode.right => (ref.right - box.right, 0.0),
        AlignMode.top => (0.0, ref.y - box.y),
        AlignMode.middleV => (
          0.0,
          ref.y + ref.height / 2 - (box.y + box.height / 2),
        ),
        AlignMode.bottom => (0.0, ref.bottom - box.bottom),
        _ => (0.0, 0.0),
      };
      _shift(e, dx, dy);
    }
    return 'Align';
  }

  void _shift(SlideElementRec e, double dx, double dy) {
    if (dx == 0 && dy == 0) return;
    final f = frameOf(e);
    writeFrame(e, x: f.x + dx, y: f.y + dy);
  }

  String groupElements(GroupElements op) {
    final ids = unique(op.elementIds);
    if (ids.length < 2) invalid('Select at least two objects to group');
    final els = [for (final id in ids) elementOf(id)];
    final owner = els.first.ownerId ?? notFound('Owner of', ids.first);
    final tree = ix.tree(owner);
    final parent = tree.parentOf(els.first.id);
    for (final e in els) {
      if (e.ownerId != owner || tree.parentOf(e.id) != parent) {
        invalid('Only objects at the same level can be grouped');
      }
      if (e.placeholderType != null) invalid("Placeholders can't be grouped");
    }
    final height = els.fold(0, (h, e) => math.max(h, tree.heightOf(e.id)));
    final depth = (parent == null ? 0 : tree.depthOf(parent) + 1) + 1 + height;
    if (depth > limits.maxElementGroupDepth) {
      limit(
        'Groups can be nested at most ${limits.maxElementGroupDepth} levels.',
      );
    }
    final sibs = zItems(owner, parent);
    final members = [
      for (final s in sibs)
        if (ids.contains(s.$2)) elementOf(s.$2),
    ];
    final box = unionRects([for (final e in members) frameOf(e).bounds])!;
    final gid = op.groupId ?? newId();
    if (b.exists(SlidesTables.slideElement, gid)) {
      invalid('Element $gid exists');
    }
    final ownerKind = members.first.ownerKind!;
    insertElement({
      SlidesCols.id: gid,
      _Planner.ownerColumn(ownerKind): owner,
      SlidesCols.parentId: parent,
      SlidesCols.kind: ElementKind.group.name,
      ElementCols.x: box.x,
      ElementCols.y: box.y,
      ElementCols.width: clampSide(box.width),
      ElementCols.height: clampSide(box.height),
      ElementCols.zKey: members.last.zKey,
      ElementCols.matchKey: newMatchKey(),
      ElementCols.dataJson: jsonEncode({
        'v': 1,
        'childBounds': {
          'x': box.x,
          'y': box.y,
          'w': clampSide(box.width),
          'h': clampSide(box.height),
        },
      }),
    });
    final keys = OrderKeys.between(null, null, members.length);
    for (final (i, e) in members.indexed) {
      b.set(
        e,
        {SlidesCols.parentId: gid, ElementCols.zKey: keys[i]},
        together: const {SlidesCols.parentId, ElementCols.zKey},
      );
      // Materialize an inherited frame so the child space holds it.
      if (e.frame == null) writeFrame(e, x: frameOf(e).x, y: frameOf(e).y);
    }
    result['groupId'] = gid;
    return 'Group';
  }

  String ungroupElements(UngroupElements op) {
    final out = <String>[];
    var removedBuilds = 0;
    for (final id in unique(op.groupIds)) {
      final g = elementOf(id);
      if (g.kind != ElementKind.group) invalid('$id is not a group');
      final owner = g.ownerId ?? notFound('Owner of', id);
      final tree = ix.tree(owner);
      final parent = tree.parentOf(id);
      final gf = frameOf(g);
      final cb = SlideResolver.childBoundsOf(decodeMap(g.dataJson)) ?? gf.rect;
      final children = tree.childrenOf(id);
      final sibs = zItems(owner, parent);
      final at = sibs.indexWhere((s) => s.$2 == id);
      final keys = OrderKeys.at(
        sibs,
        at < 0 ? sibs.length : at,
        children.length,
        exclude: {id},
      );
      final groupOpacity = g.opacity;
      for (final (i, c) in children.indexed) {
        final f = GroupSpace.toParent(frameOf(c), gf, cb);
        b.set(
          c,
          {
            SlidesCols.parentId: parent,
            ElementCols.zKey: keys[i],
            ElementCols.x: clampPos(f.x),
            ElementCols.y: clampPos(f.y),
            ElementCols.width: clampSide(f.width),
            ElementCols.height: clampSide(f.height),
            ElementCols.rotation: f.rotation == 0 && c.rotation == null
                ? null
                : f.rotation,
            ElementCols.flipH: f.flipH,
            ElementCols.flipV: f.flipV,
            if (groupOpacity != null && groupOpacity != 1)
              ElementCols.opacity: ((c.opacity ?? 1) * groupOpacity)
                  .clamp(0, 1)
                  .toDouble(),
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
        out.add(c.id);
      }
      for (final bd in ix.buildsOfElement(id)) {
        b.remove(bd);
        removedBuilds++;
      }
      b.remove(g);
    }
    if (removedBuilds > 0) {
      warnings.add(
        'Ungrouping removed $removedBuilds '
        '${removedBuilds == 1 ? 'animation' : 'animations'}',
      );
    }
    result['elementIds'] = out;
    return 'Ungroup';
  }

  String replaceImage(ReplaceImage op) {
    final e = elementOf(op.elementId);
    if (e.kind != ElementKind.image) invalid('${e.id} is not an image');
    if (!op.src.startsWith('wonky-file://') && !op.src.startsWith('https://')) {
      invalid('An image source is wonky-file:// or https://');
    }
    if (op.naturalWidth <= 0 || op.naturalHeight <= 0) {
      invalid('The image size must be positive');
    }
    final data = mergePatch(decodeMap(e.dataJson), {
      'v': 1,
      'src': op.src,
      'naturalWidth': op.naturalWidth,
      'naturalHeight': op.naturalHeight,
      'crop': op.crop,
      'fileName': op.fileName,
      'mimeType': op.mimeType,
    });
    b.set(e, {ElementCols.dataJson: jsonEncode(data)});
    return 'Replace image';
  }

  String setElementData(SetElementData op) {
    final e = elementOf(op.elementId);
    b.set(e, {
      ElementCols.dataJson: jsonObject(op.dataJson, ElementCols.dataJson),
    });
    return 'Format';
  }
}
