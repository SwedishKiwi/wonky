import 'dart:typed_data';

import '../../content/cell_content.dart';

/// Trim whitespace (07 §12.2): removes leading/trailing whitespace (space,
/// tab, CR, LF, NBSP and other Unicode `Zs`) and collapses internal runs of
/// spaces/NBSPs (`Zs`) to one space. Line breaks and tabs inside the text are
/// kept. Only text and rich text change; values remain text.
abstract final class WhitespaceTrimmer {
  /// Whether [c] is a Unicode space separator (`Zs`).
  static bool isSpaceSeparator(int c) =>
      c == 0x20 ||
      c == 0xa0 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200a) ||
      c == 0x202f ||
      c == 0x205f ||
      c == 0x3000;

  static bool _isEdgeWhitespace(int c) => isSpaceSeparator(c) || c == 0x09 || c == 0x0a || c == 0x0d;

  /// The trimmed text and the old → new offset map (length `text.length + 1`).
  static (String, Int32List) trimWithMap(String text) {
    final n = text.length;
    final map = Int32List(n + 1);
    var start = 0;
    while (start < n && _isEdgeWhitespace(text.codeUnitAt(start))) {
      start++;
    }
    var end = n;
    while (end > start && _isEdgeWhitespace(text.codeUnitAt(end - 1))) {
      end--;
    }
    final b = StringBuffer();
    for (var i = 0; i < start; i++) {
      map[i] = 0;
    }
    var i = start;
    while (i < end) {
      final c = text.codeUnitAt(i);
      if (isSpaceSeparator(c)) {
        map[i] = b.length;
        b.write(' ');
        var j = i + 1;
        while (j < end && isSpaceSeparator(text.codeUnitAt(j))) {
          map[j] = b.length;
          j++;
        }
        i = j;
        continue;
      }
      map[i] = b.length;
      b.writeCharCode(c);
      i++;
    }
    final len = b.length;
    for (var k = end; k <= n; k++) {
      map[k] = len;
    }
    return (b.toString(), map);
  }

  /// [text] trimmed.
  static String trimText(String text) => trimWithMap(text).$1;

  /// The trimmed content, or null when [content] doesn't change (numbers,
  /// booleans, formulas and errors never change).
  static CellContent? trimContent(CellContent? content) {
    switch (content) {
      case TextContent(:final text):
        final t = trimText(text);
        return t == text ? null : TextContent(t);
      case RichTextContent(:final rich):
        final (t, map) = trimWithMap(rich.text);
        if (t == rich.text) return null;
        return RichTextContent(rich.remap(t, (o) => map[o.clamp(0, rich.text.length)]));
      default:
        return null;
    }
  }

  /// Toast text after trimming [count] cells.
  static String message(int count) =>
      count == 0 ? 'No whitespace to trim.' : 'Trimmed whitespace from $count cell${count == 1 ? '' : 's'}.';
}
