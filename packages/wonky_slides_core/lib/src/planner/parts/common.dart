part of '../slides_planner.dart';

/// One planning run: the operation's changes are collected in [b].
final class _Planner {
  _Planner(this.deck, this.ctx) : b = PlanBuilder(deck), ix = deck.indexes;

  final DeckModel deck;
  final SlidesPlanContext ctx;
  final PlanBuilder b;
  final DeckIndexes ix;
  final Map<String, Object?> result = {};
  final List<String> warnings = [];

  SlidesLimits get limits => ctx.limits;

  String dispatch(SlidesOperation op) => switch (op) {
    CreateDeck() => createDeck(op),
    SetDeckProps() => setDeckProps(op),
    SetDeckTheme() => setDeckTheme(op),
    AddSlides() => addSlides(op),
    DuplicateSlides() => duplicateSlides(op),
    DeleteSlides() => deleteSlides(op),
    MoveSlides() => moveSlides(op),
    SetSlideProps() => setSlideProps(op),
    ResetSlideToLayout() => resetSlideToLayout(op),
    CreateGroup() => createGroup(op),
    Ungroup() => ungroup(op),
    MoveGroups() => moveGroups(op),
    SetGroupProps() => setGroupProps(op),
    DeleteGroups() => deleteGroups(op),
    DuplicateGroups() => duplicateGroups(op),
    PasteSlides() => pasteSlides(op),
    PasteElements() => pasteElements(op),
    InsertElements() => insertElements(op),
    UpdateFrames() => updateFrames(op),
    SetElementProps() => setElementProps(op),
    DeleteElements() => deleteElements(op),
    ReorderZ() => reorderZ(op),
    AlignDistribute() => alignDistribute(op),
    GroupElements() => groupElements(op),
    UngroupElements() => ungroupElements(op),
    ReplaceImage() => replaceImage(op),
    SetElementData() => setElementData(op),
    SetText() => setText(op),
    FormatText() => formatText(op),
    SetTextBoxStyle() => setTextBoxStyle(op),
    ResetPlaceholders() => resetPlaceholders(op),
    InsertTableAxes() => insertTableAxes(op),
    DeleteTableAxes() => deleteTableAxes(op),
    MoveTableAxes() => moveTableAxes(op),
    ResizeTableAxes() => resizeTableAxes(op),
    SetCells() => setCells(op),
    MergeCells() => mergeCells(op),
    UnmergeCells() => unmergeCells(op),
    SetTableOptions() => setTableOptions(op),
    AddBuilds() => addBuilds(op),
    UpdateBuilds() => updateBuilds(op),
    MoveBuilds() => moveBuilds(op),
    DeleteBuilds() => deleteBuilds(op),
    SetCode() => setCode(op),
    AddCodeStates() => addCodeStates(op),
    UpdateCodeState() => updateCodeState(op),
    MoveCodeStates() => moveCodeStates(op),
    DeleteCodeStates() => deleteCodeStates(op),
    LinkChart() => linkChart(op),
    UpdateChartLink() => updateChartLink(op),
    SetChartAutoUpdate() => setChartAutoUpdate(op),
    UnlinkChart() => unlinkChart(op),
    SetChartStyle() => setChartStyle(op),
    ImportTheme() => importTheme(op),
    UpdateTheme() => updateTheme(op),
    ApplyThemeToSlides() => applyThemeToSlides(op),
    DeleteTheme() => deleteTheme(op),
    AddMaster() => addMaster(op),
    AddLayout() => addLayout(op),
    UpdateMasterOrLayout() => updateMasterOrLayout(op),
    DeleteMastersOrLayouts() => deleteMastersOrLayouts(op),
    RepairDeck() => repairDeck(op),
    MoveElementsZ() => moveElementsZ(op),
    SetReadingOrder() => setReadingOrder(op),
  };

  // ---------------------------------------------------------------------------
  // Errors and lookups.

  Never notFound(String what, String id) => throw PlanException(
    PlanException.notFound,
    '$what $id not found',
    details: {'id': id},
  );

