import 'package:wonky_sync_models/ids.dart';

import '../../engine_bridge/model_cell_source.dart' show HiddenLayers;
import '../../model/axis_index.dart';
import '../../model/records.dart';
import '../../model/schema.dart';

/// Maximum group depth (07 §16.3).
const int kMaxGroupDepth = 8;

/// A group resolved to current indices.
final class GroupSpan {
  /// Creates a span.
  const GroupSpan(
    this.id,
    this.start,
    this.end,
    this.depth, {
    this.collapsed = false,
  });

  final String id;

  /// First index (inclusive).
  final int start;

  /// Last index (inclusive).
  final int end;
  final int depth;
  final bool collapsed;

  int get length => end - start + 1;

  bool contains(GroupSpan o) => start <= o.start && end >= o.end;
  bool intersects(int s, int e) => start <= e && end >= s;

  @override
  String toString() =>
      'GroupSpan($id, $start–$end, d$depth${collapsed ? ', collapsed' : ''})';
}

/// Record changes produced by group operations, as `DimensionGroup` column
/// maps for the mutation planner.
final class GroupChanges {
  /// Creates changes.
  GroupChanges({
    Map<String, Map<String, Object?>>? inserts,
    Map<String, Map<String, Object?>>? updates,
    Set<String>? deletes,
    this.error,
  }) : inserts = inserts ?? {},
       updates = updates ?? {},
       deletes = deletes ?? {};

  /// A refused operation.
  GroupChanges.error(String message) : this(error: message);

  /// New groups: id → full column map.
  final Map<String, Map<String, Object?>> inserts;

  /// Changed groups: id → changed columns only.
  final Map<String, Map<String, Object?>> updates;

  /// Deleted group ids.
  final Set<String> deletes;

  /// Refusal message (nothing to write), e.g. "You can't group more than 8 levels."
  final String? error;

  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  @override
  String toString() =>
      'GroupChanges(+${inserts.keys}, ~$updates, -$deletes${error == null ? '' : ', $error'})';
}

final class _G {
  _G(
    this.id,
    this.start,
    this.end,
    this.depth,
    this.collapsed, {
    this.isNew = false,
  });
  final String id;
  int start;
  int end;
  int depth;
  bool collapsed;
  final bool isNew;
  bool get valid => start >= 0 && end >= start;
}

/// Row/column group layout (07 §16): depth normalization, collapse masks and
/// the group commands.
final class GroupLayout {
  /// Creates the layout of [groups] (one sheet, one [dimension]) on [axis].
  GroupLayout(
    this.sheetId,
    this.dimension,
    this.axis,
    Iterable<DimensionGroupRecord> groups,
  ) : records = {
        for (final g in groups)
          if (g.dimension == dimension && g.sheetId == sheetId) g.id: g,
      };

  final String sheetId;
  final Dimension dimension;
  final AxisIndex axis;
  final Map<String, DimensionGroupRecord> records;

  static const _messageTooDeep =
      "You can't group more than $kMaxGroupDepth levels.";

  /// Resolved spans (groups whose endpoints are missing are skipped), in
  /// normalization order.
  List<GroupSpan> spans() {
    final out = <GroupSpan>[];
    for (final g in records.values) {
      final s = axis.indexOf(g.startId);
      final e = axis.indexOf(g.endId);
      if (s < 0 || e < 0) continue;
      out.add(
        GroupSpan(
          g.id,
          s < e ? s : e,
          s < e ? e : s,
          g.depth,
          collapsed: g.collapsed,
        ),
      );
    }
    out.sort(_order);
    return out;
  }

  static int _order(GroupSpan a, GroupSpan b) {
    if (a.start != b.start) return a.start - b.start;
    if (a.length != b.length) return b.length - a.length;
    if (a.depth != b.depth) return a.depth - b.depth;
    return a.id.compareTo(b.id);
  }

  static int _orderG(_G a, _G b) => _order(
    GroupSpan(a.id, a.start, a.end, a.depth),
    GroupSpan(b.id, b.start, b.end, b.depth),
  );

  /// Working copies with normalized depths; duplicates go to [deletes].
  List<_G> _normalizedWorking(Set<String> deletes) {
    final gs = _working();
    final d = _depths(gs, deletes);
    for (final g in gs) {
      g.depth = d[g.id]!;
    }
    return gs;
  }

