import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../registry.dart';

/// A positional number system of the base conversion functions (10-digit two's complement).
final class _Radix {
  final String name;
  final int base;
  final String argName;
  final String argDesc;

  const _Radix(this.name, this.base, this.argName, this.argDesc);

  /// Bits represented by 10 digits (binary 10, octal 30, hexadecimal 40).
  int get bits => switch (base) {
    2 => 10,
    8 => 30,
    _ => 40,
  };

  /// Smallest and largest signed values representable with 10 digits.
  int get min => -_pow2(bits - 1);
  int get max => _pow2(bits - 1) - 1;
}

/// 2^[n] without bit shifts (shifts are 32-bit on the web).
int _pow2(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 2;
  }
  return r;
}

const _bin = _Radix(
  'binary',
  2,
  'signed_binary_number',
  'The signed 10-bit binary value to be converted, provided as a string. The most significant bit is the sign bit; negative numbers are in two\'s complement.',
);
const _oct = _Radix(
  'octal',
  8,
  'signed_octal_number',
  'The signed 30-bit octal value to be converted, provided as a string. Negative numbers are in two\'s complement.',
);
const _hex = _Radix(
  'hexadecimal',
  16,
  'signed_hexadecimal_number',
  'The signed 40-bit hexadecimal value to be converted, provided as a string. Negative numbers are in two\'s complement.',
);

const _prefix = {2: 'BIN', 8: 'OCT', 16: 'HEX'};

/// Parses a signed 10-digit two's complement number given as text or number.
int _parseSigned(FValue v, _Radix r) {
  final String s;
  switch (v) {
    case FNumber(v: final x):
      if (x < 0 || x != x.truncateToDouble()) fail(ErrorKind.num);
      s = Numeric.toText(x);
    case FText(v: final t):
      s = t.trim();
    case FEmpty():
      return 0;
    case FBool():
      fail(ErrorKind.value);
    default:
      fail(ErrorKind.value);
  }
  if (s.isEmpty) return 0;
  if (s.length > 10) {
    fail(
      ErrorKind.num,
      'Input "$s" has more than 10 digits, the maximum for a signed ${r.name} number.',
    );
  }
  var value = 0;
  for (final unit in s.toUpperCase().codeUnits) {
    final d = switch (unit) {
      >= 0x30 && <= 0x39 => unit - 0x30,
      >= 0x41 && <= 0x46 => unit - 0x41 + 10,
      _ => 99,
    };
    if (d >= r.base) {
      fail(ErrorKind.num, 'Input "$s" is not a valid ${r.name} number.');
    }
    value = value * r.base + d;
  }
  if (s.length == 10 && value > r.max) value -= _pow2(r.bits);
  return value;
}

/// Formats [value] in radix [r]: negatives as 10-digit two's complement (places ignored),
/// non-negatives left-padded to [places] digits.
FValue _format(Args a, int value, _Radix r, int placesArg) {
  if (value < r.min || value > r.max) {
    fail(
      ErrorKind.num,
      'Value $value is out of range for a signed ${r.name} number (${r.min} to ${r.max}).',
    );
  }
  if (value < 0) {
    return FText((value + _pow2(r.bits)).toRadixString(r.base).toUpperCase());
  }
  final digits = value.toRadixString(r.base).toUpperCase();
  if (!a.has(placesArg)) return FText(digits);
  final places = a.integer(placesArg);
  if (places < 1 || places > 10) {
    fail(ErrorKind.num, 'Significant digits must be between 1 and 10.');
  }
  if (places < digits.length) {
    fail(
      ErrorKind.num,
      'Result $digits needs more than $places significant digits.',
    );
  }
  return FText(digits.padLeft(places, '0'));
}

ArgSpec _places() => P.num(
  'significant_digits',
  'The number of significant digits to ensure in the result. Ignored for negative results.',
  true,
);

/// Base conversions (05 §15.13): BIN/OCT/HEX/DEC in all directions.
void registerBaseConversion(FunctionRegistryBuilder b) {
  const radixes = [_bin, _oct, _hex];
  for (final from in radixes) {
    final fp = _prefix[from.base]!;
    final sampleIn = switch (from.base) {
      2 => '"1100100"',
      8 => '"144"',
      _ => '"64"',
    };
    b.fn(
      '${fp}2DEC',
      'Converts a signed ${from.name} number to decimal format.',
      [P.scalar(from.argName, from.argDesc)],
      (a) => FNumber(_parseSigned(a.scalar(0), from).toDouble()),
      examples: ['${fp}2DEC($sampleIn)'],
      seeAlso: ['DEC2${fp == 'BIN' ? 'HEX' : 'BIN'}'],
    );
    for (final to in radixes) {
      if (identical(to, from)) continue;
      final tp = _prefix[to.base]!;
      b.fn(
        '${fp}2$tp',
        'Converts a signed ${from.name} number to signed ${to.name} format.',
        [P.scalar(from.argName, from.argDesc), _places()],
        (a) => _format(a, _parseSigned(a.scalar(0), from), to, 1),
        examples: ['${fp}2$tp($sampleIn)', '${fp}2$tp($sampleIn, 8)'],
        seeAlso: ['${fp}2DEC', 'DEC2$tp'],
      );
    }
  }
  for (final to in radixes) {
    final tp = _prefix[to.base]!;
    b.fn(
      'DEC2$tp',
      'Converts a decimal number to signed ${to.name} format.',
      [
        P.num(
          'decimal_number',
          'The decimal value to be converted (between ${to.min} and ${to.max}). Non-integers are truncated.',
        ),
        _places(),
      ],
      (a) {
        final x = a.number(0);
        if (x < to.min || x >= to.max + 1) {
          fail(
            ErrorKind.num,
            'Value ${Numeric.toText(x)} is out of range for a signed ${to.name} number (${to.min} to ${to.max}).',
          );
        }
        return _format(a, x.truncate(), to, 1);
      },
      examples: ['DEC2$tp(100)', 'DEC2$tp(100, 8)', 'DEC2$tp(-1)'],
      seeAlso: ['${tp}2DEC'],
    );
  }
}