  Never invalid(String message, [Map<String, Object?> details = const {}]) =>
      throw PlanException(
        PlanException.invalidArgument,
        message,
        details: details,
      );

  Never limit(String message) =>
      throw PlanException(PlanException.limit, message);

  DeckRec deckRow() => deck.deck ?? notFound('Presentation', deck.deckId);

  SlideRec slideOf(String id) => deck.slide(id) ?? notFound('Slide', id);

  SlideGroupRec groupOf(String id) => deck.group(id) ?? notFound('Group', id);

  SlideElementRec elementOf(String id) =>
      deck.element(id) ?? notFound('Element', id);

  DeckThemeRec themeOf(String id) => deck.theme(id) ?? notFound('Theme', id);

  SlideLayoutRec layoutOf(String id) =>
      deck.layout(id) ?? notFound('Layout', id);

  SlideMasterRec masterOf(String id) =>
      deck.master(id) ?? notFound('Master', id);

  /// [ids] without duplicates, in their given order.
  List<String> unique(Iterable<String> ids) => {...ids}.toList();

  String newId() => ctx.ids.newId();

  String newMatchKey() => SlidesIds.newMatchKey(ctx.ids);

  SuRect get bounds {
    final d = deck.deck;
    return SuRect(0, 0, d?.width ?? 1920, d?.height ?? 1080);
  }

  String plural(int n, String one, String many) => n == 1 ? one : many;

  // ---------------------------------------------------------------------------
  // JSON.

  JsonMap? decodeMap(String? json) => PlaceholderIndex.decodeMap(json);

  /// Validates a JSON object column (`fillJson`, `dataJson`, …): must be a
  /// JSON object; `"v": 1` is added when missing. Null stays null.
  String? jsonObject(String? json, String column) {
    if (json == null) return null;
    final Object? v;
    try {
      v = jsonDecode(json);
    } on FormatException catch (e) {
      invalid('$column is not valid JSON: ${e.message}', {'column': column});
    }
    if (v is! Map<String, Object?>) {
      invalid('$column must be a JSON object', {'column': column});
    }
    if (!v.containsKey('v')) return jsonEncode({'v': 1, ...v});
    return json;
  }

