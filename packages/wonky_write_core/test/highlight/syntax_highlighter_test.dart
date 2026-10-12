import 'package:test/test.dart';
import 'package:wonky_write_core/src/highlight/highlight.dart';
import 'package:wonky_write_core/src/theme/model/syntax_token.dart';

import '../support/property.dart';

/// One representative snippet per canonical language (except `plaintext`).
const _samples = <String, String>{
  'bash': 'if [ -f "\$HOME/x" ]; then echo 1; fi # done',
  'clojure': '(defn add [a b] (+ a b)) ; sum',
  'cpp': '#include <vector>\nint main() { return 0; } // c',
  'csharp': 'public class A { string s = "x"; } // c',
  'css': '.a #b p:hover { color: #fff; margin: 0 1px; }',
  'dart': 'class Foo {\n  // hi\n  final x = 42;\n}',
  'diff': '--- a\n+++ b\n@@ -1,2 +1,2 @@\n-old\n+new\n same',
  'dockerfile': 'FROM dart:stable\nRUN dart pub get\nEXPOSE 8080',
  'elixir': 'defmodule A do\n  def f(x), do: "s" # c\nend',
  'erlang': '-module(a).\nf(X) -> "s". % c',
  'go': 'package main\nfunc main() { x := "s"; println(x, 3) }',
  'gradle': "apply plugin: 'java'\ndependencies { compile 'a:b:1' }",
  'graphql': 'query Q { user(id: 1) { name } } # c',
  'groovy': "def x = 'a'\nprintln x // c",
  'haskell': 'main :: IO ()\nmain = putStrLn "hi" -- c',
  'http': 'GET /index.html HTTP/1.1\nHost: example.com',
  'ini': '[section]\nkey = "value" ; c',
  'java': 'public class A { int x = 1; } // c',
  'javascript': 'const x = `a\${b}c`; function f(a) { return /re/g; } // c',
  'json': '{"a": [1, true, null, "s"]}',
  'kotlin': 'fun main() { val s = "x" } // c',
  'less': '@c: #fff;\n.a { color: @c; }',
  'lua': 'local x = "s" -- c\nfunction f() return 1 end',
  'makefile': 'all: build\n\t@echo "done" # c',
  'markdown': '# Head\n\n`code` and [link](http://x)\n- item',
  'matlab': 'function y = f(x)\n  y = x + 1; % c\nend',
  'nginx': 'server {\n  listen 80;\n  root /var/www; # c\n}',
  'objectivec': '@interface A : NSObject\n@end\nint x = 1; // c',
  'perl': 'my \$x = "s"; # c\nsub f { return 1; }',
  'php': '<?php\nfunction f(\$a) { return "s"; } // c',
  'powershell': '\$x = "s" # c\nWrite-Host \$x',
  'protobuf': 'syntax = "proto3";\nmessage A { int32 id = 1; }',
  'python': 'def foo(a):\n    # c\n    return "x" + 1.5',
  'r': 'x <- c(1, 2) # c\nprint("s")',
  'ruby': 'def f(a)\n  "s" # c\nend',
  'rust': 'fn main() { let x: i32 = 5; println!("{}", x); } // c',
  'scala': 'object A { val s = "x" } // c',
  'scss': '\$c: #fff;\n.a { .b { color: \$c; } }',
  'console': '\$ echo "hi"\nhi',
  'sql': "SELECT a, 'x' FROM t WHERE n = 3 -- c",
  'swift': 'func f() -> Int { let s = "x"; return 1 } // c',
  'typescript': 'interface A { x: number }\nconst s: string = "x"; // c',
  'xml': '<div class="x">hi<script>var a = 1;</script></div>',
  'yaml': 'key: value\nlist:\n  - 1\n  - "s" # c',
};

