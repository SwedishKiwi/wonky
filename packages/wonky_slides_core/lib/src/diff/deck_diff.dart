import 'dart:convert';

import '../model/api/deck_model.dart';
import '../model/api/records.dart';
import '../model/index/deck_indexes.dart';
import '../schema/slides_schema.dart';

/// How a row differs between two versions.
enum DiffStatus {
  /// Only in the newer version.
  added,

  /// Only in the older version.
  removed,

  /// In both, with different columns (or dependent rows).
  changed,
}

/// What changed on an element (Slides 09 §4.3).
enum ElementChangeKind {
  /// Its text body, a table cell's text or a code state's code.
  text,

  /// Position, size, rotation, flips.
  frame,

  /// Text style, fill, stroke, effects, opacity, table cell styling.
  style,

  /// The kind payload: data, links, alt text, name, table axes, other code
  /// state columns, the linked chart.
  data,

  /// Stacking, reading order or grouping (`zKey`, `readingKey`,
  /// `parentId`).
  order,

  /// Hidden or locked.
  visibility,

  /// Its builds (animations).
  animation,
}

/// What changed on a slide's own row (Slides 09 §4.3).
enum SlideOwnChange { background, layout, transition, notes, timings, masters }

/// One changed element of a slide.
final class ElementChange {
  /// Creates a change.
  ElementChange({
    required this.id,
    required this.slideId,
    required this.status,
    required this.topId,
    this.before,
    this.after,
    Set<ElementChangeKind>? kinds,
  }) : kinds = kinds ?? {};

  /// The element id.
  final String id;

  /// The slide it is on (the newer version's slide for [DiffStatus.added]
  /// and [DiffStatus.changed], the older one's for removed elements).
  final String slideId;
  final DiffStatus status;

  /// The top-level ancestor (the element itself at the top level): the
  /// element the canvas outlines.
  final String topId;

  /// The row in the older version (null when added).
  final SlideElementRec? before;

  /// The row in the newer version (null when removed).
  final SlideElementRec? after;

  /// What changed ([DiffStatus.changed]; children rolled up add theirs).
  final Set<ElementChangeKind> kinds;

  /// The newer row, else the older one.
  SlideElementRec get record => (after ?? before)!;

  @override
  String toString() => 'ElementChange($id, ${status.name}, $kinds)';
}

/// Builds of a slide added, removed or changed.
final class BuildChanges {
  /// Creates the counts.
  const BuildChanges({this.added = 0, this.removed = 0, this.changed = 0});

  final int added;
  final int removed;
  final int changed;

  /// Whether nothing changed.
  bool get isEmpty => added == 0 && removed == 0 && changed == 0;
}

/// One slide that differs between two versions.
final class SlideChange {
  /// Creates a change.
  SlideChange({
    required this.slideId,
    required this.status,
    this.before,
    this.after,
    this.moved = false,
    this.skipToggled = false,
    Set<SlideOwnChange>? own,
    List<ElementChange>? elements,
    this.builds = const BuildChanges(),
  }) : own = own ?? {},
       elements = elements ?? [];

  final String slideId;

  /// [DiffStatus.changed] also covers "only moved" and "only skip toggled".
  final DiffStatus status;

  /// The row in the older version (null when added).
  final SlideRec? before;

  /// The row in the newer version (null when removed).
  final SlideRec? after;

  /// `sortKey` or `groupId` changed (reordered or regrouped).
  final bool moved;

  /// `skipped` changed.
  final bool skipToggled;

  /// The slide row's own columns that changed.
  final Set<SlideOwnChange> own;

  /// Changed elements in reading order (top to bottom, left to right).
  final List<ElementChange> elements;

  /// Build changes.
  final BuildChanges builds;

  /// Whether the slide's content changed (own columns, elements, builds) —
  /// not only its position or skip.
  bool get contentChanged =>
      own.isNotEmpty || elements.isNotEmpty || !builds.isEmpty;

  @override
  String toString() =>
      'SlideChange($slideId, ${status.name}'
      '${moved ? ', moved' : ''}${skipToggled ? ', skip' : ''}, $own, '
      '$elements)';
}

/// What changed on a slide group.
enum GroupChangeKind { renamed, recolored, moved, skipToggled }

/// One slide group that differs between two versions.
final class GroupChange {
  /// Creates a change.
  GroupChange({
    required this.groupId,
    required this.status,
    this.before,
    this.after,
    Set<GroupChangeKind>? kinds,
  }) : kinds = kinds ?? {};

