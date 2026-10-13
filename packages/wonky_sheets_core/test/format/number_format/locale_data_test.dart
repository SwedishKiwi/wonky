import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';

void main() {
  group('Given CLDR locale data', () {
    final cases = <(String, String, String, bool)>[
      ('en_US', '.', ',', false),
      ('de_DE', ',', '.', false),
      ('fr_FR', ',', ' ', false),
      ('ja_JP', '.', ',', false),
      ('en_IN', '.', ',', true),
      ('hi_IN', '.', ',', true),
      ('de_CH', '.', "'", false),
    ];
    for (final (id, dec, group, indian) in cases) {
      test(
        'when loading $id then decimal, grouping and Indian grouping match',
        () {
          final l = LocaleFormatData.forId(id);
          expect((
            l.decimal,
            l.group,
            l.indianGrouping,
            l.minus,
          ), equals((dec, group, indian, '-')));
        },
      );
    }

    test(
      'when loading de_DE then names, AM/PM and currency come from CLDR',
      () {
        final l = LocaleFormatData.forId('de_DE');
        expect((
          l.months[9],
          l.weekdays[1],
          l.currencyCode,
          l.currencySymbol,
          l.currencyBefore,
        ), equals(('Oktober', 'Montag', 'EUR', '€', false)));
      },
    );

    test('when loading ja_JP then AM/PM markers are Japanese', () {
      final l = LocaleFormatData.forId('ja_JP');
      expect((
        l.am,
        l.pm,
        l.dateOrder,
      ), equals(('午前', '午後', DatePartOrder.ymd)));
    });

    test(
      'when loading a region intl only knows by language then the region currency is used',
      () {
        expect(LocaleFormatData.forId('ar_SA').currencyCode, equals('SAR'));
      },
    );

    test('when loading an unknown locale then en_US data is used', () {
      expect(LocaleFormatData.forId('xx_YY').decimal, equals('.'));
    });

    test('when using a dash locale id then it is normalized', () {
      expect(LocaleFormatData.forId('de-DE').decimal, equals(','));
    });
  });

  group('Given the LCID map', () {
    final cases = <(int, String)>[
      (0x409, 'en_US'),
      (0x407, 'de_DE'),
      (0x40C, 'fr_FR'),
      (0x411, 'ja_JP'),
      (0x807, 'de_CH'),
      (0x4009, 'en_IN'),
      (0x809, 'en_GB'),
    ];
    for (final (lcid, id) in cases) {
      test(
        'when mapping 0x${lcid.toRadixString(16)} then it is $id and back',
        () {
          expect(LocaleFormatData.localeIdForLcid(lcid), equals(id));
          expect(LocaleFormatData.lcidOf(id), equals(lcid));
        },
      );
    }

    test('when the map is listed then it covers at least 120 LCIDs', () {
      expect(LocaleFormatData.lcidLocales.length, greaterThanOrEqualTo(120));
    });

    test('when a bare language is mapped then its default region is used', () {
      expect(LocaleFormatData.lcidOf('de'), equals(0x407));
    });
  });

  group('Given locale-dependent formatting', () {
    final f = NumberFormatter();
    final cases = <(String, String, double, String)>[
      ('#,##0.00', 'en_IN', 1234567.5, '12,34,567.50'),
      ('#,##0', 'hi_IN', 123456789, '12,34,56,789'),
      ('#,##0.00', 'de_CH', 1234567.5, "1'234'567.50"),
      ('#,##0.00', 'ja_JP', 1234567.5, '1,234,567.50'),
      ('0.0%', 'de_DE', 0.125, '12,5%'),
      ('0.00E+00', 'de_DE', 1234, '1,23E+03'),
      ('h:mm AM/PM', 'ja_JP', 0.75, '6:00 午後'),
      ('dddd d mmmm yyyy', 'fr_FR', 46307, 'lundi 12 octobre 2026'),
      ('ddd', 'de_DE', 46307, 'Mo.'),
      ('mmmm yyyy', 'ru_RU', 46307, 'октябрь 2026'),
      ('d mmmm', 'ru_RU', 46307, '12 октября'),
      (r'[$-407]dddd', 'en_US', 46307, 'Montag'),
      (r'[$-411]AM/PM h', 'en_US', 0.75, '午後 6'),
      ('preset:dateTime', 'de_DE', 46307.75, '12.10.2026 18:00:00'),
      ('preset:time', 'en_US', 0.75, '6:00:00 PM'),
      ('preset:currencyRounded', 'en_US', 1000.5, r'$1,001'),
      ('preset:currency', 'ja_JP', 1234.4, '¥1,234'),
      ('preset:currency', 'en_IN', 1234567, '₹12,34,567.00'),
      ('preset:automatic', 'de_DE', 1.5, '1,5'),
    ];
    for (final (pattern, locale, value, expected) in cases) {
      test(
        'when formatting $value with "$pattern" in $locale then it shows "$expected"',
        () {
          expect(
            f.formatText(NumberValue(value), pattern, locale: locale),
            equals(expected),
          );
        },
      );
    }
  });
}