/// Problems with [spans] as a list of messages (empty when valid): sorted,
/// non-overlapping, non-empty, within `[0, length]`, adjacent equal tokens
/// merged.
List<String> _spanProblems(List<SyntaxSpan> spans, int length) {
  final problems = <String>[];
  SyntaxSpan? previous;
  for (final span in spans) {
    if (span.start < 0 || span.end > length) {
      problems.add('out of bounds $span');
    }
    if (span.end <= span.start) problems.add('empty $span');
    if (previous != null) {
      if (span.start < previous.end) problems.add('overlap $previous $span');
      if (span.start == previous.end && span.token == previous.token) {
        problems.add('unmerged $previous $span');
      }
    }
    previous = span;
  }
  return problems;
}

/// The span exactly covering the first occurrence of [text] in [code].
SyntaxSpan _spanOf(String code, String text, SyntaxToken token) {
  final start = code.indexOf(text);
  return SyntaxSpan(start, start + text.length, token);
}

const _garbageAlphabet =
    'abcxyzABC_019 \t\n\r\'"`\\/<>{}()[];:,.-+*=!?#\$@%&|^~'
    'éß中😀';

String _garbage(int length, int Function(int) nextInt) {
  final runes = _garbageAlphabet.runes.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.writeCharCode(runes[nextInt(runes.length)]);
  }
  return buffer.toString();
}

