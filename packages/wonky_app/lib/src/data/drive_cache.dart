import 'dart:async';

import 'package:clock/clock.dart';
import 'package:wonky_client/wonky_client.dart';

import '../core/local_store.dart';

/// Locally cached drive listing for offline browsing (suite 05 §4, 12 §3):
/// the last 500 items seen plus every item pinned offline, and the item
/// order of each listing that was shown.
///
/// The cache is per user: [bindUser] switches to the signed-in user's data
/// (stored under `u.<userUuid>.` in the store given to the constructor).
class DriveCache {
  DriveCache(this._base, {this.maxItems = 500}) : _store = _base;

  final LocalStore _base;
  LocalStore _store;
  String? _user;
  final int maxItems;
  final Map<String, DriveItemView> _items = {};
  final Map<String, DateTime> _seen = {};
  final Map<String, List<String>> _lists = {};
  final _changes = StreamController<DriveItemView>.broadcast(sync: true);
  Timer? _saveTimer;
  bool _loaded = false;

  /// Items stored or updated (offline availability follows pins).
  Stream<DriveItemView> get changes => _changes.stream;

  /// The user whose cache is loaded.
  String? get user => _user;

  /// Switches to [userUuid]'s cache (sign-in) and loads it.
  Future<void> bindUser(String userUuid) async {
    if (_user == userUuid) return load();
    _saveTimer?.cancel();
    _user = userUuid;
    _store = _base.scoped('u.$userUuid.');
    _items.clear();
    _seen.clear();
    _lists.clear();
    _loaded = false;
    await load();
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read('drive.cache');
      if (raw is Map) {
        final items = raw['items'];
        if (items is List) {
          for (final j in items) {
            final v = DriveItemView.fromJson(
              (j as Map).cast<String, dynamic>(),
            );
            _items[v.uuid.uuid] = v;
            _seen[v.uuid.uuid] = clock.now();
          }
        }
        final lists = raw['lists'];
        if (lists is Map) {
          for (final e in lists.entries) {
            _lists['${e.key}'] = [for (final u in e.value as List) '$u'];
          }
        }
      }
    } catch (_) {
      // A corrupt cache is discarded.
      _items.clear();
      _lists.clear();
    }
  }

  DriveItemView? item(UuidValue uuid) => _items[uuid.uuid];

  Iterable<DriveItemView> get items => _items.values;

  /// Stores [views] and returns them.
  List<DriveItemView> put(Iterable<DriveItemView> views) {
    final out = <DriveItemView>[];
    for (final v in views) {
      _items[v.uuid.uuid] = v;
      _seen[v.uuid.uuid] = clock.now();
      out.add(v);
      if (_changes.hasListener) _changes.add(v);
    }
    _trim();
    _scheduleSave();
    return out;
  }

  /// Records the order of a listing identified by [key].
  void putList(String key, List<DriveItemView> views, {bool append = false}) {
    put(views);
    final ids = [for (final v in views) v.uuid.uuid];
    _lists[key] = append ? [...?_lists[key], ...ids] : ids;
    _scheduleSave();
  }

  /// A cached listing (items still present), or null.
  List<DriveItemView>? list(String key) {
    final ids = _lists[key];
    if (ids == null) return null;
    return [
      for (final id in ids)
        if (_items[id] != null) _items[id]!,
    ];
  }

  void update(UuidValue uuid, DriveItemView Function(DriveItemView) f) {
    final v = _items[uuid.uuid];
    if (v == null) return;
    final next = _items[uuid.uuid] = f(v);
    if (_changes.hasListener) _changes.add(next);
    _scheduleSave();
  }

  void remove(UuidValue uuid) {
    _items.remove(uuid.uuid);
    for (final l in _lists.values) {
      l.remove(uuid.uuid);
    }
    _scheduleSave();
  }

  /// Adds [view] at the top of the listings of its folder.
  void insertIntoFolderLists(DriveItemView view) {
    put([view]);
    final folderKey = 'folder:${view.parentUuid?.uuid ?? 'root'}';
    for (final e in _lists.entries) {
      if (e.key.startsWith(folderKey) && !e.value.contains(view.uuid.uuid)) {
        e.value.insert(0, view.uuid.uuid);
      }
    }
    _scheduleSave();
  }

  /// Clears everything (Settings › Offline & storage › Clear local data).
  Future<void> clear() async {
    _items.clear();
    _lists.clear();
    _seen.clear();
    await _store.remove('drive.cache');
  }

  void _trim() {
    if (_items.length <= maxItems) return;
    final removable = [
      for (final v in _items.values)
        if (!v.pinnedOffline) v.uuid.uuid,
    ]..sort((a, b) => _seen[a]!.compareTo(_seen[b]!));
    var excess = _items.length - maxItems;
    for (final id in removable) {
      if (excess-- <= 0) break;
      _items.remove(id);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  Future<void> save() async {
    _saveTimer?.cancel();
    await _store.write('drive.cache', {
      'items': [for (final v in _items.values) v.toJson()],
      'lists': _lists,
    });
  }

  void dispose() {
    _saveTimer?.cancel();
    unawaited(_changes.close());
  }
}

/// A drive operation made while offline, replayed in order on reconnect.
class PendingDriveOp {
  PendingDriveOp({
    required this.id,
    required this.kind,
    required this.args,
    required this.createdAt,
  });

  final String id;

  /// rename, move, setStarred, setPinnedOffline, trash, restore,
  /// createDocument, registerSpreadsheet.
  final String kind;
  final Map<String, Object?> args;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'args': args,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  static PendingDriveOp fromJson(Map<String, Object?> j) => PendingDriveOp(
    id: j['id']! as String,
    kind: j['kind']! as String,
    args: (j['args']! as Map).cast<String, Object?>(),
    createdAt: DateTime.parse(j['createdAt']! as String),
  );
}

/// Persistent FIFO of [PendingDriveOp]s (per user, see
/// [DriveCache.bindUser]).
class PendingDriveOpQueue {
  PendingDriveOpQueue(this._base) : _store = _base;

  final LocalStore _base;
  LocalStore _store;
  String? _user;
  final List<PendingDriveOp> _ops = [];
  bool _loaded = false;

  List<PendingDriveOp> get ops => List.unmodifiable(_ops);

  int get length => _ops.length;

  /// Switches to [userUuid]'s queue and loads it.
  Future<void> bindUser(String userUuid) async {
    if (_user == userUuid) return load();
    _user = userUuid;
    _store = _base.scoped('u.$userUuid.');
    _ops.clear();
    _loaded = false;
    await load();
  }

  /// Replaces the first operation (e.g. a retry with adjusted arguments).
  Future<void> replaceFirst(PendingDriveOp op) async {
    if (_ops.isEmpty) return;
    _ops[0] = op;
    await _persist();
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read('drive.pending');
    if (raw is List) {
      for (final j in raw) {
        try {
          _ops.add(PendingDriveOp.fromJson((j as Map).cast<String, Object?>()));
        } catch (_) {}
      }
    }
  }

  Future<void> add(PendingDriveOp op) async {
    _ops.add(op);
    await _persist();
  }

  Future<void> removeFirst() async {
    if (_ops.isEmpty) return;
    _ops.removeAt(0);
    await _persist();
  }

  Future<void> clear() async {
    _ops.clear();
    await _persist();
  }

  Future<void> _persist() =>
      _store.write('drive.pending', [for (final o in _ops) o.toJson()]);
}
