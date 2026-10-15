/// The block parser of `WonkyMarkdown` (specs/16 §7.3): a small, forgiving
/// line-based Markdown parser that also renders partial (streamed) input.
library;

/// The kind of a parsed block.
enum MdKind { heading, paragraph, listItem, quote, code, table, rule }

/// A parsed block.
class MdBlock {
  MdBlock(
    this.kind,
    this.text, {
    this.level = 0,
    this.marker = '',
    this.info = '',
    this.rows = const [],
    String? source,
  }) : source = source ?? text;

  final MdKind kind;

  /// The block's content: inline Markdown (headings, paragraphs, list items,
  /// quotes), the code (code blocks) or the aligned table text (tables).
  final String text;

  /// Heading level or list nesting.
  final int level;

  /// List marker ("•", "1.", "☐").
  final String marker;

  /// The info string of a fenced code block (`dart` in ```` ```dart ````).
  final String info;

  /// The cells of a table (header row first, without the delimiter row).
  final List<List<String>> rows;

  /// The block's source lines, joined with `\n` (a profile that does not
  /// allow the block kind renders it as text).
  final String source;
}

/// A small block parser (assistant replies, board posts and comments).
abstract final class MarkdownBlocks {
  static final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _bullet = RegExp(r'^(\s*)[-*+]\s+(\[( |x|X)\]\s+)?(.*)$');
  static final _ordered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
  static final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');
  static final _delimiterCell = RegExp(r'^:?-{2,}:?$');

  /// Parses [text]. With [hardBreaks], the lines of a paragraph or quote
  /// stay separate lines (joined with `\n`, like GitHub comments); without,
  /// they are joined with a space (CommonMark soft breaks).
  static List<MdBlock> parse(String text, {bool hardBreaks = false}) {
    final out = <MdBlock>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final para = <String>[];
    final paraSource = <String>[];
    final joiner = hardBreaks ? '\n' : ' ';
    void flushPara() {
      if (para.isEmpty) return;
      out.add(
        MdBlock(
          MdKind.paragraph,
          para.join(joiner).trim(),
          source: paraSource.join('\n'),
        ),
      );
      para.clear();
      paraSource.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```')) {
        flushPara();
        final info = trimmed.substring(3).trim();
        final code = <String>[];
        final src = <String>[line];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i]);
          src.add(lines[i]);
          i++;
        }
        if (i < lines.length) src.add(lines[i]);
        i++; // closing fence (or end of a streaming block)
        out.add(
          MdBlock(
            MdKind.code,
            code.join('\n'),
            info: info,
            source: src.join('\n'),
          ),
        );
        continue;
      }
      if (trimmed.isEmpty) {
        flushPara();
        i++;
        continue;
      }
      final h = _heading.firstMatch(trimmed);
      if (h != null) {
        flushPara();
        out.add(
          MdBlock(
            MdKind.heading,
            h.group(2)!,
            level: h.group(1)!.length,
            source: line,
          ),
        );
        i++;
        continue;
      }
      if (_rule.hasMatch(trimmed)) {
        flushPara();
        out.add(MdBlock(MdKind.rule, '', source: line));
        i++;
        continue;
      }
      final b = _bullet.firstMatch(line);
      if (b != null) {
        flushPara();
        final task = b.group(3);
        out.add(
          MdBlock(
            MdKind.listItem,
            b.group(4)!,
            level: b.group(1)!.length ~/ 2,
            marker: task == null ? '•' : (task == ' ' ? '☐' : '☑'),
            source: line,
          ),
        );
        i++;
        continue;
      }
      final o = _ordered.firstMatch(line);
      if (o != null) {
        flushPara();
        out.add(
          MdBlock(
            MdKind.listItem,
            o.group(3)!,
            level: o.group(1)!.length ~/ 2,
            marker: '${o.group(2)}.',
            source: line,
          ),
        );
        i++;
        continue;
      }
      if (trimmed.startsWith('>')) {
        flushPara();
        final q = <String>[];
        final src = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          src.add(lines[i]);
          q.add(lines[i].trimLeft().substring(1).trim());
          i++;
        }
        out.add(MdBlock(MdKind.quote, q.join(joiner), source: src.join('\n')));
        continue;
      }
      if (trimmed.startsWith('|')) {
        flushPara();
        final rows = <List<String>>[];
        final src = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          src.add(lines[i]);
          final cells = lines[i]
              .trim()
              .replaceAll(RegExp(r'^\||\|$'), '')
              .split('|')
              .map((c) => c.trim())
              .toList();
          if (!cells.every(_delimiterCell.hasMatch)) {
            rows.add(cells);
          }
          i++;
        }
        final widths = <int>[];
        for (final r in rows) {
          for (var c = 0; c < r.length; c++) {
            if (widths.length <= c) widths.add(0);
            if (r[c].length > widths[c]) widths[c] = r[c].length;
          }
        }
        out.add(
          MdBlock(
            MdKind.table,
            [
              for (final r in rows)
                [
                  for (var c = 0; c < r.length; c++) r[c].padRight(widths[c]),
                ].join('  '),
            ].join('\n'),
            rows: rows,
            source: src.join('\n'),
          ),
        );
        continue;
      }
      para.add(trimmed);
      paraSource.add(line);
      i++;
    }
    flushPara();
    return out;
  }
}
