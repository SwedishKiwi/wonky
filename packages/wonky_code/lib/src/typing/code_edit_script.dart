import 'dart:math' as math;

import 'package:wonky_core/diff.dart';

import '../code_tokenizer.dart';
import '../default_code_tokenizer.dart';
import '../layout/code_columns.dart';
import '../morph/code_lexemes.dart';

/// Kind of a [CodeEdit].
enum CodeEditKind {
  /// Text is added at a position.
  insert,

  /// Text is removed.
  delete,

  /// Text is removed and other text added in its place.
  replace,
}

/// One edit of a [CodeEditScript]: replace `old[oldStart, oldEnd)` with
/// [newText]. Offsets are UTF-16 offsets into the **old** text.
final class CodeEdit {
  /// Creates an edit.
  const CodeEdit({
    required this.oldStart,
    required this.oldEnd,
    required this.newText,
    required this.lineIndex,
  });

  final int oldStart;
  final int oldEnd;
  final String newText;

  /// 0-based line of the old text where the edit starts.
  final int lineIndex;

  /// Kind derived from the ranges.
  CodeEditKind get kind => oldStart == oldEnd
      ? CodeEditKind.insert
      : newText.isEmpty
      ? CodeEditKind.delete
      : CodeEditKind.replace;

  /// UTF-16 units removed.
  int get deleteLength => oldEnd - oldStart;

  /// Change of the text length.
  int get delta => newText.length - deleteLength;

  @override
  bool operator ==(Object other) =>
      other is CodeEdit &&
      other.oldStart == oldStart &&
      other.oldEnd == oldEnd &&
      other.newText == newText &&
      other.lineIndex == lineIndex;

  @override
  int get hashCode => Object.hash(oldStart, oldEnd, newText, lineIndex);

  @override
  String toString() =>
      'CodeEdit(${kind.name} [$oldStart, $oldEnd) → "$newText", line $lineIndex)';
}

/// Line counts of a change (the state strip's "+3 −1 vs. state 1").
final class CodeDiffStats {
  const CodeDiffStats({
    required this.added,
    required this.removed,
    required this.changed,
  });

  /// New lines without an old counterpart.
  final int added;

  /// Old lines without a new counterpart.
  final int removed;

  /// Lines edited in place (paired lines).
  final int changed;
}

/// The edits that turn one code state into the next (Slides 07 §5.2), in
/// document order:
///
/// 1. a line diff ([SequenceDiff], Myers) → equal / delete / insert runs;
/// 2. in each replace hunk, old and new lines are paired in order when their
///    character similarity (`1 − editDistance / max(len)` over grapheme
///    clusters, a substitution counting once) is ≥ 0.4; unpaired lines are
///    deleted / inserted whole;
/// 3. paired lines get a character diff (Myers on graphemes);
/// 4. token snapping: an edit changing more than half of a lexeme (token
///    span, word or punctuation) of the old or new line widens to the whole
///    lexeme; edits closer than 3 kept graphemes on a line merge.
///
/// Deterministic; it depends on the tokenizer only through step 4.
final class CodeEditScript {
  CodeEditScript._(this.from, this.to, this.edits, this.stats);

  /// The script from [from] to [to]. Tokens come from [tokenizer] (default
  /// [DefaultCodeTokenizer]) in [language], or are passed precomputed.
  static CodeEditScript compute(
    String from,
    String to, {
    String language = '',
    CodeTokenizer? tokenizer,
    List<CodeToken>? fromTokens,
    List<CodeToken>? toTokens,
  }) {
    if (from == to) {
      return CodeEditScript._(
        from,
        to,
        const [],
        const CodeDiffStats(added: 0, removed: 0, changed: 0),
      );
    }
    final tk = tokenizer ?? DefaultCodeTokenizer.instance;
    final oldLex = CodeLexer.lex(
      from,
      fromTokens ?? (language.isEmpty ? const [] : tk.tokenize(from, language)),
    );
    final newLex = CodeLexer.lex(
      to,
      toTokens ?? (language.isEmpty ? const [] : tk.tokenize(to, language)),
    );
    return _Builder(from, to, oldLex, newLex).build();
  }

