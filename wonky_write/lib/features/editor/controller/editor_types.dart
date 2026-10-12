import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';

import '../applier/delta_applier.dart';
import '../extractor/change_delta_extractor.dart';

export '../extractor/change_delta_extractor.dart' show LocalChangeKind;

/// Per-user, per-session view mode of the editor (Write 04 §31).
enum EditorMode {
  /// Direct editing (Editors, Owners).
  editing,

  /// Every edit becomes a suggestion (Commenters always; Editors opt-in).
  suggesting,

  /// Read-only (`SuperReader`).
  viewing,
}

/// How suggestions are rendered (`write.view.suggestionPreview`, Write 04 §31).
enum SuggestionPreviewMode {
  /// Suggestions shown with colors (default in Editing/Suggesting).
  show,

  /// As if all suggestions were accepted.
  accepted,

  /// As if all suggestions were rejected (default in Viewing).
  original,
}

/// Layout of the document canvas (Write 04 §29.2).
enum LayoutMode { pages, pageless }

/// User preferences that change editor behavior (`UserPreferences.writeDefaults`,
/// Write 04 §7–9, §23.2, §28).
@immutable
class WriteEditorPreferences {
  const WriteEditorPreferences({
    this.markdownShortcuts = true,
    this.smartTypography = true,
    this.autoPair = true,
    this.autolink = true,
    this.copyPlainTextAsMarkdown = true,
    this.spellcheck = true,
    this.screenReaderMode = false,
  });

  final bool markdownShortcuts;
  final bool smartTypography;
  final bool autoPair;
  final bool autolink;
  final bool copyPlainTextAsMarkdown;
  final bool spellcheck;
  final bool screenReaderMode;

  WriteEditorPreferences copyWith({
    bool? markdownShortcuts,
    bool? smartTypography,
    bool? autoPair,
    bool? autolink,
    bool? copyPlainTextAsMarkdown,
    bool? spellcheck,
    bool? screenReaderMode,
  }) => WriteEditorPreferences(
    markdownShortcuts: markdownShortcuts ?? this.markdownShortcuts,
    smartTypography: smartTypography ?? this.smartTypography,
    autoPair: autoPair ?? this.autoPair,
    autolink: autolink ?? this.autolink,
    copyPlainTextAsMarkdown:
        copyPlainTextAsMarkdown ?? this.copyPlainTextAsMarkdown,
    spellcheck: spellcheck ?? this.spellcheck,
    screenReaderMode: screenReaderMode ?? this.screenReaderMode,
  );

  @override
  bool operator ==(Object other) =>
      other is WriteEditorPreferences &&
      other.markdownShortcuts == markdownShortcuts &&
      other.smartTypography == smartTypography &&
      other.autoPair == autoPair &&
      other.autolink == autolink &&
      other.copyPlainTextAsMarkdown == copyPlainTextAsMarkdown &&
      other.spellcheck == spellcheck &&
      other.screenReaderMode == screenReaderMode;

  @override
  int get hashCode => Object.hash(
    markdownShortcuts,
    smartTypography,
    autoPair,
    autolink,
    copyPlainTextAsMarkdown,
    spellcheck,
    screenReaderMode,
  );
}

/// Where a local change came from.
enum LocalChangeSource {
  /// Typing, IME, keyboard editing, gestures inside the editor.
  input,

  /// An editor command (format, insert, block, …).
  command,

  /// An autoformat / smart typography reaction (a separate undo step).
  reaction,

  /// Undo or redo (never put on the undo stack again by the undo handler).
  undo,

  /// Clipboard paste or drop.
  paste,

  /// AI or MCP edits applied locally.
  agent,
}

/// A local change of the document, ready for the undo handler and the sync
/// controller (Write 02 §4.4, Write 03 §3–4).
@immutable
class LocalDeltaChange {
  const LocalDeltaChange({
    required this.delta,
    required this.inverse,
    required this.label,
    required this.kind,
    required this.source,
    required this.at,
    this.selectionBefore,
    this.selectionAfter,
    this.nodeIds = const {},
    this.isComposing = false,
  });

  /// The change against the document before it (submit as an op).
  final Delta delta;

  /// `delta.invert(documentBefore)` (the undo entry, domain `write.content`).
  final Delta inverse;

  /// Undo label ("Typing", "Bold", "Autoformat"…).
  final String label;

  final LocalChangeKind kind;
  final LocalChangeSource source;

  /// When the change was made (from the injected clock).
  final DateTime at;

  /// Selections (Delta offsets) before and after the change.
  final DeltaSelection? selectionBefore;
  final DeltaSelection? selectionAfter;

  /// Ids of the nodes the change touched (typing coalescing: same node).
  final Set<String> nodeIds;

  /// Whether an IME composition was in progress (compositions coalesce).
  final bool isComposing;

  /// Whether [next] may join this change's undo step (Write 04 §3.3): same
  /// kind (typing or deletion), same node, within [window], no caret jump,
  /// and the group hasn't grown past a word boundary after [maxGroupLength]
  /// characters ([groupLength] = characters already in the group).
  bool canCoalesce(
    LocalDeltaChange next, {
    Duration window = const Duration(milliseconds: 1000),
    int groupLength = 0,
    int maxGroupLength = 50,
  }) {
    if (source != LocalChangeSource.input ||
        next.source != LocalChangeSource.input) {
      return false;
    }
    if (kind == LocalChangeKind.other || next.kind != kind) {
      return false;
    }
    if (next.at.difference(at) > window) {
      return false;
    }
    if (nodeIds.length != 1 || !setEquals(nodeIds, next.nodeIds)) {
      return false;
    }
    if (selectionAfter != null &&
        next.selectionBefore != null &&
        selectionAfter != next.selectionBefore) {
      return false;
    }
    if (isComposing || next.isComposing) {
      return true;
    }
    if (groupLength >= maxGroupLength && kind == LocalChangeKind.typing) {
      final text = _insertedText(next.delta);
      if (text.isNotEmpty && text.trim().isEmpty) {
        // A word boundary after a long group closes it.
        return false;
      }
    }
    return true;
  }

  static String _insertedText(Delta delta) => delta.operations
      .where((op) => op.isInsert && op.data is String)
      .map((op) => op.data as String)
      .join();

  /// Number of characters this change inserts or deletes (group length).
  int get size {
    var size = 0;
    for (final op in delta.operations) {
      if (op.isInsert || op.isDelete) size += op.length!;
    }
    return size;
  }

  LocalDeltaChange copyWith({String? label, LocalChangeSource? source}) =>
      LocalDeltaChange(
        delta: delta,
        inverse: inverse,
        label: label ?? this.label,
        kind: kind,
        source: source ?? this.source,
        at: at,
        selectionBefore: selectionBefore,
        selectionAfter: selectionAfter,
        nodeIds: nodeIds,
        isComposing: isComposing,
      );

  @override
  String toString() => 'LocalDeltaChange($label, $kind, $source: $delta)';
}
