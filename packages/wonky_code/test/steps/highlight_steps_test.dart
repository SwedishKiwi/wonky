import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  group('Given the reveal.js syntax', () {
    test('when parsing "1-3 | 5 | 7-9" then there are three steps', () {
      final r = HighlightSteps.parse('1-3 | 5 | 7-9', lineCount: 32);

      expect(r.steps, hasLength(3));
      expect(r.steps[0].lines, [1, 2, 3]);
      expect(r.steps[1].lines, [5]);
      expect(r.steps[2].lines, [7, 8, 9]);
      expect(r.issues, isEmpty);
    });

    test('when parsing "| 2,4 | *" then empty and star steps show all '
        'lines', () {
      final r = HighlightSteps.parse('| 2,4 | *', lineCount: 10);

      expect(r.steps, hasLength(3));
      expect(r.steps[0].isAll, isTrue);
      expect(r.steps[1].lines, [2, 4]);
      expect(r.steps[2].isAll, isTrue);
    });

    test('when parsing an open range then it runs to the last line', () {
      final r = HighlightSteps.parse('10-', lineCount: 12);

      expect(r.steps.single.lines, [10, 11, 12]);
    });

    test('when parsing an open range without a line count then it contains '
        'every later line', () {
      final step = HighlightSteps.parse('10-').steps.single;

      expect(step.highlights(500), isTrue);
      expect(step.highlights(9), isFalse);
      expect(step.ranges.single.text, '10-');
    });

    test('when whitespace is spread around then it is ignored', () {
      final r = HighlightSteps.parse(' 1 - 3 ,\t5 ', lineCount: 9);

      expect(r.steps.single.lines, [1, 2, 3, 5]);
    });

    test('when parsing a column range then it highlights within one line', () {
      final range = HighlightSteps.parse(
        '4:2-9',
        lineCount: 9,
      ).steps.single.ranges.single;

      expect(range.isColumnRange, isTrue);
      expect((range.first, range.startColumn, range.endColumn), (4, 2, 9));
    });

    test('when the input is empty or null then there are no steps', () {
      expect(HighlightSteps.parse('', lineCount: 3).steps, isEmpty);
      expect(HighlightSteps.parse(null, lineCount: 3).steps, isEmpty);
      expect(HighlightSteps.parse('   ').steps, isEmpty);
    });

    test('when normalizing then the stored form has no spaces', () {
      final r = HighlightSteps.parse(' 1-3 | 5 |  | 7-9 ', lineCount: 9);

      expect(r.normalized, '1-3|5|*|7-9');
    });
  });

  group('Given invalid input', () {
    test('when a line is past the end then it is clamped with an issue', () {
      final r = HighlightSteps.parse('30-40', lineCount: 32);

      expect(r.steps.single.lines.last, 32);
      expect(
        r.issues.single.message,
        "Line 40 doesn't exist (the code has 32 lines)",
      );
    });

    test('when a range is reversed then it is swapped with an issue', () {
      final r = HighlightSteps.parse('5-3', lineCount: 9);

      expect(r.steps.single.lines, [3, 4, 5]);
      expect(r.issues.single.code, 'reversedRange');
    });

    test('when an item is not a line then it is dropped with a syntax '
        'issue', () {
      final r = HighlightSteps.parse('2,abc|4', lineCount: 9);

      expect(r.steps, hasLength(2));
      expect(r.steps[0].lines, [2]);
      expect(r.issues.single.code, 'syntax');
      expect(r.issues.single.step, 0);
    });

    test('when line 0 is given then it is clamped to 1', () {
      final r = HighlightSteps.parse('0-2', lineCount: 9);

      expect(r.steps.single.lines, [1, 2]);
      expect(r.issues.single.code, 'lineOutOfRange');
    });
  });

  group('Given displayed line numbers', () {
    test('when the input starts with @ then numbers are shifted by the start '
        'line', () {
      final r = HighlightSteps.parse('@42-44', lineCount: 10, startLine: 40);

      expect(r.steps.single.lines, [3, 4, 5]);
    });
  });

  group('Given steps checked against changed code', () {
    test('when a step points past the new end then it is flagged', () {
      final steps = HighlightSteps.parse('1|2|7-9').steps;

      final issues = HighlightSteps.validate(steps, 5);

      expect(issues.single.message, 'Step 3 points past the end');
    });
  });

  group('Given a step', () {
    test('when asking for its blocks then contiguous lines are grouped', () {
      final step = HighlightSteps.parse('1-3,5,6,9', lineCount: 9).steps.single;

      expect(step.blocks, [(1, 3), (5, 6), (9, 9)]);
      expect(step.lastLine, 9);
    });
  });
}
