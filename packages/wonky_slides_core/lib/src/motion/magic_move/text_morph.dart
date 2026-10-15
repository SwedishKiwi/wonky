/// Text glyph morphs of Magic Move (06 §8.4 "Text — word / character",
/// §9.5): both texts are split into words or grapheme clusters, aligned
/// with the shared Myers diff (`wonky_core` `SequenceDiff`), and matched
/// characters are grouped into **runs** — maximal ranges that are
/// consecutive in both texts and lie on one line and one style run in both
/// layouts. A run moves from its old box to the new one (scaled by the
/// font-size ratio, color interpolated); unmatched ranges fade out (old) or
/// in (new).
library;

import 'package:wonky_core/diff.dart';

import '../../scene/nodes/text_layout.dart';
import '../../text_layout/slide_text_layout.dart' show ApproxTextMeasurer;
import '../../theme/model/common.dart' show SuRect;
import '../builds/parts.dart' show TextParts, TextPartRange;
import 'magic_move_slide.dart' show MagicMoveText;

double _r(double v) => (v * 1e6).roundToDouble() / 1e6;

List<double> _box(SuRect b) => [_r(b.x), _r(b.y), _r(b.width), _r(b.height)];

/// A matched glyph run: `[fromStart, fromEnd)` of the old text moves to
/// `[toStart, toEnd)` of the new one (same characters).
final class TextMorphRun {
  /// Creates a run.
  const TextMorphRun({
    required this.fromStart,
    required this.fromEnd,
    required this.toStart,
    required this.toEnd,
    required this.fromBox,
    required this.toBox,
    required this.fromFontSize,
    required this.toFontSize,
    required this.fromColor,
    required this.toColor,
  });

  final int fromStart, fromEnd, toStart, toEnd;

  /// Element-local boxes (su) in the old / new element.
  final SuRect fromBox, toBox;
  final double fromFontSize, toFontSize;

  /// ARGB.
  final int fromColor, toColor;

  /// New font size / old font size (the glyph scale at the end).
  double get scale => fromFontSize <= 0 ? 1 : toFontSize / fromFontSize;

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'from': [fromStart, fromEnd],
    'to': [toStart, toEnd],
    'fromBox': _box(fromBox),
    'toBox': _box(toBox),
    if (scale != 1) 'scale': _r(scale),
    if (fromColor != toColor) 'colors': [fromColor, toColor],
  };
}

/// An unmatched range of one text (fades out or in).
final class TextMorphSpan {
  /// Creates a span.
  const TextMorphSpan(this.start, this.end);

  final int start, end;

  /// Canonical JSON.
  List<int> toJson() => [start, end];
}

/// The aligned glyph runs of two texts.
final class TextMorph {
  TextMorph._(this.level, this.runs, this.removed, this.added);

  /// Texts longer than this use word alignment at `character` level
  /// (06 §8.5).
  static const maxCharacters = 2000;

  /// `word` or `character` (after the fallback).
  final String level;
  final List<TextMorphRun> runs;

  /// Unmatched ranges of the old text.
  final List<TextMorphSpan> removed;

  /// Unmatched ranges of the new text.
  final List<TextMorphSpan> added;

  /// Characters matched (both texts).
  int get matchedLength => runs.fold(0, (a, r) => a + r.fromEnd - r.fromStart);

