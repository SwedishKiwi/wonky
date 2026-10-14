import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';

/// ROMAN and ARABIC (05 §15.1).
void registerRoman(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.math;
  b.fn(
    'ROMAN',
    'Formats a number in Roman numerals.',
    [
      P.num('number', 'The number to format, between 1 and 3999, inclusive.'),
      P.scalar(
        'rule_relaxation',
        'How concise the result is: 0 (default) classic, 1–4 increasingly concise; TRUE = 0, FALSE = 4.',
        true,
        0,
      ),
    ],
    (a) {
      final n = a.integer(0);
      var mode = 0;
      if (a.has(1)) {
        final v = a.scalar(1);
        mode = switch (v) {
          FBool(:final v) => v ? 0 : 4,
          FEmpty() => 0,
          _ => a.integer(1),
        };
      }
      if (n < 0 || n > 3999) {
        fail(
          ErrorKind.value,
          'Function ROMAN parameter 1 value is $n. Valid values are between 1 and 3999 inclusive.',
        );
      }
      if (mode < 0 || mode > 4) {
        fail(
          ErrorKind.value,
          'Function ROMAN parameter 2 value is $mode. Valid values are between 0 and 4 inclusive.',
        );
      }
      return FText(toRoman(n, mode));
    },
    priority: Priority.p2,
    examples: ['ROMAN(499)', 'ROMAN(499, 4)'],
    seeAlso: ['ARABIC'],
  );
  b.fn(
    'ARABIC',
    'Computes the value of a Roman numeral.',
    [
      P.text(
        'roman_numeral',
        'The Roman numeral to format, whose value must be between 1 and 3999, inclusive.',
      ),
    ],
    (a) {
      final s = a.text(0);
      final v = fromRoman(s);
      if (v == null) {
        fail(
          ErrorKind.value,
          "Function ARABIC parameter 1 value '$s' is not a valid Roman numeral.",
        );
      }
      return FNumber(v.toDouble());
    },
    priority: Priority.p2,
    examples: ['ARABIC("XIV")', 'ARABIC("mcmxii")'],
    seeAlso: ['ROMAN'],
  );
}

const List<String> _chars = ['M', 'D', 'C', 'L', 'X', 'V', 'I'];
const List<int> _values = [1000, 500, 100, 50, 10, 5, 1];

/// Roman numeral of [n] (0–3999) in Excel's relaxation [mode] 0–4 (0 → empty text).
String toRoman(int n, int mode) {
  final out = StringBuffer();
  var v = n;
  const maxIndex = 6;
  for (var i = 0; i <= maxIndex ~/ 2; i++) {
    var index = 2 * i;
    final digit = v ~/ _values[index];
    if (digit % 5 == 4) {
      final index2 = digit == 4 ? index - 1 : index - 2;
      var steps = 0;
      while (steps < mode && index < maxIndex) {
        steps++;
        if (_values[index2] - _values[index + 1] <= v) {
          index++;
        } else {
          steps = mode;
        }
      }
      out
        ..write(_chars[index])
        ..write(_chars[index2]);
      v += _values[index];
      v -= _values[index2];
    } else {
      if (digit > 4) out.write(_chars[index - 1]);
      out.write(_chars[index] * (digit % 5));
      v %= _values[index];
    }
  }
  return out.toString();
}

/// Value of a Roman numeral (case-insensitive, optional leading minus, blank = 0), or null.
int? fromRoman(String text) {
  var s = text.trim().toUpperCase();
  if (s.length > 255) return null;
  var sign = 1;
  if (s.startsWith('-')) {
    sign = -1;
    s = s.substring(1);
  }
  if (s.isEmpty) return 0;
  var total = 0;
  for (var i = 0; i < s.length; i++) {
    final k = _chars.indexOf(s[i]);
    if (k < 0) return null;
    final v = _values[k];
    final next = i + 1 < s.length ? _chars.indexOf(s[i + 1]) : -1;
    if (next >= 0 && _values[next] > v) {
      total -= v;
    } else {
      total += v;
    }
  }
  return sign * total;
}
