import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

import '../applier/delta_applier.dart';
import '../mapping/delta_ops.dart';
import '../mapping/document_mirror.dart';

/// What kind of edit a local change was, used for undo grouping (Write 04
/// §3.3, §35).
enum LocalChangeKind {
  /// Only text was inserted into a single node (typing, IME).
  typing,

  /// Only text was deleted from a single node (Backspace/Delete runs).
  deletion,

  /// Anything else (structure, formatting, multi-node edits).
  other,
}

/// One local change extracted from a super_editor transaction (Write 02 §4.4).
class ExtractedChange {
  const ExtractedChange({
    required this.delta,
    required this.inverse,
    required this.kind,
    required this.nodeIds,
    this.label,
    this.selectionAfter,
    this.isComposing = false,
  });

  /// The change against the document before it.
  final Delta delta;

  /// The inverse of [delta] against the document before it.
  final Delta inverse;

  final LocalChangeKind kind;

  /// Ids of the nodes the change touched.
  final Set<String> nodeIds;

  /// Label of the marked reaction that produced the change ("Autoformat",
  /// "Smart quote"…), or `null` for the user's own edit.
  final String? label;

  /// The selection (Delta offsets `(base, extent)`) right after this change.
  final (int, int)? selectionAfter;

  /// Whether an IME composition was in progress when the change was made.
  final bool isComposing;

  @override
  String toString() =>
      'ExtractedChange($kind${label == null ? '' : ', $label'}: $delta)';
}

/// Thrown (in verification mode) when the extracted change doesn't transform
/// the previous document into the current one.
class ChangeExtractionInvariantError extends Error {
  ChangeExtractionInvariantError(this.message);

  final String message;

  @override
  String toString() => 'ChangeExtractionInvariantError: $message';
}

/// Computes change Deltas from super_editor transactions and keeps the
/// [DocumentMirror] in sync with the document (Write 02 §4.4).
///
/// Strategy: the events of a transaction name the touched nodes. Untouched
/// nodes (super_editor nodes are immutable, so unchanged nodes are the same
/// instances) are anchors; each run of touched nodes between anchors is
/// re-serialized and diffed against its previous Delta lines. Single text
/// insertions/deletions use a fast path that maps the event directly.
///
/// Transactions split by [checkpoint] (marked reactions, Write 04 §2.6) yield
/// several changes, one per segment.
class ChangeDeltaExtractor {
  ChangeDeltaExtractor({
    required this.mirror,
    required this.document,
    this.composer,
    bool? verifyInvariants,
  }) : verifyInvariants = verifyInvariants ?? kDebugMode;

  final DocumentMirror mirror;
  final MutableDocument document;

  /// When given, each change records the selection right after it.
  final DocumentComposer? composer;

  /// Whether every change is checked against a full re-serialization (debug).
  final bool verifyInvariants;

  int _consumed = 0;
  String? _segmentLabel;
  final _pending = <ExtractedChange>[];

  /// Closes the current segment of the running transaction. Called by marked
  /// reactions before (with `label: null` → closes the user's edit) and after
  /// (with their label) the reaction runs.
  void checkpoint(List<EditEvent> changeList, {String? labelForNextSegment}) {
    _closeSegment(changeList);
    _segmentLabel = labelForNextSegment;
  }

  /// Finishes the transaction whose complete [changeList] is given and returns
  /// its changes (possibly none).
  List<ExtractedChange> finishTransaction(List<EditEvent> changeList) {
    _closeSegment(changeList);
    final result = List<ExtractedChange>.of(_pending);
    _pending.clear();
    _consumed = 0;
    _segmentLabel = null;
    return result;
  }

  /// Discards the state of a running transaction (e.g. after a resync).
  void reset() {
    _pending.clear();
    _consumed = 0;
    _segmentLabel = null;
  }

  void _closeSegment(List<EditEvent> changeList) {
    if (_consumed > changeList.length) {
      // A different change list (new transaction) without finish; restart.
      _consumed = 0;
    }
    final events = changeList.sublist(_consumed);
    _consumed = changeList.length;
    final change = _extract(events, _segmentLabel);
    if (change != null) {
      _pending.add(change);
    }
  }

