import 'package:test/test.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart';

import 'support/property.dart';

void main() {
  group('Given inline Markdown', () {
    test('when parsing emphasis, code and links then runs carry the '
        'formatting', () {
      final runs = InlineMarkdown.parse(
        'Plain **bold *both*** `code` [link](https://x.org) ~~gone~~',
      );

      expect(runs, [
        const InlineRun('Plain '),
        const InlineRun('bold ', bold: true),
        const InlineRun('both', bold: true, italic: true),
        const InlineRun(' '),
        const InlineRun('code', code: true),
        const InlineRun(' '),
        const InlineRun('link', link: 'https://x.org'),
        const InlineRun(' '),
        const InlineRun('gone', strike: true),
      ]);
    });

    test('when a link target is not allowed then the text is kept and a '
        'warning is reported', () {
      final warnings = <ImportWarning>[];

      final runs = InlineMarkdown.parse(
        '[x](javascript:alert(1))',
        warnings: warnings,
      );

      expect(InlineRun.plainText(runs), 'x');
      expect(runs.single.link, isNull);
      expect(warnings.single.kind, ImportWarningKind.unsupportedLink);
    });

    test('when a mention link is parsed then the user uuid is kept', () {
      final runs = InlineMarkdown.parse(
        '[@Anna](mailto:anna@x.com "${mentionTitlePrefix}u-1")',
      );

      expect(runs.single.mentionUserUuid, 'u-1');
      expect(runs.single.toAttributes(), {
        'link': 'mailto:anna@x.com',
        'mention': 'u-1',
      });
    });

    test('when writing plain text with Markdown syntax then it is escaped', () {
      const text = r'1. *not* [a] _b_ # \x';

      final md = InlineMarkdownWriter.escapePlain(text);

      expect(InlineMarkdown.toPlainText(md), text);
    });

    test('when writing runs then the emphasis style is respected', () {
      const runs = [InlineRun('a', bold: true), InlineRun('b', italic: true)];

      expect(InlineMarkdownWriter.write(runs), '**a***b*');
      expect(
        InlineMarkdownWriter.write(runs, style: EmphasisStyle.html),
        '<strong>a</strong><em>b</em>',
      );
    });

    test('when converting runs to Delta attributes and back then they are '
        'equal', () {
      const run = InlineRun('x', bold: true, link: 'https://x.org');

      expect(InlineRun.fromAttributes('x', run.toAttributes()), run);
      expect(const InlineRun('x').toAttributes(), isNull);
    });

    propertyTest('when random runs are written and parsed back then the '
        'runs survive', (random, run) {
      const pieces = [
        'a',
        'b c',
        '*',
        '_',
        '`',
        '[',
        ']',
        '\\',
        '<b>',
        '&',
        '1.',
      ];
      final runs = InlineRun.merge([
        for (var i = 0; i < 1 + random.nextInt(5); i++)
          InlineRun(
            pieces[random.nextInt(pieces.length)],
            bold: random.nextBool(),
            italic: random.nextBool(),
            strike: random.nextInt(4) == 0,
          ),
      ]);

      final md = InlineMarkdownWriter.write(runs, style: EmphasisStyle.html);

      expect(InlineMarkdown.parse(md), runs, reason: md);
    }, runs: 100);
  });

  group('Given the Delta helpers', () {
    test('when canonicalizing then adjacent equal inserts merge and empty '
        'ops go', () {
      final d = Delta()
        ..insert('a', {'bold': true})
        ..insert('')
        ..insert('b', {'bold': true});

      expect(DeltaUtils.canonical(d).toJson(), [
        {
          'insert': 'ab',
          'attributes': {'bold': true},
        },
      ]);
    });

    test('when splitting attributes then inline, block and overlay keys are '
        'separated', () {
      final attrs = {
        WonkyAttr.bold: true,
        WonkyAttr.header: 2,
        WonkyAttr.commentKey('t1'): true,
      };

      expect(Attributes.inline(attrs), {WonkyAttr.bold: true});
      expect(Attributes.block(attrs), {WonkyAttr.header: 2});
      expect(Attributes.overlays(attrs).keys, ['cmt_t1']);
    });

    test('when checking links then only allowed schemes pass', () {
      expect(LinkPolicy.isValidLink('https://x.org'), isTrue);
      expect(LinkPolicy.isValidLink('wonky://doc/1'), isTrue);
      expect(LinkPolicy.isValidLink('javascript:x'), isFalse);
      expect(
        LinkPolicy.normalizeLink('https://x.org/a b'),
        'https://x.org/a%20b',
      );
    });
  });
}
