part of '../slides_planner.dart';

extension _ThemePart on _Planner {
  String _nextThemeKey() => OrderKeys.last(
    OrderKeys.sorted([
      for (final t in b.records(SlidesTables.deckTheme))
        ((t as DeckThemeRec).sortKey, t.id),
    ]),
  );

  /// Inserts the rows of a theme copy that don't exist yet (repeated copies
  /// merge, 05 §9; existing rows keep their edits). Returns the theme id.
  String copyTheme(List<SlidesRow> rows, String themeId) {
    if (!b.exists(SlidesTables.deckTheme, themeId) &&
        deck.count(SlidesTables.deckTheme) + 1 > limits.maxThemesPerDeck) {
      limit(
        'A presentation can have at most ${limits.maxThemesPerDeck} themes.',
      );
    }
    for (final (t, c) in rows) {
      final id = c[SlidesCols.id]! as String;
      if (b.exists(t, id)) continue;
      if (t == SlidesTables.slideElement) {
        insertElement(c);
      } else {
        b.insert(t, c);
      }
    }
    return themeId;
  }

  /// Copies a deck theme entry (the `deck_theme` columns plus `masters`,
  /// `layouts` and `elements` rows, `SlidesClipboardCodec.themeEntry`) as
  /// theme [themeId] with parts `themePartId(themeId, sourceRowId)`; rows
  /// that exist already are kept (repeated imports merge, 05 §9). Returns
  /// source layout id → copied layout id.
  Map<String, String?> copyThemeEntry(
    Map<String, Object?> t, {
    required String themeId,
    required String? sourceKey,
    String? name,
  }) {
    List<Map<String, Object?>> rows(Object? v) => [
      if (v is List)
        for (final r in v)
          if (r is Map) {for (final e in r.entries) '${e.key}': e.value},
    ];
    final out = <String, String?>{};
    String part(String id) => SlidesIds.themePartId(themeId, id);
    if (!b.exists(SlidesTables.deckTheme, themeId)) {
      if (deck.count(SlidesTables.deckTheme) + 1 > limits.maxThemesPerDeck) {
        limit(
          'A presentation can have at most ${limits.maxThemesPerDeck} themes.',
        );
      }
      b.insert(SlidesTables.deckTheme, {
        for (final c in SlidesTables.columns[SlidesTables.deckTheme]!) c: t[c],
        SlidesCols.id: themeId,
        DeckThemeCols.deckId: deck.deckId,
        DeckThemeCols.sourceKey: sourceKey,
        SlidesCols.name: ?name,
        SlidesCols.sortKey: _nextThemeKey(),
        SlidesCols.createdAt: ctx.now,
      });
    }
    for (final m in rows(t['masters'])) {
      final id = part('${m[SlidesCols.id]}');
      if (!b.exists(SlidesTables.slideMaster, id)) {
        b.insert(SlidesTables.slideMaster, {
          for (final c in SlidesTables.columns[SlidesTables.slideMaster]!)
            c: m[c],
          SlidesCols.id: id,
          SlideMasterCols.themeId: themeId,
          SlidesCols.createdAt: ctx.now,
        });
      }
    }
    for (final l in rows(t['layouts'])) {
      final old = '${l[SlidesCols.id]}';
      final id = part(old);
      out[old] = id;
      if (!b.exists(SlidesTables.slideLayout, id)) {
        b.insert(SlidesTables.slideLayout, {
          for (final c in SlidesTables.columns[SlidesTables.slideLayout]!)
            c: l[c],
          SlidesCols.id: id,
          SlideLayoutCols.masterId: part('${l[SlideLayoutCols.masterId]}'),
          SlidesCols.createdAt: ctx.now,
        });
      }
    }
    for (final e in rows(t['elements'])) {
      final id = part('${e[SlidesCols.id]}');
      if (b.exists(SlidesTables.slideElement, id)) continue;
      String? mapped(String col) {
        final v = e[col];
        return v == null ? null : part('$v');
      }

      insertElement({
        for (final c in SlidesTables.columns[SlidesTables.slideElement]!)
          c: e[c],
        SlidesCols.id: id,
        SlidesCols.slideId: null,
        ElementCols.layoutId: mapped(ElementCols.layoutId),
        ElementCols.masterId: mapped(ElementCols.masterId),
        SlidesCols.parentId: mapped(SlidesCols.parentId),
        ElementCols.placeholderOf: mapped(ElementCols.placeholderOf),
        SlidesCols.createdAt: ctx.now,
      });
    }
    return out;
  }

