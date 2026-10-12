import 'package:test/test.dart';
import 'package:wonky_write_core/testing.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../support/property.dart';

Delta d(List<Map<String, dynamic>> json) => Delta.fromJson(json);

Map<String, dynamic> img(String id) => {
  'image': {'id': id, 'src': 'https://x.com/a.png', 'alt': 'a'},
};

void main() {
  const normalizer = WonkyDeltaNormalizer();
  const validator = WonkyDeltaValidator();

  group('Given documents violating the schema', () {
    final cases =
        <(String, List<Map<String, dynamic>>, List<Map<String, dynamic>>)>[
          (
            'an empty delta',
            [],
            [
              {'insert': '\n'},
            ],
          ),
          (
            'missing trailing newline',
            [
              {'insert': 'abc'},
            ],
            [
              {'insert': 'abc\n'},
            ],
          ),
          (
            'unmerged inserts',
            [
              {'insert': 'a'},
              {'insert': 'b\n'},
            ],
            [
              {'insert': 'ab\n'},
            ],
          ),
          (
            'underline and color',
            [
              {
                'insert': 'a',
                'attributes': {
                  'underline': true,
                  'color': '#f00',
                  'bold': true,
                },
              },
              {'insert': '\n'},
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
            'code with bold',
            [
              {
                'insert': 'a',
                'attributes': {'code': true, 'bold': true},
              },
              {'insert': '\n'},
            ],
            [
              {
                'insert': 'a',
                'attributes': {'code': true},
              },
              {'insert': '\n'},
            ],
          ),
          (
            'a heading also marked as list',
            [
              {'insert': 'a'},
              {
                'insert': '\n',
                'attributes': {'header': 1, 'list': 'bullet', 'indent': 1},
              },
            ],
            [
              {'insert': 'a'},
              {
                'insert': '\n',
                'attributes': {'header': 1},
              },
            ],
          ),
          (
            'an indent jump',
            [
              {'insert': 'a'},
              {
                'insert': '\n',
                'attributes': {'list': 'bullet'},
              },
              {'insert': 'b'},
              {
                'insert': '\n',
                'attributes': {'list': 'bullet', 'indent': 5},
              },
            ],
            [
              {'insert': 'a'},
              {
                'insert': '\n',
                'attributes': {'list': 'bullet'},
              },
              {'insert': 'b'},
              {
                'insert': '\n',
                'attributes': {'list': 'bullet', 'indent': 1},
              },
            ],
          ),
          (
            'a tab in a paragraph and control characters',
            [
              {'insert': 'a\tb\u0000c\r\n'},
            ],
            [
              {'insert': 'a    bc\n'},
            ],
          ),
          (
            'a soft break in a code block',
            [
              {'insert': 'x\u2028y'},
              {
                'insert': '\n',
                'attributes': {'code-block': 'dart'},
              },
            ],
            [
              {'insert': 'x'},
              {
                'insert': '\n',
                'attributes': {'code-block': 'dart'},
              },
              {'insert': 'y'},
              {
                'insert': '\n',
                'attributes': {'code-block': 'dart'},
              },
            ],
          ),
          (
            'a code language with spaces',
            [
              {'insert': 'x'},
              {
                'insert': '\n',
                'attributes': {'code-block': 'objective c`'},
              },
            ],
            [
              {'insert': 'x'},
              {
                'insert': '\n',
                'attributes': {'code-block': 'objectivec'},
              },
            ],
          ),
          (
            'a javascript link',
            [
              {
                'insert': 'a',
                'attributes': {'link': 'javascript:alert(1)'},
              },
              {'insert': '\n'},
            ],
            [
              {'insert': 'a\n'},
            ],
          ),
          (
            'a link needing percent-encoding',
            [
              {
                'insert': 'a',
                'attributes': {'link': ' HTTPS://x.com/a b é '},
              },
              {'insert': '\n'},
            ],
            [
              {
                'insert': 'a',
                'attributes': {'link': 'https://x.com/a%20b%20%C3%A9'},
              },
              {'insert': '\n'},
            ],
          ),
          (
            'an embed inside a heading line',
            [
              {'insert': 'ab'},
              {'insert': img('i1')},
              {'insert': 'cd'},
              {
                'insert': '\n',
                'attributes': {'header': 2},
              },
            ],
            [
              {'insert': 'ab'},
              {
                'insert': '\n',
                'attributes': {'header': 2},
              },
              {'insert': img('i1')},
              {'insert': '\ncd'},
              {
                'insert': '\n',
                'attributes': {'header': 2},
              },
            ],
          ),
          (
            'an embed line with block attributes',
            [
              {'insert': img('i1')},
              {
                'insert': '\n',
                'attributes': {'list': 'bullet', 'cmt_t': true},
              },
            ],
            [
              {'insert': img('i1')},
              {
                'insert': '\n',
                'attributes': {'cmt_t': true},
              },
            ],
          ),
          (
            'a duplicate embed id',
            [
              {'insert': img('i1')},
              {'insert': '\nx\n'},
              {'insert': img('i1')},
              {'insert': '\n'},
            ],
            [
              {'insert': img('i1')},
              {'insert': '\nx\n'},
            ],
          ),
          (
            'an unknown embed',
            [
              {'insert': 'a\n'},
              {
                'insert': {
                  'video': {'id': 'v'},
                },
              },
              {'insert': '\nb\n'},
            ],
            [
              {'insert': 'a\nb\n'},
            ],
          ),
          (
            'a ragged table',
            [
              {
                'insert': {
                  'table': {
                    'id': 't',
                    'rows': [
                      ['a', 'b'],
                      [' c\nd '],
                    ],
                  },
                },
              },
              {'insert': '\n'},
            ],
            [
              {
                'insert': {
                  'table': {
                    'id': 't',
                    'align': [null, null],
                    'rows': [
                      ['a', 'b'],
                      ['c d', ''],
                    ],
                  },
                },
              },
              {'insert': '\n'},
            ],
          ),
          (
            'a mention without link',
            [
              {
                'insert': '@a',
                'attributes': {'mention': 'u1'},
              },
              {'insert': '\n'},
            ],
            [
              {'insert': '@a\n'},
            ],
          ),
        ];
    for (final (name, input, expected) in cases) {
      test('when normalizing $name then the result is canonical and valid', () {
        final result = normalizer.normalize(d(input));

        expect(result.document.toJson(), equals(expected));
        expect(validator.validate(result.document).issues, isEmpty);
      });
    }
  });

  group('Given a change re-inserting an existing embed id', () {
    final before = d([
      {'insert': img('t1')},
      {'insert': '\nmiddle\n'},
    ]);
    // Concurrent "replace" that the server transformed: inserts a new copy at
    // the end without deleting the old one.
    final change = Delta()
      ..retain(9)
      ..insert({
        'image': {'id': 't1', 'src': 'https://x.com/new.png', 'alt': 'new'},
      })
      ..insert('\n');

    test(
      'when normalizing the change then the pre-existing embed is deleted (LWW)',
      () {
        final result = normalizer.normalizeChange(before, change);

        expect(result.document.toJson(), [
          {'insert': 'middle\n'},
          {
            'insert': {
              'image': {
                'id': 't1',
                'src': 'https://x.com/new.png',
                'alt': 'new',
              },
            },
          },
          {'insert': '\n'},
        ]);
        expect(WonkyOt.apply(before, result.change), equals(result.document));
      },
    );
  });

  group('Given suggestion timestamps', () {
    test('when a change introduces a suggestion then its time is stamped', () {
      final before = d([
        {'insert': 'ab\n'},
      ]);
      final change = Delta()
        ..retain(1)
        ..insert('X', {
          'sug_s': {'t': 'ins', 'by': 'u', 'at': 1},
        });

      final result = normalizer.normalizeChange(
        before,
        change,
        suggestionTimestamp: 999,
      );

      expect(result.document.toJson()[1], {
        'insert': 'X',
        'attributes': {
          'sug_s': {'t': 'ins', 'by': 'u', 'at': 999},
        },
      });
    });
  });

  group('Given orphan comment cleanup', () {
    test('when a thread is unknown then its anchor is removed', () {
      final n = WonkyDeltaNormalizer(
        isKnownCommentThread: (id) => id == 'keep',
      );

      final result = n.normalize(
        d([
          {
            'insert': 'a',
            'attributes': {'cmt_keep': true, 'cmt_gone': true},
          },
          {'insert': '\n'},
        ]),
      );

      expect(result.document.toJson().first, {
        'insert': 'a',
        'attributes': {'cmt_keep': true},
      });
    });
  });

  group('Given random raw documents', () {
    propertyTest(
      'when normalizing then the result validates and the fixup composes',
      (random, _) {
        final gen = DeltaGen(
          random,
          options: const DeltaGenOptions(overlays: true),
        );
        final raw = gen.rawDocument();

        final result = normalizer.normalize(raw);

        expect(validator.validate(result.document).issues, isEmpty);
        expect(
          DeltaUtils.canonical(raw.compose(result.fixup)),
          equals(result.document),
        );
      },
    );

    propertyTest(
      'when normalizing twice then the second pass changes nothing',
      (random, _) {
        final gen = DeltaGen(
          random,
          options: const DeltaGenOptions(overlays: true),
        );
        final once = normalizer.normalize(gen.rawDocument()).document;

        final twice = normalizer.normalize(once);

        expect(twice.document, equals(once));
        expect(twice.fixup.isEmpty, isTrue);
      },
    );

    propertyTest(
      'when applying random edits then normalizeChange yields valid documents',
      (random, _) {
        final gen = DeltaGen(random);
        final edits = EditGen(random, deltaGen: gen);
        final doc = gen.document();
        final change = edits.change(doc);

        final result = normalizer.normalizeChange(doc, change);

        expect(validator.validate(result.document).issues, isEmpty);
        expect(WonkyOt.apply(doc, result.change), equals(result.document));
      },
    );
  });
}
