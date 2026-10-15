import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../features/uploads/upload_batch.dart';
import '../features/uploads/upload_dialogs.dart';
import '../features/uploads/upload_host.dart';
import '../features/uploads/upload_queue.dart';
import '../features/uploads/upload_task.dart';
import '../l10n/drive_l10n.dart';

/// The upload commands of Wonky Drive (Drive 04 §9): the drop/picker
/// handler `drive.upload.files` (one undo step per batch, Drive 02 §3.4)
/// and the panel's actions. `shell.drive.upload` (*File upload…*) stays a
/// shell command; Drive's `ImportHandler` routes it here.
List<Command<CommandArgs>> uploadCommands(ShellServices s) {
  final host = UploadHost.of(s);
  s.undo.registerHandler(UploadUndoHandler(s));
  UploadQueue? q() => host.queue.value;

  CallbackCommand cmd(
    String id, {
    required String Function(DriveLocalizations l) title,
    required Future<CommandResult> Function(CommandContext, JsonArgs) run,
    IconData? icon,
    JsonSchema args = JsonSchema.empty,
    bool Function(CommandContext, JsonArgs)? enabled,
    bool undoable = false,
    bool palette = true,
  }) => CallbackCommand(
    id: id,
    title: (c) => title(driveL10n(c)),
    run: run,
    icon: icon,
    argsSchema: args,
    enabled: enabled,
    isUndoable: undoable,
    undoTarget: UndoTarget.shell,
    showInPalette: palette,
    category: (c) => driveL10n(c).categoryUploads,
  );

  const uploadId = JsonSchema.object(
    properties: {
      'uploadId': JsonSchema.string(
        description: 'Id of the upload (from ui.drive.get_upload_queue).',
      ),
    },
    required: ['uploadId'],
  );

  return [
    cmd(
      'drive.upload.files',
      title: (l) => l.cmdUploadFiles,
      icon: LucideIcons.upload,
      undoable: true,
      // Bytes can't travel in arguments: the drop/picker handler stages
      // the files first (UI only, not for MCP — agents use
      // `drive.upload_file`).
      palette: false,
      args: const JsonSchema.object(
        properties: {
          'parentUuid': JsonSchema.string(format: 'uuid'),
          'staged': JsonSchema.string(),
        },
        required: ['staged'],
      ),
      enabled: (ctx, a) => q() != null,
      run: (ctx, a) async {
        final files = host.takeStaged(a.string('staged')!);
        if (files == null) return const CommandResult.cancelled();
        final parent = a.string('parentUuid');
        final r = await startUploadBatch(
          ctx,
          host,
          files,
          parentUuid: parent == null ? null : UuidValue.fromString(parent),
        );
        if (r.tasks.isEmpty && r.folders.isEmpty) {
          return r.cancelled
              ? const CommandResult.cancelled()
              : CommandResult.ok({'queued': 0});
        }
        ctx.record(
          UploadBatchUndoEntry(
            items: {for (final t in r.tasks) t.id: t.itemUuid.uuid},
            folders: [for (final f in r.folders) f.uuid],
          ),
        );
        return CommandResult.ok({
          'queued': r.tasks.length,
          'uploads': [for (final t in r.tasks) t.toJson()],
        });
      },
    ),
    cmd(
      'drive.upload.cancel',
      title: (l) => l.cmdUploadCancel,
      icon: LucideIcons.x,
      palette: false,
      args: uploadId,
      enabled: (ctx, a) =>
          q()?.task(a.string('uploadId') ?? '')?.status.isActive ?? false,
      run: (ctx, a) async {
        await q()!.cancel(a.string('uploadId')!);
        return const CommandResult.ok();
      },
    ),
    cmd(
      'drive.upload.cancelAll',
      title: (l) => l.cmdUploadCancelAll,
      icon: LucideIcons.circleX,
      args: const JsonSchema.object(
        properties: {'confirmed': JsonSchema.boolean()},
      ),
      enabled: (ctx, a) => q()?.hasActive ?? false,
      run: (ctx, a) async {
        final queue = q()!;
        if (a.boolean('confirmed') != true && !ctx.source.isAgent) {
          final dc = ctx.dialogContext;
          if (dc == null || !dc.mounted) return const CommandResult.cancelled();
          if (!await confirmCancelUploads(dc, queue.activeCount)) {
            return const CommandResult.cancelled();
          }
        }
        final n = await queue.cancelAll();
        return CommandResult.ok({'cancelled': n});
      },
    ),
    cmd(
      'drive.upload.retry',
      title: (l) => l.cmdUploadRetry,
      icon: LucideIcons.rotateCw,
      palette: false,
      args: const JsonSchema.object(
        properties: {
          'uploadId': JsonSchema.string(),
          'toMyDrive': JsonSchema.boolean(
            description: 'Upload to My Drive (the folder is gone).',
          ),
        },
        required: ['uploadId'],
      ),
      enabled: (ctx, a) {
        final t = q()?.task(a.string('uploadId') ?? '');
        return t != null &&
            t.status == UploadStatus.failed &&
            (t.failure?.retryable ?? true);
      },
      run: (ctx, a) async {
        final ok = await q()!.retry(
          a.string('uploadId')!,
          toMyDrive: a.boolean('toMyDrive') ?? false,
        );
        return ok ? const CommandResult.ok() : const CommandResult.cancelled();
      },
    ),
    cmd(
      'drive.upload.retryAll',
      title: (l) => l.cmdUploadRetryAll,
      icon: LucideIcons.rotateCw,
      enabled: (ctx, a) =>
          q()?.tasks.any(
            (t) =>
                t.status == UploadStatus.failed &&
                (t.failure?.retryable ?? true),
          ) ??
          false,
      run: (ctx, a) async =>
          CommandResult.ok({'retried': await q()!.retryAll()}),
    ),
    cmd(
      'drive.upload.remove',
      title: (l) => l.cmdUploadRemove,
      icon: LucideIcons.x,
      palette: false,
      args: uploadId,
      enabled: (ctx, a) => q()?.task(a.string('uploadId') ?? '') != null,
      run: (ctx, a) async {
        await q()!.remove(a.string('uploadId')!);
        return const CommandResult.ok();
      },
    ),
    cmd(
      'drive.upload.clearFinished',
      title: (l) => l.cmdUploadClearFinished,
      icon: LucideIcons.listX,
      enabled: (ctx, a) => q()?.tasks.any((t) => t.status.isFinished) ?? false,
      run: (ctx, a) async {
        final n = await q()!.clearFinished();
        if (q()!.tasks.isEmpty) host.panelVisible.value = false;
        return CommandResult.ok({'cleared': n});
      },
    ),
    cmd(
      'drive.upload.togglePanel',
      title: (l) => l.cmdUploadTogglePanel,
      icon: LucideIcons.upload,
      enabled: (ctx, a) => q()?.tasks.isNotEmpty ?? false,
      run: (ctx, a) async {
        final show = !host.panelVisible.value || host.panelCollapsed.value;
        if (show) {
          host.showPanel();
        } else {
          host.panelVisible.value = false;
        }
        return CommandResult.ok({
          'visible': host.panelVisible.value,
          'uploads': [for (final t in q()!.tasks) t.toJson()],
        });
      },
    ),
  ];
}

