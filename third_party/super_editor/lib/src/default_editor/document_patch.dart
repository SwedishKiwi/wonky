// WONKY PATCH SE-2: incremental, composer-free document patches.
//
// Collaborative editors receive changes from other users (or from undo, AI,
// scripts) that must be applied to the live document *without* going through
// the composer: the local caret must not jump, the composing region must stay
// valid, and the change must not be recorded as a local, undoable edit.
//
// Upstream only supports building whole documents from Quill Deltas
// (`parseQuillDeltaDocument`) or editing through requests that act at the
// caret. [ApplyDocumentPatchRequest] applies an ordered list of node-level
// operations (replace, insert, delete, move) directly to the [MutableDocument],
// reports precise [DocumentEdit] events, and then sets a transformed selection
// and composing region that the caller computed.
//
// The Quill Delta → node mapping lives in the app (it depends on the app's
// schema); this request is the generic primitive it is built on.
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_composer.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/node_change_events.dart';

/// A single node-level operation within an [ApplyDocumentPatchRequest].
sealed class DocumentPatchOperation {
  const DocumentPatchOperation();
}

/// Replaces the node with [nodeId] by [newNode].
///
/// [newNode] usually has the same id. If its id differs, the old node is
/// reported as removed and the new node as inserted.
class ReplaceNodePatch extends DocumentPatchOperation {
  const ReplaceNodePatch(this.nodeId, this.newNode);

  final String nodeId;
  final DocumentNode newNode;

  @override
  String toString() => "ReplaceNodePatch($nodeId -> ${newNode.id})";
}

/// Inserts [node] at [index] (0 = before the first node; `nodeCount` = append).
class InsertNodePatch extends DocumentPatchOperation {
  const InsertNodePatch(this.index, this.node);

  final int index;
  final DocumentNode node;

  @override
  String toString() => "InsertNodePatch($index: ${node.id})";
}

/// Deletes the node with [nodeId].
class DeleteNodePatch extends DocumentPatchOperation {
  const DeleteNodePatch(this.nodeId);

  final String nodeId;

  @override
  String toString() => "DeleteNodePatch($nodeId)";
}

/// Moves the node with [nodeId] to [toIndex].
class MoveNodePatch extends DocumentPatchOperation {
  const MoveNodePatch(this.nodeId, this.toIndex);

  final String nodeId;
  final int toIndex;

  @override
  String toString() => "MoveNodePatch($nodeId -> $toIndex)";
}

/// Applies [operations] to the document in order, without moving the caret
/// through the composer, and then optionally sets [selectionAfter] and
/// [composingRegionAfter].
///
/// The resulting command is [HistoryBehavior.nonHistorical] by default, so it
/// never ends up in the editor's own undo history.
///
/// A [DocumentPatchAppliedEvent] carrying [tag] is logged before the document
/// events, so listeners can tell patches apart from local user edits.
class ApplyDocumentPatchRequest implements EditRequest {
  const ApplyDocumentPatchRequest({
    required this.operations,
    this.updateSelection = false,
    this.selectionAfter,
    this.updateComposingRegion = false,
    this.composingRegionAfter,
    this.resyncIme = false,
    this.runReactions = false,
    this.tag,
    this.historyBehavior = HistoryBehavior.nonHistorical,
  });

  final List<DocumentPatchOperation> operations;

  /// Whether to replace the composer's selection with [selectionAfter].
  final bool updateSelection;
  final DocumentSelection? selectionAfter;

  /// Whether to replace the composer's composing region with
  /// [composingRegionAfter].
  final bool updateComposingRegion;
  final DocumentRange? composingRegionAfter;

  /// Whether the platform IME must be re-sent the document, e.g., because
  /// text around the caret changed without the selection changing.
  final bool resyncIme;

  /// Whether the editor's reactions run for the transaction of this patch.
  ///
  /// Defaults to `false`: a patch usually mirrors a change that was already
  /// made (and reacted to) elsewhere.
  final bool runReactions;

  /// Arbitrary data identifying the origin of the patch (e.g., "remote").
  final Object? tag;

  final HistoryBehavior historyBehavior;
}

