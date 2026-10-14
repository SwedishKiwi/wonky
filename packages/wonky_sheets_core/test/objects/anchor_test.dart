import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart';

import 'object_fixtures.dart';

void main() {
  final rowId = testUuid(1, 3);
  final colId = testUuid(2, 7);

  group('Given an over-grid anchor', () {
    final anchor = ObjectAnchor(
      rowId: rowId,
      colId: colId,
      rowKey: 'a0',
      colKey: 'a1',
      dx: 12,
      dy: 4,
      width: 600,
      height: 371,
    );

    test('when encoding then ids are written as 22-char base-62', () {
      final json = anchor.toJson();

      expect(json['rowId'], Base62Uuid.encode(rowId));
      expect((json['rowId']! as String).length, 22);
      expect(json['colId'], Base62Uuid.encode(colId));
      expect(json, containsPair('rk', 'a0'));
      expect(json, containsPair('ck', 'a1'));
    });

    test(
      'when round-tripping through encode and tryParse then it is equal',
      () {
        expect(ObjectAnchor.tryParse(anchor.encode()), anchor);
      },
    );

    test('when parsing canonical UUID ids then they are accepted', () {
      final json = {
        ...anchor.toJson(),
        'rowId': rowId.toUpperCase(),
        'colId': colId,
      };

      expect(ObjectAnchor.fromJson(json), anchor);
    });

    test('when parsing unknown keys then they are preserved on round-trip', () {
      final json = {
        ...anchor.toJson(),
        'future': {
          'a': [1, 2],
        },
        'flag': true,
      };

      final parsed = ObjectAnchor.fromJson(json);

      expect(parsed.extras, {
        'future': {
          'a': [1, 2],
        },
        'flag': true,
      });
      expect(parsed.toJson(), json);
      expect(ObjectAnchor.tryParse(jsonEncode(parsed.toJson())), parsed);
    });

    test('when parsing out-of-range values then they are sanitized', () {
      final parsed = ObjectAnchor.fromJson({
        'v': 1,
        'rowId': rowId,
        'colId': colId,
        'dx': -3,
        'dy': 'x',
        'width': 5,
        'height': 9000,
      });

      expect(parsed.dx, 0);
      expect(parsed.dy, 0);
      expect(parsed.width, ObjectAnchor.minSize);
      expect(parsed.height, ObjectAnchor.maxSize);
    });

    test('when copying with a field then only that field changes', () {
      final c = anchor.copyWith(dx: 1);

      expect(c.dx, 1);
      expect(c, anchor.copyWith(dx: 1));
      expect(c == anchor, isFalse);
      expect(c.hashCode, anchor.copyWith(dx: 1).hashCode);
    });
  });

  group('Given invalid anchor input', () {
    for (final (label, input) in <(String, Object?)>[
      ('null', null),
      ('a number', 42),
      ('broken JSON', '{nope'),
      ('a JSON list', '[]'),
      ('a map without ids', '{"v":1,"dx":3}'),
      ('a map without colId', {'v': 1, 'rowId': rowId}),
    ]) {
      test('when parsing $label then tryParse returns null', () {
        expect(ObjectAnchor.tryParse(input), isNull);
      });
    }

    test(
      'when calling fromJson without ids then it throws a FormatException',
      () {
        expect(
          () => ObjectAnchor.fromJson({'v': 1}),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('Given a chart-sheet anchor', () {
    test('when encoding then it is exactly {"v":1,"ownSheet":true}', () {
      expect(
        const ObjectAnchor.ownSheetAnchor().encode(),
        '{"v":1,"ownSheet":true}',
      );
    });

    test('when parsing it then ownSheet is set and rectIn is null', () {
      final a = ObjectAnchor.tryParse('{"v":1,"ownSheet":true}')!;

      expect(a, const ObjectAnchor.ownSheetAnchor());
      expect(a.rectIn(testAxis([21]), testAxis([100])), isNull);
      expect(a.reanchor(testAxis([21]), testAxis([100])), isNull);
    });

    test(
      'when converting an anchor with lockAspect then size and lock are kept',
      () {
        final own = ObjectAnchor(
          rowId: rowId,
          colId: colId,
          width: 300,
          height: 200,
          lockAspect: true,
        ).toOwnSheet();

        expect(own.toJson(), {
          'v': 1,
          'ownSheet': true,
          'width': 300.0,
          'height': 200.0,
          'lockAspect': true,
        });
        expect(ObjectAnchor.tryParse(own.encode()), own);
      },
    );
  });

  group('Given columns 100, 50 (hidden), 80, 120 and rows 21, 40, 21 (hidden), 30', () {
    late AxisIndex rows;
    late AxisIndex cols;
    setUp(() {
      cols = testAxis([100, 50, 80, 120], hidden: {1}, ns: 2);
      rows = testAxis([21, 40, 21, 30], hidden: {2});
    });

    for (final (x, y, col, dx, row, dy)
        in <(double, double, int, double, int, double)>[
          (0, 0, 0, 0, 0, 0),
          (99.5, 20, 0, 99.5, 0, 20),
          (100, 21, 2, 0, 1, 0),
          (150, 70, 2, 50, 3, 9),
          (180, 61, 3, 0, 3, 0),
          (-5, -5, 0, 0, 0, 0),
          (1000, 1000, 3, 120, 3, 30),
        ]) {
      test(
        'when normalizing at ($x, $y) then the anchor is column $col + $dx, row $row + $dy',
        () {
          final a = ObjectAnchor.normalizeAt(
            x,
            y,
            width: 600,
            height: 371,
            rows: rows,
            columns: cols,
          );

          expect(a.colId, cols.idAt(col));
          expect(a.dx, dx);
          expect(a.rowId, rows.idAt(row));
          expect(a.dy, dy);
          expect(a.rowKey, rows.sortKeyAt(row));
          expect(a.colKey, cols.sortKeyAt(col));
        },
      );
    }

    for (final (w, h, ew, eh) in <(double, double, double, double)>[
      (5, 5, 20, 20),
      (5000, 4001, 4000, 4000),
      (double.nan, 300, 20, 300),
    ]) {
      test(
        'when normalizing with size $w × $h then it is clamped to $ew × $eh',
        () {
          final a = ObjectAnchor.normalizeAt(
            0,
            0,
            width: w,
            height: h,
            rows: rows,
            columns: cols,
          );

          expect((a.width, a.height), (ew, eh));
        },
      );
    }

    test(
      'when computing rectIn then the top-left is the cell origin plus the offsets',
      () {
        final a = ObjectAnchor(
          rowId: rows.idAt(1),
          colId: cols.idAt(2),
          dx: 10,
          dy: 5,
          width: 200,
          height: 100,
        );

        expect(a.rectIn(rows, cols), const ChartRect(110, 26, 200, 100));
      },
    );

    test(
      'when the anchor column is hidden then the object sits at the collapsed edge',
      () {
        final a = ObjectAnchor(
          rowId: rows.idAt(2),
          colId: cols.idAt(1),
          dx: 30,
          dy: 10,
        );

        expect(a.rectIn(rows, cols), const ChartRect(100, 61, 600, 371));
      },
    );

    test('when the anchor row does not exist then rectIn is null', () {
      final a = ObjectAnchor(rowId: testUuid(9, 9), colId: cols.idAt(0));

      expect(a.rectIn(rows, cols), isNull);
    });

    test(
      'when re-normalizing an anchor that fits then ids and offsets are kept',
      () {
        final a = ObjectAnchor(
          rowId: rows.idAt(1),
          colId: cols.idAt(2),
          dx: 79.25,
          dy: 3.1,
        );

        final n = a.normalized(rows, cols);

        expect(
          n,
          a.copyWith(rowKey: rows.sortKeyAt(1), colKey: cols.sortKeyAt(2)),
        );
        expect(n.normalized(rows, cols), n);
      },
    );

    test(
      'when re-normalizing an offset wider than the column then the shown edge is kept',
      () {
        final a = ObjectAnchor(
          rowId: rows.idAt(0),
          colId: cols.idAt(0),
          dx: 130,
          dy: 0,
        );

        final n = a.normalized(rows, cols);

        expect(n.colId, cols.idAt(2));
        expect(n.dx, 0);
        expect(n.rectIn(rows, cols), a.rectIn(rows, cols));
      },
    );

    test(
      'when re-normalizing an anchor on a hidden row then it moves to the visible edge',
      () {
        final a = ObjectAnchor(rowId: rows.idAt(2), colId: cols.idAt(0), dy: 5);

        final n = a.normalized(rows, cols);

        expect(n.rowId, rows.idAt(3));
        expect(n.dy, 0);
        expect(n.rectIn(rows, cols)!.top, a.rectIn(rows, cols)!.top);
      },
    );

    test(
      'when normalizing on an empty axis then it throws an ArgumentError',
      () {
        expect(
          () => ObjectAnchor.normalizeAt(
            0,
            0,
            width: 20,
            height: 20,
            rows: testAxis([]),
            columns: cols,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('Given a resized column', () {
    test(
      'when the anchor column is widened then the object keeps its anchor and px size',
      () {
        final rows = testAxis([21, 21]);
        final cols = testAxis([100, 100, 100], ns: 2);
        final a = ObjectAnchor.normalizeAt(
          150,
          10,
          width: 300,
          height: 200,
          rows: rows,
          columns: cols,
        );
        cols.upsert(cols.idAt(0), cols.sortKeyAt(0), size: 250);

        expect(a.rectIn(rows, cols), const ChartRect(300, 10, 300, 200));
      },
    );
  });
}
