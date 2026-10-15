import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

String lines(int count, int columns) =>
    List.generate(count, (i) => 'x' * columns).join('\n');

void main() {
  group('Given a 1600 × 900 box with a title tab and line numbers', () {
    const options = CodeBoxOptions(
      chrome: CodeChrome.tab,
      hasTitle: true,
      lastLineNumber: 30,
    );

    test('when auto-sizing 30 lines × 80 columns then the size is at least '
        '16 su (07 AC-3)', () {
      final fit = CodeAutoFit.fit([lines(30, 80)], 1600, 900, options);

      expect(fit.fits, isTrue);
      expect(fit.fontSize, greaterThanOrEqualTo(16));
      expect(fit.fontSize % 0.5, 0);
    });

    test('when auto-sizing then the next step up would not fit', () {
      final fit = CodeAutoFit.fit([lines(30, 80)], 1600, 900, options);
      final next = CodeBoxGeometry.compute(
        1600,
        900,
        fit.fontSize + 0.5,
        options,
      );

      expect(
        30 * (fit.fontSize + 0.5) * 1.5,
        greaterThan(next.codeArea.height),
      );
    });

    test('when fitting across states then a longer second state lowers the '
        'size of both', () {
      final alone = CodeAutoFit.fit([lines(10, 40)], 1600, 900, options);
      final across = CodeAutoFit.fit(
        [lines(10, 40), lines(30, 80)],
        1600,
        900,
        options,
      );

      expect(across.fontSize, lessThan(alone.fontSize));
    });

    test('when short code is fitted then the maximum size is used', () {
      final fit = CodeAutoFit.fit(['x'], 1600, 900, options);

      expect(fit.fontSize, 40);
    });

    test('when nothing fits then the minimum is used and it overflows', () {
      final fit = CodeAutoFit.fit([lines(200, 80)], 1600, 900, options);

      expect(fit.fits, isFalse);
      expect(fit.fontSize, 14);
      expect(fit.rows, 200);
    });
  });

  group('Given wrapping', () {
    const options = CodeBoxOptions(wrap: true, lastLineNumber: 3);

    test('when a long line is fitted then only the wrapped rows constrain the '
        'size', () {
      final fit = CodeAutoFit.fit(['y' * 400], 800, 400, options);

      expect(fit.fits, isTrue);
      expect(fit.rows, greaterThan(1));
      expect(
        fit.columns,
        lessThanOrEqualTo(
          CodeBoxGeometry.compute(800, 400, fit.fontSize, options).wrapColumns,
        ),
      );
    });
  });

  group('Given box geometry', () {
    test('when a window chrome is used then the title bar is 2.2 × the size '
        'even without a title', () {
      final g = CodeBoxGeometry.compute(
        800,
        400,
        20,
        const CodeBoxOptions(chrome: CodeChrome.window),
      );

      expect(g.titleHeight, closeTo(44, 1e-9));
      expect(g.codeArea.top, closeTo(44 + 32, 1e-9));
    });

    test('when a caption is used then it sits above the box', () {
      final g = CodeBoxGeometry.compute(
        800,
        400,
        20,
        const CodeBoxOptions(chrome: CodeChrome.caption, hasTitle: true),
      );

      expect(g.captionHeight, 32);
      expect(g.box.top, 32);
      expect(g.titleHeight, 0);
    });

    test('when line numbers are shown then the gutter is digits + 2 columns '
        'at 0.85 × the size', () {
      final g = CodeBoxGeometry.compute(
        800,
        400,
        20,
        const CodeBoxOptions(chrome: CodeChrome.none, lastLineNumber: 120),
      );

      expect(g.codeArea.left, closeTo(32 + 5 * 0.6 * 17, 1e-9));
      expect(g.numbersRight, closeTo(32 + 4 * 0.6 * 17, 1e-9));
    });
  });
}
