import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

/// `(language, code, token text, expected token)`: one case per language with
/// a TextMate grammar (moved from Write's code highlighter test, 04 §15.4).
const _cases = <(String, String, String, SyntaxToken)>[
  ('css', 'body { color: #fff; }', 'color', SyntaxToken.attribute),
  ('dart', 'final x = "a"; // note', '// note', SyntaxToken.comment),
  ('go', 'func main() { return }', 'func', SyntaxToken.keyword),
  ('html', '<p class="x">Hi</p>', 'p', SyntaxToken.tag),
  ('java', 'public class A { int x = 42; }', '42', SyntaxToken.number),
  (
    'javascript',
    'const s = `a`; let r = /ab+/g;',
    '/ab+/g',
    SyntaxToken.regexp,
  ),
  ('json', '{"key": true}', 'true', SyntaxToken.literal),
  ('kotlin', 'fun main() { val x = "s" }', '"s"', SyntaxToken.string),
  ('python', 'def f(x):\n    return None', 'def', SyntaxToken.keyword),
  ('rust', 'fn main() { let x = 1; }', 'fn', SyntaxToken.keyword),
  (
    'serverpod',
    'class: Post\nfields:\n  title: String',
    'class',
    SyntaxToken.tag,
  ),
  ('sql', 'select * from users where id = 1', 'select', SyntaxToken.keyword),
  ('swift', 'let name: String = "x"', '"x"', SyntaxToken.string),
  ('typescript', 'const n: number = 1; // c', '// c', SyntaxToken.comment),
  ('yaml', 'name: wonky\nversion: 1', 'name', SyntaxToken.tag),
];

void main() {
  const tokenizer = TextMateTokenizer.instance;

  test('every language with a grammar has a case', () {
    expect(
      _cases.map((c) => c.$1).toSet(),
      CodeLanguages.grammars.keys.toSet(),
    );
  });

  for (final (language, code, text, expected) in _cases) {
    test('when tokenizing $language then "$text" is ${expected.name}', () {
      final tokens = tokenizer.tokenize(code, language);

      final start = code.indexOf(text);
      expect(
        tokens.where((t) => t.start <= start && t.end >= start + text.length),
        contains(isA<CodeToken>().having((t) => t.token, 'token', expected)),
      );
    });
  }

  group('Given a language without a grammar', () {
    for (final language in ['bash', 'cobol', '']) {
      test('when tokenizing "$language" then there are no tokens', () {
        expect(tokenizer.supports(language), isFalse);
        expect(tokenizer.tokenize('echo "hi"', language), isEmpty);
      });
    }
  });

  test('when the code is empty then there are no tokens', () {
    expect(tokenizer.tokenize('', 'dart'), isEmpty);
  });
}
