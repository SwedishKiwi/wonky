import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/planner_harness.dart';

void main() {
  group('Given a model bound to the formula engine', () {
    late PlannerHarness h;
    late ModelEngineBinding binding;
    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 3);
      b.values('A1', [
        [1],
        [2],
        [3],
      ]);
      h = PlannerHarness(b);
      binding = ModelEngineBinding.create(h.model);
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 4,
          col: 0,
          inputs: [
            [const CellInput.user('=SUM(A1:A3)')],
          ],
        ),
      );
    });
    tearDown(() => binding.dispose());

    test('when a precedent changes then the formula value updates', () {
      expect(
        binding.engine.valueAt(h.sheetId, 4, 0).toCellValue(),
        const NumberValue(6),
      );
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: 0,
          col: 0,
          inputs: [
            [const CellInput.user('10')],
          ],
        ),
      );
      expect(
        binding.engine.valueAt(h.sheetId, 4, 0).toCellValue(),
        const NumberValue(15),
      );
    });

    test('when a row inside the range is deleted then the sum shrinks', () {
      final s = h.model.sheets.first;
      h.apply(DeleteDimension(s.id, Dimension.rows, [s.rows.idAt(1)]));
      expect(
        binding.engine.valueAt(h.sheetId, 3, 0).toCellValue(),
        const NumberValue(4),
      );
    });

    test(
      'when a CF custom formula is evaluated relative to an anchor then offsets apply',
      () {
        final hooks = EngineFormulaHooks(h.model, engine: binding.engine);
        final stored = hooks.toStored(
          '=A1>1',
          sheetId: h.sheetId,
          row: 0,
          col: 1,
        );
        expect(
          hooks
              .evaluateRelative(
                stored,
                sheetId: h.sheetId,
                anchorRow: 0,
                anchorCol: 1,
                row: 0,
                col: 1,
              )
              .toCellValue(),
          const BoolValue(false),
        );
        expect(
          hooks
              .evaluateRelative(
                stored,
                sheetId: h.sheetId,
                anchorRow: 0,
                anchorCol: 1,
                row: 2,
                col: 1,
              )
              .toCellValue(),
          const BoolValue(true),
        );
      },
    );

    test(
      'when running maintenance on a consistent workbook then the plan is empty',
      () {
        expect(WorkbookMaintenance.plan(h.model, h.ctx).isEmpty, isTrue);
      },
    );
  });

  group('Given a model bound to the formula engine and structural changes', () {
    late PlannerHarness h;
    late ModelEngineBinding binding;
    FValue v(String a1) {
      final r = h.range(a1);
      return binding.engine.valueAt(r.sheetId, r.rect.top, r.rect.left);
    }

    void input(String a1, String text) {
      final r = h.range(a1);
      h.apply(
        SetCellInputs(
          sheetId: h.sheetId,
          row: r.rect.top,
          col: r.rect.left,
          inputs: [
            [CellInput.user(text)],
          ],
        ),
      );
    }

    String rowId(int index) => h.model.sheets.first.rows.idAt(index);

    setUp(() {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 12, cols: 4);
      b.values('A1', [
        [1],
        [2],
        [3],
      ]);
      h = PlannerHarness(b);
      binding = ModelEngineBinding.create(h.model);
      input('A5', '=SUM(A1:A3)');
      input('B5', '=A3*10');
      input('C5', '=INDEX(A1:A3, 1)');
      input('D5', '=A1');
    });
    tearDown(() => binding.dispose());

    test('when rows are inserted inside the range then it grows', () {
      expect(v('A5'), const FNumber(6));
      h.apply(InsertDimension(h.sheetId, Dimension.rows, 1, 2));
      expect(h.formulaA1('A7'), '=SUM(A1:A5)');
      input('A2', '10');
      expect(v('A7'), const FNumber(16));
      expect(v('B7'), const FNumber(30));
    });

    test(
      'when non-contiguous rows are deleted then ranges shrink and single references fail',
      () {
        expect(v('D5'), const FNumber(1));
        h.apply(
          DeleteDimension(h.sheetId, Dimension.rows, [rowId(0), rowId(2)]),
        );
        // A1 and A3 are gone: the range shrinks to the old A2, the single
        // references on deleted rows become #REF!.
        expect(h.formulaA1('A3'), '=SUM(A1:A1)');
        expect(v('A3'), const FNumber(2));
        expect(v('B3'), isA<FError>());
        expect(v('D3'), isA<FError>());
      },
    );

    test('when rows are moved then references follow the data', () {
      expect(v('C5'), const FNumber(1));
      // A3 moves above A1.
      h.apply(MoveDimension(h.sheetId, Dimension.rows, [rowId(2)], rowId(0)));
      expect(h.formulaA1('B5'), '=A1*10');
      expect(v('B5'), const FNumber(30));
      // The range follows its endpoint ids: old A1 (now A2) to old A3 (now A1).
      expect(h.formulaA1('A5'), '=SUM(A1:A2)');
      expect(v('A5'), const FNumber(4));
      expect(v('C5'), const FNumber(3));
    });

    test(
      'when rows in two separate ranges are deleted then both sums shrink',
      () {
        for (var r = 4; r <= 8; r++) {
          input('A$r', '$r');
        }
        input('C10', '=SUM(A1:A3)');
        input('C11', '=SUM(A6:A8)');
        expect(v('C10'), const FNumber(6));
        expect(v('C11'), const FNumber(21));
        h.apply(
          DeleteDimension(h.sheetId, Dimension.rows, [rowId(1), rowId(6)]),
        );
        expect(v('C8'), const FNumber(4));
        expect(v('C9'), const FNumber(14));
      },
    );

    test(
      'when one remote batch deletes and moves rows then the engine sees both',
      () {
        // A twin model (same ids) plans the changes; they arrive as one batch.
        final twin = PlannerHarness(h.builder);
        for (final (a1, text) in [
          ('A5', '=SUM(A1:A3)'),
          ('B5', '=A3*10'),
          ('C5', '=INDEX(A1:A3, 1)'),
          ('D5', '=A1'),
        ]) {
          final r = twin.range(a1);
          twin.apply(
            SetCellInputs(
              sheetId: twin.sheetId,
              row: r.rect.top,
              col: r.rect.left,
              inputs: [
                [CellInput.user(text)],
              ],
            ),
          );
        }
        final ts = twin.model.sheets.first;
        final delete = twin.apply(
          DeleteDimension(twin.sheetId, Dimension.rows, [ts.rows.idAt(8)]),
        );
        final move = twin.apply(
          MoveDimension(twin.sheetId, Dimension.rows, [
            ts.rows.idAt(2),
          ], ts.rows.idAt(0)),
        );
        expect(v('C5'), const FNumber(1));
        h.model.applyChanges([...delete.changes, ...move.changes]);
        expect(v('C5'), const FNumber(3));
        expect(v('A5'), const FNumber(4));
        expect(v('B5'), const FNumber(30));
      },
    );

    test('when a row delete is undone then the references compute again', () {
      h.apply(DeleteDimension(h.sheetId, Dimension.rows, [rowId(2)]));
      expect(v('B4'), isA<FError>());
      expect(v('A4'), const FNumber(3));
      h.undo();
      expect(h.formulaA1('B5'), '=A3*10');
      expect(v('B5'), const FNumber(30));
      expect(v('A5'), const FNumber(6));
    });

    test(
      'when random structural changes are applied then the bound engine agrees with a fresh one',
      () {
        final random = Random(7);
        input('B1', '=SUM(A:A)');
        input('B2', '=ROW()+A2');
        input('C1', '=COUNTA(A1:A4)');
        for (var step = 0; step < 40; step++) {
          final s = h.model.sheets.first;
          final n = s.rows.length;
          switch (random.nextInt(5)) {
            case 0:
              h.apply(
                InsertDimension(
                  h.sheetId,
                  Dimension.rows,
                  random.nextInt(n),
                  1 + random.nextInt(2),
                ),
              );
            case 1 when n > 8:
              final ids = {
                for (var k = 0; k < 2; k++) s.rows.idAt(random.nextInt(n)),
              }.toList();
              h.apply(DeleteDimension(h.sheetId, Dimension.rows, ids));
            case 2:
              final from = random.nextInt(n);
              final to = random.nextInt(n);
              if (from != to) {
                h.apply(
                  MoveDimension(h.sheetId, Dimension.rows, [
                    s.rows.idAt(from),
                  ], s.rows.idAt(to)),
                );
              }
            case 3:
              if (h.history.isNotEmpty) h.undo();
            default:
              input('A${1 + random.nextInt(6)}', '${random.nextInt(100)}');
          }
          final fresh = ModelEngineBinding.create(h.model);
          final sheet = h.model.sheets.first;
          for (var r = 0; r < sheet.rows.length; r++) {
            for (var c = 0; c < sheet.columns.length; c++) {
              final expected = fresh.engine.valueAt(h.sheetId, r, c);
              final actual = binding.engine.valueAt(h.sheetId, r, c);
              expect(
                FValues.sameValue(actual, expected),
                isTrue,
                reason:
                    'step $step at ${CellPos(r, c).a1}: '
                    '${actual.debugText} vs ${expected.debugText}',
              );
            }
          }
          fresh.dispose();
        }
      },
    );
  });
}
