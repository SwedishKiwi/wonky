import 'dart:math';

import 'package:petitparser/petitparser.dart';
import 'package:petitparser/reflection.dart';
import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';

Expr parse(String s, {FormulaLocale locale = FormulaLocale.enUS}) =>
    FormulaParser.parse(s, locale: locale);

NumberLit n(double v) => NumberLit(v);
RefExpr ref(String a1) => RefExpr(A1RefNode(A1Area.tryParse(a1)!));

void main() {
  group('Given the formula grammar productions', () {
    final grammar = FormulaGrammar(FormulaLocale.enUS);
    test('when linting the grammar then there are no issues', () {
      final issues = linter(grammar.build(), excludedTypes: {LinterType.info});
      expect(issues, isEmpty);
    });
    final productions = <(String, Parser<Object?>, List<String>, List<String>)>[
      (
        'numberLiteral',
        grammar.buildFrom(grammar.numberLiteral().end()),
        ['1', '1.5', '.5', '1.', '1e3', '2.5E-2'],
        ['e3', '1e', '1A', '-1'],
      ),
      (
        'stringLiteral',
        grammar.buildFrom(grammar.stringLiteral().end()),
        ['""', '"a"', '"say ""hi"""'],
        ['"a', "'a'"],
      ),
      (
        'booleanLiteral',
        grammar.buildFrom(grammar.booleanLiteral().end()),
        ['TRUE', 'false'],
        ['TRUE(', 'TRUEX'],
      ),
      (
        'errorLiteral',
        grammar.buildFrom(grammar.errorLiteral().end()),
        ['#N/A', '#ref!', '#DIV/0!', '#SPILL!'],
        ['#FOO', 'N/A'],
      ),
      (
        'a1Reference',
        grammar.buildFrom(grammar.a1Reference().end()),
        ['A1', r'$A$1', 'A1:B2', 'A:A', '1:3', "'My s'!B2"],
        ['A1B', 'AAAA1'],
      ),
    ];
    for (final (name, parser, accept, reject) in productions) {
      for (final s in accept) {
        test('when parsing "$s" with $name then it succeeds', () {
          expect(parser.parse(s), isA<Success<Object?>>());
        });
      }
      for (final s in reject) {
        test('when parsing "$s" with $name then it fails', () {
          expect(parser.parse(s), isA<Failure>());
        });
      }
    }
  });

  group('Given operator precedence (05 §3.5)', () {
    final cases = <(String, Expr)>[
      ('=-2^2', BinaryExpr(BinaryOp.pow, UnaryExpr(UnaryOp.minus, n(2)), n(2))),
      (
        '=2^3^2',
        BinaryExpr(BinaryOp.pow, BinaryExpr(BinaryOp.pow, n(2), n(3)), n(2)),
      ),
      (
        '=1-2-3',
        BinaryExpr(BinaryOp.sub, BinaryExpr(BinaryOp.sub, n(1), n(2)), n(3)),
      ),
      (
        '="a"&1+2',
        BinaryExpr(
          BinaryOp.concat,
          const StringLit('a'),
          BinaryExpr(BinaryOp.add, n(1), n(2)),
        ),
      ),
      (
        '=1+2*3',
        BinaryExpr(BinaryOp.add, n(1), BinaryExpr(BinaryOp.mul, n(2), n(3))),
      ),
      ('=50%^2', BinaryExpr(BinaryOp.pow, PercentExpr(n(50)), n(2))),
      (
        '=1<2=TRUE',
        BinaryExpr(
          BinaryOp.eq,
          BinaryExpr(BinaryOp.lt, n(1), n(2)),
          const BoolLit(true),
        ),
      ),
      ('=A1:B2', ref('A1:B2')),
      (
        '=(1+2)*3',
        BinaryExpr(
          BinaryOp.mul,
          ParenExpr(BinaryExpr(BinaryOp.add, n(1), n(2))),
          n(3),
        ),
      ),
      ('= 1 +\n 2 ', BinaryExpr(BinaryOp.add, n(1), n(2))),
      ('=--A1', UnaryExpr(UnaryOp.minus, UnaryExpr(UnaryOp.minus, ref('A1')))),
      (
        '=A1:INDEX(B:B,5)',
        RangeOpExpr(ref('A1'), CallExpr('INDEX', [ref('B:B'), n(5)])),
      ),
      ('=1<>2', BinaryExpr(BinaryOp.ne, n(1), n(2))),
      ('=1>=2', BinaryExpr(BinaryOp.ge, n(1), n(2))),
    ];
    for (final (text, ast) in cases) {
      test(
        'when parsing "${text.replaceAll('\n', r'\n')}" then the tree is $ast',
        () {
          expect(parse(text), ast);
        },
      );
    }
  });

  group('Given primaries', () {
    final cases = <(String, Expr)>[
      ('=SUM(1,2)', CallExpr('SUM', [n(1), n(2)])),
      ('=sum()', const CallExpr('SUM', [])),
      ('=IF(A1,,3)', CallExpr('IF', [ref('A1'), null, n(3)])),
      ('=LOG10(100)', CallExpr('LOG10', [n(100)])),
      ('=TRUE()', const CallExpr('TRUE', [])),
      ('=Sales', const NameExpr('Sales')),
      (
        '=NORM.DIST(1,0,1,TRUE)',
        CallExpr('NORM.DIST', [n(1), n(0), n(1), const BoolLit(true)]),
      ),
      (
        '={1,2;3,4}',
        ArrayLit([
          [n(1), n(2)],
          [n(3), n(4)],
        ]),
      ),
      (
        '=LAMBDA(x,x+1)(5)',
        InvokeExpr(
          CallExpr('LAMBDA', [
            const NameExpr('x'),
            BinaryExpr(BinaryOp.add, const NameExpr('x'), n(1)),
          ]),
          [n(5)],
        ),
      ),
      ('=#N/A', const ErrorLit(ErrorKind.na)),
      ('=1:3', ref('1:3')),
      ('=A2:B', ref('A2:B')),
    ];
    for (final (text, ast) in cases) {
      test('when parsing "$text" then the tree is $ast', () {
        expect(parse(text), ast);
      });
    }
  });

  group('Given a comma-decimal locale (de_DE)', () {
    final de = FormulaLocale.forId('de_DE');
    test(
      'when reading the locale then separators follow the decimal comma',
      () {
        expect(de.decimal, ',');
        expect(de.argSeparator, ';');
        expect(de.arrayColSeparator, r'\');
      },
    );
    final cases = <(String, Expr)>[
      ('=ROUND(1,5;0)', CallExpr('ROUND', [n(1.5), n(0)])),
      ('=SUM(A1,B1)', CallExpr('SUM', [ref('A1'), ref('B1')])),
      (
        r'={1\2;3\4}',
        ArrayLit([
          [n(1), n(2)],
          [n(3), n(4)],
        ]),
      ),
      ('=SUM(1;2)', CallExpr('SUM', [n(1), n(2)])),
    ];
    for (final (text, ast) in cases) {
      test('when parsing "$text" then the tree is $ast', () {
        expect(parse(text, locale: de), ast);
      });
    }
  });

  group('Given invalid formulas', () {
    final cases = <(String, ParseErrorKey, int)>[
      ('=SUM(1', ParseErrorKey.missingCloseParen, 6),
      ('="abc', ParseErrorKey.unterminatedString, 1),
      ('={1,,2}', ParseErrorKey.emptyArrayElement, 4),
      ('=1+', ParseErrorKey.unexpectedToken, 2),
      ('=1 2', ParseErrorKey.unexpectedToken, 3),
      ('=SUM(1))', ParseErrorKey.unexpectedToken, 7),
    ];
    for (final (text, key, offset) in cases) {
      test('when parsing "$text" then the error is ${key.name} at $offset', () {
        final (ast, err) = FormulaParser.tryParse(text);
        expect(ast, isNull);
        expect(err!.messageKey, key);
        expect(err.offset, offset);
      });
    }
    test('when nesting deeper than 256 levels then the error is tooDeep', () {
      final text = '=${'(' * 300}1${')' * 300}';
      expect(
        FormulaParser.tryParse(text).$2!.messageKey,
        ParseErrorKey.tooDeep,
      );
    });
    test('when the formula exceeds 32768 characters then it is rejected', () {
      expect(
        FormulaParser.tryParse('=${'1+' * 20000}1').$2!.messageKey,
        ParseErrorKey.tooLong,
      );
    });
  });

  group('Given random token streams (fuzzing)', () {
    const atoms = [
      '1',
      '2.5',
      '"x"',
      'A1',
      'B2:C3',
      'SUM(',
      'IF(',
      ')',
      '(',
      ',',
      '+',
      '-',
      '*',
      '/',
      '^',
      '&',
      '=',
      '<>',
      '%',
      '{',
      '}',
      ';',
      'TRUE',
      '#N/A',
      'Sheet2!A1',
      ':',
      ' ',
      'name',
      '⟦',
      '⟧',
      "'",
    ];
    final seed =
        int.tryParse(const String.fromEnvironment('WONKY_SEED')) ?? 20261012;
    test(
      'when parsing 2000 random formulas (seed $seed) then nothing throws',
      () {
        final rnd = Random(seed);
        for (var i = 0; i < 2000; i++) {
          final b = StringBuffer('=');
          final len = rnd.nextInt(20);
          for (var k = 0; k < len; k++) {
            b.write(atoms[rnd.nextInt(atoms.length)]);
          }
          final text = b.toString();
          expect(
            () => FormulaParser.tryParse(text),
            returnsNormally,
            reason: text,
          );
          expect(
            () => const FormulaLexer().tokenize(text),
            returnsNormally,
            reason: text,
          );
        }
      },
    );
  });
}
