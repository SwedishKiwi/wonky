/// Markdown ⇄ super_editor document for the lightweight editor (specs/16
/// §7.3).
library;

import 'dart:math' as math;

import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show wonkyGfm;

import 'block_syntax.dart';
import 'inline_codec.dart';
import 'markdown_features.dart';

/// Converts Markdown to a super_editor document and back.
///
/// **Subset.** Paragraphs (their lines stay lines: `"\n"` in the node
/// text), `#` headings 1–6, bullet and numbered items with nesting levels,
/// task items (`- [ ]`, `- [x]`), `>` quotes, `---` rules, and inline
/// bold, italic, strikethrough, code and links (through `wonky_rich_text`'s inline reader and writer, so
/// the syntax matches Write and Slides). [features] turns headings, quotes
/// and rules off for comments: their lines then stay text.
///
/// **Everything else is kept, never lost.** Fenced and indented code (the
/// editor has no code blocks: a fence is literal text the user edits or
/// deletes like any other block), tables, HTML blocks, link reference
/// definitions and any block whose
/// inline content the editor cannot represent (images, raw inline HTML,
/// links with titles or other schemes, styles spanning lines, a list item
/// holding a quote …) become a *literal* block: a code-styled paragraph
/// (metadata [MarkdownNodeMetadata.raw]) written back verbatim.
///
/// **Untouched blocks keep their text.** Every block remembers its source
/// and the Markdown the codec would write for it
/// ([MarkdownNodeMetadata.canonical]); while it still writes to that, the
/// source is written instead, and the text between two such neighbours
/// is kept too. Editing one paragraph therefore changes only that
/// paragraph's Markdown, which keeps diffs (the prompt editor's) small.
///
/// [encode] is stable: `encode(decode(encode(d)))` equals `encode(d)`.
class MarkdownDocumentCodec {
  const MarkdownDocumentCodec({this.features = MarkdownBlockFeatures.all});

  final MarkdownBlockFeatures features;

  /// [markdown] as a document (at least one node; a trailing paragraph
  /// follows a final rule so the caret can get past it).
  MutableDocument decode(String markdown) =>
      MutableDocument(nodes: decodeNodes(markdown));