  String importTheme(ImportTheme op) {
    if (op.themeEntry case final entry?) {
      final name = op.themeName?.trim();
      if (name != null && (name.isEmpty || name.length > 100)) {
        invalid('A theme name has 1–100 characters');
      }
      if (entry[SlidesCols.id] is! String) invalid('Invalid theme');
      final themeId = op.sourceKey == null
          ? newId()
          : SlidesIds.themeCopyId(deck.deckId, op.sourceKey!);
      final map = copyThemeEntry(
        entry,
        themeId: themeId,
        sourceKey: op.sourceKey,
        name: name,
      );
      final layoutIds = <String, String>{};
      for (final id in map.values) {
        final rec = b.rec(SlidesTables.slideLayout, id!);
        final key = rec is SlideLayoutRec ? rec.key : null;
        if (key != null) layoutIds.putIfAbsent(key, () => id);
      }
      result['themeId'] = themeId;
      result['layoutIds'] = layoutIds;
      result['layoutMap'] = map;
      return op.sourceKey == null ? 'Duplicate theme' : 'Import theme';
    }
    final ThemePackage pkg;
    final String? sourceKey;
    if (op.builtInKey != null) {
      final def =
          BuiltInThemes.byKey(op.builtInKey!) ??
          invalid('Unknown theme ${op.builtInKey}');
      final d = deck.deck;
      final size = d == null
          ? SlideSize.widescreen
          : SlideSize(d.sizePreset, d.width, d.height);
      pkg = BuiltInThemes.package(def.key, size: size)!;
      sourceKey = SlidesIds.builtinThemeSourceKey(def.key, def.version);
    } else {
      final r = ThemePackage.fromJson(op.packageJson);
      if (r.package == null) {
        invalid(
          'Invalid theme: '
          '${r.errors.map((e) => '${e.path}: ${e.message}').join('; ')}',
        );
      }
      pkg = r.package!;
      sourceKey = op.sourceKey;
    }
    final (rows, ids) = ThemeCopy.packageRows(
      pkg,
      deckId: deck.deckId,
      sourceKey: sourceKey,
      themeId: sourceKey == null ? newId() : null,
      now: ctx.now,
      sortKey: _nextThemeKey(),
    );
    copyTheme(rows, ids.themeId);
    result['themeId'] = ids.themeId;
    result['layoutIds'] = ids.layoutIds;
    return 'Add theme';
  }

  String updateTheme(UpdateTheme op) {
    final t = themeOf(op.themeId);
    final after = <String, Object?>{};
    if (op.themeName != null) {
      final n = op.themeName!.trim();
      if (n.isEmpty || n.length > 100) {
        invalid('A theme name has 1–100 characters');
      }
      after[SlidesCols.name] = n;
    }
    for (final MapEntry(key: col, value: json) in op.columns.entries) {
      final column =
          DeckThemeColumn.fromName(col) ??
          invalid('Unknown theme column $col', {'column': col});
      final r = const DeckThemeValidator().validateColumnString(column, json);
      if (!r.isValid) {
        throw PlanException(
          PlanException.invalidArgument,
          'Invalid $col: ${r.errors.map((e) => '${e.path}: ${e.message}').join('; ')}',
          details: {
            'column': col,
            'errors': [
              for (final e in r.errors) {'path': e.path, 'code': e.code},
            ],
          },
        );
      }
      final cleaned = r.cleanedJson;
      after[col] = cleaned == null ? null : jsonEncode(cleaned);
    }
    b.set(t, after);
    return op.themeName != null && op.columns.isEmpty
        ? 'Rename theme'
        : 'Edit theme';
  }

