import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';

void main() {
  group('Given preset ids resolved per locale', () {
    final cases = <(String, String, String?)>[
      ('preset:automatic', 'en_US', null),
      ('preset:currency', 'en_US', r'"$"#,##0.00'),
      ('preset:currency', 'de_DE', r'#,##0.00 [$€-407]'),
      ('preset:currencyRounded', 'en_US', r'"$"#,##0'),
      ('preset:currencyRounded', 'de_DE', r'#,##0 [$€-407]'),
      (
        'preset:accounting',
        'en_US',
        r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
      ),
      (
        'preset:accounting',
        'de_DE',
        r'_-* #,##0.00 [$€-407]_-;-* #,##0.00 [$€-407]_-;_-* "-"?? [$€-407]_-;_-@_-',
      ),
      ('preset:date', 'en_US', 'M/d/yyyy'),
      ('preset:date', 'de_DE', 'dd.MM.yyyy'),
      ('preset:time', 'en_US', 'h:mm:ss AM/PM'),
      ('preset:time', 'de_DE', 'HH:mm:ss'),
      ('preset:dateTime', 'en_US', 'M/d/yyyy H:mm:ss'),
      ('preset:dateTime', 'de_DE', 'dd.MM.yyyy HH:mm:ss'),
      ('preset:date', 'en_GB', 'dd/MM/yyyy'),
      ('preset:date', 'ja_JP', 'yyyy/MM/dd'),
      ('preset:date', 'fr_FR', 'dd/MM/yyyy'),
      ('preset:currency', 'fr_FR', r'#,##0.00 [$€-40C]'),
      ('preset:currency', 'ja_JP', r'[$¥-411]#,##0'),
      ('preset:currency', 'en_GB', r'[$£-809]#,##0.00'),
      ('preset:currency', 'de_CH', r'[$CHF-807] #,##0.00'),
      ('preset:currency', 'pt_BR', r'[$R$-416] #,##0.00'),
      ('preset:time', 'ko_KR', 'AM/PM h:mm:ss'),
      ('preset:time', 'fr_CA', 'HH "h" mm "min" ss "s"'),
      ('preset:unknown', 'en_US', null),
      ('0.00', 'de_DE', '0.00'),
    ];
    for (final (id, locale, pattern) in cases) {
      test('when resolving $id for $locale then the pattern is $pattern', () {
        expect(NumberFormatPresets.resolve(id, locale), equals(pattern));
      });
    }
  });

  group('Given the 40 most common locales', () {
    const locales = [
      'en_US',
      'en_GB',
      'en_CA',
      'en_AU',
      'en_IN',
      'de_DE',
      'de_AT',
      'de_CH',
      'fr_FR',
      'fr_CA', //
      'fr_CH',
      'es_ES',
      'es_MX',
      'it_IT',
      'pt_BR',
      'pt_PT',
      'nl_NL',
      'sv_SE',
      'nb_NO',
      'da_DK', //
      'fi_FI',
      'pl_PL',
      'cs_CZ',
      'hu_HU',
      'ro_RO',
      'ru_RU',
      'uk_UA',
      'tr_TR',
      'el_GR',
      'he_IL', //
      'ar_SA',
      'hi_IN',
      'th_TH',
      'vi_VN',
      'id_ID',
      'ja_JP',
      'ko_KR',
      'zh_CN',
      'zh_TW',
      'zh_HK', //
    ];
    for (final locale in locales) {
      test(
        'when resolving every preset in $locale then each pattern parses and formats',
        () {
          final f = NumberFormatter();
          for (final id in NumberFormatPresets.presetIds.skip(1)) {
            final p = NumberFormatPresets.resolve(id, locale)!;
            expect(NumberFormatParser.validate(p), isNull, reason: '$id → $p');
            expect(
              f.formatText(const NumberValue(46307.5), id, locale: locale),
              isNotEmpty,
            );
          }
        },
      );
    }
  });

  group('Given ICU pattern conversion', () {
    final cases = <(String, String)>[
      ("d 'de' MMMM 'de' y", 'd "de" MMMM "de" yyyy'),
      ('EEEE, MMMM d, y', 'dddd, MMMM d, yyyy'),
      ('h:mm a', 'h:mm AM/PM'),
      ('HH:mm:ss zzzz', 'HH:mm:ss'),
      ("h 'o''clock'", 'h "o\'clock"'),
      ("''h", r"\'h"),
    ];
    for (final (icu, pattern) in cases) {
      test('when converting "$icu" then it becomes "$pattern"', () {
        expect(NumberFormatPresets.icuToPattern(icu), equals(pattern));
      });
    }
  });

  group('Given the menu and shortcuts', () {
    test('when listing the menu then it has the 13 entries of 06 §5.1', () {
      expect(
        NumberFormatPresets.menu.map((m) => m.id),
        equals([
          'automatic',
          'plainText',
          'number',
          'percent',
          'scientific',
          'accounting',
          'financial', //
          'currency', 'currencyRounded', 'date', 'time', 'dateTime', 'duration',
        ]),
      );
    });

    final examples = <(String, String)>[
      ('number', '1,000.12'),
      ('percent', '10.12%'),
      ('scientific', '1.01E+03'),
      ('financial', '(1,000.12)'),
      ('currency', r'$1,000.12'),
      ('currencyRounded', r'$1,000'),
      ('date', '9/26/2008'),
      ('time', '3:59:00 PM'),
      ('dateTime', '9/26/2008 15:59:00'),
      ('duration', '24:01:00'),
    ];
    for (final (id, text) in examples) {
      test('when rendering the $id example in en_US then it shows "$text"', () {
        final item = NumberFormatPresets.menu.firstWhere((m) => m.id == id);
        expect(
          NumberFormatter().formatText(
            NumberValue(item.exampleValue),
            item.stored,
          ),
          equals(text),
        );
      });
    }

    test('when asking a menu item for its example then it is formatted in '
        'the locale', () {
      final currency = NumberFormatPresets.menu.firstWhere(
        (m) => m.id == 'currency',
      );

      expect(currency.example(), r'$1,000.12');
      expect(currency.example(locale: 'de_DE'), '1.000,12 €');
    });

    test('when looking up Mod+Shift+4 then it is the currency preset', () {
      expect(NumberFormatPresets.shortcutFormats[4], equals('preset:currency'));
    });
  });

  group('Given format classification', () {
    final cases = <(String?, NumberFormatKind, int)>[
      (null, NumberFormatKind.automatic, 0),
      ('General', NumberFormatKind.automatic, 0),
      ('#,##0.00', NumberFormatKind.number, 2),
      ('0.0%', NumberFormatKind.percent, 1),
      (r'"$"#,##0.00', NumberFormatKind.currency, 2),
      (r'[$€-407]#,##0', NumberFormatKind.currency, 0),
      ('preset:currency', NumberFormatKind.currency, 2),
      ('0.00E+00', NumberFormatKind.scientific, 2),
      ('# ?/?', NumberFormatKind.fraction, 0),
      ('yyyy-mm-dd', NumberFormatKind.date, 0),
      ('preset:date', NumberFormatKind.date, 0),
      ('h:mm:ss.000', NumberFormatKind.time, 3),
      ('preset:dateTime', NumberFormatKind.dateTime, 0),
      ('[h]:mm:ss', NumberFormatKind.duration, 0),
      ('@', NumberFormatKind.text, 0),
      ('[Colr]0', NumberFormatKind.automatic, 0),
    ];
    for (final (p, kind, decimals) in cases) {
      test(
        'when classifying $p then it is ${kind.name} with $decimals decimals',
        () {
          final info = NumberFormatInfo.of(p);
          expect((info.kind, info.decimals), equals((kind, decimals)));
        },
      );
    }

    test(
      'when checking helpers then date/time/percent/currency predicates agree',
      () {
        expect([
          NumberFormatInfo.isDatePattern('d.m.yy'),
          NumberFormatInfo.isTimePattern('[h]:mm'),
          NumberFormatInfo.isPercentPattern('0%'),
          NumberFormatInfo.isCurrencyPattern('#,##0'),
        ], equals([true, true, true, false]));
      },
    );
  });

  group('Given the format-hint presets the engine reports', () {
    final cases = <(String, String, String?)>[
      ('preset:percent', 'en_US', '0.00%'),
      ('preset:scientific', 'en_US', '0.00E+00'),
      ('preset:duration', 'en_US', '[h]:mm:ss'),
      ('preset:cur', 'en_US', r'"$"#,##0.00'),
      ('preset:cur', 'de_DE', r'#,##0.00 [$€-407]'),
      ('preset:cur:EUR', 'de_DE', r'#,##0.00 [$€-407]'),
      ('preset:cur:EUR', 'en_US', r'[$€-409]#,##0.00'),
      ('preset:cur:XYZ', 'en_US', r'[$XYZ-409]#,##0.00'),
      ('preset:unknown', 'en_US', null),
    ];
    for (final (id, locale, pattern) in cases) {
      test('when resolving $id for $locale then the pattern is $pattern', () {
        expect(NumberFormatPresets.resolve(id, locale), pattern);
      });
    }

    test('when formatting with a hint preset then it is not Automatic', () {
      final f = NumberFormatter();

      expect(f.formatText(const NumberValue(0.5), 'preset:percent'), '50.00%');
      expect(
        f.formatText(const NumberValue(1.5), 'preset:duration'),
        '36:00:00',
      );
      expect(
        f.formatText(const NumberValue(3), 'preset:cur', locale: 'de_DE'),
        '3,00 €',
      );
    });

    test('when looking up currency symbols then ISO codes map to symbols', () {
      expect(NumberFormatPresets.currencySymbolFor('eur'), '€');
      expect(NumberFormatter.currencySymbolFor('GBP'), '£');
      expect(NumberFormatPresets.currencySymbolFor('XYZ'), 'XYZ');
    });
  });
}
