import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';

/// The kinds of navigator rows (Slides 04 §5.2–§5.3, §5.11).
enum NavRowKind {
  /// A group header (chevron, color, title, count).
  group,

  /// A slide (number, thumbnail, badges).
  slide,

  /// The "Drop slides here" zone of an empty, expanded group.
  emptyGroup,
}

/// One row of the slide navigator and one cell kind of the grid view: the
/// two-level presentation order (02 §3.4) with collapsed groups folded.
final class NavRow {
  const NavRow._(
    this.kind,
    this.id, {
    this.groupId,
    this.range,
    this.entry,
    this.collapsed = false,
    this.lastInGroup = false,
  });

  final NavRowKind kind;

  /// The group id (headers, empty zones) or the slide id.
  final String id;

  /// The group the row belongs to (a header's own id; null for top-level
  /// slides).
  final String? groupId;

  /// The group's range (headers and empty zones).
  final SlideGroupRange? range;

  /// The slide's entry (slide rows).
  final SlideOrderEntry? entry;

  /// Whether the group is collapsed (headers).
  final bool collapsed;

  /// Whether this is the last row inside an expanded group (its last slide
  /// or its empty zone): the gap below it is decided by the pointer's x
  /// (04 §5.10).
  final bool lastInGroup;

  /// A stable key (`group:<id>`, `slide:<id>`, `emptyGroup:<id>`).
  String get key => '${kind.name}:$id';

  bool get isGroup => kind == NavRowKind.group;
  bool get isSlide => kind == NavRowKind.slide;

  /// Whether the row sits inside a group (indented).
  bool get inGroup => kind != NavRowKind.group && groupId != null;

  @override
  String toString() => key;
}

/// Builds the rows of [order] with the groups of [collapsed] folded:
/// top-level items in key order (a group's header, then its slides or its
/// empty zone when expanded), then orphan slides (02 §10).
List<NavRow> buildNavRows(SlideOrder order, Set<String> collapsed) {
  final rows = <NavRow>[];
  final ranges = {for (final r in order.groups) r.group.id: r};
  for (final item in order.topLevel) {
    if (!item.isGroup) {
      final e = order.entry(item.id);
      if (e != null) rows.add(NavRow._(NavRowKind.slide, e.id, entry: e));
      continue;
    }
    final r = ranges[item.id];
    if (r == null) continue;
    final folded = collapsed.contains(r.group.id);
    rows.add(
      NavRow._(
        NavRowKind.group,
        r.group.id,
        groupId: r.group.id,
        range: r,
        collapsed: folded,
      ),
    );
    if (folded) continue;
    if (r.length == 0) {
      rows.add(
        NavRow._(
          NavRowKind.emptyGroup,
          r.group.id,
          groupId: r.group.id,
          range: r,
          lastInGroup: true,
        ),
      );
      continue;
    }
    for (var i = r.start; i < r.end; i++) {
      final e = order.entries[i];
      rows.add(
        NavRow._(
          NavRowKind.slide,
          e.id,
          groupId: r.group.id,
          entry: e,
          lastInGroup: i == r.end - 1,
        ),
      );
    }
  }
  for (final e in order.entries) {
    if (e.orphan) rows.add(NavRow._(NavRowKind.slide, e.id, entry: e));
  }
  return rows;
}

/// The navigator selection as commands read it (04 §5.5): selected groups
/// (with all their slides) and the loose slides outside them, both in
/// presentation order.
final class NavSelection {
  const NavSelection({this.groupIds = const [], this.slideIds = const []});

  /// Reads the editor's selection sets against [order].
  factory NavSelection.of(
    SlideOrder order, {
    Iterable<String> slides = const [],
    Iterable<String> groups = const [],
  }) {
    final g = groups.toSet();
    final s = slides.toSet();
    return NavSelection(
      groupIds: [
        for (final r in order.groups)
          if (g.contains(r.group.id)) r.group.id,
      ],
      slideIds: [
        for (final e in order.entries)
          if (s.contains(e.id) && !g.contains(e.groupId)) e.id,
      ],
    );
  }

  final List<String> groupIds;

