import 'package:test/test.dart';
import 'package:wonky_write_core/spellcheck.dart';

List<String> _words(
  String text, {
  SpellTokenizer tokenizer = const SpellTokenizer(),
  List<(int, int)> skipRanges = const [],
}) => [
  for (final t in tokenizer.tokenize(text, skipRanges: skipRanges)) t.word,
];

void main() {
  group('Given the default tokenizer', () {
    final cases = <(String, List<String>)>[
      ('Hello, world!', ['Hello', 'world']),
      ("don't stop", ["don't", 'stop']),
      ('don’t stop', ['don’t', 'stop']),
      ("'tis the dogs' bones", ['tis', 'the', 'dogs', 'bones']),
      ('well-known -dash- end', ['well-known', 'dash', 'end']),
      ('one--two', ['one', 'two']),
      ('I am a cat', ['am', 'cat']),
      ('NASA rocks', ['rocks']),
      ('USA-based team', ['USA-based', 'team']),
      ('iPhone and JavaScript or McDonald', ['and', 'or']),
      ("O'Brien wrote", ["O'Brien", 'wrote']),
      ('abc123 3rd 2024 snake_case ok', ['ok']),
      ('see https://example.com/a?b=1 and www.foo.org now', ['see', 'and', 'now']),
      ('mail viktor@serverpod.dev or mailto:x@y.z today', ['mail', 'or', 'today']),
      ('naïve café Ελληνικά русский', ['naïve', 'café', 'Ελληνικά', 'русский']),
      ('café au lait', ['café', 'au', 'lait']),
      ('hello 👋 world', ['hello', 'world']),
      ('e.g. this', ['this']),
      ('', <String>[]),
    ];
    for (final (text, expected) in cases) {
      test('when tokenizing "$text" then the words are $expected', () {
        expect(_words(text), expected);
      });
    }
  });

  group('Given skipAllCaps is false', () {
    test('when tokenizing an acronym then it is a word', () {
      expect(
        _words('NASA rocks', tokenizer: const SpellTokenizer(skipAllCaps: false)),
        ['NASA', 'rocks'],
      );
    });
  });

  group('Given dictionary WORDCHARS with punctuation', () {
    test('when tokenizing then the punctuation joins inner word parts', () {
      expect(
        _words('e.g. and/or x', tokenizer: const SpellTokenizer(wordChars: './')),
        ['e.g', 'and/or'],
      );
    });
  });

  group('Given skip ranges from the caller', () {
    test('when a word is inside a range then it is skipped', () {
      const text = 'use printf here';
      expect(_words(text, skipRanges: [(4, 10)]), ['use', 'here']);
    });

    test('when a range only overlaps a word partially then it is skipped', () {
      expect(_words('alpha beta', skipRanges: [(3, 4)]), ['beta']);
    });
  });

  group('Given text with non-ASCII characters', () {
    test('when tokenizing then offsets are UTF-16 offsets into the text', () {
      const text = '👋 héllo, wörld.';
      final tokens = const SpellTokenizer().tokenize(text);
      expect(tokens, [
        const SpellToken(3, 8, 'héllo'),
        const SpellToken(10, 15, 'wörld', followedByPeriod: true),
      ]);
    });
  });

  group('Given a token', () {
    test('when printing it then it shows offsets and word', () {
      expect(const SpellToken(1, 3, 'ab').toString(), 'SpellToken(1, 3, "ab")');
    });
  });
}
