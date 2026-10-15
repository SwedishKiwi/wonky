part of '../slides_planner.dart';

/// Rows of a copy: elements (with descendants) and their dependent rows, as
/// column maps (from the model, or from a clipboard payload, 03 §12.2).
final class _CopySet {
  _CopySet({
    this.elements = const [],
    this.axes = const [],
    this.cells = const [],
    this.builds = const [],
    this.codeStates = const [],
    this.chartLinks = const [],
  });

  final List<Map<String, Object?>> elements;
  final List<Map<String, Object?>> axes;
  final List<Map<String, Object?>> cells;
  final List<Map<String, Object?>> builds;
  final List<Map<String, Object?>> codeStates;
  final List<Map<String, Object?>> chartLinks;
}

extension _ClonePart on _Planner {
  /// The copy set of slide [slideId] in the model.
  _CopySet slideCopySet(String slideId) {
    final elements = deck.allElementsOf(slideId).toList();
    final ids = {for (final e in elements) e.id};
    return _CopySet(
      elements: [for (final e in elements) e.toColumns()],
      axes: [
        for (final id in ids)
          for (final d in TableAxisDimension.values)
            for (final a in deck.axesOf(id, d)) a.toColumns(),
      ],
      cells: [
        for (final id in ids)
          for (final c in deck.cellsOf(id)) c.toColumns(),
      ],
      builds: [for (final bd in deck.buildsOf(slideId)) bd.toColumns()],
      codeStates: [
        for (final id in ids)
          for (final c in deck.codeStatesOf(id)) c.toColumns(),
      ],
      chartLinks: [for (final id in ids) ?deck.chartLinkOf(id)?.toColumns()],
    );
  }

  /// Copies slide [s] (02 §12.1 *DuplicateSlides*): fresh ids, placeholder
  /// instance ids recomputed, match keys kept. Returns the new slide id.
  String cloneSlide(
    SlideRec s, {
    required String? groupId,
    required String sortKey,
    required bool keepMatchKeys,
    String? layoutId,
  }) {
    final id = newId();
    b.insert(SlidesTables.slide, {
      ...s.toColumns(),
      SlidesCols.id: id,
      SlidesCols.deckId: deck.deckId,
      SlideCols.groupId: groupId,
      SlidesCols.sortKey: sortKey,
      SlideCols.layoutId: layoutId ?? s.layoutId,
      SlidesCols.createdAt: ctx.now,
    });
    copyContent(
      slideCopySet(s.id),
      targetSlideId: id,
      sourceSlideId: s.id,
      keepMatchKeys: keepMatchKeys,
    );
    return id;
  }

