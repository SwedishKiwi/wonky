/// The block features a Markdown field supports.
library;

/// Which block kinds a field turns into structure (specs/16 §7.3): blocks a
/// field does not support stay text, like the renderer's profiles do
/// (`MarkdownProfile` in the shell). Paragraphs, lists, task lists and
/// inline styles are always supported. Fenced code blocks are not edited
/// as code: they are kept as literal Markdown
/// ([MarkdownNodeMetadata.raw]), like tables and HTML.
class MarkdownBlockFeatures {
  const MarkdownBlockFeatures({
    this.headings = true,
    this.quotes = true,
    this.rules = true,
  });

  /// Every block (board posts, task prompts).
  static const all = MarkdownBlockFeatures();

  /// Comments: no headings, quotes or rules.
  static const comment = MarkdownBlockFeatures(
    headings: false,
    quotes: false,
    rules: false,
  );

  /// `#` headings (levels 1–6; the post renderer draws them at most at h3
  /// size).
  final bool headings;

  /// `>` quotes.
  final bool quotes;

  /// `---` horizontal rules.
  final bool rules;

  @override
  bool operator ==(Object other) =>
      other is MarkdownBlockFeatures &&
      other.headings == headings &&
      other.quotes == quotes &&
      other.rules == rules;

  @override
  int get hashCode => Object.hash(headings, quotes, rules);
}

/// Node metadata keys of the codec. They live on the super_editor nodes the
/// codec creates and never reach the Markdown.
abstract final class MarkdownNodeMetadata {
  /// `true` on a block kept as literal Markdown (fenced code, tables,
  /// HTML, images, anything the editor cannot represent): a code-styled
  /// paragraph whose text is written back verbatim.
  static const raw = 'wonky.md.raw';

  /// The block's Markdown as it was read.
  static const source = 'wonky.md.source';

  /// The block's Markdown as the codec writes it, computed when it was
  /// read: while the block still serializes to it, [source] is written
  /// instead, so untouched blocks keep their exact text.
  static const canonical = 'wonky.md.canonical';

  /// The text between the previous block and this one as it was read.
  static const gap = 'wonky.md.gap';

  /// The id of the block before this one when it was read.
  static const previous = 'wonky.md.previous';

  /// The block kind when it was read (`p`, `h2`, `ul`, `ol`, `task`,
  /// `quote`, `raw`, `hr`).
  static const kind = 'wonky.md.kind';
}
