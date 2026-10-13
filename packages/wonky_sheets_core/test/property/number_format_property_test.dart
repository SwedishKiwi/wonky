@Tags(['property'])
library;

import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/content/cell_content.dart';
import 'package:wonky_sheets_core/src/format/number_format/number_format.dart';
import 'package:wonky_sheets_core/src/input/input.dart';

final int _seed =
    int.tryParse(Platform.environment['WONKY_SEED'] ?? '') ?? 20261012;
final int _runs =
    int.tryParse(Platform.environment['WONKY_PROPERTY_RUNS'] ?? '') ?? 400;

const List<String> _numberItems = [
  '0',
  '#',
  '?',
  '0',
  '#',
  ',',
  '.',
  '%',
  'E+',
  'E-',
  '"x"',
  r'\$',
  ' ',
  '-',
  '(',
  ')', //
  '_)', '*-', r'[$€-407]', '/', '16', '‰', '@', 'General',
];
const List<String> _dateItems = [
  'd',
  'dd',
  'ddd',
  'dddd',
  'm',
  'mm',
  'mmm',
  'mmmm',
  'mmmmm',
  'yy',
  'yyyy',
  'h',
  'hh', //
  's',
  'ss',
  'ss.000',
  '[h]',
  '[mm]',
  '[s]',
  'AM/PM',
  'A/P',
  '/',
  '-',
  ':',
  ' ',
  '"at"',
  '.', //
];
const List<String> _brackets = [
  '',
  '',
  '',
  '[Red]',
  '[Color12]',
  '[>100]',
  '[<=-1]',
  '[Blue]',
];
const List<String> _locales = [
  'en_US',
  'de_DE',
  'fr_FR',
  'ja_JP',
  'en_IN',
  'de_CH',
];

String _section(Random r) {
  final items = r.nextBool() ? _numberItems : _dateItems;
  final b = StringBuffer(_brackets[r.nextInt(_brackets.length)]);
  final n = r.nextInt(7);
  for (var i = 0; i < n; i++) {
    b.write(items[r.nextInt(items.length)]);
  }
  return b.toString();
}

String _pattern(Random r) =>
    [for (var i = 0; i < 1 + r.nextInt(4); i++) _section(r)].join(';');

CellValue _value(Random r) {
  switch (r.nextInt(8)) {
    case 0:
      return TextValue(
        String.fromCharCodes([
          for (var i = 0; i < r.nextInt(5); i++) 97 + r.nextInt(26),
        ]),
      );
    case 1:
      return BoolValue(r.nextBool());
    case 2:
      return NumberValue((r.nextDouble() - 0.5) * 3e6);
    case 3:
      return NumberValue((r.nextDouble() - 0.5) * pow(10, r.nextInt(40) - 20));
    case 4:
      return NumberValue(r.nextInt(2958465).toDouble() + r.nextDouble());
    case 5:
      return NumberValue(r.nextDouble());
    case 6:
      return NumberValue(r.nextInt(2000000) - 1000000.0);
    default:
      return const NumberValue(0);
  }
}

void main() {
  group('Given random grammar patterns and values', () {
    test(
      'when formatting then nothing throws and results are deterministic',
      () {
        final r = Random(_seed);
        final a = NumberFormatter();
        final b = NumberFormatter();
        for (var i = 0; i < _runs; i++) {
          final pattern = _pattern(r);
          final locale = _locales[r.nextInt(_locales.length)];
          final ast = NumberFormatParser.tryParse(pattern);
          for (var k = 0; k < 5; k++) {
            final v = _value(r);
            final x = a.format(v, pattern, locale: locale);
            final y = b.format(v, pattern, locale: locale);
            expect(x, equals(y), reason: '$pattern / $v / $locale');
            if (ast != null && !NumberFormatPresets.isAutomatic(pattern)) {
              expect(
                NumberFormatRenderer.render(
                  ast,
                  v,
                  LocaleFormatData.forId(locale),
                ),
                equals(x),
                reason: 'cached vs uncached: $pattern / $v',
              );
            }
          }
        }
      },
    );

    test('when adjusting decimals then valid patterns stay valid', () {
      final r = Random(_seed + 1);
      for (var i = 0; i < _runs; i++) {
        final pattern = _pattern(r);
        if (NumberFormatParser.tryParse(pattern) == null) continue;
        for (final d in const [1, -1]) {
          final adjusted = DecimalsAdjuster.adjust(pattern, d);
          expect(
            NumberFormatParser.validate(adjusted),
            isNull,
            reason: '$pattern → $adjusted',
          );
        }
      }
    });
  });

  group('Given random character soup', () {
    test(
      'when parsing then only FormatParseError is thrown and formatting never throws',
      () {
        final r = Random(_seed + 2);
        const alphabet = r'0#?.,;%[]"\*_@$-+/:EeDdMmYyHhSsAaPpGx<>= 1';
        final f = NumberFormatter();
        for (var i = 0; i < _runs; i++) {
          final p = String.fromCharCodes([
            for (var k = 0; k < r.nextInt(12); k++)
              alphabet.codeUnitAt(r.nextInt(alphabet.length)),
          ]);
          try {
            NumberFormatParser.parse(p);
          } on FormatParseError catch (e) {
            expect(e.position, inInclusiveRange(0, p.length));
          }
          f.format(_value(r), p);
        }
      },
    );

    test('when parsing random input then the input parser never throws', () {
      final r = Random(_seed + 3);
      const alphabet = r'0123456789.,:/-+ %$€()eEaApPmMT#!';
      for (var i = 0; i < _runs; i++) {
        final s = String.fromCharCodes([
          for (var k = 0; k < r.nextInt(14); k++)
            alphabet.codeUnitAt(r.nextInt(alphabet.length)),
        ]);
        for (final locale in _locales) {
          InputParser.instance.parse(
            s,
            locale: locale,
            today: DateTime(2026, 10, 12),
          );
        }
      }
    });
  });

  group('Given formatted values typed back in', () {
    test(
      'when a grouped number is formatted and parsed then the rounded value returns',
      () {
        final r = Random(_seed + 4);
        final f = NumberFormatter();
        for (var i = 0; i < _runs; i++) {
          final locale = _locales[r.nextInt(_locales.length)];
          final x = roundHalfAwayFromZero(
            (r.nextDouble() - 0.5) * pow(10, r.nextInt(9)),
            2,
          );
          final text = f.formatText(NumberValue(x), '#,##0.00', locale: locale);
          final parsed = InputParser.instance
              .parse(text, locale: locale)
              .content;
          expect(
            parsed,
            equals(NumberContent(x)),
            reason: '$x → $text ($locale)',
          );
        }
      },
    );

    test(
      'when a date is formatted with the date preset and parsed then the serial returns',
      () {
        final r = Random(_seed + 5);
        final f = NumberFormatter();
        for (var i = 0; i < _runs; i++) {
          final locale = _locales[r.nextInt(_locales.length)];
          final serial = (1 + r.nextInt(2958464)).toDouble();
          final text = f.formatText(
            NumberValue(serial),
            'preset:date',
            locale: locale,
          );
          final parsed = InputParser.instance
              .parse(text, locale: locale)
              .content;
          expect(
            parsed,
            equals(NumberContent(serial)),
            reason: '$serial → $text ($locale)',
          );
        }
      },
    );
  });
}
