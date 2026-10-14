import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/number_format/date_time_pattern.dart';
import 'package:wonky_sheets/features/number_format/recent_formats.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given date/time patterns', () {
    test('when parsing m/d/yyyy h:mm:ss then minutes follow the hour', () {
      final parts = DateTimePatternCodec.parse('m/d/yyyy h:mm:ss');
      expect(parts.where((p) => !p.isLiteral).map((p) => p.field), [
        DtField.month,
        DtField.day,
        DtField.year,
        DtField.hour,
        DtField.minute,
        DtField.second,
      ]);
    });

    test('when parsing weekday, quoted text and AM/PM then chips map 1:1', () {
      final parts = DateTimePatternCodec.parse('dddd", "mmmm d h AM/PM');
      expect(parts.first, const DtPart.token(DtField.weekday, 'dddd'));
      expect(parts[1], const DtPart.literal(', '));
      expect(parts.last, const DtPart.token(DtField.ampm, 'AM/PM'));
    });

    test('when parsing elapsed time and milliseconds then they are tokens', () {
      final parts = DateTimePatternCodec.parse('[h]:mm:ss.000');
      expect(parts.first.field, DtField.elapsedHours);
      expect(parts[2].field, DtField.minute);
      expect(parts.last, const DtPart.token(DtField.millisecond, '.000'));
    });

    for (final p in dateTimePresets) {
      test('when round-tripping "$p" then the formatted text is unchanged', () {
        final rebuilt = DateTimePatternCodec.build(
          DateTimePatternCodec.parse(p),
        );
        const v = NumberValue(39717.66456);
        expect(
          NumberFormatter.instance.formatText(v, rebuilt),
          NumberFormatter.instance.formatText(v, p),
        );
      });
    }

    test('when building a literal with letters then it is quoted', () {
      expect(
        DateTimePatternCodec.build(const [
          DtPart.token(DtField.day, 'd'),
          DtPart.literal(' of '),
          DtPart.token(DtField.month, 'mmmm'),
        ]),
        'd" of "mmmm',
      );
    });
  });

  group('Given recent custom formats', () {
    test('when noting patterns then presets are skipped and the newest is '
        'first, at most five', () {
      final model = WorkbookModel(spreadsheetId: 'x');
      RecentNumberFormats.note(model, NumberFormatPresets.currency);
      RecentNumberFormats.note(model, '#,##0.00');
      for (final p in [
        '0.0',
        '0.000',
        '#,##0,"K"',
        '0 "items"',
        'yyyy',
        '@ x',
      ]) {
        RecentNumberFormats.note(model, p);
      }
      final recent = RecentNumberFormats.of(model);
      expect(recent.first, '@ x');
      expect(recent, hasLength(5));
      expect(recent, isNot(contains('#,##0.00')));
    });
  });
}
