/// Inline Markdown ⇄ super_editor [AttributedText], on top of the shared
/// inline codec of `wonky_rich_text` ([InlineReader], [InlineMarkdownWriter])
/// so the syntax matches the rest of the suite.
library;

import 'package:collection/collection.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:super_editor/super_editor.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart';

import 'block_syntax.dart';

/// Reads and writes the inline content of one block.
///
/// Line breaks inside a block are `"\n"` in the node text (Shift+Enter) and
/// separate Markdown lines: the suite renders the lines of a paragraph as
/// lines (`MarkdownProfile.hardBreaks`), and every line is written on its
/// own, so a break is never a CommonMark hard-break escape.
class InlineMarkdownCodec {
  InlineMarkdownCodec({md.Document? document})
    : _document = document ?? _newDocument();

  static md.Document _newDocument() =>
      md.Document(extensionSet: wonkyGfm, encodeHtml: true);

  final md.Document _document;

  /// Allows writing `[`/`]` unescaped where that reads the same (false
  /// when the text has link reference definitions, which could turn the
  /// brackets into links).
  bool bareBrackets = true;

  // ------------------------------------------------------------------ read

  /// Parses inline [lines] (one block's content, without its markers).
  /// Lines become `"\n"` in the text.
  /// Returns null when the content holds something the editor cannot
  /// represent (images, raw HTML, links with other schemes, link titles,
  /// styles across lines …): the caller keeps the block as literal text.
  AttributedText? read(List<String> lines) {
    if (lines.isEmpty) return AttributedText();
    final warnings = <ImportWarning>[];
    // Each line is read on its own, the way it is written: styles never
    // span lines.
    final runs = <InlineRun>[];
    for (final (i, line) in lines.indexed) {
      if (i > 0) runs.add(const InlineRun('\n'));
      runs.addAll(InlineReader(warnings).readRuns(_document.parseInline(line)));
    }
    if (warnings.isNotEmpty) return null;
    final text = runsToText(
      InlineRun.merge([
        for (final r in runs)
          r.copyWith(text: r.text.replaceAll(softBreak, '\n')),
      ]),
    );
    // The rewritten content must render exactly like the original.
    final rewritten = writeLines(text);
    if (_html(lines.join('\n')) != _html(rewritten.join('\n'))) return null;
    return text;
  }

  String _html(String inline) => md.HtmlRenderer()
      .render(_document.parseInline(inline))
      .replaceAll(RegExp(r'<br />\n?'), '\n');

  // ----------------------------------------------------------------- write

