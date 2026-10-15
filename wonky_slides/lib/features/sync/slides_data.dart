import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/ops.dart' show SlidesMutationPlanner;
import 'package:wonky_slides_core/planner.dart' show SlidesPlanner;
import 'package:wonky_slides_core/templates.dart' show SlidesTemplates;
import 'package:wonky_slides_core/themes.dart'
    show SlideAppearance, SlideSize, SlideSizeKind;
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show
        ReplicaInstallation,
        ReplicaOfflineProvider,
        SyncConnectivity,
        offlineStorageLimited;

import '../../l10n/slides_l10n.dart';
import '../model/deck_session.dart';
import '../model/memory_deck_session.dart';
import '../model/synced_deck_session.dart';
import '../settings/slides_user_defaults.dart';
import 'replica_recovery.dart';
import 'slides_remote.dart';
import 'slides_replica.dart';
import 'slides_sync_controller.dart';

export 'slides_sync_controller.dart'
    show SlidesSyncController, NoReservedSpaceException;

/// Opens the [DeckSession] of a presentation item (Slides 02 §9.1, 12
/// §5.3).
///
/// With the data layer installed ([SlidesData.install], done at sign-in)
/// this is a [SyncedDeckSession] on the user's replica; follow its
/// `loadState`. Without it (widget tests with fake services, signed out) an
/// in-memory blank deck. The editor only depends on this function and
/// [DeckSession].
Future<DeckSession> openDeckSession(
  ShellServices services,
  UuidValue itemUuid, {
  @visibleForTesting Duration readyTimeout = const Duration(seconds: 10),
}) async {
  final controller = await SlidesData.ready(services, timeout: readyTimeout);
  if (controller == null) {
    // Installed but not started (the replica's database failed to open or
    // is still opening): an empty in-memory deck would look like the data
    // is gone and lose every edit; the editor offers *Try again*.
    if (SlidesData.isInstalled(services)) {
      throw SlidesDataUnavailableException(
        slidesL10nOf(services).screenStorageUnavailable,
      );
    }
    return MemoryDeckSession.blank(
      planner: SlidesData.planner,
      itemUuid: itemUuid,
      title: slidesL10nOf(services).untitledPresentation,
    );
  }
  DriveItemView? item;
  try {
    item = await services.drive.get(itemUuid);
  } catch (_) {
    item = services.knownItem(itemUuid);
  }
  // Decks use the space UUID as item UUID (offline creation and server
  // creation alike, 02 §9.3).
  final space = item?.contentRef ?? itemUuid;
  unawaited(DeckOpenHistory(services.userStore).record(space.uuid));
  final session = controller.openSession(
    itemUuid: itemUuid,
    spaceUuid: space,
    role: item?.myRole ?? Role.viewer,
    strings: SlidesData.strings(services),
  );
  // Sharing changes (role up/downgrades) arrive on the drive watch before
  // the next sync cycle mirrors them into the space membership.
  final sub = services.driveChanges
      .where((c) => c.itemUuid == itemUuid && c.item != null)
      .listen((c) => session.updateRole(c.item!.myRole));
  session.addDisposeCallback(sub.cancel);
  return session;
}

/// The signed-in user's local data layer did not start, so a presentation
/// can't be opened (see [openDeckSession]).
final class SlidesDataUnavailableException implements Exception {
  /// Creates the exception with the user-facing [message].
  const SlidesDataUnavailableException(this.message);

  /// What the editor shows.
  final String message;

  @override
  String toString() => message;
}

/// Installs the Slides data layer for the signed-in user (Slides 02 §9,
/// suite 12 §2.5): one [SlidesSyncController] per user, opened when the
/// profile is known (also offline, from the cached profile) and closed when
/// the user signs out or changes. Called from `SlidesAppConfig.onSignedIn`
/// / `onSigningOut`.
abstract final class SlidesData {
  static final Expando<_Installation> _installations = Expando('SlidesData');

  /// Desktop directory of the replicas (tests).
  static String? directoryOverride;

  /// Elements kept on a device whose browser has no OPFS (IndexedDB
  /// fallback, suite 12 intro).
  static const limitedStorageElements = 50000;

  /// The planner of every deck write in the app (SL-7).
  static SlidesMutationPlanner planner = const SlidesPlanner();

