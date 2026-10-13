import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syntax_highlight/src/span_parser.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// One realistic sample per bundled grammar. Every grammar must load, every
/// sample must be highlighted without throwing, the output text must equal the
/// input, and something in it must get a scope color (SH-2).
const samples = <String, String>{
  'css': '''
/* comment */
body > .card:hover, #main {
  color: #ff0000;
  margin: 0 auto !important;
}
@media (max-width: 600px) { .a { display: none; } }
''',
  'dart': '''
import 'dart:math';

/// Doc comment.
class Point {
  final double x, y;
  const Point(this.x, this.y);
  double get length => sqrt(x * x + y * y);
}

void main() async {
  final p = Point(3, 4);
  print('length: \${p.length} \$p');
  await Future.delayed(const Duration(seconds: 1));
}
''',
  'go': '''
package main

import "fmt"

// Point is a point.
type Point struct{ X, Y int }

func main() {
	p := Point{1, 2}
	for i := 0; i < 3; i++ {
		fmt.Printf("%d %v\\n", i, p)
	}
}
''',
  'html': '''
<!DOCTYPE html>
<html lang="en">
<head><title>Hi</title><style>p { color: red; }</style></head>
<body>
  <!-- comment -->
  <p class="x" id='y'>Hello &amp; welcome</p>
  <script>const a = 1 + 2; console.log(a);</script>
</body>
</html>
''',
  'java': '''
package com.example;

import java.util.List;

/** Doc. */
public class Main {
  @Override
  public String toString() { return "Main"; }

  public static void main(String[] args) {
    List<Integer> xs = List.of(1, 2, 3);
    for (int x : xs) { System.out.println(x * 2); }
  }
}
''',
  'javascript': '''
// comment
import { a } from './a.js';
const re = /ab+c/gi;
class Foo extends Bar {
  constructor(x) { super(); this.x = x ?? 0; }
  async *gen() { yield await fetch(`/api/\${this.x}`); }
}
export default (y) => y.map((z) => z * 2);
''',
  'json': '''
{
  "name": "wonky",
  "version": 1.5,
  "tags": ["a", "b"],
  "nested": { "ok": true, "none": null }
}
''',
  'kotlin': '''
package demo

data class User(val name: String, val age: Int)

fun main() {
    val users = listOf(User("a", 1), User("b", 2))
    // comment
    users.filter { it.age > 1 }.forEach { println("\${it.name} is \$it") }
}
''',
  'python': '''
import os
from typing import List

@decorator
class Foo(Base):
    """Docstring."""
    def bar(self, xs: List[int]) -> int:
        # comment
        return sum(x * 2 for x in xs if x > 0)

print(f"hello {os.name!r}")
''',
  'rust': '''
use std::collections::HashMap;

/// Doc.
#[derive(Debug)]
struct Point<'a> { name: &'a str, x: i32 }

fn main() {
    let mut m: HashMap<String, i32> = HashMap::new();
    m.insert("a".to_string(), 1);
    println!("{:?}", m);
}
''',
  'serverpod_protocol': '''
class: Company
table: company
fields:
  name: String
  foundedDate: DateTime?
  employees: List<Employee>?, relation
indexes:
  company_name_idx:
    fields: name
    unique: true
''',
  'sql': '''
-- comment
SELECT u.id, COUNT(*) AS n
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2020-01-01' AND u.active = TRUE
GROUP BY u.id
ORDER BY n DESC
LIMIT 10;
''',
  'swift': '''
import Foundation

/// Doc.
struct Point: Codable {
    var x: Double
    var y: Double
}

func greet(_ name: String) -> String {
    let p = Point(x: 1, y: 2)
    return "Hello, \\(name) \\(p.x)"
}
''',
  'typescript': '''
interface User { id: number; name?: string }
type Id = User['id'];
enum Color { Red, Green }
export async function load<T extends User>(id: Id): Promise<T | null> {
  const res = await fetch(`/u/\${id}`) as Response;
  return (await res.json()) as T;
}
''',
  'yaml': '''
# comment
name: wonky
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
list:
  - "a"
  - 1
  - true
''',
};

