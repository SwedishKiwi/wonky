import 'package:flutter/services.dart' show TextAffinity;
import 'package:super_editor/super_editor.dart';

/// Arrow keys into an embed select the whole block; the next press in the
/// same direction moves past it to the adjacent text block (Write 04 §5),
/// creating the lazy trailing paragraph after a final embed (§6.5).
class EmbedSelectionReaction extends EditReaction {
  EmbedSelectionReaction({required this.isEditable});

  final bool Function() isEditable;

  DocumentSelection? _previous;

  @override
  void react(EditContext editorContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    final selectionEvent = changeList.whereType<SelectionChangeEvent>().lastOrNull;
    final composer = editorContext.composer;
    final selection = composer.selection;
    final previous = _previous;
    _previous = selection;
    if (selectionEvent == null || selection == null || !selection.isCollapsed) {
      return;
    }
    if (selectionEvent.reason != SelectionReason.userInteraction ||
        changeList.any((e) => e is DocumentEdit)) {
      return;
    }
    final document = editorContext.document;
    final node = document.getNodeById(selection.extent.nodeId);
    final position = selection.extent.nodePosition;
    if (node is! BlockNode || position is! UpstreamDownstreamNodePosition) {
      return;
    }

    final wasThisEmbedSelected = previous != null &&
        !previous.isCollapsed &&
        previous.base.nodeId == node.id &&
        previous.extent.nodeId == node.id;
    if (!wasThisEmbedSelected) {
      // Entering the embed: select it whole.
      _previous = DocumentSelection(
        base: DocumentPosition(nodeId: node.id, nodePosition: const UpstreamDownstreamNodePosition.upstream()),
        extent: DocumentPosition(nodeId: node.id, nodePosition: const UpstreamDownstreamNodePosition.downstream()),
      );
      requestDispatcher.execute([
        ChangeSelectionRequest(_previous, SelectionChangeType.expandSelection, SelectionReason.contentChange),
      ]);
      return;
    }

    // Leaving the selected embed in the arrow's direction.
    final downstream = position.affinity == TextAffinity.downstream;
    final neighbor = downstream ? document.getNodeAfter(node) : document.getNodeBefore(node);
    if (neighbor != null) {
      final target = DocumentPosition(
        nodeId: neighbor.id,
        nodePosition: downstream ? neighbor.beginningPosition : neighbor.endPosition,
      );
      _previous = DocumentSelection.collapsed(position: target);
      requestDispatcher.execute([
        ChangeSelectionRequest(_previous, SelectionChangeType.placeCaret, SelectionReason.contentChange),
      ]);
      return;
    }
    if (downstream && isEditable()) {
      final paragraphId = Editor.createNodeId();
      _previous = DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: paragraphId, nodePosition: const TextNodePosition(offset: 0)),
      );
      requestDispatcher.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: node.id,
          newNode: ParagraphNode(id: paragraphId, text: AttributedText('')),
        ),
        ChangeSelectionRequest(_previous, SelectionChangeType.placeCaret, SelectionReason.contentChange),
      ]);
    }
  }
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
