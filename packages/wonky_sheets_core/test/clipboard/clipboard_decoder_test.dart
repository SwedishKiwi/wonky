import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import '../support/planner_harness.dart';
import 'support/clipboard_support.dart';

PlannerHarness _harness() {
  final b = WorkbookBuilder()..sheet('Sheet1', rows: 30, cols: 8);
  b.values('A1', [
    [1, 'a'],
    [2, 'b'],
    [3, 'c'],
  ]);
  return PlannerHarness(b);
}

void _formula(PlannerHarness h, String a1, String formula) {
  final r = h.range(a1);
  h.apply(
    SetCellInputs(
      sheetId: r.sheetId,
      row: r.rect.top,
      col: r.rect.left,
      inputs: [
        [CellInput.user(formula)],
      ],
    ),
  );
}

ClipboardContent _copy(PlannerHarness h, String a1, {bool cut = false}) =>
    ClipboardEncoder.copy(
      h.model,
      h.range(a1),
      ModelCellSource(h.model),
      clipId: 'clip-$a1',
      hooks: h.hooks,
      isCut: cut,
    );

ClipboardPasteInput _decode(
  PlannerHarness h,
  String target, {
  String? html,
  String? text,
  SheetsClipboardPayload? last,
  String? spreadsheetId,
}) {
  final r = h.range(target);
  return ClipboardDecoder.decode(
    html: html,
    text: text,
    last: last,
    targetSpreadsheetId: spreadsheetId ?? h.model.spreadsheetId,
    targetSheetId: r.sheetId,
    targetRow: r.rect.top,
    targetCol: r.rect.left,
    hooks: h.hooks,
  )!;
}

