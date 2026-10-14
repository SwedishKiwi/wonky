import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given typed values', () {
    const cases = [
      (TextValue('hi "x"'), '{"1":2,"2":"hi \\"x\\""}'),
      (NumberValue(3), '{"1":3,"3":3}'),
      (NumberValue(1.5), '{"1":3,"3":1.5}'),
      (BoolValue(true), '{"1":4,"4":1}'),
      (BoolValue(false), '{"1":4,"4":0}'),
    ];
    for (final (value, json) in cases) {
      test('when encoding $value then data-sheets-value is $json', () {
        expect(SheetsHtmlAttrs.encodeValue(value), json);
        expect(SheetsHtmlAttrs.decodeValue(json), value);
      });
    }

    test('when encoding empty values and errors then nothing is written', () {
      expect(SheetsHtmlAttrs.encodeValue(const EmptyValue()), isNull);
      expect(
        SheetsHtmlAttrs.encodeValue(const ErrorValue(CellErrorKind.na)),
        isNull,
      );
    });

    test('when decoding malformed JSON then null is returned', () {
      expect(SheetsHtmlAttrs.decodeValue('{nope'), isNull);
      expect(SheetsHtmlAttrs.decodeValue('{"1":3,"3":"x"}'), isNull);
      expect(SheetsHtmlAttrs.decodeValue(null), isNull);
    });
  });

  group('Given number format patterns', () {
    const cases = [
      ('@', 1),
      ('#,##0.00', 2),
      ('0.0%', 3),
      (r'"$"#,##0.00', 4),
      ('yyyy-mm-dd', 5),
      ('h:mm:ss', 6),
      ('M/d/yyyy H:mm:ss', 7),
      ('0.00E+00', 8),
    ];
    for (final (pattern, type) in cases) {
      test('when encoding "$pattern" then the Google type is $type', () {
        final json = SheetsHtmlAttrs.encodeNumberFormat(pattern);
        expect(json, contains('"1":$type'));
        expect(SheetsHtmlAttrs.decodeNumberFormat(json), pattern);
      });
    }

    test('when exchanging presets then en_US patterns are used', () {
      expect(SheetsHtmlAttrs.interchangePattern('preset:date'), 'M/d/yyyy');
      expect(SheetsHtmlAttrs.interchangePattern('preset:automatic'), isNull);
      expect(SheetsHtmlAttrs.interchangePattern('preset:unknown'), isNull);
      expect(SheetsHtmlAttrs.interchangePattern('0.00'), '0.00');
    });

    test('when decoding a text type without pattern then it is @', () {
      expect(SheetsHtmlAttrs.decodeNumberFormat('{"1":1}'), '@');
    });
  });
}
