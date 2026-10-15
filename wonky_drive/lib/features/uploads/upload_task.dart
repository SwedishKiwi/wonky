import 'dart:convert';

import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/files.dart';

/// Where an upload is in its life (Drive 02 §3.5).
enum UploadStatus {
  /// Waits for a free slot (3 run in parallel).
  queued,

  /// Offline (or the server is unreachable): starts when the connection
  /// returns.
  waitingForNetwork,

  /// `drive.createFileUpload` is running.
  starting,

  /// Bytes are on their way ([UploadTask.bytesSent]).
  uploading,

  /// `drive.completeFileUpload` verifies the bytes.
  verifying,

  /// Uploaded ([UploadTask.result] is the ready item).
  done,

  /// Not uploaded ([UploadTask.failure]).
  failed,

  /// Cancelled by the user (or by undo).
  cancelled;

  /// Still to finish (counts as "in progress" for the panel and the
  /// leave prompt).
  bool get isActive =>
      this == queued ||
      this == waitingForNetwork ||
      this == starting ||
      this == uploading ||
      this == verifying;

  /// Finished one way or the other.
  bool get isFinished => !isActive;
}

/// Why an upload failed (Drive 02 §3.2–§4.2).
enum UploadFailure {
  /// The connection dropped or the server could not be reached; retried
  /// automatically with backoff.
  network,

  /// The quota doesn't fit the file (server `quotaExceeded`).
  outOfStorage,

  /// Larger than `maxFileUploadBytes`.
  tooLarge,

  /// The target folder was deleted or access to it was lost.
  folderGone,

  /// Too many uploads at once / per hour (server `limitExceeded`).
  rateLimited,

  /// The bytes were held in memory only (IndexedDB fallback) and the page
  /// was reloaded (Drive 02 §4.1).
  notSaved,

  /// Anything else (the message is in [UploadTask.error]).
  other;

  /// Retried automatically (with backoff) when the connection returns.
  bool get automatic => this == network;

  /// *Retry* is offered.
  bool get retryable => this != tooLarge && this != notSaved;
}

/// One file of the upload queue (Drive 02 §3.5, persisted as a
/// `local_pending_upload` row, §4.1).
class UploadTask {
  UploadTask({
    required this.id,
    required this.batchId,
    required this.itemUuid,
    required this.fileUuid,
    required this.fileName,
    required this.sizeBytes,
    required this.createdAt,
    this.parentUuid,
    this.parentName,
    this.mimeType,
    this.lastModified,
    this.status = UploadStatus.queued,
    this.attempts = 0,
    this.failure,
    this.error,
    this.result,
    this.volatile = false,
    this.bytesSent = 0,
  });

  /// Stable id of the task (the first item uuid; [itemUuid] changes when
  /// a failed upload is started again).
  final String id;

  /// The batch (one undo step, Drive 02 §3.4).
  final String batchId;

  /// Client-generated drive item uuid (idempotency key with [fileUuid]).
  UuidValue itemUuid;
  UuidValue fileUuid;

  /// Target folder; null = My Drive.
  UuidValue? parentUuid;

  /// Name of the target folder, for "Upload to Team" (null = My Drive).
  String? parentName;

  final String fileName;
  final int sizeBytes;
  final String? mimeType;
  final DateTime? lastModified;
  final DateTime createdAt;

  UploadStatus status;

  /// Failed attempts since the last manual start (backoff exponent).
  int attempts;

  UploadFailure? failure;

  /// The server's or the transport's message of the last failure.
  String? error;

  /// The ready item once [UploadStatus.done]: the uploaded file, or the
  /// document/spreadsheet it was converted to (Drive 02 §7.3).
  DriveItemView? result;

  /// *Convert uploads* was on but the conversion failed: [result] is the
  /// uploaded file (not persisted).
  bool conversionFailed = false;

  /// The upload became a Wonky document or spreadsheet.
  bool get converted => result != null && result!.kind != DriveItemKind.file;

  /// The bytes are held in memory only (not stored on this device).
  bool volatile;

  /// Bytes sent in the current attempt (not persisted).
  int bytesSent;

