import 'package:clock/clock.dart';

import '../commands/command_types.dart';

/// A change made by someone else (or by the server) that arrived after a local
/// undo entry was recorded. Each domain defines its own subclasses
/// (`write.content` carries a Delta, `sheets.rows` the changed columns, …).
abstract class RemoteChange {
  const RemoteChange();

  /// The domain this change belongs to; entries of other domains ignore it.
  String get domain;
}

/// A generic "field changed remotely" change, used by metadata-style domains
/// (`drive`, `write.meta`, …): the field [key] of [target] now has [value].
class FieldRemoteChange extends RemoteChange {
  const FieldRemoteChange({
    required this.domain,
    required this.target,
    required this.key,
    this.value,
    this.deleted = false,
  });

  @override
  final String domain;

  /// The object id (item uuid, thread uuid …).
  final String target;

  /// The changed field.
  final String key;

  /// The new value.
  final Object? value;

  /// Whether [target] was deleted entirely.
  final bool deleted;
}

/// One undoable change in one domain (suite 08 §3.2).
abstract class UndoEntry {
  const UndoEntry();

  /// Domain key ("write.content", "write.meta", "sheets.rows", "drive"…).
  /// Routes the entry to the matching [UndoHandler].
  String get domain;

  /// Called when a remote change arrives in this domain. Returns the rebased
  /// entry, or null if the entry is now a no-op.
  UndoEntry? rebase(RemoteChange change);

  /// Merges [next] (a later entry of the same coalesced step) into this
  /// entry, or returns null when they cannot be merged and must both be kept.
  UndoEntry? coalesce(UndoEntry next) => null;

  /// JSON for best-effort persistence (null = not persistable; the step is
  /// then dropped from the persisted stack).
  Map<String, Object?>? toJson() => null;
}

/// Decodes persisted entries of one domain.
typedef UndoEntryDecoder = UndoEntry? Function(Map<String, Object?> json);

/// Selection to restore on undo/redo. Opaque to the shell; each app encodes
/// its own selection (Delta offsets, cell ranges by id, drive item uuids).
class SelectionSnapshot {
  const SelectionSnapshot(this.domain, [this.data = const {}]);

  /// Which surface the selection belongs to (`write.editor`, `sheets.grid`,
  /// `drive.list`).
  final String domain;

  /// JSON payload.
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {'domain': domain, 'data': data};

  static SelectionSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final domain = json['domain'];
    final data = json['data'];
    if (domain is! String) return null;
    return SelectionSnapshot(
      domain,
      data is Map ? Map<String, Object?>.from(data) : const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SelectionSnapshot &&
      other.domain == domain &&
      _deepEquals(other.data, data);

  @override
  int get hashCode => Object.hash(domain, data.length);

  @override
  String toString() => 'SelectionSnapshot($domain, $data)';
}

bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// One user gesture = one undo step: a labelled group of entries committed
/// atomically.
class UndoStep {
  UndoStep({
    required this.id,
    required this.label,
    required List<UndoEntry> entries,
    this.selectionBefore,
    this.selectionAfter,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.source = InvocationSource.ui,
    this.coalesceKey,
    this.partiallyRebased = false,
  }) : entries = List.unmodifiable(entries),
       createdAt = createdAt ?? clock.now(),
       updatedAt = updatedAt ?? createdAt ?? clock.now();

  /// Unique id of the step (used by `shell.edit.undoTo`).
  final String id;

  /// "Typing", "Insert row", "Paste" … — shown as "Undo Typing".
  final String label;

  /// Entries, applied in reverse order on undo.
  final List<UndoEntry> entries;

  final SelectionSnapshot? selectionBefore;
  final SelectionSnapshot? selectionAfter;
  final DateTime createdAt;

  /// Last time an entry was coalesced into the step.
  final DateTime updatedAt;

  /// So MCP/AI steps can be labelled ("Undo AI edit").
  final InvocationSource source;

  /// Consecutive steps with the same key within the coalescing window merge
  /// (typing in the same block).
  final String? coalesceKey;

  /// Whether some entries were dropped because a collaborator changed the
  /// same data; the UI then shows "Some changes couldn't be undone…".
  final bool partiallyRebased;

  /// The domains touched by this step.
  Set<String> get domains => {for (final e in entries) e.domain};

