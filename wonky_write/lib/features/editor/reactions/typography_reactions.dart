import 'package:super_editor/super_editor.dart';

import '../mapping/wonky_schema.dart';
import 'reaction_wrappers.dart';

/// Shared checks for smart typography (Write 04 §8): never in code blocks or
/// inline code, never after a backslash.
abstract final class _TypographyContext {
  static (TextNode, TextInsertionEvent)? typed(
    EditContext editContext,
    List<EditEvent> changeList,
    String char,
  ) {
    final insertion = TypedText.lastInsertion(changeList);
    if (insertion == null || insertion.text.toPlainText() != char) {
      return null;
    }
    final node = editContext.document.getNodeById(insertion.nodeId);
    if (node is! TextNode || isCodeBlockNode(node)) {
      return null;
    }
    if (node.text
        .getAllAttributionsAt(insertion.offset)
        .contains(codeAttribution)) {
      return null;
    }
    if (insertion.offset > 0 &&
        node.text.toPlainText()[insertion.offset - 1] == r'\') {
      return null;
    }
    return (node, insertion);
  }

  static List<EditRequest> replace(
    TextNode node,
    int start,
    int end,
    String replacement,
    int caretAfter,
  ) {
    final attributions = node.text.getAllAttributionsAt(end - 1);
    return [
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(
            nodeId: node.id,
            nodePosition: TextNodePosition(offset: start),
          ),
          end: DocumentPosition(
            nodeId: node.id,
            nodePosition: TextNodePosition(offset: end),
          ),
        ),
      ),
      InsertTextRequest(
        documentPosition: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: start),
        ),
        textToInsert: replacement,
        attributions: attributions,
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: node.id,
            nodePosition: TextNodePosition(offset: caretAfter),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ];
  }
}

/// `"` → “ or ”, `'` → ‘ or ’ (apostrophe after a letter or digit).
class SmartQuotesReaction extends EditReaction {
  const SmartQuotesReaction();

  static final _openingContext = RegExp(r'[\s(\[{“‘]');
  static final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final double = _TypographyContext.typed(editorContext, changeList, '"');
    final single = double == null
        ? _TypographyContext.typed(editorContext, changeList, "'")
        : null;
    final typed = double ?? single;
    if (typed == null) {
      return;
    }
    final (node, insertion) = typed;
    final text = node.text.toPlainText();
    final offset = insertion.offset;
    final previous = offset == 0 ? null : text[offset - 1];
    final isOpening = previous == null || _openingContext.hasMatch(previous);
    final String replacement;
    if (double != null) {
      replacement = isOpening ? '“' : '”';
    } else {
      final isApostrophe =
          previous != null && _wordCharacter.hasMatch(previous);
      replacement = isOpening && !isApostrophe ? '‘' : '’';
    }
    requestDispatcher.execute(
      _TypographyContext.replace(
        node,
        offset,
        offset + 1,
        replacement,
        offset + 1,
      ),
    );
  }
}

/// `...` → `…`.
class EllipsisReaction extends EditReaction {
  const EllipsisReaction();

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final typed = _TypographyContext.typed(editorContext, changeList, '.');
    if (typed == null) {
      return;
    }
    final (node, insertion) = typed;
    final offset = insertion.offset;
    if (offset < 2) {
      return;
    }
    final text = node.text.toPlainText();
    if (text.substring(offset - 2, offset) != '..') {
      return;
    }
    if (offset >= 3 && text[offset - 3] == r'\') {
      return;
    }
    requestDispatcher.execute(
      _TypographyContext.replace(node, offset - 2, offset + 1, '…', offset - 1),
    );
  }
}

/// `--` → `—` (em dash). Replaces super_editor's `DashConversionReaction`,
/// which also fires in code.
class EmDashReaction extends EditReaction {
  const EmDashReaction();

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final typed = _TypographyContext.typed(editorContext, changeList, '-');
    if (typed == null) {
      return;
    }
    final (node, insertion) = typed;
    final offset = insertion.offset;
    if (offset < 1 || node.text.toPlainText()[offset - 1] != '-') {
      return;
    }
    if (offset >= 2 && node.text.toPlainText()[offset - 2] == '-') {
      // Part of `---` (a divider shortcut) or a longer run: leave it.
      return;
    }
    requestDispatcher.execute(
      _TypographyContext.replace(node, offset - 1, offset + 1, '—', offset),
    );
  }
}