  /// When the current byte transfer started (throughput, not persisted).
  DateTime? sendingSince;

  /// The file category (panel icon), from the name and the browser's type
  /// (the server sniffs the real one).
  FileCategory get category => FileCategory.values.byName(
    FileTypes.categoryOf(
      mimeType ?? FileTypes.mimeTypeForName(fileName) ?? '',
      fileName: fileName,
    ).name,
  );

  /// 0…1 of the current attempt.
  double get progress => switch (status) {
    UploadStatus.done || UploadStatus.verifying => 1,
    UploadStatus.uploading =>
      sizeBytes <= 0 ? 1 : (bytesSent / sizeBytes).clamp(0, 1).toDouble(),
    _ => 0,
  };

  /// Bytes still to send (time left of the batch).
  int get remainingBytes => switch (status) {
    UploadStatus.done ||
    UploadStatus.verifying ||
    UploadStatus.failed ||
    UploadStatus.cancelled => 0,
    _ => sizeBytes - bytesSent,
  };

  /// The persisted row (without the bytes).
  Map<String, Object?> toRow() => {
    'id': id,
    'purpose': 'driveFile',
    'batch_id': batchId,
    'item_uuid': itemUuid.uuid,
    'file_uuid': fileUuid.uuid,
    'parent_uuid': parentUuid?.uuid,
    'parent_name': parentName,
    'file_name': fileName,
    'size_bytes': sizeBytes,
    'mime_type': mimeType,
    'last_modified': lastModified?.millisecondsSinceEpoch,
    'volatile': volatile ? 1 : 0,
    'state': status.name,
    'attempts': attempts,
    'last_error': error,
    'error_kind': failure?.name,
    'received_bytes': 0,
    'result_json': result == null ? null : jsonEncode(result!.toJson()),
    'created_at': createdAt.microsecondsSinceEpoch,
  };

  /// A task from a persisted row. Interrupted uploads (waiting, starting,
  /// uploading, verifying) are queued again: the server calls are
  /// idempotent; the queue marks them waiting again while offline.
  static UploadTask fromRow(Map<String, Object?> r) {
    final state = UploadStatus.values.asNameMap()[r['state']];
    final resultJson = r['result_json'] as String?;
    final lastModified = r['last_modified'] as int?;
    final errorKind = r['error_kind'] as String?;
    return UploadTask(
      id: r['id']! as String,
      batchId: r['batch_id']! as String,
      itemUuid: UuidValue.fromString(r['item_uuid']! as String),
      fileUuid: UuidValue.fromString(r['file_uuid']! as String),
      parentUuid: switch (r['parent_uuid']) {
        final String s => UuidValue.fromString(s),
        _ => null,
      },
      parentName: r['parent_name'] as String?,
      fileName: r['file_name']! as String,
      sizeBytes: r['size_bytes']! as int,
      mimeType: r['mime_type'] as String?,
      lastModified: lastModified == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastModified),
      createdAt: DateTime.fromMicrosecondsSinceEpoch(r['created_at']! as int),
      status: switch (state) {
        null ||
        UploadStatus.waitingForNetwork ||
        UploadStatus.starting ||
        UploadStatus.uploading ||
        UploadStatus.verifying => UploadStatus.queued,
        final s => s,
      },
      attempts: (r['attempts'] as int?) ?? 0,
      failure: errorKind == null
          ? null
          : UploadFailure.values.asNameMap()[errorKind],
      error: r['last_error'] as String?,
      result: resultJson == null
          ? null
          : DriveItemView.fromJson(
              (jsonDecode(resultJson) as Map).cast<String, dynamic>(),
            ),
      volatile: (r['volatile'] as int?) == 1,
    );
  }

  /// A snapshot for MCP (`ui.drive.get_upload_queue`) and command results.
  Map<String, Object?> toJson() => {
    'uploadId': id,
    'itemUuid': itemUuid.uuid,
    'name': fileName,
    'sizeBytes': sizeBytes,
    'status': status.name,
    'progress': progress,
    if (parentUuid != null) 'parentUuid': parentUuid!.uuid,
    if (failure != null) 'failure': failure!.name,
    if (error != null) 'error': error,
  };
}
