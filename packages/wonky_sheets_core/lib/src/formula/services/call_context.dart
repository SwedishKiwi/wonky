import '../parser/lexer.dart';

/// An unclosed call (or grouping) frame at a caret position, derived from the token stream.
final class CallFrame {
  /// Function name for calls; null for plain parentheses and array braces.
  final String? name;
  final bool isArray;

  /// Offset of the function name (or the bracket).
  final int start;

  /// Offset after the opening bracket.
  final int openEnd;

  /// Zero-based argument index at the caret.
  int argIndex = 0;

  /// Names appearing as complete arguments (LET/LAMBDA scope), by argument index.
  final Map<int, String> nameArgs = {};

  /// Whether the current argument consists of a single name token so far.
  final List<String> currentTokens = [];

  CallFrame(this.name, this.start, this.openEnd, {this.isArray = false});
}

/// Walks [tokens] up to [caret] and returns the stack of open frames (innermost last).
List<CallFrame> openFrames(List<FormulaToken> tokens, int caret) {
  final stack = <CallFrame>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.start >= caret) break;
    if (t.end > caret && t.kind != TokenKind.whitespace) {
      // caret inside a token: stop before it (it is the current argument's text)
      break;
    }
    switch (t.kind) {
      case TokenKind.openParen:
        String? name;
        var start = t.start;
        if (i > 0) {
          final p = tokens[i - 1];
          if (p.kind == TokenKind.functionName && p.end == t.start) {
            name = p.text;
            start = p.start;
          }
        }
        stack.add(CallFrame(name, start, t.end));
      case TokenKind.openBrace:
        stack.add(CallFrame(null, t.start, t.end, isArray: true));
      case TokenKind.closeParen:
      case TokenKind.closeBrace:
        if (stack.isNotEmpty) stack.removeLast();
        if (stack.isNotEmpty) stack.last.currentTokens.add(')');
      case TokenKind.argSeparator:
      case TokenKind.arrayColSep:
      case TokenKind.arrayRowSep:
        if (stack.isNotEmpty) {
          final f = stack.last;
          if (f.currentTokens.length == 1 && f.currentTokens.first.isNotEmpty && f.currentTokens.first != ')') {
            f.nameArgs[f.argIndex] = f.currentTokens.first;
          }
          f.currentTokens.clear();
          f.argIndex++;
        }
      case TokenKind.whitespace:
        break;
      default:
        if (stack.isNotEmpty) {
          stack.last.currentTokens.add(t.kind == TokenKind.name ? t.text : '');
        }
    }
  }
  return stack;
}