class ApplyDocumentPatchCommand extends EditCommand {
  const ApplyDocumentPatchCommand(this.request);

  final ApplyDocumentPatchRequest request;

  @override
  HistoryBehavior get historyBehavior => request.historyBehavior;

  @override
  String describe() =>
      "Apply document patch (${request.operations.length} operations, tag: ${request.tag})";

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final composer = context.composer;

    final changes = <EditEvent>[
      DocumentPatchAppliedEvent(request.tag,
          suppressesReactions: !request.runReactions),
    ];
    for (final operation in request.operations) {
      switch (operation) {
        case ReplaceNodePatch(:final nodeId, :final newNode):
          final oldNode = document.getNodeById(nodeId);
          if (oldNode == null) {
            throw Exception(
                "ApplyDocumentPatchCommand: no node with id '$nodeId' to replace");
          }
          if (identical(oldNode, newNode)) {
            continue;
          }
          document.replaceNodeById(nodeId, newNode);
          if (newNode.id == nodeId) {
            changes.add(DocumentEdit(
                NodeReplacedEvent(nodeId, before: oldNode, after: newNode)));
          } else {
            changes
              ..add(DocumentEdit(NodeRemovedEvent(nodeId, oldNode)))
              ..add(DocumentEdit(NodeInsertedEvent(
                  newNode.id, document.getNodeIndexById(newNode.id))));
          }
        case InsertNodePatch(:final index, :final node):
          if (index < 0 || index > document.nodeCount) {
            throw Exception(
                "ApplyDocumentPatchCommand: insertion index $index out of range");
          }
          document.insertNodeAt(index, node);
          changes.add(DocumentEdit(NodeInsertedEvent(node.id, index)));
        case DeleteNodePatch(:final nodeId):
          final oldNode = document.getNodeById(nodeId);
          if (oldNode == null) {
            throw Exception(
                "ApplyDocumentPatchCommand: no node with id '$nodeId' to delete");
          }
          document.deleteNode(nodeId);
          changes.add(DocumentEdit(NodeRemovedEvent(nodeId, oldNode)));
        case MoveNodePatch(:final nodeId, :final toIndex):
          final from = document.getNodeIndexById(nodeId);
          if (from < 0) {
            throw Exception(
                "ApplyDocumentPatchCommand: no node with id '$nodeId' to move");
          }
          if (from == toIndex) {
            continue;
          }
          document.moveNode(nodeId: nodeId, targetIndex: toIndex);
          changes.add(DocumentEdit(
              NodeMovedEvent(nodeId: nodeId, from: from, to: toIndex)));
      }
    }

    if (request.updateComposingRegion) {
      final oldRegion = composer.composingRegion.value;
      if (oldRegion != request.composingRegionAfter) {
        composer.setComposingRegion(request.composingRegionAfter);
        changes.add(ComposingRegionChangeEvent(
          oldComposingRegion: oldRegion,
          newComposingRegion: request.composingRegionAfter,
        ));
      }
    }

    if (request.updateSelection) {
      final oldSelection = composer.selection;
      if (oldSelection != request.selectionAfter) {
        composer.setSelectionWithReason(
            request.selectionAfter, SelectionReason.contentChange);
        changes.add(SelectionChangeEvent(
          oldSelection: oldSelection,
          newSelection: request.selectionAfter,
          changeType: SelectionChangeType.alteredContent,
          reason: SelectionReason.contentChange,
        ));
      }
    }

    if (request.resyncIme) {
      composer.requestImeResync();
    }

    executor.logChanges(changes);
  }
}

/// Logged by [ApplyDocumentPatchCommand] before the document changes of a patch.
class DocumentPatchAppliedEvent extends EditEvent
    implements ReactionSuppressingEvent {
  DocumentPatchAppliedEvent(this.tag, {this.suppressesReactions = true});

  /// The [ApplyDocumentPatchRequest.tag] of the patch.
  final Object? tag;

  @override
  final bool suppressesReactions;

  @override
  String describe() => "Document patch applied (tag: $tag)";

  @override
  String toString() => "DocumentPatchAppliedEvent($tag)";
}