  String applyThemeToSlides(ApplyThemeToSlides op) {
    final theme = themeOf(op.themeId);
    final layouts = ix.themes.layoutsOfTheme(theme.id);
    if (layouts.isEmpty) invalid('The theme has no layouts');
    final ids = op.slideIds.isEmpty
        ? [for (final e in ix.order.entries) e.id]
        : unique(op.slideIds);
    final visible = [
      for (final l in layouts)
        if (!l.hidden) l,
    ];
    final candidates = [
      for (final l in visible.isEmpty ? layouts : visible)
        LayoutCandidate(
          id: l.id,
          key: l.key,
          types: [
            for (final p in ix.placeholders.placeholdersOf(l.id))
              p.placeholderType!,
          ],
        ),
    ];
    for (final id in ids) {
      final s = slideOf(id);
      final old = ix.themes.effectiveLayout(s);
      if (old != null && ix.themes.themeOfLayout(old)?.id == theme.id) continue;
      String? target = old == null ? null : op.layoutMapping[old.id];
      if (target != null && !layouts.any((l) => l.id == target)) {
        invalid('Layout $target is not in theme ${theme.id}');
      }
      target ??= LayoutMatcher.match(
        key: old?.key,
        types: [
          for (final p
              in old == null
                  ? ix.placeholders.instancesOf(id)
                  : ix.placeholders.placeholdersOf(old.id))
            p.placeholderType!,
        ],
        candidates: candidates,
      )!.id;
      applyLayout(s, target);
    }
    final all = ids.length == deck.count(SlidesTables.slide);
    if (op.setDefault ?? all) {
      b.set(deckRow(), {DeckCols.themeId: theme.id});
    }
    return 'Apply theme';
  }

  /// Deletes master [m] with its layouts and all their elements.
  void _deleteMaster(SlideMasterRec m) {
    for (final l in deck.layoutsOf(m.id)) {
      _deleteLayout(l);
    }
    for (final e in deck.allElementsOf(m.id)) {
      deleteElementTree(e);
    }
    b.remove(m);
  }

  void _deleteLayout(SlideLayoutRec l) {
    for (final e in deck.allElementsOf(l.id)) {
      deleteElementTree(e);
    }
    b.remove(l);
  }

  String deleteTheme(DeleteTheme op) {
    final t = themeOf(op.themeId);
    final used = ix.themes.slidesUsingTheme(t.id);
    if (used > 0) {
      invalid(
        'Used by $used ${used == 1 ? 'slide' : 'slides'} — apply another '
        'theme first',
      );
    }
    final others = [
      for (final x in deck.themes)
        if (x.id != t.id) x,
    ];
    if (others.isEmpty) invalid("The last theme can't be removed");
    if (ix.themes.defaultTheme?.id == t.id) {
      b.set(deckRow(), {DeckCols.themeId: others.first.id});
    }
    for (final m in deck.mastersOf(t.id)) {
      _deleteMaster(m);
    }
    b.remove(t);
    return 'Remove theme';
  }

  /// Copies the elements of [fromOwner] to [toOwner] (fresh ids; parents
  /// and placeholder links remapped through [ids], which is extended).
  void _copyOwnerElements(
    String fromOwner,
    String toOwner,
    ElementOwnerKind kind,
    Map<String, String> ids, {
    String? Function(SlideElementRec e)? placeholderOf,
  }) {
    final elements = deck.allElementsOf(fromOwner).toList();
    for (final e in elements) {
      ids[e.id] = newId();
    }
    for (final e in elements) {
      insertElement({
        ...e.toColumns(),
        SlidesCols.id: ids[e.id],
        SlidesCols.slideId: null,
        ElementCols.layoutId: null,
        ElementCols.masterId: null,
        _Planner.ownerColumn(kind): toOwner,
        SlidesCols.parentId: e.parentId == null ? null : ids[e.parentId],
        ElementCols.placeholderOf: placeholderOf != null
            ? placeholderOf(e)
            : (ids[e.placeholderOf] ?? e.placeholderOf),
        ElementCols.matchKey: newMatchKey(),
        SlidesCols.createdAt: ctx.now,
      });
    }
  }

