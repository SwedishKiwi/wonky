import 'dart:math' as math;

import 'package:wonky_core/diff.dart';

import '../code_tokenizer.dart';
import '../default_code_tokenizer.dart';
import '../layout/code_layout.dart';
import '../syntax_token.dart';
import 'code_lexemes.dart';

/// One lexeme of a [TokenMorphPlan]: matched (in both states), removed
/// (only in the old one) or added (only in the new one).
final class MorphLexeme {
  const MorphLexeme({
    required this.text,
    this.from,
    this.to,
    this.fromToken,
    this.toToken,
    this.fromPos,
    this.toPos,
  });

  /// The lexeme text (equal in both states when matched).
  final String text;

  /// Offset in the old text, or null when added.
  final int? from;

  /// Offset in the new text, or null when removed.
  final int? to;

  /// Token classes (a matched lexeme may change class: its color
  /// interpolates).
  final SyntaxToken? fromToken;
  final SyntaxToken? toToken;

  /// Grid positions in the old / new layout.
  final GridPos? fromPos;
  final GridPos? toPos;

  bool get isMatched => from != null && to != null;
  bool get isRemoved => to == null;
  bool get isAdded => from == null;

  @override
  String toString() =>
      'MorphLexeme("$text" ${fromPos ?? '-'} → ${toPos ?? '-'})';
}

/// A lexeme's look at one moment of a morph.
final class MorphGlyph {
  const MorphGlyph({
    required this.lexeme,
    required this.x,
    required this.y,
    required this.opacity,
    required this.colorMix,
    required this.fontSize,
  });

  final MorphLexeme lexeme;

  /// Left edge (su, relative to the code area).
  final double x;

  /// Top of the row (su, relative to the code area; drift included).
  final double y;

  /// 0..1.
  final double opacity;

  /// 0 = old token color, 1 = new (interpolate in OKLab: [oklabLerp]).
  final double colorMix;

  /// Font size (su; interpolates when the auto size differs).
  final double fontSize;
}

/// The morph mode (Slides 07 §5.6): unchanged lexemes glide from their old
/// grid position to the new one, removed lexemes fade out drifting up during
/// the first 50 %, added ones fade in settling from below during the last
/// 60 %.
///
/// Matching: equal lines match their lexemes directly; the lexemes of each
/// changed hunk are matched with [SequenceDiff] over their text; leftover
/// identical lexemes then match greedily by nearest grid distance (moved
/// lines, swapped blocks). A class change still matches.
final class TokenMorphPlan {
  TokenMorphPlan._(
    this.lexemes,
    this.fromLayout,
    this.toLayout,
    this.durationMs,
    this.staggerMs,
  );

  /// Drift of removed / added lexemes (su).
  static const drift = 8.0;

  /// Hunks with more lexemes than this on a side skip the sequence diff
  /// (memory/time bound) and rely on nearest matching.
  static const maxDiffLexemes = 800;

  /// Groups of identical leftovers with more candidate pairs than this are
  /// paired in order instead of by distance.
  static const maxGreedyPairs = 20000;

  /// Plans the morph from [from] to [to]. Layouts default to unwrapped
  /// layouts with default options; pass the layouts of both states at their
  /// sizes so positions are in slide units.
  static TokenMorphPlan build(
    String from,
    String to, {
    String language = '',
    CodeTokenizer? tokenizer,
    List<CodeToken>? fromTokens,
    List<CodeToken>? toTokens,
    CodeLayout? fromLayout,
    CodeLayout? toLayout,
    int durationMs = 800,
    int staggerMs = 0,
  }) {
    final tk = tokenizer ?? DefaultCodeTokenizer.instance;
    final a = CodeLexer.lex(
      from,
      fromTokens ?? (language.isEmpty ? const [] : tk.tokenize(from, language)),
    );
    final b = CodeLexer.lex(
      to,
      toTokens ?? (language.isEmpty ? const [] : tk.tokenize(to, language)),
    );
    final la = fromLayout ?? CodeLayout.layout(from);
    final lb = toLayout ?? CodeLayout.layout(to);
    final match = _match(from, to, a, b, la, lb);
    final out = <MorphLexeme>[];
    final usedB = List<bool>.filled(b.length, false);
    for (var i = 0; i < a.length; i++) {
      final j = match[i];
      final x = a[i];
      if (j >= 0) {
        usedB[j] = true;
        final y = b[j];
        out.add(
          MorphLexeme(
            text: y.text,
            from: x.start,
            to: y.start,
            fromToken: x.token,
            toToken: y.token,
            fromPos: la.posOf(x.start),
            toPos: lb.posOf(y.start),
          ),
        );
      } else {
        out.add(
          MorphLexeme(
            text: x.text,
            from: x.start,
            fromToken: x.token,
            fromPos: la.posOf(x.start),
          ),
        );
      }
    }
    for (var j = 0; j < b.length; j++) {
      if (usedB[j]) continue;
      final y = b[j];
      out.add(
        MorphLexeme(
          text: y.text,
          to: y.start,
          toToken: y.token,
          toPos: lb.posOf(y.start),
        ),
      );
    }
    return TokenMorphPlan._(out, la, lb, durationMs, staggerMs);
  }