/// One upload batch on the shell undo stack (Drive 02 §3.4): undo cancels
/// the batch's running uploads and moves its uploaded files to the trash;
/// redo restores them and starts the cancelled uploads again.
class UploadBatchUndoEntry extends UndoEntry {
  const UploadBatchUndoEntry({required this.items, this.folders = const []});

  /// Upload id → drive item uuid when recorded.
  final Map<String, String> items;

  /// Folders created for dropped folders (trashed with their contents).
  final List<String> folders;

  static const domainName = 'drive.upload';

  @override
  String get domain => domainName;

  @override
  UndoEntry? rebase(RemoteChange change) => this;

  @override
  Map<String, Object?> toJson() => {'items': items, 'folders': folders};

  static UploadBatchUndoEntry? fromJson(Map<String, Object?> j) {
    try {
      return UploadBatchUndoEntry(
        items: (j['items']! as Map).cast<String, String>(),
        folders: [for (final f in (j['folders'] as List?) ?? const []) '$f'],
      );
    } on Object {
      return null;
    }
  }
}

/// Applies [UploadBatchUndoEntry]s through the queue and the drive.
class UploadUndoHandler extends UndoHandler<UploadBatchUndoEntry> {
  UploadUndoHandler(this.services);

  final ShellServices services;

  @override
  String get domain => UploadBatchUndoEntry.domainName;

  @override
  UndoEntryDecoder get decoder => UploadBatchUndoEntry.fromJson;

  @override
  Future<UploadBatchUndoEntry> undo(UploadBatchUndoEntry entry) async {
    final q = UploadHost.of(services).queue.value;
    final trash = <UuidValue>[];
    for (final e in entry.items.entries) {
      final t = q?.task(e.key);
      if (t != null && t.status.isActive) {
        await q!.cancel(e.key, byUndo: true);
      } else if (t == null) {
        trash.add(UuidValue.fromString(e.value));
      } else if (t.status == UploadStatus.done) {
        trash.add(t.result?.uuid ?? t.itemUuid);
      }
    }
    // Files first, then the folders that were created for them.
    trash.addAll([for (final f in entry.folders) UuidValue.fromString(f)]);
    await _each(
      trash,
      (u) => services.drive.trash([u]),
      DriveChangeKind.trashed,
    );
    return entry;
  }

  @override
  Future<UploadBatchUndoEntry> redo(UploadBatchUndoEntry entry) async {
    final q = UploadHost.of(services).queue.value;
    final restore = [for (final f in entry.folders) UuidValue.fromString(f)];
    for (final e in entry.items.entries) {
      final t = q?.task(e.key);
      if (t != null &&
          t.status == UploadStatus.cancelled &&
          q!.cancelledByUndo(e.key)) {
        await q.retry(e.key);
      } else if (t == null) {
        restore.add(UuidValue.fromString(e.value));
      } else if (t.status == UploadStatus.done) {
        restore.add(t.result?.uuid ?? t.itemUuid);
      }
    }
    await _each(
      restore,
      (u) => services.drive.restore([u]),
      DriveChangeKind.restored,
    );
    return entry;
  }

  /// Applies [op] per item; items that are gone (never uploaded, deleted
  /// forever) are skipped.
  Future<void> _each(
    List<UuidValue> uuids,
    Future<void> Function(UuidValue) op,
    DriveChangeKind kind,
  ) async {
    for (final u in uuids) {
      try {
        await op(u);
        services.emitDriveChange(DriveChange(kind: kind, itemUuid: u));
      } on WonkyException catch (e) {
        if (e.code != WonkyErrorCode.notFound) rethrow;
      }
    }
  }
}
