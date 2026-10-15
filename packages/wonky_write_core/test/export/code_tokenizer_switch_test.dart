// Export diff review of the M10 tokenizer switch (Slides SL-35, v2 review
// Q25): Write's exports moved from highlight.js to the shared
// `DefaultCodeTokenizer` (TextMate first). Every exporter runs over a corpus
// of code blocks with both tokenizers; after removing the token styling of
// code runs (colors, and the per-token weight/italic some themes set) the
// two exports must be identical — so only token colors changed.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';
import 'package:xml/xml.dart';

import 'export_support.dart';

/// Code blocks in every TextMate language, highlight.js languages, aliases,
/// unknown languages and plain text, with characters each format escapes
/// (`<&>`, `{}\`, quotes), tabs, non-ASCII text and a line long enough to
/// wrap in PDF.
const _corpus = r'''
# Code corpus

Intro with **bold**, *italic*, `inline code` and a [link](https://example.com).

```dart
import 'dart:math';

/// Doc comment with <html> & {braces}.
class Point {
  final double x, y;
  const Point(this.x, this.y);
  double get length => sqrt(x * x + y * y);
  @override
  String toString() => 'Point($x, $y) \\ ${x + y}';
}
```

- A list item
- Another one

```css
body { color: #fff; margin: 0 auto; } /* comment */
a:hover > span::after { content: "\201C"; }
```

```go
package main

func main() { fmt.Println("hi", 42) }
```

```html
<!doctype html>
<p class="x" data-a='1'>Hi &amp; bye</p>
<script>const a = 1 < 2;</script>
<style>p { color: red; }</style>
```

```java
public class A { private int x = 42; /* c */ }
```

```javascript
const s = `a ${b}`; let r = /ab+c/gi; // comment
export default function f(a, b = {}) { return a ?? b; }
```

```JS
const upper = 'alias in caps';
```

```json
{"key": true, "n": -1.5e3, "list": [null, "s\"q"]}
```

```kotlin
fun main() { val x = "s"; println(x) }
```

```python
def f(x: int) -> str:
	return f"{x} π → ✓"  # tab-indented
```

```rust
fn main<'a>(s: &'a str) { let x: u32 = 1; println!("{}", x); }
```

```serverpod
class: Post
table: post
fields:
  title: String
```

```sql
SELECT id, name FROM users WHERE id = 1 AND name LIKE 'a%'; -- c
```

```swift
let name: String = "x"; func f() -> Int { return 1 }
```

```typescript
interface P { x: number } const p: P = { x: 1 }; // c
```

```yaml
name: wonky
version: 1.0.0 # comment
list: [a, "b"]
```

```bash
echo "hi $USER" | grep -v '{x}' # comment
```

```c
#include <stdio.h>
int main(void) { return 0; }
```

```cpp
template <typename T> class Box { T value; };
```

```csharp
public record P(int X) { }
```

```diff
- old line
+ new line
```

```dockerfile
FROM dart:stable
RUN dart pub get
```

```ruby
def hello(name) = puts "Hello #{name}"
```

```php
<?php echo $x . "y"; ?>
```

```xml
<root a="1"><child/></root>
```

```toml
[section]
key = "value"
```

```cobol
DISPLAY 'unknown language'.
```

```
plain text without a language { } \ < >
```

```dart
final aVeryLongLineThatWrapsInPdf = someFunction(argumentNumberOne, argumentNumberTwo, argumentNumberThree, argumentNumberFour);
```

| Name | Value |
| --- | ---: |
| a | `1` |

The end.
''';

/// What an export reduces to once token styling is removed.
typedef _Normalizer = String Function(Uint8List bytes);

/// One exporter run with the theme and variant of a case.
typedef _Export = Future<ExportArtifact> Function(ExportInput input);

