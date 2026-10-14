import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';

import '../support/planner_harness.dart';

MutationPlan _roundTrip(PlannerHarness h, SheetsOperation op) {
  final before = h.dump();
  final p = h.apply(op);
  h.undo();
  expect(h.dump(), before, reason: 'undo restores the model');
  h.model.applyPlan(p);
  h.history.add(p);
  return p;
}

List<String?> _column(PlannerHarness h, String col, int from, int to) => [
  for (var r = from; r <= to; r++) h.content('$col$r'),
];

void _input(PlannerHarness h, String a1, String text) {
  final r = h.range(a1);
  h.apply(
    SetCellInputs(
      sheetId: r.sheetId,
      row: r.rect.top,
      col: r.rect.left,
      inputs: [
        [CellInput.user(text)],
      ],
    ),
  );
}

PlannerHarness _harness() =>
    PlannerHarness(WorkbookBuilder()..sheet('Sheet1', rows: 12, cols: 6));

void main() {
  group('Given sources for the fill handle (03 §10)', () {
    test(
      'when filling 1, 3 down then the step continues and undo restores',
      () {
        final h = _harness();
        _input(h, 'A1', '1');
        _input(h, 'A2', '3');
        final p = _roundTrip(
          h,
          FillSeries(
            h.sheetId,
            const GridRect(0, 0, 1, 0),
            const GridRect(0, 0, 4, 0),
          ),
        );
        expect(p.label, 'Fill series');
        expect(p.result['cells'], 3);
        expect(_column(h, 'A', 3, 5), ['n:5', 'n:7', 'n:9']);
      },
    );

    test('when filling Mon down then the weekdays continue cyclically', () {
      final h = _harness();
      _input(h, 'A1', 'Mon');
      _roundTrip(
        h,
        FillSeries(
          h.sheetId,
          const GridRect(0, 0, 0, 0),
          const GridRect(0, 0, 8, 0),
        ),
      );
      expect(_column(h, 'A', 2, 9), [
        's:Tue',
        's:Wed',
        's:Thu',
        's:Fri',
        's:Sat',
        's:Sun',
        's:Mon',
        's:Tue',
      ]);
    });

    test('when filling a formula down then references are translated', () {
      final h = _harness();
      _input(h, 'B1', '=A1*2');
      _roundTrip(
        h,
        FillSeries(
          h.sheetId,
          const GridRect(0, 1, 0, 1),
          const GridRect(0, 1, 3, 1),
        ),
      );
      expect(h.formulaA1('B2'), '=A2*2');
      expect(h.formulaA1('B4'), '=A4*2');
    });

    test('when filling up then the series extends backwards', () {
      final h = _harness();
      _input(h, 'A5', '10');
      _input(h, 'A6', '20');
      _roundTrip(
        h,
        FillSeries(
          h.sheetId,
          const GridRect(4, 0, 5, 0),
          const GridRect(2, 0, 5, 0),
        ),
      );
      expect(_column(h, 'A', 3, 4), ['n:-10', 'n:0']);
    });

    test('when filling right then each row is filled independently', () {
      final h = _harness();
      _input(h, 'A1', 'Item 1');
      _input(h, 'A2', 'x');
      _roundTrip(
        h,
        FillSeries(
          h.sheetId,
          const GridRect(0, 0, 1, 0),
          const GridRect(0, 0, 1, 2),
        ),
      );
      expect(h.content('C1'), 's:Item 3');
      expect(h.content('C2'), 's:x');
    });

    test(
      'when filling in copy mode then a single number is a series and others copy',
      () {
        final h = _harness();
        _input(h, 'A1', '5');
        final p = _roundTrip(
          h,
          FillSeries(
            h.sheetId,
            const GridRect(0, 0, 0, 0),
            const GridRect(0, 0, 2, 0),
            mode: FillMode.copy,
          ),
        );
        expect(p.label, 'Fill');
        expect(_column(h, 'A', 2, 3), ['n:6', 'n:7']);
      },
    );

    test('when filling then formats are copied but notes are not', () {
      final h = _harness();
      _input(h, 'A1', '1');
      h.apply(SetFormat([h.range('A1')], {FormatAttr.bold: true}));
      h.apply(SetNote(h.sheetId, 0, 0, 'note'));
      _input(h, 'A2', 'old');
      h.apply(SetFormat([h.range('A2')], {FormatAttr.italic: true}));
      _roundTrip(
        h,
        FillSeries(
          h.sheetId,
          const GridRect(0, 0, 0, 0),
          const GridRect(0, 0, 1, 0),
        ),
      );
      final c = h.cell('A2')!;
      expect(c.content, 'n:1');
      expect(c.format[FormatAttr.bold], isTrue);
      expect(c.format[FormatAttr.italic], isNull);
      expect(c.note, isNull);
    });

    test(
      'when the target grows in both directions then the active cell fills the whole block',
      () {
        final h = _harness();
        _input(h, 'B2', '=A1');
        _roundTrip(
          h,
          FillSeries(
            h.sheetId,
            const GridRect(1, 1, 1, 1),
            const GridRect(0, 0, 2, 2),
            mode: FillMode.copy,
            label: 'Fill selection',
          ),
        );
        expect(h.formulaA1('C3'), '=B2');
        expect(h.formulaA1('B1'), contains('#REF!'));
        expect(h.formulaA1('A3'), contains('#REF!'));
      },
    );

    test('when the target is inside the source then nothing changes', () {
      final h = _harness();
      _input(h, 'A1', '1');
      _input(h, 'A2', '2');
      final p = h.plan(
        FillSeries(
          h.sheetId,
          const GridRect(0, 0, 1, 0),
          const GridRect(0, 0, 0, 0),
        ),
      );
      expect(p.changes, isEmpty);
    });

    test('when the target leaves the grid then it is refused', () {
      final h = _harness();
      expect(
        () => h.plan(
          FillSeries(
            h.sheetId,
            const GridRect(0, 0, 0, 0),
            const GridRect(0, 0, 50, 0),
          ),
        ),
        throwsA(
          isA<PlanException>().having((e) => e.code, 'code', 'invalid_range'),
        ),
      );
    });
  });
}