void main() {
  const highlighter = SyntaxHighlighter.instance;

  group('Given code in a supported language', () {
    final cases = <(String, String, String, SyntaxToken)>[
      ('dart', 'class Foo {}', 'class', SyntaxToken.keyword),
      ('dart', 'class Foo {}', 'Foo', SyntaxToken.type),
      ('dart', 'var x = 42;', '42', SyntaxToken.number),
      ('dart', "var s = 'hi';", "'hi'", SyntaxToken.string),
      ('dart', 'x; // note', '// note', SyntaxToken.comment),
      ('dart', '@override\nvoid f() {}', '@override', SyntaxToken.meta),
      ('dart', 'int f() => 1;', 'int', SyntaxToken.builtin),
      ('python', 'def foo(a):\n    pass', 'def', SyntaxToken.keyword),
      ('python', 'def foo(a):\n    pass', 'foo', SyntaxToken.function),
      ('python', 'x = 1  # c', '# c', SyntaxToken.comment),
      ('python', 'x = 1.5', '1.5', SyntaxToken.number),
      ('javascript', 'const x = 1;', 'const', SyntaxToken.keyword),
      ('javascript', 'f(/re/g);', '/re/g', SyntaxToken.regexp),
      ('js', 'function go() {}', 'go', SyntaxToken.function),
      ('json', '{"a": true}', '"a"', SyntaxToken.attribute),
      ('json', '{"a": true}', 'true', SyntaxToken.literal),
      ('json', '{"a": "s"}', '"s"', SyntaxToken.string),
      ('sql', "SELECT 'x' FROM t", 'SELECT', SyntaxToken.keyword),
      ('sql', "SELECT 'x' FROM t", "'x'", SyntaxToken.string),
      ('sql', 'SELECT 1 -- c', '-- c', SyntaxToken.comment),
      ('bash', 'echo "\$HOME"', 'echo', SyntaxToken.builtin),
      ('bash', 'echo "\$HOME"', '\$HOME', SyntaxToken.variable),
      ('sh', 'if true; then :; fi', 'if', SyntaxToken.keyword),
      ('html', '<div class="x"></div>', 'class', SyntaxToken.attribute),
      ('html', '<div class="x"></div>', '"x"', SyntaxToken.string),
      ('html', '<!DOCTYPE html>', '<!DOCTYPE html>', SyntaxToken.meta),
      ('html', '<script>var a = 1;</script>', 'var', SyntaxToken.keyword),
      (
        'html',
        '<style>a { color: red; }</style>',
        'color',
        SyntaxToken.attribute,
      ),
      ('css', '.a { color: #fff; }', '.a', SyntaxToken.attribute),
      ('css', '.a { color: #fff; }', 'color', SyntaxToken.attribute),
      ('css', '.a { color: #fff; }', '#fff', SyntaxToken.number),
      ('css', 'p { margin: 0; }', 'p', SyntaxToken.tag),
      ('yaml', 'key: value', 'key:', SyntaxToken.attribute),
      ('yaml', 'key: value', 'value', SyntaxToken.string),
      ('yaml', 'a: 1 # c', '# c', SyntaxToken.comment),
      ('diff', '@@ -1,2 +1,2 @@\n-old\n+new', '-old', SyntaxToken.deletion),
      ('diff', '@@ -1,2 +1,2 @@\n-old\n+new', '+new', SyntaxToken.addition),
      (
        'diff',
        '@@ -1,2 +1,2 @@\n-old\n+new',
        '@@ -1,2 +1,2 @@',
        SyntaxToken.meta,
      ),
      ('rust', 'fn main() {}', 'fn', SyntaxToken.keyword),
      ('rust', 'fn main() {}', 'main', SyntaxToken.function),
      ('rust', 'let x: i32 = 5;', 'i32', SyntaxToken.builtin),
      ('go', 'func main() {}', 'func', SyntaxToken.keyword),
      ('go', 'x := "s"', '"s"', SyntaxToken.string),
      ('markdown', '# Head', '# Head', SyntaxToken.function),
      ('markdown', 'a `code` b', '`code`', SyntaxToken.string),
      ('toml', 'key = "v"', 'key', SyntaxToken.attribute),
      ('ini', '[core]\nx = 1', '[core]', SyntaxToken.function),
      (
        'http',
        'POST / HTTP/1.1\nA: b\n\n{"k": 1}',
        '"k"',
        SyntaxToken.attribute,
      ),
      ('c', 'int main() { return 0; }', 'return', SyntaxToken.keyword),
    ];
    for (final (language, code, text, token) in cases) {
      test('when tokenizing "$code" as $language '
          'then "$text" is a ${token.name} span', () {
        final spans = highlighter.tokenize(code, language);

        expect(spans, contains(_spanOf(code, text, token)));
      });
    }

    test('when a string contains an interpolation '
        'then the interpolation is not string-colored', () {
      const code = r"var s = 'a${b}c';";

      final spans = highlighter.tokenize(code, 'dart');

      expect(spans, [
        _spanOf(code, 'var', SyntaxToken.keyword),
        _spanOf(code, "'a", SyntaxToken.string),
        _spanOf(code, "c'", SyntaxToken.string),
      ]);
    });

    test('when a comment contains a doc tag '
        'then the comment is one merged span', () {
      const code = '/** @param x */';

      final spans = highlighter.tokenize(code, 'javascript');

      expect(spans, [const SyntaxSpan(0, 15, SyntaxToken.comment)]);
    });

    test('when tokenizing text outside the BMP '
        'then offsets are UTF-16 code units', () {
      const code = "// 😀\nvar s = 'x';";

      final spans = highlighter.tokenize(code, 'dart');

      expect(spans, [
        const SyntaxSpan(0, 5, SyntaxToken.comment),
        _spanOf(code, 'var', SyntaxToken.keyword),
        _spanOf(code, "'x'", SyntaxToken.string),
      ]);
    });
  });

  group('Given one sample per supported language', () {
    for (final MapEntry(key: language, value: code) in _samples.entries) {
      test('when tokenizing the $language sample '
          'then spans are non-empty, sorted and non-overlapping', () {
        final spans = highlighter.tokenize(code, language);

        expect(spans, isNotEmpty);
        expect(_spanProblems(spans, code.length), isEmpty);
      });
    }

    test('when listing the languages '
        'then every sample language and plaintext is listed', () {
      expect(
        SyntaxHighlighter.languages,
        unorderedEquals([..._samples.keys, SyntaxHighlighter.plaintext]),
      );
    });

    test('when tokenizing twice then the results are equal', () {
      final first = {
        for (final e in _samples.entries)
          e.key: highlighter.tokenize(e.value, e.key),
      };
      final second = {
        for (final e in _samples.entries)
          e.key: highlighter.tokenize(e.value, e.key),
      };

      expect(second, equals(first));
    });
  });

  group('Given code that must not be highlighted', () {
    const code = 'class Foo {}';
    final cases = <(String, String?)>[
      ('a null language', null),
      ('an empty language', ''),
      ('a blank language', '   '),
      ('an unknown language', 'brainfuck'),
      ('plaintext', 'plaintext'),
      ('the text alias', 'text'),
    ];
    for (final (description, language) in cases) {
      test('when tokenizing with $description then there are no spans', () {
        expect(highlighter.tokenize(code, language), isEmpty);
      });
    }

    test('when the code is empty then there are no spans', () {
      expect(highlighter.tokenize('', 'dart'), isEmpty);
    });

    test('when the code exceeds maxLength then there are no spans', () {
      const small = SyntaxHighlighter(maxLength: 11);

      expect(small.tokenize(code, 'dart'), isEmpty);
    });

    test('when the code is exactly maxLength then it is highlighted', () {
      const small = SyntaxHighlighter(maxLength: 12);

      expect(small.tokenize(code, 'dart'), isNotEmpty);
    });
  });

  group('Given language names and aliases', () {
    final cases = <(String?, String?)>[
      ('dart', 'dart'),
      ('Dart', 'dart'),
      ('  python  ', 'python'),
      ('py', 'python'),
      ('js', 'javascript'),
      ('JSX', 'javascript'),
      ('mjs', 'javascript'),
      ('ts', 'typescript'),
      ('tsx', 'typescript'),
      ('kt', 'kotlin'),
      ('c', 'cpp'),
      ('c++', 'cpp'),
      ('hpp', 'cpp'),
      ('cs', 'csharp'),
      ('C#', 'csharp'),
      ('golang', 'go'),
      ('rs', 'rust'),
      ('rb', 'ruby'),
      ('sh', 'bash'),
      ('zsh', 'bash'),
      ('shell', 'bash'),
      ('console', 'console'),
      ('shellsession', 'console'),
      ('yml', 'yaml'),
      ('html', 'xml'),
      ('svg', 'xml'),
      ('plist', 'xml'),
      ('md', 'markdown'),
      ('docker', 'dockerfile'),
      ('make', 'makefile'),
      ('toml', 'ini'),
      ('objective-c', 'objectivec'),
      ('objc', 'objectivec'),
      ('ps1', 'powershell'),
      ('gql', 'graphql'),
      ('proto', 'protobuf'),
      ('patch', 'diff'),
      ('txt', 'plaintext'),
      ('dart title="main.dart"', 'dart'),
      ('cobol', null),
      ('', null),
      (null, null),
    ];
    for (final (input, expected) in cases) {
      test('when resolving "$input" then the canonical id is $expected', () {
        expect(highlighter.canonicalLanguage(input), expected);
      });
    }

    test('when checking support then aliases and plaintext are supported', () {
      expect(
        [
          highlighter.supports('c++'),
          highlighter.supports('plaintext'),
          highlighter.supports('cobol'),
          highlighter.supports(null),
        ],
        [true, true, false, false],
      );
    });

    test('when resolving every alias then it maps to a listed language', () {
      expect(
        SyntaxHighlighter.languages,
        containsAll(SyntaxHighlighter.aliases.values.toSet()),
      );
    });

    test('when listing the languages then they are sorted and at least 40', () {
      final languages = SyntaxHighlighter.languages;

      expect(languages, [...languages]..sort());
      expect(languages.length, greaterThanOrEqualTo(40));
    });
  });

  group('Given spans', () {
    test(
      'when comparing equal spans then they are equal with equal hashes',
      () {
        const a = SyntaxSpan(1, 4, SyntaxToken.keyword);
        final b = SyntaxSpan(1, 4, SyntaxToken.values[0]);

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(const SyntaxSpan(1, 4, SyntaxToken.string)));
        expect(a.length, 3);
        expect(a.toString(), 'SyntaxSpan(1, 4, keyword)');
      },
    );
  });

  group('Given random input', () {
    final languages = SyntaxHighlighter.languages;
    propertyTest('when tokenizing in any language '
        'then it never throws and spans are valid', (random, run) {
      final language = languages[random.nextInt(languages.length)];
      final code = _garbage(random.nextInt(80), random.nextInt);

      final spans = highlighter.tokenize(code, language);

      expect(
        _spanProblems(spans, code.length),
        isEmpty,
        reason: '$language: ${code.codeUnits}',
      );
    }, runs: 300);
  });
}
