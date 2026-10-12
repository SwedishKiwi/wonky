import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/services.dart' show TextAffinity;
import 'package:super_editor/super_editor.dart';

import 'delta_index.dart';
import 'delta_node_codec.dart';

/// The serialized Delta of one document node.
class MirrorEntry {
  MirrorEntry(this.node, this.delta) : length = _lengthOf(delta);

  /// The node instance this entry was serialized from. super_editor nodes are
  /// immutable, so `identical(entry.node, documentNode)` means "unchanged".
  final DocumentNode node;

  /// The node's Delta lines (inserts only).
  final Delta delta;

  /// Delta length of [delta].
  final int length;

  String get nodeId => node.id;

  static int _lengthOf(Delta delta) {
    var length = 0;
    for (final op in delta.operations) {
      length += op.length!;
    }
    return length;
  }
}

/// A Delta mirror of a super_editor [MutableDocument]: one [MirrorEntry] per
/// node plus a [DeltaIndex] for O(log n) Delta offset ⇄ [DocumentPosition]
/// conversions.
///
/// The mirror is kept in sync by the `ChangeDeltaExtractor` (local edits) and
/// the `DeltaApplier` (remote edits).
class DocumentMirror {
  DocumentMirror({this.serializer = const WonkyDeltaSerializer()});

  final WonkyDeltaSerializer serializer;

  final _entries = <MirrorEntry>[];
  final _indexById = <String, int>{};
  final _index = DeltaIndex();

  /// Number of nodes.
  int get nodeCount => _entries.length;

  /// Total Delta length of the document.
  int get length => _index.totalLength;

  List<MirrorEntry> get entries => List.unmodifiable(_entries);

  MirrorEntry entryAt(int index) => _entries[index];

  /// Index of the node with [nodeId], or -1.
  int indexOfNode(String nodeId) => _indexById[nodeId] ?? -1;

  MirrorEntry? entryOf(String nodeId) {
    final index = _indexById[nodeId];
    return index == null ? null : _entries[index];
  }

  /// Delta offset at which node [index] starts.
  int startOfIndex(int index) => _index.startOf(index);

  /// Delta offset at which the node with [nodeId] starts.
  int startOfNode(String nodeId) {
    final index = _indexById[nodeId];
    if (index == null) {
      throw ArgumentError('Unknown node $nodeId');
    }
    return _index.startOf(index);
  }

  /// Index of the node containing Delta [offset].
  int indexAtOffset(int offset) => _index.indexAt(offset);

  /// Rebuilds the whole mirror from [document].
  void rebuild(Iterable<DocumentNode> document) {
    _entries
      ..clear()
      ..addAll(document.map(serializeEntry));
    _reindexIds(0);
    _index.reset(_entries.map((e) => e.length));
  }

  /// Serializes [node] into an entry.
  MirrorEntry serializeEntry(DocumentNode node) =>
      MirrorEntry(node, serializer.serializeNode(node));

  /// Replaces entries `[start, end)` with [newEntries].
  void replaceRange(int start, int end, List<MirrorEntry> newEntries) {
    final sameCount = end - start == newEntries.length;
    for (var i = start; i < end; i += 1) {
      final oldId = _entries[i].nodeId;
      if (_indexById[oldId] == i) {
        _indexById.remove(oldId);
      }
    }
    _entries.replaceRange(start, end, newEntries);
    if (sameCount) {
      for (var i = 0; i < newEntries.length; i += 1) {
        _indexById[newEntries[i].nodeId] = start + i;
      }
    } else {
      _reindexIds(start);
    }
    _index.replaceRange(start, end, newEntries.map((e) => e.length).toList());
  }

  void _reindexIds(int from) {
    if (from == 0) {
      _indexById.clear();
    }
    for (var i = from; i < _entries.length; i += 1) {
      _indexById[_entries[i].nodeId] = i;
    }
  }

  /// The whole document Delta.
  Delta toDelta() => entriesDelta(0, _entries.length);

