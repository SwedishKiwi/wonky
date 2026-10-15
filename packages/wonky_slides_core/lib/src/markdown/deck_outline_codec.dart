import 'dart:convert';

import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../charts/chart_element_data.dart';
import '../model/api/deck_model.dart';
import '../model/api/kinds.dart';
import '../model/api/records.dart';
import '../model/text/slides_text.dart';
import '../theme/layout/placeholder_type.dart';
import 'slides_markdown_codec.dart';

/// A fenced code block of an outline slide.
final class OutlineCode {
  const OutlineCode(this.language, this.code);

  /// The fence's info string (empty = plain text).
  final String language;
  final String code;
}

/// An image of an outline slide (`![alt](wonky-file://<uuid>)`).
final class OutlineImage {
  const OutlineImage(this.fileUuid, this.alt);

  final String fileUuid;
  final String alt;
}

/// One slide of a deck outline (Slides 11 §3.3).
final class OutlineSlide {
  OutlineSlide();

  /// `<!-- layout: key -->` (null = chosen by [inferLayout]).
  String? layout;

  /// `<!-- group: Title color=blue -->` starts a new group with this
  /// slide; [groupNone] (`group: none`) ends grouping.
  String? groupTitle;
  String? groupColor;
  bool groupNone = false;

  /// `<!-- skip -->`.
  bool skipped = false;

  /// `<!-- transition: fade -->` (a transition type id).
  String? transition;

  /// The first heading (`#` or `##`), as inline Markdown.
  String? title;

  /// The heading level of [title] (1 or 2).
  int titleLevel = 2;

  /// Body columns (`|||` separates two); each a Markdown body.
  final List<List<String>> columns = [[]];

  /// Speaker notes Markdown (after `Notes:` or `???`).
  String? notes;

  /// Fenced code blocks.
  final List<OutlineCode> code = [];

  /// GFM tables (rows of inline-Markdown cells; the first row is the
  /// header).
  final List<List<List<String>>> tables = [];

  /// Images.
  final List<OutlineImage> images = [];

  /// The body Markdown of column [i] (trimmed lines joined).
  String body([int i = 0]) =>
      i < columns.length ? columns[i].join('\n').trim() : '';

  /// Whether the slide has body text.
  bool get hasBody => columns.any((c) => c.any((l) => l.trim().isNotEmpty));

  static final _bigNumber = RegExp(
    r'^[\s$€£¥+\-~≈]*\d[\d.,\s]*\s*(%|x|×|k|K|M|B|bn|m)?\s*$',
  );

  /// The layout key for this slide when none is given (11 §3.3):
  /// title-only → `title` (first slide or `#`) / `section`; two columns →
  /// `twoColumns`; a lone big number → `bigNumber`; a lone quote →
  /// `quote`; code → `code`; images → `imageRight` (`imageFull` without a
  /// title); otherwise `titleBody` (`titleOnly` with a table).
  String inferLayout({bool first = false}) {
    if (layout != null) return layout!;
    final lines = [
      for (final l in columns.first)
        if (l.trim().isNotEmpty) l.trim(),
    ];
    if (code.isNotEmpty) return 'code';
    if (images.isNotEmpty && !hasBody) {
      return title == null ? 'imageFull' : 'imageRight';
    }
    if (columns.length > 1) return 'twoColumns';
    if (tables.isNotEmpty) return 'titleOnly';
    if (!hasBody) {
      if (title == null) return 'blank';
      return first || titleLevel == 1 ? 'title' : 'section';
    }
    if (lines.length <= 2 && _bigNumber.hasMatch(lines.first)) {
      return 'bigNumber';
    }
    if (lines.first.startsWith('>') &&
        lines.every((l) => l.startsWith('>') || l.startsWith('—'))) {
      return 'quote';
    }
    return 'titleBody';
  }
}

/// A parsed deck outline.
final class DeckOutline {
  DeckOutline(this.slides, {this.title});

  /// `<!-- deck: title="…" -->`.
  final String? title;
  final List<OutlineSlide> slides;
}