void main() {
  group('Given a formula copied inside the spreadsheet', () {
    late PlannerHarness h;
    late ClipboardContent copy;
    setUp(() {
      h = _harness();
      _formula(h, 'D1', '=SUM(A1:A3)');
      copy = _copy(h, 'D1');
    });

    test(
      'when the HTML carries the in-memory clip id then the payload is used',
      () {
        final input = _decode(h, 'E5', html: copy.html, last: copy.payload);
        expect(input.kind, ClipboardPasteKind.internal);
        expect(input.supportsInternalModes, isTrue);
        expect(input.source.sheetId, h.sheetId);
      },
    );

    test(
      'when pasting into a 2 × 2 selection then every tile is translated',
      () {
        final input = _decode(h, 'E5', html: copy.html, last: copy.payload);
        h.apply(PasteClipboard(h.range('E5:F6'), input.source));
        expect(h.formulaA1('E5'), '=SUM(B5:B7)');
        expect(h.formulaA1('F5'), '=SUM(C5:C7)');
        expect(h.formulaA1('F6'), '=SUM(C6:C8)');
      },
    );

    test(
      'when the clipboard comes from another window then the embedded payload is used',
      () {
        final input = _decode(h, 'E5', html: copy.html);
        expect(input.kind, ClipboardPasteKind.embedded);
        h.apply(PasteClipboard(h.range('E5'), input.source));
        expect(h.formulaA1('E5'), '=SUM(B5:B7)');
      },
    );

    test(
      'when only the copied plain text is on the clipboard then the payload is used',
      () {
        final r = h.range('E5');
        final input = ClipboardDecoder.decode(
          text: copy.tsv,
          last: copy.payload,
          lastText: copy.tsv,
          targetSpreadsheetId: h.model.spreadsheetId,
          targetSheetId: r.sheetId,
          targetRow: r.rect.top,
          targetCol: r.rect.left,
          hooks: h.hooks,
        )!;
        expect(input.kind, ClipboardPasteKind.internal);
      },
    );

    test('when the in-memory clip id differs then the HTML payload wins', () {
      final other = _copy(h, 'A1');
      final input = _decode(h, 'E5', html: copy.html, last: other.payload);
      expect(input.kind, ClipboardPasteKind.embedded);
      expect(input.payload!.clipId, 'clip-D1');
    });
  });

  group('Given a copy that skipped a hidden row', () {
    test('when pasting then formulas keep their relative meaning', () {
      final h = _harness();
      _formula(h, 'D1', '=A1');
      _formula(h, 'D3', '=A3');
      final rowId = h.builder.rowId(1);
      h.model.applyChanges([
        RowChange.update(
          SheetsTables.sheetRow,
          rowId,
          {Cols.hidden: false},
          {Cols.hidden: true},
        ),
      ]);
      final copy = _copy(h, 'D1:D3');
      expect(copy.payload.rowIndices, [0, 2]);
      final input = _decode(h, 'F1', html: copy.html, last: copy.payload);
      h.apply(PasteClipboard(h.range('F1'), input.source));
      expect(h.formulaA1('F1'), '=C1');
      expect(h.formulaA1('F2'), '=C2');
    });
  });

  group('Given a payload from another spreadsheet', () {
    test('when pasting then A1 formulas are re-based for every tile', () {
      final h = _harness();
      _formula(h, 'D1', '=SUM(A1:A3)');
      final copy = _copy(h, 'D1', cut: true);
      final foreign = SheetsClipboardPayload.fromJson({
        ...copy.payload.toJson(),
        'ss': 'another-spreadsheet',
        's': 'another-sheet',
      });
      final target = h.range('E5');
      final source = ClipboardDecoder.fromPayload(
        foreign,
        targetSpreadsheetId: h.model.spreadsheetId,
        targetSheetId: target.sheetId,
        targetRow: target.rect.top,
        targetCol: target.rect.left,
        hooks: h.hooks,
      );
      expect(source.isCut, isFalse, reason: 'a cut becomes a copy');
      expect(source.internal, isTrue);
      h.apply(PasteClipboard(h.range('E5:E6'), source));
      expect(h.formulaA1('E5'), '=SUM(B5:B7)');
      expect(h.formulaA1('E6'), '=SUM(B6:B8)');
    });
  });

  group('Given a cut inside the spreadsheet', () {
    test('when pasting then the cells move and the source is cleared', () {
      final h = _harness();
      final copy = _copy(h, 'A1:B1', cut: true);
      final input = _decode(h, 'E10', html: copy.html, last: copy.payload);
      expect(input.source.isCut, isTrue);
      h.apply(PasteClipboard(h.range('E10'), input.source));
      expect(h.content('E10'), 'n:1');
      expect(h.content('F10'), 's:a');
      expect(h.content('A1'), isNull);
    });
  });

  group('Given Google Sheets HTML', () {
    test(
      'when pasting at the copied position then R1C1 formulas become A1',
      () {
        final h = _harness();
        final input = _decode(
          h,
          'A1',
          html: readFixture('clipboard', 'google_sheets.html'),
        );
        expect(input.kind, ClipboardPasteKind.html);
        expect(input.supportsInternalModes, isFalse);
        h.apply(PasteClipboard(h.range('A1'), input.source));
        expect(h.content('A1'), 's:Item');
        expect(h.content('B2'), 'n:12.5');
        expect(h.cell('B2')!.format[FormatAttr.numberFormat], r'"$"#,##0.00');
        expect(h.formulaA1('C2'), '=B2*2');
        expect(h.formulaA1('C3'), '=SUM(B2:C2)');
        expect(h.cell('A2')!.note, 'Arabica');
      },
    );

    test(
      'when pasting into a taller selection then each tile gets its own references',
      () {
        final h = _harness();
        const html =
            '<google-sheets-html-origin><table><tr><td data-sheets-value='
            '"{&quot;1&quot;:3,&quot;3&quot;:2}" data-sheets-formula="=R[0]C[-1]*2">2</td>'
            '</tr></table>';
        final input = _decode(h, 'C1', html: html);
        h.apply(PasteClipboard(h.range('C1:C3'), input.source));
        expect(h.formulaA1('C1'), '=B1*2');
        expect(h.formulaA1('C3'), '=B3*2');
      },
    );
  });

  group('Given plain text only', () {
    test('when pasting then TSV fields are parsed like typing', () {
      final h = _harness();
      final input = _decode(h, 'D1', text: 'x\t1,5\n=1+1\t2026-10-14');
      expect(input.kind, ClipboardPasteKind.text);
      h.apply(PasteClipboard(h.range('D1'), input.source));
      expect(h.content('D1'), 's:x');
      expect(h.formulaA1('D2'), '=1+1');
      expect(h.content('E2'), startsWith('n:'));
    });

    test(
      'when the text is one column of CSV lines then splitting is suggested',
      () {
        final h = _harness();
        final input = _decode(h, 'D1', text: 'a,b\nc,d');
        expect(input.splitSuggestion?.delimiter, ',');
      },
    );

    test('when there is nothing to paste then null is returned', () {
      final h = _harness();
      expect(
        ClipboardDecoder.decode(
          html: '<p>no table</p>',
          targetSpreadsheetId: h.model.spreadsheetId,
          targetSheetId: h.sheetId,
          targetRow: 0,
          targetCol: 0,
        ),
        isNull,
      );
    });
  });

  group('Given formula hooks are not available', () {
    test(
      'when decoding HTML then formulas are A1 text relative to the target',
      () {
        final t = HtmlTableCodec.parse(
          readFixture('clipboard', 'google_sheets.html'),
        )!;
        final src = ClipboardDecoder.fromTable(
          t,
          targetSpreadsheetId: 'ss',
          targetSheetId: 's',
          targetRow: 10,
          targetCol: 0,
        );
        expect(src.cells[1][2]!.formulaA1, '=B12*2');
        expect(src.cells[1][2]!.storedFormula, isNull);
        expect(src.cells[1][2]!.value, const NumberValue(25));
        expect(src.merges, t.merges);
        expect(const IdentityFormulaHooks(), isA<FormulaHooks>());
      },
    );
  });
}
