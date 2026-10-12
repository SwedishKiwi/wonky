import 'dart:convert';
import 'package:test/test.dart';
import 'package:wonky_write_core/src/import/importers.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

void main() {
  test('probe', () {
    var n = 0;
    final r = const HtmlImporter().importHtml('''
<html lang="en-us"><head><title>T</title></head><body>
<h1>Hello <b>world</b></h1>
<p>Some   <i>text</i><br>next <a href="https://x.com">link</a> <a href="javascript:x">bad</a></p>
<ul><li>a<ul><li>b</li></ul></li><li><input type="checkbox" checked> done</li></ul>
<blockquote><p>q1</p><p>q2</p></blockquote>
<pre><code class="language-dart">void main() {
  print(1);
}
</code></pre>
<table><tr><th>A</th><th align="right">B</th></tr><tr><td colspan="2">x <b>y</b></td></tr></table>
<figure><img src="https://e.com/a.png" alt="An image"><figcaption>Cap</figcaption></figure>
<p><span style="color:red;text-decoration:underline">red</span></p>
<p><br></p>
</body></html>''', ImportOptions(idGenerator: () => 'id${n++}'));
    print(jsonEncode(r.delta.toJson()).replaceAll("\u2028", "<SB>"));
    print(r.warnings);
    print('${r.title} ${r.language}');
  });
}
