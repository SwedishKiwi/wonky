/// Import interfaces and results (02 §2.1, 07 §2.2).
library;

import 'dart:typed_data';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:uuid/uuid.dart';

/// Import source formats.
enum ImportFormat {
  /// Markdown (`.md`, `.markdown`, …).
  markdown,

  /// Plain text.
  txt,

  /// HTML (files and clipboard).
  html,

  /// Word (`.docx`).
  docx,

  /// OpenDocument text (`.odt`).
  odt,

  /// Rich Text Format (`.rtf`).
  rtf,
}

/// Kinds of import warnings (stable codes shown in the import banner).
enum ImportWarningKind {
  /// Nested blockquotes flattened to one level.
  nestedQuoteFlattened,

  /// A list inside a blockquote was flattened to quote lines.
  listInQuoteFlattened,

  /// A block (heading, code, table, …) inside a list item or quote was moved
  /// out or flattened.
  blockFlattened,

  /// Ordered list starting at a number other than 1 (numbering restarts).
  orderedListStart,

  /// List nesting deeper than 8 levels was flattened.
  indentTooDeep,

  /// A list item with several paragraphs was joined with soft breaks.
  multiParagraphItem,

  /// Inline HTML was stripped to text.
  htmlStripped,

  /// An HTML block was converted to text.
  htmlBlock,

  /// A link with a relative or unsupported target was dropped (text kept).
  unsupportedLink,

  /// An image could not be resolved (relative path, unsupported source).
  unresolvedImage,

  /// An image inside a link or table cell was converted to text.
  imageFlattened,

  /// Formatting not expressible in Markdown (underline, color, fonts, …) was
  /// removed.
  formattingRemoved,

  /// Table cells were merged/spanned or nested; content flattened.
  tableFlattened,

  /// Content that could not be represented was dropped (scripts, forms, …).
  contentDropped,

  /// Footnotes/endnotes were appended as a "Notes" section.
  footnotesAppended,

  /// Comments in the source were dropped.
  commentsDropped,

  /// Tracked changes were accepted.
  trackedChangesAccepted,

  /// Page/section breaks or columns were dropped.
  breaksDropped,

  /// Headers/footers were dropped.
  headersFootersDropped,

  /// The source text encoding was guessed (invalid UTF-8).
  encodingGuessed,

  /// Equations/charts/shapes were replaced with placeholders.
  placeholderInserted,
}

/// One import warning.
final class ImportWarning {
  /// Creates a warning.
  const ImportWarning(this.kind, this.message, {this.line, this.blockIndex});

  /// Kind.
  final ImportWarningKind kind;

  /// Human-readable description.
  final String message;

  /// 1-based source line, when known.
  final int? line;

  /// 0-based line index in the resulting document, when known.
  final int? blockIndex;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'message': message,
    'line': ?line,
    'block_index': ?blockIndex,
  };

  @override
  String toString() => 'ImportWarning(${kind.name}: $message)';
}

/// An image extracted during import, referenced by `import-image://<tempId>`.
final class ImportedImage {
  /// Creates an imported image.
  const ImportedImage({
    required this.tempId,
    required this.bytes,
    required this.mime,
    this.alt = '',
  });

  /// Temporary id used in the `src`.
  final String tempId;

  /// Image bytes.
  final Uint8List bytes;

  /// MIME type.
  final String mime;

  /// Alt text.
  final String alt;

  /// The temporary `src` value.
  String get src => 'import-image://$tempId';
}

/// Page geometry detected in a source document (DOCX/ODT/RTF → page setup).
final class ImportedPageSetup {
  /// Creates detected page geometry (all lengths in points).
  const ImportedPageSetup({
    required this.widthPt,
    required this.heightPt,
    this.marginTopPt,
    this.marginRightPt,
    this.marginBottomPt,
    this.marginLeftPt,
  });

  /// Page width.
  final double widthPt;

  /// Page height.
  final double heightPt;

  /// Top margin.
  final double? marginTopPt;

  /// Right margin.
  final double? marginRightPt;

  /// Bottom margin.
  final double? marginBottomPt;

  /// Left margin.
  final double? marginLeftPt;
}

/// Result of an import.
final class ImportResult {
  /// Creates a result.
  const ImportResult({
    required this.delta,
    this.warnings = const [],
    this.title,
    this.frontMatter,
    this.language,
    this.images = const [],
    this.pageSetup,
  });

  /// The imported, normalized and valid document delta.
  final Delta delta;

  /// What could not be imported exactly.
  final List<ImportWarning> warnings;

  /// Suggested title (front matter, document properties, `<title>`, first H1).
  final String? title;

  /// Front matter (without `---` fences).
  final String? frontMatter;

  /// Source language (BCP-47) when known.
  final String? language;

  /// Images referenced as `import-image://<tempId>`.
  final List<ImportedImage> images;

  /// Page geometry from the source, when present.
  final ImportedPageSetup? pageSetup;
}

/// Options shared by importers.
final class ImportOptions {
  /// Creates options.
  ImportOptions({
    String Function()? idGenerator,
    this.txtLineBreaks = TxtLineBreaks.paragraph,
    this.baseUrl,
    this.fileName,
  }) : idGenerator = idGenerator ?? _uuidV7;

  static String _uuidV7() => const Uuid().v7();

  /// Generates embed ids (UUIDv7 by default; inject for determinism).
  final String Function() idGenerator;

  /// Plain-text line break handling.
  final TxtLineBreaks txtLineBreaks;

  /// Base URL for resolving relative links (HTML `<base>`/source URL).
  final Uri? baseUrl;

  /// Original file name (title fallback).
  final String? fileName;
}

/// Plain-text import line handling (07 §3.4).
enum TxtLineBreaks {
  /// Each line becomes a paragraph.
  paragraph,

  /// Blank-line separated blocks become paragraphs; single line breaks become
  /// soft breaks (U+2028).
  soft,
}

/// An importer for one [ImportFormat].
abstract interface class DocumentImporter {
  /// The format.
  ImportFormat get format;

  /// Imports [bytes].
  Future<ImportResult> import(Uint8List bytes, ImportOptions options);
}
