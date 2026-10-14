/// Kind of a [DiffLine].
enum DiffOp {
  /// The line is in both texts.
  equal,

  /// Only in the new text.
  insert,

  /// Only in the old text.
  delete,
}

/// One line of a line diff.
final class DiffLine {
  /// Creates a line.
  const DiffLine(this.op, this.text, {this.oldLine, this.newLine});

  /// What happened to the line.
  final DiffOp op;

  /// The line text (without the line break).
  final String text;

  /// 1-based line number in the old text (null for inserts).
  final int? oldLine;

  /// 1-based line number in the new text (null for deletes).
  final int? newLine;

  @override
  String toString() => switch (op) {
    DiffOp.equal => '  $text',
    DiffOp.insert => '+ $text',
    DiffOp.delete => '- $text',
  };
}

/// Line diffs (Myers' O(ND) algorithm) and a three-way merge, used by the
/// script editor's *Compare* and *Merge* (Sheets 09 §14.3).
abstract final class LineDiff {
  /// Splits [text] into lines (`\r\n` and `\n`).
  static List<String> lines(String text) =>
      text.isEmpty ? const [] : text.replaceAll('\r\n', '\n').split('\n');

  /// The shortest edit script from [oldText] to [newText], line by line.
  static List<DiffLine> diff(String oldText, String newText) =>
      diffLines(lines(oldText), lines(newText));