  final String groupId;
  final DiffStatus status;
  final SlideGroupRec? before;
  final SlideGroupRec? after;
  final Set<GroupChangeKind> kinds;
}

/// A slide of the older version that is gone: where to show its ghost row
/// (after [afterSlideId] of the newer order; null = at the start).
final class RemovedSlide {
  /// Creates the entry.
  const RemovedSlide(this.change, this.afterSlideId);

  final SlideChange change;
  final String? afterSlideId;
}

/// One stop of *Next change* / *Previous change* (09 §4.2 step 5): a slide,
/// or an element on it.
typedef DeckChangeStop = ({String slideId, String? elementId});

/// The difference between two versions of a deck (Slides 09 §4.3): rows
/// matched by id per table, column by column; element changes classified
/// ([ElementChangeKind]) with children of changed groups rolled up into
/// the group; slides added, removed, moved, changed or skip-toggled;
/// groups; theme rows (themes, masters, layouts and their elements) and
/// the deck row. Pure Dart; computed on the client (decks are small).
final class DeckDiff {
  DeckDiff._({
    required this.slides,
    required this.removedSlides,
    required this.groups,
    required this.themeChanged,
    required this.deckChanged,
    required this.stops,
  });

  /// Changed slides of the newer version by id (added, moved, changed).
  final Map<String, SlideChange> slides;

  /// Slides of the older version that are gone, in their older order.
  final List<RemovedSlide> removedSlides;

  /// Changed groups by id (the newer version's and removed ones).
  final Map<String, GroupChange> groups;

  /// Whether themes, masters, layouts or their elements changed.
  final bool themeChanged;

  /// The deck row's changed columns (title, size, numbering …).
  final Set<String> deckChanged;

  /// Changed slides and elements in presentation order (navigation).
  final List<DeckChangeStop> stops;

  /// Whether nothing differs.
  bool get isEmpty =>
      slides.isEmpty &&
      removedSlides.isEmpty &&
      groups.isEmpty &&
      !themeChanged &&
      deckChanged.isEmpty;

  /// Number of slides added, changed or moved plus removed ones.
  int get changedSlideCount => slides.length + removedSlides.length;

  /// The change of [slideId] (newer version), or null.
  SlideChange? slide(String slideId) => slides[slideId];

  static const _frame = {
    ElementCols.x,
    ElementCols.y,
    ElementCols.width,
    ElementCols.height,
    ElementCols.rotation,
    ElementCols.flipH,
    ElementCols.flipV,
  };
  static const _style = {
    ElementCols.textStyleJson,
    ElementCols.fillJson,
    ElementCols.strokeJson,
    ElementCols.effectsJson,
    ElementCols.opacity,
  };
  static const _order = {
    ElementCols.zKey,
    ElementCols.readingKey,
    SlidesCols.parentId,
  };
  static const _visibility = {SlidesCols.hidden, ElementCols.locked};
  static const _ignored = {SlidesCols.id, SlidesCols.createdAt};

  /// The kinds of the columns that differ between two element rows.
  static Set<ElementChangeKind> elementKinds(
    SlideElementRec before,
    SlideElementRec after,
  ) {
    final kinds = <ElementChangeKind>{};
    for (final col in _changedColumns(before.columns, after.columns)) {
      if (col == SlidesCols.text) {
        kinds.add(ElementChangeKind.text);
      } else if (_frame.contains(col)) {
        kinds.add(ElementChangeKind.frame);
      } else if (_style.contains(col)) {
        kinds.add(ElementChangeKind.style);
      } else if (_order.contains(col)) {
        kinds.add(ElementChangeKind.order);
      } else if (_visibility.contains(col)) {
        kinds.add(ElementChangeKind.visibility);
      } else if (!ElementCols.owners.contains(col)) {
        kinds.add(ElementChangeKind.data);
      }
    }
    return kinds;
  }

  static Set<String> _changedColumns(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) => {
    for (final k in {...a.keys, ...b.keys})
      if (!_ignored.contains(k) && !sameValue(a[k], b[k])) k,
  };

