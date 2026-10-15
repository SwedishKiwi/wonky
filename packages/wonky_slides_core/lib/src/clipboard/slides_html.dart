import 'dart:convert';
import 'dart:math' as math;

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:wonky_rich_text/wonky_rich_text.dart';

import '../text/slides_delta.dart';
import 'slides_clipboard_codec.dart';
import 'slides_paste_mappers.dart';

/// The `text/html` side of the Slides clipboard (03 §12.1, §12.4, §12.5):
///
/// - **Writing**: [ofPayload] renders a payload as readable HTML (text
///   bodies as paragraphs, headings and lists, tables as `<table>`, slides
///   as a title and their text) that Wonky Write, Wonky Sheets and other
///   apps paste, with the lossless payload embedded in the
///   `data-wonky-slides` attribute (base64url JSON — the pattern of
///   Write's `data-wonky-delta`), so another tab, deck or app of Wonky Work
///   pastes it exactly.
/// - **Reading**: [payloadOf] (a Slides payload), [writeDeltaOf] (Wonky
///   Write's embedded Delta), [tableOf] (a single table: Sheets cells,
///   spreadsheets, HTML tables) and [importHtml] (any other HTML mapped to
///   a Write-flavored Delta for `SlidesPasteMappers.writeDelta`).
abstract final class SlidesHtml {
  /// Attribute holding the embedded Slides payload.
  static const payloadAttribute = 'data-wonky-slides';

  /// Attribute holding Wonky Write's Delta (Write 04 §23.2).
  static const writeDeltaAttribute = 'data-wonky-delta';

  /// Payloads larger than this (JSON characters) are not embedded; the
  /// in-app store still pastes them in this browser.
  static const maxEmbedChars = 4 * 1024 * 1024;

  // ---------------------------------------------------------------- write

  /// The clipboard HTML of [payload]: readable content plus the embedded
  /// payload (unless larger than [maxEmbedChars]).
  static String ofPayload(Map<String, Object?> payload) {
    final body = SlidesClipboardCodec.htmlBody(payload);
    final json = SlidesClipboardCodec.encode(payload);
    if (json.length > maxEmbedChars) return '<div>$body</div>';
    final encoded = base64Url.encode(utf8.encode(json));
    return '<div $payloadAttribute="$encoded">$body</div>';
  }

  /// HTML of a Slides text body (Delta JSON value or [Delta]): paragraphs,
  /// `title`/`heading` styles as headings, quotes, nested lists, and
  /// bold/italic/underline/strike/code/links/colors inline.
  static String ofDelta(Object? delta) {
    final Delta d;
    if (delta is Delta) {
      d = delta;
    } else {
      d = SlidesDeltaNormalizer().normalizeValue(delta).delta;
    }
    final out = StringBuffer();
    // Open list stack: (tag, indent).
    final lists = <(String, int)>[];
    void closeLists([int toDepth = 0]) {
      while (lists.length > toDepth) {
        out.write('</li></${lists.removeLast().$1}>');
      }
    }

    final line = StringBuffer();
    for (final op in d.operations) {
      final data = op.data;
      if (data is! String) continue;
      var rest = data;
      while (rest.isNotEmpty) {
        final nl = rest.indexOf('\n');
        if (nl < 0) {
          line.write(_inlineHtml(rest, op.attributes));
          break;
        }
        if (nl > 0) {
          line.write(_inlineHtml(rest.substring(0, nl), op.attributes));
        }
        rest = rest.substring(nl + 1);
        final a = op.attributes ?? const <String, dynamic>{};
        final list = a['list'];
        final content = line.isEmpty ? '<br>' : line.toString();
        line.clear();
        final align = a['align'];
        final alignStyle = align is String && align != 'left'
            ? ' style="text-align:$align"'
            : '';
        if (list is String) {
          final tag = list == 'ordered' ? 'ol' : 'ul';
          final indent = (a['indent'] as int?) ?? 0;
          // Depth = indent + 1 (lists nest inside the previous item).
          final depth = math.min(indent + 1, lists.length + 1);
          if (lists.length > depth) {
            closeLists(depth);
          }
          if (lists.length == depth && lists.last.$1 != tag) {
            closeLists(depth - 1);
          }
          if (lists.length == depth) {
            out.write('</li><li$alignStyle>');
          } else {
            out.write('<$tag><li$alignStyle>');
            lists.add((tag, indent));
          }
          if (list == 'check') out.write('&#9745; ');
          if (list == 'unchecked') out.write('&#9744; ');
          out.write(content);
          continue;
        }
        closeLists();
        final tag = switch (a['style']) {
          'title' => 'h1',
          'subtitle' || 'heading' => 'h2',
          'quote' => 'blockquote',
          _ => 'p',
        };
        out.write('<$tag$alignStyle>$content</$tag>');
      }
    }
    if (line.isNotEmpty) {
      closeLists();
      out.write('<p>$line</p>');
    }
    closeLists();
    return out.toString();
  }