  /// Selected slides outside the selected groups.
  final List<String> slideIds;

  bool get isEmpty => groupIds.isEmpty && slideIds.isEmpty;
  bool get hasGroups => groupIds.isNotEmpty;

  /// Every selected slide (the slides of the selected groups included), in
  /// presentation order.
  List<String> allSlideIds(SlideOrder order) {
    final g = groupIds.toSet();
    final s = slideIds.toSet();
    return [
      for (final e in order.entries)
        if (s.contains(e.id) || g.contains(e.groupId)) e.id,
    ];
  }

  @override
  String toString() => 'NavSelection(groups: $groupIds, slides: $slideIds)';
}

/// A moving unit: a whole group or one slide.
typedef NavUnit = ({String id, bool isGroup});

/// Why a navigator move can't happen.
class NavMoveRefused implements Exception {
  const NavMoveRefused(this.reason);

  /// `nesting` (groups dropped inside a group) or `edge` (nothing to move
  /// past).
  final String reason;

  @override
  String toString() => 'NavMoveRefused($reason)';
}

/// The order operations of the navigator and grid view (04 §5.7, §5.10):
/// moves of mixed selections as units in visible order, keyboard steps
/// across group boundaries, explicit `to` targets and the no-op check.
/// Every move writes `groupId` + `sortKey` together through the planner
/// (02 P4); runs of adjacent units become one operation.
abstract final class NavigatorOps {
  /// The units of [sel] in presentation order: selected groups, and the
  /// selected slides outside them.
  static List<NavUnit> units(SlideOrder order, NavSelection sel) {
    final groups = sel.groupIds.toSet();
    final slides = sel.slideIds.toSet();
    final out = <NavUnit>[];
    final ranges = {for (final r in order.groups) r.group.id: r};
    for (final item in order.topLevel) {
      if (item.isGroup) {
        if (groups.contains(item.id)) {
          out.add((id: item.id, isGroup: true));
          continue;
        }
        final r = ranges[item.id];
        if (r == null) continue;
        for (var i = r.start; i < r.end; i++) {
          final id = order.entries[i].id;
          if (slides.contains(id)) out.add((id: id, isGroup: false));
        }
      } else if (slides.contains(item.id)) {
        out.add((id: item.id, isGroup: false));
      }
    }
    for (final e in order.entries) {
      if (e.orphan && slides.contains(e.id)) {
        out.add((id: e.id, isGroup: false));
      }
    }
    return out;
  }

  /// The operations that move [sel] to [target] (executed in order; later
  /// ones anchor on the rows the earlier ones placed). Throws
  /// [NavMoveRefused] for groups dropped inside a group. Empty when the
  /// move changes nothing.
  static List<SlidesOperation> moveOps(
    SlideOrder order,
    NavSelection sel,
    SlideTarget target,
  ) {
    final units = NavigatorOps.units(order, sel);
    if (units.isEmpty) return const [];
    if (target is InGroup && units.any((u) => u.isGroup)) {
      throw const NavMoveRefused('nesting');
    }
    final t = normalize(order, units, target);
    if (_isNoOp(order, units, t)) return const [];
    if (t is InGroup) {
      return [
        MoveSlides([for (final u in units) u.id], t),
      ];
    }
    final ops = <SlidesOperation>[];
    SlideTarget at = t;
    var i = 0;
    while (i < units.length) {
      final isGroup = units[i].isGroup;
      final run = <String>[];
      while (i < units.length && units[i].isGroup == isGroup) {
        run.add(units[i].id);
        i++;
      }
      if (isGroup) {
        final (before, after) = switch (at) {
          TopLevel(:final beforeId, :final afterId) => (beforeId, afterId),
          InGroup() => (null, null),
        };
        ops.add(MoveGroups(run, beforeId: before, afterId: after));
      } else {
        ops.add(MoveSlides(run, at));
      }
      at = TopLevel(afterId: run.last);
    }
    return ops;
  }