  String addMaster(AddMaster op) {
    final t = themeOf(op.themeId);
    final masters = deck.mastersOf(t.id);
    if (masters.length + 1 > limits.maxMastersPerTheme) {
      limit('A theme can have at most ${limits.maxMastersPerTheme} masters.');
    }
    final source = op.duplicateOf == null ? null : masterOf(op.duplicateOf!);
    final items = [for (final m in masters) (m.sortKey, m.id)];
    final at = source == null
        ? items.length
        : items.indexWhere((x) => x.$2 == source.id) + 1;
    final id = newId();
    b.insert(SlidesTables.slideMaster, {
      SlidesCols.id: id,
      SlideMasterCols.themeId: t.id,
      SlidesCols.name: _partName(
        op.masterName,
        source?.name,
        'Master ${masters.length + 1}',
      ),
      SlidesCols.sortKey: OrderKeys.at(
        items,
        at < 0 ? items.length : at,
        1,
      ).single,
      SlidesCols.backgroundJson: source?.backgroundJson,
      SlidesCols.createdAt: ctx.now,
    });
    if (source != null) {
      final ids = <String, String>{};
      _copyOwnerElements(source.id, id, ElementOwnerKind.master, ids);
      for (final l in deck.layoutsOf(source.id)) {
        final lid = newId();
        b.insert(SlidesTables.slideLayout, {
          ...l.toColumns(),
          SlidesCols.id: lid,
          SlideLayoutCols.masterId: id,
          SlidesCols.createdAt: ctx.now,
        });
        _copyOwnerElements(l.id, lid, ElementOwnerKind.layout, ids);
      }
    }
    result['masterId'] = id;
    return source == null ? 'Add master' : 'Duplicate master';
  }

  String _partName(String? given, String? source, String fallback) {
    final n = given?.trim();
    if (n != null && n.isNotEmpty) {
      if (n.length > 100) invalid('A name has at most 100 characters');
      return n;
    }
    return source == null ? fallback : '$source copy';
  }

  String addLayout(AddLayout op) {
    final m = masterOf(op.masterId);
    final layouts = deck.layoutsOf(m.id);
    if (layouts.length + 1 > limits.maxLayoutsPerMaster) {
      limit('A master can have at most ${limits.maxLayoutsPerMaster} layouts.');
    }
    final source = op.duplicateOf == null ? null : layoutOf(op.duplicateOf!);
    final items = [for (final l in layouts) (l.sortKey, l.id)];
    final i = source == null ? -1 : items.indexWhere((x) => x.$2 == source.id);
    final id = newId();
    b.insert(SlidesTables.slideLayout, {
      SlidesCols.id: id,
      SlideLayoutCols.masterId: m.id,
      SlidesCols.name: _partName(
        op.layoutName,
        source?.name,
        'Layout ${layouts.length + 1}',
      ),
      SlideLayoutCols.key: op.key,
      SlidesCols.sortKey: OrderKeys.at(
        items,
        i < 0 ? items.length : i + 1,
        1,
      ).single,
      SlidesCols.backgroundJson: source?.backgroundJson,
      SlidesCols.hideMasterElements: source?.hideMasterElements ?? false,
      SlidesCols.hidden: false,
      SlidesCols.createdAt: ctx.now,
    });
    if (source != null) {
      // Placeholders refine this master's placeholder of the same type.
      _copyOwnerElements(
        source.id,
        id,
        ElementOwnerKind.layout,
        {},
        placeholderOf: (e) {
          final type = e.placeholderType;
          if (type == null) return null;
          return ix.placeholders.masterPlaceholder(m.id, type)?.id;
        },
      );
    } else {
      final title = ix.placeholders.masterPlaceholder(
        m.id,
        SlidePlaceholderType.title,
      );
      insertElement({
        SlidesCols.id: newId(),
        ElementCols.layoutId: id,
        SlidesCols.kind: ElementKind.text.name,
        ElementCols.placeholderType: SlidePlaceholderType.title.name,
        ElementCols.placeholderOf: title?.id,
        if (title == null) ...{
          ElementCols.x: bounds.width * 0.06,
          ElementCols.y: bounds.height * 0.07,
          ElementCols.width: bounds.width * 0.88,
          ElementCols.height: bounds.height * 0.15,
        },
        ElementCols.zKey: FractionalIndex.first(),
        ElementCols.matchKey: newMatchKey(),
      });
    }
    result['layoutId'] = id;
    return source == null ? 'Add layout' : 'Duplicate layout';
  }

