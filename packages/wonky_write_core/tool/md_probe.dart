import 'package:markdown/markdown.dart' as md;
import 'package:wonky_write_core/src/markdown/md_syntax.dart';

String dump(List<md.Node> nodes, [int d = 0]) {
  final b = StringBuffer();
  for (final n in nodes) {
    if (n is md.Element) {
      b.writeln('${'  ' * d}<${n.tag} ${n.attributes}>');
      b.write(dump(n.children ?? [], d + 1));
    } else if (n is md.Text) {
      b.writeln('${'  ' * d}T"${n.text.replaceAll('\n', r'\n')}"');
    }
  }
  return b.toString();
}

void main(List<String> args) {
  for (final c in args) {
    final src = c.replaceAll(r'\n', '\n');
    print('=== $c');
    print(dump(parseMarkdownAst(src)));
  }
}
