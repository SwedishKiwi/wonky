import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';
import '../../rules/support/rule_fixtures.dart';

/// Applies [changes] to the model (as the planner would).
void apply(WorkbookModel m, GroupChanges changes) {
  for (final e in changes.inserts.entries) {
    m.upsertRow(SheetsTables.dimensionGroup, e.key, e.value);
  }
  for (final e in changes.updates.entries) {
    m.upsertRow(SheetsTables.dimensionGroup, e.key, {
      ...m.sheets.first.groups[e.key]!.toColumns(),
      ...e.value,
    });
  }
  for (final id in changes.deletes) {
    m.deleteRow(SheetsTables.dimensionGroup, id);
  }
}

void main() {
  late WorkbookBuilder b;
  late WorkbookModel m;
  late String sid;
  final ids = SequentialIdGenerator(5000);
  setUp(() {
    b = WorkbookBuilder();
    sid = b.sheet('Sheet1', rows: 30, cols: 3);
    m = b.build();
  });

  GroupLayout layout() {
    final s = m.sheets.single;
    return GroupLayout(sid, Dimension.rows, s.rows, s.groups.values);
  }

  List<String> spans() => [for (final g in layout().spans()) '${g.start + 1}-${g.end + 1}:d${g.depth}${g.collapsed ? 'c' : ''}'];

  void addGroup(String id, int s, int e, int depth, {bool collapsed = false}) =>
      m.upsertRow(SheetsTables.dimensionGroup, id, {
        Cols.sheetId: sid,
        'dimension': 'rows',
        'startId': b.rowId(s),
        'endId': b.rowId(e),
        'depth': depth,
        'collapsed': collapsed,
      });

  group('Given rows 3–8 grouped and 4–5 grouped inside (07 §16.4)', () {
    setUp(() {
      apply(m, layout().create(2, 7, ids));
      apply(m, layout().create(3, 4, ids));
    });

    test('when grouping then the inner group has depth 2', () {
      expect(spans(), ['3-8:d1', '4-5:d2']);
    });

    test('when pressing level 1 then everything collapses', () {
      apply(m, layout().collapseToLevel(1));
      expect(spans(), ['3-8:d1c', '4-5:d2c']);
      expect(layout().collapsedHiddenIds(), {for (var i = 2; i <= 7; i++) b.rowId(i)});
      expect(layout().collapsedRanges(), [(2, 7)]);
    });

    test('when pressing level 2 then only depth ≥ 2 collapses', () {
      apply(m, layout().collapseToLevel(2));
      expect(spans(), ['3-8:d1', '4-5:d2c']);
    });

    test('when ungrouping row 5 then the depth-2 group shrinks to row 4', () {
      apply(m, layout().ungroup(4, 4, ids));
      expect(spans(), ['3-8:d1', '4-4:d2']);
    });

    test('when ungrouping the whole outer span then the deepest group goes first', () {
      apply(m, layout().ungroup(2, 7, ids));
      expect(spans(), ['3-8:d1']);
    });

    test('when ungrouping the middle of a group then it splits', () {
      apply(m, layout().ungroup(4, 4, ids));
      apply(m, layout().ungroup(4, 5, ids));
      expect(spans(), ['3-4:d1', '4-4:d2', '7-8:d1']);
    });

    test('when grouping the identical span again then it nests one level deeper', () {
      apply(m, layout().create(3, 4, ids));
      expect(spans(), ['3-8:d1', '4-5:d2', '4-5:d3']);
    });

    test('when a span contains existing groups then they get deeper', () {
      apply(m, layout().create(1, 9, ids));
      expect(spans(), ['2-10:d1', '3-8:d2', '4-5:d3']);
    });

    test('when toggling and expanding all then the collapsed flags follow', () {
      final id = layout().spans().first.id;
      apply(m, layout().toggle(id));
      expect(spans(), ['3-8:d1c', '4-5:d2']);
      apply(m, layout().expandAll());
      expect(spans(), ['3-8:d1', '4-5:d2']);
      apply(m, layout().collapseAll());
      expect(spans(), ['3-8:d1c', '4-5:d2c']);
    });

    test('when removing all then every group is deleted', () {
      apply(m, layout().removeAll());
      expect(spans(), isEmpty);
    });
  });

  group('Given partially overlapping spans', () {
    test('when grouping over a partial overlap at the same depth then the spans merge', () {
      apply(m, layout().create(4, 7, ids));
      final changes = layout().create(2, 5, ids);
      expect(changes.inserts, isEmpty);
      apply(m, changes);
      expect(spans(), ['3-8:d1']);
    });

    test('when two users grouped overlapping spans offline then normalization converges', () {
      addGroup(fid(2), 4, 9, 1);
      addGroup(fid(1), 2, 6, 1);
      apply(m, layout().normalize());
      expect(spans(), ['3-7:d1', '5-10:d1']);
      expect(layout().normalize().isEmpty, isTrue);
    });

    test('when identical spans with equal stored depth exist then the smaller id is kept', () {
      addGroup(fid(2), 2, 6, 1);
      addGroup(fid(1), 2, 6, 1);
      final c = layout().normalize();
      expect(c.deletes, {fid(2)});
    });

    test('when nesting exceeds 8 levels then grouping is refused', () {
      for (var i = 0; i < 8; i++) {
        apply(m, layout().create(i, 20 - i, ids));
      }
      expect(layout().maxDepth, 8);
      expect(layout().create(10, 10, ids).error, "You can't group more than 8 levels.");
    });

    test('when stored depths are wrong then normalization fixes only those rows', () {
      addGroup(fid(1), 2, 9, 3);
      addGroup(fid(2), 3, 4, 2);
      final c = layout().normalize();
      expect(c.updates, {
        fid(1): {'depth': 1},
      });
    });
  });
}
