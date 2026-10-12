import 'package:wonky_write_core/src/markdown/md_syntax.dart';
import 'md_probe.dart' show dump;

void main() {
  for (final src in [r'a\``h`', r'a&#96;`h`', r'\` `h`', r'`h`\`', r'a\\`h`']) {
    print('=== $src');
    print(dump(parseMarkdownAst(src)));
  }
}