  /// RFC 7386 JSON merge patch of [patch] onto [target].
  JsonMap mergePatch(JsonMap? target, Map<String, Object?> patch) {
    final out = <String, Object?>{...?target};
    for (final e in patch.entries) {
      final v = e.value;
      if (v == null) {
        out.remove(e.key);
      } else if (v is Map<String, Object?>) {
        final cur = out[e.key];
        out[e.key] = mergePatch(cur is Map<String, Object?> ? cur : null, v);
      } else {
        out[e.key] = v;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Geometry.

  double clampSide(double v) {
    if (!v.isFinite) return limits.minFrameSide;
    return v.clamp(limits.minFrameSide, limits.maxFrameSide).toDouble();
  }

  double clampPos(double v) {
    if (!v.isFinite) return 0;
    return v.clamp(-limits.maxPosition, limits.maxPosition).toDouble();
  }

  /// The effective frame of [e] in its own (parent) space: stored columns,
  /// else the placeholder chain (02 §10, 05 §5.3).
  ElementFrame frameOf(SlideElementRec e) {
    final stored = e.frame;
    if (stored != null) {
      return ElementFrame.of(
        stored,
        rotation: e.rotation ?? 0,
        flipH: e.flipH,
        flipV: e.flipV,
      );
    }
    final eff = ix.placeholders.effective(e, bounds: bounds);
    return ElementFrame.of(
      eff.frame,
      rotation: e.rotation ?? eff.rotation,
      flipH: e.flipH,
      flipV: e.flipV,
    );
  }

  // ---------------------------------------------------------------------------
  // Key spaces.

  /// Top-level items of the slide order `(sortKey, id)` (groups and
  /// ungrouped slides), in the plan's view.
  List<KeyedItem> topLevelItems() {
    final items = <KeyedItem>[
      for (final g in b.records(SlidesTables.slideGroup))
        ((g as SlideGroupRec).sortKey, g.id),
      for (final s in b.records(SlidesTables.slide))
        if ((s as SlideRec).groupId == null) (s.sortKey, s.id),
    ];
    return OrderKeys.sorted(items);
  }

  /// Slides of [groupId] `(sortKey, id)` in the plan's view.
  List<KeyedItem> groupItems(String groupId) {
    final items = <KeyedItem>[
      for (final s in b.records(SlidesTables.slide))
        if ((s as SlideRec).groupId == groupId) (s.sortKey, s.id),
    ];
    return OrderKeys.sorted(items);
  }

  /// [count] keys at [target] and the target key space's group id. Items in
  /// [exclude] (rows being moved) are skipped.
  (String?, List<String>) keysAt(
    SlideTarget target,
    int count, {
    Set<String> exclude = const {},
  }) {
    switch (target) {
      case TopLevel(:final beforeId, :final afterId):
        final items = topLevelItems();
        final i = OrderKeys.indexFor(
          items,
          beforeId: beforeId,
          afterId: afterId,
        );
        if (i < 0) notFound('Slide or group', (afterId ?? beforeId)!);
        return (null, OrderKeys.at(items, i, count, exclude: exclude));
      case InGroup(:final groupId, :final beforeId, :final afterId):
        if (!b.exists(SlidesTables.slideGroup, groupId)) {
          notFound('Group', groupId);
        }
        final items = groupItems(groupId);
        final i = OrderKeys.indexFor(
          items,
          beforeId: beforeId,
          afterId: afterId,
        );
        if (i < 0) notFound('Slide', (afterId ?? beforeId)!);
        return (groupId, OrderKeys.at(items, i, count, exclude: exclude));
    }
  }

  /// The target "after [slideId], in its key space" (*New slide*).
  SlideTarget afterSlide(String slideId) {
    final s = slideOf(slideId);
    final g = s.groupId;
    return g != null && deck.group(g) != null
        ? InGroup(g, afterId: s.id)
        : (s.groupId == null ? TopLevel(afterId: s.id) : const TopLevel());
  }

  /// Sibling elements `(zKey, id)` of owner [ownerId] under [parentId], in
  /// the plan's view.
  List<KeyedItem> zItems(String ownerId, String? parentId) {
    final items = <KeyedItem>[];
    final seen = <String>{};
    for (final e in deck.allElementsOf(ownerId)) {
      seen.add(e.id);
      final cur = b.rec(SlidesTables.slideElement, e.id) as SlideElementRec?;
      if (cur != null && cur.ownerId == ownerId && cur.parentId == parentId) {
        items.add((cur.zKey, cur.id));
      }
    }
    for (final r in b.inserted(SlidesTables.slideElement)) {
      final cur = r as SlideElementRec;
      if (seen.contains(cur.id)) continue;
      if (cur.ownerId == ownerId && cur.parentId == parentId) {
        items.add((cur.zKey, cur.id));
      }
    }
    return OrderKeys.sorted(items);
  }

  // ---------------------------------------------------------------------------
  // Shared row writers.

  /// The `ElementCols` owner column for [kind].
  static String ownerColumn(ElementOwnerKind kind) => switch (kind) {
    ElementOwnerKind.slide => SlidesCols.slideId,
    ElementOwnerKind.layout => ElementCols.layoutId,
    ElementOwnerKind.master => ElementCols.masterId,
  };

  /// Inserts an element row (defaults for missing columns).
  void insertElement(Map<String, Object?> columns) {
    b.insert(SlidesTables.slideElement, {
      ...elementDefaults(),
      SlidesCols.createdAt: ctx.now,
      ...columns,
    });
  }

  /// Inserts a slide row.
  void insertSlide(String id, Map<String, Object?> columns) =>
      b.insert(SlidesTables.slide, {
        SlidesCols.id: id,
        SlidesCols.deckId: deck.deckId,
        SlidesCols.backgroundJson: null,
        SlidesCols.skipped: false,
        SlideCols.notes: null,
        SlidesCols.transitionJson: null,
        SlidesCols.hideMasterElements: null,
        SlideCols.timingsJson: null,
        SlidesCols.createdAt: ctx.now,
        ...columns,
      });

  /// Creates the placeholder instances of [placeholders] (a layout's
  /// placeholder definitions in order) on slide [slideId] (05 §5.2):
  /// deterministic ids, frame/style null, `text` null. Returns the ids.
  List<String> instantiate(
    String slideId,
    List<SlideElementRec> placeholders, {
    String? afterZ,
  }) {
    var z = afterZ;
    final out = <String>[];
    for (final def in placeholders) {
      final type = def.placeholderType;
      if (type == null || !type.isInstantiated) continue;
      var id = SlidesIds.placeholderInstanceId(slideId, def.id);
      if (b.exists(SlidesTables.slideElement, id)) {
        final cur = b.rec(SlidesTables.slideElement, id) as SlideElementRec;
        if (cur.placeholderOf == def.id && cur.slideId == slideId) {
          continue; // Already instantiated.
        }
        id = newId(); // The deterministic id is taken by a re-pointed instance.
      }
      z = OrderKeys.between(z, null, 1).single;
      insertElement({
        SlidesCols.id: id,
        SlidesCols.slideId: slideId,
        SlidesCols.kind: def.kindName,
        ElementCols.placeholderType: type.name,
        ElementCols.placeholderOf: def.id,
        ElementCols.zKey: z,
        ElementCols.matchKey: newMatchKey(),
      });
      out.add(id);
    }
    return out;
  }

  /// Deletes [e] with its descendants and dependent rows (table axes and
  /// cells, code states, chart link, builds), listed for undo.
  void deleteElementTree(SlideElementRec e, [Set<String>? visiting]) {
    final seen = visiting ?? <String>{};
    if (!seen.add(e.id)) return;
    if (!b.exists(SlidesTables.slideElement, e.id)) return;
    final owner = e.ownerId;
    if (owner != null) {
      // Children in the plan's view (the engine cascades `parent`).
      for (final c in [
        ...deck
            .allElementsOf(owner)
            .map(
              (c) => b.rec(SlidesTables.slideElement, c.id) as SlideElementRec?,
            ),
        ...b.inserted(SlidesTables.slideElement).cast<SlideElementRec>(),
      ]) {
        if (c != null && c.parentId == e.id && c.ownerId == owner) {
          deleteElementTree(c, seen);
        }
      }
    }
    for (final r in [
      ...deck.cellsOf(e.id),
      for (final d in TableAxisDimension.values) ...deck.axesOf(e.id, d),
      ...deck.codeStatesOf(e.id),
      ?deck.chartLinkOf(e.id),
      ...ix.buildsOfElement(e.id),
    ]) {
      b.remove(r);
    }
    b.remove(e);
  }

  /// Deletes slide [s] with its elements and builds.
  void deleteSlide(SlideRec s) {
    for (final e in deck.allElementsOf(s.id)) {
      deleteElementTree(e);
    }
    for (final bd in deck.buildsOf(s.id)) {
      b.remove(bd);
    }
    b.remove(s);
  }

  /// Number of elements of [ownerId] in the plan's view.
  int elementCount(String ownerId) {
    var n = 0;
    for (final e in deck.allElementsOf(ownerId)) {
      if (b.exists(SlidesTables.slideElement, e.id)) n++;
    }
    for (final r in b.inserted(SlidesTables.slideElement)) {
      if ((r as SlideElementRec).ownerId == ownerId) n++;
    }
    return n;
  }

  void checkElementLimit(String ownerId, int adding) {
    final max = limits.maxElementsPerOwner;
    if (elementCount(ownerId) + adding > max) {
      limit("This slide can't hold more than $max objects.");
    }
  }

  void checkSlideLimit(int adding) {
    final max = limits.maxSlidesPerDeck;
    if (deck.count(SlidesTables.slide) + adding > max) {
      limit('A presentation can have at most ${_fmt(max)} slides.');
    }
  }

  void checkGroupLimit(int adding) {
    final max = limits.maxGroupsPerDeck;
    if (deck.count(SlidesTables.slideGroup) + adding > max) {
      limit('A presentation can have at most $max groups.');
    }
  }

  static String _fmt(int n) {
    final s = '$n';
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}