  /// The old text.
  final String from;

  /// The new text.
  final String to;

  /// Edits in document order (non-overlapping; edits at one offset apply in
  /// list order).
  final List<CodeEdit> edits;

  /// Line statistics.
  final CodeDiffStats stats;

  /// Whether nothing changes.
  bool get isEmpty => edits.isEmpty;

  /// [text] (the old text) with every edit applied.
  String apply([String? text]) {
    final src = text ?? from;
    final b = StringBuffer();
    var pos = 0;
    for (final e in edits) {
      b
        ..write(src.substring(pos, e.oldStart))
        ..write(e.newText);
      pos = e.oldEnd;
    }
    b.write(src.substring(pos));
    return b.toString();
  }
}

/// Similarity threshold of line pairing.
const _pairThreshold = 0.4;

/// Edits closer than this many kept graphemes merge.
const _mergeGap = 3;

/// Pairing looks at most this many new lines ahead per old line.
const _pairWindow = 24;

enum _Op { keep, del, ins }

final class _Builder {
  _Builder(this.from, this.to, this.oldLex, this.newLex)
    : a = from.split('\n'),
      b = to.split('\n') {
    aStart = _starts(a);
    bStart = _starts(b);
  }

  final String from, to;
  final List<CodeLexeme> oldLex, newLex;
  final List<String> a, b;
  late final List<int> aStart, bStart;
  final edits = <CodeEdit>[];
  var added = 0, removed = 0, changed = 0;

  static List<int> _starts(List<String> lines) {
    final out = List<int>.filled(lines.length, 0);
    var pos = 0;
    for (var i = 0; i < lines.length; i++) {
      out[i] = pos;
      pos += lines[i].length + 1;
    }
    return out;
  }

  int aEnd(int i) => aStart[i] + a[i].length;

  CodeEditScript build() {
    final ops = SequenceDiff.diff(a, b);
    var i = 0, j = 0;
    var k = 0;
    while (k < ops.length) {
      if (ops[k] == DiffOp.equal) {
        i++;
        j++;
        k++;
        continue;
      }
      final i0 = i, j0 = j;
      while (k < ops.length && ops[k] != DiffOp.equal) {
        if (ops[k] == DiffOp.delete) {
          i++;
        } else {
          j++;
        }
        k++;
      }
      _hunk(i0, i, j0, j);
    }
    return CodeEditScript._(
      from,
      to,
      edits,
      CodeDiffStats(added: added, removed: removed, changed: changed),
    );
  }

  /// Old lines `[i0, i1)` become new lines `[j0, j1)`.
  void _hunk(int i0, int i1, int j0, int j1) {
    final pairs = <(int, int)>[];
    var jp = j0;
    final graphemes = <int, List<String>>{};
    List<String> g(List<String> lines, int base, int idx) =>
        graphemes[base + idx] ??= _graphemes(lines[idx]);
    for (var i = i0; i < i1 && jp < j1; i++) {
      final ga = g(a, 0, i);
      for (var j = jp; j < j1 && j < jp + _pairWindow; j++) {
        if (_similar(ga, g(b, 1 << 20, j))) {
          pairs.add((i, j));
          jp = j + 1;
          break;
        }
      }
    }
    var ci = i0, cj = j0;
    for (final (pi, pj) in [...pairs, (i1, j1)]) {
      _wholeLines(ci, pi, cj, pj);
      if (pi < i1) {
        _pairedLine(pi, pj, g(a, 0, pi), g(b, 1 << 20, pj));
        changed++;
      }
      ci = pi + 1;
      cj = pj + 1;
    }
  }

