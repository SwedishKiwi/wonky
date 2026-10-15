import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart'
    show
        ConnectivityService,
        OfflineDataProvider,
        OfflineUsage,
        OfflineWarning,
        ShellServices;
import 'package:wonky_client/wonky_client.dart'
    show Client, DriveItemKind, DriveItemView, UuidValue;

import '../controller/app_sync_controller.dart';
import '../controller/sync_remote.dart';
import '../controller/sync_session_host.dart';
import '../replica/replica_files.dart';
import '../replica/sync_replica.dart';
import '../writer/sync_writer.dart';

/// [SyncConnectivity] on the shell's [ConnectivityService].
class ShellSyncConnectivity implements SyncConnectivity {
  ShellSyncConnectivity(this.service)
    : _online = ValueNotifier(service.online) {
    service.addListener(_sync);
  }

  final ConnectivityService service;
  final ValueNotifier<bool> _online;

  void _sync() => _online.value = service.online;

  @override
  ValueListenable<bool> get online => _online;

  @override
  void reportFailure() => service.reportFailure();

  @override
  void reportSuccess() => service.reportSuccess();

  void dispose() {
    service.removeListener(_sync);
    _online.dispose();
  }
}

/// The per-user lifecycle of an app's sync data layer (suite 12 §2.5): one
/// controller per signed-in user, opened when the profile is known (also
/// offline, from the cached profile) and closed when the user signs out or
/// changes; sync pauses while the app is hidden (`AppLifecycleListener`).
///
/// A replica that can't be opened is moved aside (desktop; kept for
/// recovery after [readRecovery] read what it could) and a fresh one
/// re-syncs. [reset] is *Clear local data*.
///
/// Apps subclass it (Sheets' `SheetsData` installation) with their replica
/// file, opener and controller, and register their offline provider in
/// [started].
abstract class ReplicaInstallation<
  R extends SyncReplica,
  C extends AppSyncController<R, SyncWriter, HostedSpaceSession>
