import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_rich_editor/wonky_rich_editor.dart'
    show MarkdownEditingController;
import 'package:wonky_ui/testing.dart' show settleTooltips;

import '../support/screen_pump.dart';

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  group('Given the composer', () {
    late CommandTestHarness h;
    setUp(() => h = CommandTestHarness());
    tearDown(() => h.dispose());

    Future<TextEditingController> pump(
      WidgetTester tester, {
      String text = '',
      Brightness brightness = Brightness.light,
      VoidCallback? onSubmit,
      ValueChanged<String>? onChanged,
      Future<String?> Function(BuildContext)? requestLink,
      int? maxLength,
      MarkdownProfile profile = MarkdownProfile.comment,
    }) async {
      final c = TextEditingController(text: text);
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
              profile: profile,
              onSubmit: onSubmit,
              onChanged: onChanged,
              requestLink: requestLink,
              maxLength: maxLength,
            ),
          ),
        ),
        brightness: brightness,
      );
      return c;
    }

    MarkdownEditingController rich(WidgetTester tester) =>
        tester.state<MarkdownComposerState>(_key('composer')).editor;

    /// Focuses the field and selects [start]…[end] of its first block.
    Future<void> select(WidgetTester tester, int start, int end) =>
        selectRichText(tester, _key('markdown.composer'), start, end: end);

    Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
      final mod = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.meta
          : LogicalKeyboardKey.control;
      await tester.sendKeyDownEvent(mod);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(mod);
      await tester.pump();
    }

    for (final b in Brightness.values) {
      testWidgets('when tapping the toolbar in ${b.name} then the selection '
          'is formatted and the text holds the Markdown', (tester) async {
        final c = await pump(tester, text: 'hello world', brightness: b);
        await select(tester, 6, 11);
        await tester.tap(_key('markdown.composer.bold'));
        await tester.pump();
        expect(c.text, 'hello **world**');
        await tester.tap(_key('markdown.composer.italic'));
        await tester.pump();
        expect(c.text, 'hello ***world***');
        await tester.tap(_key('markdown.composer.bullets'));
        await tester.pump();
        expect(c.text, '- hello ***world***');
        // No Write | Preview toggle: the field is the preview.
        expect(_key('markdown.composer.preview'), findsNothing);
        await expectAccessible(tester);
        await settleTooltips(tester);
      });
    }

    for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
      testWidgets('when pressing the shortcuts on ${platform.name} then '
          'bold, italic, code, undo and submit run', (tester) async {
        var submitted = 0;
        final c = await pump(
          tester,
          text: 'a b c',
          onSubmit: () => submitted++,
        );
        await select(tester, 0, 1);
        await chord(tester, LogicalKeyboardKey.keyB);
        expect(c.text, '**a** b c');
        await select(tester, 2, 3);
        await chord(tester, LogicalKeyboardKey.keyI);
        expect(c.text, '**a** *b* c');
        await select(tester, 4, 5);
        await chord(tester, LogicalKeyboardKey.keyE);
        expect(c.text, '**a** *b* `c`');
        await chord(tester, LogicalKeyboardKey.keyZ);
        expect(c.text, '**a** *b* c');
        await chord(tester, LogicalKeyboardKey.enter);
        expect(submitted, 1);
      }, variant: TargetPlatformVariant.only(platform));
    }

    testWidgets('when typing Markdown then it is formatted and onChanged '
        'gets the Markdown', (tester) async {
      final changes = <String>[];
      final c = await pump(tester, onChanged: changes.add);
      await typeMarkdown(
        tester,
        _key('markdown.composer'),
        '- [] check `code`',
      );
      expect(c.text, '- [ ] check `code`');
      expect(changes.last, '- [ ] check `code`');
      expect(find.text('Say something', findRichText: true), findsNothing);
    });

    testWidgets('when the text is set from outside then the editor shows it '
        'exactly, and clearing it empties the field', (tester) async {
      final c = await pump(tester, text: '*  loose*');
      expect(rich(tester).markdown, '*  loose*');
      c.text = '## New';
      await tester.pump();
      expect(rich(tester).markdown, '## New');
      c.clear();
      await tester.pump();
      expect(rich(tester).isEmpty, isTrue);
      expect(find.text('Say something', findRichText: true), findsOneWidget);
    });

    testWidgets('when a comment has a # line then it stays text', (
      tester,
    ) async {
      final c = await pump(tester);
      await enterMarkdown(tester, _key('markdown.composer'), '# not a title');
      expect(c.text, '# not a title');
      expect(_key('markdown.composer.quote'), findsNothing);
      await select(tester, 0, 1);
      await chord(tester, LogicalKeyboardKey.keyB);
      expect(c.text, '**#** not a title');
    });

    testWidgets('when pressing Mod+K then the URL dialog makes the selection '
        'a link, and on the link it edits or removes it', (tester) async {
      final c = await pump(tester, text: 'see docs');
      await select(tester, 4, 8);
      await chord(tester, LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(find.text('Insert link'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, 'wonky.work');
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();
      expect(c.text, 'see [docs](https://wonky.work)');

      await select(tester, 5, 5);
      await tester.tap(_key('markdown.composer.link'));
      await tester.pumpAndSettle();
      expect(find.text('Edit link'), findsOneWidget);
      await tester.tap(find.text('Remove link'));
      await tester.pumpAndSettle();
      expect(c.text, 'see docs');
    });

    testWidgets('when the link dialog gets a javascript: URL then it refuses '
        'it', (tester) async {
      final c = await pump(tester, text: 'x');
      await select(tester, 0, 1);
      await tester.tap(_key('markdown.composer.link'));
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

    testWidgets('when a custom link request answers then it is used', (
      tester,
    ) async {
      final c = await pump(
        tester,
        text: 'x',
        requestLink: (_) async => 'https://a.b',
      );
      await select(tester, 0, 1);
      await tester.tap(_key('markdown.composer.link'));
      await tester.pumpAndSettle();
      expect(c.text, '[x](https://a.b)');
    });

    testWidgets('when the text nears the max length then a counter shows', (
      tester,
    ) async {
      final c = await pump(tester, maxLength: 10);
      expect(_key('markdown.composer.count'), findsNothing);
      c.text = '123456789';
      await tester.pump();
      expect(find.text('9 / 10'), findsOneWidget);
    });
  });
}
