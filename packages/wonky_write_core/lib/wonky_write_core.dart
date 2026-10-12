/// Pure Dart core for Wonky Write: Delta schema, Markdown codec, OT helpers,
/// derived data, importers/exporters and the theme model.
///
/// Never imports Flutter; runs on the server (VM) and in the apps (VM + web).
library;

export 'package:dart_quill_delta/dart_quill_delta.dart' show Delta, Operation;

export 'src/delta/attributes.dart';
export 'src/delta/delta_utils.dart';
export 'src/delta/document.dart';
export 'src/delta/embeds.dart';
export 'src/delta/hash.dart';
export 'src/delta/links.dart';
export 'src/delta/normalizer.dart';
export 'src/delta/ot.dart';
export 'src/delta/validator.dart';
export 'src/derived/outline.dart';
export 'src/derived/stats.dart';
export 'src/ir/anchors.dart';
export 'src/collab/suggestion_view.dart';
export 'src/import/import_api.dart';
export 'src/ir/doc_tree.dart';
export 'src/ir/doc_tree_builder.dart';
export 'src/markdown/front_matter.dart';
export 'src/markdown/inline_markdown.dart';
export 'src/markdown/inline_reader.dart' show mentionTitlePrefix;
export 'src/markdown/inline_writer.dart';
export 'src/markdown/markdown_codec.dart';
export 'src/markdown/markdown_exporter.dart';
export 'src/markdown/markdown_importer.dart'
    show MarkdownImporter, RelativeImageResolver;