final _formats = <(String, _Export, _Normalizer)>[
  (
    'Markdown',
    (i) => const MarkdownFileExporter().export(
      i,
      const MarkdownFileExportOptions(),
    ),
    utf8.decode,
  ),
  (
    'TXT',
    (i) => const TxtExporter().export(i, const TxtExportOptions()),
    utf8.decode,
  ),
  (
    'HTML',
    (i) => const HtmlExporter().export(i, const HtmlExportOptions()),
    (b) => _unwrapHtmlTokens(utf8.decode(b)),
  ),
  (
    'HTML zip',
    (i) => const HtmlZipExporter().export(i, const HtmlExportOptions()),
    (b) => _zip(b, (_, text) => _unwrapHtmlTokens(text)),
  ),
  (
    'EPUB',
    (i) => const EpubExporter().export(i, const EpubExportOptions()),
    (b) => _zip(b, (_, text) => _unwrapHtmlTokens(text)),
  ),
  (
    'DOCX',
    (i) => const DocxExporter().export(i, const OfficeExportOptions()),
    (b) => _zip(b, _docxPart),
  ),
  (
    'ODT',
    (i) => const OdtExporter().export(i, const OfficeExportOptions()),
    (b) => _zip(b, _odtPart),
  ),
  (
    'RTF',
    (i) => const RtfExporter().export(i, const RtfExportOptions()),
    (b) => _rtf(latin1.decode(b)),
  ),
  (
    'PDF',
    (i) => const PdfExporter(
      compress: false,
    ).export(i, const PdfExportOptions(includeToc: true)),
    (b) => _pdfText(latin1.decode(b)),
  ),
];

/// The cases: every built-in theme in light, and a few in dark.
final _themes = [
  for (final b in BuiltinThemes.all) (b.key, ThemeVariant.light),
  ('wonky-default', ThemeVariant.dark),
  ('technical', ThemeVariant.dark),
  ('minimal-mono', ThemeVariant.dark),
];

Future<(ExportArtifact, ExportArtifact)> _beforeAfter(
  _Export export,
  ExportInput input,
) async {
  final before = await SyntaxHighlighter.withTokenizer(
    HighlightJsTokenizer.instance,
    () => export(input),
  );
  final after = await export(input);
  return (before, after);
}

