import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import 'object_fixtures.dart';

void main() {
  group('Given 20 rows of 21 px and 10 columns of 100 px', () {
    late AxisIndex rows;
    late AxisIndex cols;
    setUp(() {
      rows = testAxis(List.filled(20, null));
      cols = testAxis(List.filled(10, null), defaultSize: 100, ns: 2);
    });

    test(
      'when placing a chart for B3:C10 then it sits right of the region at row 3 + 12 px',
      () {
        final a = ObjectPlacement.defaultChartAnchor(
          dataRegion: const GridRect(2, 1, 9, 2),
          rows: rows,
          columns: cols,
        );

        expect(a.colId, cols.idAt(3));
        expect(a.rowId, rows.idAt(2));
        expect((a.dx, a.dy), (12, 0));
        expect((a.width, a.height), (600, 371));
        expect(a.lockAspect, isFalse);
      },
    );

    test(
      'when the next column is hidden then the first visible column is used',
      () {
        cols.upsert(cols.idAt(3), cols.sortKeyAt(3), hidden: true);

        final a = ObjectPlacement.defaultChartAnchor(
          dataRegion: const GridRect(2, 1, 9, 2),
          rows: rows,
          columns: cols,
        );

        expect(a.colId, cols.idAt(4));
        expect(a.dx, 12);
      },
    );

    test(
      'when the next column is narrower than 12 px then the position is still +12 px',
      () {
        cols.upsert(cols.idAt(3), cols.sortKeyAt(3), size: 8);

        final a = ObjectPlacement.defaultChartAnchor(
          dataRegion: const GridRect(0, 0, 3, 2),
          rows: rows,
          columns: cols,
        );

        expect(a.rectIn(rows, cols)!.left, 312);
        expect(a.colId, cols.idAt(4));
      },
    );

    test(
      'when the region ends at the last column then it goes to the viewport + 24 px',
      () {
        final a = ObjectPlacement.defaultChartAnchor(
          dataRegion: const GridRect(0, 5, 3, 9),
          rows: rows,
          columns: cols,
          viewport: const ChartRect(250, 42, 500, 300),
        );

        expect(a.rectIn(rows, cols), const ChartRect(274, 66, 600, 371));
      },
    );

    test(
      'when the next column starts right of the viewport then it goes to the viewport',
      () {
        final a = ObjectPlacement.defaultChartAnchor(
          dataRegion: const GridRect(0, 0, 3, 4),
          rows: rows,
          columns: cols,
          viewport: const ChartRect(0, 0, 500, 300),
        );

        expect(a.rectIn(rows, cols), const ChartRect(24, 24, 600, 371));
      },
    );

    test(
      'when the next column is inside the viewport then the region rule applies',
      () {
        final a = ObjectPlacement.defaultChartAnchor(
          dataRegion: const GridRect(0, 0, 3, 3),
          rows: rows,
          columns: cols,
          viewport: const ChartRect(0, 0, 500, 300),
          width: 400,
          height: 250,
        );

        expect(a.rectIn(rows, cols), const ChartRect(412, 0, 400, 250));
      },
    );

    test(
      'when pasting at C5 then the copy keeps size and lock with dx = dy = 0',
      () {
        const copied = ObjectAnchor(
          width: 320,
          height: 240,
          lockAspect: true,
          dx: 9,
          dy: 9,
        );

        final a = ObjectPlacement.pasteAnchor(
          row: 4,
          col: 2,
          copied: copied,
          rows: rows,
          columns: cols,
        );

        expect(a.rectIn(rows, cols), const ChartRect(200, 84, 320, 240));
        expect(a.lockAspect, isTrue);
      },
    );

    test(
      'when inserting an image at B2 then it is locked and fits 600 × 400',
      () {
        final a = ObjectPlacement.imageAnchor(
          row: 1,
          col: 1,
          naturalWidth: 1200,
          naturalHeight: 800,
          rows: rows,
          columns: cols,
        );

        expect(a.rectIn(rows, cols), const ChartRect(100, 21, 600, 400));
        expect(a.lockAspect, isTrue);
      },
    );
  });

  group('Given image natural sizes', () {
    for (final (w, h, ew, eh) in <(double, double, double, double)>[
      (1200, 800, 600, 400),
      (1000, 1600, 250, 400),
      (300, 200, 300, 200),
      (2400, 400, 600, 100),
      (10, 10, 20, 20),
      (0, 100, 600, 400),
    ]) {
      test(
        'when computing the default size of $w × $h then it is $ew × $eh',
        () {
          final s = ObjectPlacement.defaultImageSize(w, h);

          expect((s.width, s.height), (ew, eh));
        },
      );
    }

    for (final (w, h, ew, eh) in <(double, double, double, double)>[
      (1200, 800, 1200, 800),
      (8000, 4000, 4000, 2000),
      (3000, 6000, 2000, 4000),
    ]) {
      test('when resetting the size of $w × $h then it is $ew × $eh', () {
        final s = ObjectPlacement.resetImageSize(w, h);

        expect((s.width, s.height), (ew, eh));
      });
    }
  });

  group('Given a chart moved to its own sheet', () {
    late AxisIndex rows;
    late AxisIndex cols;
    late ObjectAnchor previous;
    setUp(() {
      rows = testAxis(List.filled(10, null));
      cols = testAxis(List.filled(5, null), defaultSize: 100, ns: 2);
      previous = ObjectAnchor.atCell(
        2,
        3,
        dx: 4,
        dy: 5,
        width: 500,
        height: 300,
        rows: rows,
        columns: cols,
      );
    });

    test(
      'when storing the previous anchor then the spec keeps its other keys',
      () {
        final spec = ChartSheetAnchors.withPreviousAnchor({
          'v': 1,
          'title': 'Sales',
        }, previous);

        expect(spec, containsPair('title', 'Sales'));
        expect(ChartSheetAnchors.previousAnchorOf(spec), previous);
      },
    );

    test('when removing the previous anchor then previousAnchorOf is null', () {
      final spec = ChartSheetAnchors.withPreviousAnchor({'v': 1}, previous);

      expect(
        ChartSheetAnchors.previousAnchorOf(
          ChartSheetAnchors.withoutPreviousAnchor(spec),
        ),
        isNull,
      );
    });

    test('when the anchor is nested under extras then it is read too', () {
      final spec = {
        'v': 1,
        'extras': {'previousAnchor': previous.toJson()},
      };

      expect(ChartSheetAnchors.previousAnchorOf(spec), previous);
      expect(
        ChartSheetAnchors.previousAnchorOf(
          ChartSheetAnchors.withoutPreviousAnchor(spec),
        ),
        isNull,
      );
    });

    test(
      'when moving back to the original sheet then the previous anchor is restored',
      () {
        final spec = ChartSheetAnchors.withPreviousAnchor({'v': 1}, previous);

        final a = ChartSheetAnchors.anchorForMoveToSheet(
          spec: spec,
          current: previous.toOwnSheet(),
          rows: rows,
          columns: cols,
        );

        expect(a, previous);
      },
    );

    test(
      'when moving to another sheet then it goes to A1 with the previous size',
      () {
        final spec = ChartSheetAnchors.withPreviousAnchor({'v': 1}, previous);
        final otherRows = testAxis(List.filled(10, null), ns: 3);
        final otherCols = testAxis(
          List.filled(5, null),
          defaultSize: 100,
          ns: 4,
        );

        final a = ChartSheetAnchors.anchorForMoveToSheet(
          spec: spec,
          current: previous.toOwnSheet(),
          rows: otherRows,
          columns: otherCols,
        );

        expect(a.rowId, otherRows.idAt(0));
        expect(a.colId, otherCols.idAt(0));
        expect((a.dx, a.dy, a.width, a.height), (0, 0, 500, 300));
      },
    );

    test(
      'when no previous anchor is stored then it goes to A1 with the current size',
      () {
        final a = ChartSheetAnchors.anchorForMoveToSheet(
          spec: const {'v': 1},
          current: const ObjectAnchor.ownSheetAnchor(),
          rows: rows,
          columns: cols,
        );

        expect(a.rectIn(rows, cols), const ChartRect(0, 0, 600, 371));
      },
    );
  });

  group('Given 2 frozen rows and 1 frozen column', () {
    late AxisIndex rows;
    late AxisIndex cols;
    setUp(() {
      rows = testAxis(List.filled(40, null));
      cols = testAxis(List.filled(10, null), defaultSize: 100, ns: 2);
    });

    test('when the data starts in the frozen rows then the chart goes to the '
        'top of the scrolling pane', () {
      final a = ObjectPlacement.defaultChartAnchor(
        dataRegion: const GridRect(0, 0, 9, 0),
        rows: rows,
        columns: cols,
        frozenRows: 2,
        frozenColumns: 1,
        viewport: ChartRect(100, rows.offsetOf(10), 900, 600),
      );
      expect(rows.indexOf(a.rowId!), 10);
      expect(cols.indexOf(a.colId!), 1);
    });

    test('when there is no viewport then the first scrolling row is used', () {
      final a = ObjectPlacement.defaultChartAnchor(
        dataRegion: const GridRect(1, 0, 9, 0),
        rows: rows,
        columns: cols,
        frozenRows: 2,
      );
      expect(rows.indexOf(a.rowId!), 2);
    });

    test('when the region is right of the frozen columns then nothing '
        'changes', () {
      final a = ObjectPlacement.defaultChartAnchor(
        dataRegion: const GridRect(5, 2, 9, 3),
        rows: rows,
        columns: cols,
        frozenRows: 2,
        frozenColumns: 1,
      );
      expect(rows.indexOf(a.rowId!), 5);
      expect(cols.indexOf(a.colId!), 4);
    });
  });
}
