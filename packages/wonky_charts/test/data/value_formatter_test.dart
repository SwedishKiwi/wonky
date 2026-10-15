import 'package:test/test.dart';
import 'package:wonky_charts/wonky_charts.dart';

void main() {
  group('Given number format patterns', () {
    for (final (pattern, isDate) in [
      ('yyyy-mm-dd', true),
      ('mmm d', true),
      ('h:mm', true),
      ('preset:date', true),
      ('[h]:mm', false),
      ('#,##0.00', false),
      ('"day" 0', false),
      ('0%', false),
      (null, false),
    ]) {
      test('when checking "$pattern" then date/time is $isDate', () {
        expect(ChartFormats.isDateTime(pattern), isDate);
      });
    }

    for (final (pattern, isPercent) in [
      ('0%', true),
      ('0.0%', true),
      ('"%"0', false),
      ('#,##0', false),
    ]) {
      test('when checking "$pattern" then percent is $isPercent', () {
        expect(ChartFormats.isPercent(pattern), isPercent);
      });
    }

    test(
      'when building tick patterns then decimals and percent are honoured',
      () {
        expect(ChartFormats.tickPattern(0), '#,##0');
        expect(ChartFormats.tickPattern(2), '#,##0.00');
        expect(ChartFormats.tickPattern(1, percent: true), '0.0%');
      },
    );
  });

  group('Given the default formatter in en_US', () {
    const fmt = DefaultChartValueFormatter();

    test(
      'when formatting with a grouping pattern then it uses the format engine',
      () {
        expect(fmt.format(1234.5, '#,##0.00'), '1,234.50');
      },
    );

    test('when formatting a percent then it is scaled', () {
      expect(fmt.format(0.25, '0%'), '25%');
    });

    test('when formatting NaN then the text is empty', () {
      expect(fmt.format(double.nan, null), '');
    });
  });
}
