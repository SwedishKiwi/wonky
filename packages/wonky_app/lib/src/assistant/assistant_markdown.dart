import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// Renders assistant Markdown (streamed, so partial input must render):
/// headings, paragraphs, lists, quotes, fenced code with a copy button,
/// rules, tables (as aligned text) and inline bold / italic / strike /
/// code / links. Links are styled but not opened (single window).
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown(this.text, {super.key, this.onCopyCode});

  final String text;

  /// Copies a code block (defaults to the clipboard).
  final void Function(String code)? onCopyCode;

  @override
  Widget build(BuildContext context) {
    final blocks = MarkdownBlocks.parse(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [for (final b in blocks) _block(context, b)],
    );
  }

  Widget _block(BuildContext context, MdBlock b) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final base = theme.textTheme.small.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.45,
    );
    switch (b.kind) {
      case MdKind.heading:
        final size = switch (b.level) {
          1 => 17.0,
          2 => 15.5,
          _ => 14.0,
        };
        return Text.rich(
          inlineSpans(
            b.text,
            base.copyWith(fontSize: size, fontWeight: FontWeight.w600),
            cs,
          ),
        );
      case MdKind.paragraph:
        return Text.rich(inlineSpans(b.text, base, cs));
      case MdKind.listItem:
        return Padding(
          padding: EdgeInsets.only(left: 4.0 + 14.0 * b.level),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: b.marker.length > 2 ? 26 : 16,
                child: Text(
                  b.marker,
                  style: base.copyWith(color: cs.mutedForeground),
                ),
              ),
              Expanded(child: Text.rich(inlineSpans(b.text, base, cs))),
            ],
          ),
        );
      case MdKind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: cs.border, width: 3)),
          ),
          child: Text.rich(
            inlineSpans(b.text, base.copyWith(color: cs.mutedForeground), cs),
          ),
        );
      case MdKind.code:
      case MdKind.table:
        final mono = base.copyWith(fontFamily: 'JetBrains Mono', fontSize: 12);
        return Container(
          decoration: BoxDecoration(
            color: cs.muted,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 8, 34, 8),
                child: Text(b.text, style: mono),
              ),
              if (b.kind == MdKind.code)
                Positioned(
                  top: 2,
                  right: 2,
                  child: ShadIconButton.ghost(
                    key: const ValueKey<String>('assistant.code.copy'),
                    width: 26,
                    height: 26,
                    iconSize: 13,
                    semanticLabel: 'Copy code',
                    icon: const Icon(LucideIcons.copy),
                    onPressed: () {
                      final copy = onCopyCode;
                      if (copy != null) {
                        copy(b.text);
                      } else {
                        Clipboard.setData(ClipboardData(text: b.text));
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      case MdKind.rule:
        return Container(height: 1, color: cs.border);
    }
  }

  static final _inline = RegExp(
    r'(\*\*([^*]+)\*\*)|(__([^_]+)__)|(~~([^~]+)~~)|(`([^`]+)`)|(\[([^\]]+)\]\(([^)\s]+)\))|(\*([^*\s][^*]*)\*)|(_([^_\s][^_]*)_)',
  );

  /// Inline Markdown as spans.
  static TextSpan inlineSpans(String text, TextStyle base, ShadColorScheme cs) {
    final children = <InlineSpan>[];
    var i = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > i) children.add(TextSpan(text: text.substring(i, m.start)));
      if (m.group(2) != null || m.group(4) != null) {
        children.add(
          TextSpan(
            text: m.group(2) ?? m.group(4),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (m.group(6) != null) {
        children.add(
          TextSpan(
            text: m.group(6),
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
        );
      } else if (m.group(8) != null) {
        children.add(
          TextSpan(
            text: m.group(8),
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: (base.fontSize ?? 14) - 1,
              backgroundColor: cs.muted,
            ),
          ),
        );
      } else if (m.group(10) != null) {
        children.add(
          TextSpan(
            text: m.group(10),
            style: TextStyle(
              color: cs.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else {
        children.add(
          TextSpan(
            text: m.group(13) ?? m.group(15),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      i = m.end;
    }
    if (i < text.length) children.add(TextSpan(text: text.substring(i)));
    return TextSpan(
      style: base.copyWith(color: base.color ?? cs.foreground),
      children: children,
    );
  }
}

enum MdKind { heading, paragraph, listItem, quote, code, table, rule }

/// A parsed block.
class MdBlock {
  MdBlock(this.kind, this.text, {this.level = 0, this.marker = ''});
  final MdKind kind;
  final String text;

  /// Heading level or list nesting.
  final int level;

  /// List marker ("•", "1.", "☐").
  final String marker;
}

/// A small block parser for assistant replies.
abstract final class MarkdownBlocks {
  static final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
  static final _bullet = RegExp(r'^(\s*)[-*+]\s+(\[( |x|X)\]\s+)?(.*)$');
  static final _ordered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
  static final _rule = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');

  static List<MdBlock> parse(String text) {
    final out = <MdBlock>[];
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final para = <String>[];
    void flushPara() {
      if (para.isEmpty) return;
      out.add(MdBlock(MdKind.paragraph, para.join(' ').trim()));
      para.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```')) {
        flushPara();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        i++; // closing fence (or end of a streaming block)
        out.add(MdBlock(MdKind.code, code.join('\n')));
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
          MdBlock(MdKind.heading, h.group(2)!, level: h.group(1)!.length),
        );
        i++;
        continue;
      }
      if (_rule.hasMatch(trimmed)) {
        flushPara();
        out.add(MdBlock(MdKind.rule, ''));
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
          ),
        );
        i++;
        continue;
      }
      if (trimmed.startsWith('>')) {
        flushPara();
        final q = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          q.add(lines[i].trimLeft().substring(1).trim());
          i++;
        }
        out.add(MdBlock(MdKind.quote, q.join(' ')));
        continue;
      }
      if (trimmed.startsWith('|')) {
        flushPara();
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          final cells = lines[i]
              .trim()
              .replaceAll(RegExp(r'^\||\|$'), '')
              .split('|')
              .map((c) => c.trim())
              .toList();
          if (!cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c))) {
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
          ),
        );
        continue;
      }
      para.add(trimmed);
      i++;
    }
    flushPara();
    return out;
  }
}
