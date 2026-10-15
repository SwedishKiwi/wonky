/// The line patterns of the block parser. They follow the suite's renderer
/// (`MarkdownBlocks` in the shell: line based, forgiving) so a block reads
/// the same in the editor and on the board, and CommonMark where the
/// renderer has no opinion.
library;

/// A fence opening a code block: indentation, the fence, the info string.
final fenceOpen = RegExp(r'^(\s*)(`{3,}|~{3,})(.*)$');

/// An ATX heading: the `#`s and the content (closing `#`s removed later).
final headingLine = RegExp(r'^\s*(#{1,6})[ \t]+(.*?)\s*$');

/// A thematic break (`---`, `***`, `___`, spaced or not).
final ruleLine = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');

/// A bullet item: indentation, marker, spaces, content.
final bulletLine = RegExp(r'^(\s*)([-*+])(\s+)(.*)$');

/// A numbered item: indentation, number, delimiter, spaces, content.
final orderedLine = RegExp(r'^(\s*)(\d{1,9})([.)])(\s+)(.*)$');

/// The checkbox of a task item's content (`[ ] `, `[x] `).
final taskBox = RegExp(r'^\[( |x|X)\]\s+(.*)$');

/// A quote line.
final quoteLine = RegExp(r'^\s*>');

/// A table row (kept as literal text).
final tableLine = RegExp(r'^\s*\|');

/// An HTML block start (kept as literal text).
final htmlLine = RegExp(
  r'^ {0,3}<(?:[A-Za-z][A-Za-z0-9-]*(?:[\s/>]|$)|/[A-Za-z]|!--|\?|![A-Za-z]|!\[CDATA\[)',
);

/// A link reference definition (`[label]: url`), kept as literal text.
final linkDefinitionLine = RegExp(r'^ {0,3}\[[^\]]+\]:\s*\S');

/// An indented code line (4 spaces or a tab), kept as literal text.
final indentedCodeLine = RegExp(r'^( {4,}|\t)\S');

/// Whether [line] starts a block other than a paragraph: written text must
/// never start one by accident.
bool startsBlock(String line) =>
    fenceOpen.hasMatch(line) ||
    headingLine.hasMatch(line) ||
    RegExp(r'^\s*#{1,6}$').hasMatch(line) ||
    ruleLine.hasMatch(line) ||
    bulletLine.hasMatch(line) ||
    RegExp(r'^\s*[-*+]$').hasMatch(line) ||
    orderedLine.hasMatch(line) ||
    RegExp(r'^\s*\d{1,9}[.)]$').hasMatch(line) ||
    quoteLine.hasMatch(line) ||
    tableLine.hasMatch(line) ||
    htmlLine.hasMatch(line) ||
    linkDefinitionLine.hasMatch(line) ||
    RegExp(r'^\s*(=+|-+)\s*$').hasMatch(line);

/// The width of [indent] in columns (a tab counts 4).
int indentWidth(String indent) {
  var n = 0;
  for (final c in indent.codeUnits) {
    n += c == 0x09 ? 4 - n % 4 : 1;
  }
  return n;
}