  /// Inserts copies of [set] on slide [targetSlideId] with fresh ids and
  /// remapped references (parents, placeholder instances, connectors, table
  /// cells, builds, code states, chart links). Top-level elements get the
  /// z keys in [topZ] when given (by old id). Returns old id → new id of
  /// the elements.
  Map<String, String> copyContent(
    _CopySet set, {
    required String targetSlideId,
    required String? sourceSlideId,
    required bool keepMatchKeys,
    Map<String, String> topZ = const {},
    double dx = 0,
    double dy = 0,
    bool keepPlaceholders = true,
  }) {
    final ids = <String, String>{};
    for (final e in set.elements) {
      final old = e[SlidesCols.id]! as String;
      final of = e[ElementCols.placeholderOf] as String?;
      final isInstance =
          keepPlaceholders &&
          of != null &&
          sourceSlideId != null &&
          old == SlidesIds.placeholderInstanceId(sourceSlideId, of);
      final candidate = isInstance
          ? SlidesIds.placeholderInstanceId(targetSlideId, of)
          : newId();
      ids[old] = b.exists(SlidesTables.slideElement, candidate)
          ? newId()
          : candidate;
    }
    final b62 = {
      for (final e in ids.entries)
        Base62Uuid.encode(e.key): Base62Uuid.encode(e.value),
    };
    for (final e in set.elements) {
      final old = e[SlidesCols.id]! as String;
      final parent = e[SlidesCols.parentId] as String?;
      final top = parent == null || !ids.containsKey(parent);
      final placeholder = keepPlaceholders
          ? <String, Object?>{}
          : {
              ElementCols.placeholderType: null,
              ElementCols.placeholderOf: null,
            };
      double? shift(Object? v, double d) =>
          v is num ? clampPos(v.toDouble() + d) : null;
      insertElement({
        ..._known(SlidesTables.slideElement, e),
        SlidesCols.id: ids[old],
        SlidesCols.slideId: targetSlideId,
        ElementCols.layoutId: null,
        ElementCols.masterId: null,
        SlidesCols.parentId: top ? null : ids[parent],
        if (top && topZ.containsKey(old)) ElementCols.zKey: topZ[old],
        if (top && (dx != 0 || dy != 0)) ...{
          ElementCols.x: shift(e[ElementCols.x], dx),
          ElementCols.y: shift(e[ElementCols.y], dy),
        },
        ElementCols.matchKey: keepMatchKeys
            ? (e[ElementCols.matchKey] ?? newMatchKey())
            : newMatchKey(),
        ElementCols.dataJson: _remapJsonIds(
          e[ElementCols.dataJson] as String?,
          b62,
        ),
        ...placeholder,
        SlidesCols.createdAt: ctx.now,
      });
    }
    final axes = <String, String>{};
    for (final a in set.axes) {
      final el = ids[a[SlidesCols.elementId]];
      if (el == null) continue;
      final id = newId();
      axes[a[SlidesCols.id]! as String] = id;
      b.insert(SlidesTables.slideTableAxis, {
        ..._known(SlidesTables.slideTableAxis, a),
        SlidesCols.id: id,
        SlidesCols.elementId: el,
        SlidesCols.createdAt: ctx.now,
      });
    }
    for (final c in set.cells) {
      final el = ids[c[SlidesCols.elementId]];
      final row = axes[c[TableCellCols.rowId]];
      final col = axes[c[TableCellCols.columnId]];
      if (el == null || row == null || col == null) continue;
      b.insert(SlidesTables.slideTableCell, {
        ..._known(SlidesTables.slideTableCell, c),
        SlidesCols.id: SlidesIds.tableCellId(el, row, col),
        SlidesCols.elementId: el,
        TableCellCols.rowId: row,
        TableCellCols.columnId: col,
        SlidesCols.createdAt: ctx.now,
      });
    }
    for (final c in set.codeStates) {
      final el = ids[c[SlidesCols.elementId]];
      if (el == null) continue;
      b.insert(SlidesTables.codeState, {
        ..._known(SlidesTables.codeState, c),
        SlidesCols.id: newId(),
        SlidesCols.elementId: el,
        SlidesCols.createdAt: ctx.now,
      });
    }
    for (final c in set.chartLinks) {
      final el = ids[c[SlidesCols.elementId]];
      if (el == null) continue;
      b.insert(SlidesTables.chartLink, {
        ..._known(SlidesTables.chartLink, c),
        SlidesCols.id: SlidesIds.chartLinkId(el),
        SlidesCols.elementId: el,
        SlidesCols.createdAt: ctx.now,
      });
    }
    // Builds whose element isn't copied are dropped (03 §12.3).
    final existing = OrderKeys.sorted([
      for (final bd in deck.buildsOf(targetSlideId)) (bd.sortKey, bd.id),
    ]);
    final copied =
        [
          for (final bd in set.builds)
            if (ids.containsKey(bd[SlidesCols.elementId])) bd,
        ]..sort(
          (a, c) => FractionalIndex.compare(
            '${a[SlidesCols.sortKey] ?? ''}',
            '${a[SlidesCols.id]}',
            '${c[SlidesCols.sortKey] ?? ''}',
            '${c[SlidesCols.id]}',
          ),
        );
    final sameSlide = sourceSlideId == targetSlideId;
    final keys = sameSlide || existing.isNotEmpty
        ? OrderKeys.at(existing, existing.length, copied.length)
        : null;
    for (final (i, bd) in copied.indexed) {
      b.insert(SlidesTables.slideBuild, {
        ..._known(SlidesTables.slideBuild, bd),
        SlidesCols.id: newId(),
        SlidesCols.slideId: targetSlideId,
        SlidesCols.elementId: ids[bd[SlidesCols.elementId]],
        if (keys != null) SlidesCols.sortKey: keys[i],
        BuildCols.optionsJson: _remapJsonIds(
          bd[BuildCols.optionsJson] as String?,
          b62,
        ),
        SlidesCols.createdAt: ctx.now,
      });
    }
    return ids;
  }

  /// The known columns of [table] from [row].
  static Map<String, Object?> _known(String table, Map<String, Object?> row) =>
      {for (final c in SlidesTables.columns[table]!) c: row[c]};