  /// Unpaired old lines `[i0, i1)` and new lines `[j0, j1)` at one spot.
  void _wholeLines(int i0, int i1, int j0, int j1) {
    if (i0 >= i1 && j0 >= j1) return;
    removed += i1 - i0;
    added += j1 - j0;
    final text = b.sublist(j0, j1).join('\n');
    if (i1 > i0 && j1 > j0) {
      _add(aStart[i0], aEnd(i1 - 1), text, i0);
    } else if (i1 > i0) {
      if (i1 < a.length) {
        _add(aStart[i0], aStart[i1], '', i0);
      } else if (i0 > 0) {
        _add(aEnd(i0 - 1), aEnd(i1 - 1), '', i0 - 1);
      } else {
        _add(0, aEnd(i1 - 1), '', 0);
      }
    } else {
      // Typed like an editor user: at the end of the previous line, Enter,
      // then the new lines (auto-indent brings the indentation along).
      if (i0 > 0) {
        _add(aEnd(i0 - 1), aEnd(i0 - 1), '\n$text', i0 - 1);
      } else {
        _add(0, 0, '$text\n', 0);
      }
    }
  }

  void _add(int start, int end, String text, int line) {
    if (start == end && text.isEmpty) return;
    edits.add(
      CodeEdit(oldStart: start, oldEnd: end, newText: text, lineIndex: line),
    );
  }

  static List<String> _graphemes(String s) {
    final bounds = CodeColumns.boundaries(s);
    return [
      for (var i = 0; i < bounds.length - 1; i++)
        s.substring(bounds[i], bounds[i + 1]),
    ];
  }

  /// Whether two lines are similar enough to pair: `1 − levenshtein /
  /// max(len) ≥ 0.4` over graphemes (a substitution counts once).
  static bool _similar(List<String> x, List<String> y) {
    final n = math.max(x.length, y.length);
    if (n == 0) return true;
    // The largest distance that still pairs.
    final limit = ((1 - _pairThreshold) * n + 1e-9).floor();
    // Cheap lower bounds: length difference and character multisets.
    if ((x.length - y.length).abs() > limit) return false;
    final counts = <String, int>{};
    for (final c in x) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    var common = 0;
    for (final c in y) {
      final k = counts[c];
      if (k != null && k > 0) {
        counts[c] = k - 1;
        common++;
      }
    }
    if (n - common > limit) return false;
    return _levenshteinWithin(x, y, limit);
  }

  /// Whether the Levenshtein distance of [x] and [y] is at most [limit]
  /// (rows stop early once every cell exceeds it).
  static bool _levenshteinWithin(List<String> x, List<String> y, int limit) {
    var prev = List<int>.generate(y.length + 1, (j) => j);
    var cur = List<int>.filled(y.length + 1, 0);
    for (var i = 1; i <= x.length; i++) {
      cur[0] = i;
      var rowMin = cur[0];
      final xi = x[i - 1];
      for (var j = 1; j <= y.length; j++) {
        final sub = prev[j - 1] + (xi == y[j - 1] ? 0 : 1);
        final del = prev[j] + 1, ins = cur[j - 1] + 1;
        final v = sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins);
        cur[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > limit) return false;
      final t = prev;
      prev = cur;
      cur = t;
    }
    return prev[y.length] <= limit;
  }

  /// Character-level edits of paired lines.
  void _pairedLine(int i, int j, List<String> ga, List<String> gb) {
    final ops = <_Op>[
      for (final o in SequenceDiff.diff(ga, gb))
        switch (o) {
          DiffOp.equal => _Op.keep,
          DiffOp.delete => _Op.del,
          DiffOp.insert => _Op.ins,
        },
    ];
    if (!ops.any((o) => o != _Op.keep)) return;
    // Grapheme → UTF-16 offset within the lines.
    final ao = _offsets(ga), bo = _offsets(gb);
    final lineA = aStart[i], lineB = bStart[j];
    final lexA = _lexemesIn(oldLex, lineA, lineA + a[i].length);
    final lexB = _lexemesIn(newLex, lineB, lineB + b[j].length);

    // Token snapping until stable.
    var current = ops;
    for (var round = 0; round < 4; round++) {
      final next = _snap(current, ao, bo, lineA, lineB, lexA, lexB);
      if (identical(next, current)) break;
      current = next;
    }
    current = _merge(current);

    // Extract runs.
    var x = 0, y = 0, k = 0;
    while (k < current.length) {
      if (current[k] == _Op.keep) {
        x++;
        y++;
        k++;
        continue;
      }
      final x0 = x, y0 = y;
      while (k < current.length && current[k] != _Op.keep) {
        if (current[k] == _Op.del) {
          x++;
        } else {
          y++;
        }
        k++;
      }
      _add(lineA + ao[x0], lineA + ao[x], b[j].substring(bo[y0], bo[y]), i);
    }
  }

