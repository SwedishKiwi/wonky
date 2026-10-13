import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/src/clipboard/clipboard.dart';

void main() {
  group('Given a clipboard payload with cells, merges and rules', () {
    late SheetsClipboardPayload payload;
    setUp(() {
      payload = SheetsClipboardPayload(
        clipId: 'clip-1',
        spreadsheetId: 'ss-1',
        sheetId: 'sheet-1',
        sheetName: 'Q3 plan',
        locale: 'de_DE',
        sourceRect: const GridRect(1, 1, 3, 2),
        sourceRange: const GridRange(
          sheetId: 'sheet-1',
          r1: 'r1',
          r2: 'r3',
          c1: 'c1',
          c2: 'c2',
        ),
        rowIndices: const [1, 3],
        colIndices: const [1, 2],
        cells: [
          [
            ClipCell(
              sourceRow: 1,
              sourceCol: 1,
              content: '=SUM(A1:A2)',
              value: const NumberValue(3),
              formulaA1: '=SUM(A1:A2)',
              format: CellFormat({
                FormatAttr.bold: true,
                FormatAttr.linkUrl: 'https://x.test',
              }),
              note: 'Total',
            ),
            null,
          ],
          [
            null,
            ClipCell(
              sourceRow: 3,
              sourceCol: 2,
              content: 's:hé "x"',
              value: const TextValue('hé "x"'),
            ),
          ],
        ],
        merges: const [GridRect(0, 0, 0, 1)],
        rules: const [
          ClipRule(
            kind: ClipRuleKind.dataValidation,
            columns: {'criteriaJson': '{"type":"checkbox"}', 'strict': false},
            rects: [GridRect(0, 0, 1, 1)],
            anchorRow: 1,
            anchorCol: 1,
            sourceRuleId: 'dv-1',
          ),
        ],
        columnWidths: const [120, null],
        rowHeights: const [null, 30],
        isCut: true,
      );
    });

    test('when encoding to JSON and back then every field round-trips', () {
      final back = SheetsClipboardPayload.decodeJson(payload.encodeJson());
      expect(back.toJson(), equals(payload.toJson()));
      expect(back.cellAt(0, 0), equals(payload.cellAt(0, 0)));
      expect(back.cellAt(1, 1)!.value, const TextValue('hé "x"'));
      expect(back.merges, [const GridRect(0, 0, 0, 1)]);
      expect(back.rules.single.columns['criteriaJson'], '{"type":"checkbox"}');
      expect(back.columnWidths, [120, null]);
      expect(back.rowHeights, [null, 30]);
      expect(back.isCut, isTrue);
    });

    test('when encoding to base64 and back then the payload is equal', () {
      final b64 = payload.encodeBase64();
      expect(b64, matches(RegExp(r'^[A-Za-z0-9+/=]+$')));
      final back = SheetsClipboardPayload.decodeBase64(b64);
      expect(back.encodeJson(), payload.encodeJson());
    });

    test('when decoding malformed base64 then tryDecode returns null', () {
      expect(SheetsClipboardPayload.tryDecodeBase64('not base64 !!'), isNull);
      expect(SheetsClipboardPayload.tryDecodeBase64('e30='), isNull); // {}
    });

    test('when marking as copied then only the cut flag changes', () {
      final copy = payload.withCut(false);
      expect(copy.isCut, isFalse);
      expect(copy.cells, same(payload.cells));
    });
  });
}