/// The deck outline Markdown of Slides 11 §3.3: slides separated by `---`
/// lines, the first `#`/`##` heading is the title, the rest the body,
/// `Notes:` (or `???`) starts the speaker notes, HTML-comment directives
/// (`layout:`, `group:` (`group: none`), `skip`, `transition:`, `deck:
/// title="…"`), fenced code → code blocks, GFM tables → tables,
/// `![alt](wonky-file://<uuid>)` → images, `|||` → a second column.
///
/// [write] produces the same format from a deck (titles, bodies, notes,
/// code, tables; charts as `<!-- chart: … -->` comments) for the
/// `wonky://deck/<uuid>` resource and `drive.export` `md`.
abstract final class DeckOutlineCodec {
  static final _directive = RegExp(
    r'^\s*<!--\s*([a-zA-Z]+)\s*:?\s*(.*?)\s*-->\s*$',
  );
  static final _separator = RegExp(r'^\s*---+\s*$');
  static final _fenceOpen = RegExp(r'^\s*(```+|~~~+)\s*([^`\s]*)');
  static final _heading = RegExp(r'^(#{1,2})\s+(.*?)\s*#*\s*$');
  static final _tableRow = RegExp(r'^\s*\|(.*)\|\s*$');
  static final _tableRule = RegExp(
    r'^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$',
  );
  static final _imageLine = RegExp(
    r'^\s*!\[([^\]]*)\]\(\s*wonky-file://([0-9a-fA-F-]{36})\s*\)\s*$',
  );
  static final _quoted = RegExp(r'^(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"');
  static final _attr = RegExp(r'(\w+)\s*=\s*("((?:[^"\\]|\\.)*)"|\S+)');

  /// Parses an outline. Lines that are neither headings, directives,
  /// fences, tables, images nor notes are body Markdown.
  static DeckOutline parse(String markdown) {
    final lines = markdown
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final slides = <OutlineSlide>[];
    String? deckTitle;
    var s = OutlineSlide();
    var inNotes = false;
    final notes = <String>[];
    var touched = false;

    void finish() {
      if (inNotes) s.notes = notes.join('\n').trim();
      notes.clear();
      inNotes = false;
      if (touched) slides.add(s);
      s = OutlineSlide();
      touched = false;
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      i++;
      final fence = _fenceOpen.firstMatch(line);
      if (fence != null) {
        final marker = fence.group(1)!;
        final code = <String>[];
        while (i < lines.length && !lines[i].trimLeft().startsWith(marker)) {
          code.add(lines[i]);
          i++;
        }
        i++; // closing fence
        if (inNotes) {
          notes.addAll([line, ...code, marker]);
        } else {
          s.code.add(OutlineCode(fence.group(2) ?? '', code.join('\n')));
          touched = true;
        }
        continue;
      }
      if (_separator.hasMatch(line)) {
        finish();
        continue;
      }
      final d = _directive.firstMatch(line);
      if (d != null) {
        final key = d.group(1)!.toLowerCase();
        final value = d.group(2)!.trim();
        switch (key) {
          case 'deck':
            final m = _quoted.firstMatch(value);
            if (m != null && m.group(1) == 'title') {
              deckTitle = m.group(2)!.replaceAll(r'\"', '"');
            }
          case 'layout':
            s.layout = value.isEmpty ? null : value;
            touched = true;
          case 'group':
            if (value.toLowerCase() == 'none') {
              s.groupNone = true;
            } else {
              final attrs = <String, String>{};
              var title = value;
              for (final m in _attr.allMatches(value)) {
                attrs[m.group(1)!] = m.group(3) ?? m.group(2)!;
              }
              final firstAttr = _attr.firstMatch(value);
              if (firstAttr != null) {
                title = value.substring(0, firstAttr.start);
              }
              s.groupTitle = title.trim().isEmpty ? null : title.trim();
              s.groupColor = attrs['color'];
              s.groupTitle ??= attrs['title'];
            }
            touched = true;
          case 'skip':
            s.skipped = true;
            touched = true;
          case 'transition':
            s.transition = value.isEmpty ? null : value;
            touched = true;
          default:
          // Other comments (chart descriptions) are ignored.
        }
        continue;
      }
      if (inNotes) {
        notes.add(line);
        continue;
      }
      final t = line.trim();
      if (t == 'Notes:' || t == '???' || t.startsWith('Notes: ')) {
        inNotes = true;
        touched = true;
        if (t.startsWith('Notes: ')) notes.add(t.substring(7));
        continue;
      }
      final h = _heading.firstMatch(line);
      if (h != null && s.title == null) {
        s.title = h.group(2);
        s.titleLevel = h.group(1)!.length;
        touched = true;
        continue;
      }
      final img = _imageLine.firstMatch(line);
      if (img != null) {
        s.images.add(OutlineImage(img.group(2)!.toLowerCase(), img.group(1)!));
        touched = true;
        continue;
      }
      if (t == '|||') {
        s.columns.add([]);
        touched = true;
        continue;
      }
      if (_tableRow.hasMatch(line)) {
        final rows = <List<String>>[];
        var j = i - 1;
        while (j < lines.length && _tableRow.hasMatch(lines[j])) {
          if (!_tableRule.hasMatch(lines[j])) rows.add(_cells(lines[j]));
          j++;
        }
        i = j;
        s.tables.add(rows);
        touched = true;
        continue;
      }
      if (t.isEmpty && s.columns.last.isEmpty) continue;
      s.columns.last.add(line);
      if (t.isNotEmpty) touched = true;
    }
    finish();
    return DeckOutline(slides, title: deckTitle);
  }

