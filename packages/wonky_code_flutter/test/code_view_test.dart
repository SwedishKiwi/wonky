import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool bounded = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: bounded
            ? SizedBox(width: 600, height: 300, child: child)
            : SingleChildScrollView(child: child),
      ),
    ),
  );
}

/// The rich text spans of the code lines (not the line numbers).
Iterable<TextSpan> _lineSpans(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text)
    .whereType<TextSpan>();

/// The color of the run [text] in any rendered line.
Color? _colorOf(WidgetTester tester, String text) {
  for (final line in _lineSpans(tester)) {
    Color? found;
    line.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.style?.color ?? line.style?.color;
        return false;
      }
      return true;
    });
    if (found != null) return found;
  }
  return null;
}

const _dart = 'void main() {\n  // greet\n  print("hi");\n}';

void main() {
  for (final brightness in Brightness.values) {
    group('Given Dart code in a ${brightness.name} app', () {
      final palette = brightness == Brightness.dark
          ? BuiltInPalettes.wonkyDark
          : BuiltInPalettes.wonkyLight;

      testWidgets('when shown then every line and its number is visible', (
        tester,
      ) async {
        await _pump(
          tester,
          const CodeView(code: _dart, language: 'dart'),
          brightness: brightness,
        );

        expect(find.text('  // greet', findRichText: true), findsOneWidget);
        for (final n in ['1', '2', '3', '4']) {
          expect(find.text(n), findsOneWidget);
        }
      });

      testWidgets('when shown then keywords use the default '
          '${brightness.name} palette', (tester) async {
        await _pump(
          tester,
          const CodeView(code: _dart, language: 'dart'),
          brightness: brightness,
        );

        expect(
          _colorOf(tester, '// greet'),
          Color(palette.styleOf(SyntaxToken.comment).color),
        );
        final box = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(CodeView),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(box.color, Color(palette.background));
      });
    });
  }

  group('Given a code view', () {
    testWidgets('when line numbers are off then no numbers are shown', (
      tester,
    ) async {
      await _pump(tester, const CodeView(code: 'a\nb', lineNumbers: false));

      expect(find.text('1'), findsNothing);
      expect(find.text('b', findRichText: true), findsOneWidget);
    });

    testWidgets('when starting at line 41 then numbers start at 41', (
      tester,
    ) async {
      await _pump(tester, const CodeView(code: 'a\nb', startLine: 41));

      expect(find.text('41'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('when a fixed palette is given then it wins over the theme', (
      tester,
    ) async {
      final palette = BuiltInPalettes.dracula;
      await _pump(
        tester,
        CodeView(code: _dart, language: 'dart', palette: palette),
      );

      expect(
        _colorOf(tester, '// greet'),
        Color(palette.styleOf(SyntaxToken.comment).color),
      );
    });

    testWidgets('when the language is plain then all text has the text color', (
      tester,
    ) async {
      final palette = BuiltInPalettes.wonkyLight;
      await _pump(
        tester,
        CodeView(code: _dart, palette: palette, lineNumbers: false),
      );

      expect(_colorOf(tester, '// greet'), isNull);
      expect(_lineSpans(tester).map((s) => s.style?.color).toSet(), {
        Color(palette.text),
      });
    });

    testWidgets('when wrapping then a long line wraps instead of scrolling', (
      tester,
    ) async {
      final long = List.filled(60, 'word').join(' ');
      await _pump(tester, CodeView(code: long, wrap: true));

      final size = tester.getSize(find.text(long, findRichText: true));
      expect(size.width, lessThanOrEqualTo(600));
      expect(size.height, greaterThan(40));
    });

    testWidgets('when not wrapping then a long line scrolls horizontally', (
      tester,
    ) async {
      final long = List.filled(60, 'word').join(' ');
      await _pump(tester, CodeView(code: long));

      expect(
        tester.getSize(find.text(long, findRichText: true)).width,
        greaterThan(600),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('when the height is unbounded then every line is laid out', (
      tester,
    ) async {
      final code = List.generate(80, (i) => 'line ${i + 1}').join('\n');
      await _pump(tester, CodeView(code: code), bounded: false);

      expect(find.text('line 80', findRichText: true), findsOneWidget);
    });

    testWidgets('when the code is long then only visible lines are built', (
      tester,
    ) async {
      final code = List.generate(5000, (i) => 'line ${i + 1}').join('\n');
      await _pump(tester, CodeView(code: code));

      expect(find.text('line 1', findRichText: true), findsOneWidget);
      expect(find.text('line 5000', findRichText: true), findsNothing);
    });

    testWidgets('when scrolling the code then the line numbers follow', (
      tester,
    ) async {
      final code = List.generate(500, (i) => 'line ${i + 1}').join('\n');
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(tester, CodeView(code: code, verticalController: controller));
      final lineHeight =
          tester.getTopLeft(find.text('line 2', findRichText: true)).dy -
          tester.getTopLeft(find.text('line 1', findRichText: true)).dy;

      controller.jumpTo(lineHeight * 100);
      await tester.pump();

      expect(find.text('1'), findsNothing);
      final line = tester.getTopLeft(find.text('line 102', findRichText: true));
      final number = tester.getTopLeft(find.text('102'));
      expect(number.dy, closeTo(line.dy, 1));
    });

    testWidgets('when the code is larger than the sync limit then it is '
        'highlighted after the first frame', (tester) async {
      final palette = BuiltInPalettes.wonkyLight;
      await _pump(
        tester,
        CodeView(
          code: _dart,
          language: 'dart',
          palette: palette,
          syncHighlightLength: 10,
        ),
      );
      expect(_colorOf(tester, '// greet'), isNull);

      await tester.pump(const Duration(milliseconds: 1));

      expect(
        _colorOf(tester, '// greet'),
        Color(palette.styleOf(SyntaxToken.comment).color),
      );
    });

    testWidgets(
      'when lines are highlighted then their rows get the bar color',
      (tester) async {
        final palette = BuiltInPalettes.wonkyLight;
        await _pump(
          tester,
          CodeView(code: _dart, palette: palette, highlightedLines: const {2}),
        );

        final number = tester.widget<Text>(find.text('2'));
        expect(number.style?.color, Color(palette.lineNumberActive));
        expect(
          tester.widget<Text>(find.text('1')).style?.color,
          Color(palette.lineNumber),
        );
      },
    );

    testWidgets('when selectable then the code is in a selection area', (
      tester,
    ) async {
      await _pump(tester, const CodeView(code: _dart));

      expect(find.byType(SelectionArea), findsOneWidget);
    });

    testWidgets('when not selectable then there is no selection area', (
      tester,
    ) async {
      await _pump(tester, const CodeView(code: _dart, selectable: false));

      expect(find.byType(SelectionArea), findsNothing);
    });

    testWidgets('when labelled then the label is in the semantics tree', (
      tester,
    ) async {
      await _pump(
        tester,
        const CodeView(code: _dart, semanticsLabel: 'main.dart'),
      );

      expect(find.bySemanticsLabel(RegExp('main.dart')), findsOneWidget);
    });
  });
}