  /// Whether two column values are equal (numbers by value, dates by
  /// instant, JSON text by content).
  static bool sameValue(Object? a, Object? b) {
    if (a == b) return true;
    if (a is num && b is num) return a == b;
    if (a is DateTime || b is DateTime) {
      DateTime? d(Object? v) => v is DateTime
          ? v.toUtc()
          : v is String
          ? DateTime.tryParse(v)?.toUtc()
          : null;
      final x = d(a), y = d(b);
      return x != null && x == y;
    }
    if (a is bool || b is bool) {
      bool? f(Object? v) => v is bool
          ? v
          : v == 1 || v == 'true'
          ? true
          : v == 0 || v == 'false'
          ? false
          : null;
      return f(a) == f(b) && f(a) != null;
    }
    if (a is String && b is String) {
      final x = a.trimLeft(), y = b.trimLeft();
      if ((x.startsWith('{') || x.startsWith('[')) &&
          (y.startsWith('{') || y.startsWith('['))) {
        try {
          return jsonEncode(jsonDecode(a)) == jsonEncode(jsonDecode(b));
        } on FormatException {
          return false;
        }
      }
    }
    return false;
  }

  /// The diff from [before] (null = empty: everything is new) to [after].
  static DeckDiff compute(DeckModel? before, DeckModel after) {
    final old = before ?? DeckModel(deckId: after.deckId);
    final slides = <String, SlideChange>{};

    // Elements of slides, with dependent rows folded in.
    final rawElements = <String, ElementChange>{};
    void element(SlideElementRec? b, SlideElementRec? a) {
      final rec = (a ?? b)!;
      final slideId = rec.slideId;
      if (slideId == null) return; // layout/master elements: theme
      if (b != null && a != null && b.slideId != a.slideId) {
        // Moved to another slide: removed there, added here.
        final from = b.slideId;
        if (from != null) {
          rawElements['${rec.id}|moved'] = ElementChange(
            id: rec.id,
            slideId: from,
            status: DiffStatus.removed,
            topId: rec.id,
            before: b,
          );
        }
        element(null, a);
        return;
      }
      if (b == null) {
        rawElements[rec.id] = ElementChange(
          id: rec.id,
          slideId: slideId,
          status: DiffStatus.added,
          topId: rec.id,
          after: a,
        );
      } else if (a == null) {
        rawElements[rec.id] = ElementChange(
          id: rec.id,
          slideId: slideId,
          status: DiffStatus.removed,
          topId: rec.id,
          before: b,
        );
      } else {
        final kinds = elementKinds(b, a);
        if (kinds.isEmpty) return;
        rawElements[rec.id] = ElementChange(
          id: rec.id,
          slideId: slideId,
          status: DiffStatus.changed,
          topId: rec.id,
          before: b,
          after: a,
          kinds: kinds,
        );
      }
    }

    var themeChanged = false;
    for (final (b, a) in _pairs<SlideElementRec>(
      old,
      after,
      SlidesTables.slideElement,
    )) {
      if ((a ?? b)!.slideId == null) {
        if (b == null || a == null || elementKinds(b, a).isNotEmpty) {
          themeChanged = true;
        }
        continue;
      }
      element(b, a);
    }

    // Dependent rows (tables, code states, chart links): the element
    // changed when it exists in both versions.
    void dependent(String table, ElementChangeKind Function(Set<String>) kind) {
      for (final (b, a) in _pairs<SlidesRecord>(old, after, table)) {
        final cols = b == null || a == null
            ? null
            : _changedColumns(b.columns, a.columns);
        if (cols != null && cols.isEmpty) continue;
        final elementId = '${(a ?? b)![SlidesCols.elementId]}';
        final ea = after.element(elementId);
        final eb = old.element(elementId);
        if (ea == null || eb == null) continue; // added/removed element
        final slideId = ea.slideId;
        if (slideId == null) {
          themeChanged = true;
          continue;
        }
        final k = kind(cols ?? const {});
        final existing = rawElements[elementId];
        if (existing != null) {
          existing.kinds.add(k);
        } else if (eb.slideId == slideId) {
          rawElements[elementId] = ElementChange(
            id: elementId,
            slideId: slideId,
            status: DiffStatus.changed,
            topId: elementId,
            before: eb,
            after: ea,
            kinds: {k},
          );
        }
      }
    }

    dependent(
      SlidesTables.slideTableCell,
      (cols) => cols.isEmpty
          ? ElementChangeKind.data
          : cols.contains(SlidesCols.text)
          ? ElementChangeKind.text
          : ElementChangeKind.style,
    );
    dependent(SlidesTables.slideTableAxis, (_) => ElementChangeKind.data);
    dependent(
      SlidesTables.codeState,
      (cols) => cols.contains(CodeStateCols.code)
          ? ElementChangeKind.text
          : ElementChangeKind.data,
    );
    dependent(SlidesTables.chartLink, (_) => ElementChangeKind.data);

    // Builds: per slide counts; the element gets `animation`.
    final builds = <String, (int, int, int)>{};
    for (final (b, a) in _pairs<SlideBuildRec>(
      old,
      after,
      SlidesTables.slideBuild,
    )) {
      final cols = b == null || a == null
          ? null
          : _changedColumns(b.columns, a.columns);
      if (cols != null && cols.isEmpty) continue;
      final rec = (a ?? b)!;
      final slideId = rec.slideId;
      if (slideId == null) continue;
      final c = builds[slideId] ?? (0, 0, 0);
      builds[slideId] = b == null
          ? (c.$1 + 1, c.$2, c.$3)
          : a == null
          ? (c.$1, c.$2 + 1, c.$3)
          : (c.$1, c.$2, c.$3 + 1);
      final elementId = rec.elementId;
      if (elementId == null) continue;
      final existing = rawElements[elementId];
      if (existing != null) {
        if (existing.status == DiffStatus.changed) {
          existing.kinds.add(ElementChangeKind.animation);
        }
        continue;
      }
      final ea = after.element(elementId);
      final eb = old.element(elementId);
      if (ea == null || eb == null || ea.slideId != eb.slideId) continue;
      rawElements[elementId] = ElementChange(
        id: elementId,
        slideId: ea.slideId!,
        status: DiffStatus.changed,
        topId: elementId,
        before: eb,
        after: ea,
        kinds: {ElementChangeKind.animation},
      );
    }

    // Roll children up (09 §4.3): a child whose group itself changed (or
    // was added/removed) is folded into the group; other children keep
    // their entry and outline their top-level ancestor.
    String topOf(ElementChange c) {
      final model = c.status == DiffStatus.removed ? old : after;
      var id = c.id;
      final seen = <String>{};
      while (seen.add(id)) {
        final parent = model.element(id)?.parentId;
        if (parent == null || model.element(parent) == null) break;
        id = parent;
      }
      return id;
    }

    final perSlide = <String, List<ElementChange>>{};
    for (final c in rawElements.values) {
      final top = topOf(c);
      final model = c.status == DiffStatus.removed ? old : after;
      // The nearest ancestor that has its own change absorbs the child.
      ElementChange? owner;
      var parent = model.element(c.id)?.parentId;
      final seen = <String>{};
      while (parent != null && seen.add(parent)) {
        final p = rawElements[parent];
        if (p != null) {
          owner = p;
          break;
        }
        parent = model.element(parent)?.parentId;
      }
      if (owner != null) {
        if (owner.status == DiffStatus.changed) {
          owner.kinds
            ..addAll(c.kinds)
            ..addAll(switch (c.status) {
              DiffStatus.changed => const <ElementChangeKind>{},
              _ => const {ElementChangeKind.data},
            });
        }
        continue;
      }
      final entry = top == c.id
          ? c
          : ElementChange(
              id: c.id,
              slideId: c.slideId,
              status: c.status,
              topId: top,
              before: c.before,
              after: c.after,
              kinds: c.kinds,
            );
      (perSlide[c.slideId] ??= []).add(entry);
    }

    // Slides.
    final oldOrder = old.indexes.order;
    for (final (b, a) in _pairs<SlideRec>(old, after, SlidesTables.slide)) {
      final id = (a ?? b)!.id;
      if (b == null) {
        slides[id] = SlideChange(
          slideId: id,
          status: DiffStatus.added,
          after: a,
          elements: perSlide[id],
        );
        continue;
      }
      if (a == null) continue; // removed: below, in the older order
      final cols = _changedColumns(b.columns, a.columns);
      final own = <SlideOwnChange>{
        for (final c in cols)
          ?switch (c) {
            SlidesCols.backgroundJson => SlideOwnChange.background,
            SlideCols.layoutId => SlideOwnChange.layout,
            SlidesCols.transitionJson => SlideOwnChange.transition,
            SlideCols.notes => SlideOwnChange.notes,
            SlideCols.timingsJson => SlideOwnChange.timings,
            SlidesCols.hideMasterElements => SlideOwnChange.masters,
            _ => null,
          },
      };
      final moved =
          cols.contains(SlidesCols.sortKey) || cols.contains(SlideCols.groupId);
      final skip = cols.contains(SlidesCols.skipped);
      final els = perSlide[id] ?? const <ElementChange>[];
      final bc = builds[id];
      final buildChanges = bc == null
          ? const BuildChanges()
          : BuildChanges(added: bc.$1, removed: bc.$2, changed: bc.$3);
      if (own.isEmpty && !moved && !skip && els.isEmpty && bc == null) {
        continue;
      }
      slides[id] = SlideChange(
        slideId: id,
        status: DiffStatus.changed,
        before: b,
        after: a,
        moved: moved,
        skipToggled: skip,
        own: own,
        elements: List.of(els),
        builds: buildChanges,
      );
    }
    for (final c in slides.values) {
      c.elements.sort(_readingOrder);
    }

    // Removed slides, placed after the nearest surviving predecessor.
    final removed = <RemovedSlide>[];
    String? lastSurvivor;
    for (final e in oldOrder.entries) {
      if (after.slide(e.id) != null) {
        lastSurvivor = e.id;
        continue;
      }
      removed.add(
        RemovedSlide(
          SlideChange(
            slideId: e.id,
            status: DiffStatus.removed,
            before: e.slide,
            elements: perSlide[e.id],
          ),
          lastSurvivor,
        ),
      );
    }

    // Groups.
    final groups = <String, GroupChange>{};
    for (final (b, a) in _pairs<SlideGroupRec>(
      old,
      after,
      SlidesTables.slideGroup,
    )) {
      final id = (a ?? b)!.id;
      if (b == null || a == null) {
        groups[id] = GroupChange(
          groupId: id,
          status: b == null ? DiffStatus.added : DiffStatus.removed,
          before: b,
          after: a,
        );
        continue;
      }
      final cols = _changedColumns(b.columns, a.columns);
      final kinds = <GroupChangeKind>{
        if (cols.contains(SlidesCols.title)) GroupChangeKind.renamed,
        if (cols.contains(SlideGroupCols.color)) GroupChangeKind.recolored,
        if (cols.contains(SlidesCols.sortKey) ||
            cols.contains(SlidesCols.parentId))
          GroupChangeKind.moved,
        if (cols.contains(SlidesCols.skipped)) GroupChangeKind.skipToggled,
      };
      if (kinds.isEmpty) continue;
      groups[id] = GroupChange(
        groupId: id,
        status: DiffStatus.changed,
        before: b,
        after: a,
        kinds: kinds,
      );
    }

    // Theme rows.
    for (final t in const [
      SlidesTables.deckTheme,
      SlidesTables.slideMaster,
      SlidesTables.slideLayout,
    ]) {
      if (themeChanged) break;
      for (final (b, a) in _pairs<SlidesRecord>(old, after, t)) {
        if (b == null ||
            a == null ||
            _changedColumns(b.columns, a.columns).isNotEmpty) {
          themeChanged = true;
          break;
        }
      }
    }

    final deckBefore = old.deck;
    final deckAfter = after.deck;
    final deckChanged = deckAfter == null
        ? const <String>{}
        : deckBefore == null
        ? const <String>{}
        : _changedColumns(deckBefore.columns, deckAfter.columns);

    // Navigation stops in presentation order.
    final stops = <DeckChangeStop>[];
    for (final e in after.indexes.order.entries) {
      final c = slides[e.id];
      if (c == null) continue;
      stops.add((slideId: e.id, elementId: null));
      for (final el in c.elements) {
        if (el.status == DiffStatus.removed) continue;
        stops.add((slideId: e.id, elementId: el.id));
      }
    }

    return DeckDiff._(
      slides: slides,
      removedSlides: removed,
      groups: groups,
      themeChanged: themeChanged,
      deckChanged: deckChanged,
      stops: stops,
    );
  }

  /// Top to bottom, then left to right (removed elements by their older
  /// frame), ties by id.
  static int _readingOrder(ElementChange a, ElementChange b) {
    final ra = a.record, rb = b.record;
    final y = (ra.y ?? 0).compareTo(rb.y ?? 0);
    if (y != 0) return y;
    final x = (ra.x ?? 0).compareTo(rb.x ?? 0);
    return x != 0 ? x : a.id.compareTo(b.id);
  }

  /// The rows of [table] matched by id: (older, newer), one side null when
  /// the row exists in only one version.
  static Iterable<(T?, T?)> _pairs<T extends SlidesRecord>(
    DeckModel before,
    DeckModel after,
    String table,
  ) sync* {
    for (final a in after.records(table)) {
      yield (before.record(table, a.id) as T?, a as T);
    }
    for (final b in before.records(table)) {
      if (after.record(table, b.id) == null) yield (b as T, null);
    }
  }
}