  /// The concatenated Delta of entries `[start, end)`.
  Delta entriesDelta(int start, int end) {
    final delta = Delta();
    for (var i = start; i < end; i += 1) {
      for (final op in _entries[i].delta.operations) {
        delta.push(op);
      }
    }
    return delta;
  }

  /// The document Delta between Delta offsets `[start, end)`, computed from the
  /// entries that cover the range (O(log n + k)).
  Delta slice(int start, int end) {
    if (_entries.isEmpty || end <= start) {
      return Delta();
    }
    final first = _index.indexAt(start);
    final firstStart = _index.startOf(first);
    var last = first;
    var lastEnd = firstStart + _entries[first].length;
    while (lastEnd < end && last + 1 < _entries.length) {
      last += 1;
      lastEnd += _entries[last].length;
    }
    return entriesDelta(
      first,
      last + 1,
    ).slice(start - firstStart, end - firstStart);
  }

  /// `change.invert(document)` computed from the slices of the document that
  /// the change touches, without materializing the whole document.
  Delta invert(Delta change) {
    final inverted = Delta();
    var offset = 0;
    for (final op in change.operations) {
      final length = op.length!;
      if (op.isInsert) {
        inverted.delete(length);
      } else if (op.isRetain && op.isPlain) {
        inverted.retain(length);
        offset += length;
      } else {
        final base = slice(offset, offset + length);
        for (final baseOp in base.operations) {
          if (op.isDelete) {
            inverted.push(baseOp);
          } else {
            final attributes = Delta.invertAttributes(
              op.attributes,
              baseOp.attributes,
            );
            inverted.retain(
              baseOp.length!,
              attributes.isEmpty ? null : attributes,
            );
          }
        }
        offset += length;
      }
    }
    inverted.trim();
    return inverted;
  }

  /// Converts a [DocumentPosition] to a Delta offset, or `null` when the node
  /// is unknown.
  int? offsetOf(DocumentPosition position) {
    final index = _indexById[position.nodeId];
    if (index == null) {
      return null;
    }
    final start = _index.startOf(index);
    final entry = _entries[index];
    final nodePosition = position.nodePosition;
    if (nodePosition is TextNodePosition) {
      return start + nodePosition.offset.clamp(0, entry.length - 1);
    }
    if (nodePosition is UpstreamDownstreamNodePosition) {
      return nodePosition.affinity == TextAffinity.upstream
          ? start
          : start + (entry.length > 1 ? 1 : 0);
    }
    return start;
  }

  /// Converts a Delta offset to a [DocumentPosition]. Offsets at or past the
  /// end of the document map to the end of the last node.
  DocumentPosition? positionAt(int offset) {
    if (_entries.isEmpty) {
      return null;
    }
    final index = _index.indexAt(offset);
    final entry = _entries[index];
    final start = _index.startOf(index);
    final local = (offset - start).clamp(
      0,
      entry.length > 0 ? entry.length - 1 : 0,
    );
    final node = entry.node;
    if (node is TextNode) {
      return DocumentPosition(
        nodeId: node.id,
        nodePosition: TextNodePosition(offset: local),
      );
    }
    return DocumentPosition(
      nodeId: node.id,
      nodePosition: local == 0
          ? const UpstreamDownstreamNodePosition.upstream()
          : const UpstreamDownstreamNodePosition.downstream(),
    );
  }

  /// Converts a [DocumentSelection] to Delta offsets `(base, extent)`.
  (int, int)? offsetsOf(DocumentSelection selection) {
    final base = offsetOf(selection.base);
    final extent = offsetOf(selection.extent);
    if (base == null || extent == null) {
      return null;
    }
    return (base, extent);
  }

  /// Builds a [DocumentSelection] from Delta offsets.
  DocumentSelection? selectionAt(int base, int extent) {
    final basePosition = positionAt(base);
    final extentPosition = positionAt(extent);
    if (basePosition == null || extentPosition == null) {
      return null;
    }
    return DocumentSelection(base: basePosition, extent: extentPosition);
  }
}
