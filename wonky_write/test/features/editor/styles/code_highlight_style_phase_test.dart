import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/editor/model/code_languages.dart';
import 'package:wonky_write/features/editor/styles/style_phases.dart';

/// `(language, code, token text, expected class)`: one sample per supported
/// language (Write 04 §15.4). The tokenizer itself is tested in `wonky_code`
/// (`test/textmate/`); these check the editor's class keys.
const _cases = <(String, String, String, String)>[
  ('css', 'body { color: #fff; }', 'color', 'attribute'),
  ('dart', 'final x = "a"; // note', '// note', 'comment'),
  ('go', 'func main() { return }', 'func', 'keyword'),
  ('html', '<p class="x">Hi</p>', 'p', 'tag'),
  ('java', 'public class A { int x = 42; }', '42', 'number'),
  ('javascript', 'const s = `a`; let r = /ab+/g;', '/ab+/g', 'regexp'),
  ('json', '{"key": true}', 'true', 'literal'),
  ('kotlin', 'fun main() { val x = "s" }', '"s"', 'string'),
  ('python', 'def f(x):\n    return None', 'def', 'keyword'),
  ('rust', 'fn main() { let x = 1; }', 'fn', 'keyword'),
  ('serverpod', 'class: Post\nfields:\n  title: String', 'class', 'tag'),
  ('sql', 'select * from users where id = 1', 'select', 'keyword'),
  ('swift', 'let name: String = "x"', '"x"', 'string'),
  ('typescript', 'const n: number = 1; // c', '// c', 'comment'),
  ('yaml', 'name: wonky\nversion: 1', 'name', 'tag'),
];

void main() {
  test('every highlighted language has a case', () {
    expect(
      _cases.map((c) => c.$1).toSet(),
      CodeLanguages.grammars.keys.toSet(),
    );
  });

  group('Given a language without a TextMate grammar', () {
    for (final language in ['bash', 'cobol', '']) {
      test('when tokenizing "$language" then there are no tokens', () {
        expect(
          CodeHighlightStylePhase.tokenize('echo "hi"', language),
          isEmpty,
        );
      });
    }
  });

  group('Given a supported language', () {
    for (final (language, code, token, expected) in _cases) {
      test('when tokenizing $language then "$token" is $expected', () {
        final spans = CodeHighlightStylePhase.tokenize(code, language);

        final start = code.indexOf(token);
        expect(
          spans.where((s) => s.$1 <= start && s.$2 >= start + token.length),
          contains(
            isA<(int, int, String)>().having((s) => s.$3, 'class', expected),
          ),
        );
      });
    }

    test('when a built-in function is tokenized then its class is '
        'built_in', () {
      const code = 'total = sum(xs)';

      final spans = CodeHighlightStylePhase.tokenize(code, 'python');

      final start = code.indexOf('sum');
      expect(
        spans.where((s) => s.$1 <= start && s.$2 >= start + 3),
        contains(
          isA<(int, int, String)>().having((s) => s.$3, 'class', 'built_in'),
        ),
      );
    });
  });
}