  static List<String> _cells(String row) {
    final inner = _tableRow.firstMatch(row)!.group(1)!;
    final out = <String>[];
    final b = StringBuffer();
    for (var k = 0; k < inner.length; k++) {
      final c = inner[k];
      if (c == r'\' && k + 1 < inner.length && inner[k + 1] == '|') {
        b.write('|');
        k++;
      } else if (c == '|') {
        out.add(b.toString().trim());
        b.clear();
      } else {
        b.write(c);
      }
    }
    out.add(b.toString().trim());
    return out;
  }

  // ------------------------------------------------------------- writing

  /// The outline Markdown of [deck] (presentation order). [slideLink] maps
  /// stored slide links (base-62 ids) to the written target (default: the
  /// slide's 1-based position).
  static String write(
    DeckModel deck, {
    String Function(String b62)? slideLink,
  }) {
    final slides = deck.slides;
    final positions = {
      for (final (i, s) in slides.indexed) Base62Uuid.encode(s.id): i + 1,
    };
    String link(String b62) =>
        slideLink?.call(b62) ?? '${positions[b62] ?? b62}';
    String md(String? json) =>
        SlidesMarkdownCodec.toMarkdown(json, slideLink: link);

    final out = StringBuffer();
    final title = deck.deck?.title ?? '';
    out.writeln('<!-- deck: title="${title.replaceAll('"', r'\"')}" -->');
    String? group;
    for (final (i, s) in slides.indexed) {
      if (i > 0) out.writeln('---');
      if (s.groupId != group) {
        if (s.groupId == null) {
          out.writeln('<!-- group: none -->');
        } else {
          final g = deck.group(s.groupId!);
          final color = g?.color;
          out.writeln(
            '<!-- group: ${g?.title ?? ''}'
            '${color == null ? '' : ' color=$color'} -->',
          );
        }
        group = s.groupId;
      }
      final layout = s.layoutId == null ? null : deck.layout(s.layoutId!);
      final key = layout?.key;
      if (key != null) out.writeln('<!-- layout: $key -->');
      if (s.skipped) out.writeln('<!-- skip -->');
      final tj = s.transitionJson;
      if (tj != null) {
        try {
          final t = jsonDecode(tj);
          if (t is Map && t['type'] is String) {
            out.writeln('<!-- transition: ${t['type']} -->');
          }
        } on FormatException {
          // Ignored.
        }
      }
      final elements = _ordered(deck.elementsOf(s.id));
      final titleEl = elements
          .where((e) => e.placeholderType == SlidePlaceholderType.title)
          .firstOrNull;
      final titleText = md(titleEl?.text).replaceAll('\n', ' ').trim();
      if (titleText.isNotEmpty) {
        final level = key == 'title' || key == 'section' ? '#' : '##';
        out.writeln('$level ${titleText.replaceFirst(RegExp('^#+ '), '')}');
      }
      final bodies = <String>[];
      for (final e in elements) {
        if (identical(e, titleEl) || e.hidden) continue;
        switch (e.kind) {
          case ElementKind.text || ElementKind.shape:
            final t = md(e.text).trim();
            if (t.isNotEmpty) bodies.add(t);
          case ElementKind.code:
            final states = deck.codeStatesOf(e.id);
            final lang = _codeLanguage(e.dataJson);
            final code = states.isEmpty ? '' : states.first.code;
            final fence = code.contains('```') ? '~~~' : '```';
            bodies.add('$fence$lang\n$code\n$fence');
          case ElementKind.table:
            final t = _table(deck, e.id);
            if (t.isNotEmpty) bodies.add(t);
          case ElementKind.chart:
            bodies.add(_chartComment(deck, e));
          case ElementKind.image:
            final src = _imageSrc(e.dataJson);
            if (src != null && src.startsWith('wonky-file://')) {
              final alt = (e.altText ?? '').replaceAll(
                RegExp(r'[\[\]\n]'),
                ' ',
              );
              bodies.add('![$alt]($src)');
            }
          default:
        }
      }
      final twoColumns = key == 'twoColumns' || key == 'comparison';
      if (twoColumns && bodies.length >= 2) {
        out
          ..writeln(bodies.first)
          ..writeln('|||')
          ..writeln(bodies.skip(1).join('\n'));
      } else if (bodies.isNotEmpty) {
        out.writeln(bodies.join('\n'));
      }
      final notes = md(s.notes).trim();
      if (notes.isNotEmpty) {
        out
          ..writeln('Notes:')
          ..writeln(notes);
      }
    }
    return out.toString();
  }

  static List<SlideElementRec> _ordered(List<SlideElementRec> list) {
    String key(SlideElementRec e) => e.readingKey ?? e.zKey;
    final placeholders = [
      for (final e in list)
        if (e.isPlaceholder) e,
    ];
    final rest =
        [
          for (final e in list)
            if (!e.isPlaceholder) e,
        ]..sort((a, b) {
          final c = key(a).compareTo(key(b));
          return c != 0 ? c : a.id.compareTo(b.id);
        });
    int rank(SlideElementRec e) =>
        SlidePlaceholderType.values.indexOf(e.placeholderType!);
    placeholders.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      if (c != 0) return c;
      final z = key(a).compareTo(key(b));
      return z != 0 ? z : a.id.compareTo(b.id);
    });
    return [...placeholders, ...rest];
  }