  List<_G> _working() => [
    for (final s in spans()) _G(s.id, s.start, s.end, s.depth, s.collapsed),
  ];

  /// Computes depths: sort by (start, −length, depth, id); identical spans
  /// with equal stored depth keep the smaller id (others deleted); depth = 1 +
  /// number of earlier groups containing the group, clamped to 8. Returns
  /// deletes in [deletes] and the computed depth per id.
  static Map<String, int> _depths(List<_G> gs, Set<String> deletes) {
    gs.sort(_orderG);
    final seen = <(int, int, int)>{};
    final kept = <_G>[];
    for (final g in gs) {
      if (!seen.add((g.start, g.end, g.depth))) {
        deletes.add(g.id);
        continue;
      }
      kept.add(g);
    }
    final depth = <String, int>{};
    final stack = <_G>[];
    for (final g in kept) {
      // Containers: earlier groups whose span contains g.
      var d = 1;
      for (final o in stack) {
        if (o.start <= g.start && o.end >= g.end) d++;
      }
      depth[g.id] = d > kMaxGroupDepth ? kMaxGroupDepth : d;
      stack.add(g);
    }
    gs
      ..clear()
      ..addAll(kept);
    return depth;
  }

  Map<String, Object?> _columns(_G g) => {
    Cols.sheetId: sheetId,
    'dimension': dimension.name,
    'startId': axis.idAt(g.start),
    'endId': axis.idAt(g.end),
    'depth': g.depth,
    'collapsed': g.collapsed,
  };

  /// Builds the changes turning the stored records into [gs] (plus [deletes]).
  GroupChanges _diff(
    List<_G> gs,
    Set<String> deletes, {
    bool checkDepth = false,
  }) {
    final depths = _depths(gs, deletes);
    if (checkDepth) {
      for (final g in gs) {
        // Unclamped depth check.
        var d = 1;
        for (final o in gs) {
          if (o == g) break;
          if (o.start <= g.start && o.end >= g.end) d++;
        }
        if (d > kMaxGroupDepth) return GroupChanges.error(_messageTooDeep);
      }
    }
    final out = GroupChanges(deletes: {...deletes});
    for (final g in gs) {
      g.depth = depths[g.id]!;
      if (g.isNew) {
        out.inserts[g.id] = _columns(g);
        continue;
      }
      final rec = records[g.id]!;
      final up = <String, Object?>{};
      final startId = axis.idAt(g.start);
      final endId = axis.idAt(g.end);
      if (rec.startId != startId) up['startId'] = startId;
      if (rec.endId != endId) up['endId'] = endId;
      if (rec.depth != g.depth) up['depth'] = g.depth;
      if (rec.collapsed != g.collapsed) up['collapsed'] = g.collapsed;
      if (up.isNotEmpty) out.updates[g.id] = up;
    }
    return out;
  }

  /// Invariant normalization (02 §8, 07 §16.3): writes only groups whose
  /// stored depth differs and deletes duplicates. Idempotent.
  GroupChanges normalize() => _diff(_working(), {});

  /// The ids (rows/columns) hidden by collapsed groups (`GroupCollapseMask`).
  Set<String> collapsedHiddenIds() {
    final out = <String>{};
    for (final (s, e) in collapsedRanges()) {
      for (var i = s; i <= e; i++) {
        out.add(axis.idAt(i));
      }
    }
    return out;
  }

  /// Applies the collapse mask to [axis] as its `groups` hidden layer
  /// (`GroupCollapseMask`, 07 §16.1); call after group records change.
  void applyCollapseMask() =>
      axis.setHiddenLayer(HiddenLayers.groups, collapsedHiddenIds());

  /// Merged index ranges hidden by collapsed groups.
  List<(int, int)> collapsedRanges() {
    final cs = [
      for (final s in spans())
        if (s.collapsed) (s.start, s.end),
    ]..sort((a, b) => a.$1 - b.$1);
    final out = <(int, int)>[];
    for (final r in cs) {
      if (out.isNotEmpty && r.$1 <= out.last.$2 + 1) {
        if (r.$2 > out.last.$2) out[out.length - 1] = (out.last.$1, r.$2);
      } else {
        out.add(r);
      }
    }
    return out;
  }

