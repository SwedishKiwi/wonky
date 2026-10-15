import 'dart:convert';

import 'package:wonky_rich_text/wonky_rich_text.dart'
    show InlineMarkdownWriter, InlineRun, softBreak;
import 'package:wonky_slides_core/model.dart' show SlidesText;

/// A run of uniformly formatted text of an [OutlineParagraph] (Delta
/// inline attributes).
class OutlineRun {
  const OutlineRun(this.text, [this.attributes = const {}]);

  final String text;
  final Map<String, Object?> attributes;

  bool get bold => attributes['bold'] == true;
  bool get italic => attributes['italic'] == true;
  bool get underline => attributes['underline'] == true;
  bool get strike => attributes['strike'] == true;

  OutlineRun withText(String t) => OutlineRun(t, attributes);

  Map<String, Object?> toOp() => {
    'insert': text,
    if (attributes.isNotEmpty) 'attributes': attributes,
  };
}

/// One paragraph (one outline line) of a text body: its runs and its block
/// attributes (`list`, `indent`, `style`, …, on the paragraph's `"\n"`).
class OutlineParagraph {
  const OutlineParagraph(this.runs, [this.block = const {}]);

  /// A plain paragraph at list [level] with [block] attributes.
  factory OutlineParagraph.plain(
    String text, {
    int level = 0,
    Map<String, Object?> block = const {},
  }) => OutlineParagraph([
    if (text.isNotEmpty) OutlineRun(text),
  ], _withLevel(block, level));

  final List<OutlineRun> runs;
  final Map<String, Object?> block;

  /// The plain text (soft breaks as U+2028).
  String get text => runs.map((r) => r.text).join();

  /// The list indentation level (0–8).
  int get level => (block['indent'] as num?)?.toInt() ?? 0;

  OutlineParagraph withLevel(int level) =>
      OutlineParagraph(runs, _withLevel(block, level));

  static Map<String, Object?> _withLevel(Map<String, Object?> b, int level) {
    final l = level.clamp(0, 8);
    return {
      for (final e in b.entries)
        if (e.key != 'indent') e.key: e.value,
      if (l > 0) 'indent': l,
    };
  }

  /// The paragraph with its text changed to [next]: the common prefix and
  /// suffix keep their runs (formatting of untouched text is kept, 04
  /// §10); inserted text takes the attributes of the character before it
  /// (or after it at the start).
  OutlineParagraph withText(String next) {
    final old = text;
    if (old == next) return this;
    var p = 0;
    final maxP = old.length < next.length ? old.length : next.length;
    while (p < maxP && old.codeUnitAt(p) == next.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < old.length - p &&
        s < next.length - p &&
        old.codeUnitAt(old.length - 1 - s) ==
            next.codeUnitAt(next.length - 1 - s)) {
      s++;
    }
    final inserted = next.substring(p, next.length - s);
    final head = slice(0, p);
    final tail = slice(old.length - s, old.length);
    final attrs = head.runs.isNotEmpty
        ? head.runs.last.attributes
        : (tail.runs.isNotEmpty
              ? tail.runs.first.attributes
              : const <String, Object?>{});
    return OutlineParagraph(
      _merge([
        ...head.runs,
        if (inserted.isNotEmpty) OutlineRun(inserted, _typing(attrs)),
        ...tail.runs,
      ]),
      block,
    );
  }

  /// Links don't extend to typed text.
  static Map<String, Object?> _typing(Map<String, Object?> a) => {
    for (final e in a.entries)
      if (e.key != 'link') e.key: e.value,
  };

  /// The runs of `[from, to)` (same block attributes).
  OutlineParagraph slice(int from, [int? to]) {
    final end = to ?? text.length;
    final out = <OutlineRun>[];
    var at = 0;
    for (final r in runs) {
      final a = at, b = at + r.text.length;
      at = b;
      final s = from > a ? from : a;
      final e = end < b ? end : b;
      if (e > s) out.add(r.withText(r.text.substring(s - a, e - a)));
    }
    return OutlineParagraph(out, block);
  }

  /// This paragraph followed by [other]'s runs (this one's block).
  OutlineParagraph append(OutlineParagraph other) =>
      OutlineParagraph(_merge([...runs, ...other.runs]), block);

  static List<OutlineRun> _merge(List<OutlineRun> runs) {
    final out = <OutlineRun>[];
    for (final r in runs) {
      if (r.text.isEmpty) continue;
      if (out.isNotEmpty && _sameAttrs(out.last.attributes, r.attributes)) {
        out[out.length - 1] = out.last.withText(out.last.text + r.text);
      } else {
        out.add(r);
      }
    }
    return out;
  }

  static bool _sameAttrs(Map<String, Object?> a, Map<String, Object?> b) =>
      jsonEncode(a) == jsonEncode(b);

  /// Inline Markdown of the runs (bold, italic, strike, code, links).
  String toMarkdown() => InlineMarkdownWriter.write([
    for (final r in runs)
      InlineRun(
        r.text.replaceAll(softBreak, ' '),
        bold: r.bold,
        italic: r.italic,
        strike: r.strike,
        code: r.attributes['code'] == true,
        link: r.attributes['link'] as String?,
      ),
  ]);
}

