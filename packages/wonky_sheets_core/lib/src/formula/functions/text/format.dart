import '../../eval/eval_context.dart';
import '../../values/coercion.dart';
import '../../values/errors.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../parser/to_functions.dart';
import '../registry.dart';

/// Number ⇄ text conversions: TEXT, DOLLAR, FIXED, VALUE, NUMBERVALUE, VALUETOTEXT,
/// ARRAYTOTEXT (05 §15.5). Patterns are formatted by the engine's [NumberTextFormatter].
void registerTextFormat(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.text;

  b.fn(
    'TEXT',
    'Converts a number into text according to a specified format.',
    [
      P.scalar('number', 'The number, date, or time to format.'),
      P.text(
        'format',
        'The pattern by which to format the number, enclosed in quotation marks.',
      ),
    ],
    (a) {
      var v = a.scalar(0);
      final pattern = a.text(1);
      if (v is FText) {
        final p = TextNumberParser.parse(
          v.v,
          a.locale,
          currentYear: a.ctx.currentYear,
        );
        if (p != null) v = FNumber(p.$1, p.$2);
      }
      return FText(_format(a, v, pattern));
    },
    priority: Priority.p0,
    examples: [
      'TEXT(1.23, "\$0.00")',
      'TEXT(A2, "yyyy-mm-dd")',
      'TEXT(0.285, "0.0%")',
    ],
    seeAlso: ['TO_TEXT', 'FIXED', 'DOLLAR', 'VALUE'],
    notes:
        'Uses the number format language of Format › Number › Custom number format.',
  );
  b.fn(
    'DOLLAR',
    'Formats a number into the locale-specific currency format.',
    [
      P.num('number', 'The value to be formatted.'),
      P.num(
        'number_of_places',
        'The number of decimal places to display. Negative values round to the left of the decimal point.',
        true,
        2,
      ),
    ],
    (a) {
      final places = _places(a, 1);
      final x = Numeric.roundHalfAway(a.number(0), places);
      final pattern = patternForHint(
        FormatHint.currencyDefault,
        a.locale,
      )!.replaceFirst('#,##0.00', _numberPattern(places, grouping: true));
      return FText(_format(a, FNumber(x), pattern));
    },
    examples: ['DOLLAR(1.2351, 4)', 'DOLLAR(A2)'],
    seeAlso: ['FIXED', 'TEXT', 'TO_DOLLARS'],
    notes: 'Returns text in the spreadsheet locale\'s currency format.',
  );
  b.fn(
    'FIXED',
    'Formats a number with a fixed number of decimal places.',
    [
      P.num('number', 'The number to format.'),
      P.num(
        'number_of_places',
        'The number of decimal places to display in the result. Negative values round to the left of the decimal point.',
        true,
        2,
      ),
      P.bool_(
        'suppress_separator',
        'Whether to suppress the thousands separator used in some locales.',
        true,
        false,
      ),
    ],
    (a) {
      final places = _places(a, 1);
      final grouping = !a.boolOr(2, false);
      final x = Numeric.roundHalfAway(a.number(0), places);
      return FText(
        _format(a, FNumber(x), _numberPattern(places, grouping: grouping)),
      );
    },
    examples: ['FIXED(3.141592, 2)', 'FIXED(1234.567, -1, TRUE)'],
    seeAlso: ['DOLLAR', 'TEXT', 'ROUND'],
  );
  b.fn(
    'VALUE',
    'Converts a string in any of the date, time or number formats that Sheets understands into a number.',
    [P.scalar('text', 'The string containing the value to be converted.')],
    (a) {
      final v = a.scalar(0);
      switch (v) {
        case FNumber(:final v):
          return FNumber(v);
        case FEmpty():
          return FNumber.zero;
        case FText(:final v):
          final p = TextNumberParser.parse(
            v,
            a.locale,
            currentYear: a.ctx.currentYear,
          );
          if (p == null) {
            fail(
              ErrorKind.value,
              "VALUE parameter '$v' cannot be parsed to number.",
            );
          }
          return FNumber(p.$1);
        default:
          fail(
            ErrorKind.value,
            "VALUE parameter '${v.debugText}' cannot be parsed to number.",
          );
      }
    },
    priority: Priority.p0,
    examples: ['VALUE("123")', 'VALUE("2027-01-15")', 'VALUE("12%")'],
    seeAlso: ['NUMBERVALUE', 'TEXT', 'N'],
  );
  b.fn(
    'NUMBERVALUE',
    'Converts text to a number using the given decimal and group separators, independent of the locale.',
    [
      P.text('text', 'The text to convert to a number.'),
      P.text(
        'decimal_separator',
        'The character used as the decimal separator. Defaults to the spreadsheet locale.',
        true,
      ),
      P.text(
        'group_separator',
        'The character used to separate groups of digits. Defaults to the spreadsheet locale.',
        true,
      ),
    ],
    _numberValue,
    examples: ['NUMBERVALUE("2.500,27", ",", ".")', 'NUMBERVALUE("3.5%")'],
    seeAlso: ['VALUE'],
  );
  b.fn(
    'VALUETOTEXT',
    'Returns text from any specified value.',
    [
      P.scalar('value', 'The value to return as text.'),
      P.num(
        'format',
        '0 (concise, default) returns the value as displayed; 1 (strict) puts text in quotation marks.',
        true,
        0,
      ),
    ],
    (a) {
      final strict = _strict(a, 1);
      return FText(_valueText(a, a.scalarOrError(0), strict));
    },
    handlesErrors: true,
    priority: Priority.p2,
    examples: ['VALUETOTEXT(A2)', 'VALUETOTEXT("Hello", 1)'],
    seeAlso: ['ARRAYTOTEXT', 'TO_TEXT'],
  );
  b.fn(
    'ARRAYTOTEXT',
    'Returns an array of text values from any specified range.',
    [
      P.array('array', 'The array to return as text.'),
      P.num(
        'format',
        '0 (concise, default) returns a comma-separated list; 1 (strict) returns an array constant with quoted text.',
        true,
        0,
      ),
    ],
    (a) {
      final strict = _strict(a, 1);
      final arr = a.array(0);
      final col = a.locale.arrayColSeparator;
      if (!strict) {
        return FText(
          [for (final v in arr.elements) _valueText(a, v, false)].join('$col '),
        );
      }
      final rows = [
        for (var r = 0; r < arr.rows; r++)
          [for (var c = 0; c < arr.cols; c++) _valueText(a, arr.at(r, c), true)]
              .join(col),
      ];
      return FText('{${rows.join(a.locale.arrayRowSeparator)}}');
    },
    handlesErrors: true,
    priority: Priority.p2,
    examples: ['ARRAYTOTEXT(A2:B3)', 'ARRAYTOTEXT({1, "a"; TRUE, 2}, 1)'],
    seeAlso: ['VALUETOTEXT', 'TEXTJOIN'],
  );
}

