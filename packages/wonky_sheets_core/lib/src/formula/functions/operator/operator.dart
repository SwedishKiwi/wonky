import '../../ast/ast.dart';
import '../../eval/operators.dart';
import '../../values/compare.dart';
import '../../values/fvalue.dart';
import '../registry.dart';

/// Operator functions (05 §15.16).
void registerOperators(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.operator;
  void bin(String name, BinaryOp op, String summary, String a1, String a2, String example) {
    b.fn(
      name,
      summary,
      [P.scalar(a1, 'The first value.'), P.scalar(a2, 'The second value.')],
      (a) => Operators.binary(op, a.scalarOrError(0), a.scalarOrError(1), a.locale),
      priority: Priority.p0,
      examples: [example],
    );
  }

  bin('ADD', BinaryOp.add, 'Returns the sum of two numbers. Equivalent to the `+` operator.', 'value1', 'value2', 'ADD(2, 3)');
  bin('MINUS', BinaryOp.sub, 'Returns the difference of two numbers. Equivalent to the `-` operator.', 'value1', 'value2', 'MINUS(5, 3)');
  bin('MULTIPLY', BinaryOp.mul, 'Returns the product of two numbers. Equivalent to the `*` operator.', 'factor1', 'factor2', 'MULTIPLY(2, 3)');
  bin('DIVIDE', BinaryOp.div, 'Returns one number divided by another. Equivalent to the `/` operator.', 'dividend', 'divisor', 'DIVIDE(6, 3)');
  bin('POW', BinaryOp.pow, 'Returns a number raised to a power. Equivalent to the `^` operator.', 'base', 'exponent', 'POW(2, 10)');
  bin('EQ', BinaryOp.eq, 'Returns TRUE if two specified values are equal and FALSE otherwise. Equivalent to the `=` operator.', 'value1', 'value2', 'EQ(A1, 5)');
  bin('NE', BinaryOp.ne, 'Returns TRUE if two specified values are not equal and FALSE otherwise. Equivalent to the `<>` operator.', 'value1', 'value2', 'NE(A1, 5)');
  bin('GT', BinaryOp.gt, 'Returns TRUE if the first argument is strictly greater than the second. Equivalent to the `>` operator.', 'value1', 'value2', 'GT(3, 2)');
  bin('GTE', BinaryOp.ge, 'Returns TRUE if the first argument is greater than or equal to the second. Equivalent to the `>=` operator.', 'value1', 'value2', 'GTE(3, 3)');
  bin('LT', BinaryOp.lt, 'Returns TRUE if the first argument is strictly less than the second. Equivalent to the `<` operator.', 'value1', 'value2', 'LT(2, 3)');
  bin('LTE', BinaryOp.le, 'Returns TRUE if the first argument is less than or equal to the second. Equivalent to the `<=` operator.', 'value1', 'value2', 'LTE(2, 3)');

  b.fn(
    'UMINUS',
    'Returns a number with the sign reversed.',
    [P.scalar('value', 'The number to negate.')],
    (a) => Operators.unary(UnaryOp.minus, a.scalarOrError(0), a.locale),
    priority: Priority.p0,
    examples: ['UMINUS(4)'],
  );
  b.fn(
    'UPLUS',
    'Returns a specified number, unchanged.',
    [P.scalar('value', 'The number to return.')],
    (a) => Operators.unary(UnaryOp.plus, a.scalarOrError(0), a.locale),
    priority: Priority.p0,
    examples: ['UPLUS(4)'],
  );
  b.fn(
    'UNARY_PERCENT',
    'Returns a value interpreted as a percentage; that is, UNARY_PERCENT(100) equals 1.',
    [P.scalar('percentage', 'The value to interpret as a percentage.')],
    (a) => Operators.percent(a.scalarOrError(0), a.locale),
    priority: Priority.p0,
    examples: ['UNARY_PERCENT(50)'],
  );
  b.fn(
    'ISBETWEEN',
    'Checks whether a provided number is between two other numbers either inclusively or exclusively.',
    [
      P.scalar('value_to_compare', 'The value to test as being between lower_value and upper_value.'),
      P.scalar('lower_value', 'The lower boundary of the range of values that value_to_compare can fall within.'),
      P.scalar('upper_value', 'The upper boundary of the range of values that value_to_compare can fall within.'),
      P.bool_('lower_value_is_inclusive', 'Whether the range of values includes the lower_value.', true, true),
      P.bool_('upper_value_is_inclusive', 'Whether the range of values includes the upper_value.', true, true),
    ],
    (a) {
      final v = a.scalar(0), lo = a.scalar(1), hi = a.scalar(2);
      final li = a.boolOr(3, true), ui = a.boolOr(4, true);
      final c1 = Compare.compare(v, lo), c2 = Compare.compare(v, hi);
      final okLo = li ? c1 >= 0 : c1 > 0;
      final okHi = ui ? c2 <= 0 : c2 < 0;
      return FBool(okLo && okHi);
    },
    priority: Priority.p0,
    examples: ['ISBETWEEN(7, 1, 10)', 'ISBETWEEN(A1, 1, 10, FALSE, FALSE)'],
  );
}
