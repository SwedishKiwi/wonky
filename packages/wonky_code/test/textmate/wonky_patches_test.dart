// The patch tests of the vendored syntax_highlight (its
// test/wonky_patches_test.dart), moved with the TextMate engine (Slides 07
// §2.7 step 4). Patch ids: THIRD_PARTY.md.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_code/src/grammars/grammars.dart';
import 'package:wonky_code/src/textmate/span_parser.dart';
import 'package:wonky_code/wonky_code.dart';

/// One realistic sample per embedded grammar (keyed by grammar id). Every
/// grammar must parse, every sample must be tokenized without throwing, and
/// it must get several token classes (SH-2).
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
  'json': [('1.5', 'constant.numeric'), ('true', 'constant.language')],
  'css': [
    ('@media', 'keyword'),
    ('(max-width: 600px)', 'support.type.media-query'),
  ],
  'go': [('package', 'keyword'), ('import', 'keyword'), ('"fmt"', 'string')],
  'sql': [
    ('SELECT', 'keyword'),
    ('LEFT JOIN', 'keyword'),
    ('COUNT', 'support'),
  ],
  'swift': [
    ('func', 'storage'),
    ('greet', 'entity.name.function'),
    ('"Hello, ', 'string'),
    ('return', 'keyword.control'),
  ],
  'typescript': [
    ('interface', 'storage'),
    ('Promise', 'support.class'),
    ('async', 'storage'),
    ('`/u/', 'string.template'),
    ('number', 'support.type'),
  ],
  'javascript': [
    ('/ab+c/gi', 'string.regexp'),
    ('Foo', 'entity.name.type'),
    ('yield', 'keyword.control'),
  ],
  'python': [
    ('import', 'keyword'),
    ('@decorator', 'storage.type.annotation'),
    ('bar', 'entity.name.function'),
    ('sum', 'support.function'),
    ('f"hello ', 'string.interpolated'),
  ],
  'rust': [
    ("'a", 'storage.modifier.lifetime'),
    ('println!', 'entity.name.function'),
    ('HashMap', 'support.class'),
    ('"a"', 'string'),
  ],
};

/// The language id that uses grammar [grammar].
String _languageOf(String grammar) =>
    CodeLanguages.grammars.entries.firstWhere((e) => e.value == grammar).key;

void main() {
  final grammars = embeddedGrammars.keys.toList()..sort();
  const tokenizer = TextMateTokenizer.instance;

  test('every embedded grammar has a sample', () {
    expect(samples.keys.toList()..sort(), grammars);
  });

  test('every language with a grammar maps to an embedded grammar', () {
    expect(CodeLanguages.grammars.values.toSet(), grammars.toSet());
  });

  group('SH-4 scope spans', () {
    test('when parsing dart then spans are sorted, disjoint and scoped', () {
      final grammar = Grammar.fromJson(
        jsonDecode(embeddedGrammars['dart']!) as Map<String, dynamic>,
      );
      const code = 'final x = "a"; // c';

      final spans = SpanParser.parse(grammar, code);

      var end = 0;
      for (final span in spans) {
        expect(span.start, greaterThanOrEqualTo(end));
        end = span.end;
      }
      final string = spans.firstWhere((s) => s.start == code.indexOf('"'));
      expect(string.scopes.last, startsWith('string'));
    });
  });

  for (final grammar in grammars) {
    final language = _languageOf(grammar);

    test('$grammar highlights its sample', () {
      final code = samples[grammar]!;

      final tokens = tokenizer.tokenize(code, language);

      expect(_problems(tokens, code.length), isEmpty);
      expect(
        tokens.map((t) => t.token).toSet().length,
        greaterThan(2),
        reason: 'too few token classes',
      );
    });

    test('$grammar survives every prefix of its sample', () {
      final code = samples[grammar]!;
      final problems = <String>[];

      for (var i = 0; i <= code.length; i++) {
        final tokens = tokenizer.tokenize(code.substring(0, i), language);
        problems.addAll(_problems(tokens, i).map((p) => 'prefix $i: $p'));
      }

      expect(problems, isEmpty);
    });

    final expected = expectedScopes[grammar];
    if (expected != null) {
      test('$grammar scopes its key tokens', () {
        final parsed = Grammar.fromJson(
          jsonDecode(embeddedGrammars[grammar]!) as Map<String, dynamic>,
        );
        final code = samples[grammar]!;
        final spans = SpanParser.parse(parsed, code);
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

/// Violations of the tokenizer contract: sorted, disjoint, non-empty, within
/// [length], adjacent tokens of one class merged.
List<String> _problems(List<CodeToken> tokens, int length) {
  final problems = <String>[];
  CodeToken? previous;
  for (final t in tokens) {
    if (t.start < 0 || t.end > length) problems.add('$t out of bounds');
    if (t.end <= t.start) problems.add('$t is empty');
    if (previous != null) {
      if (t.start < previous.end) problems.add('$t overlaps $previous');
      if (t.start == previous.end && t.token == previous.token) {
        problems.add('$t is not merged with $previous');
      }
    }
    previous = t;
  }
  return problems;
}