  /// [target] with anchors that are moving replaced by the nearest
  /// non-moving neighbor of the same gap.
  static SlideTarget normalize(
    SlideOrder order,
    List<NavUnit> units,
    SlideTarget target,
  ) {
    final moving = {for (final u in units) u.id};
    switch (target) {
      case TopLevel(:final beforeId, :final afterId):
        final ids = [for (final t in order.topLevel) t.id];
        final pos = _gap(ids, moving, beforeId: beforeId, afterId: afterId);
        final rest = [
          for (final id in ids)
            if (!moving.contains(id)) id,
        ];
        if (pos < rest.length) return TopLevel(beforeId: rest[pos]);
        return rest.isEmpty ? const TopLevel() : TopLevel(afterId: rest.last);
      case InGroup(:final groupId, :final beforeId, :final afterId):
        final ids = _members(order, groupId);
        final pos = _gap(ids, moving, beforeId: beforeId, afterId: afterId);
        final rest = [
          for (final id in ids)
            if (!moving.contains(id)) id,
        ];
        if (pos < rest.length) return InGroup(groupId, beforeId: rest[pos]);
        return rest.isEmpty
            ? InGroup(groupId)
            : InGroup(groupId, afterId: rest.last);
    }
  }

  /// The position in [ids] without [moving] of the gap "before/after" an
  /// id (both null = the end; an unknown anchor = the end).
  static int _gap(
    List<String> ids,
    Set<String> moving, {
    String? beforeId,
    String? afterId,
  }) {
    int raw;
    if (afterId != null) {
      final i = ids.indexOf(afterId);
      raw = i < 0 ? ids.length : i + 1;
    } else if (beforeId != null) {
      final i = ids.indexOf(beforeId);
      raw = i < 0 ? ids.length : i;
    } else {
      raw = ids.length;
    }
    var pos = 0;
    for (var i = 0; i < raw; i++) {
      if (!moving.contains(ids[i])) pos++;
    }
    return pos;
  }

  static List<String> _members(SlideOrder order, String groupId) {
    final r = order.range(groupId);
    if (r == null) return const [];
    return [for (var i = r.start; i < r.end; i++) order.entries[i].id];
  }

