import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/files.dart' show ConvertTarget, FileTypes;

import '../../l10n/drive_l10n.dart';
import '../settings/drive_settings_keys.dart';
import 'leave_guard.dart';
import 'storage_probe.dart';
import 'upload_api.dart';
import 'upload_queue.dart';
import 'upload_store.dart';
import 'upload_task.dart';

/// Per-shell state of Drive's uploads (Drive 02 §3.5): the queue of the
/// signed-in user, its collaborators (replaceable in tests), the files a
/// drop or picker staged for `drive.upload.files`, and the panel state.
class UploadHost {
  UploadHost._(this.services);

  static final Expando<UploadHost> _hosts = Expando('UploadHost');

  /// The host of [services] (created on first use).
  static UploadHost of(ShellServices services) =>
      _hosts[services] ??= UploadHost._(services);

  final ShellServices services;

  UploadApi? _api;

  /// Server access ([ServerUploadApi] unless replaced).
  UploadApi get api => _api ??= ServerUploadApi(services);
  set api(UploadApi v) => _api = v;

  /// Opens the persistent store of a user (`drive_<userId>.db`); falls
  /// back to memory when the local database can't be opened.
  Future<UploadStore> Function(String userUuid) openStore = (user) async {
    try {
      return await SqliteUploadStore.open(user);
    } on Object catch (e) {
      debugPrint('Opening the upload store failed: $e');
      return MemoryUploadStore();
    }
  };

  /// Whether large files' bytes can't be stored on this device.
  Future<bool> Function() storageLimited = uploadStorageLimited;

  /// Whether the *Upload options* dialog asks about existing names (Drive
  /// setting *Ask when uploaded files have the same name*, Drive 04 §8;
  /// default on). Replaceable in tests.
  late bool Function() askOnNameConflict = () =>
      services.prefs.driveDefaults['askOnNameConflict'] != false;

  /// The signed-in user's queue (null while signed out).
  final ValueNotifier<UploadQueue?> queue = ValueNotifier(null);

  /// The panel is shown (it opens when files are added; ✕ hides it).
  final ValueNotifier<bool> panelVisible = ValueNotifier(false);

  /// The panel is collapsed to the pill.
  final ValueNotifier<bool> panelCollapsed = ValueNotifier(false);

  final Map<String, List<UploadFile>> _staged = {};
  StreamSubscription<UploadEvent>? _events;
  int _stageSeq = 0;

  /// Keeps [files] for one `drive.upload.files` invocation (bytes can't
  /// travel in command arguments); returns the id to pass as `staged`.
  String stage(List<UploadFile> files) {
    final id = 'staged-${++_stageSeq}';
    _staged[id] = files;
    return id;
  }

  /// The files staged as [id] (once).
  List<UploadFile>? takeStaged(String id) => _staged.remove(id);

  String? _user;
  bool _installed = false;

  /// Follows the signed-in user (also offline: the profile is cached):
  /// opens their queue, closes it at sign-out (`DriveAppConfig.onSignedIn`).
  void install() {
    if (_installed) return;
    _installed = true;
    services.currentUser.addListener(_onUser);
    _onUser();
  }

  /// Stops following the user and closes the queue (sign-out).
  Future<void> uninstall() async {
    if (_installed) services.currentUser.removeListener(_onUser);
    _installed = false;
    _user = null;
    await stop();
  }

  void _onUser() {
    final me = services.currentUser.value?.summary.uuid.uuid;
    if (me == _user) return;
    _user = me;
    unawaited(me == null ? stop() : startFor(me));
  }

  /// Opens the store of [userUuid] and starts its queue.
  Future<void> startFor(String userUuid) async {
    await stop();
    final store = await openStore(userUuid);
    if (_installed && _user != userUuid) {
      await store.close();
      return;
    }
    final q = UploadQueue(
      api: api,
      store: store,
      connectivity: services.connectivity,
      newId: services.ids.next,
      storeAllBytes: !await storageLimited(),
    );
    attach(q);
    await q.start();
    if (q.tasks.isNotEmpty) panelVisible.value = true;
  }

  /// The kind a finished upload becomes with *Convert uploads to Wonky
  /// formats* on (Drive 02 §7.3): documents and spreadsheets for the files
  /// Write and Sheets open; null keeps the file.
  DriveItemKind? convertTargetOf(UploadTask t) {
    if (!DriveSettings.convertsUploads(services)) return null;
    return switch (FileTypes.convertTargetOf(t.fileName)) {
      ConvertTarget.write => DriveItemKind.document,
      ConvertTarget.sheets => DriveItemKind.spreadsheet,
      null => null,
    };
  }

  /// Uses [q] as the queue (tests attach a queue on a memory store).
  void attach(UploadQueue q) {
    q.convertTo ??= convertTargetOf;
    queue.value = q;
    q.addListener(_onQueue);
    _events = q.events.listen(_onEvent);
  }

  /// Stops the queue (sign-out): uploads in flight are aborted and resume
  /// at the next sign-in.
  Future<void> stop() async {
    final q = queue.value;
    if (q == null) return;
    await _events?.cancel();
    _events = null;
    q.removeListener(_onQueue);
    queue.value = null;
    panelVisible.value = false;
    setLeaveGuard(false);
    q.dispose();
  }

  void _onQueue() {
    final q = queue.value;
    if (q == null) return;
    setLeaveGuard(q.hasActive);
    services.registry.notifyStateChanged();
  }

  void _onEvent(UploadEvent e) {
    final t = e.task;
    final l = driveL10nOf(services);
    if (e.done) {
      final item = t.result;
      if (item != null) {
        services.emitDriveChange(
          DriveChange(
            kind: DriveChangeKind.created,
            itemUuid: item.uuid,
            item: item,
          ),
        );
      }
      unawaited(services.storage.refresh());
      if (t.conversionFailed) {
        services.toasts.show(l.uploadConvertFailed(t.fileName));
      }
    } else if (t.failure == UploadFailure.outOfStorage) {
      unawaited(services.storage.refresh());
    }
    _announce(
      e.done
          ? l.uploadAnnounceDone(t.fileName)
          : l.uploadAnnounceFailed(t.fileName),
    );
  }

  /// The panel is a polite live region (Drive 04 §12).
  void _announce(String message) {
    final c = services.navigatorContext;
    if (c == null) return;
    final view = View.maybeOf(c);
    if (view == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        message,
        Directionality.maybeOf(c) ?? TextDirection.ltr,
      ),
    );
  }

  /// Shows (and expands) the panel.
  void showPanel() {
    panelVisible.value = true;
    panelCollapsed.value = false;
  }
}
