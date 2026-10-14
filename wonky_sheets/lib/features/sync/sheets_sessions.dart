import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:wonky_core/wonky_core.dart' show Role;

import '../../l10n/sheets_l10n.dart';

import '../formatting/sheets_user_defaults.dart';
import '../model/local_view_state.dart';
import '../model/memory_workbook_session.dart';
import '../model/workbook_session.dart';
import 'replica_recovery.dart';
import 'replica_recovery_ui.dart';
import 'replica_path_io.dart'
    if (dart.library.js_interop) 'replica_path_web.dart'
    as platform;
import 'sheets_remote.dart';
import 'sheets_replica.dart';
import 'sheets_sync_controller.dart';
import 'storage_mode.dart';
import 'synced_workbook_session.dart' show ViewportHint;

export 'sheets_sync_controller.dart'
    show SheetsSyncController, NoReservedSpaceException;

/// Opens the [WorkbookSession] of a spreadsheet item (suite 12 §2.5).
///
/// With the data layer installed ([SheetsData.install], done at sign-in)
/// this is a `SyncedWorkbookSession` on the user's replica; follow its
/// `loadState`. Without it (widget tests with fake services, signed out) an
/// in-memory blank spreadsheet. The editor only depends on this function
/// and [WorkbookSession].
Future<WorkbookSession> openWorkbookSession(
  ShellServices services,
  UuidValue itemUuid, {
  @visibleForTesting Duration readyTimeout = const Duration(seconds: 10),
}) async {
  final controller = await SheetsData.ready(services, timeout: readyTimeout);
  if (controller == null) {
    // Installed but not started (the replica's database failed to open or
    // is still opening): an empty in-memory spreadsheet would look like the
    // data is gone and lose every edit; the editor offers *Try again*.
    if (SheetsData.isInstalled(services)) {
      throw SheetsDataUnavailableException(
        sheetsL10nOf(services).screenStorageUnavailable,
      );
    }
    return MemoryWorkbookSession.blank(itemUuid: itemUuid);
  }
  DriveItemView? item;
  try {
    item = await services.drive.get(itemUuid);
  } catch (_) {
    item = services.knownItem(itemUuid);
  }
  // Spreadsheets created by this app (and by the server since the sync
  // layer landed) use the space UUID as item UUID.
  final space = item?.contentRef ?? itemUuid;
  // Where the user left it: those rows load first (viewport-first loading)
  // and the editor restores the view (LocalViewState, 02 §4).
  final view = await LocalViewStateStore(services.userStore).read(space.uuid);
  final session = controller.openSession(
    itemUuid: itemUuid,
    spaceUuid: space,
    role: item?.myRole ?? Role.viewer,
    viewport: view == null
        ? null
        : ViewportHint(sheetId: view.activeSheetId, topRow: view.topRow),
  );
  // Sharing changes (role up/downgrades) arrive on the drive watch before
  // the next sync cycle mirrors them into the space membership.
  final sub = services.driveChanges
      .where((c) => c.itemUuid == itemUuid && c.item != null)
      .listen((c) => session.updateRole(c.item!.myRole));
  session.addDisposeCallback(sub.cancel);
  return session;
}

/// The signed-in user's local data layer did not start, so a spreadsheet
/// can't be opened (see [openWorkbookSession]).
final class SheetsDataUnavailableException implements Exception {
  /// Creates the exception with the user-facing [message].
  const SheetsDataUnavailableException(this.message);

  /// What the editor shows.
  final String message;

  @override
  String toString() => message;
}

/// Installs the Sheets data layer for the signed-in user (suite 12 §2.5):
/// one [SheetsSyncController] per user, opened when the profile is known
/// (also offline, from the cached profile) and closed when the user signs
/// out or changes. Called from the app config's `onSignedIn` /
/// `onSigningOut`.
abstract final class SheetsData {
  static final Expando<_Installation> _installations = Expando('SheetsData');

  /// Desktop directory of the replicas (tests).
  static String? directoryOverride;

  /// Cells kept on a device whose browser has no OPFS (IndexedDB fallback,
  /// suite 12 intro).
  static const limitedStorageCells = 200000;

  /// Installs (idempotent). [open] and [remote] replace the production
  /// replica opener and server API (tests).
  static void install(
    ShellServices services, {
    SheetsReplicaOpener? open,
    SheetsRemote Function()? remote,
  }) {
    if (_installations[services] != null) return;
    final inst = _Installation(services, open, remote);
    _installations[services] = inst;
    inst.attach();
  }

  /// Closes the user's controller and stops listening.
  static Future<void> uninstall(ShellServices services) async {
    final inst = _installations[services];
    if (inst == null) return;
    _installations[services] = null;
    await inst.detach();
  }

