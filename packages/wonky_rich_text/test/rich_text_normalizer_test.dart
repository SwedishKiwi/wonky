import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart';

import 'support/property.dart';

/// A small Slides-like schema (Slides 02 §4.1 subset).
final _schema = RichTextSchema(
  inline: {
    'bold': RichTextSchema.trueOnly,
    'italic': RichTextSchema.trueOnly,
    'size': RichTextSchema.numIn(6, 800),
    'weight': RichTextSchema.intIn(100, 900),
    'link': (v) => v is String ? LinkPolicy.normalizeLink(v) : null,
  },
  block: {
    'align': RichTextSchema.oneOf({'left', 'center', 'right', 'justify'}),
    'indent': RichTextSchema.intIn(0, 8),
  },
);

const _normalizer = RichTextNormalizer(RichTextSchema());

List<Map<String, Object?>> _ops(Delta d) => [
  for (final o in d.toJson()) Map<String, Object?>.from(o as Map),
];

void main() {
  final normalizer = RichTextNormalizer(_schema);

  group('Given RichTextNormalizer.sanitizeText', () {
    test('when the text is clean then it is returned unchanged', () {
      const text = 'Hello, wörld 👋 next';
      expect(identical(RichTextNormalizer.sanitizeText(text), text), isTrue);
    });

    test('when the text has CR, tabs, U+2029 and control characters then '
        'they are replaced or removed', () {
      expect(
        RichTextNormalizer.sanitizeText('a\r\nb\rc\td e\u0007f￾g'),
        'a\nb\nc    d efg',
      );
    });

    test('when tabs are kept then they survive', () {
      expect(
        RichTextNormalizer.sanitizeText('a\tb', tabReplacement: null),
        'a\tb',
      );
    });

    test('when there are lone surrogates then they are removed and pairs '
        'kept', () {
      expect(RichTextNormalizer.sanitizeText('a\uD800b😀c\uDC00'), 'ab😀c');
    });
  });

  group('Given RichTextNormalizer.normalize', () {
    test('when the body is empty then it becomes a single newline', () {
      final r = normalizer.normalize(Delta());
      expect(_ops(r.document), [
        {'insert': '\n'},
      ]);
      expect(r.changed, isTrue);
    });

    test('when the body is canonical then nothing changes', () {
      final body = Delta()
        ..insert('Hi ', {'bold': true})
        ..insert('there')
        ..insert('\n', {'align': 'center'});
      final r = normalizer.normalize(body);
      expect(r.document, body);
      expect(r.changed, isFalse);
      expect(normalizer.isNormalized(body), isTrue);
    });

    test('when adjacent inserts have equal attributes then they merge '
        'without counting as a change', () {
      // Delta.insert would merge them already; build the ops directly.
      final body = Delta.fromOperations([
        Operation.insert('a', {'bold': true}),
        Operation.insert('b', {'bold': true}),
        Operation.insert('\n'),
      ]);
      final r = normalizer.normalize(body);
      expect(_ops(r.document), [
        {
          'insert': 'ab',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);
      expect(r.changed, isFalse);
      expect(normalizer.isNormalized(body), isFalse);
    });

    test('when the trailing newline is missing then it is appended', () {
      final r = normalizer.normalize(Delta()..insert('x'));
      expect(_ops(r.document), [
        {'insert': 'x\n'},
      ]);
      expect(r.changed, isTrue);
    });

    test('when ops are not text inserts then they are dropped', () {
      final body = Delta()
        ..insert('a')
        ..insert({'image': 'x'})
        ..retain(2)
        ..insert('b\n');
      final r = normalizer.normalize(body);
      expect(_ops(r.document), [
        {'insert': 'ab\n'},
      ]);
      expect(r.changed, isTrue);
    });

    test('when attributes are unknown, invalid or on the wrong part then '
        'they are dropped or sanitized', () {
      final body = Delta()
        ..insert('a', {
          'bold': true,
          'color': '#f00',
          'align': 'center',
          'size': 2000,
          'weight': 450.4,
        })
        ..insert('\n', {'align': 'middle', 'indent': 12, 'italic': true});
      final r = normalizer.normalize(body);
      expect(_ops(r.document), [
        {
          'insert': 'a',
          'attributes': {'bold': true, 'size': 800, 'weight': 450},
        },
        {
          'insert': '\n',
          'attributes': {'indent': 8},
        },
      ]);
      expect(r.changed, isTrue);
    });

    test('when a multi-line insert carries attributes then text keeps the '
        'inline ones and each newline the block ones', () {
      final body = Delta()
        ..insert('one\ntwo\n', {'bold': true, 'align': 'right'});
      final r = normalizer.normalize(body);
      expect(_ops(r.document), [
        {
          'insert': 'one',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'right'},
        },
        {
          'insert': 'two',
          'attributes': {'bold': true},
        },
        {
          'insert': '\n',
          'attributes': {'align': 'right'},
        },
      ]);
    });

    test('when links are given then they are canonicalized or dropped', () {
      final body = Delta()
        ..insert('ok', {'link': 'https://example.com/a b'})
        ..insert('bad', {'link': 'javascript:alert(1)'})
        ..insert('\n');
      final r = normalizer.normalize(body);
      expect(_ops(r.document), [
        {
          'insert': 'ok',
          'attributes': {'link': 'https://example.com/a%20b'},
        },
        {'insert': 'bad\n'},
      ]);
    });

    test('when the schema is empty then all attributes are dropped', () {
      final body = Delta()
        ..insert('a', {'bold': true})
        ..insert('\n', {'align': 'left'});
      expect(_ops(_normalizer.normalize(body).document), [
        {'insert': 'a\n'},
      ]);
    });

    propertyTest('when normalizing random bodies then the result is '
        'canonical, valid and normalize is idempotent', (random, run) {
      final body = _randomBody(random);
      final once = normalizer.normalize(body).document;
      final twice = normalizer.normalize(once);

      expect(twice.document, once);
      expect(twice.changed, isFalse);
      expect(DeltaUtils.canonical(once), once);
      expect(DeltaUtils.isDocument(once), isTrue);
      expect(DeltaUtils.text(once), endsWith('\n'));
      for (final op in once.operations) {
        final text = op.data as String;
        expect(TextRules.firstLoneSurrogate(text), -1);
        for (final u in text.codeUnits) {
          expect(u == 0x09 || TextRules.isForbiddenUnit(u), isFalse);
        }
        final keys = op.attributes?.keys ?? const <String>[];
        // Consecutive newlines with equal block attributes merge.
        final allowed = text.replaceAll('\n', '').isEmpty
            ? _schema.block
            : _schema.inline;
        expect(keys.every(allowed.containsKey), isTrue);
      }
    });
  });
}

const _alphabet = [
  'a', 'b', ' ', '\n', '\t', '\r', ' ', ' ', '\u0000', '\uD800', //
  '\uDC00', '😀', 'é', '￼',
];

const _attrSets = <Map<String, Object?>?>[
  null,
  {'bold': true},
  {'bold': false},
  {'italic': true, 'size': 12},
  {'align': 'center'},
  {'indent': 3, 'bold': true},
  {'color': 'red'},
  {'weight': 1000},
  {'link': 'mailto:a@b.c'},
];

Delta _randomBody(Random random) {
  final d = Delta();
  final n = random.nextInt(8);
  for (var i = 0; i < n; i++) {
    if (random.nextInt(10) == 0) {
      d.insert({'image': 'x'});
      continue;
    }
    final len = 1 + random.nextInt(6);
    final text = [
      for (var k = 0; k < len; k++) _alphabet[random.nextInt(_alphabet.length)],
    ].join();
    final attrs = _attrSets[random.nextInt(_attrSets.length)];
    d.insert(text, attrs == null ? null : Map<String, dynamic>.from(attrs));
  }
  return d;
}