  static String _codeLanguage(String? dataJson) {
    if (dataJson == null) return '';
    try {
      final d = jsonDecode(dataJson);
      if (d is Map && d['language'] is String) return d['language'] as String;
    } on FormatException {
      // Ignored.
    }
    return '';
  }

  static String? _imageSrc(String? dataJson) {
    if (dataJson == null) return null;
    try {
      final d = jsonDecode(dataJson);
      if (d is Map && d['src'] is String) return d['src'] as String;
    } on FormatException {
      // Ignored.
    }
    return null;
  }

  static String _table(DeckModel deck, String elementId) {
    final rows = deck.axesOf(elementId, TableAxisDimension.row);
    final cols = deck.axesOf(elementId, TableAxisDimension.column);
    if (rows.isEmpty || cols.isEmpty) return '';
    final cells = {
      for (final c in deck.cellsOf(elementId)) '${c.rowId}|${c.columnId}': c,
    };
    String cell(String r, String c) => SlidesMarkdownCodec.toMarkdown(
      cells['$r|$c']?.text,
    ).replaceAll('\n', ' ').replaceAll('|', r'\|');
    final out = <String>[];
    for (final (i, r) in rows.indexed) {
      out.add('| ${[for (final c in cols) cell(r.id, c.id)].join(' | ')} |');
      if (i == 0) out.add('|${[for (final _ in cols) ' --- '].join('|')}|');
    }
    return out.join('\n');
  }

  static String _chartComment(DeckModel deck, SlideElementRec e) {
    final name = (e.name ?? '').replaceAll('"', "'");
    final link = deck.chartLinkOf(e.id);
    var source = '';
    try {
      source = ChartElementData.fromJson(e.dataJson).source.name;
    } on Object {
      // Ignored.
    }
    if (link != null) {
      return '<!-- chart: "$name" linked to spreadsheet '
          '${link.spreadsheetItemUuid} chart ${link.chartObjectId} -->';
    }
    return '<!-- chart: "$name"${source.isEmpty ? '' : ' ($source)'} -->';
  }

  /// The plain text of a body (for summaries and search).
  static String plain(String? json) =>
      SlidesText.plainText(json).trim().replaceAll('\n', ' ');
}