  static String _inlineHtml(String text, Map<String, dynamic>? a) {
    var s = escape(text);
    if (a == null || a.isEmpty) return s;
    if (a['code'] == true) s = '<code>$s</code>';
    if (a['bold'] == true) s = '<b>$s</b>';
    if (a['italic'] == true) s = '<i>$s</i>';
    if (a['underline'] == true) s = '<u>$s</u>';
    if (a['strike'] == true) s = '<s>$s</s>';
    final color = a['color'];
    if (color is String && color.startsWith('#')) {
      s = '<span style="color:${escape(color)}">$s</span>';
    }
    final link = a['link'];
    if (link is String &&
        (link.startsWith('https://') || link.startsWith('mailto:'))) {
      s = '<a href="${escape(link)}">$s</a>';
    }
    return s;
  }

  /// HTML-escapes [s] (text and attribute values).
  static String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ----------------------------------------------------------------- read

  static dom.DocumentFragment? _parse(String html) {
    if (html.trim().isEmpty) return null;
    try {
      return html_parser.parseFragment(html);
    } on Object {
      return null;
    }
  }

  static String? _attr(String html, String name) {
    final i = html.indexOf(name);
    if (i < 0) return null;
    final m = RegExp(
      '$name\\s*=\\s*["\']([^"\']*)["\']',
    ).firstMatch(html.substring(i));
    return m?.group(1);
  }

  static Object? _base64Json(String value) {
    try {
      final padded = value.padRight((value.length + 3) ~/ 4 * 4, '=');
      return jsonDecode(utf8.decode(base64Url.decode(padded)));
    } on Object {
      return null;
    }
  }

