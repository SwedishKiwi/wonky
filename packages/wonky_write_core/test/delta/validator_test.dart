import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

Delta d(List<Map<String, dynamic>> json) => Delta.fromJson(json);

const img = {
  'image': {'id': 'i1', 'src': 'https://x.com/a.png', 'alt': 'a'},
};

void main() {
  const validator = WonkyDeltaValidator();

  group('Given valid documents', () {
    final cases = <(String, List<Map<String, dynamic>>)>[
      (
        'a single empty line',
        [
          {'insert': '\n'},
        ],
      ),
      (
        'formatted text and a heading',
        [
          {'insert': 'Hi '},
          {
            'insert': 'there',
            'attributes': {'bold': true, 'italic': true},
          },
          {
            'insert': '\n',
            'attributes': {'header': 2},
          },
        ],
      ),
      (
        'a nested list',
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'b'},
          {
            'insert': '\n',
            'attributes': {'list': 'ordered', 'indent': 1},
          },
          {'insert': 'c'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked', 'indent': 2},
          },
        ],
      ),
      (
        'an image embed between lines',
        [
          {'insert': 'x\n'},
          {'insert': img},
          {'insert': '\ny\n'},
        ],
      ),
      (
        'a code block with a tab',
        [
          {'insert': '\tcode'},
          {
            'insert': '\n',
            'attributes': {'code-block': 'dart'},
          },
        ],
      ),
      (
        'a mention with mailto link and comment overlay',
        [
          {
            'insert': '@Anna',
            'attributes': {
              'mention': 'u1',
              'link': 'mailto:anna@x.com',
              'cmt_t1': true,
            },
          },
          {
            'insert': '\n',
            'attributes': {'cmt_t1': true},
          },
        ],
      ),
      (
        'a format suggestion on a line end',
        [
          {'insert': 'Title'},
          {
            'insert': '\n',
            'attributes': {
              'header': 2,
              'sug_s1': {
                't': 'fmt',
                'by': 'u1',
                'at': 5,
                'before': <String, dynamic>{},
              },
            },
          },
        ],
      ),
    ];
    for (final (name, json) in cases) {
      test('when validating $name then it is valid', () {
        final result = validator.validate(d(json));

        expect(result.issues, isEmpty);
      });
    }
  });

  group('Given invalid documents', () {
    final cases = <(String, List<Map<String, dynamic>>, ValidationCode)>[
      ('an empty delta', [], ValidationCode.missingTrailingNewline),
      (
        'no trailing newline',
        [
          {'insert': 'abc'},
        ],
        ValidationCode.missingTrailingNewline,
      ),
      (
        'a retain op',
        [
          {'retain': 1},
        ],
        ValidationCode.notDocument,
      ),
      (
        'unmerged equal inserts',
        [
          {'insert': 'a'},
          {'insert': 'b\n'},
        ],
        ValidationCode.notCanonical,
      ),
      (
        'underline',
        [
          {
            'insert': 'a',
            'attributes': {'underline': true},
          },
          {'insert': '\n'},
        ],
        ValidationCode.unknownAttribute,
      ),
      (
        'a block attribute on text',
        [
          {
            'insert': 'a',
            'attributes': {'header': 1},
          },
          {'insert': '\n'},
        ],
        ValidationCode.unknownAttribute,
      ),
      (
        'bold on a line end',
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'bold': true},
          },
        ],
        ValidationCode.unknownAttribute,
      ),
      (
        'header level 7',
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'header': 7},
          },
        ],
        ValidationCode.invalidAttributeValue,
      ),
      (
        'heading and list together',
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'header': 1, 'list': 'bullet'},
          },
        ],
        ValidationCode.conflictingBlockAttributes,
      ),
      (
        'indent without list',
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'indent': 1},
          },
        ],
        ValidationCode.invalidIndent,
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
            'attributes': {'list': 'bullet', 'indent': 2},
          },
        ],
        ValidationCode.invalidIndent,
      ),
      (
        'a first list item with indent',
        [
          {'insert': 'a'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
        ],
        ValidationCode.invalidIndent,
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
        ValidationCode.codeWithFormatting,
      ),
      (
        'a mention without mailto',
        [
          {
            'insert': 'a',
            'attributes': {'mention': 'u1', 'link': 'https://x.com'},
          },
          {'insert': '\n'},
        ],
        ValidationCode.mentionWithoutMailto,
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
        ValidationCode.invalidAttributeValue,
      ),
      (
        'a link with a space',
        [
          {
            'insert': 'a',
            'attributes': {'link': 'https://x.com/a b'},
          },
          {'insert': '\n'},
        ],
        ValidationCode.invalidAttributeValue,
      ),
      (
        'an embed after text',
        [
          {'insert': 'x'},
          {'insert': img},
          {'insert': '\n'},
        ],
        ValidationCode.embedPlacement,
      ),
      (
        'an embed followed by text',
        [
          {'insert': img},
          {'insert': 'x\n'},
        ],
        ValidationCode.embedPlacement,
      ),
      (
        'an embed line with a heading',
        [
          {'insert': img},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
        ],
        ValidationCode.embedPlacement,
      ),
      (
        'a bold embed',
        [
          {
            'insert': img,
            'attributes': {'bold': true},
          },
          {'insert': '\n'},
        ],
        ValidationCode.embedAttributes,
      ),
      (
        'an unknown embed',
        [
          {
            'insert': {
              'video': {'id': 'v'},
            },
          },
          {'insert': '\n'},
        ],
        ValidationCode.invalidEmbed,
      ),
      (
        'duplicate embed ids',
        [
          {'insert': img},
          {'insert': '\n'},
          {'insert': img},
          {'insert': '\n'},
        ],
        ValidationCode.duplicateEmbedId,
      ),
      (
        'a control character',
        [
          {'insert': 'a\u0007b\n'},
        ],
        ValidationCode.invalidCharacter,
      ),
      (
        'a lone surrogate',
        [
          {'insert': 'a\uD800b\n'},
        ],
        ValidationCode.invalidCharacter,
      ),
      (
        'a tab in a paragraph',
        [
          {'insert': 'a\tb\n'},
        ],
        ValidationCode.tabOutsideCode,
      ),
      (
        'a soft break in code',
        [
          {'insert': 'a\u2028b'},
          {
            'insert': '\n',
            'attributes': {'code-block': ''},
          },
        ],
        ValidationCode.softBreakInCode,
      ),
      (
        'an invalid suggestion value',
        [
          {
            'insert': 'a',
            'attributes': {
              'sug_x': {'t': 'zap', 'by': 'u', 'at': 1},
            },
          },
          {'insert': '\n'},
        ],
        ValidationCode.invalidAttributeValue,
      ),
      (
        'a ragged table',
        [
          {
            'insert': {
              'table': {
                'id': 't',
                'align': [null, null],
                'rows': [
                  ['a', 'b'],
                  ['c'],
                ],
              },
            },
          },
          {'insert': '\n'},
        ],
        ValidationCode.invalidEmbed,
      ),
    ];
    for (final (name, json, code) in cases) {
      test('when validating $name then it reports ${code.name}', () {
        final result = validator.validate(d(json));

        expect(result.issues.map((i) => i.code), contains(code));
      });
    }

    test('when the document is too long then it reports tooLong', () {
      const small = WonkyDeltaValidator(maxDocumentChars: 3);

      final result = small.validate(Delta()..insert('abcdef\n'));

      expect(result.issues.map((i) => i.code), [ValidationCode.tooLong]);
    });
  });
}