  ExtractedChange? _extract(List<EditEvent> events, String? label) {
    if (events.any(
      (e) =>
          e is DocumentPatchAppliedEvent &&
          '${e.tag}'.startsWith(DeltaApplier.patchTag),
    )) {
      // Applied by the DeltaApplier, which keeps the mirror in sync itself.
      return null;
    }
    final touched = <String>{};
    final textEventsByNode = <String, List<NodeChangeEvent>>{};
    var hasStructuralEvent = false;
    for (final event in events) {
      if (event is! DocumentEdit) {
        continue;
      }
      final change = event.change;
      switch (change) {
        case NodeChangeEvent(:final nodeId):
          touched.add(nodeId);
          if (change is TextInsertionEvent || change is TextDeletedEvent) {
            (textEventsByNode[nodeId] ??= []).add(change);
          } else {
            textEventsByNode.remove(nodeId);
            hasStructuralEvent = true;
          }
        case NodeInsertedEvent(:final nodeId):
          touched.add(nodeId);
          hasStructuralEvent = true;
        case NodeRemovedEvent(:final nodeId):
          touched.add(nodeId);
          hasStructuralEvent = true;
        case NodeMovedEvent(:final nodeId):
          touched.add(nodeId);
          hasStructuralEvent = true;
        default:
          break;
      }
    }
    if (touched.isEmpty) {
      return null;
    }

    final before = verifyInvariants ? mirror.toDelta() : null;
    final result = _diffTouched(touched, textEventsByNode, hasStructuralEvent);
    if (result == null) {
      return null;
    }
    final (delta, inverse) = result;

    if (before != null) {
      final expected = mirror.serializer.serializeNode;
      final actualDoc = Delta();
      for (final node in document) {
        for (final op in expected(node).operations) {
          actualDoc.push(op);
        }
      }
      final composed = before.compose(delta);
      if (composed != actualDoc) {
        throw ChangeExtractionInvariantError(
          'previous.compose(change) != document\nchange: $delta\nexpected: $actualDoc\nactual: $composed',
        );
      }
      if (mirror.toDelta() != actualDoc) {
        throw ChangeExtractionInvariantError(
          'mirror out of sync with the document',
        );
      }
      if (composed.compose(inverse) != before) {
        throw ChangeExtractionInvariantError(
          'inverse does not restore the previous document\ninverse: $inverse',
        );
      }
    }

    if (delta.isEmpty) {
      return null;
    }

    final kind = _classify(
      events,
      touched,
      textEventsByNode,
      hasStructuralEvent,
    );
    final selection = composer?.selection;
    return ExtractedChange(
      delta: delta,
      inverse: inverse,
      kind: kind,
      nodeIds: touched,
      label: label,
      selectionAfter: selection == null ? null : mirror.offsetsOf(selection),
      isComposing: composer?.composingRegion.value != null,
    );
  }

  LocalChangeKind _classify(
    List<EditEvent> events,
    Set<String> touched,
    Map<String, List<NodeChangeEvent>> textEventsByNode,
    bool hasStructuralEvent,
  ) {
    if (hasStructuralEvent ||
        touched.length != 1 ||
        textEventsByNode.length != 1) {
      return LocalChangeKind.other;
    }
    final nodeEvents = textEventsByNode.values.single;
    if (nodeEvents.every((e) => e is TextInsertionEvent)) {
      return LocalChangeKind.typing;
    }
    if (nodeEvents.every((e) => e is TextDeletedEvent)) {
      return LocalChangeKind.deletion;
    }
    return LocalChangeKind.other;
  }

  (Delta, Delta)? _diffTouched(
    Set<String> touched,
    Map<String, List<NodeChangeEvent>> textEventsByNode,
    bool hasStructuralEvent,
  ) {
    final oldCount = mirror.nodeCount;
    final newCount = document.nodeCount;

    // Region bounds: everything before the first and after the last touched
    // node (in either list) is identical in both lists.
    // Not `1 << 62`: shifts by ≥ 32 are 0 on the web.
    const none = 0x1FFFFFFFFFFFFF;
    var start = none;
    var endOld = -1;
    var endNew = -1;
    for (final id in touched) {
      final oldIndex = mirror.indexOfNode(id);
      if (oldIndex >= 0) {
        if (oldIndex < start) start = oldIndex;
        if (oldIndex > endOld) endOld = oldIndex;
      }
      final newIndex = document.getNodeIndexById(id);
      if (newIndex >= 0) {
        if (newIndex < start) start = newIndex;
        if (newIndex > endNew) endNew = newIndex;
      }
    }
    if (start == none) {
      // Touched nodes that exist in neither list (inserted and removed in the
      // same segment): nothing changed.
      return null;
    }
    endOld = endOld < start ? start : endOld + 1;
    endNew = endNew < start ? start : endNew + 1;
    final suffix = (oldCount - endOld) < (newCount - endNew)
        ? oldCount - endOld
        : newCount - endNew;
    final oEnd = oldCount - (suffix < 0 ? 0 : suffix);
    final nEnd = newCount - (suffix < 0 ? 0 : suffix);

    final delta = Delta()..retain(mirror.startOfIndex(start));
    final inverse = Delta()..retain(mirror.startOfIndex(start));
    final gaps = <(int, int, List<MirrorEntry>)>[];

    var i = start;
    var j = start;
    while (i < oEnd || j < nEnd) {
      if (i < oEnd && j < nEnd) {
        final oldEntry = mirror.entryAt(i);
        final newNode = document.getNodeAt(j)!;
        if (oldEntry.nodeId == newNode.id &&
            !touched.contains(newNode.id) &&
            identical(oldEntry.node, newNode)) {
          delta.retain(oldEntry.length);
          inverse.retain(oldEntry.length);
          i += 1;
          j += 1;
          continue;
        }
      }

      // A gap: touched (or otherwise changed) nodes up to the next anchor.
      final gi = i;
      final gj = j;
      while (i < oEnd && _isGapEntry(mirror.entryAt(i), touched)) {
        i += 1;
      }
      while (j < nEnd && _isGapNode(document.getNodeAt(j)!, touched)) {
        j += 1;
      }
      if (gi == i && gj == j) {
        // Anchors that don't line up (a node changed without an event):
        // include both in the gap.
        if (i < oEnd) i += 1;
        if (j < nEnd) j += 1;
      }

      final oldEntries = [for (var k = gi; k < i; k += 1) mirror.entryAt(k)];
      final newEntries = <MirrorEntry>[];
      for (var k = gj; k < j; k += 1) {
        final node = document.getNodeAt(k)!;
        final oldIndex = mirror.indexOfNode(node.id);
        final oldEntry = oldIndex >= 0 ? mirror.entryAt(oldIndex) : null;
        newEntries.add(
          oldEntry != null && identical(oldEntry.node, node)
              ? oldEntry
              : mirror.serializeEntry(node),
        );
      }

      _appendGapChange(
        delta,
        inverse,
        oldEntries,
        newEntries,
        textEventsByNode,
        hasStructuralEvent,
      );
      gaps.add((gi, i, newEntries));
    }

    for (final (from, to, entries) in gaps.reversed) {
      mirror.replaceRange(from, to, entries);
    }

    delta.trim();
    inverse.trim();
    return (delta, inverse);
  }