  UndoStep copyWith({
    String? label,
    List<UndoEntry>? entries,
    SelectionSnapshot? selectionBefore,
    SelectionSnapshot? selectionAfter,
    DateTime? updatedAt,
    bool? partiallyRebased,
  }) => UndoStep(
    id: id,
    label: label ?? this.label,
    entries: entries ?? this.entries,
    selectionBefore: selectionBefore ?? this.selectionBefore,
    selectionAfter: selectionAfter ?? this.selectionAfter,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    source: source,
    coalesceKey: coalesceKey,
    partiallyRebased: partiallyRebased ?? this.partiallyRebased,
  );

  /// Rebases every entry over [change]; entries that become no-ops are
  /// dropped. Returns null when nothing is left.
  UndoStep? rebase(RemoteChange change) {
    var dropped = false;
    final out = <UndoEntry>[];
    for (final e in entries) {
      if (e.domain != change.domain) {
        out.add(e);
        continue;
      }
      final r = e.rebase(change);
      if (r == null) {
        dropped = true;
      } else {
        out.add(r);
      }
    }
    if (out.isEmpty) return null;
    if (!dropped) {
      var same = true;
      for (var i = 0; i < out.length; i++) {
        if (!identical(out[i], entries[i])) same = false;
      }
      if (same) return this;
    }
    return copyWith(
      entries: out,
      partiallyRebased: partiallyRebased || dropped,
    );
  }

  /// JSON for persistence, or null when an entry is not persistable.
  Map<String, Object?>? toJson() {
    final encoded = <Map<String, Object?>>[];
    for (final e in entries) {
      final j = e.toJson();
      if (j == null) return null;
      encoded.add({'domain': e.domain, 'entry': j});
    }
    return {
      'id': id,
      'label': label,
      'entries': encoded,
      if (selectionBefore != null) 'selectionBefore': selectionBefore!.toJson(),
      if (selectionAfter != null) 'selectionAfter': selectionAfter!.toJson(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'source': source.name,
      if (coalesceKey != null) 'coalesceKey': coalesceKey,
    };
  }

  /// Inverse of [toJson]; returns null when an entry cannot be decoded.
  static UndoStep? fromJson(
    Map<String, Object?> json,
    Map<String, UndoEntryDecoder> decoders,
  ) {
    final rawEntries = json['entries'];
    if (rawEntries is! List) return null;
    final entries = <UndoEntry>[];
    for (final raw in rawEntries) {
      if (raw is! Map) return null;
      final domain = raw['domain'];
      final entry = raw['entry'];
      final decoder = decoders[domain];
      if (decoder == null || entry is! Map) return null;
      final decoded = decoder(Map<String, Object?>.from(entry));
      if (decoded == null) return null;
      entries.add(decoded);
    }
    final id = json['id'];
    final label = json['label'];
    if (id is! String || label is! String) return null;
    return UndoStep(
      id: id,
      label: label,
      entries: entries,
      selectionBefore: SelectionSnapshot.fromJson(json['selectionBefore']),
      selectionAfter: SelectionSnapshot.fromJson(json['selectionAfter']),
      createdAt: DateTime.tryParse('${json['createdAt']}'),
      updatedAt: DateTime.tryParse('${json['updatedAt']}'),
      source: InvocationSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => InvocationSource.ui,
      ),
      coalesceKey: json['coalesceKey'] as String?,
    );
  }

  @override
  String toString() => 'UndoStep($label, ${entries.length} entries)';
}

/// Applies undo/redo for one domain (suite 08 §3.2).
abstract class UndoHandler<E extends UndoEntry> {
  const UndoHandler();

  /// The domain this handler serves.
  String get domain;

  /// Applies the inverse of [entry] as a new forward change and returns the
  /// entry that would redo it. Throws [UndoConflict] when the entry could not
  /// be applied because someone else changed the data in the meantime.
  Future<E> undo(E entry);

  /// Re-applies [entry] and returns the entry that would undo it again.
  Future<E> redo(E entry);

  /// Decoder for persisted entries of this domain (null = not persisted).
  UndoEntryDecoder? get decoder => null;
}

/// Thrown by an [UndoHandler] when an entry is skipped because the data was
/// edited by someone else. The step continues with the remaining entries.
class UndoConflict implements Exception {
  const UndoConflict([this.message]);

  final String? message;

  @override
  String toString() => 'UndoConflict(${message ?? ''})';
}
