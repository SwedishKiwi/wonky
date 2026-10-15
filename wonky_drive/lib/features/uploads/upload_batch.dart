import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import '../../l10n/drive_l10n.dart';
import 'upload_dialogs.dart';
import 'upload_host.dart';
import 'upload_precheck.dart';
import 'upload_queue.dart';
import 'upload_task.dart';

/// Result of [startUploadBatch].
class UploadBatchResult {
  const UploadBatchResult(
    this.tasks, {
    this.cancelled = false,
    this.folders = const [],
  });

  /// The queued tasks (one undo step).
  final List<UploadTask> tasks;

  /// Top-level folders created for dropped folders (undo trashes them).
  final List<UuidValue> folders;

  /// The user cancelled a pre-check dialog.
  final bool cancelled;
}

/// Runs the client pre-checks of Drive 02 §3.2 on [files] for
/// [parentUuid] (null = My Drive) and queues what passes as one batch:
/// over-size files become failed rows, a batch that doesn't fit the quota
/// asks *Upload the files that fit*, existing names ask *Keep both* /
/// *Skip*. Headless invocations (no dialog context) upload the files that
/// fit and keep both names.
Future<UploadBatchResult> startUploadBatch(
  CommandContext ctx,
  UploadHost host,
  List<UploadFile> files, {
  UuidValue? parentUuid,
}) async {
  final s = host.services;
  final q = host.queue.value;
  if (q == null || files.isEmpty) {
    return const UploadBatchResult([], cancelled: true);
  }
  final l = driveL10nOf(s);
  if (files.length > maxUploadBatchFiles) {
    s.toasts.error(l.uploadTooManyFiles(maxUploadBatchFiles));
    return const UploadBatchResult([], cancelled: true);
  }
  final parentName = await _folderName(s, parentUuid);
  var names = const <String>{};
  if (host.askOnNameConflict() && s.connectivity.online) {
    try {
      names = await host.api.namesIn(parentUuid);
    } on Object {
      // Offline or the folder is gone: the server numbers names anyway.
    }
  }
  final usage = s.storage.value;
  final maxFileBytes = s.storageChecks.maxFileUploadBytes;
  var plan = UploadPlan.of(
    files,
    maxFileBytes: maxFileBytes,
    usage: usage,
    pendingBytes: q.unreservedBytes,
    existingNames: names,
  );
  // The cached usage may be stale: online, the server's `drive.checkRoom`
  // has the last word before anything is queued (Drive 02 §3.2).
  if (plan.fitsQuota && plan.files.isNotEmpty && s.connectivity.online) {
    try {
      await s.storage.checkRoom(plan.neededBytes + q.unreservedBytes);
    } on Object catch (e) {
      final d = QuotaErrorPresenter.detailsOf(e);
      if (d != null || QuotaErrorPresenter.isQuotaExceeded(e)) {
        plan = UploadPlan.of(
          files,
          maxFileBytes: maxFileBytes,
          availableBytes:
              (d?.availableBytes ?? usage?.availableBytes ?? 0) -
              q.unreservedBytes,
          existingNames: names,
        );
      }
    }
  }
  q.addRejected(
    plan.tooLarge,
    UploadFailure.tooLarge,
    parentUuid: parentUuid,
    parentName: parentName,
  );
  if (plan.tooLarge.isNotEmpty) host.showPanel();

  var chosen = plan.files;
  if (!plan.fitsQuota) {
    if (ctx.dialogContext == null || ctx.source.isAgent) {
      chosen = plan.fitting;
    } else {
      // The shell's *Out of storage* dialog (Drive 03 §6.3; *Manage
      // storage* opens the Storage page itself).
      final choice = await s.quotaErrors.show(
        plan.fitting.isEmpty || plan.files.length == 1
            ? OwnQuotaProblem(
                neededBytes: plan.neededBytes,
                availableBytes: plan.availableBytes ?? 0,
                quotaBytes: usage?.quotaBytes ?? defaultQuotaBytes,
              )
            : BatchQuotaProblem(
                fileCount: plan.files.length,
                neededBytes: plan.neededBytes,
                availableBytes: plan.availableBytes ?? 0,
              ),
        context: ctx.dialogContext,
      );
      if (choice != QuotaDialogChoice.uploadFitting) {
        return const UploadBatchResult([], cancelled: true);
      }
      chosen = plan.fitting;
    }
  }
  final conflicts = [
    for (final f in plan.conflicts)
      if (f.folderPath.isEmpty && chosen.contains(f)) f,
  ];
  if (conflicts.isNotEmpty) {
    final dc2 = ctx.dialogContext;
    if (dc2 != null && dc2.mounted && !ctx.source.isAgent) {
      switch (await showUploadConflictDialog(
        dc2,
        names: [for (final f in conflicts) f.name],
        folderName: parentName ?? l.uploadMyDrive,
      )) {
        case ConflictChoice.keepBoth:
          break;
        case ConflictChoice.skip:
          chosen = [
            for (final f in chosen)
              if (!conflicts.contains(f)) f,
          ];
        case ConflictChoice.cancel:
          return const UploadBatchResult([], cancelled: true);
      }
    }
  }
  if (chosen.isEmpty) return const UploadBatchResult([]);

  // Dropped folders: recreate the structure below the target first
  // (Drive 02 §3.1); this needs the server.
  final nested = [
    for (final f in chosen)
      if (f.folderPath.isNotEmpty) f,
  ];
  final folders = <String, (UuidValue, String)>{};
  final topFolders = <UuidValue>[];
  if (nested.isNotEmpty) {
    if (!s.connectivity.online) {
      s.toasts.error(l.uploadFolderNeedsConnection);
      chosen = [
        for (final f in chosen)
          if (f.folderPath.isEmpty) f,
      ];
    } else {
      try {
        for (final f in nested) {
          var parent = parentUuid;
          for (var i = 0; i < f.folderPath.length; i++) {
            final key = f.folderPath.sublist(0, i + 1).join('/');
            final known = folders[key];
            if (known != null) {
              parent = known.$1;
              continue;
            }
            final created = await s.drive.createFolder(
              parentUuid: parent,
              name: f.folderPath[i],
            );
            s.emitDriveChange(
              DriveChange(
                kind: DriveChangeKind.created,
                itemUuid: created.uuid,
                item: created,
              ),
            );
            folders[key] = (created.uuid, created.name);
            if (i == 0) topFolders.add(created.uuid);
            parent = created.uuid;
          }
        }
      } on Object catch (e) {
        s.toasts.error(l.uploadFolderFailed, description: errorMessage(e));
        chosen = [
          for (final f in chosen)
            if (f.folderPath.isEmpty) f,
        ];
      }
    }
  }

  final tasks = <UploadTask>[];
  final groups = <String, List<UploadFile>>{};
  for (final f in chosen) {
    final key = f.folderPath.join('/');
    if (key.isNotEmpty && !folders.containsKey(key)) continue;
    (groups[key] ??= []).add(f);
  }
  for (final e in groups.entries) {
    final folder = folders[e.key];
    tasks.addAll(
      await q.enqueue(
        e.value,
        parentUuid: folder?.$1 ?? parentUuid,
        parentName: folder?.$2 ?? parentName,
      ),
    );
  }
  if (tasks.isNotEmpty) host.showPanel();
  return UploadBatchResult(tasks, folders: topFolders);
}

/// The display name of folder [uuid] (null for My Drive).
Future<String?> _folderName(ShellServices s, UuidValue? uuid) async {
  if (uuid == null) return null;
  final known = s.knownItem(uuid) ?? s.currentFolder.value;
  if (known != null && known.uuid == uuid) return known.name;
  try {
    return (await s.drive.get(uuid)).name;
  } on Object {
    return null;
  }
}