  /// Every lexeme (matched and removed in old order, then added).
  final List<MorphLexeme> lexemes;

  /// Layout of the old / new state.
  final CodeLayout fromLayout;
  final CodeLayout toLayout;

  /// Duration of one lexeme's animation (ms).
  final int durationMs;

  /// Delay per row (ms).
  final int staggerMs;

  Iterable<MorphLexeme> get matched => lexemes.where((l) => l.isMatched);
  Iterable<MorphLexeme> get removed => lexemes.where((l) => l.isRemoved);
  Iterable<MorphLexeme> get added => lexemes.where((l) => l.isAdded);

  /// Total duration incl. the stagger.
  int get totalDurationMs =>
      durationMs +
      staggerMs *
          math.max(0, math.max(fromLayout.rowCount, toLayout.rowCount) - 1);

  /// The glyphs at [ms] (clamped to `[0, totalDurationMs]`).
  List<MorphGlyph> frameAt(num ms) {
    final fs0 = fromLayout.options.fontSize, fs1 = toLayout.options.fontSize;
    final out = <MorphGlyph>[];
    for (final l in lexemes) {
      final row = l.toPos?.row ?? l.fromPos!.row;
      final local = durationMs <= 0
          ? 1.0
          : ((ms - row * staggerMs) / durationMs).clamp(0.0, 1.0);
      final e = easeInOutCubic(local);
      final size = fs0 + (fs1 - fs0) * e;
      if (l.isMatched) {
        final x0 = fromLayout.xOf(l.fromPos!.column);
        final y0 = fromLayout.yOf(l.fromPos!.row);
        final x1 = toLayout.xOf(l.toPos!.column);
        final y1 = toLayout.yOf(l.toPos!.row);
        out.add(
          MorphGlyph(
            lexeme: l,
            x: x0 + (x1 - x0) * e,
            y: y0 + (y1 - y0) * e,
            opacity: 1,
            colorMix: e,
            fontSize: size,
          ),
        );
      } else if (l.isRemoved) {
        final q = (local / 0.5).clamp(0.0, 1.0);
        if (q >= 1) continue;
        out.add(
          MorphGlyph(
            lexeme: l,
            x: fromLayout.xOf(l.fromPos!.column),
            y: fromLayout.yOf(l.fromPos!.row) - drift * easeInOutCubic(q),
            opacity: 1 - q,
            colorMix: 0,
            fontSize: size,
          ),
        );
      } else {
        final q = ((local - 0.4) / 0.6).clamp(0.0, 1.0);
        if (q <= 0) continue;
        out.add(
          MorphGlyph(
            lexeme: l,
            x: toLayout.xOf(l.toPos!.column),
            y: toLayout.yOf(l.toPos!.row) + drift * (1 - easeInOutCubic(q)),
            opacity: q,
            colorMix: 1,
            fontSize: size,
          ),
        );
      }
    }
    return out;
  }

