import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';

import '../support/screen_pump.dart';

/// `[` and `]` mark the selection (one `|` marks a caret).
TextEditingValue _v(String marked) {
  final caret = marked.indexOf('|');
  if (caret >= 0) {
    return TextEditingValue(
      text: marked.replaceFirst('|', ''),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
  final start = marked.indexOf('[');
  final end = marked.indexOf(']') - 1;
  return TextEditingValue(
    text: marked.replaceFirst('[', '').replaceFirst(']', ''),
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );
}

String _marked(TextEditingValue v) {
  final s = v.selection;
  if (s.isCollapsed) return v.text.replaceRange(s.start, s.start, '|');
  return v.text
      .replaceRange(s.end, s.end, ']')
      .replaceRange(s.start, s.start, '[');
}

void main() {
  group('Given the Markdown edits', () {
    test('when bolding a selection twice then it wraps and unwraps', () {
      final once = MarkdownEdits.bold(_v('a [word] b'));
      expect(_marked(once), 'a **[word]** b');
      expect(_marked(MarkdownEdits.bold(once)), 'a [word] b');
      // Selecting the markup too also unwraps.
      expect(_marked(MarkdownEdits.bold(_v('a [**word**] b'))), 'a [word] b');
    });

    test('when italicizing bold text then both apply, and italic toggles '
        'without touching the bold', () {
      final bi = MarkdownEdits.italic(_v('**[x]**'));
      expect(_marked(bi), '***[x]***');
      expect(_marked(MarkdownEdits.italic(bi)), '**[x]**');
      expect(_marked(MarkdownEdits.italic(_v('[x]'))), '*[x]*');
    });

    test(
      'when the selection has surrounding spaces then they stay outside',
      () {
        expect(_marked(MarkdownEdits.bold(_v('a[ word ]b'))), 'a **[word]** b');
      },
    );

    test('when nothing is selected then the markup is inserted around the '
        'caret', () {
      expect(_marked(MarkdownEdits.bold(_v('ab|'))), 'ab**|**');
      expect(_marked(MarkdownEdits.code(_v('|'))), '`|`');
    });

    test('when code contains backticks then a longer fence is used', () {
      expect(_marked(MarkdownEdits.code(_v('[a`b]'))), '``[a`b]``');
      expect(_marked(MarkdownEdits.code(_v('[`a]'))), '`` [`a] ``');
    });

    test('when code spans lines then it becomes a fenced block and back', () {
      final fenced = MarkdownEdits.code(_v('x\n[a\nb]\ny'));
      expect(fenced.text, 'x\n```\na\nb\n```\ny');
      final again = MarkdownEdits.code(
        fenced.copyWith(
          selection: const TextSelection(baseOffset: 2, extentOffset: 13),
        ),
      );
      expect(again.text, 'x\na\nb\ny');
    });

    test('when bolding several lines then each line is wrapped', () {
      expect(MarkdownEdits.bold(_v('[a\n\nb]')).text, '**a**\n\n**b**');
    });

    test('when linking then the selection is the label and the caret ends '
        'after the link', () {
      expect(
        _marked(MarkdownEdits.link(_v('see [docs] now'), 'https://a.b')),
        'see [docs](https://a.b)| now',
      );
      expect(
        _marked(MarkdownEdits.link(_v('|'), 'https://a.b/x y')),
        '[https://a.b/x y](<https://a.b/x y>)|',
      );
    });

    test('when toggling bullets then lines get and lose `- `', () {
      final on = MarkdownEdits.bullets(_v('[a\nb]'));
      expect(on.text, '- a\n- b');
      expect(MarkdownEdits.bullets(on).text, 'a\nb');
      expect(_marked(MarkdownEdits.bullets(_v('x\nab|'))), 'x\n- ab|');
    });
  });

  group('Given the composer', () {
    late CommandTestHarness h;
    setUp(() => h = CommandTestHarness());
    tearDown(() => h.dispose());

    Future<TextEditingController> pump(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      VoidCallback? onSubmit,
      Future<String?> Function(BuildContext)? requestLink,
      int? maxLength,
    }) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await pumpScreen(
        tester,
        h,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            child: MarkdownComposer(
              key: const ValueKey<String>('composer'),
              controller: c,
              hint: 'Say something',
              onSubmit: onSubmit,
              requestLink: requestLink,
              maxLength: maxLength,
            ),
          ),
        ),
        brightness: brightness,
      );
      return c;
    }

    Future<void> select(
      WidgetTester tester,
      TextEditingController c,
      String text,
      int start,
      int end,
    ) async {
      await tester.tap(find.byKey(const ValueKey('markdown.composer')));
      await tester.pump();
      c.value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: start, extentOffset: end),
      );
      await tester.pump();
    }

    for (final b in Brightness.values) {
      testWidgets('when tapping the toolbar in ${b.name} then the selection '
          'is wrapped', (tester) async {
        final c = await pump(tester, brightness: b);
        await select(tester, c, 'hello world', 6, 11);
        await tester.tap(find.byKey(const ValueKey('markdown.composer.bold')));
        await tester.pump();
        expect(c.text, 'hello **world**');
        await tester.tap(
          find.byKey(const ValueKey('markdown.composer.italic')),
        );
        await tester.pump();
        expect(c.text, 'hello ***world***');
        await tester.tap(
          find.byKey(const ValueKey('markdown.composer.bullets')),
        );
        await tester.pump();
        expect(c.text, '- hello ***world***');
        await expectAccessible(tester);
      });
    }

    for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
      testWidgets('when pressing the shortcuts on ${platform.name} then '
          'bold, italic, code and submit run', (tester) async {
        final mod = platform == TargetPlatform.macOS
            ? LogicalKeyboardKey.meta
            : LogicalKeyboardKey.control;
        Future<void> chord(LogicalKeyboardKey key) async {
          await tester.sendKeyDownEvent(mod);
          await tester.sendKeyEvent(key);
          await tester.sendKeyUpEvent(mod);
          await tester.pump();
        }

        var submitted = 0;
        final c = await pump(tester, onSubmit: () => submitted++);
        await select(tester, c, 'a b c', 0, 1);
        await chord(LogicalKeyboardKey.keyB);
        expect(c.text, '**a** b c');
        c.selection = const TextSelection(baseOffset: 6, extentOffset: 7);
        await chord(LogicalKeyboardKey.keyI);
        expect(c.text, '**a** *b* c');
        c.selection = const TextSelection(baseOffset: 10, extentOffset: 11);
        await chord(LogicalKeyboardKey.keyE);
        expect(c.text, '**a** *b* `c`');
        await chord(LogicalKeyboardKey.enter);
        expect(submitted, 1);
      }, variant: TargetPlatformVariant.only(platform));
    }

    testWidgets('when pressing Mod+K then the URL dialog makes the selection '
        'a link', (tester) async {
      final c = await pump(tester);
      await select(tester, c, 'see docs', 4, 8);
      final mod = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.meta
          : LogicalKeyboardKey.control;
      await tester.sendKeyDownEvent(mod);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(mod);
      await tester.pumpAndSettle();
      expect(find.text('Insert link'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'wonky.work');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();
      expect(c.text, 'see [docs](https://wonky.work)');
    });

    testWidgets('when the link dialog gets a javascript: URL then it refuses '
        'it', (tester) async {
      final c = await pump(tester);
      await select(tester, c, 'x', 0, 1);
      await tester.tap(find.byKey(const ValueKey('markdown.composer.link')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'javascript:1');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a web (http or https) or email (mailto) link'),
        findsOneWidget,
      );
      expect(c.text, 'x');
    });

    testWidgets('when switching to Preview then the Markdown renders, and '
        'Write brings the field back', (tester) async {
      final c = await pump(tester);
      await select(tester, c, '**Hi** there', 0, 0);
      await tester.tap(find.byKey(const ValueKey('markdown.composer.preview')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('markdown.composer.rendered')),
        findsOneWidget,
      );
      expect(find.text('Hi there'), findsOneWidget);
      expect(find.byKey(const ValueKey('markdown.composer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('markdown.composer.write')));
      await tester.pump();
      expect(find.byKey(const ValueKey('markdown.composer')), findsOneWidget);
      expect(c.text, '**Hi** there');
    });

    testWidgets('when the text nears the max length then a counter shows', (
      tester,
    ) async {
      final c = await pump(tester, maxLength: 10);
      expect(
        find.byKey(const ValueKey('markdown.composer.count')),
        findsNothing,
      );
      c.text = '123456789';
      await tester.pump();
      expect(find.text('9 / 10'), findsOneWidget);
    });
  });
}