  /// [markdown] as document nodes (see [decode]).
  List<DocumentNode> decodeNodes(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final mdDoc = md.Document(extensionSet: wonkyGfm, encodeHtml: true);
    final definitions = [
      for (final l in lines)
        if (linkDefinitionLine.hasMatch(l)) l,
    ];
    if (definitions.isNotEmpty) mdDoc.parseLines(definitions);
    final inline = InlineMarkdownCodec(document: mdDoc)
      ..bareBrackets = definitions.isEmpty;

    final blocks = _Scanner(lines, features).scan();
    final nodes = <DocumentNode>[];
    final sources = <String>[];
    final gaps = <String?>[];
    var previousEnd = -1;
    for (final b in blocks) {
      final source = lines.sublist(b.start, b.end).join('\n');
      final node = _node(b, inline) ?? _literal(source);
      nodes.add(node);
      sources.add(source);
      gaps.add(
        previousEnd < 0
            ? null
            : '\n${lines.sublist(previousEnd, b.start).map((l) => '$l\n').join()}',
      );
      previousEnd = b.end;
    }
    if (nodes.isEmpty || nodes.last is! TextNode) {
      nodes.add(_paragraph(AttributedText()));
      sources.add('');
      gaps.add(null);
    }

    // What the codec writes for each block now, in context.
    final encoder = _Encoder(MutableDocument(nodes: nodes), features);
    final out = <DocumentNode>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final canonical = encoder.next(node);
      if (canonical == null && sources[i].isEmpty) {
        out.add(node);
        continue;
      }
      out.add(
        node.copyWithAddedMetadata({
          MarkdownNodeMetadata.source: sources[i],
          MarkdownNodeMetadata.canonical: canonical ?? '',
          MarkdownNodeMetadata.kind: kindOf(node),
          MarkdownNodeMetadata.gap: ?gaps[i],
          if (i > 0) MarkdownNodeMetadata.previous: nodes[i - 1].id,
        }),
      );
    }
    return out;
  }

  /// [document] as Markdown.
  String encode(Document document) {
    final encoder = _Encoder(document, features);
    final b = StringBuffer();
    DocumentNode? previous;
    for (final node in document) {
      final fresh = encoder.next(node);
      if (fresh == null) continue;
      final kind = kindOf(node);
      var text = fresh;
      final source = node.getMetadataValue(MarkdownNodeMetadata.source);
      if (source is String &&
          node.getMetadataValue(MarkdownNodeMetadata.canonical) == fresh &&
          node.getMetadataValue(MarkdownNodeMetadata.kind) == kind) {
        text = source;
      }
      if (previous != null) {
        final gap = node.getMetadataValue(MarkdownNodeMetadata.gap);
        final keepGap =
            gap is String &&
            node.getMetadataValue(MarkdownNodeMetadata.previous) ==
                previous.id &&
            node.getMetadataValue(MarkdownNodeMetadata.kind) == kind &&
            previous.getMetadataValue(MarkdownNodeMetadata.kind) ==
                kindOf(previous);
        b.write(keepGap ? gap : _defaultGap(kindOf(previous), kind));
      }
      b.write(text);
      previous = node;
    }
    return b.toString().trimRight();
  }

  static String _defaultGap(String before, String after) {
    if (_listKinds.contains(before) && _listKinds.contains(after)) return '\n';
    if (before == 'quote' && after == 'quote') return '\n>\n';
    return '\n\n';
  }

  static const _listKinds = {'ul', 'ol', 'task'};

  /// The block kind of [node] (`p`, `h1`…`h6`, `ul`, `ol`, `task`, `quote`,
  /// `raw`, `hr`, or `other`). Every code-styled paragraph is a literal
  /// block (`raw`): the editor has no code blocks.
  static String kindOf(DocumentNode node) {
    if (node is ListItemNode) {
      return node.type == ListItemType.ordered ? 'ol' : 'ul';
    }
    if (node is TaskNode) return 'task';
    if (node is HorizontalRuleNode) return 'hr';
    if (node is ParagraphNode) {
      final type = node.getMetadataValue(NodeMetadata.blockType);
      if (type == codeAttribution) return 'raw';
      if (type == blockquoteAttribution) return 'quote';
      final h = headingLevelOf(node);
      if (h != null) return 'h$h';
      return 'p';
    }
    return 'other';
  }

  /// The heading level (1–6) of [node], or null.
  static int? headingLevelOf(DocumentNode node) {
    final type = node.getMetadataValue(NodeMetadata.blockType);
    for (var i = 0; i < _headers.length; i++) {
      if (type == _headers[i]) return i + 1;
    }
    return null;
  }

  static const _headers = [
    header1Attribution,
    header2Attribution,
    header3Attribution,
    header4Attribution,
    header5Attribution,
    header6Attribution,
  ];

  /// The block attribution of heading [level] (1–6).
  static Attribution headerAttribution(int level) =>
      _headers[(level - 1).clamp(0, 5)];

  // ------------------------------------------------------------- reading

  DocumentNode? _node(_Block b, InlineMarkdownCodec inline) {
    switch (b.kind) {
      case _K.paragraph:
        final t = inline.read(b.content);
        return t == null ? null : _paragraph(t);
      case _K.heading:
        final t = inline.read(b.content);
        return t == null
            ? null
            : ParagraphNode(
                id: Editor.createNodeId(),
                text: t,
                metadata: {NodeMetadata.blockType: headerAttribution(b.level)},
              );
      case _K.quote:
        final t = inline.read(b.content);
        return t == null
            ? null
            : ParagraphNode(
                id: Editor.createNodeId(),
                text: t,
                metadata: {NodeMetadata.blockType: blockquoteAttribution},
              );
      case _K.bullet || _K.ordered:
        final t = inline.read(b.content);
        return t == null
            ? null
            : ListItemNode(
                id: Editor.createNodeId(),
                itemType: b.kind == _K.ordered
                    ? ListItemType.ordered
                    : ListItemType.unordered,
                text: t,
                indent: b.level,
              );
      case _K.task:
        final t = inline.read(b.content);
        return t == null
            ? null
            : TaskNode(
                id: Editor.createNodeId(),
                text: t,
                isComplete: b.checked,
                indent: b.level,
              );
      case _K.rule:
        return HorizontalRuleNode(id: Editor.createNodeId());
      case _K.raw:
        return null;
    }
  }

  static ParagraphNode _paragraph(AttributedText text) =>
      ParagraphNode(id: Editor.createNodeId(), text: text);

  /// A literal block: [source] kept as is.
  static ParagraphNode _literal(String source) => ParagraphNode(
    id: Editor.createNodeId(),
    text: AttributedText(source),
    metadata: {
      NodeMetadata.blockType: codeAttribution,
      MarkdownNodeMetadata.raw: true,
    },
  );
}

