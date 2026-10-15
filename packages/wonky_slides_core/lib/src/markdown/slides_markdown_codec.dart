import 'dart:convert';

import 'package:wonky_rich_text/wonky_rich_text.dart';

import '../model/text/slides_text.dart';

/// Warning codes of the Markdown codecs (Slides 11 §2.2).
abstract final class SlidesMarkdownWarnings {
  /// Markdown without a Slides text form (images, tables, code fences,
  /// HTML) was dropped or mapped.
  static const flattened = 'markdown_flattened';

  /// A `slide:` link names no slide of the deck (the link is dropped).
  static const slideLink = 'slide_link_unresolved';
}

/// Markdown converted to a Slides text body (02 §4.1).
final class SlidesMarkdownResult {
  const SlidesMarkdownResult(this.deltaJson, this.warnings);

  /// The normalized Delta JSON of the body (`[{"insert": "…\n"}]`).
  final String deltaJson;

  /// Warning codes ([SlidesMarkdownWarnings]), each at most once.
  final List<String> warnings;
}

/// Text bodies as Markdown (Slides 11 §3.2): the MCP `TextInput` and
/// `text_format: markdown` of reads, the deck outline and AI.
///
/// Block rules (a slide-friendly subset of CommonMark): **every line is a
/// paragraph** (no lazy continuation; blank lines only separate), a line
/// ending in `\` or two spaces continues the paragraph after a soft break
/// (U+2028); `- `/`* `/`+ ` bullets, `1. ` numbers (`listStart` from the
/// first number), `- [ ] `/`- [x] ` checklists, nesting by 2 spaces or a
/// tab (max 8); `#`/`##`/`###` → paragraph style `title`/`heading`/
/// `subtitle`; `> ` → `quote`. Inline: `**bold**`, `*italic*`,
/// `~~strike~~`, `` `code` ``, `[text](https://…)`, `mailto:` and
/// `[text](slide:3)` / `slide:<id>` (resolved by the caller). Images, code
/// fences, tables and HTML are dropped with `markdown_flattened`.
///
/// Writing maps back; attributes without a Markdown form (font, size,
/// color, alignment, underline, …) are omitted — [toRich] keeps them.
abstract final class SlidesMarkdownCodec {
  static final _listItem = RegExp(r'^([-*+])\s+(.*)$');
  static final _task = RegExp(r'^\[([ xX])\]\s+(.*)$');
  static final _ordered = RegExp(r'^(\d{1,9})[.)]\s+(.*)$');
  static final _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');
  static final _quote = RegExp(r'^>\s?(.*)$');
  static final _fence = RegExp(r'^\s*(```|~~~)');
  static final _tableRow = RegExp(r'^\s*\|.*\|\s*$');
  static final _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
  static final _slideLinkIn = RegExp(r'\]\(\s*slide:([^)\s]+)\s*\)');

  /// The link prefix slide links use inside the inline codec.
  static const _slideScheme = 'wonky://slide/';

  /// Converts [markdown] to a body. [notes] uses the speaker-notes schema.
  /// [slideLink] maps a `slide:` target (`3`, a uuid or a base-62 id) to the
  /// stored `slide:<b62>` value (null = unresolved: the link is dropped).
  static SlidesMarkdownResult toDelta(
    String markdown, {
    bool notes = false,
    String? Function(String target)? slideLink,
  }) {
    final warnings = <String>{};
    final paragraphs = _parseBlocks(markdown, warnings);
    final delta = Delta();
    for (final p in paragraphs) {
      for (final r in p.runs) {
        if (r.text.isEmpty) continue;
        var attrs = r.toAttributes();
        final link = r.link;
        if (link != null && link.startsWith(_slideScheme)) {
          final target = Uri.decodeComponent(
            link.substring(_slideScheme.length),
          );
          final resolved = slideLink?.call(target);
          attrs = {...?attrs}..remove('link');
          if (resolved == null) {
            warnings.add(SlidesMarkdownWarnings.slideLink);
          } else {
            attrs['link'] = resolved;
          }
          if (attrs.isEmpty) attrs = null;
        }
        attrs?.remove('mention');
        delta.insert(r.text, attrs == null || attrs.isEmpty ? null : attrs);
      }
      delta.insert('\n', p.block.isEmpty ? null : p.block);
    }
    if (delta.isEmpty) delta.insert('\n');
    final normalized = SlidesText.normalize(delta, notes: notes);
    return SlidesMarkdownResult(
      SlidesText.encode(normalized),
      warnings.toList(),
    );
  }

