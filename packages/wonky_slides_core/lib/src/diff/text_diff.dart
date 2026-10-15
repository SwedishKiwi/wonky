import '../model/text/slides_text.dart';

/// One span of a [TextDiff].
enum TextDiffOp {
  /// In both texts.
  equal,

  /// Only in the newer text.
  insert,

  /// Only in the older text.
  delete,
}

/// A run of text with its [op].
typedef TextDiffSpan = ({TextDiffOp op, String text});

/// Word-level text diff of two text bodies (Slides 09 §4.2 step 4: the
/// inline text diff of a text change, insertions and deletions colored).
/// The bodies are compared as plain text, token by token (words,
/// whitespace runs and punctuation), with a longest common subsequence;
/// very long texts fall back to one deletion and one insertion around the
/// common prefix and suffix.
abstract final class TextDiff {
  /// Max product of token counts diffed with the LCS table.
  static const maxCells = 400000;

  /// The diff of two Slides text bodies (Delta JSON, `SlidesText`).
  static List<TextDiffSpan> ofBodies(String? before, String? after) => of(
    SlidesText.plainText(before).trimRight(),
    SlidesText.plainText(after).trimRight(),
  );

  /// The diff of two plain texts; adjacent spans of the same op merged.
  static List<TextDiffSpan> of(String before, String after) {
    if (before == after) {
      return before.isEmpty ? const [] : [(op: TextDiffOp.equal, text: before)];
    }
    final a = tokens(before);
    final b = tokens(after);
    // Common prefix and suffix.
    var start = 0;
    while (start < a.length && start < b.length && a[start] == b[start]) {
      start++;
    }
    var endA = a.length, endB = b.length;
    while (endA > start && endB > start && a[endA - 1] == b[endB - 1]) {
      endA--;
      endB--;
    }
    final out = <TextDiffSpan>[];
    void add(TextDiffOp op, String text) {
      if (text.isEmpty) return;
      if (out.isNotEmpty && out.last.op == op) {
        out[out.length - 1] = (op: op, text: out.last.text + text);
      } else {
        out.add((op: op, text: text));
      }
    }

    add(TextDiffOp.equal, a.sublist(0, start).join());
    final midA = a.sublist(start, endA);
    final midB = b.sublist(start, endB);
    if (midA.length * midB.length > maxCells) {
      add(TextDiffOp.delete, midA.join());
      add(TextDiffOp.insert, midB.join());
    } else {
      // LCS table over the middle part.
      final n = midA.length, m = midB.length;
      final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
      for (var i = n - 1; i >= 0; i--) {
        for (var j = m - 1; j >= 0; j--) {
          lcs[i][j] = midA[i] == midB[j]
              ? lcs[i + 1][j + 1] + 1
              : (lcs[i + 1][j] >= lcs[i][j + 1]
                    ? lcs[i + 1][j]
                    : lcs[i][j + 1]);
        }
      }
      var i = 0, j = 0;
      while (i < n && j < m) {
        if (midA[i] == midB[j]) {
          add(TextDiffOp.equal, midA[i]);
          i++;
          j++;
        } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
          add(TextDiffOp.delete, midA[i++]);
        } else {
          add(TextDiffOp.insert, midB[j++]);
        }
      }
      while (i < n) {
        add(TextDiffOp.delete, midA[i++]);
      }
      while (j < m) {
        add(TextDiffOp.insert, midB[j++]);
      }
    }
    add(TextDiffOp.equal, a.sublist(endA).join());
    return out;
  }

  static final _token = RegExp(r'\s+|[\p{L}\p{N}_]+|.', unicode: true);

  /// [text] split into words, whitespace runs and single other characters.
  static List<String> tokens(String text) => [
    for (final m in _token.allMatches(text)) m[0]!,
  ];
}