  /// Maximum depth (number of gutter levels).
  int get maxDepth => spans().fold(0, (m, s) => s.depth > m ? s.depth : m);

  /// Creates a group over indices [start]..[end] (07 §16.3): depth = 1 + groups
  /// containing the span; partial overlaps at that depth merge into the union
  /// (the first overlapping group is extended); contained groups get deeper.
  GroupChanges create(int start, int end, IdGenerator ids) {
    if (end < start) (start, end) = (end, start);
    if (start < 0 || end >= axis.length) return GroupChanges();
    final deletes = <String>{};
    final gs = _normalizedWorking(deletes);
    var s = start, e = end;
    _G? reuse;
    while (true) {
      var d = 1;
      for (final g in gs) {
        if (deletes.contains(g.id)) continue;
        if (g.start <= s && g.end >= e) d++;
      }
      final partial = [
        for (final g in gs)
          if (!deletes.contains(g.id) &&
              g.depth == d &&
              g.start <= e &&
              g.end >= s &&
              !(g.start <= s && g.end >= e) &&
              !(s <= g.start && e >= g.end))
            g,
      ];
      if (partial.isEmpty) break;
      partial.sort((a, b) => a.id.compareTo(b.id));
      for (final g in partial) {
        if (g.start < s) s = g.start;
        if (g.end > e) e = g.end;
      }
      reuse ??= partial.first;
      for (final g in partial) {
        if (g != reuse) deletes.add(g.id);
      }
      reuse
        ..start = s
        ..end = e;
    }
    final kept = [
      for (final g in gs)
        if (!deletes.contains(g.id)) g,
    ];
    // Provisional depth sorts the new group inside identical spans.
    if (reuse == null) {
      kept.add(_G(ids.newId(), s, e, kMaxGroupDepth + 1, false, isNew: true));
    }
    return _diff(kept, deletes, checkDepth: true);
  }

  /// Ungroups indices [start]..[end] from the deepest intersecting groups:
  /// covered → deleted; an end covered → shrunk; strictly inside → split.
  GroupChanges ungroup(int start, int end, IdGenerator ids) {
    if (end < start) (start, end) = (end, start);
    final deletes = <String>{};
    final gs = _normalizedWorking(deletes);
    final hits = [
      for (final g in gs)
        if (g.start <= end && g.end >= start) g,
    ];
    if (hits.isEmpty) return GroupChanges();
    final deepest = hits.fold(0, (m, g) => g.depth > m ? g.depth : m);
    final added = <_G>[];
    for (final g in hits.where((g) => g.depth == deepest)) {
      if (start <= g.start && end >= g.end) {
        deletes.add(g.id);
      } else if (start <= g.start) {
        g.start = end + 1;
      } else if (end >= g.end) {
        g.end = start - 1;
      } else {
        added.add(
          _G(ids.newId(), end + 1, g.end, g.depth, g.collapsed, isNew: true),
        );
        g.end = start - 1;
      }
    }
    final kept = [
      for (final g in gs)
        if (!deletes.contains(g.id) && g.valid) g,
      ...added,
    ];
    return _diff(kept, deletes);
  }

  /// Toggles the collapsed state of [groupId].
  GroupChanges toggle(String groupId) {
    final r = records[groupId];
    if (r == null) return GroupChanges();
    return GroupChanges(
      updates: {
        groupId: {'collapsed': !r.collapsed},
      },
    );
  }

  GroupChanges _setCollapsed(bool Function(GroupSpan s) collapsed) {
    final out = GroupChanges();
    for (final s in spans()) {
      final c = collapsed(s);
      if (c != s.collapsed) out.updates[s.id] = {'collapsed': c};
    }
    return out;
  }

  /// Level button [level]: groups with depth ≥ level collapse, others expand.
  GroupChanges collapseToLevel(int level) =>
      _setCollapsed((s) => s.depth >= level);

  /// Expands every group.
  GroupChanges expandAll() => _setCollapsed((_) => false);

  /// Collapses every group.
  GroupChanges collapseAll() => _setCollapsed((_) => true);

  /// Removes every group of the dimension.
  GroupChanges removeAll() => GroupChanges(deletes: records.keys.toSet());
}
