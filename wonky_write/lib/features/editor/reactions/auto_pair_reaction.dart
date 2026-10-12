import 'package:super_editor/super_editor.dart';

import '../mapping/wonky_schema.dart';

/// Auto-pairs brackets and quotes (Write 04 §9). Implemented as a reaction
/// (not a keyboard action) so that it also works for IME input.
///
/// - Typing an opener before whitespace, the end, or a closer inserts the pair
///   with the caret in between.
/// - Typing the closer right before the auto-inserted closer overtypes it.
/// - Backspace right after an auto-inserted opener of an empty pair deletes
///   both.
/// - Typing an opener over a selection wraps it; `` ` `` `*` `~` apply inline
///   code / italic / strike instead (when [markdownShortcuts] is on).
class AutoPairReaction extends EditReaction {
  AutoPairReaction({required this.enabled, required this.markdownShortcuts});

  final bool Function() enabled;
  final bool Function() markdownShortcuts;

  static const _pairs = {'(': ')', '[': ']', '{': '}'};
  static const _codePairs = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`'};
  static final _wordCharacter = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// The closer we inserted last: (nodeId, offset, character).
  (String, int, String)? _pending;

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final edits = changeList.whereType<DocumentEdit>().map((e) => e.change).toList();
    if (edits.isEmpty) {
      return;
    }
    if (!enabled()) {
      _pending = null;
      return;
    }
    final document = editContext.document;

    // Wrap: a selection was replaced by an opener.
    if (edits.length >= 2) {
      final deletion = edits[edits.length - 2];
      final insertion = edits.last;
      if (deletion is TextDeletedEvent &&
          insertion is TextInsertionEvent &&
          deletion.nodeId == insertion.nodeId &&
          deletion.offset == insertion.offset &&
          deletion.deletedText.isNotEmpty) {
        final node = document.getNodeById(insertion.nodeId);
        if (node is TextNode && _wrap(node, insertion, deletion.deletedText, requestDispatcher)) {
          _pending = null;
          return;
        }
      }
    }

    final last = edits.last;
    if (edits.length != 1) {
      _pending = null;
      return;
    }

    if (last is TextDeletedEvent) {
      final pending = _pending;
      _pending = null;
      final deleted = last.deletedText.toPlainText();
      final node = document.getNodeById(last.nodeId);
      if (pending == null || node is! TextNode || deleted.length != 1) return;
      final closer = _closerFor(deleted, isCodeBlockNode(node));
      if (closer == null || pending.$1 != node.id || pending.$2 != last.offset + 1 || pending.$3 != closer) return;
      final text = node.text.toPlainText();
      if (last.offset < text.length && text[last.offset] == closer) {
        requestDispatcher.execute([
          DeleteContentRequest(documentRange: _range(node.id, last.offset, last.offset + 1)),
          _caret(node.id, last.offset),
        ]);
      }
      return;
    }

    if (last is! TextInsertionEvent) {
      _pending = null;
      return;
    }
    final typed = last.text.toPlainText();
    final node = document.getNodeById(last.nodeId);
    if (typed.length != 1 || node is! TextNode) {
      _pending = null;
      return;
    }
    final text = node.text.toPlainText();
    final offset = last.offset;
    final isCode = isCodeBlockNode(node);

    // Overtype the auto-inserted closer.
    final pending = _pending;
    if (pending != null && pending.$1 == node.id && pending.$3 == typed && pending.$2 == offset) {
      if (offset + 1 < text.length && text[offset + 1] == typed) {
        _pending = null;
        requestDispatcher.execute([
          DeleteContentRequest(documentRange: _range(node.id, offset + 1, offset + 2)),
          _caret(node.id, offset + 1),
        ]);
        return;
      }
    }
    // Typing inside the pair keeps tracking the auto-inserted closer.
    _pending = pending != null && pending.$1 == node.id && offset <= pending.$2
        ? (pending.$1, pending.$2 + 1, pending.$3)
        : null;

    final closer = _closerFor(typed, isCode);
    if (closer == null) return;
    if (!isCode && node.text.getAllAttributionsAt(offset).contains(codeAttribution)) return;
    if ((typed == "'" || typed == '"') && offset > 0 && _wordCharacter.hasMatch(text[offset - 1])) return;
    final next = offset + 1 < text.length ? text[offset + 1] : null;
    if (next != null && next.trim().isNotEmpty && !_isCloser(next)) return;

    requestDispatcher.execute([
      InsertTextRequest(
        documentPosition: DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: offset + 1)),
        textToInsert: closer,
        attributions: node.text.getAllAttributionsAt(offset),
      ),
      _caret(node.id, offset + 1),
    ]);
    _pending = (node.id, offset + 1, closer);
  }

  bool _wrap(TextNode node, TextInsertionEvent insertion, AttributedText deleted, RequestDispatcher dispatcher) {
    final typed = insertion.text.toPlainText();
    final isCode = isCodeBlockNode(node);
    final offset = insertion.offset;
    final selected = deleted.copy();
    if (deleted.toPlainText().contains('\n')) return false;

    final formatting = isCode || !markdownShortcuts()
        ? null
        : switch (typed) {
            '`' => codeAttribution,
            '*' => italicsAttribution,
            '~' => strikethroughAttribution,
            _ => null,
          };
    if (formatting != null) {
      if (formatting == codeAttribution) {
        for (final a in [boldAttribution, italicsAttribution, strikethroughAttribution]) {
          selected.removeAttribution(a, SpanRange(0, selected.length - 1));
        }
      }
      selected.addAttribution(formatting, SpanRange(0, selected.length - 1));
      dispatcher.execute([
        DeleteContentRequest(documentRange: _range(node.id, offset, offset + 1)),
        InsertAttributedTextRequest(
          DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: offset)),
          selected,
        ),
        _select(node.id, offset, offset + selected.length),
      ]);
      return true;
    }

    final closer = _closerFor(typed, isCode) ?? (typed == '"' ? '"' : null);
    if (closer == null) return false;
    dispatcher.execute([
      InsertAttributedTextRequest(
        DocumentPosition(nodeId: node.id, nodePosition: TextNodePosition(offset: offset + 1)),
        selected.copyAndAppend(AttributedText(closer)),
      ),
      _select(node.id, offset + 1, offset + 1 + selected.length),
    ]);
    return true;
  }

  static String? _closerFor(String opener, bool isCode) => (isCode ? _codePairs : _pairs)[opener];

  static bool _isCloser(String char) => char == ')' || char == ']' || char == '}' || char == '"' || char == "'";

  static DocumentRange _range(String nodeId, int start, int end) => DocumentRange(
        start: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: start)),
        end: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: end)),
      );

  static ChangeSelectionRequest _caret(String nodeId, int offset) => ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: offset)),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      );

  static ChangeSelectionRequest _select(String nodeId, int start, int end) => ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: start)),
          extent: DocumentPosition(nodeId: nodeId, nodePosition: TextNodePosition(offset: end)),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.contentChange,
      );
}