// ------------------------------------------------------------------ writing

/// Writes nodes one after the other (list levels and numbering need the
/// nodes before).
class _Encoder {
  _Encoder(this.document, this.features) {
    // `[label]` could become a link next to a reference definition.
    for (final node in document) {
      if (node is ParagraphNode &&
          node.getMetadataValue(MarkdownNodeMetadata.raw) == true &&
          node.text
              .toPlainText()
              .split('\n')
              .any(linkDefinitionLine.hasMatch)) {
        _bareBrackets = false;
        break;
      }
    }
    _inline = InlineMarkdownCodec()..bareBrackets = _bareBrackets;
  }

  final Document document;
  final MarkdownBlockFeatures features;
  late final InlineMarkdownCodec _inline;
  var _bareBrackets = true;

  /// The content columns of the open list levels.
  final _columns = <int>[];

  /// The numbers of the open numbered lists per level (super_editor's
  /// numbering: a task or another block ends them, a bullet ends its
  /// level's, a lower item the deeper ones).
  final _numbers = <int>[];

  static final _cache = Expando<_Lines>('wonky.md.lines');

  List<String> _lines(TextNode node, {bool heading = false}) {
    final cached = _cache[node];
    if (cached != null &&
        cached.bareBrackets == _bareBrackets &&
        cached.heading == heading) {
      return cached.lines;
    }
    final lines = _inline.writeLines(node.text, heading: heading);
    _cache[node] = _Lines(lines, _bareBrackets, heading);
    return lines;
  }

  /// The Markdown of [node], or null when it writes nothing (an empty
  /// paragraph, heading or quote).
  String? next(DocumentNode node) {
    final kind = MarkdownDocumentCodec.kindOf(node);
    if (node is ListItemNode || node is TaskNode) {
      return _item(node as TextNode);
    }
    if (kind != 'raw') _columns.clear();
    _numbers.clear();
    switch (kind) {
      case 'hr':
        return '---';
      case 'raw':
        final t = (node as ParagraphNode).text.toPlainText();
        return t.trim().isEmpty ? null : t;
      case 'quote':
        final lines = _lines(node as ParagraphNode);
        if (lines.every((l) => l.isEmpty)) return null;
        return [for (final l in lines) l.isEmpty ? '>' : '> $l'].join('\n');
      case 'p':
        final lines = _lines(node as ParagraphNode);
        if (lines.every((l) => l.isEmpty)) return null;
        return lines.join('\n').trim();
      case 'other':
        return null;
    }
    // Headings: one line (breaks become spaces).
    final level = MarkdownDocumentCodec.headingLevelOf(node)!;
    final p = node as ParagraphNode;
    final line = _inline.writeLine(
      InlineMarkdownCodec.textToRuns(
        p.text,
      ).map((r) => r.copyWith(text: r.text.replaceAll('\n', ' '))).toList(),
      heading: true,
    );
    if (line.isEmpty) return null;
    return '${'#' * level} $line';
  }

  String _item(TextNode node) {
    final indent = node is ListItemNode
        ? node.indent
        : (node as TaskNode).indent;
    final level = math.min(indent, _columns.length);
    _columns.length = level;
    final pad = level == 0 ? 0 : _columns[level - 1];
    final String marker;
    if (node is TaskNode) {
      marker = node.isComplete ? '- [x] ' : '- [ ] ';
      _columns.add(pad + 2);
      _numbers.clear();
    } else {
      while (_numbers.length <= level) {
        _numbers.add(0);
      }
      _numbers.length = level + 1;
      if ((node as ListItemNode).type == ListItemType.ordered) {
        _numbers[level]++;
        marker = '${_numbers[level]}. ';
        _columns.add(pad + marker.length);
      } else {
        _numbers[level] = 0;
        marker = '- ';
        _columns.add(pad + 2);
      }
    }
    final lines = _lines(node).where((l) => l.isNotEmpty).toList();
    // An empty item keeps its marker's space (`- `), so it stays an item.
    if (lines.isEmpty) return '${' ' * pad}$marker';
    final continuation = ' ' * _columns.last;
    return [
      '${' ' * pad}$marker${lines.first}',
      for (final l in lines.skip(1)) '$continuation$l',
    ].join('\n');
  }
}