  bool _isGapEntry(MirrorEntry entry, Set<String> touched) {
    if (touched.contains(entry.nodeId)) {
      return true;
    }
    final node = document.getNodeById(entry.nodeId);
    return node == null || !identical(node, entry.node);
  }

  bool _isGapNode(DocumentNode node, Set<String> touched) {
    if (touched.contains(node.id)) {
      return true;
    }
    final entry = mirror.entryOf(node.id);
    return entry == null || !identical(entry.node, node);
  }

  void _appendGapChange(
    Delta delta,
    Delta inverse,
    List<MirrorEntry> oldEntries,
    List<MirrorEntry> newEntries,
    Map<String, List<NodeChangeEvent>> textEventsByNode,
    bool hasStructuralEvent,
  ) {
    final oldLength = oldEntries.fold<int>(0, (sum, e) => sum + e.length);
    final newLength = newEntries.fold<int>(0, (sum, e) => sum + e.length);

    // Fast path: one node, one text insertion or deletion.
    if (!hasStructuralEvent &&
        oldEntries.length == 1 &&
        newEntries.length == 1 &&
        oldEntries.single.nodeId == newEntries.single.nodeId) {
      final events = textEventsByNode[oldEntries.single.nodeId];
      if (events != null && events.length == 1) {
        final event = events.single;
        if (event is TextInsertionEvent &&
            newLength == oldLength + event.text.length) {
          final inserted = newEntries.single.delta.slice(
            event.offset,
            event.offset + event.text.length,
          );
          final insertion = Delta()..retain(event.offset);
          for (final op in inserted.operations) {
            insertion.push(op);
          }
          _append(delta, insertion, oldLength);
          _append(
            inverse,
            Delta()
              ..retain(event.offset)
              ..delete(event.text.length),
            newLength,
          );
          return;
        }
        if (event is TextDeletedEvent &&
            oldLength == newLength + event.deletedText.length) {
          final deleted = oldEntries.single.delta.slice(
            event.offset,
            event.offset + event.deletedText.length,
          );
          _append(
            delta,
            Delta()
              ..retain(event.offset)
              ..delete(event.deletedText.length),
            oldLength,
          );
          final restore = Delta()..retain(event.offset);
          for (final op in deleted.operations) {
            restore.push(op);
          }
          _append(inverse, restore, newLength);
          return;
        }
      }
    }

    final oldDelta = Delta();
    for (final entry in oldEntries) {
      for (final op in entry.delta.operations) {
        oldDelta.push(op);
      }
    }
    final newDelta = Delta();
    for (final entry in newEntries) {
      for (final op in entry.delta.operations) {
        newDelta.push(op);
      }
    }
    final change = oldDelta.diff(newDelta, cleanupSemantic: false);
    _append(delta, change, oldLength);
    _append(inverse, DeltaOps.invert(change, oldDelta), newLength);
  }

  /// Appends [part] (a change over a base of [baseLength]) to [target] and pads
  /// it with a retain to cover the whole base.
  static void _append(Delta target, Delta part, int baseLength) {
    var consumed = 0;
    for (final op in part.operations) {
      target.push(op);
      if (!op.isInsert) {
        consumed += op.length!;
      }
    }
    if (consumed < baseLength) {
      target.retain(baseLength - consumed);
    }
  }
}