/// A text body (Delta JSON, 02 §4.1) as outline lines (Slides 04 §10):
/// one [OutlineParagraph] per paragraph. Edits produce a new body; [toJson]
/// writes the Delta again (the planner normalizes it).
class OutlineBody {
  OutlineBody(List<OutlineParagraph> paragraphs)
    : paragraphs = paragraphs.isEmpty
          ? const [OutlineParagraph([])]
          : List.unmodifiable(paragraphs);

  /// Parses stored Delta JSON (null or malformed = one empty paragraph).
  factory OutlineBody.parse(String? json) {
    if (json == null || json.isEmpty) return OutlineBody(const []);
    Object? v;
    try {
      v = jsonDecode(json);
    } on FormatException {
      return OutlineBody(const []);
    }
    if (v is Map && v['ops'] is List) v = v['ops'];
    if (v is! List) return OutlineBody(const []);
    final out = <OutlineParagraph>[];
    var runs = <OutlineRun>[];
    for (final op in v) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'] is Map
          ? (op['attributes'] as Map).cast<String, Object?>()
          : const <String, Object?>{};
      final inline = <String, Object?>{
        for (final e in attrs.entries)
          if (!SlidesText.isBlockAttribute(e.key)) e.key: e.value,
      };
      final block = <String, Object?>{
        for (final e in attrs.entries)
          if (SlidesText.isBlockAttribute(e.key)) e.key: e.value,
      };
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) runs.add(OutlineRun(parts[i], inline));
        if (i < parts.length - 1) {
          out.add(OutlineParagraph(OutlineParagraph._merge(runs), block));
          runs = <OutlineRun>[];
        }
      }
    }
    if (runs.isNotEmpty) {
      out.add(OutlineParagraph(OutlineParagraph._merge(runs)));
    }
    return OutlineBody(out);
  }

  final List<OutlineParagraph> paragraphs;

  int get length => paragraphs.length;

  OutlineParagraph operator [](int i) => paragraphs[i];

  /// Whether the body holds no visible text.
  bool get isBlank => paragraphs.every((p) => p.text.trim().isEmpty);

  /// The plain text of each line.
  List<String> get lines => [for (final p in paragraphs) p.text];

  /// Delta JSON (`[{"insert": …}, …, {"insert": "\n", "attributes": …}]`).
  String toJson() {
    final ops = <Map<String, Object?>>[];
    for (final p in paragraphs) {
      for (final r in p.runs) {
        ops.add(r.toOp());
      }
      ops.add({'insert': '\n', if (p.block.isNotEmpty) 'attributes': p.block});
    }
    return jsonEncode(ops);
  }

  OutlineBody _with(List<OutlineParagraph> ps) => OutlineBody(ps);

  List<OutlineParagraph> get _list => [...paragraphs];

  /// Line [i]'s text set to [text] (formatting kept, [OutlineParagraph.
  /// withText]).
  OutlineBody withText(int i, String text) =>
      _with(_list..[i] = paragraphs[i].withText(text));

  /// Line [i] split at [offset]: the tail becomes line `i + 1` with the
  /// same block attributes (Enter).
  OutlineBody split(int i, int offset) {
    final p = paragraphs[i];
    final o = offset.clamp(0, p.text.length);
    return _with(
      _list
        ..[i] = p.slice(0, o)
        ..insert(i + 1, p.slice(o)),
    );
  }

  /// Line [i] joined onto line `i - 1` (Backspace at its start).
  OutlineBody join(int i) {
    if (i <= 0 || i >= length) return this;
    return _with(
      _list
        ..[i - 1] = paragraphs[i - 1].append(paragraphs[i])
        ..removeAt(i),
    );
  }

  /// Line [i] at list [level] (Tab / Shift+Tab).
  OutlineBody withLevel(int i, int level) =>
      _with(_list..[i] = paragraphs[i].withLevel(level));

  /// Line [i] moved to position [to].
  OutlineBody move(int i, int to) {
    if (to < 0 || to >= length || to == i) return this;
    final l = _list;
    final p = l.removeAt(i);
    l.insert(to, p);
    return _with(l);
  }

  OutlineBody removeAt(int i) => _with(_list..removeAt(i));

  OutlineBody insert(int i, OutlineParagraph p) => _with(_list..insert(i, p));

  /// Lines `[from, to)`.
  OutlineBody sublist(int from, [int? to]) =>
      _with(paragraphs.sublist(from, to));

  /// This body (without a trailing empty line when blank) followed by
  /// [other]'s lines, [levelDelta] deeper.
  OutlineBody concat(OutlineBody other, {int levelDelta = 0}) => _with([
    if (!isBlank) ...paragraphs,
    for (final p in other.paragraphs)
      if (p.text.isNotEmpty || !other.isBlank)
        p.withLevel(p.level + levelDelta),
  ]);

  /// Line [i]'s runs as a one-paragraph body without block attributes (a
  /// bullet promoted to a slide title).
  OutlineBody titleOf(int i) =>
      OutlineBody([OutlineParagraph(paragraphs[i].runs)]);
}