class _Lines {
  const _Lines(this.lines, this.bareBrackets, this.heading);

  final List<String> lines;
  final bool bareBrackets;
  final bool heading;
}

// ------------------------------------------------------------------ scanning

enum _K { paragraph, heading, bullet, ordered, task, quote, raw, rule }

class _Block {
  _Block(
    this.kind,
    this.start,
    this.end, {
    this.level = 0,
    this.checked = false,
    this.content = const [],
  });

  final _K kind;

  /// Source lines `[start, end)`.
  final int start;
  final int end;

  /// Heading level, or list level (0 = top).
  final int level;
  final bool checked;

  /// Inline content lines.
  final List<String> content;
}

/// The line-based block scanner (see [startsBlock] for the patterns).
class _Scanner {
  _Scanner(this.lines, this.features);

  final List<String> lines;
  final MarkdownBlockFeatures features;

  /// Content columns of the open list items (CommonMark nesting: an item
  /// indented to at least its predecessor's content column is its child).
  final _stack = <int>[];

  bool _blank(int k) => lines[k].trim().isEmpty;

  static String _leading(String line) =>
      RegExp(r'^\s*').firstMatch(line)!.group(0)!;

  List<_Block> scan() {
    final out = <_Block>[];
    final n = lines.length;
    var i = 0;
    while (i < n) {
      final line = lines[i];
      if (_blank(i)) {
        i++;
        continue;
      }

      // Fenced code is kept literally, fences included: the editor has no
      // code blocks (specs/16 §7.3).
      final f = fenceOpen.firstMatch(line);
      if (f != null &&
          !(f.group(2)!.startsWith('`') && f.group(3)!.contains('`'))) {
        final fence = f.group(2)!;
        final close = RegExp(
          '^\\s*${RegExp.escape(fence[0])}{${fence.length},}\\s*\$',
        );
        var j = i + 1;
        while (j < n && !close.hasMatch(lines[j])) {
          j++;
        }
        final end = j < n ? j + 1 : n;
        _stack.clear();
        out.add(_Block(_K.raw, i, end));
        i = end;
        continue;
      }

      // Indented code, link reference definitions, tables and HTML are
      // kept literally.
      if (_stack.isEmpty && indentedCodeLine.hasMatch(line)) {
        var j = i + 1;
        while (j < n && (_blank(j) || indentedCodeLine.hasMatch(lines[j]))) {
          j++;
        }
        while (j > i + 1 && _blank(j - 1)) {
          j--;
        }
        out.add(_Block(_K.raw, i, j));
        i = j;
        continue;
      }
      if (linkDefinitionLine.hasMatch(line)) {
        var j = i + 1;
        while (j < n && linkDefinitionLine.hasMatch(lines[j])) {
          j++;
        }
        _stack.clear();
        out.add(_Block(_K.raw, i, j));
        i = j;
        continue;
      }
      if (tableLine.hasMatch(line)) {
        var j = i + 1;
        while (j < n && tableLine.hasMatch(lines[j])) {
          j++;
        }
        _stack.clear();
        out.add(_Block(_K.raw, i, j));
        i = j;
        continue;
      }
      if (htmlLine.hasMatch(line)) {
        var j = i + 1;
        while (j < n && !_blank(j)) {
          j++;
        }
        _stack.clear();
        out.add(_Block(_K.raw, i, j));
        i = j;
        continue;
      }

      final h = features.headings ? headingLine.firstMatch(line) : null;
      if (h != null) {
        var content = h.group(2)!;
        // A closing sequence (`## Title ##`) is not content.
        content = content.replaceFirst(RegExp(r'(^|[ \t]+)#+$'), '');
        _stack.clear();
        out.add(
          _Block(
            _K.heading,
            i,
            i + 1,
            level: h.group(1)!.length,
            content: [content.trim()],
          ),
        );
        i++;
        continue;
      }
      if (features.rules && ruleLine.hasMatch(line)) {
        _stack.clear();
        out.add(_Block(_K.rule, i, i + 1));
        i++;
        continue;
      }

      final item = _item(i);
      if (item != null) {
        out.add(item);
        i = item.end;
        continue;
      }

      if (features.quotes && quoteLine.hasMatch(line)) {
        var j = i;
        while (j < n && quoteLine.hasMatch(lines[j])) {
          j++;
        }
        _stack.clear();
        final inner = [
          for (var k = i; k < j; k++)
            lines[k].replaceFirst(RegExp(r'^\s*>\s?'), ''),
        ];
        // Blocks inside a quote are not supported: kept literally.
        if (inner.any((l) => l.trim().isNotEmpty && startsBlock(l))) {
          out.add(_Block(_K.raw, i, j));
        } else {
          // A blank `>` line separates the quote's paragraphs.
          var s = 0;
          for (var k = 0; k <= inner.length; k++) {
            if (k == inner.length || inner[k].trim().isEmpty) {
              if (k > s) {
                out.add(
                  _Block(
                    _K.quote,
                    i + s,
                    i + k,
                    content: [for (final l in inner.sublist(s, k)) l.trim()],
                  ),
                );
              }
              s = k + 1;
            }
          }
        }
        i = j;
        continue;
      }

      // A paragraph: lines up to a blank line or a line starting a block.
      var j = i;
      final content = <String>[];
      while (j < n && !_blank(j)) {
        if (j > i && _interrupts(lines[j])) break;
        content.add(lines[j].trim());
        j++;
      }
      _stack.clear();
      out.add(_Block(_K.paragraph, i, j, content: content));
      i = j;
    }
    return out;
  }

