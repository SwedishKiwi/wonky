import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';

import '../attributions/wonky_attributions.dart';

/// Keeps the caret and selection edges outside mentions (Write 04 §19.3): a
/// position strictly inside a mention snaps to the nearest edge.
class MentionAtomicityReaction extends EditReaction {
  const MentionAtomicityReaction();

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    if (_completePartialMentionDeletion(
      editorContext,
      requestDispatcher,
      changeList,
    )) {
      return;
    }
    if (!changeList.any((e) => e is SelectionChangeEvent)) {
      return;
    }
    final composer = editorContext.composer;
    final selection = composer.selection;
    if (selection == null) {
      return;
    }
    final document = editorContext.document;
    final base = snap(document, selection.base);
    final extent = snap(document, selection.extent);
    if (base == selection.base && extent == selection.extent) {
      return;
    }
    requestDispatcher.execute([
      ChangeSelectionRequest(
        DocumentSelection(base: base, extent: extent),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
    ]);
  }

  /// When part of a mention was deleted (e.g. one character by an IME), the
  /// rest of it is deleted too.
  bool _completePartialMentionDeletion(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final lastEdit = changeList.whereType<DocumentEdit>().lastOrNull?.change;
    if (lastEdit is! TextDeletedEvent) return false;
    final deleted = lastEdit.deletedText;
    if (deleted.isEmpty) return false;
    final mentions = {
      ...deleted.getAllAttributionsAt(0).whereType<MentionAttribution>(),
      ...deleted
          .getAllAttributionsAt(deleted.length - 1)
          .whereType<MentionAttribution>(),
    };
    if (mentions.isEmpty) return false;
    final node = editContext.document.getNodeById(lastEdit.nodeId);
    if (node is! TextNode) return false;
    final offset = lastEdit.offset;
    for (final mention in mentions) {
      for (final probe in [offset - 1, offset]) {
        if (probe < 0 || probe >= node.text.length) continue;
        if (!node.text.hasAttributionAt(probe, attribution: mention)) continue;
        final range = node.text.getAttributedRange({mention}, probe);
        requestDispatcher.execute([
          DeleteContentRequest(
            documentRange: DocumentRange(
              start: DocumentPosition(
                nodeId: node.id,
                nodePosition: TextNodePosition(offset: range.start),
              ),
              end: DocumentPosition(
                nodeId: node.id,
                nodePosition: TextNodePosition(offset: range.end + 1),
              ),
            ),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: node.id,
                nodePosition: TextNodePosition(offset: range.start),
              ),
            ),
            SelectionChangeType.deleteContent,
            SelectionReason.contentChange,
          ),
        ]);
        return true;
      }
    }
    return false;
  }

  /// [position] moved to the nearest edge of the mention it is inside of.
  static DocumentPosition snap(Document document, DocumentPosition position) {
    final range = mentionRangeAround(document, position);
    if (range == null) {
      return position;
    }
    final offset = (position.nodePosition as TextNodePosition).offset;
    final target = offset - range.start <= range.end + 1 - offset
        ? range.start
        : range.end + 1;
    return DocumentPosition(
      nodeId: position.nodeId,
      nodePosition: TextNodePosition(offset: target),
    );
  }

  /// The mention span (inclusive) that strictly contains [position].
  static SpanRange? mentionRangeAround(
    Document document,
    DocumentPosition position,
  ) {
    final node = document.getNodeById(position.nodeId);
    final nodePosition = position.nodePosition;
    if (node is! TextNode || nodePosition is! TextNodePosition) {
      return null;
    }
    final offset = nodePosition.offset;
    if (offset <= 0 || offset >= node.text.length) {
      return null;
    }
    final mention = node.text
        .getAllAttributionsAt(offset)
        .firstWhereOrNull((a) => a is MentionAttribution);
    if (mention == null ||
        !node.text.hasAttributionAt(offset - 1, attribution: mention)) {
      return null;
    }
    return node.text.getAttributedRange({mention}, offset);
  }

  /// The mention span (inclusive) that ends right before [offset] or starts
  /// at [offset] in [node], used by atomic Backspace/Delete.
  static SpanRange? mentionAdjacentTo(
    TextNode node,
    int offset, {
    required bool upstream,
  }) {
    final probe = upstream ? offset - 1 : offset;
    if (probe < 0 || probe >= node.text.length) {
      return null;
    }
    final mention = node.text
        .getAllAttributionsAt(probe)
        .firstWhereOrNull((a) => a is MentionAttribution);
    if (mention == null) {
      return null;
    }
    return node.text.getAttributedRange({mention}, probe);
  }
}