> {
  ReplicaInstallation(this.services, {this.opener});

  final ShellServices services;

  /// Replaces the production replica opener (tests).
  final Future<R> Function(UuidValue user)? opener;

  /// Desktop directory of the replica (tests); null = the default.
  String? get directory => null;

  /// The open controller (null while opening, signed out or failed).
  C? controller;

  /// Completes with the next controller that starts.
  Completer<C> next = Completer();

  String? _user;
  ShellSyncConnectivity? _connectivity;
  AppLifecycleListener? _lifecycle;
  Future<void> _switching = Future.value();

  /// The app's key in log messages (`Sheets`, `Slides`).
  String get name;

  /// The replica file name of [user] (`sheets_<userId>.db`).
  String fileNameFor(String user);

  /// Opens (creating and migrating) the replica at [path].
  Future<R> openReplicaAt(Client client, String path, UuidValue user);

  /// Reads what can be recovered from the broken replica at [path] before
  /// it is moved aside; the returned callback runs afterwards (offering the
  /// download). Default: nothing.
  Future<VoidCallback?> readRecovery(String path) async => null;

  /// Builds the controller on [replica] (not started yet); null when it
  /// can't run (no client), which closes the replica.
  Future<C?> createController(R replica, SyncConnectivity connectivity);

  /// The controller [c] was created and is about to start (register the
  /// offline provider here).
  void started(C c) {}

  /// The controller [c] is about to close (unregister what [started]
  /// registered).
  void closing(C c) {}

  /// Starts following the signed-in user.
  void attach() {
    services.currentUser.addListener(_onUser);
    _lifecycle = AppLifecycleListener(
      onShow: () => controller?.setVisible(true),
      onResume: () => controller?.setVisible(true),
      onHide: () => controller?.setVisible(false),
    );
    _onUser();
  }

  /// Stops following the user and closes the controller.
  Future<void> detach() async {
    services.currentUser.removeListener(_onUser);
    _lifecycle?.dispose();
    _user = null;
    await (_switching = _switching.then((_) => _close()));
  }

  /// The controller once open; null when no user appears within
  /// [timeout].
  Future<C?> ready(Duration timeout) async {
    if (controller != null) return controller;
    try {
      return await next.future.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  void _onUser() {
    final user = services.me?.uuid.uuid;
    if (user == _user) return;
    _user = user;
    _switching = _switching.then((_) async {
      await _close();
      if (user != null && user == _user) await _openFor(user);
    });
  }

  Future<void> _close() async {
    final c = controller;
    controller = null;
    if (c != null) {
      closing(c);
      await c.close();
    }
    _connectivity?.dispose();
    _connectivity = null;
    if (next.isCompleted) next = Completer();
  }

  /// *Clear local data*: deletes the replica (desktop) or empties every
  /// table (web, where databases can't be deleted), then starts over with
  /// a fresh replica that re-syncs. Unsynced changes are lost.
  Future<void> reset(String user) => _switching = _switching.then((_) async {
    final c = controller;
    if (c == null || _user != user) return;
    if (kIsWeb) {
      await c.stop();
      await c.replica.clearAllTables();
    }
    await _close();
    await ReplicaFiles.delete(fileNameFor(user), directory);
    if (_user == user) await _openFor(user);
  });

  Future<R> _openReplica(UuidValue user) async {
    final open = opener;
    if (open != null) return open(user);
    final client = services.client;
    if (client == null) throw StateError('No client');
    final name = fileNameFor(user.uuid);
    Future<R> openIt() async =>
        openReplicaAt(client, await ReplicaFiles.path(name, directory), user);
    try {
      return await openIt();
    } catch (e, st) {
      // The replica can be re-synced: move it aside (kept for recovery on
      // desktop) and start over. Files with unsynced writes are offered as
      // a download first (12 §2.5).
      debugPrint(
        'Opening the ${this.name} replica failed, resetting it: $e\n$st',
      );
      final path = await ReplicaFiles.path(name, directory);
      final offer = await readRecovery(path);
      await ReplicaFiles.moveAside(name, directory);
      offer?.call();
      return openIt();
    }
  }

  Future<void> _openFor(String user) async {
    try {
      final uuid = UuidValue.fromString(user);
      final replica = await _openReplica(uuid);
      if (_user != user) {
        await replica.close();
        return;
      }
      final connectivity = ShellSyncConnectivity(services.connectivity);
      final c = await createController(replica, connectivity);
      if (c == null) {
        connectivity.dispose();
        await replica.close();
        return;
      }
      _connectivity = connectivity;
      controller = c;
      started(c);
      c.start();
      if (!next.isCompleted) next.complete(c);
    } catch (e, st) {
      debugPrint('Starting $name sync failed: $e\n$st');
    }
  }
}

/// An app's entry in Settings › Offline & storage and the drive's offline
/// badges: the files of [kind] on the device (root rows of the replica) and
/// the spaces with unsynced writes. Refreshes after every sync cycle.
class ReplicaOfflineProvider extends ChangeNotifier
    implements OfflineDataProvider {
  ReplicaOfflineProvider(
    this.controller,
    this.onClear, {
    required this.id,
    required this.kind,
    this.warning,
  }) {
    controller.cycles.addListener(_refresh);
    _refresh();
  }

  final AppSyncController<SyncReplica, SyncWriter, HostedSpaceSession>
  controller;
  final Future<void> Function() onClear;

  @override
  final String id;

  /// The drive item kind of the app's files.
  final DriveItemKind kind;

  /// A storage limit of this device ("Offline storage is limited in this
  /// browser").
  final OfflineWarning? warning;

  Set<String> _local = const {};
  OfflineUsage _usage = OfflineUsage.empty;
  bool _disposed = false;

  @override
  bool? isAvailableOffline(DriveItemView item) {
    if (item.kind != kind) return null;
    final space = item.contentRef?.uuid ?? item.uuid.uuid;
    return _local.contains(space);
  }

  @override
  OfflineUsage get usage => _usage;

  Future<void> _refresh() async {
    final r = controller.replica;
    if (r.isClosed || _disposed) return;
    try {
      final ids = await r.rootIds();
      final dirty = await r.dirtySpaces();
      if (_disposed) return;
      _local = {for (final s in ids) s.uuid};
      _usage = OfflineUsage(
        documents: _local.length,
        pendingChanges: dirty.length,
        warnings: [?warning],
      );
      notifyListeners();
    } catch (_) {}
  }

  @override
  Future<void> clear() => onClear();

  @override
  void dispose() {
    _disposed = true;
    controller.cycles.removeListener(_refresh);
    super.dispose();
  }
}
