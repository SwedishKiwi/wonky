part of '../slides_planner.dart';

extension _RepairPart on _Planner {
  /// Repairs the [RepairDeck.violations] that still hold (02 §10). Every
  /// write is deterministic so concurrent repairs converge.
  String repairDeck(RepairDeck op) {
    final d = deck.deck;
    if (d == null) return DeckMaintenance.label;
    final byRule = <String, List<DeckViolation>>{};
    for (final v in op.violations) {
      (byRule[v.rule] ??= []).add(v);
    }
    List<String> ids(String rule) => ({
      for (final v in byRule[rule] ?? const <DeckViolation>[]) v.rowId,
    }.toList()..sort());

    // Themes first: everything else resolves against them.
    if (byRule.containsKey(DeckMaintenance.noTheme)) _repairNoTheme(d);
    if (byRule.containsKey(DeckMaintenance.missingDeckTheme)) {
      final cur = b.rec(SlidesTables.deck, d.id)! as DeckRec;
      final id = cur.themeId;
      if (id == null || !b.exists(SlidesTables.deckTheme, id)) {
        final themes = [for (final t in b.records(SlidesTables.deckTheme)) t.id]
          ..sort();
        if (themes.isNotEmpty) b.set(cur, {DeckCols.themeId: themes.first});
      }
    }

    // Orphan slides → end of the top level in (sortKey, id) order.
    final orphans =
        [
          for (final id in ids(DeckMaintenance.orphanSlide))
            if (deck.slide(id) case final s?)
              if (s.groupId != null &&
                  !b.exists(SlidesTables.slideGroup, s.groupId!))
                s,
        ]..sort(
          (a, c) => FractionalIndex.compare(a.sortKey, a.id, c.sortKey, c.id),
        );
    if (orphans.isNotEmpty) {
      final top = topLevelItems();
      final keys = OrderKeys.at(top, top.length, orphans.length);
      for (final (i, s) in orphans.indexed) {
        b.set(
          s,
          {SlideCols.groupId: null, SlidesCols.sortKey: keys[i]},
          together: const {SlideCols.groupId, SlidesCols.sortKey},
        );
      }
    }

    // Element trees: re-parent to the top level (the render rule already
    // draws these elements top-level with their stored frame).
    for (final rule in const [
      DeckMaintenance.groupCycle,
      DeckMaintenance.foreignParent,
      DeckMaintenance.missingParent,
    ]) {
      for (final id in ids(rule)) {
        final e = deck.element(id);
        if (e == null || e.ownerId == null) continue;
        final tree = ix.tree(e.ownerId!);
        final holds = switch (rule) {
          DeckMaintenance.groupCycle => tree.cycleBreakers.contains(id),
          DeckMaintenance.foreignParent => tree.foreignParent.contains(id),
          _ => tree.missingParent.contains(id),
        };
        if (!holds) continue;
        b.set(e, {SlidesCols.parentId: null});
      }
    }
    for (final id in ids(DeckMaintenance.emptyGroup)) {
      final e = deck.element(id);
      if (e == null || e.kind != ElementKind.group || e.ownerId == null) {
        continue;
      }
      final children = ix.tree(e.ownerId!).childrenOf(id);
      if (children.any((c) => b.exists(SlidesTables.slideElement, c.id))) {
        continue;
      }
      deleteElementTree(e);
    }

    // Placeholders.
    for (final id in ids(DeckMaintenance.danglingPlaceholder)) {
      final e = deck.element(id);
      if (e == null || e.slideId == null || !ix.placeholders.isDangling(e)) {
        continue;
      }
      final slide = deck.slide(e.slideId!);
      final layout = slide == null ? null : ix.themes.effectiveLayout(slide);
      final type = e.placeholderType;
      String? target;
      if (layout != null && type != null) {
        final taken = <String?>{
          for (final i in ix.placeholders.instancesOf(e.slideId!))
            if (i.id != e.id)
              (b.rec(SlidesTables.slideElement, i.id) as SlideElementRec?)
                  ?.placeholderOf,
        };
        for (final p in ix.placeholders.placeholdersOf(layout.id)) {
          if (p.placeholderType == type && !taken.contains(p.id)) {
            target = p.id;
            break;
          }
        }
      }
      materialize(e, placeholderOf: target);
    }
    for (final id in ids(DeckMaintenance.dupPlaceholder)) {
      final e = deck.element(id);
      if (e == null || e.slideId == null) continue;
      if (DeckMaintenance.isKept(e, ix.placeholders.instancesOf(e.slideId!))) {
        continue;
      }
      materialize(e, placeholderOf: null);
    }

    // Tables, code, builds.
    for (final id in ids(DeckMaintenance.mergeOverlap)) {
      final c =
          deck.record(SlidesTables.slideTableCell, id) as SlideTableCellRec?;
      final el = c?.elementId;
      if (c == null || el == null) continue;
      if (!ix.table(el).overlapping.any((m) => m.origin.id == id)) continue;
      writeCell(
        el,
        c.rowId!,
        c.columnId!,
        {TableCellCols.rowSpan: null, TableCellCols.colSpan: null},
        together: const {TableCellCols.rowSpan, TableCellCols.colSpan},
      );
    }
    for (final id in ids(DeckMaintenance.codeWithoutState)) {
      final e = deck.element(id);
      if (e == null || e.kind != ElementKind.code) continue;
      if (deck.codeStatesOf(id).isNotEmpty) continue;
      b.insert(SlidesTables.codeState, {
        SlidesCols.id: DeckMaintenance.repairCodeStateId(id),
        SlidesCols.elementId: id,
        SlidesCols.sortKey: FractionalIndex.first(),
        CodeStateCols.code: '',
        SlidesCols.createdAt: ctx.now,
      });
    }
    for (final id in ids(DeckMaintenance.orphanBuild)) {
      final bd = deck.build(id);
      if (bd == null) continue;
      final el = bd.elementId == null ? null : deck.element(bd.elementId!);
      final ok =
          el != null &&
          bd.slideId != null &&
          deck.slide(bd.slideId!) != null &&
          el.slideId == bd.slideId;
      if (!ok) b.remove(bd);
    }
    return DeckMaintenance.label;
  }

  /// Copies the built-in default theme (deterministic ids) and makes it the
  /// deck's theme when the current one has no layouts (02 §10).
  void _repairNoTheme(DeckRec d) {
    final hasLayout = deck.themes.any(
      (t) => ix.themes.layoutsOfTheme(t.id).isNotEmpty,
    );
    if (hasLayout) return;
    final def = BuiltInThemes.defaultTheme;
    final pkg = BuiltInThemes.package(
      def.key,
      size: SlideSize(d.sizePreset, d.width, d.height),
    )!;
    final (rows, copy) = ThemeCopy.packageRows(
      pkg,
      deckId: deck.deckId,
      sourceKey: SlidesIds.builtinThemeSourceKey(def.key, def.version),
      now: ctx.now,
      sortKey: _repairThemeKey(),
    );
    for (final (t, c) in rows) {
      final id = c[SlidesCols.id]! as String;
      if (b.exists(t, id)) continue;
      if (t == SlidesTables.slideElement) {
        insertElement(c);
      } else {
        b.insert(t, c);
      }
    }
    b.set(d, {DeckCols.themeId: copy.themeId});
  }

  /// A deterministic theme key after the existing ones.
  String _repairThemeKey() => OrderKeys.last(
    OrderKeys.sorted([for (final t in deck.themes) (t.sortKey, t.id)]),
  );
}
