/// Document IR shared by importers and exporters (07 §2.1).
library;

import 'package:collection/collection.dart';

import '../delta/embeds.dart';

/// A run of text with uniform inline formatting.
final class InlineRun {
  /// Creates a run.
  const InlineRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.link,
    this.mentionUserUuid,
  });

  /// Text; may contain U+2028 (soft break), never `"\n"`.
  final String text;

  /// Bold.
  final bool bold;

  /// Italic.
  final bool italic;

  /// Strikethrough.
  final bool strike;

  /// Inline code.
  final bool code;

  /// Link target.
  final String? link;

  /// Mentioned user UUID (with a `mailto:` [link]).
  final String? mentionUserUuid;

  /// Whether formatting equals [other]'s.
  bool sameFormat(InlineRun other) =>
      bold == other.bold &&
      italic == other.italic &&
      strike == other.strike &&
      code == other.code &&
      link == other.link &&
      mentionUserUuid == other.mentionUserUuid;

  /// Whether the run has no formatting.
  bool get isPlain =>
      !bold &&
      !italic &&
      !strike &&
      !code &&
      link == null &&
      mentionUserUuid == null;

  /// Copy with changed fields.
  InlineRun copyWith({
    String? text,
    bool? bold,
    bool? italic,
    bool? strike,
    bool? code,
    String? link,
    bool clearLink = false,
    String? mentionUserUuid,
    bool clearMention = false,
  }) => InlineRun(
    text ?? this.text,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    strike: strike ?? this.strike,
    code: code ?? this.code,
    link: clearLink ? null : (link ?? this.link),
    mentionUserUuid: clearMention
        ? null
        : (mentionUserUuid ?? this.mentionUserUuid),
  );

  /// Delta attributes of this run (`null` when plain).
  Map<String, dynamic>? toAttributes() {
    final a = <String, dynamic>{
      if (bold && !code) 'bold': true,
      if (italic && !code) 'italic': true,
      if (strike && !code) 'strike': true,
      if (code) 'code': true,
      'link': ?link,
      'mention': ?mentionUserUuid,
    };
    return a.isEmpty ? null : a;
  }

  /// Reads a run from Delta attributes (overlays are ignored).
  factory InlineRun.fromAttributes(String text, Map<String, dynamic>? a) =>
      InlineRun(
        text,
        bold: a?['bold'] == true,
        italic: a?['italic'] == true,
        strike: a?['strike'] == true,
        code: a?['code'] == true,
        link: a?['link'] as String?,
        mentionUserUuid: a?['mention'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is InlineRun && other.text == text && sameFormat(other);

  @override
  int get hashCode =>
      Object.hash(text, bold, italic, strike, code, link, mentionUserUuid);

  @override
  String toString() {
    final f = [
      if (bold) 'b',
      if (italic) 'i',
      if (strike) 's',
      if (code) 'c',
      if (link != null) 'link=$link',
      if (mentionUserUuid != null) '@$mentionUserUuid',
    ];
    return 'Run("$text"${f.isEmpty ? '' : ' ${f.join(',')}'})';
  }

  /// Merges adjacent runs with equal formatting and drops empty runs.
  static List<InlineRun> merge(Iterable<InlineRun> runs) {
    final out = <InlineRun>[];
    for (final r in runs) {
      if (r.text.isEmpty) continue;
      if (out.isNotEmpty && out.last.sameFormat(r)) {
        out[out.length - 1] = out.last.copyWith(text: out.last.text + r.text);
      } else {
        out.add(r);
      }
    }
    return out;
  }

  /// Concatenated text of [runs].
  static String plainText(Iterable<InlineRun> runs) =>
      runs.map((r) => r.text).join();
}

/// Kind of a [ListItemBlock].
enum ListKindIr {
  /// Bullet list.
  bullet,

  /// Ordered list.
  ordered,
}

/// Document metadata passed to exporters.
final class DocMeta {
  /// Creates metadata.
  const DocMeta({
    this.documentUuid,
    this.title,
    this.authorName,
    this.language,
    this.frontMatter,
    this.description,
    this.createdAt,
    this.modifiedAt,
  });

  /// Document UUID.
  final String? documentUuid;

  /// Title (Drive item name).
  final String? title;

  /// Owner display name (or front matter `author`).
  final String? authorName;

  /// BCP-47 language.
  final String? language;

  /// Front matter (without `---` fences).
  final String? frontMatter;

  /// Drive description.
  final String? description;

  /// Creation time.
  final DateTime? createdAt;

  /// Last modification time (used for deterministic timestamps).
  final DateTime? modifiedAt;

  /// Copy with changed fields.
  DocMeta copyWith({
    String? documentUuid,
    String? title,
    String? authorName,
    String? language,
    String? frontMatter,
    String? description,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) => DocMeta(
    documentUuid: documentUuid ?? this.documentUuid,
    title: title ?? this.title,
    authorName: authorName ?? this.authorName,
    language: language ?? this.language,
    frontMatter: frontMatter ?? this.frontMatter,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
  );
}

/// A block of the IR. Offsets map back to the source Delta (exports only;
/// 0 for imported trees).
sealed class DocBlock {
  const DocBlock({this.deltaStart = 0, this.deltaLength = 0});

  /// Delta offset of the first line of the block.
  final int deltaStart;

  /// Delta length of the block (all its lines).
  final int deltaLength;
}

/// A paragraph.
final class ParagraphBlock extends DocBlock {
  /// Creates a paragraph.
  const ParagraphBlock(this.runs, {super.deltaStart, super.deltaLength});

  /// Inline content (empty = empty paragraph).
  final List<InlineRun> runs;
}

/// A heading.
final class HeadingBlock extends DocBlock {
  /// Creates a heading.
  const HeadingBlock(
    this.level,
    this.runs, {
    this.anchorId = '',
    super.deltaStart,
    super.deltaLength,
  });

  /// Level 1–6.
  final int level;

  /// Inline content.
  final List<InlineRun> runs;

  /// Unique anchor id (`h-<slug>-<n>`).
  final String anchorId;
}

/// A bullet or ordered list item.
final class ListItemBlock extends DocBlock {
  /// Creates a list item.
  const ListItemBlock(
    this.kind,
    this.indent,
    this.runs, {
    this.ordinal = 1,
    super.deltaStart,
    super.deltaLength,
  });

  /// Bullet or ordered.
  final ListKindIr kind;

  /// Nesting level 0–8.
  final int indent;

  /// 1-based number among consecutive ordered items at this level.
  final int ordinal;

  /// Inline content.
  final List<InlineRun> runs;
}

/// A task list item.
final class TaskBlock extends DocBlock {
  /// Creates a task item.
  const TaskBlock(
    this.checked,
    this.indent,
    this.runs, {
    super.deltaStart,
    super.deltaLength,
  });

  /// Whether the task is done.
  final bool checked;

  /// Nesting level 0–8.
  final int indent;

  /// Inline content.
  final List<InlineRun> runs;
}

/// Consecutive blockquote lines.
final class QuoteBlock extends DocBlock {
  /// Creates a quote.
  const QuoteBlock(this.lines, {super.deltaStart, super.deltaLength});

  /// One entry per quote line.
  final List<List<InlineRun>> lines;
}

/// Consecutive code lines with the same language.
final class CodeBlock extends DocBlock {
  /// Creates a code block.
  const CodeBlock(
    this.language,
    this.text, {
    super.deltaStart,
    super.deltaLength,
  });

  /// Language (`""` = none).
  final String language;

  /// Code text; lines separated by `"\n"` (no trailing newline).
  final String text;

  /// The code lines.
  List<String> get lines => text.split('\n');
}

/// An image.
final class ImageBlock extends DocBlock {
  /// Creates an image block.
  const ImageBlock(
    this.id,
    this.src,
    this.alt, {
    this.title,
    super.deltaStart,
    super.deltaLength,
  });

  /// Embed id.
  final String id;

  /// Source URL.
  final String src;

  /// Alt text.
  final String alt;

  /// Optional title / caption.
  final String? title;

  /// As an embed.
  ImageEmbed toEmbed() => ImageEmbed(id: id, src: src, alt: alt, title: title);
}

/// A horizontal rule.
final class RuleBlock extends DocBlock {
  /// Creates a rule.
  const RuleBlock(this.id, {super.deltaStart, super.deltaLength});

  /// Embed id.
  final String id;
}

/// A table.
final class TableBlock extends DocBlock {
  /// Creates a table.
  const TableBlock(
    this.id,
    this.align,
    this.rows, {
    required this.cellMarkdown,
    super.deltaStart,
    super.deltaLength,
  });

  /// Embed id.
  final String id;

  /// Column alignment.
  final List<CellAlign?> align;

  /// Parsed cells: rows → cells → runs. Row 0 is the header.
  final List<List<List<InlineRun>>> rows;

  /// The original inline-Markdown cell strings (same shape as [rows]).
  final List<List<String>> cellMarkdown;

  /// Number of columns.
  int get columnCount => align.length;

  /// As an embed.
  TableEmbed toEmbed() => TableEmbed(id: id, align: align, rows: cellMarkdown);
}

/// The document IR: blocks plus metadata.
final class DocTree {
  /// Creates a tree.
  const DocTree(this.blocks, {this.meta = const DocMeta()});

  /// Blocks in document order.
  final List<DocBlock> blocks;

  /// Metadata.
  final DocMeta meta;

  /// Headings in order.
  Iterable<HeadingBlock> get headings => blocks.whereType<HeadingBlock>();

  /// Images in order.
  Iterable<ImageBlock> get images => blocks.whereType<ImageBlock>();

  /// The first block if it is a level-1 heading.
  HeadingBlock? get titleHeading {
    final first = blocks.firstOrNull;
    return first is HeadingBlock && first.level == 1 ? first : null;
  }
}
