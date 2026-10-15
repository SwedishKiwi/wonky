import 'package:wonky_rich_text/wonky_rich_text.dart';
import 'package:wonky_sync_models/ids.dart' show FractionalIndex;

import '../model/api/deck_model.dart';
import '../model/api/kinds.dart';
import '../model/api/records.dart';
import '../model/text/slides_text.dart';
import '../ops/operations.dart';

/// Where *Find and replace* searches (03 §13).
enum FindScope {
  /// Every slide (presentation order).
  all,

  /// The current slide only.
  currentSlide,

  /// The selected slides only.
  selectedSlides,
}

/// The options of *Find and replace* (03 §13).
final class DeckFindOptions {
  /// Creates options (the dialog's defaults).
  const DeckFindOptions({
    this.matchCase = false,
    this.wholeWords = false,
    this.useRegex = false,
    this.includeNotes = true,
    this.includeSkipped = true,
    this.scope = FindScope.all,
    this.slideIds = const [],
  });

  final bool matchCase;
  final bool wholeWords;
  final bool useRegex;

  /// Search speaker notes (default on).
  final bool includeNotes;

  /// Search skipped slides (default on).
  final bool includeSkipped;

  /// The slides searched.
  final FindScope scope;

  /// The slides of [FindScope.currentSlide] / [FindScope.selectedSlides].
  final List<String> slideIds;

  /// A copy with the given values.
  DeckFindOptions copyWith({
    bool? matchCase,
    bool? wholeWords,
    bool? useRegex,
    bool? includeNotes,
    bool? includeSkipped,
    FindScope? scope,
    List<String>? slideIds,
  }) => DeckFindOptions(
    matchCase: matchCase ?? this.matchCase,
    wholeWords: wholeWords ?? this.wholeWords,
    useRegex: useRegex ?? this.useRegex,
    includeNotes: includeNotes ?? this.includeNotes,
    includeSkipped: includeSkipped ?? this.includeSkipped,
    scope: scope ?? this.scope,
    slideIds: slideIds ?? this.slideIds,
  );

  @override
  bool operator ==(Object other) =>
      other is DeckFindOptions &&
      other.matchCase == matchCase &&
      other.wholeWords == wholeWords &&
      other.useRegex == useRegex &&
      other.includeNotes == includeNotes &&
      other.includeSkipped == includeSkipped &&
      other.scope == scope &&
      _sameList(other.slideIds, slideIds);

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    matchCase,
    wholeWords,
    useRegex,
    includeNotes,
    includeSkipped,
    scope,
    Object.hashAll(slideIds),
  );
}

/// One match of a search: a range of one text body's plain text (the
/// paragraphs of the Delta joined by `"\n"`).
final class DeckFindMatch {
  /// Creates a match.
  const DeckFindMatch({
    required this.slideId,
    required this.target,
    required this.start,
    required this.length,
    required this.text,
  });

  /// The slide the body is on (notes: their slide).
  final String slideId;

  /// The body: `ElementText`, `CellText` or `NotesText`.
  final TextTarget target;

  /// Offset of the match in the body's plain text.
  final int start;

  /// Length of the match.
  final int length;

  /// The matched text.
  final String text;

  /// The element of an element or cell body (null for notes).
  String? get elementId => switch (target) {
    ElementText(:final elementId) => elementId,
    CellText(:final elementId) => elementId,
    NotesText() => null,
  };

  /// Whether the match is in speaker notes.
  bool get inNotes => target is NotesText;

  /// A key unique per body.
  String get bodyKey => DeckFind.bodyKey(target);

  @override
  String toString() =>
      'DeckFindMatch($bodyKey @$start+$length "${text.replaceAll('\n', r'\n')}")';
}

/// Find and replace over a deck (03 §13): every text body in presentation
/// order — slide elements in reading order (groups expanded, table cells
/// row by row), then the slide's speaker notes — with match case, whole
/// words, regular expressions, scope and the notes/skipped switches.
/// Placeholder instances without their own text (prompts) and code are
/// not searched; master and layout text only in master editing (not yet).
abstract final class DeckFind {
  /// Max matches of one search ("100,000+" is not useful on slides).
  static const maxMatches = 10000;

  /// A key unique per body of [t].
  static String bodyKey(TextTarget t) => switch (t) {
    ElementText(:final elementId) => 'text:$elementId',
    CellText(:final elementId, :final rowId, :final columnId) =>
      'tableCell:$elementId|$rowId|$columnId',
    NotesText(:final slideId) => 'notes:$slideId',
  };

  /// The pattern of [query] (null when empty). Throws [FormatException]
  /// for an invalid regular expression.
  static RegExp? pattern(String query, DeckFindOptions o) {
    if (query.isEmpty) return null;
    var source = o.useRegex ? query : RegExp.escape(query);
    if (o.wholeWords) {
      source = r'(?<![\p{L}\p{N}_])(?:' + source + r')(?![\p{L}\p{N}_])';
    }
    return RegExp(source, caseSensitive: o.matchCase, unicode: true);
  }

  /// The text bodies of [deck] searched with [o], in presentation order:
  /// (slide id, target, stored Delta JSON).
  static Iterable<(String, TextTarget, String)> bodies(
    DeckModel deck,
    DeckFindOptions o,
  ) sync* {
    final only = o.scope == FindScope.all ? null : o.slideIds.toSet();
    for (final s in deck.slides) {
      if (only != null && !only.contains(s.id)) continue;
      if (!o.includeSkipped && _skipped(deck, s)) continue;
      yield* _elementBodies(deck, s.id, _ordered(deck.elementsOf(s.id)));
      final notes = s.notes;
      if (o.includeNotes && notes != null && !SlidesText.isBlank(notes)) {
        yield (s.id, NotesText(s.id), notes);
      }
    }
  }

