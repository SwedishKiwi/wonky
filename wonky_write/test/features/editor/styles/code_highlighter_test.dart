import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/editor/model/code_languages.dart';
import 'package:wonky_write/features/editor/styles/code_highlighter.dart';
import 'package:wonky_write/features/editor/styles/style_phases.dart';

/// `(language, code, token text, expected class)`: one sample per supported
/// language (Write 04 §15.4).
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every highlighted language has a case', () {
    expect(
      _cases.map((c) => c.$1).toSet(),
      CodeLanguages.grammars.keys.toSet(),
    );
  });

  group('Given a language without a grammar', () {
    for (final language in ['bash', 'cobol', '']) {
      test('when tokenizing "$language" then there are no tokens', () {
        expect(
          CodeHighlightStylePhase.tokenize('echo "hi"', language),
          isEmpty,
        );
      });
    }
  });

  group('Given TextMate scopes', () {
    test('when punctuation is inside a string then it is a string', () {
      expect(
        CodeHighlighter.tokenForScopes([
          'source.js',
          'string.quoted.double.js',
          'punctuation.definition.string.begin.js',
        ]),
        'string',
      );
    });

    test(
      'when plain code is embedded in a template string then it is plain',
      () {
        expect(
          CodeHighlighter.tokenForScopes([
            'source.ts',
            'string.template.ts',
            'meta.template.expression.ts',
          ]),
          isNull,
        );
      },
    );

    test('when only a separator is scoped then it is punctuation', () {
      expect(
        CodeHighlighter.tokenForScopes([
          'source.go',
          'punctuation.separator.go',
        ]),
        'punctuation',
      );
    });
  });

  group('Given the grammar of a supported language is loaded', () {
    for (final (language, code, token, expected) in _cases) {
      test('when tokenizing $language then "$token" is $expected', () async {
        final grammar = CodeLanguages.grammarFor(language)!;
        expect(await CodeHighlighter.load(grammar), isTrue);

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
  });
}
