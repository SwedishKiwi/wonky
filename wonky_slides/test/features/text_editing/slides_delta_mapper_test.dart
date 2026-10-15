import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_slides/features/text_editing/slides_delta_mapper.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart' show TextBody;

/// Bodies of the Slides text schema (02 §4.1) that must survive
/// Delta → super_editor document → Delta unchanged.
final _cases = <String, List<Map<String, Object?>>>{
  'empty body': [
    {'insert': '\n'},
  ],
  'plain paragraphs and an empty one': [
    {'insert': 'One\n\nThree\n'},
  ],
  'every boolean inline attribute': [
    {
      'insert': 'b',
      'attributes': {'bold': true},
    },
    {
      'insert': 'i',
      'attributes': {'italic': true},
    },
    {
      'insert': 'u',
      'attributes': {'underline': true},
    },
    {
      'insert': 's',
      'attributes': {'strike': true},
    },
    {
      'insert': 'c',
      'attributes': {'code': true},
    },
    {'insert': '\n'},
  ],
  'valued inline attributes': [
    {
      'insert': 'Big',
      'attributes': {'size': 64, 'font': '@heading', 'weight': 700},
    },
    {
      'insert': ' red',
      'attributes': {'color': 'theme:accent1', 'highlight': '#ffee00'},
    },
    {
      'insert': ' caps',
      'attributes': {'caps': 'small', 'letterSpacing': 0.1},
    },
    {
      'insert': '2',
      'attributes': {'script': 'super'},
    },
    {
      'insert': 'x',
      'attributes': {'script': 'sub'},
    },
    {
      'insert': ' link',
      'attributes': {'link': 'https://example.com/'},
    },
    {'insert': '\n'},
  ],
  'block attributes': [
    {'insert': 'Title'},
    {
      'insert': '\n',
      'attributes': {
        'style': 'title',
        'align': 'center',
        'lineHeight': 1.4,
        'spaceBefore': 12,
        'spaceAfter': 24,
      },
    },
    {'insert': 'RTL'},
    {
      'insert': '\n',
      'attributes': {'dir': 'rtl', 'indent': 2},
    },
  ],
  'lists, levels, styles and tasks': [
    {'insert': 'Bullet'},
    {
      'insert': '\n',
      'attributes': {'list': 'bullet', 'listStyle': 'dash'},
    },
    {'insert': 'Nested'},
    {
      'insert': '\n',
      'attributes': {'list': 'bullet', 'indent': 1},
    },
    {'insert': 'First'},
    {
      'insert': '\n',
      'attributes': {
        'list': 'ordered',
        'listStart': 3,
        'listStyle': 'upperRoman',
      },
    },
    {'insert': 'Done'},
    {
      'insert': '\n',
      'attributes': {'list': 'check'},
    },
    {'insert': 'Open'},
    {
      'insert': '\n',
      'attributes': {'list': 'unchecked', 'indent': 1},
    },
  ],
  'soft line breaks and emoji': [
    {'insert': 'Line one line two 🚀\n'},
  ],
};

void main() {
  const mapper = SlidesDeltaMapper();

  group('Given Slides text bodies', () {
    for (final MapEntry(key: name, value: ops) in _cases.entries) {
      test('when "$name" maps to a document and back then the Delta is '
          'unchanged', () {
        final stored = SlidesText.normalize(Delta.fromJson(ops));

        final doc = mapper.documentFromBody(TextBody(ops));
        final back = mapper.deltaOf(doc);

        expect(sameDelta(back, stored), isTrue, reason: '$back != $stored');
      });
    }

    test('when mapped then every paragraph is one node of the right kind', () {
      final doc = mapper.documentFromBody(
        TextBody(_cases['lists, levels, styles and tasks']!),
      );

      expect(doc.map((n) => n.runtimeType).toList(), [
        ListItemNode,
        ListItemNode,
        ListItemNode,
        TaskNode,
        TaskNode,
      ]);
      expect((doc.getNodeAt(1)! as ListItemNode).indent, 1);
      expect((doc.getNodeAt(2)! as ListItemNode).type, ListItemType.ordered);
      expect((doc.getNodeAt(3)! as TaskNode).isComplete, isTrue);
    });

    test('when a soft break is mapped then the node holds a newline and the '
        'Delta U+2028', () {
      final doc = mapper.documentFromBody(
        TextBody(_cases['soft line breaks and emoji']!),
      );
      final node = doc.first as ParagraphNode;

      expect(node.text.toPlainText(), 'Line one\nline two 🚀');
      expect(mapper.jsonOf(doc), contains(r' '));
    });
  });

  group('Given an editor over a mapped body', () {
    late MutableDocument doc;
    late Editor editor;
    late MutableDocumentComposer composer;

    setUp(() {
      doc = mapper.documentFromBody(
        TextBody([
          {'insert': 'Hello world'},
          {
            'insert': '\n',
            'attributes': {'style': 'heading', 'align': 'center'},
          },
        ]),
      );
      composer = MutableDocumentComposer();
      editor = createDefaultDocumentEditor(document: doc, composer: composer);
    });

    test(
      'when bold is toggled on a word then the Delta carries bold on it',
      () {
        final id = doc.first.id;
        editor.execute([
          ToggleTextAttributionsRequest(
            documentRange: DocumentRange(
              start: DocumentPosition(
                nodeId: id,
                nodePosition: const TextNodePosition(offset: 6),
              ),
              end: DocumentPosition(
                nodeId: id,
                nodePosition: const TextNodePosition(offset: 11),
              ),
            ),
            attributions: {boldAttribution},
          ),
        ]);

        expect(jsonDecode(mapper.jsonOf(doc)), [
          {'insert': 'Hello '},
          {
            'insert': 'world',
            'attributes': {'bold': true},
          },
          {
            'insert': '\n',
            'attributes': {'style': 'heading', 'align': 'center'},
          },
        ]);
      },
    );

    test('when Enter splits the paragraph then both halves keep the '
        'paragraph attributes', () {
      final id = doc.first.id;
      editor.execute([
        SplitParagraphRequest(
          nodeId: id,
          splitPosition: const TextNodePosition(offset: 5),
          newNodeId: Editor.createNodeId(),
          replicateExistingMetadata: true,
        ),
      ]);

      expect(jsonDecode(mapper.jsonOf(doc)), [
        {'insert': 'Hello'},
        {
          'insert': '\n',
          'attributes': {'style': 'heading', 'align': 'center'},
        },
        {'insert': ' world'},
        {
          'insert': '\n',
          'attributes': {'style': 'heading', 'align': 'center'},
        },
      ]);
    });
  });
}