  /// The Markdown lines of [text] (one per `"\n"`-separated line).
  List<String> writeLines(AttributedText text, {bool heading = false}) {
    final runs = textToRuns(text);
    final lines = <List<InlineRun>>[[]];
    for (final r in runs) {
      final parts = r.text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) lines.add([]);
        if (parts[i].isNotEmpty) lines.last.add(r.copyWith(text: parts[i]));
      }
    }
    final out = [for (final l in lines) writeLine(l, heading: heading)];
    if (out.length < 2) return out;
    // Lines are read one by one, but CommonMark (and the board) read the
    // block as a whole: an unescaped `[` or `~` on one line must not pair
    // with one on the next. When they would, nothing is unescaped.
    final joint = InlineRun.merge(
      InlineReader([]).readRuns(_document.parseInline(out.join('\\\n'))),
    );
    final expected = InlineRun.merge([
      for (final (i, l) in out.indexed) ...[
        if (i > 0) const InlineRun(softBreak),
        ..._reparse(l),
      ],
    ]);
    if (const ListEquality<InlineRun>().equals(joint, expected)) return out;
    return [
      for (final l in lines) writeLine(l, heading: heading, unescape: false),
    ];
  }

  /// One line of inline Markdown for [runs] (no `"\n"` in them). With
  /// [unescape] off, every character the writer escapes stays escaped.
  String writeLine(
    List<InlineRun> runs, {
    bool heading = false,
    bool unescape = true,
  }) {
    var normalized = _normalize(runs);
    if (normalized.isEmpty) return '';
    final context = heading ? InlineContext.heading : InlineContext.block;
    final exact = _writeExact(normalized, context);
    normalized = exact.$1;
    var out = exact.$2;
    final target = normalized;
    bool same(String s) =>
        !startsBlock(s) &&
        // `[x] ` after a bullet would make it a task.
        !taskBox.hasMatch(s) &&
        const ListEquality<InlineRun>().equals(_reparse(s), target);

    // URLs that are their own text are written bare (`https://x.y`), like
    // the bare URLs people type.
    if (normalized.any(_isAutolink)) {
      final urls = <String>[];
      final placeholders = [
        for (final r in normalized)
          if (_isAutolink(r) && urls.length < 0x1000)
            InlineRun(String.fromCharCode(0xE000 + (urls..add(r.text)).length))
          else
            r,
      ];
      var bare = InlineMarkdownWriter.write(placeholders, context: context);
      for (var i = 0; i < urls.length; i++) {
        bare = bare.replaceAll(String.fromCharCode(0xE001 + i), urls[i]);
      }
      if (same(bare)) out = bare;
    }

    // Drop the backslash escapes the line reads the same without (the
    // writer escapes `[ ] | ~ <` and friends wherever they could be syntax;
    // most of them are not). Emphasis characters and backslashes stay
    // escaped: the board's renderer reads them more loosely than CommonMark.
    var tries = unescape ? 0 : 40;
    var from = 0;
    while (tries < 40) {
      final m = _escape.allMatches(out, from).firstOrNull;
      if (m == null) break;
      tries++;
      final entity = m.group(0) == '&#96;';
      final ch = entity ? '`' : m.group(1)!;
      if (!bareBrackets && (ch == '[' || ch == ']')) {
        from = m.end;
        continue;
      }
      // A literal backtick reads better escaped than as an entity.
      final replacement = entity ? r'\`' : ch;
      final candidate = out.replaceRange(m.start, m.end, replacement);
      // `[a](b)` and `[a][b]` stay escaped even where they are no link:
      // the board's renderer reads them as links.
      final bracketSyntax =
          (ch == '[' || ch == ']') && candidate.contains(_linkish);
      if (!bracketSyntax && same(candidate)) {
        out = candidate;
        from = m.start + replacement.length;
      } else {
        from = m.end;
      }
    }
    return out;
  }

  /// Writes [runs] so that they read back as the same runs: with `*`, or
  /// `_` when the flanking rules need it; emphasis that neither can express
  /// (`*a.*b`) is dropped, starting with the runs at punctuation.
  (List<InlineRun>, String) _writeExact(
    List<InlineRun> runs,
    InlineContext context,
  ) {
    const eq = ListEquality<InlineRun>();
    var current = runs;
    for (var attempt = 0; attempt < 12; attempt++) {
      for (final style in const [
        EmphasisStyle.asterisk,
        EmphasisStyle.underscore,
      ]) {
        final out = InlineMarkdownWriter.write(
          current,
          context: context,
          style: style,
        );
        if (eq.equals(_reparse(out), current)) return (current, out);
      }
      final styled = [
        for (var i = 0; i < current.length; i++)
          if (current[i].bold || current[i].italic || current[i].strike) i,
      ];
      if (styled.isEmpty) break;
      bool edgy(int i) {
        final t = current[i].text;
        return !_wordChar.hasMatch(t[0]) ||
            !_wordChar.hasMatch(t[t.length - 1]);
      }

      final victim = styled.firstWhere(edgy, orElse: () => styled.first);
      current = InlineRun.merge([
        for (var i = 0; i < current.length; i++)
          i == victim
              ? current[i].copyWith(bold: false, italic: false, strike: false)
              : current[i],
      ]);
    }
    final plain = InlineRun.merge([
      for (final r in current)
        r.copyWith(bold: false, italic: false, strike: false),
    ]);
    return (plain, InlineMarkdownWriter.write(plain, context: context));
  }

  static final _linkish = RegExp(r'\](\(|\[)');

  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

  static final _escape = RegExp(r'\\([!-)+-/:-@\[\]^{-~])|&#96;');

  List<InlineRun> _reparse(String line) =>
      InlineRun.merge(InlineReader([]).readRuns(_document.parseInline(line)));

  static bool _isAutolink(InlineRun r) {
    final link = r.link;
    return link != null &&
        !r.code &&
        !r.bold &&
        !r.italic &&
        !r.strike &&
        r.text == link &&
        (link.startsWith('https://') || link.startsWith('http://'));
  }

  /// Merged runs as the reader produces them: inline code carries no other
  /// style, links are canonical (or dropped), and the line is trimmed.
  static List<InlineRun> _normalize(List<InlineRun> runs) {
    final out = <InlineRun>[
      for (final r in runs)
        InlineRun(
          r.text.replaceAll(softBreak, ' '),
          bold: r.bold && !r.code,
          italic: r.italic && !r.code,
          strike: r.strike && !r.code,
          code: r.code,
          link: r.link == null ? null : normalizeLinkTarget(r.link!),
        ),
    ];
    // Spaces at the edges of emphasis are written outside it (`**a** b`,
    // never `**a **b`, which is not emphasis).
    final split = <InlineRun>[];
    for (final r in out) {
      if (r.code || !(r.bold || r.italic || r.strike) || r.text.isEmpty) {
        split.add(r);
        continue;
      }
      final core = r.text.trim();
      if (core.isEmpty) {
        split.add(r.copyWith(bold: false, italic: false, strike: false));
        continue;
      }
      final start = r.text.indexOf(core);
      final lead = r.text.substring(0, start);
      final trail = r.text.substring(start + core.length);
      final bare = r.copyWith(bold: false, italic: false, strike: false);
      if (lead.isNotEmpty) split.add(bare.copyWith(text: lead));
      split.add(r.copyWith(text: core));
      if (trail.isNotEmpty) split.add(bare.copyWith(text: trail));
    }
    var merged = InlineRun.merge(split);
    // Leading and trailing spaces of a line are not Markdown content.
    while (merged.isNotEmpty && !merged.first.code) {
      final t = merged.first.text.trimLeft();
      if (t.isNotEmpty) {
        merged[0] = merged.first.copyWith(text: t);
        break;
      }
      merged = merged.sublist(1);
    }
    while (merged.isNotEmpty && !merged.last.code) {
      final t = merged.last.text.trimRight();
      if (t.isNotEmpty) {
        merged[merged.length - 1] = merged.last.copyWith(text: t);
        break;
      }
      merged = merged.sublist(0, merged.length - 1);
    }
    return merged;
  }

  // ------------------------------------------------- runs ⇄ attributed text

  /// The runs of [text] (bold, italic, strikethrough, code and links; other
  /// attributions are not Markdown and are dropped).
  static List<InlineRun> textToRuns(AttributedText text) {
    final plain = text.toPlainText();
    if (plain.isEmpty) return const [];
    final runs = <InlineRun>[];
    for (final span in text.computeAttributionSpans()) {
      final a = span.attributions;
      final link = a.whereType<LinkAttribution>().firstOrNull;
      runs.add(
        InlineRun(
          plain.substring(span.start, span.end + 1),
          bold: a.contains(boldAttribution),
          italic: a.contains(italicsAttribution),
          strike: a.contains(strikethroughAttribution),
          code: a.contains(codeAttribution),
          link: link?.plainTextUri,
        ),
      );
    }
    return InlineRun.merge(runs);
  }

  /// [runs] as attributed text.
  static AttributedText runsToText(List<InlineRun> runs) {
    final text = AttributedText(runs.map((r) => r.text).join());
    var at = 0;
    for (final r in runs) {
      final end = at + r.text.length;
      if (r.text.isNotEmpty) {
        final range = SpanRange(at, end - 1);
        if (r.bold) text.addAttribution(boldAttribution, range);
        if (r.italic) text.addAttribution(italicsAttribution, range);
        if (r.strike) text.addAttribution(strikethroughAttribution, range);
        if (r.code) text.addAttribution(codeAttribution, range);
        if (r.link != null) {
          text.addAttribution(LinkAttribution(r.link!), range);
        }
      }
      at = end;
    }
    return text;
  }
}

/// The link target the codec writes for [url]: a scheme is added when
/// missing (`example.com` → `https://example.com`, `a@b.c` →
/// `mailto:a@b.c`) and the URL is made canonical ([LinkPolicy]); null when
/// it cannot be a link (`javascript:`, relative URLs …).
String? normalizeLinkTarget(String url) {
  final t = url.trim();
  if (t.isEmpty) return null;
  var withScheme = t;
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*:').hasMatch(t)) {
    withScheme = RegExp(r'^[^\s@/]+@[^\s@/]+\.[^\s@/]+$').hasMatch(t)
        ? 'mailto:$t'
        : 'https://$t';
  }
  return LinkPolicy.normalizeLink(withScheme);
}

/// Whether [url] may be opened from the board: http(s) with a host, or
/// mailto (the rule of the shell's link dialog and renderer).
bool isSafeLink(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if ((scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty) {
    return true;
  }
  return scheme == 'mailto' && uri.path.isNotEmpty;
}
