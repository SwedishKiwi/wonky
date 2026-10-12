import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../helpers.dart';
import '../registry.dart';

/// 2^48: exclusive upper bound of bitwise operands (Excel / Google Sheets).
const double _limit = 281474976710656.0;

/// 2^24: bitwise operations are applied on two 24-bit halves (web ints are 32-bit for `&`).
const int _half = 16777216;

/// Operand [i] as a non-negative integer below 2^48, else `#NUM!`.
int _operand(Args a, int i) {
  final x = a.number(i);
  if (x < 0 || x >= _limit || x != x.truncateToDouble()) {
    fail(
      ErrorKind.num,
      'Function ${a.fn} parameter ${i + 1} must be an integer between 0 and 2^48-1.',
    );
  }
  return x.toInt();
}

int _bitwise(int x, int y, int Function(int, int) op) {
  final hi = op(x ~/ _half, y ~/ _half);
  final lo = op(x % _half, y % _half);
  return hi * _half + lo;
}

FValue _shift(Args a, double direction) {
  final x = _operand(a, 0);
  final n = a.integer(1);
  if (n.abs() > 53) {
    fail(
      ErrorKind.num,
      'Function ${a.fn} parameter 2 must be between -53 and 53.',
    );
  }
  final s = n * direction;
  final r = s >= 0
      ? x * math.pow(2, s).toDouble()
      : (x / math.pow(2, -s)).floorToDouble();
  return numResult(r);
}

/// Bitwise functions (05 §15.13): BITAND, BITOR, BITXOR, BITLSHIFT, BITRSHIFT.
void registerBitwise(FunctionRegistryBuilder b) {
  final ops = <(String, String, int Function(int, int))>[
    ('BITAND', 'Bitwise boolean AND of two numbers.', (x, y) => x & y),
    ('BITOR', 'Bitwise boolean OR of two numbers.', (x, y) => x | y),
    ('BITXOR', 'Bitwise XOR (exclusive OR) of two numbers.', (x, y) => x ^ y),
  ];
  for (final (name, summary, op) in ops) {
    b.fn(
      name,
      summary,
      [
        P.num('value1', 'The first number, an integer between 0 and 2^48-1.'),
        P.num('value2', 'The second number, an integer between 0 and 2^48-1.'),
      ],
      (a) => FNumber(_bitwise(_operand(a, 0), _operand(a, 1), op).toDouble()),
      examples: ['$name(12, 10)'],
      seeAlso: [
        for (final o in ['BITAND', 'BITOR', 'BITXOR'])
          if (o != name) o,
      ],
    );
  }
  b.fn(
    'BITLSHIFT',
    'Shifts the bits of the input a certain number of places to the left.',
    [
      P.num(
        'value',
        'The number to be shifted, an integer between 0 and 2^48-1.',
      ),
      P.num(
        'shift_amount',
        'The number of places to shift (between -53 and 53). Negative values shift to the right.',
      ),
    ],
    (a) => _shift(a, 1),
    examples: ['BITLSHIFT(4, 2)'],
    seeAlso: ['BITRSHIFT'],
  );
  b.fn(
    'BITRSHIFT',
    'Shifts the bits of the input a certain number of places to the right.',
    [
      P.num(
        'value',
        'The number to be shifted, an integer between 0 and 2^48-1.',
      ),
      P.num(
        'shift_amount',
        'The number of places to shift (between -53 and 53). Negative values shift to the left.',
      ),
    ],
    (a) => _shift(a, -1),
    examples: ['BITRSHIFT(13, 2)'],
    seeAlso: ['BITLSHIFT'],
  );
}