  /// [json] with base-62 element ids replaced by their copies (connector
  /// `connect.elementId`, build step refs).
  String? _remapJsonIds(String? json, Map<String, String> b62) {
    if (json == null || b62.isEmpty) return json;
    Object? walk(Object? v) => switch (v) {
      final String s => b62[s] ?? s,
      final List<Object?> l => [for (final x in l) walk(x)],
      final Map<String, Object?> m => {
        for (final e in m.entries) e.key: walk(e.value),
      },
      _ => v,
    };
    try {
      return jsonEncode(walk(jsonDecode(json)));
    } on FormatException {
      return json;
    }
  }

  // ---------------------------------------------------------------------------
  // Paste (03 §12).

  static List<Map<String, Object?>> _rows(Object? v) => [
    if (v is List)
      for (final r in v)
        if (r is Map) {for (final e in r.entries) '${e.key}': e.value},
  ];

  _CopySet _payloadSet(Map<String, Object?> p) => _CopySet(
    elements: _rows(p['elements']),
    axes: _rows(p['tableAxes']),
    cells: _rows(p['tableCells']),
    builds: _rows(p['builds']),
    codeStates: _rows(p['codeStates']),
    chartLinks: _rows(p['chartLinks']),
  );

  void _checkPayload(Map<String, Object?> p, Set<String> kinds) {
    if (p['format'] != 'wonky-slides-clipboard' || p['v'] != 1) {
      invalid('Not a Wonky Slides clipboard payload');
    }
    if (!kinds.contains(p['kind'])) {
      invalid('The clipboard holds ${p['kind']}, not ${kinds.join('/')}');
    }
  }

  String pasteSlides(PasteSlides op) {
    final p = op.payload;
    _checkPayload(p, const {'slides', 'groups'});
    final set = _payloadSet(p);
    // Slides in payload order (the copied order).
    final slides = _rows(p['slides']);
    if (slides.isEmpty) invalid('The clipboard holds no slides');
    checkSlideLimit(slides.length);
    final sourceDeck = p['sourceDeckId'] as String?;
    final sameDeck = sourceDeck == deck.deckId;
    // Layout mapping (03 §12.3): same deck → kept; keep source → the
    // source theme copied in; else matched in the destination theme.
    final layoutMap = <String, String?>{};
    if (!sameDeck && op.themeMode == PasteThemeMode.keepSource) {
      layoutMap.addAll(_importPayloadThemes(p));
    }
    final groupsBySlide = <String, Map<String, Object?>>{};
    final groups = _rows(p['groups']);
    for (final g in groups) {
      for (final s in (g['slides'] as List?) ?? const []) {
        groupsBySlide['$s'] = g;
      }
    }
    if (groups.isNotEmpty) checkGroupLimit(groups.length);
    final target =
        op.target ??
        (op.afterSlideId != null
            ? afterSlide(op.afterSlideId!)
            : const TopLevel());
    // Top-level slots: one per ungrouped slide and per group.
    final slots = <Object>[];
    for (final s in slides) {
      final g = groupsBySlide['${s[SlidesCols.id]}'];
      final slot = g ?? s;
      if (!slots.contains(slot)) slots.add(slot);
    }
    final pasteTarget = groups.isNotEmpty && target is InGroup
        ? TopLevel(afterId: target.groupId)
        : target;
    final (groupId, keys) = keysAt(pasteTarget, slots.length);
    final out = <String>[];
    final newGroups = <String>[];
    for (final (i, slot) in slots.indexed) {
      final isGroup = groups.any((g) => identical(g, slot));
      if (isGroup) {
        final g = slot as Map<String, Object?>;
        final gid = newId();
        newGroups.add(gid);
        b.insert(SlidesTables.slideGroup, {
          SlidesCols.id: gid,
          SlidesCols.deckId: deck.deckId,
          SlidesCols.title: _groupTitleOr(g['title']),
          SlidesCols.sortKey: keys[i],
          SlidesCols.parentId: null,
          SlideGroupCols.color: _groupColors.contains(g['color'])
              ? g['color']
              : null,
          SlidesCols.skipped: g['skipped'] == true,
          SlidesCols.createdAt: ctx.now,
        });
        final members = [
          for (final s in slides)
            if (identical(groupsBySlide['${s[SlidesCols.id]}'], g)) s,
        ];
        final inner = OrderKeys.between(null, null, members.length);
        for (final (k, s) in members.indexed) {
          out.add(_pasteSlide(s, set, gid, inner[k], sameDeck, layoutMap));
        }
      } else {
        out.add(
          _pasteSlide(
            slot as Map<String, Object?>,
            set,
            groupId,
            keys[i],
            sameDeck,
            layoutMap,
          ),
        );
      }
    }
    result['slideIds'] = out;
    if (newGroups.isNotEmpty) result['groupIds'] = newGroups;
    return plural(out.length, 'Paste slide', 'Paste slides');
  }

