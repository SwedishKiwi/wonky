/// The canonical Markdown ⇄ Delta codec (02 §2).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../collab/suggestion_view.dart';
import '../import/import_api.dart';
import '../ir/doc_tree.dart';
import '../ir/doc_tree_builder.dart';
import 'markdown_exporter.dart';
import 'markdown_importer.dart';

/// Converts between Markdown and Wonky Deltas.
///
/// Round-trip guarantee: `importMarkdown(exportMarkdown(D)).delta ==
/// normalize(D)` for every valid `D` without `cmt_*`/`sug_*` attributes
/// (embed ids are not representable in Markdown; pass an
/// [ImportOptions.idGenerator] replaying them to compare exactly) and with
/// canonical table cells ([InlineMarkdown.canonicalCell]).
final class MarkdownCodec {
  /// Creates a codec.
  const MarkdownCodec();

  /// Parses [markdown] (GFM subset; unsupported constructs mapped with
  /// warnings, front matter preserved in [ImportResult.frontMatter]).
  ImportResult importMarkdown(
    String markdown, {
    ImportOptions? options,
    RelativeImageResolver? resolveImage,
  }) => MarkdownImporter(
    options ?? ImportOptions(),
    resolveImage: resolveImage,
  ).import(markdown);

  /// Serializes [document] to Markdown. Suggestions are rendered per [view]
  /// (accepted by default); comments are dropped. [frontMatter] is emitted at
  /// the top when given.
  String exportMarkdown(
    Delta document, {
    SuggestionViewMode view = SuggestionViewMode.accepted,
    String? frontMatter,
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) {
    final tree = const DocTreeBuilder().fromDelta(
      document,
      view: view == SuggestionViewMode.raw ? SuggestionViewMode.accepted : view,
      meta: DocMeta(frontMatter: frontMatter),
    );
    return MarkdownExporter(options: options).export(tree);
  }

  /// Serializes an IR tree.
  String exportTree(
    DocTree tree, {
    MarkdownExportOptions options = const MarkdownExportOptions(),
  }) => MarkdownExporter(options: options).export(tree);
}
