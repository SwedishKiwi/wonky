import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../core/local_store.dart';
import 'storage_controller.dart';

/// The production [StorageController] (Drive 03 §3, §6): loads
/// `drive.storageUsage` when the user signs in, follows the `storageChanged`
/// events of the supervised `drive.watch` stream, refetches when the drive
/// refreshes (reconnect, empty trash) and caches the last value per user,
/// so meters and banners show it offline ([stale]).
///
/// `WonkyShell` creates it and calls [start] after sign-in and [stop]
/// before sign-out.
class LiveStorageController extends ChangeNotifier
    implements StorageController {
  LiveStorageController({
    required this._fetch,
    required this._checkRoom,
    this._cache,
    this.refreshDelay = const Duration(milliseconds: 300),
  });

  final Future<StorageUsage> Function() _fetch;
  final Future<void> Function(int bytes, UuidValue? itemUuid) _checkRoom;
  final LocalStore Function()? _cache;

  /// Coalesces refresh signals (several drive refreshes in a row → one
  /// fetch).
  final Duration refreshDelay;

  /// The cache key in the per-user store.
  static const cacheKey = 'storage.usage';

  StorageUsage? _value;
  bool _stale = false;
  bool _disposed = false;
  int _generation = 0;
  StreamSubscription<DriveChange>? _changes;
  Listenable? _refreshSignal;
  Timer? _refreshTimer;

  @override
  StorageUsage? get value => _value;

  @override
  bool get stale => _stale;

  /// Starts following the signed-in user's storage: shows the cached value
  /// right away, then fetches; [changes] are the drive events (their
  /// `storageChanged` events carry the new usage), [refreshSignal] fires
  /// when listings reload (reconnect, empty trash).
  Future<void> start({
    required Stream<DriveChange> changes,
    Listenable? refreshSignal,
  }) async {
    stop();
    final gen = _generation;
    _changes = changes.listen(onDriveChange);
    _refreshSignal = refreshSignal?..addListener(_scheduleRefresh);
    await _loadCached(gen);
    if (gen != _generation) return;
    await refresh();
  }

  /// Stops following and forgets the value (sign-out).
  void stop() {
    _generation++;
    unawaited(_changes?.cancel());
    _changes = null;
    _refreshSignal?.removeListener(_scheduleRefresh);
    _refreshSignal = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _set(null, stale: false, save: false);
  }

  /// Applies a drive event: `storageChanged` replaces the usage.
  void onDriveChange(DriveChange change) {
    if (change.kind != DriveChangeKind.storageChanged) return;
    final usage = change.storage;
    if (usage != null) {
      _set(usage, stale: false);
    } else {
      _scheduleRefresh();
    }
  }

  @override
  void report(StorageUsage usage) => _set(usage, stale: false);

  @override
  Future<StorageUsage?> refresh() async {
    final gen = _generation;
    try {
      final usage = await _fetch();
      if (gen == _generation) _set(usage, stale: false);
    } catch (e) {
      // Offline or failing: the last (cached) value stays, marked stale.
      if (gen == _generation && _value != null && !_stale) {
        _stale = true;
        _notify();
      }
    }
    return _value;
  }

  @override
  Future<void> checkRoom(int bytes, {UuidValue? itemUuid}) =>
      _checkRoom(bytes, itemUuid);

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(refreshDelay, () => unawaited(refresh()));
  }

  Future<void> _loadCached(int gen) async {
    final store = _cache?.call();
    if (store == null) return;
    try {
      final raw = await store.read(cacheKey);
      if (gen != _generation || _value != null || raw is! Map) return;
      _set(
        StorageUsage.fromJson(raw.cast<String, dynamic>()),
        stale: true,
        save: false,
      );
    } catch (e) {
      debugPrint('Reading the cached storage usage failed: $e');
    }
  }

  void _set(StorageUsage? usage, {required bool stale, bool save = true}) {
    if (_disposed) return;
    _value = usage;
    _stale = stale;
    _notify();
    final store = _cache?.call();
    if (save && usage != null && store != null) {
      unawaited(
        store.write(cacheKey, usage.toJson()).catchError((Object e) {
          debugPrint('Caching the storage usage failed: $e');
        }),
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