  /// The Markdown of the body [deltaJson] (null/empty = ""). [slideLink]
  /// maps a stored `slide:<b62>` link to the target written after
  /// `slide:` (default: the base-62 id).
  static String toMarkdown(
    String? deltaJson, {
    String Function(String b62)? slideLink,
  }) {
    final paras = paragraphsOf(deltaJson);
    final out = <String>[];
    final counters = <int, int>{};
    for (final p in paras) {
      final block = p.block;
      final indent = (block['indent'] as num?)?.toInt() ?? 0;
      final list = block['list'];
      final style = block['style'];
      final runs = [
        for (final r in p.runs)
          InlineRun.fromAttributes(r.text, _inlineFor(r.attrs, slideLink)),
      ];
      if (list != 'ordered') {
        counters.removeWhere((k, _) => k >= indent);
      } else {
        counters.removeWhere((k, _) => k > indent);
      }
      final pad = '  ' * indent;
      String prefix;
      var context = InlineContext.block;
      switch (list) {
        case 'bullet':
          prefix = '$pad- ';
        case 'check':
          prefix = '$pad- [x] ';
        case 'unchecked':
          prefix = '$pad- [ ] ';
        case 'ordered':
          final start = (block['listStart'] as num?)?.toInt();
          final n = start ?? ((counters[indent] ?? 0) + 1);
          counters[indent] = n;
          prefix = '$pad$n. ';
        default:
          switch (style) {
            case 'title':
              prefix = '# ';
              context = InlineContext.heading;
            case 'heading':
              prefix = '## ';
              context = InlineContext.heading;
            case 'subtitle':
              prefix = '### ';
              context = InlineContext.heading;
            case 'quote':
              prefix = '> ';
            default:
              prefix = '';
          }
      }
      out.add('$prefix${_writeRuns(runs, context)}');
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.join('\n').replaceAll('](wonky://slide/', '](slide:');
  }

  /// `text_format: "rich"` (11 §3.2): the Markdown plus every run's and
  /// paragraph's attributes over the plain text (offsets in UTF-16 code
  /// units, paragraphs by 0-based index).
  static Map<String, Object?> toRich(
    String? deltaJson, {
    String Function(String b62)? slideLink,
  }) {
    final runs = <Map<String, Object?>>[];
    final paragraphs = <Map<String, Object?>>[];
    var offset = 0;
    for (final (i, p) in paragraphsOf(deltaJson).indexed) {
      for (final r in p.runs) {
        if (r.attrs.isNotEmpty) {
          runs.add({
            'start': offset,
            'length': r.text.length,
            'attrs': r.attrs,
          });
        }
        offset += r.text.length;
      }
      offset += 1; // "\n"
      if (p.block.isNotEmpty) paragraphs.add({'index': i, 'attrs': p.block});
    }
    return {
      'markdown': toMarkdown(deltaJson, slideLink: slideLink),
      'delta': deltaJson == null ? const [] : jsonDecode(deltaJson),
      'runs': runs,
      'paragraphs': paragraphs,
    };
  }

  /// The plain text of a body without the final line break.
  static String toPlain(String? deltaJson) {
    final t = SlidesText.plainText(deltaJson);
    return t.endsWith('\n') ? t.substring(0, t.length - 1) : t;
  }

  /// Keeps the formatting of [oldJson] on the new body [newJson]
  /// (`keep_formatting`, 11 §3.8): the first run's attributes without a
  /// Markdown form (font, size, color, …) go to every run that lacks them,
  /// and each paragraph keeps the block attributes of the old paragraph at
  /// its position (the last old paragraph for extra ones) that Markdown
  /// can't express (alignment, spacing, list style, …).
  static String keepFormatting(
    String? oldJson,
    String newJson, {
    bool notes = false,
  }) {
    if (oldJson == null) return newJson;
    final old = paragraphsOf(oldJson);
    if (old.isEmpty) return newJson;
    Map<String, Object?> firstRun = const {};
    for (final p in old) {
      if (p.runs.isNotEmpty) {
        firstRun = {
          for (final e in p.runs.first.attrs.entries)
            if (!_markdownInline.contains(e.key)) e.key: e.value,
        };
        break;
      }
    }
    final next = paragraphsOf(newJson);
    final delta = Delta();
    for (final (i, p) in next.indexed) {
      for (final r in p.runs) {
        final attrs = {...firstRun, ...r.attrs};
        delta.insert(r.text, attrs.isEmpty ? null : attrs);
      }
      final source = old[i < old.length ? i : old.length - 1].block;
      final block = {
        for (final e in source.entries)
          if (!_markdownBlock.contains(e.key)) e.key: e.value,
        ...p.block,
      };
      delta.insert('\n', block.isEmpty ? null : block);
    }
    if (delta.isEmpty) delta.insert('\n');
    return SlidesText.encode(SlidesText.normalize(delta, notes: notes));
  }

  /// Appends ([prepend] false) or prepends the paragraphs of [addJson] to
  /// [baseJson] (an empty base body is replaced).
  static String concat(
    String? baseJson,
    String addJson, {
    bool prepend = false,
    bool notes = false,
  }) {
    if (baseJson == null || SlidesText.isBlank(baseJson)) return addJson;
    final a = SlidesText.parse(prepend ? addJson : baseJson);
    final b = SlidesText.parse(prepend ? baseJson : addJson);
    final d = Delta();
    for (final op in [...a.operations, ...b.operations]) {
      d.push(op);
    }
    return SlidesText.encode(SlidesText.normalize(d, notes: notes));
  }

  // ------------------------------------------------------------- reading

  static const _markdownInline = {'bold', 'italic', 'strike', 'code', 'link'};
  static const _markdownBlock = {'list', 'indent', 'style', 'listStart'};

  static List<_Para> _parseBlocks(String markdown, Set<String> warnings) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final out = <_Para>[];
    var inFence = false;
    var prevOrderedIndent = -1;
    var i = 0;
    while (i < lines.length) {
      var line = lines[i];
      i++;
      if (_fence.hasMatch(line)) {
        inFence = !inFence;
        warnings.add(SlidesMarkdownWarnings.flattened);
        continue;
      }
      if (inFence) continue;
      if (line.trim().isEmpty) continue;
      if (_tableRow.hasMatch(line)) {
        warnings.add(SlidesMarkdownWarnings.flattened);
        continue;
      }
      // Indentation (2 spaces or a tab per level).
      var spaces = 0;
      var k = 0;
      while (k < line.length && (line[k] == ' ' || line[k] == '\t')) {
        spaces += line[k] == '\t' ? 2 : 1;
        k++;
      }
      line = line.substring(k);
      final block = <String, Object?>{};
      var text = line;
      final indent = (spaces ~/ 2).clamp(0, 8);
      final item = _listItem.firstMatch(line);
      final ordered = _ordered.firstMatch(line);
      if (item != null) {
        text = item.group(2)!;
        final task = _task.firstMatch(text);
        if (task != null) {
          block['list'] = task.group(1) == ' ' ? 'unchecked' : 'check';
          text = task.group(2)!;
        } else {
          block['list'] = 'bullet';
        }
        if (indent > 0) block['indent'] = indent;
        prevOrderedIndent = -1;
      } else if (ordered != null) {
        block['list'] = 'ordered';
        final n = int.parse(ordered.group(1)!);
        if (prevOrderedIndent != indent && n != 1) block['listStart'] = n;
        text = ordered.group(2)!;
        if (indent > 0) block['indent'] = indent;
        prevOrderedIndent = indent;
      } else {
        prevOrderedIndent = -1;
        final h = _heading.firstMatch(line);
        final q = _quote.firstMatch(line);
        if (h != null) {
          final level = h.group(1)!.length;
          block['style'] = switch (level) {
            1 => 'title',
            2 => 'heading',
            _ => 'subtitle',
          };
          if (level > 3) warnings.add(SlidesMarkdownWarnings.flattened);
          text = h.group(2)!;
        } else if (q != null) {
          block['style'] = 'quote';
          text = q.group(1)!;
        }
      }
      // Soft breaks: a line ending in `\` (odd count) or two spaces.
      final segments = <String>[];
      var seg = text;
      while (true) {
        final cont = _continues(seg);
        if (cont == null) {
          segments.add(seg);
          break;
        }
        segments.add(cont);
        if (i >= lines.length || lines[i].trim().isEmpty) break;
        seg = lines[i].trimLeft();
        i++;
      }
      final runs = <InlineRun>[];
      for (final (n, s) in segments.indexed) {
        if (n > 0) runs.add(const InlineRun(' '));
        runs.addAll(_inline(s, warnings));
      }
      out.add(_Para(runs, block));
    }
    return out;
  }