  /// The open controller (null while opening, signed out or not installed).
  static SheetsSyncController? current(ShellServices services) =>
      _installations[services]?.controller;

  /// The controller once open; null when not installed or no user appears
  /// within [timeout].
  /// Whether the data layer is installed for [services] (signed in), even
  /// when it has not started yet.
  static bool isInstalled(ShellServices services) =>
      _installations[services] != null;

  static Future<SheetsSyncController?> ready(
    ShellServices services, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final inst = _installations[services];
    if (inst == null) return null;
    if (inst.controller != null) return inst.controller;
    try {
      return await inst.next.future.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  /// Creates a spreadsheet: locally in a reserved space (works offline),
  /// then `drive.registerSpreadsheet` (queued while offline; the item uuid
  /// is the space uuid). Templates and devices without a usable reservation
  /// while online create on the server. Returns the item uuid.
  static Future<UuidValue?> createSpreadsheet(
    ShellServices services, {
    UuidValue? parentUuid,
    UuidValue? templateUuid,
    String? name,
  }) async {
    Future<UuidValue?> onServer() => services.createItemOnServer(
      DriveItemKind.spreadsheet,
      parentUuid: parentUuid,
      templateUuid: templateUuid,
      name: name,
    );
    final ctx = services.navigatorContext;
    final title =
        name ??
        (ctx == null
            ? 'Untitled spreadsheet'
            : services.config.untitledName(ctx));
    if (templateUuid != null) return onServer();
    final controller = await SheetsData.ready(services);
    if (controller == null) return onServer();
    final UuidValue space;
    try {
      // The user's defaults (Settings › Sheets, 04 §11.24).
      final d = SheetsUserDefaults.of(services);
      space = await controller.createLocalSpreadsheet(
        title: title,
        locale: d.locale ?? 'en_US',
        timeZone: d.timeZone ?? 'UTC',
        fontFamily: d.fontFamily,
        fontSize: d.fontSize,
      );
    } on NoReservedSpaceException {
      if (services.connectivity.online) return onServer();
      rethrow;
    }
    try {
      await services.drive.registerSpreadsheet(
        spaceUuid: space,
        parentUuid: parentUuid,
        name: title,
      );
    } catch (e) {
      // The spreadsheet exists locally; registration is retried by the
      // drive queue when offline. Other errors are reported.
      debugPrint('Registering spreadsheet $space failed: $e');
      if (!isOfflineError(e)) rethrow;
    }
    services.refreshDrive();
    return space;
  }
}

class _ShellConnectivity implements SheetsConnectivity {
  _ShellConnectivity(this.service) : _online = ValueNotifier(service.online) {
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

class _Installation {
  _Installation(this.services, this._open, this._remote);

  final ShellServices services;
  final SheetsReplicaOpener? _open;
  final SheetsRemote Function()? _remote;

  SheetsSyncController? controller;
  String? _user;
  Completer<SheetsSyncController> next = Completer();
  _ShellConnectivity? _connectivity;
  AppLifecycleListener? _lifecycle;
  Future<void> _switching = Future.value();
  _SheetsOfflineProvider? _provider;

  void attach() {
    services.currentUser.addListener(_onUser);
    _lifecycle = AppLifecycleListener(
      onShow: () => controller?.setVisible(true),
      onResume: () => controller?.setVisible(true),
      onHide: () => controller?.setVisible(false),
    );
    _onUser();
  }

  Future<void> detach() async {
    services.currentUser.removeListener(_onUser);
    _lifecycle?.dispose();
    _user = null;
    await (_switching = _switching.then((_) => _close()));
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
    if (_provider != null) {
      OfflineStorage.of(services).unregister(_provider!);
      _provider!.dispose();
      _provider = null;
    }
    if (c != null) await c.close();
    _connectivity?.dispose();
    _connectivity = null;
    if (next.isCompleted) next = Completer();
  }

  /// *Clear local data*: deletes the replica (desktop) or empties every
  /// table (web, where databases can't be deleted), then starts over with
  /// a fresh replica that re-syncs. Unsynced changes are lost.
  Future<void> _reset(String user) => _switching = _switching.then((_) async {
    final c = controller;
    if (c == null || _user != user) return;
    if (kIsWeb) {
      await c.stop();
      final tables = await c.replica.db.unsafeQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'serverpod_migration%'",
      );
      for (final t in tables) {
        await c.replica.db.unsafeExecute('DELETE FROM "${t[0]}"');
      }
    }
    await _close();
    await platform.deleteReplica(
      SheetsReplica.fileNameFor(user),
      SheetsData.directoryOverride,
    );
    if (_user == user) await _openFor(user);
  });

  Future<SheetsReplica> _openReplica(UuidValue user) async {
    if (_open != null) return _open(user);
    final client = services.client;
    if (client == null) throw StateError('No client');
    final name = SheetsReplica.fileNameFor(user.uuid);
    Future<SheetsReplica> open() async => SheetsReplica.open(
      client: client,
      path: await platform.replicaPath(name, SheetsData.directoryOverride),
      userUuid: user,
      isDebugMode: kDebugMode,
    );
    try {
      return await open();
    } catch (e, st) {
      // The replica can be re-synced: move it aside (kept for recovery on
      // desktop) and start over. Spreadsheets with unsynced writes are
      // offered as a download first (12 §2.5).
      debugPrint('Opening the Sheets replica failed, resetting it: $e\n$st');
      final path = await platform.replicaPath(
        name,
        SheetsData.directoryOverride,
      );
      final recovery = await ReplicaRecovery.read(path);
      await platform.moveReplicaAside(name, SheetsData.directoryOverride);
      if (recovery != null && !recovery.isEmpty) {
        offerRecoveryDownload(services, recovery);
      }
      return open();
    }
  }

  OfflineWarning _limitedWarning() {
    final l = sheetsL10nOf(services);
    return OfflineWarning(
      title: l.storageLimitedTitle,
      description: l.storageLimitedDescription(
        NumberFormat.decimalPattern().format(SheetsData.limitedStorageCells),
      ),
    );
  }

  /// Tells the user once per device and user that offline storage is
  /// limited in this browser.
  Future<void> _announceLimitedStorage() async {
    const key = 'sheets.storageLimitedShown';
    try {
      if (await services.userStore.read(key) == true) return;
      await services.userStore.write(key, true);
    } catch (_) {}
    final w = _limitedWarning();
    services.toasts.show(
      w.title,
      description: w.description,
      duration: const Duration(seconds: 12),
    );
  }

  Future<void> _openFor(String user) async {
    try {
      final uuid = UuidValue.fromString(user);
      final replica = await _openReplica(uuid);
      if (_user != user) {
        await replica.close();
        return;
      }
      final client = services.client;
      final remote =
          _remote?.call() ??
          (client == null ? null : ClientSheetsRemote(client));
      if (remote == null) {
        await replica.close();
        return;
      }
      final connectivity = _connectivity = _ShellConnectivity(
        services.connectivity,
      );
      // Web without OPFS keeps the database in memory (IndexedDB
      // fallback): cap the cells kept on the device and say so (12 intro).
      final limited = await offlineStorageLimited();
      final views = LocalViewStateStore(services.userStore);
      final c = SheetsSyncController(
        replica: replica,
        remote: remote,
        connectivity: connectivity,
        cellCap: limited ? SheetsData.limitedStorageCells : null,
        lastOpened: views.lastOpened,
        maintenanceStore: services.userStore,
      );
      controller = c;
      _provider = _SheetsOfflineProvider(
        c,
        () => _reset(user),
        warning: limited ? _limitedWarning() : null,
      );
      if (limited) unawaited(_announceLimitedStorage());
      OfflineStorage.of(services).register(_provider!);
      c.start();
      if (!next.isCompleted) next.complete(c);
    } catch (e, st) {
      debugPrint('Starting Sheets sync failed: $e\n$st');
    }
  }
}

/// Sheets' entry in Settings › Offline & storage and the drive's offline
/// badges: spreadsheets on the device, spaces with unsynced writes.
class _SheetsOfflineProvider extends ChangeNotifier
    implements OfflineDataProvider {
  _SheetsOfflineProvider(this.controller, this.onClear, {this.warning}) {
    controller.cycles.addListener(_refresh);
    _refresh();
  }

  final SheetsSyncController controller;
  final Future<void> Function() onClear;

  /// "Offline storage is limited in this browser" (IndexedDB fallback).
  final OfflineWarning? warning;
  Set<String> _local = const {};
  OfflineUsage _usage = OfflineUsage.empty;
  bool _disposed = false;

  @override
  String get id => 'sheets';

  @override
  bool? isAvailableOffline(DriveItemView item) {
    if (item.kind != DriveItemKind.spreadsheet) return null;
    final space = item.contentRef?.uuid ?? item.uuid.uuid;
    return _local.contains(space);
  }

  @override
  OfflineUsage get usage => _usage;

  Future<void> _refresh() async {
    final r = controller.replica;
    if (r.isClosed || _disposed) return;
    try {
      final sheets = await Spreadsheet.db.find(r.session);
      final dirty = await r.dirtySpaces();
      if (_disposed) return;
      _local = {for (final s in sheets) s.id.uuid};
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