  static bool _skipped(DeckModel deck, SlideRec s) {
    if (s.skipped) return true;
    final g = s.groupId == null ? null : deck.group(s.groupId!);
    return g?.skipped ?? false;
  }

  static int _cmp(String ka, String ia, String kb, String ib) =>
      FractionalIndex.compare(ka, ia, kb, ib);

  /// Top-level elements in reading order (`readingKey`, else z-order).
  static List<SlideElementRec> _ordered(List<SlideElementRec> list) {
    String key(SlideElementRec e) => e.readingKey ?? e.zKey;
    return [...list]..sort((a, b) => _cmp(key(a), a.id, key(b), b.id));
  }

  static Iterable<(String, TextTarget, String)> _elementBodies(
    DeckModel deck,
    String slideId,
    List<SlideElementRec> list,
  ) sync* {
    for (final e in list) {
      switch (e.kind) {
        case ElementKind.group:
          final children = [...deck.elementsOf(slideId, parentId: e.id)]
            ..sort((a, b) => _cmp(a.zKey, a.id, b.zKey, b.id));
          yield* _elementBodies(deck, slideId, children);
        case ElementKind.table:
          int axisIndex(List<SlideTableAxisRec> axes, String? id) =>
              axes.indexWhere((a) => a.id == id);
          final rows = _axes(deck.axesOf(e.id, TableAxisDimension.row));
          final cols = _axes(deck.axesOf(e.id, TableAxisDimension.column));
          final cells = [
            for (final c in deck.cellsOf(e.id))
              if (c.text != null &&
                  !SlidesText.isBlank(c.text) &&
                  axisIndex(rows, c.rowId) >= 0 &&
                  axisIndex(cols, c.columnId) >= 0)
                c,
          ];
          cells.sort((a, b) {
            final r = axisIndex(rows, a.rowId) - axisIndex(rows, b.rowId);
            if (r != 0) return r;
            return axisIndex(cols, a.columnId) - axisIndex(cols, b.columnId);
          });
          for (final c in cells) {
            yield (slideId, CellText(e.id, c.rowId!, c.columnId!), c.text!);
          }
        case ElementKind.code ||
            ElementKind.image ||
            ElementKind.chart ||
            ElementKind.line:
          break;
        default:
          final t = e.text;
          if (t != null && !SlidesText.isBlank(t)) {
            yield (slideId, ElementText(e.id), t);
          }
      }
    }
  }

  static List<SlideTableAxisRec> _axes(List<SlideTableAxisRec> a) =>
      [...a]..sort((x, y) => _cmp(x.sortKey, x.id, y.sortKey, y.id));

  /// The plain text of a stored body without its final `"\n"`.
  static String plainOf(String json) {
    final t = SlidesText.plainText(json);
    return t.endsWith('\n') ? t.substring(0, t.length - 1) : t;
  }

  /// Every match of [query] in [deck] (at most [limit]). Throws
  /// [FormatException] for an invalid regular expression.
  static List<DeckFindMatch> search(
    DeckModel deck,
    String query,
    DeckFindOptions o, {
    int limit = maxMatches,
  }) {
    final re = pattern(query, o);
    if (re == null) return const [];
    final out = <DeckFindMatch>[];
    for (final (slideId, target, json) in bodies(deck, o)) {
      final text = plainOf(json);
      for (final m in re.allMatches(text)) {
        if (m.end == m.start) continue;
        out.add(
          DeckFindMatch(
            slideId: slideId,
            target: target,
            start: m.start,
            length: m.end - m.start,
            text: m.group(0)!,
          ),
        );
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  /// The replacement text of [match] text: with regular expressions,
  /// `$1`…`$9` insert groups and `$$` a dollar sign.
  static String expand(
    String matched,
    String replacement,
    RegExp re, {
    required bool useRegex,
  }) {
    if (!useRegex || !replacement.contains(r'$')) return replacement;
    final m = re.matchAsPrefix(matched);
    if (m == null) return replacement;
    return replacement.replaceAllMapped(RegExp(r'\$(\$|\d)'), (x) {
      final g = x.group(1)!;
      if (g == r'$') return r'$';
      final i = int.parse(g);
      return i <= m.groupCount ? (m.group(i) ?? '') : '';
    });
  }

  /// [json] with the ranges `(start, length, replacement)` replaced (plain
  /// text offsets; ranges must not overlap). The replacement takes the
  /// inline attributes of the first replaced character; paragraph
  /// attributes stay. The result is normalized ([notes] = notes schema).
  static String replaceRanges(
    String json,
    List<(int, int, String)> ranges, {
    bool notes = false,
  }) {
    var doc = SlidesText.parse(json);
    final sorted = [...ranges]..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (start, length, text) in sorted) {
      final attrs = _inlineAt(doc, start);
      final change = Delta()..retain(start);
      if (length > 0) change.delete(length);
      final insert = text.replaceAll('\n', ' ');
      if (insert.isNotEmpty) change.insert(insert, attrs);
      doc = doc.compose(change);
    }
    return SlidesText.encode(SlidesText.normalize(doc, notes: notes));
  }

  static Map<String, dynamic>? _inlineAt(Delta doc, int offset) {
    var at = 0;
    for (final op in doc.operations) {
      final len = op.length ?? 0;
      if (offset < at + len) {
        final a = op.attributes;
        if (a == null) return null;
        final inline = {
          for (final e in a.entries)
            if (!SlidesText.isBlockAttribute(e.key)) e.key: e.value,
        };
        return inline.isEmpty ? null : inline;
      }
      at += len;
    }
    return null;
  }
}