  /// The line without its hard-break marker, or null when it has none.
  static String? _continues(String line) {
    if (line.endsWith('  ') && line.trim().isNotEmpty) return line.trimRight();
    var n = 0;
    while (n < line.length && line[line.length - 1 - n] == r'\') {
      n++;
    }
    if (n.isOdd) return line.substring(0, line.length - 1);
    return null;
  }

  static List<InlineRun> _inline(String text, Set<String> warnings) {
    var source = text;
    if (_image.hasMatch(source)) {
      warnings.add(SlidesMarkdownWarnings.flattened);
      source = source.replaceAll(_image, '');
    }
    source = source.replaceAllMapped(
      _slideLinkIn,
      (m) => ']($_slideScheme${Uri.encodeComponent(m.group(1)!)})',
    );
    final w = <ImportWarning>[];
    final runs = InlineMarkdown.parse(source, warnings: w);
    if (w.isNotEmpty) warnings.add(SlidesMarkdownWarnings.flattened);
    return runs;
  }

  // ------------------------------------------------------------- writing

  static Map<String, dynamic>? _inlineFor(
    Map<String, Object?> attrs,
    String Function(String b62)? slideLink,
  ) {
    if (attrs.isEmpty) return null;
    final link = attrs['link'];
    if (link is String && link.startsWith('slide:')) {
      final b62 = link.substring(6);
      return {...attrs, 'link': '$_slideScheme${slideLink?.call(b62) ?? b62}'};
    }
    return attrs;
  }