  static List<int> _offsets(List<String> g) {
    final out = List<int>.filled(g.length + 1, 0);
    for (var i = 0; i < g.length; i++) {
      out[i + 1] = out[i] + g[i].length;
    }
    return out;
  }

  static List<CodeLexeme> _lexemesIn(List<CodeLexeme> lex, int start, int end) {
    // Binary search the first lexeme ending after start.
    var lo = 0, hi = lex.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (lex[mid].end <= start) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final out = <CodeLexeme>[];
    for (var k = lo; k < lex.length && lex[k].start < end; k++) {
      out.add(lex[k]);
    }
    return out;
  }

  /// One snapping pass: lexemes more than half changed become fully
  /// changed (their kept graphemes turn into delete + insert). Returns [ops]
  /// itself when nothing changes.
  static List<_Op> _snap(
    List<_Op> ops,
    List<int> ao,
    List<int> bo,
    int lineA,
    int lineB,
    List<CodeLexeme> lexA,
    List<CodeLexeme> lexB,
  ) {
    // Per alignment step: old / new grapheme index.
    final n = ops.length;
    final xs = List<int>.filled(n, -1), ys = List<int>.filled(n, -1);
    var x = 0, y = 0;
    for (var k = 0; k < n; k++) {
      switch (ops[k]) {
        case _Op.keep:
          xs[k] = x++;
          ys[k] = y++;
        case _Op.del:
          xs[k] = x++;
        case _Op.ins:
          ys[k] = y++;
      }
    }
    final forced = List<bool>.filled(n, false);
    var any = false;
    void side(
      List<CodeLexeme> lex,
      List<int> offs,
      int base,
      List<int> idx,
      _Op changedOp,
    ) {
      for (final l in lex) {
        final s = l.start - base, e = l.end - base;
        var total = 0, changedCount = 0;
        final keeps = <int>[];
        for (var k = 0; k < n; k++) {
          final gi = idx[k];
          if (gi < 0) continue;
          final o = offs[gi];
          if (o < s || o >= e) continue;
          total++;
          if (ops[k] == changedOp) {
            changedCount++;
          } else if (ops[k] == _Op.keep) {
            keeps.add(k);
          }
        }
        if (total > 0 && changedCount * 2 > total && keeps.isNotEmpty) {
          for (final k in keeps) {
            forced[k] = true;
          }
          any = true;
        }
      }
    }

    side(lexA, ao, lineA, xs, _Op.del);
    side(lexB, bo, lineB, ys, _Op.ins);
    if (!any) return ops;
    return _expand(ops, forced);
  }

  /// Replaces every forced keep with delete + insert.
  static List<_Op> _expand(List<_Op> ops, List<bool> forced) => [
    for (var k = 0; k < ops.length; k++)
      if (forced[k]) ...[_Op.del, _Op.ins] else ops[k],
  ];

  /// Merges edit runs separated by fewer than [_mergeGap] kept graphemes.
  static List<_Op> _merge(List<_Op> ops) {
    final forced = List<bool>.filled(ops.length, false);
    var lastChange = -1;
    var any = false;
    for (var k = 0; k < ops.length; k++) {
      if (ops[k] == _Op.keep) continue;
      if (lastChange >= 0) {
        final gap = k - lastChange - 1;
        if (gap > 0 && gap < _mergeGap) {
          for (var m = lastChange + 1; m < k; m++) {
            forced[m] = true;
          }
          any = true;
        }
      }
      lastChange = k;
    }
    return any ? _expand(ops, forced) : ops;
  }
}