  /// Whether moving [units] to the normalized [t] leaves the order as is.
  static bool _isNoOp(SlideOrder order, List<NavUnit> units, SlideTarget t) {
    final top = [for (final i in order.topLevel) i.id];
    final members = {
      for (final r in order.groups) r.group.id: _members(order, r.group.id),
    };
    final moving = {for (final u in units) u.id};
    final orphans = [
      for (final e in order.entries)
        if (e.orphan) e.id,
    ];
    // Orphans always move (the planner gives them a proper key).
    if (orphans.any(moving.contains)) return false;
    List<String> without(List<String> ids) => [
      for (final id in ids)
        if (!moving.contains(id)) id,
    ];
    List<String> insert(List<String> ids, String? before, String? after) {
      final out = [...ids];
      var at = out.length;
      if (before != null) at = out.indexOf(before);
      if (after != null) at = out.indexOf(after) + 1;
      if (at < 0) at = out.length;
      out.insertAll(at, [for (final u in units) u.id]);
      return out;
    }

    bool same(List<String> a, List<String> b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    switch (t) {
      case TopLevel(:final beforeId, :final afterId):
        if (!same(insert(without(top), beforeId, afterId), top)) return false;
        // Slides leaving a group change their group.
        for (final m in members.values) {
          if (m.any(moving.contains)) return false;
        }
        return true;
      case InGroup(:final groupId, :final beforeId, :final afterId):
        if (top.any(moving.contains)) return false;
        for (final MapEntry(key: g, value: m) in members.entries) {
          final after = g == groupId
              ? insert(without(m), beforeId, afterId)
              : without(m);
          if (!same(after, m)) return false;
        }
        return true;
    }
  }

  /// The target of moving [sel] one visible position (⌘↑ / ⌘↓, 04 §5.7):
  /// slides step past their siblings, leave their group at its edges and
  /// enter an expanded group next to them (a collapsed group is jumped
  /// over as one item); groups step past top-level items. Null at the
  /// edge.
  static SlideTarget? stepTarget(
    SlideOrder order,
    NavSelection sel,
    Set<String> collapsed, {
    required bool down,
  }) {
    final units = NavigatorOps.units(order, sel);
    if (units.isEmpty) return null;
    final moving = {for (final u in units) u.id};
    final top = [for (final t in order.topLevel) t];
    final groupIds = {for (final r in order.groups) r.group.id};

    String topItemOf(String id) {
      if (groupIds.contains(id)) return id;
      final e = order.entry(id);
      final g = e?.groupId;
      return g ?? id;
    }

    final boundary = down ? units.last : units.first;
    final hasGroups = units.any((u) => u.isGroup);
    final e = boundary.isGroup ? null : order.entry(boundary.id);
    final inGroup = e?.groupId;

    if (!hasGroups && inGroup != null) {
      final siblings = _members(order, inGroup);
      final i = siblings.indexOf(boundary.id);
      final step = down ? 1 : -1;
      for (var j = i + step; j >= 0 && j < siblings.length; j += step) {
        if (moving.contains(siblings[j])) continue;
        return down
            ? InGroup(inGroup, afterId: siblings[j])
            : InGroup(inGroup, beforeId: siblings[j]);
      }
      // At the group's edge: out, next to the group.
      return down ? TopLevel(afterId: inGroup) : TopLevel(beforeId: inGroup);
    }

    final anchor = topItemOf(boundary.id);
    final i = top.indexWhere((t) => t.id == anchor);
    if (i < 0) {
      // An orphan: to the end (or the start).
      return down ? null : const TopLevel();
    }
    final step = down ? 1 : -1;
    for (var j = i + step; j >= 0 && j < top.length; j += step) {
      final n = top[j];
      if (moving.contains(n.id)) continue;
      if (n.isGroup && !hasGroups && !collapsed.contains(n.id)) {
        final m = _members(order, n.id);
        if (down) {
          return m.isEmpty ? InGroup(n.id) : InGroup(n.id, beforeId: m.first);
        }
        return m.isEmpty ? InGroup(n.id) : InGroup(n.id, afterId: m.last);
      }
      return down ? TopLevel(afterId: n.id) : TopLevel(beforeId: n.id);
    }
    return null;
  }

  /// The target of an explicit move argument (`slides.slide.move {to}`,
  /// 04 §5.7): `start`, `up`, `down`, `end`, `{beforeId}`, `{afterId}`
  /// (a slide or group id; a slide inside a group targets its group) or
  /// `{groupId, index}`. Null when [to] is not understood or at the edge.
  static SlideTarget? targetOf(
    SlideOrder order,
    NavSelection sel,
    Set<String> collapsed,
    Object? to,
  ) {
    switch (to) {
      case 'start':
        final units = NavigatorOps.units(order, sel);
        final moving = {for (final u in units) u.id};
        for (final t in order.topLevel) {
          if (!moving.contains(t.id)) return TopLevel(beforeId: t.id);
        }
        return const TopLevel();
      case 'end':
        return const TopLevel();
      case 'up':
        return stepTarget(order, sel, collapsed, down: false);
      case 'down':
        return stepTarget(order, sel, collapsed, down: true);
      case final Map<Object?, Object?> m:
        final groupId = m['groupId'];
        if (groupId is String) {
          final members = _members(order, groupId);
          if (order.range(groupId) == null) return null;
          final index = m['index'];
          if (index is int && index >= 0 && index < members.length) {
            return InGroup(groupId, beforeId: members[index]);
          }
          return InGroup(groupId);
        }
        final before = m['beforeId'];
        final after = m['afterId'];
        final id = before is String ? before : (after is String ? after : null);
        if (id == null) return null;
        final isBefore = before is String;
        if (order.range(id) != null) {
          return isBefore ? TopLevel(beforeId: id) : TopLevel(afterId: id);
        }
        final e = order.entry(id);
        if (e == null) return null;
        final g = e.groupId;
        if (g == null) {
          return isBefore ? TopLevel(beforeId: id) : TopLevel(afterId: id);
        }
        return isBefore ? InGroup(g, beforeId: id) : InGroup(g, afterId: id);
    }
    return null;
  }
}
