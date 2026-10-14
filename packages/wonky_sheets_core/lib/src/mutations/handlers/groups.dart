import '../../data_tools/groups/group_layout.dart';
import '../../model/schema.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';

/// [GroupOperation] (07 §16): group/ungroup a span ([GroupOperation.start] ..
/// [GroupOperation.end], indices), collapse/expand/toggle one group
/// ([GroupOperation.groupId]), collapse to a level, expand/collapse/remove
/// all groups of the dimension. Collapse state is synced content.
///
/// Refusals: `invalid_argument` (missing span/group/level), `not_found`
/// (unknown group), `group_too_deep` ("You can't group more than 8 levels.").
///
/// Result: `groupId` for group (the new or extended group).
MutationPlan planGroupOperation(PlanBuilder b, GroupOperation op) {
  final s = b.sheetOf(op.sheetId);
  final rows = op.dimension == Dimension.rows;
  final what = rows ? 'rows' : 'columns';
  final layout = GroupLayout(s.id, op.dimension, s.axis(op.dimension), [
    for (final g in s.groups.values) g,
  ]);
  (int, int) span() {
    final start = op.start;
    final end = op.end ?? start;
    final len = s.axis(op.dimension).length;
    if (start == null || end == null) {
      throw const PlanException('invalid_argument', 'Select what to group');
    }
    if (start < 0 || end < 0 || start >= len || end >= len) {
      throw PlanException(
        'invalid_range',
        'The $what are outside the grid of "${s.name}"',
      );
    }
    return start <= end ? (start, end) : (end, start);
  }

  String groupId() {
    final id = op.groupId;
    if (id == null) {
      throw const PlanException('invalid_argument', 'Choose a group');
    }
    if (!layout.records.containsKey(id)) {
      throw PlanException('not_found', 'Group not found', details: {'id': id});
    }
    return id;
  }

  final GroupChanges changes;
  final String label;
  switch (op.action) {
    case GroupAction.group:
      final (a, z) = span();
      changes = layout.create(a, z, b.ctx.ids);
      label = 'Group $what';
    case GroupAction.ungroup:
      final (a, z) = span();
      changes = layout.ungroup(a, z, b.ctx.ids);
      label = 'Ungroup $what';
    case GroupAction.collapse || GroupAction.expand:
      final id = groupId();
      final collapsed = op.action == GroupAction.collapse;
      changes = GroupChanges(
        updates: {
          if (layout.records[id]!.collapsed != collapsed)
            id: {'collapsed': collapsed},
        },
      );
      label = collapsed ? 'Collapse group' : 'Expand group';
    case GroupAction.toggle:
      final id = groupId();
      changes = layout.toggle(id);
      label = layout.records[id]!.collapsed ? 'Expand group' : 'Collapse group';
    case GroupAction.collapseToLevel:
      final level = op.level;
      if (level == null || level < 1 || level > kMaxGroupDepth + 1) {
        throw const PlanException('invalid_argument', 'Invalid group level');
      }
      changes = layout.collapseToLevel(level);
      label = 'Show group level $level';
    case GroupAction.expandAll:
      changes = layout.expandAll();
      label = 'Expand all groups';
    case GroupAction.collapseAll:
      changes = layout.collapseAll();
      label = 'Collapse all groups';
    case GroupAction.removeAll:
      changes = layout.removeAll();
      label = 'Remove all groups';
  }
  if (changes.error != null) {
    throw PlanException('group_too_deep', changes.error!);
  }
  for (final id in changes.deletes) {
    b.delete(SheetsTables.dimensionGroup, id);
  }
  for (final e in changes.updates.entries) {
    b.update(SheetsTables.dimensionGroup, e.key, e.value);
  }
  for (final e in changes.inserts.entries) {
    b.insert(SheetsTables.dimensionGroup, e.key, e.value);
  }
  if (op.action == GroupAction.group) {
    final created = changes.inserts.keys.firstOrNull;
    final extended = [
      for (final e in changes.updates.entries)
        if (e.value.containsKey('startId') || e.value.containsKey('endId'))
          e.key,
    ];
    final id = created ?? extended.firstOrNull;
    if (id != null) b.result['groupId'] = id;
  }
  b.summary.sheets.add(s.id);
  return b.build(label, kinds: [ChangeKinds.structure]);
}
