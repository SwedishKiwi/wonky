import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/engine_bridge/model_cell_source.dart';
import 'package:wonky_sheets_core/src/format/attributes.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';
import 'package:wonky_sheets_core/src/formula/values/format_hint.dart';
import 'package:wonky_sheets_core/src/formula/values/fvalue.dart';
import 'package:wonky_sheets_core/src/model/workbook_model.dart';
import 'package:wonky_sheets_core/src/testing/workbook_builder.dart';

void main() {
  group(
    'Given a sheet with formatted literals and a hinted formula result',
    () {
      late WorkbookModel m;
      late String sid;
      late CellTextFormatter display;

      setUp(() {
        final b = WorkbookBuilder();
        sid = b.sheet('Sheet1', rows: 10, cols: 4);
        b.value('A1', 1234.5, format: {FormatAttr.numberFormat: '#,##0.00'});
        b.value(
          'A2',
          -5,
          format: {FormatAttr.numberFormat: '#,##0;[Red](#,##0)'},
        );
        b.value('A3', 0.25);
        b.set('A4', '=B1+1');
        m = b.build();
        // A4 is a formula: the "engine" returns a date with a date hint.
        final values = ModelCellSource(
          m,
          computed: (s, r, c) => r == 3 && c == 0 ? FNumber(46307) : null,
          formatHint: (s, r, c) =>
              r == 3 && c == 0 ? NumberFormatPresets.date : null,
        );
        display = CellTextFormatter(values);
      });

      test('when displaying an explicitly formatted number then the format '
          'applies', () {
        expect(display.textAt(sid, 0, 0), '1,234.50');
        expect(display.numberFormatAt(sid, 0, 0), '#,##0.00');
      });

      test(
        'when a section has a color then the formatted value carries it',
        () {
          final f = display.formattedAt(sid, 1, 0);

          expect(f.plainText, '(5)');
          expect(f.colorArgb, 0xFFFF0000);
        },
      );

      test('when the format is Automatic then Automatic rules apply', () {
        expect(display.textAt(sid, 2, 0), '0.25');
        expect(display.numberFormatAt(sid, 2, 0), isNull);
      });

      test('when a formula result has a date hint then it shows as a date', () {
        expect(display.textAt(sid, 3, 0), '10/12/2026');
        expect(display.valueAt(sid, 3, 0), const NumberValue(46307));
      });

      test('when the locale is German then separators follow it', () {
        final de = CellTextFormatter(display.values, locale: 'de_DE');

        expect(de.textAt(sid, 0, 0), '1.234,50');
        expect(de.textAt(sid, 3, 0), '12.10.2026');
      });

      test('when a cell is empty then the text is empty', () {
        expect(display.textAt(sid, 8, 3), '');
      });
    },
  );

  group('Given formatValue', () {
    final cases = <(String, Object, String?, FormatHint, String)>[
      ('an explicit format', 0.5, '0%', FormatHint.date, '50%'),
      ('a percent hint', 0.5, null, FormatHint.percent, '50.00%'),
      (
        'an Automatic preset id',
        0.5,
        'preset:automatic',
        FormatHint.none,
        '0.5',
      ),
      ('a duration hint', 1.5, null, FormatHint.duration, '36:00:00'),
      ('a euro hint in en_US', 3, null, FormatHint.currency('EUR'), '€3.00'),
      ('text', 'abc', null, FormatHint.date, 'abc'),
    ];
    for (final (what, value, explicit, hint, expected) in cases) {
      test('when formatting with $what then it shows "$expected"', () {
        expect(
          CellTextFormatter.formatValue(
            value,
            explicitFormat: explicit,
            hint: hint,
          ).plainText,
          expected,
        );
      });
    }

    test('when an engine number carries its own hint then it is used', () {
      expect(
        CellTextFormatter.formatValue(
          FNumber(46307, FormatHint.date),
        ).plainText,
        '10/12/2026',
      );
    });
  });
}