  /// The default morph easing (`easeInOutCubic`).
  static double easeInOutCubic(double x) {
    final t = x.clamp(0.0, 1.0);
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  /// For each old lexeme the matched new index, or −1.
  static List<int> _match(
    String from,
    String to,
    List<CodeLexeme> a,
    List<CodeLexeme> b,
    CodeLayout la,
    CodeLayout lb,
  ) {
    final match = List<int>.filled(a.length, -1);
    final matchedB = List<bool>.filled(b.length, false);
    // Lexeme index ranges per line.
    final aLines = _byLine(a, la), bLines = _byLine(b, lb);
    final oldLines = from.split('\n'), newLines = to.split('\n');
    final ops = SequenceDiff.diff(oldLines, newLines);

    void diffRange(int a0, int a1, int b0, int b1) {
      if (a0 >= a1 || b0 >= b1) return;
      if (a1 - a0 > maxDiffLexemes || b1 - b0 > maxDiffLexemes) return;
      final xs = [for (var i = a0; i < a1; i++) a[i].text];
      final ys = [for (var j = b0; j < b1; j++) b[j].text];
      var i = a0, j = b0;
      for (final o in SequenceDiff.diff(xs, ys)) {
        switch (o) {
          case DiffOp.equal:
            match[i] = j;
            matchedB[j] = true;
            i++;
            j++;
          case DiffOp.delete:
            i++;
          case DiffOp.insert:
            j++;
        }
      }
    }

    var li = 0, lj = 0, k = 0;
    while (k < ops.length) {
      if (ops[k] == DiffOp.equal) {
        diffRange(aLines[li].$1, aLines[li].$2, bLines[lj].$1, bLines[lj].$2);
        li++;
        lj++;
        k++;
        continue;
      }
      final li0 = li, lj0 = lj;
      while (k < ops.length && ops[k] != DiffOp.equal) {
        if (ops[k] == DiffOp.delete) {
          li++;
        } else {
          lj++;
        }
        k++;
      }
      if (li > li0 && lj > lj0) {
        diffRange(
          aLines[li0].$1,
          aLines[li - 1].$2,
          bLines[lj0].$1,
          bLines[lj - 1].$2,
        );
      }
    }

    // Leftovers: identical texts, nearest first.
    final leftA = <String, List<int>>{}, leftB = <String, List<int>>{};
    for (var i = 0; i < a.length; i++) {
      if (match[i] < 0) (leftA[a[i].text] ??= []).add(i);
    }
    for (var j = 0; j < b.length; j++) {
      if (!matchedB[j]) (leftB[b[j].text] ??= []).add(j);
    }
    final pa = [for (final x in a) la.posOf(x.start)];
    final pb = [for (final y in b) lb.posOf(y.start)];
    final keys = leftA.keys.where(leftB.containsKey).toList()..sort();
    for (final text in keys) {
      final xs = leftA[text]!, ys = leftB[text]!;
      if (xs.length * ys.length > maxGreedyPairs) {
        for (var n = 0; n < math.min(xs.length, ys.length); n++) {
          match[xs[n]] = ys[n];
          matchedB[ys[n]] = true;
        }
        continue;
      }
      final pairs = <(double, int, int)>[];
      for (final i in xs) {
        final x0 = la.xOf(pa[i].column), y0 = la.yOf(pa[i].row);
        for (final j in ys) {
          final dx = lb.xOf(pb[j].column) - x0, dy = lb.yOf(pb[j].row) - y0;
          pairs.add((dx * dx + dy * dy, i, j));
        }
      }
      pairs.sort((p, q) {
        final c = p.$1.compareTo(q.$1);
        if (c != 0) return c;
        final d = p.$2.compareTo(q.$2);
        return d != 0 ? d : p.$3.compareTo(q.$3);
      });
      for (final (_, i, j) in pairs) {
        if (match[i] >= 0 || matchedB[j]) continue;
        match[i] = j;
        matchedB[j] = true;
      }
    }
    return match;
  }

  /// Per physical line, the lexeme index range `[start, end)`.
  static List<(int, int)> _byLine(List<CodeLexeme> lex, CodeLayout layout) {
    final out = List<(int, int)>.filled(layout.lineCount, (0, 0));
    var k = 0;
    for (var line = 0; line < layout.lineCount; line++) {
      final next = line + 1 < layout.lineCount
          ? layout.lines[line + 1].start
          : 1 << 62;
      final s = k;
      while (k < lex.length && lex[k].start < next) {
        k++;
      }
      out[line] = (s, k);
    }
    return out;
  }
}

/// Interpolates two ARGB colors in OKLab (07 §5.6: matched lexemes whose
/// class changes).
int oklabLerp(int a, int b, double t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  final la = _toOklab(a), lb = _toOklab(b);
  final l = la.$1 + (lb.$1 - la.$1) * t;
  final m = la.$2 + (lb.$2 - la.$2) * t;
  final s = la.$3 + (lb.$3 - la.$3) * t;
  final alpha = ((a >>> 24) + (((b >>> 24) - (a >>> 24)) * t)).round();
  return (alpha << 24) | _fromOklab(l, m, s);
}

double _toLinear(int c) {
  final v = c / 255;
  return v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

int _fromLinear(double linear) {
  final v = linear.clamp(0.0, 1.0);
  final c = v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  return (c * 255).round().clamp(0, 255);
}

(double, double, double) _toOklab(int argb) {
  final r = _toLinear((argb >> 16) & 0xFF);
  final g = _toLinear((argb >> 8) & 0xFF);
  final b = _toLinear(argb & 0xFF);
  final l = math.pow(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    1 / 3,
  );
  final m = math.pow(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    1 / 3,
  );
  final s = math.pow(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    1 / 3,
  );
  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

int _fromOklab(double lightness, double a, double b) {
  final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3);
  final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3);
  final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3);
  final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
  return (_fromLinear(r) << 16) | (_fromLinear(g) << 8) | _fromLinear(bl);
}