  bool _interrupts(String line) =>
      fenceOpen.hasMatch(line) ||
      (features.headings && headingLine.hasMatch(line)) ||
      (features.rules && ruleLine.hasMatch(line)) ||
      bulletLine.hasMatch(line) ||
      orderedLine.hasMatch(line) ||
      (features.quotes && quoteLine.hasMatch(line)) ||
      tableLine.hasMatch(line) ||
      htmlLine.hasMatch(line);

  /// A list item at line [i] (with its continuation lines), or null.
  _Block? _item(int i) {
    final line = lines[i];
    final b = bulletLine.firstMatch(line);
    final o = b == null ? orderedLine.firstMatch(line) : null;
    if (b == null && o == null) return null;
    final m = (b ?? o)!;
    final indent = indentWidth(m.group(1)!);
    final marker = b != null ? 1 : m.group(2)!.length + 1;
    final spaces = (b != null ? m.group(3) : m.group(4))!.length;
    final column = indent + marker + (spaces > 4 ? 1 : spaces);
    while (_stack.isNotEmpty && indent < _stack.last) {
      _stack.removeLast();
    }
    final level = math.min(_stack.length, 8);
    _stack.add(column);
    final rest = (b != null ? m.group(4) : m.group(5))!;
    var first = rest.trim();
    var kind = b != null ? _K.bullet : _K.ordered;
    var checked = false;
    if (b != null) {
      final t = taskBox.firstMatch(rest);
      if (t != null) {
        kind = _K.task;
        checked = t.group(1) != ' ';
        first = t.group(2)!.trim();
      }
    }
    // Continuation lines: indented to the content column, no blank line
    // before, not a block of their own.
    var j = i + 1;
    final content = [first];
    while (j < lines.length &&
        !_blank(j) &&
        indentWidth(_leading(lines[j])) >= column &&
        !startsBlock(lines[j])) {
      content.add(lines[j].trim());
      j++;
    }
    // A block inside an item (`- > quote`, `- # title`) is not supported.
    if (first.isNotEmpty && startsBlock(first)) {
      return _Block(_K.raw, i, j, level: level);
    }
    return _Block(kind, i, j, level: level, checked: checked, content: content);
  }
}
