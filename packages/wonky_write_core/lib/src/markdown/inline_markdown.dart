/// Inline Markdown helpers (table cells, inline insertion, plain text).
library;

import 'package:markdown/markdown.dart' as md;

import '../import/import_api.dart';
import '../ir/doc_tree.dart';
import 'inline_reader.dart';
import 'inline_writer.dart';
import 'md_syntax.dart';

/// Parsing and canonicalization of inline Markdown strings.
abstract final class InlineMarkdown {
  /// Parses inline Markdown (e.g. a table cell) into runs. Block structure is
  /// ignored: the text is read as one paragraph.
  static List<InlineRun> parse(String source, {List<ImportWarning>? warnings}) {
    final nodes = parseMarkdownAst(source.replaceAll('\n', ' '));
    final reader = InlineReader(warnings ?? <ImportWarning>[]);
    final runs = <InlineRun>[];
    for (final n in nodes) {
      if (n is md.Element && n.children != null) {
        runs.addAll(reader.readRuns(n.children!));
      } else {
        runs.addAll(reader.readRuns([n]));
      }
    }
    return InlineRun.merge(runs);
  }

  /// Plain text of inline Markdown (formatting removed).
  static String toPlainText(String source) =>
      InlineRun.plainText(parse(source));

  /// Canonical inline Markdown for a table cell: `write(parse(cell))`.
  static String canonicalCell(String cell) =>
      InlineMarkdownWriter.write(parse(cell), context: InlineContext.tableCell);
}
