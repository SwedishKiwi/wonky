import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';

import '../support/screen_pump.dart';

/// The plain text of every rich text under [finder].
String _textOf(WidgetTester tester, Finder finder) => tester
    .widgetList<RichText>(
      find.descendant(of: finder, matching: find.byType(RichText)),
    )
    .map((r) => r.text.toPlainText())
    .join('\n');

/// The leaf spans that carry a tap recognizer.
List<TextSpan> _links(WidgetTester tester) {
  final out = <TextSpan>[];
  for (final r in tester.widgetList<RichText>(find.byType(RichText))) {
    r.text.visitChildren((s) {
      if (s is TextSpan && s.recognizer != null && s.text != null) out.add(s);
      return true;
    });
  }
  return out;
}

void main() {
  late CommandTestHarness h;
  setUp(() => h = CommandTestHarness());
  tearDown(() => h.dispose());

  Future<void> pump(
    WidgetTester tester,
    String text,
    MarkdownProfile profile, {
    Brightness brightness = Brightness.light,
    void Function(String url)? onOpenLink,
  }) => pumpScreen(
    tester,
    h,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 600,
        child: WonkyMarkdown(
          text,
          key: const ValueKey<String>('md'),
          profile: profile,
          onOpenLink: onOpenLink,
        ),
      ),
    ),
    brightness: brightness,
  );

  group('Given the post profile', () {
    for (final b in Brightness.values) {
      testWidgets('when rendering headings, lists, quotes, code and tables '
          'in ${b.name} then each renders without its markup', (tester) async {
        await pump(
          tester,
          '# Title\n\nSome **bold**, *italic*, ~~gone~~ and `code`.\n\n'
          '- one\n- two\n\n> quoted\n\n```dart\nfinal x = 1;\n```\n\n'
          '| A | B |\n|---|---|\n| 1 | 2 |\n',
          MarkdownProfile.post,
          brightness: b,
        );
        final text = _textOf(tester, find.byKey(const ValueKey('md')));
        expect(text, contains('Title'));
        expect(text, isNot(contains('#')));
        expect(text, contains('Some bold, italic, gone and code.'));
        expect(find.text('•'), findsNWidgets(2));
        expect(text, contains('quoted'));
        expect(text, isNot(contains('>')));
        expect(find.text('final x = 1;'), findsOneWidget);
        expect(find.byType(Table), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('markdown.code.copy')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('when rendering an h1 then it is no larger than an h3', (
      tester,
    ) async {
      await pump(tester, '# Big\n\n### Small', MarkdownProfile.post);
      double sizeOf(String t) {
        final rich = tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == t,
          ),
        );
        // Text.rich wraps our span in the default style.
        final ours = (rich.text as TextSpan).children!.single as TextSpan;
        return ours.style!.fontSize!;
      }

      expect(sizeOf('Big'), sizeOf('Small'));
    });

    testWidgets('when rendering an image or raw HTML then the image is a link '
        'and the HTML is text', (tester) async {
      await pump(
        tester,
        '![a cat](https://example.com/cat.png) <b>hi</b>',
        MarkdownProfile.post,
      );
      final text = _textOf(tester, find.byKey(const ValueKey('md')));
      expect(text, 'a cat <b>hi</b>');
      expect(find.byType(Image), findsNothing);
      expect(_links(tester).single.text, 'a cat');
    });
  });

  group('Given the comment profile', () {
    testWidgets('when rendering headings, quotes and tables then they stay '
        'text, while lists, code and inline styles render', (tester) async {
      await pump(
        tester,
        '# Not a heading\n> not a quote\n\n- item **bold**\n\n```\ncode\n```',
        MarkdownProfile.comment,
      );
      final text = _textOf(tester, find.byKey(const ValueKey('md')));
      expect(text, contains('# Not a heading\n> not a quote'));
      expect(text, contains('item bold'));
      expect(find.text('•'), findsOneWidget);
      expect(find.text('code'), findsOneWidget);
      // Comments have no copy button on code.
      expect(find.byType(ShadIconButton), findsNothing);
    });

    testWidgets('when a comment has line breaks then they are kept', (
      tester,
    ) async {
      await pump(tester, 'first\nsecond', MarkdownProfile.comment);
      expect(find.text('first\nsecond'), findsOneWidget);
    });
  });

  group('Given links', () {
    for (final url in [
      'https://example.com/a',
      'http://example.com',
      'mailto:ada@example.com',
    ]) {
      testWidgets('when tapping a $url link then the external-link '
          'confirmation opens it', (tester) async {
        await pump(tester, 'See [the page]($url).', MarkdownProfile.comment);
        await tester.tapOnText(find.textRange.ofSubstring('the page'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('dialog.externalLink')),
          findsOneWidget,
        );
        expect(h.crossApp.external, isEmpty);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(h.crossApp.external, [url]);
      });
    }

    for (final src in [
      '[x](javascript:alert(1))',
      '[x](data:text/html,hi)',
      '[x](file:///etc/passwd)',
      '[x](JavaScript:alert)',
      '[x](/relative)',
    ]) {
      testWidgets('when the link is $src then it renders as its source text', (
        tester,
      ) async {
        await pump(tester, src, MarkdownProfile.post);
        expect(_links(tester), isEmpty);
        expect(_textOf(tester, find.byKey(const ValueKey('md'))), src);
      });
    }

    testWidgets('when a bare https URL is in the text then it is a link', (
      tester,
    ) async {
      final opened = <String>[];
      await pump(
        tester,
        'Go to https://wonky.work/x.',
        MarkdownProfile.comment,
        onOpenLink: opened.add,
      );
      final link = _links(tester).single;
      expect(link.text, 'https://wonky.work/x');
      (link.recognizer! as TapGestureRecognizer).onTap!();
      expect(opened, ['https://wonky.work/x']);
    });

    testWidgets('when the assistant renders a link then it is styled but '
        'not tappable', (tester) async {
      await pump(
        tester,
        '[docs](https://example.com)',
        MarkdownProfile.assistant,
      );
      expect(_links(tester), isEmpty);
      expect(_textOf(tester, find.byKey(const ValueKey('md'))), 'docs');
    });
  });

  group('Given inline Markdown', () {
    test(
      'when checking URLs then only http(s) with a host and mailto pass',
      () {
        expect(MarkdownInline.safeUrl('https://a.b'), 'https://a.b');
        expect(MarkdownInline.safeUrl('HTTP://a.b'), 'HTTP://a.b');
        expect(MarkdownInline.safeUrl('mailto:a@b.c'), 'mailto:a@b.c');
        for (final bad in [
          'javascript:alert(1)',
          'data:text/html,x',
          'file:///x',
          'https://',
          '//a.b',
          'vbscript:x',
        ]) {
          expect(MarkdownInline.safeUrl(bad), isNull, reason: bad);
        }
      },
    );

    test('when text has escapes, snake_case and code with backticks then '
        'they render literally', () {
      final span = MarkdownInline.spans(
        r'\*not italic\* snake_case_name ``a`b``',
        const TextStyle(fontSize: 14),
        const ShadSlateColorScheme.light(),
      );
      expect(span.toPlainText(), '*not italic* snake_case_name a`b');
    });
  });
}