  String _groupTitleOr(Object? t) {
    if (t is String && t.trim().isNotEmpty && t.trim().length <= 100) {
      return t.trim();
    }
    return 'Group ${deck.count(SlidesTables.slideGroup) + 1}';
  }

  String _pasteSlide(
    Map<String, Object?> s,
    _CopySet set,
    String? groupId,
    String sortKey,
    bool sameDeck,
    Map<String, String?> layoutMap,
  ) {
    final old = s[SlidesCols.id]! as String;
    final oldLayout = s[SlideCols.layoutId] as String?;
    final elements = [
      for (final e in set.elements)
        if (e[SlidesCols.slideId] == old) e,
    ];
    String? layoutId;
    if (oldLayout != null && layoutMap.containsKey(oldLayout)) {
      layoutId = layoutMap[oldLayout];
    } else if (sameDeck &&
        oldLayout != null &&
        deck.layout(oldLayout) != null) {
      layoutId = oldLayout;
    } else {
      layoutId = _matchLayout(oldLayout, elements);
    }
    final id = newId();
    b.insert(SlidesTables.slide, {
      for (final c in SlidesTables.columns[SlidesTables.slide]!) c: s[c],
      SlidesCols.id: id,
      SlidesCols.deckId: deck.deckId,
      SlideCols.groupId: groupId,
      SlidesCols.sortKey: sortKey,
      SlideCols.layoutId: layoutId,
      SlidesCols.skipped: s[SlidesCols.skipped] == true,
      SlidesCols.createdAt: ctx.now,
    });
    final sub = _CopySet(
      elements: elements,
      axes: set.axes,
      cells: set.cells,
      builds: [
        for (final bd in set.builds)
          if (bd[SlidesCols.slideId] == old) bd,
      ],
      codeStates: set.codeStates,
      chartLinks: set.chartLinks,
    );
    final ids = copyContent(
      sub,
      targetSlideId: id,
      sourceSlideId: old,
      keepMatchKeys: true,
    );
    // Instances must point at placeholders of the new layout.
    if (layoutId != null) {
      final targets = ix.placeholders.placeholdersOf(layoutId);
      final pending = [...targets];
      for (final e in elements) {
        final type = SlidePlaceholderType.fromName(
          e[ElementCols.placeholderType],
        );
        if (type == null) continue;
        final of = e[ElementCols.placeholderOf] as String?;
        final keep = of != null && targets.any((t) => t.id == of);
        String? next;
        if (keep) {
          next = of;
          pending.removeWhere((t) => t.id == of);
        } else {
          final i = pending.indexWhere((t) => t.placeholderType == type);
          if (i >= 0) next = pending.removeAt(i).id;
        }
        b.update(SlidesTables.slideElement, ids[e[SlidesCols.id]]!, {
          ElementCols.placeholderOf: next,
          if (next == null) ElementCols.placeholderType: null,
        });
      }
    }
    return id;
  }

  /// A destination layout for a pasted slide (03 §12.3): same key, else
  /// best placeholder-signature match in the default theme.
  String? _matchLayout(String? oldLayout, List<Map<String, Object?>> elements) {
    final theme = ix.themes.defaultTheme;
    if (theme == null) return null;
    final key = oldLayout == null ? null : deck.layout(oldLayout)?.key;
    final types = [
      for (final e in elements)
        ?SlidePlaceholderType.fromName(e[ElementCols.placeholderType]),
    ];
    final match = LayoutMatcher.match(
      key: key,
      types: types,
      candidates: [
        for (final l in ix.themes.layoutsOfTheme(theme.id))
          LayoutCandidate(
            id: l.id,
            key: l.key,
            types: [
              for (final p in ix.placeholders.placeholdersOf(l.id))
                p.placeholderType!,
            ],
          ),
      ],
    );
    return match?.id;
  }

