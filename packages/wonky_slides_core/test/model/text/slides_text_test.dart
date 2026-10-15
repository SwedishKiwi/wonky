import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';

String _norm(Object ops, {bool notes = false}) =>
    SlidesText.normalizeJson(jsonEncode(ops), notes: notes)!;

void main() {
  group('Given the Slides text schema', () {
    final cases = <(String, Object, Object)>[
      (
        'drops unknown attributes and adds the final newline',
        [
          {
            'insert': 'a',
            'attributes': {'bold': true, 'foo': 1},
          },
        ],
        [
          {
            'insert': 'a',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
      ),
      (
        'clamps sizes and snaps weights',
        [
          {
            'insert': 'a',
            'attributes': {'size': 1, 'weight': 449},
          },
          {'insert': '\n'},
        ],
        [
          {
            'insert': 'a',
            'attributes': {'size': 6, 'weight': 400},
          },
          {'insert': '\n'},
        ],
      ),
      (
        'keeps theme colors and slide links, drops javascript links',
        [
          {
            'insert': 'a',
            'attributes': {
              'color': 'theme:accent1/lum:+0.2',
              'link': 'slide:0123456789abcdefABCDEF',
            },
          },
          {
            'insert': 'b',
            'attributes': {'link': 'javascript:alert(1)'},
          },
          {'insert': '\n'},
        ],
        [
          {
            'insert': 'a',
            'attributes': {
              'color': 'theme:accent1/lum:+0.2',
              'link': 'slide:0123456789abcdefABCDEF',
            },
          },
          {'insert': 'b\n'},
        ],
      ),
      (
        'keeps block attributes only on newlines',
        [
          {
            'insert': 'a',
            'attributes': {'align': 'center'},
          },
          {
            'insert': '\n',
            'attributes': {'align': 'center', 'list': 'bullet', 'bold': true},
          },
        ],
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'align': 'center', 'list': 'bullet'},
          },
        ],
      ),
    ];
    for (final (what, input, expected) in cases) {
      test('when normalizing then it $what', () {
        expect(jsonDecode(_norm(input)), expected);
      });
    }

    test('when normalizing twice then the result is stable', () {
      final once = _norm([
        {
          'insert': 'x\ty',
          'attributes': {'italic': true},
        },
      ]);

      expect(SlidesText.normalizeJson(once), once);
    });

    test('when normalizing notes then only the notes subset survives', () {
      expect(
        jsonDecode(
          _norm([
            {
              'insert': 'a',
              'attributes': {'bold': true, 'size': 40, 'color': '#ff0000'},
            },
            {
              'insert': '\n',
              'attributes': {'list': 'check', 'indent': 2},
            },
          ], notes: true),
        ),
        [
          {
            'insert': 'a',
            'attributes': {'bold': true},
          },
          {
            'insert': '\n',
            'attributes': {'indent': 2},
          },
        ],
      );
    });

    test('when the JSON is not a Delta then a FormatException is thrown', () {
      expect(
        () => SlidesText.normalizeJson('{"insert":1}'),
        throwsFormatException,
      );
    });

    test('when formatting the second paragraph with a caret then only its '
        'newline gets the block attribute', () {
      final doc = SlidesText.parse(
        jsonEncode([
          {'insert': 'one\ntwo\n'},
        ]),
      );

      final out = SlidesText.format(
        doc,
        const {'style': 'heading'},
        start: 5,
        length: 0,
      );

      expect(out.toJson(), [
        {'insert': 'one\ntwo'},
        {
          'insert': '\n',
          'attributes': {'style': 'heading'},
        },
      ]);
    });

    test('when removing an attribute with null then it is gone', () {
      final doc = SlidesText.parse(
        jsonEncode([
          {
            'insert': 'ab',
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ]),
      );

      final out = SlidesText.format(
        doc,
        const {'bold': null},
        start: 0,
        length: 1,
      );

      expect(out.toJson(), [
        {'insert': 'a'},
        {
          'insert': 'b',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);
    });

    test('when measuring then the length excludes the final newline', () {
      expect(SlidesText.lengthOf('[{"insert":"abc\\n"}]'), 3);
      expect(SlidesText.isBlank('[{"insert":"  \\n"}]'), isTrue);
    });
  });
}