  static String _writeRuns(List<InlineRun> runs, InlineContext context) {
    // Soft breaks are written as `\` + newline (one paragraph).
    final lines = <List<InlineRun>>[[]];
    for (final r in runs) {
      final parts = r.text.split(' ');
      for (final (i, p) in parts.indexed) {
        if (i > 0) lines.add([]);
        if (p.isNotEmpty) lines.last.add(r.copyWith(text: p));
      }
    }
    return [
      for (final l in lines)
        l.isEmpty
            ? ''
            : InlineMarkdownWriter.write(
                l,
                context: context == InlineContext.heading
                    ? InlineContext.heading
                    : InlineContext.block,
              ).replaceAll('\n', ' '),
    ].join('\\\n');
  }

  /// The paragraphs of a body: runs (text + inline attributes) and block
  /// attributes.
  static List<SlidesParagraph> paragraphsOf(String? deltaJson) {
    if (deltaJson == null || deltaJson.isEmpty) return const [];
    final Delta doc;
    try {
      doc = SlidesText.parse(deltaJson);
    } on FormatException {
      return const [];
    }
    final out = <SlidesParagraph>[];
    var runs = <SlidesRun>[];
    for (final op in doc.operations) {
      final data = op.data;
      if (!op.isInsert || data is! String) continue;
      final all = <String, Object?>{...?op.attributes};
      final inline = {
        for (final e in all.entries)
          if (!SlidesText.isBlockAttribute(e.key)) e.key: e.value,
      };
      final block = {
        for (final e in all.entries)
          if (SlidesText.isBlockAttribute(e.key)) e.key: e.value,
      };
      final parts = data.split('\n');
      for (final (i, part) in parts.indexed) {
        if (part.isNotEmpty) runs.add(SlidesRun(part, inline));
        if (i < parts.length - 1) {
          out.add(SlidesParagraph(runs, block));
          runs = [];
        }
      }
    }
    if (runs.isNotEmpty) out.add(SlidesParagraph(runs, const {}));
    return out;
  }
}

/// A run of a body paragraph.
final class SlidesRun {
  const SlidesRun(this.text, this.attrs);

  final String text;
  final Map<String, Object?> attrs;
}

/// A paragraph of a body ([SlidesMarkdownCodec.paragraphsOf]).
final class SlidesParagraph {
  const SlidesParagraph(this.runs, this.block);

  final List<SlidesRun> runs;

  /// Block attributes (on the paragraph's `"\n"`).
  final Map<String, Object?> block;

  /// The paragraph's text.
  String get text => runs.map((r) => r.text).join();
}

final class _Para {
  _Para(this.runs, this.block);

  final List<InlineRun> runs;
  final Map<String, Object?> block;
}