  /// Aligns [a] with [b] at [level] (`word` or `character`; identical
  /// texts align character by character). Null when either text has no
  /// layout.
  static TextMorph? build(MagicMoveText a, MagicMoveText b, String level) {
    final la = a.layout, lb = b.layout;
    if (la == null || lb == null) return null;
    var lv = level == 'character' ? 'character' : 'word';
    if (lv == 'character' &&
        (a.plain.length > maxCharacters || b.plain.length > maxCharacters)) {
      lv = 'word';
    }
    final ga = _Glyphs(a, la), gb = _Glyphs(b, lb);
    // Matched character pairs (a offset → b offset), in order.
    final pairs = <(int, int)>[];
    if (a.plain == b.plain) {
      for (var i = 0; i < a.plain.length; i++) {
        pairs.add((i, i));
      }
    } else {
      final ta = lv == 'word'
          ? TextParts.words(a.plain)
          : TextParts.characters(a.plain);
      final tb = lv == 'word'
          ? TextParts.words(b.plain)
          : TextParts.characters(b.plain);
      String text(String s, TextPartRange r) => s.substring(r.start, r.end);
      final xa = [for (final r in ta) text(a.plain, r)];
      final xb = [for (final r in tb) text(b.plain, r)];
      final ops = SequenceDiff.diff(xa, xb);
      var i = 0, j = 0;
      TextPartRange? prevA, prevB;
      for (final op in ops) {
        switch (op) {
          case DiffOp.equal:
            final ra = ta[i], rb = tb[j];
            // The gap since the previous matched token joins the run when
            // it is the same in both texts (spaces between matched words).
            if (prevA != null && prevB != null) {
              final gapA = a.plain.substring(prevA.end, ra.start);
              final gapB = b.plain.substring(prevB.end, rb.start);
              if (gapA == gapB) {
                for (var k = 0; k < gapA.length; k++) {
                  pairs.add((prevA.end + k, prevB.end + k));
                }
              }
            }
            for (var k = 0; k < ra.end - ra.start; k++) {
              pairs.add((ra.start + k, rb.start + k));
            }
            prevA = ra;
            prevB = rb;
            i++;
            j++;
          case DiffOp.delete:
            prevA = null;
            i++;
          case DiffOp.insert:
            prevB = null;
            j++;
        }
      }
    }

    // Group into runs.
    final runs = <TextMorphRun>[];
    final usedA = List<bool>.filled(a.plain.length, false);
    final usedB = List<bool>.filled(b.plain.length, false);
    var k = 0;
    while (k < pairs.length) {
      final (sa, sb) = pairs[k];
      final pa = ga.pieceOf(sa), pb = gb.pieceOf(sb);
      if (pa < 0 || pb < 0) {
        k++;
        continue;
      }
      var ea = sa + 1, eb = sb + 1;
      k++;
      while (k < pairs.length) {
        final (na, nb) = pairs[k];
        if (na != ea || nb != eb) break;
        if (ga.pieceOf(na) != pa || gb.pieceOf(nb) != pb) break;
        ea++;
        eb++;
        k++;
      }
      for (var x = sa; x < ea; x++) {
        usedA[x] = true;
      }
      for (var x = sb; x < eb; x++) {
        usedB[x] = true;
      }
      if (_blank(a.plain, sa, ea)) continue;
      final ra = ga.run(pa), rb = gb.run(pb);
      runs.add(
        TextMorphRun(
          fromStart: sa,
          fromEnd: ea,
          toStart: sb,
          toEnd: eb,
          fromBox: ga.box(pa, sa, ea),
          toBox: gb.box(pb, sb, eb),
          fromFontSize: ra.fontSize,
          toFontSize: rb.fontSize,
          fromColor: ra.color,
          toColor: rb.color,
        ),
      );
    }
    return TextMorph._(
      lv,
      runs,
      _spans(a.plain, usedA),
      _spans(b.plain, usedB),
    );
  }

  static bool _blank(String s, int start, int end) =>
      s.substring(start, end).trim().isEmpty;

  static bool _space(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0;

  /// Maximal unused ranges, trimmed of whitespace.
  static List<TextMorphSpan> _spans(String s, List<bool> used) {
    final out = <TextMorphSpan>[];
    var i = 0;
    while (i < s.length) {
      if (used[i]) {
        i++;
        continue;
      }
      var start = i;
      while (i < s.length && !used[i]) {
        i++;
      }
      var end = i;
      while (start < end && _space(s.codeUnitAt(start))) {
        start++;
      }
      while (end > start && _space(s.codeUnitAt(end - 1))) {
        end--;
      }
      if (end > start) out.add(TextMorphSpan(start, end));
    }
    return out;
  }

  /// Canonical JSON.
  Map<String, Object?> toJson() => {
    'level': level,
    'runs': [for (final r in runs) r.toJson()],
    'removed': [for (final s in removed) s.toJson()],
    'added': [for (final s in added) s.toJson()],
  };
}

/// Character → (line, run) pieces of one laid-out text.
final class _Glyphs {
  _Glyphs(this.text, this.layout) {
    _piece = List<int>.filled(text.plain.length, -1);
    for (var li = 0; li < layout.lines.length; li++) {
      final line = layout.lines[li];
      for (var ri = 0; ri < line.runs.length; ri++) {
        final r = line.runs[ri];
        final id = _runs.length;
        _runs.add((li, ri));
        final end = r.start + r.text.length;
        for (var c = r.start; c < end && c < _piece.length; c++) {
          if (c >= 0) _piece[c] = id;
        }
      }
    }
  }

  final MagicMoveText text;
  final TextLayoutResult layout;
  final _runs = <(int, int)>[];
  late final List<int> _piece;

  /// The piece (line + run) of character [offset], or −1 (not laid out).
  int pieceOf(int offset) =>
      offset >= 0 && offset < _piece.length ? _piece[offset] : -1;

  TextRunBox run(int piece) {
    final (li, ri) = _runs[piece];
    return layout.lines[li].runs[ri];
  }

  /// The element-local box of `[start, end)` within [piece].
  SuRect box(int piece, int start, int end) {
    final exact = text.rangeBox?.call(start, end);
    if (exact != null) return exact;
    final (li, ri) = _runs[piece];
    final line = layout.lines[li];
    final r = line.runs[ri];
    double adv(int from, int to) {
      var w = 0.0;
      for (var i = from; i < to && i < r.text.length; i++) {
        w += ApproxTextMeasurer.advance(r.text.codeUnitAt(i));
      }
      return w;
    }

    final total = adv(0, r.text.length);
    final s = start - r.start, e = end - r.start;
    final x0 = total <= 0 ? 0.0 : r.width * adv(0, s) / total;
    final x1 = total <= 0 ? r.width : r.width * adv(0, e) / total;
    return SuRect(
      text.originX + line.left + r.x + x0,
      text.originY + line.top,
      x1 - x0,
      line.height,
    );
  }
}
