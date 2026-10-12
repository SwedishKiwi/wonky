// WONKY PATCH SE-3: detailed node change events.
//
// Upstream super_editor reports most block-level changes (block type, list type,
// indentation, task completion, metadata, node type conversions) as a bare
// [NodeChangeEvent], which forces listeners that mirror the document (e.g., a
// Quill Delta sync layer) to re-serialize and diff the node. The events below
// are subclasses of [NodeChangeEvent], so existing listeners keep working, but
// they also carry the before/after values of the change.
import 'package:attributed_text/attributed_text.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/editor.dart';
import 'package:super_editor/src/default_editor/list_items.dart';

/// A [ParagraphNode]'s block type changed, e.g., from paragraph to header 2.
class BlockTypeChangeEvent extends NodeChangeEvent {
  const BlockTypeChangeEvent(
    super.nodeId, {
    required this.before,
    required this.after,
  });

  final Attribution? before;
  final Attribution? after;

  @override
  String describe() => "Block type changed ($nodeId): $before -> $after";

  @override
  String toString() => "BlockTypeChangeEvent('$nodeId': $before -> $after)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockTypeChangeEvent &&
          nodeId == other.nodeId &&
          before == other.before &&
          after == other.after;

  @override
  int get hashCode => nodeId.hashCode ^ before.hashCode ^ after.hashCode;
}

/// A [ListItemNode]'s type changed, e.g., from unordered to ordered.
class ListItemTypeChangeEvent extends NodeChangeEvent {
  const ListItemTypeChangeEvent(
    super.nodeId, {
    required this.before,
    required this.after,
  });

  final ListItemType before;
  final ListItemType after;

  @override
  String describe() => "List item type changed ($nodeId): $before -> $after";

  @override
  String toString() => "ListItemTypeChangeEvent('$nodeId': $before -> $after)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListItemTypeChangeEvent &&
          nodeId == other.nodeId &&
          before == other.before &&
          after == other.after;

  @override
  int get hashCode => nodeId.hashCode ^ before.hashCode ^ after.hashCode;
}

/// The indentation of a node (paragraph, list item or task) changed.
class IndentChangeEvent extends NodeChangeEvent {
  const IndentChangeEvent(
    super.nodeId, {
    required this.before,
    required this.after,
  });

  final int before;
  final int after;

  @override
  String describe() => "Indent changed ($nodeId): $before -> $after";

  @override
  String toString() => "IndentChangeEvent('$nodeId': $before -> $after)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndentChangeEvent &&
          nodeId == other.nodeId &&
          before == other.before &&
          after == other.after;

  @override
  int get hashCode => nodeId.hashCode ^ before.hashCode ^ after.hashCode;
}

/// A [TaskNode] was checked or unchecked.
class TaskCompletionChangeEvent extends NodeChangeEvent {
  const TaskCompletionChangeEvent(
    super.nodeId, {
    required this.before,
    required this.after,
  });

  final bool before;
  final bool after;

  @override
  String describe() => "Task completion changed ($nodeId): $before -> $after";

  @override
  String toString() =>
      "TaskCompletionChangeEvent('$nodeId': $before -> $after)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCompletionChangeEvent &&
          nodeId == other.nodeId &&
          before == other.before &&
          after == other.after;

  @override
  int get hashCode => nodeId.hashCode ^ before.hashCode ^ after.hashCode;
}

/// One or more metadata values of a node changed.
///
/// [before] and [after] contain only the keys that changed. A missing key in
/// [before] means the key didn't exist before; a `null` value in [after] means
/// the key was removed.
class NodeMetadataChangeEvent extends NodeChangeEvent {
  const NodeMetadataChangeEvent(
    super.nodeId, {
    required this.before,
    required this.after,
  });

  final Map<String, dynamic> before;
  final Map<String, dynamic> after;

  @override
  String describe() => "Metadata changed ($nodeId): $before -> $after";

  @override
  String toString() => "NodeMetadataChangeEvent('$nodeId': $before -> $after)";
}

/// A node was replaced by another node with the same id, typically a node of a
/// different type, e.g., a paragraph converted to a list item or a task.
class NodeReplacedEvent extends NodeChangeEvent {
  const NodeReplacedEvent(
    super.nodeId, {
    required this.before,
    required this.after,
  });

  final DocumentNode before;
  final DocumentNode after;

  @override
  String describe() =>
      "Node replaced ($nodeId): ${before.runtimeType} -> ${after.runtimeType}";

  @override
  String toString() =>
      "NodeReplacedEvent('$nodeId': ${before.runtimeType} -> ${after.runtimeType})";
}

/// Request to change (merge) metadata values of the node with [nodeId].
///
/// Keys mapped to `null` in [metadata] are removed. The change is reported as a
/// [NodeMetadataChangeEvent].
// WONKY PATCH SE-3
class ChangeNodeMetadataRequest implements EditRequest {
  const ChangeNodeMetadataRequest({
    required this.nodeId,
    required this.metadata,
  });

  final String nodeId;
  final Map<String, dynamic> metadata;
}

// WONKY PATCH SE-3
class ChangeNodeMetadataCommand extends EditCommand {
  const ChangeNodeMetadataCommand({
    required this.nodeId,
    required this.metadata,
  });

  final String nodeId;
  final Map<String, dynamic> metadata;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final document = context.document;
    final node = document.getNodeById(nodeId);
    if (node == null) {
      return;
    }

    final before = <String, dynamic>{};
    final after = <String, dynamic>{};
    final newMetadata = node.metadata;
    for (final entry in metadata.entries) {
      final hadKey = newMetadata.containsKey(entry.key);
      final oldValue = newMetadata[entry.key];
      if (hadKey && oldValue == entry.value) {
        continue;
      }
      if (!hadKey && entry.value == null) {
        continue;
      }
      if (hadKey) {
        before[entry.key] = oldValue;
      }
      after[entry.key] = entry.value;
      if (entry.value == null) {
        newMetadata.remove(entry.key);
      } else {
        newMetadata[entry.key] = entry.value;
      }
    }
    if (after.isEmpty) {
      return;
    }

    document.replaceNodeById(nodeId, node.copyAndReplaceMetadata(newMetadata));
    executor.logChanges([
      DocumentEdit(
          NodeMetadataChangeEvent(nodeId, before: before, after: after)),
    ]);
  }
}