void main() {
  final doc = md(_corpus);

  for (final (name, export, normalize) in _formats) {
    group('Given the $name export of the code corpus', () {
      for (final (theme, variant) in _themes) {
        test(
          'when switching from highlight.js to the shared tokenizer with '
          '$theme (${variant.name}) then only token styling differs',
          () async {
            final (before, after) = await _beforeAfter(
              export,
              input(doc, theme: theme, variant: variant),
            );

            expect(normalize(after.bytes), normalize(before.bytes));
            expect(after.pageCount, before.pageCount);
            expect(
              after.warnings.map((w) => w.code),
              before.warnings.map((w) => w.code),
            );
          },
        );
      }
    });
  }

  group('Given the code corpus', () {
    for (final (name, export, _) in _formats.where(
      (f) => !const {'Markdown', 'TXT'}.contains(f.$1),
    )) {
      test('when switching tokenizers then the raw $name export changes '
          '(the review is not vacuous)', () async {
        final (before, after) = await _beforeAfter(export, input(doc));

        expect(after.bytes, isNot(equals(before.bytes)));
      });
    }
  });

  group('Given the HTML export of a Dart block', () {
    test('when exporting then the code is tokenized by the shared '
        'DefaultCodeTokenizer', () async {
      const code = "final x = 'a'; // note";
      final a = await const HtmlExporter().export(
        input(md('```dart\n$code\n```\n')),
        const HtmlExportOptions(),
      );

      final html = utf8.decode(a.bytes);
      final spans = [
        for (final t in DefaultCodeTokenizer.instance.tokenize(code, 'dart'))
          '<span class="tok-${t.token.name}">'
              '${const HtmlEscape(HtmlEscapeMode.element).convert(code.substring(t.start, t.end))}'
              '</span>',
      ];
      expect(html, stringContainsInOrder(spans));
    });
  });

  group('Given a long code line in PDF', () {
    test('when it is highlighted then it wraps where the plain line wraps '
        '(at spaces, not between tokens)', () async {
      final doc = md(
        '```dart\nfinal aVeryLongLineThatWrapsInPdf = someFunction('
        'argumentNumberOne, argumentNumberTwo, argumentNumberThree, '
        'argumentNumberFour, argumentNumberFive);\n```\n',
      );
      Future<String> text() async => _pdfText(
        latin1.decode(
          (await const PdfExporter(
            compress: false,
          ).export(input(doc), const PdfExportOptions())).bytes,
        ),
      );

      final plain = await SyntaxHighlighter.withTokenizer(
        const _NoTokens(),
        text,
      );
      final highlighted = await text();

      expect(highlighted, plain);
      expect(highlighted, contains('argumentNumberOne, > argumentNumberTwo'));
    });
  });

  group('Given a fence language with an alias or capitals', () {
    test('when tokenizing then it is normalized like the editor stores it', () {
      expect(
        SyntaxHighlighter.instance.tokenize('const a = 1;', 'JS'),
        DefaultCodeTokenizer.instance.tokenize('const a = 1;', 'javascript'),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Normalizers: each removes exactly the token styling of code runs.

/// Every zip entry, normalized by [part] (by path), in path order.
String _zip(Uint8List bytes, String Function(String path, String text) part) {
  final files = DeterministicZip.decode(bytes);
  final b = StringBuffer();
  for (final path in files.keys.toList()..sort()) {
    final data = files[path]!;
    final text = _isText(path) ? part(path, utf8.decode(data)) : '$data';
    b.writeln('== $path\n$text');
  }
  return b.toString();
}

bool _isText(String path) =>
    RegExp(r'\.(x?html|xml|css|opf|ncx|rels|txt)$|^mimetype$').hasMatch(path);

// HTML / XHTML: `<span class="tok-…">` wrappers only appear in code blocks
// (their text is escaped, so it has no `<`).
final _htmlToken = RegExp(r'<span class="tok-[a-z]+">([^<]*)</span>');

String _unwrapHtmlTokens(String html) =>
    html.replaceAllMapped(_htmlToken, (m) => m[1]!);

// DOCX: in `CodeBlock` paragraphs, drop run colors and bold/italic, then
// merge runs with equal properties.
const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _tokenRunProps = {'color', 'b', 'bCs', 'i', 'iCs'};

String _docxPart(String path, String text) {
  if (path != 'word/document.xml') return text;
  final doc = XmlDocument.parse(text);
  for (final p in doc.findAllElements('p', namespaceUri: _w)) {
    final style = p
        .findElements('pPr', namespaceUri: _w)
        .expand((e) => e.findElements('pStyle', namespaceUri: _w))
        .firstOrNull
        ?.getAttribute('val', namespaceUri: _w);
    if (style != 'CodeBlock') continue;
    final runs = p.findElements('r', namespaceUri: _w).toList();
    final merged = <(String, StringBuffer)>[];
    for (final r in runs) {
      final props = r.getElement('w:rPr')?.copy();
      props?.children.removeWhere(
        (c) => c is XmlElement && _tokenRunProps.contains(c.localName),
      );
      final key = props == null || props.children.isEmpty
          ? ''
          : props.toXmlString();
      final content = StringBuffer();
      for (final c in r.childElements) {
        if (c.localName == 'rPr') continue;
        content.write(c.localName == 't' ? c.innerText : '<${c.localName}/>');
      }
      if (merged.isNotEmpty && merged.last.$1 == key) {
        merged.last.$2.write(content);
      } else {
        merged.add((key, content));
      }
      r.remove();
    }
    p.children.add(
      XmlElement(XmlName.qualified('code-runs'), const [], [
        for (final (key, content) in merged)
          XmlElement(
            XmlName.qualified('run'),
            [XmlAttribute(XmlName.qualified('props'), key)],
            [XmlText(content.toString())],
          ),
      ]),
    );
  }
  return doc.toXmlString();
}

// ODT: automatic style names depend on the order styles are first used, so
// every `style-name` reference is replaced by the style's definition and the
// automatic styles are dropped; in code paragraphs, spans whose style only
// sets token props are unwrapped and adjacent text merged.
const _office = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
const _style = 'urn:oasis:names:tc:opendocument:xmlns:style:1.0';
const _text = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
const _fo = 'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0';
const _tokenTextProps = {'color', 'font-style', 'font-weight'};

String _odtPart(String path, String text) {
  if (!path.endsWith('.xml')) return text;
  final doc = XmlDocument.parse(text);
  final auto = doc
      .findAllElements('automatic-styles', namespaceUri: _office)
      .firstOrNull;
  final definitions = <String, XmlElement>{
    for (final s
        in auto?.findElements('style', namespaceUri: _style) ??
            const <XmlElement>[])
      s.getAttribute('name', namespaceUri: _style)!: s,
  };
  bool isCode(XmlElement p) {
    const code = 'Preformatted_20_Text';
    final name = p.getAttribute('style-name', namespaceUri: _text);
    return name == code ||
        definitions[name]?.getAttribute(
              'parent-style-name',
              namespaceUri: _style,
            ) ==
            code;
  }

  bool onlyTokenProps(XmlElement span) {
    final s = definitions[span.getAttribute('style-name', namespaceUri: _text)];
    if (s == null) return false;
    final props = s.findElements('text-properties', namespaceUri: _style);
    return props.every(
      (p) => p.attributes.every(
        (a) =>
            a.name.namespaceUri == _fo && _tokenTextProps.contains(a.localName),
      ),
    );
  }

  for (final p in doc.findAllElements('p', namespaceUri: _text).where(isCode)) {
    for (final span in p.findElements('span', namespaceUri: _text).toList()) {
      if (!onlyTokenProps(span)) continue;
      final children = [for (final c in span.children) c.copy()];
      span.replace(XmlDocumentFragment(children));
    }
    p.normalize();
  }
  for (final e in doc.descendantElements) {
    for (final a in e.attributes) {
      if (a.localName.endsWith('style-name') && definitions[a.value] != null) {
        final d = definitions[a.value]!.copy()
          ..removeAttribute('name', namespaceUri: _style);
        a.value = d.toXmlString();
      }
    }
  }
  auto?.children.clear();
  return doc.toXmlString();
}

// RTF: colors are numbered by first use, so `\cfN`-style references are
// resolved through the color table (then dropped); groups that only set a
// color, italic or bold (code tokens; inline runs are identical on both
// sides) are unwrapped.
String _rtf(String rtf) {
  final table = RegExp(r'\{\\colortbl;([^}]*)\}').firstMatch(rtf);
  final colors = <String>[
    '',
    for (final m in RegExp(
      r'\\red(\d+)\\green(\d+)\\blue(\d+);',
    ).allMatches(table?[1] ?? ''))
      '#${m[1]}.${m[2]}.${m[3]}',
  ];
  var out = rtf.replaceFirst(table?[0] ?? '\u0000', '');
  out = out.replaceAllMapped(
    RegExp(r'\\(cf|cbpat|brdrcf|chcbpat)(\d+)'),
    (m) => '\\${m[1]}<${colors[int.parse(m[2]!)]}>',
  );
  final tokenGroup = RegExp(
    r'\{((?:\\(?:cf<[^>]*>|i|b))+) ?((?:[^{}\\]|\\[{}\\]|'
    r"\\'[0-9a-f]{2}|\\u-?\d+ ?\??|\\tab ?)*)\}",
  );
  out = out.replaceAllMapped(tokenGroup, (m) => m[2]!);
  return out;
}

// PDF (uncompressed): the shown strings in order; run boundaries and color
// and font operators are ignored.
String _pdfText(String pdf) => [
  for (final m in RegExp(r'\(((?:[^()\\]|\\.)*)\)').allMatches(pdf)) m[1],
].join();

/// A tokenizer that highlights nothing (the plain layout).
final class _NoTokens implements CodeTokenizer {
  const _NoTokens();

  @override
  bool supports(String language) => true;

  @override
  List<CodeToken> tokenize(String code, String language) => const [];
}
