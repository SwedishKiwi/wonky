import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/planner_harness.dart';

void main() {
  group('Given 6,000 rows', () {
    late PlannerHarness h;
    setUp(() {
      const n = 6000;
      final b = WorkbookBuilder()..sheet('Sheet1', rows: n, cols: 3);
      b.values('A1', [
        for (var r = 0; r < n; r++)
          [(r * 7919) % n, 'name ${r % 97}', '=A${r + 1}*2'],
      ]);
      h = PlannerHarness(b);
    });

    List<double> progressOf(
      Iterable<Object> steps,
      void Function(MutationPlan) last,
    ) {
      final out = <double>[];
      for (final x in steps) {
        if (x is double) out.add(x);
        if (x is MutationPlan) last(x);
      }
      return out;
    }

    for (final (name, op)
        in <(String, SheetsOperation Function(PlannerHarness))>[
          (
            'sort (whole rows)',
            (h) => SortRange(
              ResolvedRange(
                h.sheetId,
                const GridRect(0, 0, 5999, 2),
                wholeRows: true,
              ),
              [SortKeySpec(h.model.sheets.first.columns.idAt(0))],
            ),
          ),
          (
            'remove duplicates (content move)',
            (h) => RemoveDuplicates(
              ResolvedRange(h.sheetId, const GridRect(0, 0, 5999, 2)),
              colIds: [h.model.sheets.first.columns.idAt(1)],
            ),
          ),
        ]) {
      test('when $name is planned in steps then progress rises to 1 and the '
          'plan equals the one-shot plan', () {
        MutationPlan? stepped;
        final progress = progressOf(
          const SheetsMutationPlanner().steps(op(h), h.model, h.ctx),
          (p) => stepped = p,
        );
        final once = h.plan(op(h));
        expect(progress.length, greaterThan(2));
        for (var i = 1; i < progress.length; i++) {
          expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
        }
        expect(progress.last, lessThanOrEqualTo(1));
        expect(stepped!.changes.length, once.changes.length);
        expect(stepped!.result, once.result);
      });
    }

    test('when a plan is offered for an op then the next plan of that op '
        'returns it once, and other models plan anew', () {
      final op = RandomizeRange(
        ResolvedRange(h.sheetId, const GridRect(0, 0, 9, 2)),
      );
      final made = h.plan(op);
      SheetsMutationPlanner.offer(op, h.model, made);
      expect(identical(h.plan(op), made), isTrue);
      expect(identical(h.plan(op), made), isFalse);
      SheetsMutationPlanner.offer(op, WorkbookBuilder().build(), made);
      expect(identical(h.plan(op), made), isFalse);
    });
  });
}