  /// The Slides payload embedded in [html] (sanitized), or null.
  static Map<String, Object?>? payloadOf(String html) {
    final v = _attr(html, payloadAttribute);
    if (v == null) return null;
    final raw = _base64Json(v);
    if (raw is! Map) return null;
    try {
      return SlidesClipboardCodec.sanitize(raw.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  /// Wonky Write's Delta embedded in [html] (`data-wonky-delta`), or null.
  static Delta? writeDeltaOf(String html) {
    final v = _attr(html, writeDeltaAttribute);
    if (v == null) return null;
    final raw = _base64Json(v);
    if (raw is! List) return null;
    try {
      return Delta.fromJson(raw);
    } on Object {
      return null;
    }
  }

  static const _skipped = {
    'script',
    'style',
    'head',
    'meta',
    'title',
    'link',
    'template',
    'noscript',
    'colgroup',
  };

  /// The grid of [html] when its content is one table (Sheets cells,
  /// spreadsheets, Google Sheets, Excel), else null: displayed text,
  /// bold/italic, text color, fill, horizontal alignment and merges
  /// (covered cells as empty cells).
  static List<List<GridCell>>? tableOf(String html) {
    final frag = _parse(html);
    if (frag == null) return null;
    dom.Element? table;
    var other = false;
    void scan(dom.Node n) {
      if (other) return;
      if (n is dom.Element) {
        final tag = n.localName ?? '';
        if (_skipped.contains(tag)) return;
        if (tag == 'table') {
          if (table != null) {
            other = true;
          } else {
            table = n;
          }
          return;
        }
        if (tag == 'img') {
          other = true;
          return;
        }
        for (final c in n.nodes) {
          scan(c);
        }
        return;
      }
      if (n is dom.Text && n.text.trim().isNotEmpty) other = true;
    }

    for (final n in frag.nodes) {
      scan(n);
    }
    final t = table;
    if (other || t == null) return null;
    final rows = <List<GridCell?>>[];
    final occupied = <(int, int)>{};
    var r = 0;
    for (final tr in _rowsOf(t)) {
      final row = <GridCell?>[];
      while (rows.length <= r) {
        rows.add([]);
      }
      var c = 0;
      for (final td in tr.children) {
        if (td.localName != 'td' && td.localName != 'th') continue;
        while (occupied.contains((r, c))) {
          c++;
        }
        final rs = int.tryParse(td.attributes['rowspan'] ?? '') ?? 1;
        final cs = int.tryParse(td.attributes['colspan'] ?? '') ?? 1;
        final cell = _gridCell(td, rowSpan: rs, colSpan: cs);
        _put(rows, r, c, cell);
        for (var dr = 0; dr < rs; dr++) {
          for (var dc = 0; dc < cs; dc++) {
            if (dr == 0 && dc == 0) continue;
            occupied.add((r + dr, c + dc));
          }
        }
        c += cs;
      }
      row.clear();
      r++;
    }
    if (rows.isEmpty) return null;
    final width = rows.fold<int>(0, (m, x) => math.max(m, x.length));
    final height = math.max(
      rows.length,
      occupied.fold<int>(0, (m, p) => math.max(m, p.$1 + 1)),
    );
    if (width == 0) return null;
    return [
      for (var i = 0; i < height; i++)
        [
          for (var j = 0; j < width; j++)
            (i < rows.length && j < rows[i].length ? rows[i][j] : null) ??
                const GridCell(''),
        ],
    ];
  }

  static void _put(List<List<GridCell?>> rows, int r, int c, GridCell cell) {
    final row = rows[r];
    while (row.length <= c) {
      row.add(null);
    }
    row[c] = cell;
  }

  static Iterable<dom.Element> _rowsOf(dom.Element table) sync* {
    for (final c in table.children) {
      final tag = c.localName;
      if (tag == 'tr') {
        yield c;
      } else if (tag == 'tbody' || tag == 'thead' || tag == 'tfoot') {
        for (final tr in c.children) {
          if (tr.localName == 'tr') yield tr;
        }
      }
    }
  }

  static GridCell _gridCell(
    dom.Element td, {
    required int rowSpan,
    required int colSpan,
  }) {
    final css = _css(td.attributes['style']);
    var bold =
        td.localName == 'th' ||
        _isBold(css['font-weight']) ||
        _hasTag(td, {'b', 'strong'});
    final italic = css['font-style'] == 'italic' || _hasTag(td, {'i', 'em'});
    // Google Sheets/Docs wrap content in `font-weight:normal` spans.
    if (css['font-weight'] == 'normal' || css['font-weight'] == '400') {
      bold = _hasTag(td, {'b', 'strong'});
    }
    final color = _color(css['color']) ?? _innerColor(td);
    final fill = _color(css['background-color'] ?? css['background']);
    final align = switch (css['text-align'] ?? td.attributes['align']) {
      'center' => 'center',
      'right' => 'right',
      'left' => 'left',
      _ => null,
    };
    return GridCell(
      _cellText(td),
      bold: bold,
      italic: italic,
      color: color,
      fill: fill == '#ffffff' ? null : fill,
      align: align,
      rowSpan: rowSpan > 1 ? rowSpan : null,
      colSpan: colSpan > 1 ? colSpan : null,
    );
  }

  static bool _hasTag(dom.Element e, Set<String> tags) {
    for (final c in e.children) {
      if (tags.contains(c.localName)) {
        final w = _css(c.attributes['style'])['font-weight'];
        if (w == 'normal' || w == '400') continue;
        return true;
      }
      if (_hasTag(c, tags)) return true;
    }
    return false;
  }

  static String? _innerColor(dom.Element e) {
    for (final c in e.children) {
      final v = _color(_css(c.attributes['style'])['color']) ?? _innerColor(c);
      if (v != null) return v;
    }
    return null;
  }

  static String _cellText(dom.Element td) {
    final b = StringBuffer();
    void walk(dom.Node n) {
      if (n is dom.Text) {
        b.write(n.text);
      } else if (n is dom.Element) {
        if (_skipped.contains(n.localName)) return;
        if (n.localName == 'br') {
          b.write('\n');
          return;
        }
        for (final c in n.nodes) {
          walk(c);
        }
        if (n.localName == 'p' || n.localName == 'div') b.write('\n');
      }
    }

    for (final n in td.nodes) {
      walk(n);
    }
    return b
        .toString()
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  static Map<String, String> _css(String? style) {
    if (style == null || style.isEmpty) return const {};
    final out = <String, String>{};
    for (final part in style.split(';')) {
      final i = part.indexOf(':');
      if (i <= 0) continue;
      out[part.substring(0, i).trim().toLowerCase()] = part
          .substring(i + 1)
          .trim()
          .toLowerCase();
    }
    return out;
  }

  static bool _isBold(String? w) {
    if (w == null) return false;
    if (w == 'bold' || w == 'bolder') return true;
    final n = int.tryParse(w);
    return n != null && n >= 600;
  }

  static final _rgb = RegExp(r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)');

  /// A CSS color as `#rrggbb` (hex and `rgb()`), else null.
  static String? _color(String? v) {
    if (v == null) return null;
    final m = _rgb.firstMatch(v.trim());
    if (m != null) {
      String h(String x) =>
          int.parse(x).clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return '#${h(m.group(1)!)}${h(m.group(2)!)}${h(m.group(3)!)}';
    }
    final s = v.split(' ').first.trim();
    if (RegExp(r'^#[0-9a-f]{6}$').hasMatch(s)) return s;
    if (RegExp(r'^#[0-9a-f]{3}$').hasMatch(s)) {
      return '#${s[1]}${s[1]}${s[2]}${s[2]}${s[3]}${s[3]}';
    }
    return null;
  }

  /// Any HTML (03 §12.5, P1) as a Write-flavored Delta that
  /// `SlidesPasteMappers.writeDelta` maps to elements: paragraphs and
  /// headings (`header`), quotes, nested lists (`list`, `indent`), code
  /// blocks (`code-block` with the `language-*` class), bold, italic,
  /// underline, strike, inline code and links; `<img>` with `https://` or
  /// `wonky-file://` sources → image embeds; tables → table embeds. Fonts,
  /// sizes and other styling are dropped ([HtmlImport.dropped]).
  static HtmlImport importHtml(String html) {
    final frag = _parse(html);
    final w = _DeltaWriter();
    if (frag != null) {
      for (final n in frag.nodes) {
        w.node(n, const {});
      }
    }
    w.endBlock();
    return HtmlImport(w.delta, dropped: w.dropped);
  }
}

/// The result of [SlidesHtml.importHtml].
final class HtmlImport {
  /// Creates a result.
  const HtmlImport(this.delta, {this.dropped = false});

  /// Write-flavored Delta (text, `image` and `table` embeds).
  final Delta delta;

  /// Whether styling was dropped.
  final bool dropped;
}

/// Walks HTML and writes a Write-flavored Delta.
final class _DeltaWriter {
  final delta = Delta();
  bool dropped = false;

  /// Inline runs of the current line.
  final _line = <(String, Map<String, dynamic>)>[];

  /// Block attributes of the open block elements (innermost last).
  final _blocks = <Map<String, dynamic>>[];
  int _listDepth = 0;
  final _listTags = <String>[];

  static const _blockTags = {
    'p',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'section',
    'article',
    'header',
    'footer',
    'figure',
    'figcaption',
    'dt',
    'dd',
  };

  /// Writes the current line (if it has text) with the open blocks'
  /// attributes.
  void endBlock() {
    final text = _line.map((r) => r.$1).join();
    if (text.trim().isEmpty) {
      _line.clear();
      return;
    }
    final block = <String, dynamic>{for (final b in _blocks) ...b};
    for (final (t, a) in _line) {
      delta.insert(t, a.isEmpty ? null : Map.of(a));
    }
    delta.insert('\n', block.isEmpty ? null : block);
    _line.clear();
  }

  void _text(String t, Map<String, dynamic> inline) {
    var s = t.replaceAll(RegExp(r'[\r\n\t ]+'), ' ').replaceAll('\u00a0', ' ');
    if (_line.isEmpty) s = s.trimLeft();
    if (s.isEmpty) return;
    _line.add((s, inline));
  }

  Map<String, dynamic> _blockAttrs(String tag) => switch (tag) {
    'h1' => {'header': 1},
    'h2' || 'h3' || 'h4' || 'h5' || 'h6' => {'header': int.parse(tag[1])},
    'blockquote' => {'blockquote': true},
    'li' when _listDepth > 0 => {
      'list': _listTags.last == 'ol' ? 'ordered' : 'bullet',
      if (_listDepth > 1) 'indent': _listDepth - 1,
    },
    _ => const {},
  };

  void node(dom.Node n, Map<String, dynamic> inline) {
    if (n is dom.Text) {
      _text(n.text, inline);
      return;
    }
    if (n is! dom.Element) return;
    final tag = n.localName ?? '';
    if (SlidesHtml._skipped.contains(tag)) return;
    final css = SlidesHtml._css(n.attributes['style']);
    final styled = css.keys.toSet()
      ..removeAll({'font-weight', 'font-style', 'text-decoration'});
    if (styled.isNotEmpty) dropped = true;
    switch (tag) {
      case 'br':
        endBlock();
        return;
      case 'img':
        final src = n.attributes['src'] ?? '';
        if (src.startsWith('https://') || src.startsWith('wonky-file://')) {
          endBlock();
          delta.insert({
            'image': {'src': src, 'alt': ?n.attributes['alt']},
          });
        } else {
          dropped = true;
        }
        return;
      case 'table':
        endBlock();
        final rows = [
          for (final tr in SlidesHtml._rowsOf(n))
            [
              for (final td in tr.children)
                if (td.localName == 'td' || td.localName == 'th')
                  SlidesHtml._cellText(td).replaceAll('\n', ' '),
            ],
        ];
        if (rows.isNotEmpty) {
          delta.insert({
            'table': {'rows': rows},
          });
        }
        return;
      case 'pre':
        endBlock();
        final cls = [
          n.attributes['class'] ?? '',
          for (final c in n.children) c.attributes['class'] ?? '',
        ].join(' ');
        final lang =
            RegExp(r'language-([\w+#-]+)').firstMatch(cls)?.group(1) ??
            'plaintext';
        final code = n.text.replaceAll('\r\n', '\n');
        final lines = code.endsWith('\n')
            ? code.substring(0, code.length - 1).split('\n')
            : code.split('\n');
        for (final l in lines) {
          if (l.isNotEmpty) delta.insert(l);
          delta.insert('\n', {'code-block': lang});
        }
        return;
      case 'ul':
      case 'ol':
        endBlock();
        _listTags.add(tag);
        _listDepth++;
        for (final c in n.nodes) {
          node(c, inline);
        }
        endBlock();
        _listDepth--;
        _listTags.removeLast();
        return;
    }
    final isBlock = _blockTags.contains(tag);
    if (isBlock) {
      endBlock();
      _blocks.add(_blockAttrs(tag));
    }
    final next = Map<String, dynamic>.of(inline);
    switch (tag) {
      case 'b' || 'strong':
        next['bold'] = true;
      case 'i' || 'em':
        next['italic'] = true;
      case 'u' || 'ins':
        next['underline'] = true;
      case 's' || 'strike' || 'del':
        next['strike'] = true;
      case 'code' || 'kbd' || 'samp':
        next['code'] = true;
      case 'a':
        final href = n.attributes['href'];
        if (href != null &&
            (href.startsWith('https://') ||
                href.startsWith('http://') ||
                href.startsWith('mailto:'))) {
          next['link'] = href;
        }
    }
    if (SlidesHtml._isBold(css['font-weight'])) next['bold'] = true;
    // Google Docs wraps everything in `<b style="font-weight:normal">`.
    if (css['font-weight'] == 'normal' || css['font-weight'] == '400') {
      next.remove('bold');
    }
    if (css['font-style'] == 'italic') next['italic'] = true;
    final deco = css['text-decoration'] ?? css['text-decoration-line'] ?? '';
    if (deco.contains('underline')) next['underline'] = true;
    if (deco.contains('line-through')) next['strike'] = true;
    for (final c in n.nodes) {
      node(c, next);
    }
    if (isBlock) {
      endBlock();
      _blocks.removeLast();
    }
  }
}