/// Tokens the patched grammars must scope (SH-2 case-insensitive regexes,
/// SH-3 rewritten grammars, SH-5 grammar fixes): `token` must be covered by a
/// span whose innermost scope starts with `scope`.
const expectedScopes = <String, List<(String, String)>>{
  'json': [
    ('1.5', 'constant.numeric'),
    ('true', 'constant.language'),
  ],
  'css': [
    ('@media', 'keyword'),
    ('(max-width: 600px)', 'support.type.media-query'),
  ],
  'go': [
    ('package', 'keyword'),
    ('import', 'keyword'),
    ('"fmt"', 'string'),
  ],
  'sql': [
    ('SELECT', 'keyword'),
    ('LEFT JOIN', 'keyword'),
    ('COUNT', 'support')
  ],
  'swift': [
    ('func', 'storage'),
    ('greet', 'entity.name.function'),
    ('"Hello, ', 'string'),
    ('return', 'keyword.control')
  ],
  'typescript': [
    ('interface', 'storage'),
    ('Promise', 'support.class'),
    ('async', 'storage'),
    ('`/u/', 'string.template'),
    ('number', 'support.type')
  ],
  'javascript': [
    ('/ab+c/gi', 'string.regexp'),
    ('Foo', 'entity.name.type'),
    ('yield', 'keyword.control')
  ],
  'python': [
    ('import', 'keyword'),
    ('@decorator', 'storage.type.annotation'),
    ('bar', 'entity.name.function'),
    ('sum', 'support.function'),
    ('f"hello ', 'string.interpolated')
  ],
  'rust': [
    ("'a", 'storage.modifier.lifetime'),
    ('println!', 'entity.name.function'),
    ('HashMap', 'support.class'),
    ('"a"', 'string')
  ],
};

void main() {
  final grammars = Directory('grammars')
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
      .toList()
    ..sort();

  test('every bundled grammar has a sample', () {
    expect(samples.keys.toList()..sort(), grammars);
  });

  final theme = HighlighterTheme.fromConfiguration(
    [
      File('themes/light_vs.json').readAsStringSync(),
    ].single,
    const TextStyle(color: Color(0xFF000088)),
  );

  group('SH-4 parseScopes', () {
    test('when the grammar is not loaded then isInitialized is false', () {
      expect(Highlighter.isInitialized('no-such-language'), isFalse);
    });

    test('when parsing dart then spans are sorted, disjoint and scoped', () {
      Highlighter.addLanguage(
        'dart',
        File('grammars/dart.json').readAsStringSync(),
      );
      expect(Highlighter.isInitialized('dart'), isTrue);

      const code = 'final x = "a"; // c';
      final spans = Highlighter.parseScopes('dart', code);

      var end = 0;
      for (final span in spans) {
        expect(span.start, greaterThanOrEqualTo(end));
        end = span.end;
      }
      final string = spans.firstWhere((s) => s.start == code.indexOf('"'));
      expect(string.scopes.last, startsWith('string'));
    });
  });

  for (final language in grammars) {
    test('$language highlights its sample', () {
      Highlighter.addLanguage(
        language,
        File('grammars/$language.json').readAsStringSync(),
      );
      final code = samples[language]!;
      final span = Highlighter(language: language, theme: theme).highlight(
        code,
      );
      expect(span.toPlainText(), code);
      final colors = <Color>{};
      span.visitChildren((s) {
        final color = (s as TextSpan).style?.color;
        if (color != null) colors.add(color);
        return true;
      });
      expect(colors.length, greaterThan(2), reason: 'too few colors');
    });

    test('$language survives every prefix of its sample', () {
      Highlighter.addLanguage(
        language,
        File('grammars/$language.json').readAsStringSync(),
      );
      final highlighter = Highlighter(language: language, theme: theme);
      final code = samples[language]!;
      for (var i = 0; i <= code.length; i++) {
        final prefix = code.substring(0, i);
        expect(highlighter.highlight(prefix).toPlainText(), prefix);
      }
    });

    final expected = expectedScopes[language];
    if (expected != null) {
      test('$language scopes its key tokens', () {
        final grammar = Grammar.fromJson(
          jsonDecode(File('grammars/$language.json').readAsStringSync()),
        );
        final code = samples[language]!;
        final spans = SpanParser.parse(grammar, code);
        for (final (token, scope) in expected) {
          final start = code.indexOf(token);
          expect(start, isNot(-1), reason: token);
          final span = spans.where(
            (s) => s.start <= start && s.end >= start + token.length,
          );
          expect(
            span.map((s) => s.scopes.last),
            contains(startsWith(scope)),
            reason: '"$token" should be $scope',
          );
        }
      });
    }
  }
}