  /// Copies the payload's themes (*Keep source formatting*) with
  /// `themeCopyId(deck, "deck:<sourceItem>:<themeId>")` / `themePartId`
  /// ids; returns old layout id → new layout id.
  Map<String, String?> _importPayloadThemes(Map<String, Object?> p) {
    final source = (p['sourceItemUuid'] ?? p['sourceDeckId']) as String?;
    final out = <String, String?>{};
    if (source == null) return out;
    for (final t in _rows(p['themes'])) {
      final oldTheme = t[SlidesCols.id] as String?;
      if (oldTheme == null) continue;
      final sourceKey = SlidesIds.deckThemeSourceKey(source, oldTheme);
      out.addAll(
        copyThemeEntry(
          t,
          themeId: SlidesIds.themeCopyId(deck.deckId, sourceKey),
          sourceKey: sourceKey,
        ),
      );
    }
    return out;
  }

  String pasteElements(PasteElements op) {
    final p = op.payload;
    _checkPayload(p, const {'elements'});
    final slide = slideOf(op.slideId);
    final set = _payloadSet(p);
    if (set.elements.isEmpty) invalid('The clipboard holds no objects');
    checkElementLimit(slide.id, set.elements.length);
    final oldIds = {for (final e in set.elements) e[SlidesCols.id]};
    final tops =
        [
          for (final e in set.elements)
            if (!oldIds.contains(e[SlidesCols.parentId])) e,
        ]..sort(
          (a, c) => FractionalIndex.compare(
            '${a[ElementCols.zKey] ?? ''}',
            '${a[SlidesCols.id]}',
            '${c[ElementCols.zKey] ?? ''}',
            '${c[SlidesCols.id]}',
          ),
        );
    final sameSlide =
        p['sourceSlideId'] == slide.id && p['sourceDeckId'] == deck.deckId;
    // Position: [at] = top-left of the pasted bounds; else same position,
    // +32 su on the source slide (03 §12.3).
    final rects = [
      for (final e in tops)
        if (e[ElementCols.x] is num &&
            e[ElementCols.y] is num &&
            e[ElementCols.width] is num &&
            e[ElementCols.height] is num)
          SuRect(
            (e[ElementCols.x]! as num).toDouble(),
            (e[ElementCols.y]! as num).toDouble(),
            (e[ElementCols.width]! as num).toDouble(),
            (e[ElementCols.height]! as num).toDouble(),
          ),
    ];
    final box = unionRects(rects);
    var dx = 0.0, dy = 0.0;
    if (op.atX != null && op.atY != null && box != null) {
      dx = op.atX! - box.x;
      dy = op.atY! - box.y;
    } else if (sameSlide) {
      dx = dy = 32;
    }
    final z = zItems(slide.id, null);
    final keys = OrderKeys.at(z, z.length, tops.length);
    final topZ = {
      for (final (i, e) in tops.indexed) '${e[SlidesCols.id]}': keys[i],
    };
    // Pasted placeholders become regular elements with their frame.
    final materialized = <Map<String, Object?>>[
      for (final e in set.elements)
        if (e[ElementCols.placeholderType] != null && e[ElementCols.x] == null)
          {...e, ..._payloadFrame(e)}
        else
          e,
    ];
    final ids = copyContent(
      _CopySet(
        elements: materialized,
        axes: set.axes,
        cells: set.cells,
        builds: set.builds,
        codeStates: set.codeStates,
        chartLinks: set.chartLinks,
      ),
      targetSlideId: slide.id,
      sourceSlideId: null,
      keepMatchKeys: !sameSlide,
      topZ: topZ,
      dx: dx,
      dy: dy,
      keepPlaceholders: false,
    );
    result['elementIds'] = [for (final e in tops) ids['${e[SlidesCols.id]}']];
    return 'Paste';
  }

  /// The effective frame of a pasted placeholder instance whose source is
  /// in this deck, else the 10 % inset default (02 §10).
  Map<String, Object?> _payloadFrame(Map<String, Object?> e) {
    final src = deck.element('${e[SlidesCols.id]}');
    final f = src != null
        ? frameOf(src).rect
        : SuRect(
            bounds.width * 0.1,
            bounds.height * 0.1,
            bounds.width * 0.8,
            bounds.height * 0.8,
          );
    return {
      ElementCols.x: f.x,
      ElementCols.y: f.y,
      ElementCols.width: f.width,
      ElementCols.height: f.height,
    };
  }
}
