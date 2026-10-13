import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/charts/scene/geometry.dart';
import 'package:wonky_sheets_core/src/objects/objects.dart';

import 'object_fixtures.dart';

void main() {
  group('Given an object at (110, 26) on columns 100, 50 (hidden), 80, 120', () {
    late AxisIndex rows;
    late AxisIndex cols;
    late ObjectAnchor anchor;
    setUp(() {
      cols = testAxis([100, 50, 80, 120], hidden: {1}, ns: 2);
      rows = testAxis([21, 40, 21, 30, 30], hidden: {2});
      anchor = ObjectAnchor.normalizeAt(
        110,
        26,
        width: 200,
        height: 100,
        rows: rows,
        columns: cols,
      );
    });

    for (final (sx, sy, large, left, top) in <(int, int, bool, double, double)>[
      (1, 0, false, 111, 26),
      (0, 1, false, 110, 27),
      (-1, -1, false, 109, 25),
      (1, 0, true, 120, 26),
      (0, -1, true, 110, 16),
      (-20, 0, true, 0, 26),
    ]) {
      test(
        'when nudging ($sx, $sy) large=$large then the top-left is ($left, $top)',
        () {
          final n = anchor.nudge(sx, sy, rows, cols, large: large);

          expect(n.rectIn(rows, cols), ChartRect(left, top, 200, 100));
        },
      );
    }

    test(
      'when nudging across a cell edge then the anchor moves to the new cell',
      () {
        final n = anchor.nudge(0, -1, rows, cols, large: true);

        expect(n.rowId, rows.idAt(0));
        expect(n.dy, 16);
      },
    );

    test('when moving by a px delta then the result is normalized', () {
      final n = anchor.moveBy(80, 40, rows, cols);

      expect(n.colId, cols.idAt(3));
      expect(n.dx, 10);
      expect(n.rowId, rows.idAt(3));
      expect(n.dy, 5);
    });

    for (final (dRow, dCol, row, col) in <(int, int, int, int)>[
      (1, 0, 3, 2),
      (0, -1, 1, 0),
      (0, 1, 1, 3),
      (5, 5, 4, 3),
      (-5, -5, 0, 0),
    ]) {
      test(
        'when nudging by ($dRow, $dCol) cells then the anchor is row $row, column $col',
        () {
          final n = anchor.nudgeByCells(dRow, dCol, rows, cols);

          expect((rows.indexOf(n.rowId!), cols.indexOf(n.colId!)), (row, col));
        },
      );
    }

    test(
      'when nudging by cells into a narrower cell then offsets that do not fit reset',
      () {
        final wide = anchor.moveToCell(1, 3, rows, cols, dx: 90, dy: 35);

        final n = wide.nudgeByCells(0, -1, rows, cols);

        expect(cols.indexOf(n.colId!), 2);
        expect(n.dx, 0);
        expect(n.dy, 35);
      },
    );

    test('when moving to a cell then the offsets are stored in that cell', () {
      final n = anchor.moveToCell(3, 3, rows, cols, dx: 5, dy: 6);

      expect(n.rectIn(rows, cols), const ChartRect(185, 67, 200, 100));
    });

    test(
      'when moving to a cell with an offset past its edge then it is normalized',
      () {
        final n = anchor.moveToCell(0, 0, rows, cols, dx: 110);

        expect(cols.indexOf(n.colId!), 2);
        expect(n.dx, 10);
      },
    );

    test('when duplicating then the copy is offset by (+16, +16)', () {
      expect(
        anchor.duplicated(rows, cols).rectIn(rows, cols),
        const ChartRect(126, 42, 200, 100),
      );
    });

    for (final (w, h, keep, ew, eh)
        in <(double, double, bool?, double, double)>[
          (300, 50, null, 300, 50),
          (10, 5000, null, 20, 4000),
          (400, 100, true, 400, 200),
          (100, 300, true, 600, 300),
          (8000, 10, true, 4000, 2000),
          (5, 5, true, 40, 20),
        ]) {
      test(
        'when resizing to $w × $h keepAspect=$keep then the size is $ew × $eh',
        () {
          final r = anchor.resized(w, h, keepAspect: keep);

          expect((r.width, r.height), (ew, eh));
          expect(
            (r.rowId, r.colId, r.dx, r.dy),
            (anchor.rowId, anchor.colId, anchor.dx, anchor.dy),
          );
        },
      );
    }

    test(
      'when resizing a lockAspect object without keepAspect then the ratio is kept',
      () {
        final r = anchor.copyWith(lockAspect: true).resized(400, 0);

        expect((r.width, r.height), (400, 200));
      },
    );

    test(
      'when dragging the top-left handle then the bottom-right corner stays fixed',
      () {
        final r = anchor.resizeByHandle(
          ResizeHandle.topLeft,
          -10,
          -6,
          rows,
          cols,
        );

        expect(r.rectIn(rows, cols), const ChartRect(100, 20, 210, 106));
      },
    );

    test(
      'when dragging the left handle past the sheet edge then it stops at 0',
      () {
        final r = anchor.resizeByHandle(ResizeHandle.left, -500, 0, rows, cols);

        expect(r.rectIn(rows, cols), const ChartRect(0, 26, 310, 100));
      },
    );

    test('when dragging a corner with keepAspect then the ratio is kept', () {
      final r = anchor.resizeByHandle(
        ResizeHandle.bottomRight,
        100,
        0,
        rows,
        cols,
        keepAspect: true,
      );

      expect(r.rectIn(rows, cols), const ChartRect(110, 26, 300, 150));
    });

    test('when dropping a ghost rect then the anchor is normalized to it', () {
      final r = anchor.withRect(const ChartRect(185, 70, 50, 60), rows, cols);

      expect(r.rectIn(rows, cols), const ChartRect(185, 70, 50, 60));
      expect(cols.indexOf(r.colId!), 3);
    });
  });

  group('Given a chart-sheet anchor', () {
    test('when moving it then it is unchanged', () {
      const own = ObjectAnchor.ownSheetAnchor();

      expect(own.moveBy(5, 5, testAxis([21]), testAxis([100])), own);
      expect(own.nudgeByCells(1, 1, testAxis([21]), testAxis([100])), own);
    });
  });

  group('Given gridlines at 0, 100, 100 (hidden), 180, 300', () {
    final cols = testAxis([100, 50, 80, 120], hidden: {1}, ns: 2);
    final rows = testAxis([20, 20, 20]);

    for (final (px, snapped) in <(double, double)>[
      (-10, 0),
      (0, 0),
      (49, 0),
      (50, 0),
      (51, 100),
      (130, 100),
      (141, 180),
      (299, 300),
      (5000, 300),
    ]) {
      test('when snapping $px then it snaps to $snapped', () {
        expect(GridSnap.snapOffset(px, cols), snapped);
      });
    }

    test('when snap-moving then the edge nearer to a gridline lands on it', () {
      final r = GridSnap.snapMove(const ChartRect(95, 3, 82, 30), rows, cols);

      expect(r, const ChartRect(98, 0, 82, 30));
    });

    test(
      'when snap-resizing the bottom-right handle then those edges snap',
      () {
        final r = GridSnap.snapResize(
          const ChartRect(10, 5, 160, 30),
          ResizeHandle.bottomRight,
          rows,
          cols,
        );

        expect(r, const ChartRect(10, 5, 170, 35));
      },
    );

    test(
      'when snapping would make the object too small then the edge stays',
      () {
        final r = GridSnap.snapResize(
          const ChartRect(90, 0, 25, 25),
          ResizeHandle.left,
          rows,
          cols,
        );

        expect(r, const ChartRect(90, 0, 25, 25));
      },
    );
  });

  group('Given size constraints', () {
    for (final (w, h, aspect, ew, eh)
        in <(double, double, double?, double, double)>[
          (100, 100, null, 100, 100),
          (1, 1, null, 20, 20),
          (100, 10, 2, 100, 50),
          (10, 100, 2, 200, 100),
          (1, 1, 200, 4000, 20),
        ]) {
      test(
        'when constraining $w × $h with aspect $aspect then the size is $ew × $eh',
        () {
          final s = ObjectGeometry.constrainSize(w, h, aspect: aspect);

          expect((s.width, s.height), (ew, eh));
        },
      );
    }

    test(
      'when the ratio cannot fit the limits then each side is clamped on its own',
      () {
        final s = ObjectGeometry.constrainSize(10, 10, aspect: 1000);

        expect((s.width, s.height), (4000, 20));
      },
    );
  });
}