  String updateMasterOrLayout(UpdateMasterOrLayout op) {
    final layout = deck.layout(op.id);
    final master = layout == null ? deck.master(op.id) : null;
    if (layout == null && master == null) notFound('Master or layout', op.id);
    final allowed = layout != null
        ? const {
            SlidesCols.name,
            SlidesCols.backgroundJson,
            SlidesCols.hideMasterElements,
            SlidesCols.hidden,
            SlideLayoutCols.key,
            SlidesCols.sortKey,
          }
        : const {
            SlidesCols.name,
            SlidesCols.backgroundJson,
            SlidesCols.sortKey,
          };
    final after = <String, Object?>{};
    for (final MapEntry(:key, :value) in op.columns.entries) {
      if (!allowed.contains(key)) {
        invalid('Column $key can\'t be changed here', {'column': key});
      }
      after[key] = switch (key) {
        SlidesCols.name => _partName(value as String?, null, ''),
        SlidesCols.backgroundJson => _background(value as String?),
        SlidesCols.hideMasterElements || SlidesCols.hidden => value == true,
        // SL-28: *Move layout* / *Move master* (a key between siblings).
        SlidesCols.sortKey =>
          value is String && value.isNotEmpty
              ? value
              : invalid('A sort key is a non-empty string'),
        _ => value,
      };
    }
    b.set((layout ?? master)!, after);
    if (after.containsKey(SlidesCols.name)) {
      return layout != null ? 'Rename layout' : 'Rename master';
    }
    if (after.containsKey(SlidesCols.backgroundJson)) {
      return 'Change background';
    }
    if (after.containsKey(SlidesCols.sortKey)) {
      return layout != null ? 'Move layout' : 'Move master';
    }
    return layout != null ? 'Layout settings' : 'Master settings';
  }

  String deleteMastersOrLayouts(DeleteMastersOrLayouts op) {
    final ids = unique(op.ids);
    for (final id in ids) {
      final layout = deck.layout(id);
      if (layout != null) {
        final used = ix.themes.slidesUsingLayout(id);
        if (used > 0) {
          invalid(
            'Used by $used ${used == 1 ? 'slide' : 'slides'} — apply another '
            'layout first',
          );
        }
        _deleteLayout(layout);
        continue;
      }
      final master = masterOf(id);
      final used = ix.themes.slidesUsingMaster(id);
      if (used > 0) {
        invalid(
          'Used by $used ${used == 1 ? 'slide' : 'slides'} — apply another '
          'layout first',
        );
      }
      final siblings = deck.mastersOf(master.themeId ?? '');
      if (siblings.where((m) => !ids.contains(m.id)).isEmpty) {
        invalid("The last master of a theme can't be deleted");
      }
      _deleteMaster(master);
    }
    return 'Delete';
  }
}