  /// [diff] over pre-split lines.
  static List<DiffLine> diffLines(List<String> a, List<String> b) {
    // Common prefix and suffix are cheap and keep the search small.
    var start = 0;
    while (start < a.length && start < b.length && a[start] == b[start]) {
      start++;
    }
    var endA = a.length, endB = b.length;
    while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
      endA--;
      endB--;
    }
    final out = <DiffLine>[
      for (var i = 0; i < start; i++)
        DiffLine(DiffOp.equal, a[i], oldLine: i + 1, newLine: i + 1),
    ];
    final middle = _myers(a.sublist(start, endA), b.sublist(start, endB));
    var ia = start, ib = start;
    for (final op in middle) {
      switch (op) {
        case DiffOp.equal:
          out.add(DiffLine(op, a[ia], oldLine: ia + 1, newLine: ib + 1));
          ia++;
          ib++;
        case DiffOp.delete:
          out.add(DiffLine(op, a[ia], oldLine: ia + 1));
          ia++;
        case DiffOp.insert:
          out.add(DiffLine(op, b[ib], newLine: ib + 1));
          ib++;
      }
    }
    for (var i = endA; i < a.length; i++) {
      out.add(
        DiffLine(
          DiffOp.equal,
          a[i],
          oldLine: i + 1,
          newLine: ib + 1 + i - endA,
        ),
      );
    }
    return out;
  }

  /// Myers' greedy algorithm with a trace for backtracking. Returns the
  /// operations in order.
  static List<DiffOp> _myers(List<String> a, List<String> b) {
    final n = a.length, m = b.length;
    if (n == 0) return List.filled(m, DiffOp.insert);
    if (m == 0) return List.filled(n, DiffOp.delete);
    final max = n + m;
    final offset = max;
    var v = List<int>.filled(2 * max + 2, 0);
    final trace = <List<int>>[];
    var found = false;
    for (var d = 0; d <= max && !found; d++) {
      trace.add(List.of(v));
      for (var k = -d; k <= d; k += 2) {
        int x;
        if (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) {
          x = v[offset + k + 1];
        } else {
          x = v[offset + k - 1] + 1;
        }
        var y = x - k;
        while (x < n && y < m && a[x] == b[y]) {
          x++;
          y++;
        }
        v[offset + k] = x;
        if (x >= n && y >= m) {
          found = true;
          break;
        }
      }
    }
    // Backtrack.
    final ops = <DiffOp>[];
    var x = n, y = m;
    for (var d = trace.length - 1; d >= 0; d--) {
      v = trace[d];
      final k = x - y;
      int prevK;
      if (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) {
        prevK = k + 1;
      } else {
        prevK = k - 1;
      }
      final prevX = v[offset + prevK];
      final prevY = prevX - prevK;
      while (x > prevX && y > prevY) {
        ops.add(DiffOp.equal);
        x--;
        y--;
      }
      if (d > 0) {
        if (x == prevX) {
          ops.add(DiffOp.insert);
          y--;
        } else {
          ops.add(DiffOp.delete);
          x--;
        }
      }
    }
    return ops.reversed.toList();
  }

  /// Three-way merge of [mine] and [theirs] against their common [base]
  /// (09 §14.3 *Merge*): changes of one side apply; changes of both sides
  /// to the same lines are kept as a conflict block
  /// (`<<<<<<< yours` / `=======` / `>>>>>>> theirs`).
  static MergeResult merge3(String base, String mine, String theirs) {
    final b = lines(base), x = lines(mine), y = lines(theirs);
    final hx = _hunks(b, x), hy = _hunks(b, y);
    final out = <String>[];
    final conflicts = <int>[];
    var pos = 0; // next base line to copy
    var i = 0, j = 0;
    while (i < hx.length || j < hy.length) {
      final nx = i < hx.length ? hx[i] : null;
      final ny = j < hy.length ? hy[j] : null;
      // Take the hunk that starts first; overlapping hunks merge into one
      // region (adjacent insertions at the same base line also conflict).
      _Hunk? only;
      if (nx != null && (ny == null || _before(nx, ny))) {
        only = nx;
      } else if (ny != null && (nx == null || _before(ny, nx))) {
        only = ny;
      }
      if (only != null) {
        out.addAll(b.sublist(pos, only.baseStart));
        out.addAll(only.lines);
        pos = only.baseEnd;
        if (identical(only, nx)) {
          i++;
        } else {
          j++;
        }
        continue;
      }
      // Overlap: grow the region until no hunk of either side touches it.
      var start = nx!.baseStart < ny!.baseStart ? nx.baseStart : ny.baseStart;
      var end = nx.baseEnd > ny.baseEnd ? nx.baseEnd : ny.baseEnd;
      final xs = <_Hunk>[nx], ys = <_Hunk>[ny];
      i++;
      j++;
      var grew = true;
      while (grew) {
        grew = false;
        while (i < hx.length && _touches(hx[i], start, end)) {
          xs.add(hx[i]);
          end = hx[i].baseEnd > end ? hx[i].baseEnd : end;
          i++;
          grew = true;
        }
        while (j < hy.length && _touches(hy[j], start, end)) {
          ys.add(hy[j]);
          end = hy[j].baseEnd > end ? hy[j].baseEnd : end;
          j++;
          grew = true;
        }
      }
      start = start < pos ? pos : start;
      final mineText = _apply(b, start, end, xs);
      final theirsText = _apply(b, start, end, ys);
      out.addAll(b.sublist(pos, start));
      if (_same(mineText, theirsText)) {
        out.addAll(mineText);
      } else {
        conflicts.add(out.length + 1);
        out
          ..add('<<<<<<< yours')
          ..addAll(mineText)
          ..add('=======')
          ..addAll(theirsText)
          ..add('>>>>>>> theirs');
      }
      pos = end;
    }
    out.addAll(b.sublist(pos));
    return MergeResult(out.join('\n'), conflicts);
  }

  static bool _before(_Hunk a, _Hunk b) =>
      a.baseEnd < b.baseStart ||
      (a.baseEnd == b.baseStart &&
          !(a.baseStart == a.baseEnd && b.baseStart == b.baseEnd) &&
          a.baseStart < b.baseStart);

  static bool _touches(_Hunk h, int start, int end) =>
      h.baseStart < end ||
      (h.baseStart == end && h.baseStart == h.baseEnd) ||
      (h.baseStart <= start && h.baseEnd >= start);

  static List<String> _apply(
    List<String> base,
    int start,
    int end,
    List<_Hunk> hunks,
  ) {
    final out = <String>[];
    var pos = start;
    for (final h in hunks) {
      if (h.baseStart > pos) out.addAll(base.sublist(pos, h.baseStart));
      out.addAll(h.lines);
      pos = h.baseEnd > pos ? h.baseEnd : pos;
    }
    if (pos < end) out.addAll(base.sublist(pos, end));
    return out;
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Changed regions of [b] → [other]: base range `[baseStart, baseEnd)`
  /// replaced by [_Hunk.lines].
  static List<_Hunk> _hunks(List<String> base, List<String> other) {
    final d = diffLines(base, other);
    final out = <_Hunk>[];
    var bi = 0;
    _Hunk? cur;
    for (final l in d) {
      switch (l.op) {
        case DiffOp.equal:
          if (cur != null) {
            out.add(cur);
            cur = null;
          }
          bi++;
        case DiffOp.delete:
          cur ??= _Hunk(bi);
          bi++;
          cur.baseEnd = bi;
        case DiffOp.insert:
          cur ??= _Hunk(bi);
          cur.lines.add(l.text);
      }
    }
    if (cur != null) out.add(cur);
    return out;
  }
}

final class _Hunk {
  _Hunk(this.baseStart) : baseEnd = baseStart;
  final int baseStart;
  int baseEnd;
  final List<String> lines = [];
}

/// The result of [LineDiff.merge3].
final class MergeResult {
  /// Creates a result.
  const MergeResult(this.text, this.conflictLines);

  /// The merged text (conflicts marked).
  final String text;

  /// 1-based lines of the `<<<<<<< yours` markers.
  final List<int> conflictLines;

  /// Whether the merge has conflicts.
  bool get hasConflicts => conflictLines.isNotEmpty;
}
