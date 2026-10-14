import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../parser/formula_locale.dart';
import '../../values/coercion.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';

/// Shared helpers of the text functions (05 §15.5).

/// Byte width of a UTF-16 code unit for the `…B` functions: Latin-1 and half-width katakana
/// are single-byte, everything else is double-byte (DBCS = 2 bytes).
int byteWidth(int unit) =>
    unit <= 0xff || (unit >= 0xff61 && unit <= 0xff9f) ? 1 : 2;

/// Length of [s] in bytes (see [byteWidth]).
int byteLength(String s) {
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    n += byteWidth(s.codeUnitAt(i));
  }
  return n;
}

/// Number of code units of [s] from [from] that fit in [bytes] bytes (a double-byte
/// character that would be split is left out).
int unitsInBytes(String s, int from, int bytes) {
  var used = 0, i = from;
  while (i < s.length) {
    final w = byteWidth(s.codeUnitAt(i));
    if (used + w > bytes) break;
    used += w;
    i++;
  }
  return i - from;
}

/// Code-unit index of the character that contains the 1-based byte position [bytePos]
/// ([s.length] when the position is past the end).
int unitAtByte(String s, int bytePos) {
  var used = 0;
  for (var i = 0; i < s.length; i++) {
    used += byteWidth(s.codeUnitAt(i));
    if (used >= bytePos) return i;
  }
  return s.length;
}

/// Integer argument that must be ≥ 0 (`#VALUE!` "… is negative" otherwise).
int nonNegativeArg(Args a, int i, [int orElse = 0]) {
  final n = a.has(i) ? a.integer(i) : orElse;
  if (n < 0) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter ${i + 1} value is negative. It should be positive or zero.',
    );
  }
  return n;
}

/// Integer argument that must be ≥ 1.
int positiveArg(Args a, int i, [int orElse = 1]) {
  final n = a.has(i) ? a.integer(i) : orElse;
  if (n < 1) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter ${i + 1} value is $n. It should be greater than or equal to 1.',
    );
  }
  return n;
}

/// Text of an element of a range or array argument; errors throw.
String elementText(FValue v, FormulaLocale locale) {
  if (v is FError) throw FormulaError(v);
  final r = Coerce.toText(v, locale);
  if (r is FError) throw FormulaError(r);
  return r as String;
}

/// Strings of a delimiter argument (scalar, range or array), in row-major order.
List<String> delimiterList(Args a, int i) => [
  for (final v in a.flat(i)) elementText(v, a.locale),
];

/// Finds the earliest occurrence of any of [delims] in [hay] at or after [from]; ties prefer
/// the longest delimiter. Returns (start, end) or null. Empty delimiters match zero-width.
(int, int)? findAny(String hay, List<String> delims, int from) {
  (int, int)? best;
  for (final d in delims) {
    final p = hay.indexOf(d, from);
    if (p < 0) continue;
    if (best == null ||
        p < best.$1 ||
        (p == best.$1 && p + d.length > best.$2)) {
      best = (p, p + d.length);
    }
  }
  return best;
}
