import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:wonky_core/wonky_core.dart' show Role;

import '../../l10n/sheets_l10n.dart';

import '../formatting/sheets_user_defaults.dart';
import '../model/local_view_state.dart';
import '../model/memory_workbook_session.dart';
import '../model/workbook_session.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show
        ReplicaInstallation,
        ReplicaOfflineProvider,
        SyncConnectivity,
        offlineStorageLimited;

import 'replica_recovery.dart';
import 'replica_recovery_ui.dart';
import 'sheets_remote.dart';
import 'sheets_replica.dart';
import 'sheets_sync_controller.dart';
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
    return inst.ready(timeout);
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

/// The Sheets data layer of one signed-in shell: the shared kit's
/// [ReplicaInstallation] with the Sheets replica, remote, cell cap (web
/// without OPFS), offline provider and recovery download.
class _Installation
    extends ReplicaInstallation<SheetsReplica, SheetsSyncController> {
  _Installation(super.services, SheetsReplicaOpener? open, this._remote)
    : super(opener: open);

  final SheetsRemote Function()? _remote;
  ReplicaOfflineProvider? _provider;
  bool _limited = false;

  @override
  String? get directory => SheetsData.directoryOverride;

  @override
  String get name => 'Sheets';

  @override
  String fileNameFor(String user) => SheetsReplica.fileNameFor(user);

  @override
  Future<SheetsReplica> openReplicaAt(
    Client client,
    String path,
    UuidValue user,
  ) => SheetsReplica.open(
    client: client,
    path: path,
    userUuid: user,
    isDebugMode: kDebugMode,
  );

  /// Spreadsheets with unsynced writes are offered as a download (12 §2.5).
  @override
  Future<VoidCallback?> readRecovery(String path) async {
    final recovery = await ReplicaRecovery.read(path);
    if (recovery == null || recovery.isEmpty) return null;
    return () => offerRecoveryDownload(services, recovery);
  }

  @override
  Future<SheetsSyncController?> createController(
    SheetsReplica replica,
    SyncConnectivity connectivity,
  ) async {
    final client = services.client;
    final remote =
        _remote?.call() ?? (client == null ? null : ClientSheetsRemote(client));
    if (remote == null) return null;
    // Web without OPFS keeps the database in memory (IndexedDB fallback):
    // cap the cells kept on the device and say so (12 intro).
    _limited = await offlineStorageLimited();
    final views = LocalViewStateStore(services.userStore);
    return SheetsSyncController(
      replica: replica,
      remote: remote,
      connectivity: connectivity,
      cellCap: _limited ? SheetsData.limitedStorageCells : null,
      lastOpened: views.lastOpened,
      maintenanceStore: services.userStore,
    );
  }

  @override
  void started(SheetsSyncController c) {
    final user = c.replica.userUuid.uuid;
    final provider = _provider = ReplicaOfflineProvider(
      c,
      () => reset(user),
      id: 'sheets',
      kind: DriveItemKind.spreadsheet,
      warning: _limited ? _limitedWarning() : null,
    );
    if (_limited) unawaited(_announceLimitedStorage());
    OfflineStorage.of(services).register(provider);
  }

  @override
  void closing(SheetsSyncController c) {
    final provider = _provider;
    if (provider == null) return;
    OfflineStorage.of(services).unregister(provider);
    provider.dispose();
    _provider = null;
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
}
