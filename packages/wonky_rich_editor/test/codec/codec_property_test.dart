import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_rich_editor/wonky_rich_editor.dart';

const _codec = MarkdownDocumentCodec();

/// Words with the characters Markdown cares about.
const _words = [
  'plain',
  'snake_case',
  'a*b',
  '2 * 3',
  '[x]',
  'a|b',
  '~/p',
  '#tag',
  '<T>',
  'R&D',
  '&amp;',
  '1.',
  '3)',
  '-',
  '+1',
  '>',
  'back`tick',
  r'C:\dir',
  'www.x',
  'https://wonky.work/a',
  'mail@x.y',
  '**',
  '__',
  '`',
  '!',
  '(paren)',
  'é',
  '日本',
  '=',
  '---',
  'x_',
  '_y',
  'end.',
];

/// A random paragraph-like text with random inline styles.
AttributedText _text(Random r, {bool lines = true}) {
  final n = 1 + r.nextInt(6);
  final parts = <String>[];
  for (var i = 0; i < n; i++) {
    parts.add(_words[r.nextInt(_words.length)]);
  }
  var s = parts.join(' ');
  if (lines && r.nextInt(4) == 0) s = '$s\n${_words[r.nextInt(_words.length)]}';
  final t = AttributedText(s);
  for (var k = 0; k < r.nextInt(3); k++) {
    final a = r.nextInt(s.length);
    final b = a + r.nextInt(s.length - a);
    final attribution = [
      boldAttribution,
      italicsAttribution,
      strikethroughAttribution,
      codeAttribution,
      LinkAttribution('https://example.com/${r.nextInt(9)}'),
    ][r.nextInt(5)];
    t.addAttribution(
      attribution,
      SpanRange(a, b),
      overwriteConflictingSpans: true,
    );
  }
  return t;
}

DocumentNode _node(Random r, int i) {
  final id = 'n$i';
  switch (r.nextInt(9)) {
    case 0:
      return ParagraphNode(
        id: id,
        text: _text(r, lines: false),
        metadata: {
          NodeMetadata.blockType: MarkdownDocumentCodec.headerAttribution(
            1 + r.nextInt(3),
          ),
        },
      );
    case 1:
      return ListItemNode.unordered(
        id: id,
        text: _text(r),
        indent: r.nextInt(2),
      );
    case 2:
      return ListItemNode.ordered(id: id, text: _text(r), indent: r.nextInt(2));
    case 3:
      return TaskNode(
        id: id,
        text: _text(r),
        isComplete: r.nextBool(),
        indent: r.nextInt(2),
      );
    case 4:
      return ParagraphNode(
        id: id,
        text: _text(r),
        metadata: {NodeMetadata.blockType: blockquoteAttribution},
      );
    case 5:
      // A fence typed as text stays text (the editor has no code blocks).
      return ParagraphNode(
        id: id,
        text: AttributedText(
          '${_words[r.nextInt(_words.length)]}\n```${r.nextBool() ? 'dart' : ''}\nx',
        ),
      );
    case 6:
      return HorizontalRuleNode(id: id);
    default:
      return ParagraphNode(id: id, text: _text(r));
  }
}

void main() {
  test('Given random documents when written, read and written again then '
      'the Markdown is a fixed point and the text survives', () {
    final r = Random(
      int.parse(const String.fromEnvironment("SEED", defaultValue: "7")),
    );
    for (
      var round = 0;
      round <
          int.parse(
            const String.fromEnvironment("ROUNDS", defaultValue: "300"),
          );
      round++
    ) {
      final doc = MutableDocument(
        nodes: [for (var i = 0; i < 1 + r.nextInt(7); i++) _node(r, i)],
      );
      final once = _codec.encode(doc);
      final back = _codec.decode(once);
      final twice = _codec.encode(back);
      expect(twice, once, reason: 'round $round:\n$once');

      // Strip the remembered sources: the codec's own writing of what it
      // read is the same Markdown again.
      final fresh = MutableDocument(
        nodes: [
          for (final n in back)
            n.copyAndReplaceMetadata({
              for (final e in n.metadata.entries)
                if (!{
                  MarkdownNodeMetadata.source,
                  MarkdownNodeMetadata.canonical,
                  MarkdownNodeMetadata.gap,
                  MarkdownNodeMetadata.previous,
                  MarkdownNodeMetadata.kind,
                }.contains(e.key))
                  e.key: e.value,
            }),
        ],
      );
      expect(_codec.encode(fresh), once, reason: 'round $round:\n$once');

      // No block became literal text, and the words are all there.
      expect(
        back.where((n) => n.getMetadataValue(MarkdownNodeMetadata.raw) == true),
        isEmpty,
        reason: 'round $round:\n$once',
      );
    }
  });
}
