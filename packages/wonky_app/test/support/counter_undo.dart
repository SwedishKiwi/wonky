import 'package:wonky_core/wonky_core.dart';

/// A tiny undo domain for tests: sets `values[key]` from [before] to [after].
class CounterEntry extends UndoEntry {
  const CounterEntry(this.key, this.before, this.after);

  final String key;
  final int before;
  final int after;

  static const domainName = 'test.counter';

  @override
  String get domain => domainName;

  @override
  UndoEntry? rebase(RemoteChange change) {
    if (change is FieldRemoteChange && change.target == key) {
      return change.deleted ? null : this;
    }
    return this;
  }

  @override
  UndoEntry? coalesce(UndoEntry next) => next is CounterEntry && next.key == key
      ? CounterEntry(key, before, next.after)
      : null;

  @override
  Map<String, Object?> toJson() => {
    'key': key,
    'before': before,
    'after': after,
  };

  static CounterEntry? fromJson(Map<String, Object?> j) => CounterEntry(
    j['key']! as String,
    j['before']! as int,
    j['after']! as int,
  );
}

/// Applies [CounterEntry]s to [values]; keys in [conflicting] throw
/// [UndoConflict].
class CounterHandler extends UndoHandler<UndoEntry> {
  CounterHandler(this.values);

  final Map<String, int> values;
  final Set<String> conflicting = {};

  @override
  String get domain => CounterEntry.domainName;

  @override
  Future<UndoEntry> undo(UndoEntry entry) async {
    final e = entry as CounterEntry;
    if (conflicting.contains(e.key)) throw const UndoConflict('changed');
    values[e.key] = e.before;
    return e;
  }

  @override
  Future<UndoEntry> redo(UndoEntry entry) async {
    final e = entry as CounterEntry;
    if (conflicting.contains(e.key)) throw const UndoConflict('changed');
    values[e.key] = e.after;
    return e;
  }

  @override
  UndoEntryDecoder? get decoder => CounterEntry.fromJson;
}
