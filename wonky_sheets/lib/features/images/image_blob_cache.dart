import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';

/// Schema of `sheets_images_<userId>.db` (08 §10.1, A-08-5
/// `LocalBlobCache`): the encoded bytes of images this device inserted or
/// downloaded, so spreadsheets show their images offline and after a
/// reload. Local only; least recently used entries are purged above
/// [SheetsImageBlobCache.maxBytes].
final sheetsImageCacheMigrations = SqliteMigrations()
  ..add(
    SqliteMigration(1, (tx) async {
      await tx.execute('''
        CREATE TABLE local_blob_cache (
          file_uuid TEXT PRIMARY KEY NOT NULL,
          mime TEXT NOT NULL,
          bytes BLOB NOT NULL,
          size INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          used_at INTEGER NOT NULL
        )''');
    }),
  );

/// One cached image file.
@immutable
class CachedBlob {
  const CachedBlob(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

/// Storage of [SheetsImageBlobCache] (SQLite; a map in tests).
abstract class ImageBlobStore {
  Future<void> put(String key, Uint8List bytes, String mime);
  Future<CachedBlob?> get(String key);
  Future<void> touch(String key);

  /// Deletes the least recently used entries until at most [maxBytes] stay.
  Future<void> trim(int maxBytes);
  Future<void> close();
}

/// [ImageBlobStore] on the per-user SQLite database.
class SqliteImageBlobStore implements ImageBlobStore {
  SqliteImageBlobStore(this.db);

  final SqliteDatabase db;

  @override
  Future<void> put(String key, Uint8List bytes, String mime) {
    final now = clock.now().millisecondsSinceEpoch;
    return db.execute(
      'INSERT OR REPLACE INTO local_blob_cache (file_uuid, mime, bytes, size, '
      'created_at, used_at) VALUES (?, ?, ?, ?, ?, ?)',
      [key, mime, bytes, bytes.length, now, now],
    );
  }

  @override
  Future<CachedBlob?> get(String key) async {
    final r = await db.getOptional(
      'SELECT mime, bytes FROM local_blob_cache WHERE file_uuid = ?',
      [key],
    );
    if (r == null) return null;
    final bytes = switch (r['bytes']) {
      final Uint8List b => b,
      final List<int> b => Uint8List.fromList(b),
      _ => null,
    };
    if (bytes == null) return null;
    return CachedBlob(bytes, r['mime']! as String);
  }

  @override
  Future<void> touch(String key) => db.execute(
    'UPDATE local_blob_cache SET used_at = ? WHERE file_uuid = ?',
    [clock.now().millisecondsSinceEpoch, key],
  );

  @override
  Future<void> trim(int maxBytes) => db.writeTransaction((tx) async {
    final rows = await tx.getAll(
      'SELECT file_uuid, size FROM local_blob_cache ORDER BY used_at DESC',
    );
    var total = 0;
    final drop = <String>[];
    for (final r in rows) {
      total += r['size']! as int;
      if (total > maxBytes) drop.add(r['file_uuid']! as String);
    }
    for (final k in drop) {
      await tx.execute('DELETE FROM local_blob_cache WHERE file_uuid = ?', [k]);
    }
  });

  @override
  Future<void> close() => db.close();
}

/// [ImageBlobStore] in memory (tests).
class MemoryImageBlobStore implements ImageBlobStore {
  final Map<String, (CachedBlob, int)> rows = {};
  int _tick = 0;

  @override
  Future<void> put(String key, Uint8List bytes, String mime) async =>
      rows[key] = (CachedBlob(bytes, mime), _tick++);

  @override
  Future<CachedBlob?> get(String key) async => rows[key]?.$1;

  @override
  Future<void> touch(String key) async {
    final r = rows[key];
    if (r != null) rows[key] = (r.$1, _tick++);
  }

  @override
  Future<void> trim(int maxBytes) async {
    final keys = rows.keys.toList()
      ..sort((a, b) => rows[b]!.$2.compareTo(rows[a]!.$2));
    var total = 0;
    for (final k in keys) {
      total += rows[k]!.$1.bytes.length;
      if (total > maxBytes) rows.remove(k);
    }
  }

  @override
  Future<void> close() async {}
}

/// The local image cache of the signed-in user (08 §10.1): bytes of images
/// inserted on this device (before and after their upload) and of images
/// downloaded from the files service, keyed by file uuid (or the https
/// URL for `IMAGE()` sources). One per signed-in user ([install]).
class SheetsImageBlobCache {
  SheetsImageBlobCache(this.store, {this.maxBytes = defaultMaxBytes});

  final ImageBlobStore store;
  final int maxBytes;

  /// 200 MB.
  static const defaultMaxBytes = 200 * 1024 * 1024;

  int _writes = 0;

  /// Stores [bytes] for [key] (best effort).
  Future<void> put(String key, Uint8List bytes, String mime) async {
    if (bytes.length > maxBytes ~/ 4) return;
    try {
      await store.put(key, bytes, mime);
      // Trim now and then, not on every write.
      if (++_writes % 8 == 1) await store.trim(maxBytes);
    } on Object catch (e) {
      debugPrint('Caching an image failed: $e');
    }
  }

  /// The cached bytes of [key], or null.
  Future<CachedBlob?> get(String key) async {
    try {
      final b = await store.get(key);
      if (b != null) unawaited(store.touch(key).catchError((_) {}));
      return b;
    } on Object catch (e) {
      debugPrint('Reading the image cache failed: $e');
      return null;
    }
  }

  // ------------------------------------------------------- per user

  static final Expando<_Install> _installs = Expando('SheetsImageBlobCache');

  /// `sheets_images_<userId>.db`.
  static String fileNameFor(String userUuid) => 'sheets_images_$userUuid.db';

  /// Opens the signed-in user's cache now and whenever the user changes
  /// (idempotent). [openStore] overrides the SQLite store (tests).
  static void install(
    ShellServices services, {
    Future<ImageBlobStore> Function(String userUuid)? openStore,
  }) {
    if (_installs[services] != null) return;
    final inst = _Install(
      services,
      openStore ??
          (user) async => SqliteImageBlobStore(
            await LocalDatabases.open(
              fileNameFor(user),
              migrations: sheetsImageCacheMigrations,
            ),
          ),
    );
    _installs[services] = inst;
    services.currentUser.addListener(inst.onUser);
    inst.onUser();
  }

  /// Installs [cache] for [services] without a user (tests).
  @visibleForTesting
  static void installCache(ShellServices services, SheetsImageBlobCache cache) {
    _installs[services] = _Install(services, (_) async => cache.store)
      ..cache = cache
      ..opening = Future<void>.value();
  }

  /// The signed-in user's cache (null while opening, signed out or not
  /// installed).
  static SheetsImageBlobCache? of(ShellServices services) =>
      _installs[services]?.cache;

  /// The cache once open (null when unavailable).
  static Future<SheetsImageBlobCache?> ready(ShellServices services) async {
    final inst = _installs[services];
    if (inst == null) return null;
    await inst.opening;
    return inst.cache;
  }
}

class _Install {
  _Install(this.s, this.openStore);

  final ShellServices s;
  final Future<ImageBlobStore> Function(String userUuid) openStore;
  String? user;
  SheetsImageBlobCache? cache;
  Future<void>? opening;

  void onUser() {
    final next = s.me?.uuid.uuid;
    if (next == user) return;
    user = next;
    final old = cache;
    cache = null;
    if (old != null) unawaited(old.store.close());
    if (next == null) return;
    opening = () async {
      try {
        final store = await openStore(next);
        if (user != next) {
          await store.close();
          return;
        }
        cache = SheetsImageBlobCache(store);
      } on Object catch (e) {
        debugPrint('Opening the Sheets image cache failed: $e');
      }
    }();
  }
}
