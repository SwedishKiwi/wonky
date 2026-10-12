import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';

import '../attributions/wonky_attributions.dart';

/// Keeps the caret and selection edges outside mentions (Write 04 §19.3): a
/// position strictly inside a mention snaps to the nearest edge.
class MentionAtomicityReaction extends EditReaction {
  const MentionAtomicityReaction();

  @override
  void react(EditContext editContext, RequestDispatcher requestDispatcher, List<EditEvent> changeList) {
    if (!changeList.any((e) => e is SelectionChangeEvent)) {
      return;
    }
    final composer = editContext.composer;
    final selection = composer.selection;
    if (selection == null) {
      return;
    }
    final document = editContext.document;
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

  /// [position] moved to the nearest edge of the mention it is inside of.
  static DocumentPosition snap(Document document, DocumentPosition position) {
    final range = mentionRangeAround(document, position);
    if (range == null) {
      return position;
    }
    final offset = (position.nodePosition as TextNodePosition).offset;
    final target = offset - range.start <= range.end + 1 - offset ? range.start : range.end + 1;
    return DocumentPosition(nodeId: position.nodeId, nodePosition: TextNodePosition(offset: target));
  }

  /// The mention span (inclusive) that strictly contains [position].
  static SpanRange? mentionRangeAround(Document document, DocumentPosition position) {
    final node = document.getNodeById(position.nodeId);
    final nodePosition = position.nodePosition;
    if (node is! TextNode || nodePosition is! TextNodePosition) {
      return null;
    }
    final offset = nodePosition.offset;
    if (offset <= 0 || offset >= node.text.length) {
      return null;
    }
    final mention = node.text.getAllAttributionsAt(offset).firstWhereOrNull((a) => a is MentionAttribution);
    if (mention == null || !node.text.hasAttributionAt(offset - 1, attribution: mention)) {
      return null;
    }
    return node.text.getAttributedRange({mention}, offset);
  }

  /// The mention span (inclusive) that ends right before [offset] or starts
  /// at [offset] in [node], used by atomic Backspace/Delete.
  static SpanRange? mentionAdjacentTo(TextNode node, int offset, {required bool upstream}) {
    final probe = upstream ? offset - 1 : offset;
    if (probe < 0 || probe >= node.text.length) {
      return null;
    }
    final mention = node.text.getAllAttributionsAt(probe).firstWhereOrNull((a) => a is MentionAttribution);
    if (mention == null) {
      return null;
    }
    return node.text.getAttributedRange({mention}, probe);
  }
}