  /// Installs (idempotent). [open] and [remote] replace the production
  /// replica opener and server API (tests).
  static void install(
    ShellServices services, {
    SlidesReplicaOpener? open,
    SlidesRemote Function()? remote,
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
  static SlidesSyncController? current(ShellServices services) =>
      _installations[services]?.controller;

  /// Whether the data layer is installed for [services] (signed in), even
  /// when it has not started yet.
  static bool isInstalled(ShellServices services) =>
      _installations[services] != null;

  /// The controller once open; null when not installed or no user appears
  /// within [timeout].
  static Future<SlidesSyncController?> ready(
    ShellServices services, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final inst = _installations[services];
    if (inst == null) return null;
    return inst.ready(timeout);
  }

  /// The localized load-state messages of deck sessions.
  static SyncedDeckStrings strings(ShellServices services) {
    final l = slidesL10nOf(services);
    return SyncedDeckStrings(
      downloading: l.deckDownloading,
      opening: l.deckOpening,
      notAvailableOffline: l.deckNotAvailableOffline,
      noAccess: l.deckNoAccess,
      downloadFailed: l.deckDownloadFailed,
      openFailed: l.deckOpenFailed,
      notOnDevice: l.deckNotOnDevice,
      accessRemoved: l.deckAccessRemoved,
      stillOpening: l.deckStillOpening,
    );
  }

  /// Creates a presentation (02 §9.3): locally in a reserved deck space
  /// (works offline; `CreateDeck` = deck row, default theme copy, a title
  /// slide and the "Create presentation" log row in one transaction), then
  /// `drive.registerPresentation` (queued while offline; the item uuid is
  /// the space uuid). Built-in templates (`SlidesTemplates`, SL-22) are
  /// built locally the same way; other templates (presentations published
  /// as templates) and devices without a usable reservation while online
  /// create on the server (`drive.createPresentation`).
  /// Returns the item uuid. Throws `NoReservedSpaceException` offline
  /// before the first reservations arrived.
  static Future<UuidValue?> createPresentation(
    ShellServices services, {
    UuidValue? parentUuid,
    UuidValue? templateUuid,
    String? name,
  }) async {
    Future<UuidValue?> onServer() => services.createItemOnServer(
      DriveItemKind.presentation,
      parentUuid: parentUuid,
      templateUuid: templateUuid,
      name: name,
    );
    final builtin = templateUuid == null
        ? null
        : SlidesTemplates.byUuid(templateUuid.uuid);
    final ctx = services.navigatorContext;
    final title =
        name ??
        builtin?.name ??
        (ctx == null
            ? slidesL10nOf(services).untitledPresentation
            : services.config.untitledName(ctx));
    if (templateUuid != null && builtin == null) return onServer();
    final controller = await SlidesData.ready(services);
    if (controller == null) return onServer();
    final UuidValue space;
    try {
      final d = newPresentationDefaults(services);
      space = await controller.createLocalPresentation(
        title: title,
        template: builtin,
        themeKey: d.themeKey,
        size: d.size,
        appearance: d.appearance,
      );
    } on NoReservedSpaceException {
      if (services.connectivity.online) return onServer();
      rethrow;
    }
    try {
      await services.drive.registerPresentation(
        spaceUuid: space,
        parentUuid: parentUuid,
        name: title,
      );
    } catch (e) {
      // The deck exists locally; registration is retried by the drive
      // queue when offline. Other errors are reported.
      debugPrint('Registering presentation $space failed: $e');
      if (!isOfflineError(e)) rethrow;
    }
    services.refreshDrive();
    return space;
  }
}

/// The user's *New presentations* settings (Slides 04 §13.16) for a blank
/// deck: the default theme, slide size and — only when the user chose one —
/// appearance (otherwise the theme's own).
({String themeKey, SlideSize? size, SlideAppearance? appearance})
newPresentationDefaults(ShellServices services) {
  final d = SlidesUserDefaults.of(services);
  final size = d.string(SlidesUserDefaults.keyDefaultSize);
  final chosen = services.prefs.slidesDefaults.containsKey(
    SlidesUserDefaults.keyDefaultAppearance,
  );
  final appearance = d.string(SlidesUserDefaults.keyDefaultAppearance);
  return (
    themeKey: d.string(SlidesUserDefaults.keyDefaultThemeKey),
    size: [
      for (final k in SlideSizeKind.values)
        if (k.name == size && k != SlideSizeKind.custom) SlideSize.preset(k),
    ].firstOrNull,
    appearance: chosen
        ? SlideAppearance.values.where((a) => a.name == appearance).firstOrNull
        : null,
  );
}

/// When each deck was last opened on this device (`slides.opened.<deckId>`
/// in the user store): the device cap of browsers without OPFS evicts the
/// decks opened least recently first. Keeps the newest [keep].
class DeckOpenHistory {
  DeckOpenHistory(this.store);

  final LocalStore store;

  static const prefix = 'slides.opened.';

  /// Entries kept.
  static const keep = 200;

  /// Records that [deckId] was opened now.
  Future<void> record(String deckId) async {
    try {
      await store.write(
        '$prefix$deckId',
        clock.now().toUtc().toIso8601String(),
      );
      final all = await lastOpened();
      if (all.length <= keep) return;
      final oldest = all.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final e in oldest.take(all.length - keep)) {
        await store.remove('$prefix${e.key}');
      }
    } catch (e) {
      debugPrint('Recording the opened deck failed: $e');
    }
  }

  /// Deck id → when it was last opened.
  Future<Map<String, DateTime>> lastOpened() async {
    final out = <String, DateTime>{};
    for (final k in await store.keys(prefix)) {
      final at = DateTime.tryParse('${await store.read(k)}');
      if (at != null) out[k.substring(prefix.length)] = at;
    }
    return out;
  }
}

/// The Slides data layer of one signed-in shell: the shared kit's
/// [ReplicaInstallation] with the Slides replica, remote, element cap (web
/// without OPFS), offline provider and recovery download.
class _Installation
    extends ReplicaInstallation<SlidesReplica, SlidesSyncController> {
  _Installation(super.services, SlidesReplicaOpener? open, this._remote)
    : super(opener: open);

  final SlidesRemote Function()? _remote;
  ReplicaOfflineProvider? _provider;
  bool _limited = false;

  @override
  String? get directory => SlidesData.directoryOverride;

  @override
  String get name => 'Slides';

  @override
  String fileNameFor(String user) => SlidesReplica.fileNameFor(user);

  @override
  Future<SlidesReplica> openReplicaAt(
    Client client,
    String path,
    UuidValue user,
  ) => SlidesReplica.open(
    client: client,
    path: path,
    userUuid: user,
    isDebugMode: kDebugMode,
  );

  /// Decks with unsynced writes are offered as a download (suite 12 §2.5).
  @override
  Future<VoidCallback?> readRecovery(String path) async {
    final recovery = await SlidesReplicaRecovery.read(path);
    if (recovery == null || recovery.isEmpty) return null;
    return () => offerSlidesRecoveryDownload(services, recovery);
  }

  @override
  Future<SlidesSyncController?> createController(
    SlidesReplica replica,
    SyncConnectivity connectivity,
  ) async {
    final client = services.client;
    final remote =
        _remote?.call() ?? (client == null ? null : ClientSlidesRemote(client));
    if (remote == null) return null;
    // Web without OPFS keeps the database in memory (IndexedDB fallback):
    // cap the elements kept on the device and say so (suite 12 intro).
    _limited = await offlineStorageLimited();
    return SlidesSyncController(
      replica: replica,
      remote: remote,
      connectivity: connectivity,
      planner: SlidesData.planner,
      elementCap: _limited ? SlidesData.limitedStorageElements : null,
      lastOpened: DeckOpenHistory(services.userStore).lastOpened,
      maintenanceStore: services.userStore,
    );
  }

  @override
  void started(SlidesSyncController c) {
    final user = c.replica.userUuid.uuid;
    final provider = _provider = ReplicaOfflineProvider(
      c,
      () => reset(user),
      id: 'slides',
      kind: DriveItemKind.presentation,
      warning: _limited ? _limitedWarning() : null,
    );
    if (_limited) unawaited(_announceLimitedStorage());
    OfflineStorage.of(services).register(provider);
  }

  @override
  void closing(SlidesSyncController c) {
    final provider = _provider;
    if (provider == null) return;
    OfflineStorage.of(services).unregister(provider);
    provider.dispose();
    _provider = null;
  }

  OfflineWarning _limitedWarning() {
    final l = slidesL10nOf(services);
    return OfflineWarning(
      title: l.storageLimitedTitle,
      description: l.storageLimitedDescription(
        NumberFormat.decimalPattern().format(SlidesData.limitedStorageElements),
      ),
    );
  }

  /// Tells the user once per device and user that offline storage is
  /// limited in this browser.
  Future<void> _announceLimitedStorage() async {
    const key = 'slides.storageLimitedShown';
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
