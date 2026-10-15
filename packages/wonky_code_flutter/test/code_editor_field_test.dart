import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';

const _dart = 'void main() {\n  print("hi");\n}';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SizedBox(width: 600, height: 300, child: child)),
    ),
  );
  await tester.pump();
}

/// Unmounts the field and lets its timers finish.
Future<void> _done(WidgetTester tester) async {
  // re_editor's mobile caret starts blinking 100 ms after focus (tests run
  // as Android): let it start before unmounting.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

CodeEditorFieldState _state(WidgetTester tester) =>
    tester.state<CodeEditorFieldState>(find.byType(CodeEditorField));

void main() {
  for (final brightness in Brightness.values) {
    final palette = brightness == Brightness.dark
        ? BuiltInPalettes.wonkyDark
        : BuiltInPalettes.wonkyLight;

    group(
      'Given a code editor field with Dart in a ${brightness.name} app',
      () {
        testWidgets('when shown then it holds the code and paints its gutter', (
          tester,
        ) async {
          await _pump(
            tester,
            CodeEditorField(
              text: _dart,
              language: 'dart',
              palette: palette,
              gutter: const CodeEditorGutter(width: 48, numbersRight: 40),
            ),
            brightness: brightness,
          );

          expect(_state(tester).controller.text, _dart);
          expect(tester.takeException(), isNull);
          await _done(tester);
        });

        testWidgets('when typing then every edit reports the whole text', (
          tester,
        ) async {
          final seen = <String>[];
          await _pump(
            tester,
            CodeEditorField(
              text: 'a',
              language: 'dart',
              palette: palette,
              onChanged: seen.add,
            ),
            brightness: brightness,
          );
          final c = _state(tester).controller;
          c.selection = CodeLineSelection.collapsed(index: 0, offset: 1);
          c.replaceSelection('b');
          await tester.pump();

          expect(seen, ['ab']);
          await _done(tester);
        });
      },
    );
  }

  group('Given a code editor field', () {
    testWidgets('when the external text changes then the field takes it '
        'over without reporting it back', (tester) async {
      final seen = <String>[];
      Widget field(String text) => CodeEditorField(
        text: text,
        palette: BuiltInPalettes.wonkyLight,
        onChanged: seen.add,
      );
      await _pump(tester, field('one'));
      await _pump(tester, field('one\ntwo'));

      expect(_state(tester).controller.text, 'one\ntwo');
      expect(seen, isEmpty);
      await _done(tester);
    });

    testWidgets('when Escape is pressed then the field asks to exit', (
      tester,
    ) async {
      var exits = 0;
      await _pump(
        tester,
        CodeEditorField(
          text: 'x',
          palette: BuiltInPalettes.wonkyLight,
          onExit: () => exits++,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(exits, 1);
      await _done(tester);
    });

    test('when asking for comment prefixes then they follow the language', () {
      expect(CodeEditorField.commentPrefixOf('dart'), '//');
      expect(CodeEditorField.commentPrefixOf('python'), '#');
      expect(CodeEditorField.commentPrefixOf('sql'), '--');
      expect(CodeEditorField.commentPrefixOf(''), isNull);
    });
  });
}