int _places(FunctionArgs a, int i) {
  final n = a.has(i) ? a.integer(i) : 2;
  if (n > 127) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter ${i + 1} value $n is too large.',
    );
  }
  return n;
}

/// `#,##0.00`-style pattern with [places] decimals (none when negative).
String _numberPattern(int places, {required bool grouping}) {
  final base = grouping ? '#,##0' : '0';
  return places > 0 ? '$base.${'0' * places}' : base;
}

String _format(FunctionArgs a, FValue v, String pattern) {
  final s = a.ctx.host.textFormatter.format(v, pattern, a.locale);
  if (s == null) {
    fail(
      ErrorKind.value,
      "Function ${a.fn} parameter 2 value '$pattern' is not a valid number format.",
    );
  }
  return s;
}

bool _strict(FunctionArgs a, int i) {
  if (!a.has(i)) return false;
  final n = a.integer(i);
  if (n != 0 && n != 1) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter ${i + 1} value $n is out of range.',
    );
  }
  return n == 1;
}

String _valueText(FunctionArgs a, FValue v, bool strict) {
  if (v is FRich) v = v.scalar;
  return switch (v) {
    FText(:final v) => strict ? '"${v.replaceAll('"', '""')}"' : v,
    FNumber(:final v) => Numeric.toText(v, decimal: a.locale.decimal),
    FBool(:final v) => v ? 'TRUE' : 'FALSE',
    FError(:final kind) => kind.literal,
    _ => '',
  };
}

final RegExp _plainNumber = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

FValue _numberValue(FunctionArgs a) {
  String sep(int i, String d) {
    if (!a.has(i)) return d;
    final s = a.text(i);
    if (s.isEmpty) {
      fail(
        ErrorKind.value,
        'Function NUMBERVALUE parameter ${i + 1} value should be non-empty.',
      );
    }
    return s[0];
  }

  final decimal = sep(1, a.locale.decimal);
  final group = sep(2, a.locale.group);
  if (decimal == group) {
    fail(
      ErrorKind.value,
      'Function NUMBERVALUE needs different decimal and group separators.',
    );
  }
  final raw = a.text(0).replaceAll(RegExp(r'\s'), '');
  if (raw.isEmpty) return FNumber.zero;
  var s = raw;
  var percents = 0;
  while (s.endsWith('%')) {
    percents++;
    s = s.substring(0, s.length - 1);
  }
  final out = StringBuffer();
  var seenDecimal = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == decimal) {
      if (seenDecimal) fail(ErrorKind.value, _nvError(raw));
      seenDecimal = true;
      out.write('.');
    } else if (c == group) {
      if (seenDecimal) fail(ErrorKind.value, _nvError(raw));
    } else {
      out.write(c);
    }
  }
  final t = out.toString();
  if (!_plainNumber.hasMatch(t)) fail(ErrorKind.value, _nvError(raw));
  var x = double.parse(t);
  for (var k = 0; k < percents; k++) {
    x /= 100;
  }
  if (!x.isFinite) fail(ErrorKind.num);
  return FNumber(x);
}

String _nvError(String text) =>
    "NUMBERVALUE parameter '$text' cannot be parsed to number.";
