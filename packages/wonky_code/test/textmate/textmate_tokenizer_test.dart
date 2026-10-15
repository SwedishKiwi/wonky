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

  // SH-7: the name's text also occurs in the keyword before it; it was
  // scoped at that first occurrence (overlapping tokens, `functionfunction`
  // in HTML exports).
  group('Given a name whose text also occurs earlier in its match', () {
    for (final (language, code, keyword, name, expected) in _captureCases) {
      test('when tokenizing $language "$code" then "$keyword" is a keyword '
          'and "$name" is ${expected.name}', () {
        final tokens = tokenizer.tokenize(code, language);

        final at = code.lastIndexOf(name);
        expect(tokens, contains(CodeToken(at, at + name.length, expected)));
        expect(
          tokens,
          contains(
            CodeToken(
              code.indexOf(keyword),
              code.indexOf(keyword) + keyword.length,
              SyntaxToken.keyword,
            ),
          ),
        );
      });
    }
  });

  test('when the code is empty then there are no tokens', () {
    expect(tokenizer.tokenize('', 'dart'), isEmpty);
  });
}

/// `(language, code, keyword, name, expected)` for SH-7.
const _captureCases = <(String, String, String, String, SyntaxToken)>[
  ('javascript', 'function f() {}', 'function', 'f', SyntaxToken.function),
  (
    'typescript',
    'function f(): void {}',
    'function',
    'f',
    SyntaxToken.function,
  ),
  ('python', 'def f(): pass', 'def', 'f', SyntaxToken.function),
  ('python', 'def e(): pass', 'def', 'e', SyntaxToken.function),
  ('swift', 'func f() {}', 'func', 'f', SyntaxToken.function),
  ('rust', 'fn f() {}', 'fn', 'f', SyntaxToken.function),
];
