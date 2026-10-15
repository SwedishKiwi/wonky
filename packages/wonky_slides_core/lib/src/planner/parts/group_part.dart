part of '../slides_planner.dart';

/// Palette tokens of slide groups (04 §5.4).
const _groupColors = {
  'gray',
  'red',
  'orange',
  'amber',
  'green',
  'teal',
  'blue',
  'violet',
  'pink',
};

extension _GroupPart on _Planner {
  String _groupTitle(String? raw) {
    if (raw == null) return 'Group ${deck.count(SlidesTables.slideGroup) + 1}';
    final t = raw.trim();
    if (t.isEmpty || t.length > 100) {
      invalid('A group title has 1–100 characters');
    }
    return t;
  }

  String? _groupColor(String? c) {
    if (c == null) return null;
    if (!_groupColors.contains(c)) invalid('Unknown group color $c');
    return c;
  }

  String createGroup(CreateGroup op) {
    final ids = unique(op.slideIds).toSet();
    for (final id in ids) {
      slideOf(id);
    }
    final ordered = [
      for (final e in ix.order.entries)
        if (ids.contains(e.id)) e,
    ];
    if (ordered.isEmpty) invalid('Select at least one slide');
    checkGroupLimit(1);
    final groupId = op.groupId ?? newId();
    if (deck.group(groupId) != null) invalid('Group $groupId already exists');
    // The group takes the position of the first slide (its group's
    // position when that slide is grouped).
    final first = ordered.first;
    final anchor = first.groupId ?? first.id;
    final items = topLevelItems();
    final i = items.indexWhere((t) => t.$2 == anchor);
    final key = OrderKeys.at(
      items,
      i < 0 ? items.length : i,
      1,
      exclude: {...ids},
    ).single;
    b.insert(SlidesTables.slideGroup, {
      SlidesCols.id: groupId,
      SlidesCols.deckId: deck.deckId,
      SlidesCols.title: _groupTitle(op.title),
      SlidesCols.sortKey: key,
      SlidesCols.parentId: null,
      SlideGroupCols.color: _groupColor(op.color),
      SlidesCols.skipped: false,
      SlidesCols.createdAt: ctx.now,
    });
    final keys = OrderKeys.between(null, null, ordered.length);
    for (final (i, e) in ordered.indexed) {
      b.set(
        e.slide,
        {SlideCols.groupId: groupId, SlidesCols.sortKey: keys[i]},
        together: const {SlideCols.groupId, SlidesCols.sortKey},
      );
    }
    result['groupId'] = groupId;
    return 'Group slides';
  }

  /// Moves the slides of [g] into the top level at [g]'s position.
  void _dissolve(SlideGroupRec g) {
    final slides = deck.slidesInGroup(g.id);
    final items = topLevelItems();
    final i = items.indexWhere((t) => t.$2 == g.id);
    final keys = OrderKeys.at(
      items,
      i < 0 ? items.length : i,
      slides.length,
      exclude: {g.id},
    );
    for (final (k, s) in slides.indexed) {
      b.set(
        s,
        {SlideCols.groupId: null, SlidesCols.sortKey: keys[k]},
        together: const {SlideCols.groupId, SlidesCols.sortKey},
      );
    }
  }

  String ungroup(Ungroup op) {
    final g = groupOf(op.groupId);
    _dissolve(g);
    b.remove(g);
    return 'Ungroup slides';
  }

  String moveGroups(MoveGroups op) {
    final ids = unique(op.groupIds);
    final groups = [for (final id in ids) groupOf(id)]
      ..sort(
        (a, c) => FractionalIndex.compare(a.sortKey, a.id, c.sortKey, c.id),
      );
    final items = topLevelItems();
    final i = OrderKeys.indexFor(
      items,
      beforeId: op.beforeId,
      afterId: op.afterId,
    );
    if (i < 0) notFound('Slide or group', (op.afterId ?? op.beforeId)!);
    final keys = OrderKeys.at(items, i, groups.length, exclude: {...ids});
    for (final (k, g) in groups.indexed) {
      b.set(
        g,
        {SlidesCols.parentId: null, SlidesCols.sortKey: keys[k]},
        together: const {SlidesCols.parentId, SlidesCols.sortKey},
      );
    }
    return plural(groups.length, 'Move group', 'Move groups');
  }

  String setGroupProps(SetGroupProps op) {
    final ids = unique(op.groupIds);
    for (final id in ids) {
      b.set(groupOf(id), {
        if (op.title != null) SlidesCols.title: _groupTitle(op.title),
        if (op.color != null)
          SlideGroupCols.color: _groupColor(op.color!.value),
        SlidesCols.skipped: ?op.skipped,
      });
    }
    if (op.title != null) return 'Rename group';
    if (op.skipped != null) {
      return op.skipped! ? 'Skip group' : "Don't skip group";
    }
    return 'Group settings';
  }

  String deleteGroups(DeleteGroups op) {
    final ids = unique(op.groupIds);
    for (final id in ids) {
      final g = groupOf(id);
      if (op.withSlides) {
        for (final s in deck.slidesInGroup(id)) {
          deleteSlide(s);
        }
      } else {
        _dissolve(g);
      }
      b.remove(g);
    }
    return plural(ids.length, 'Delete group', 'Delete groups');
  }

  String duplicateGroups(DuplicateGroups op) {
    final ids = unique(op.groupIds);
    final groups = [for (final id in ids) groupOf(id)];
    checkGroupLimit(groups.length);
    checkSlideLimit(
      groups.fold(0, (n, g) => n + deck.slidesInGroup(g.id).length),
    );
    final out = <String>[];
    for (final g in groups) {
      final items = topLevelItems();
      final i = items.indexWhere((t) => t.$2 == g.id);
      final key = OrderKeys.at(items, i + 1, 1).single;
      final copy = newId();
      b.insert(SlidesTables.slideGroup, {
        ...g.toColumns(),
        SlidesCols.id: copy,
        SlidesCols.sortKey: key,
        SlidesCols.createdAt: ctx.now,
      });
      for (final s in deck.slidesInGroup(g.id)) {
        cloneSlide(s, groupId: copy, sortKey: s.sortKey, keepMatchKeys: true);
      }
      out.add(copy);
    }
    result['groupIds'] = out;
    return plural(out.length, 'Duplicate group', 'Duplicate groups');
  }
}
