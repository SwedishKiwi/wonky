import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import 'byte_sender.dart';

export 'byte_sender.dart'
    show UploadAbort, UploadAborted, UploadTransferException;

/// What the upload queue needs from the server (Drive 02 §3.3): the
/// `drive.*FileUpload` endpoints and the byte transfer of an upload
/// description. [ServerUploadApi] talks to the server; tests use a fake.
abstract class UploadApi {
  /// `drive.createFileUpload` (idempotent on item + file uuid).
  Future<FileUploadStart> create(FileUploadRequest request);

  /// Sends [bytes] for [uploadDescription], reporting the bytes sent so far
  /// to [onProgress]. Throws [UploadTransferException] (HTTP error),
  /// `OfflineException` (unreachable) or [UploadAborted] after
  /// [UploadAbort.abort].
  Future<void> send(
    String uploadDescription,
    Uint8List bytes, {
    required void Function(int sent) onProgress,
    required UploadAbort abort,
  });

  /// `drive.completeFileUpload`: verifies the bytes, returns the ready item.
  Future<DriveItemView> complete(UuidValue itemUuid);

  /// `drive.cancelFileUpload` (releases the reservation).
  Future<void> cancel(UuidValue itemUuid);

  /// The ready names (lower case) in folder [parentUuid] (null = My Drive),
  /// for the name-conflict check (Drive 02 §3.2).
  Future<Set<String>> namesIn(UuidValue? parentUuid);

  /// *Convert uploads to Wonky formats* (Drive 02 §7.3): `drive.convertFile`
  /// of the uploaded file [fileItemUuid] into [target] (a document or a
  /// spreadsheet next to it), then the uploaded file is deleted for good
  /// (it was only the vehicle of the import). Returns the new item.
  Future<DriveItemView> convert(UuidValue fileItemUuid, DriveItemKind target);
}

/// [UploadApi] on the generated client: endpoint calls through [Api.guard]
/// (errors become `WonkyException` / `OfflineException`), bytes through
/// [ByteSender] (web: `XMLHttpRequest` with upload progress — Serverpod's
/// `FileUploader` buffers the body on the web and reports none, spike
/// S-D2; desktop: `FileUploader` on a counted stream).
class ServerUploadApi implements UploadApi {
  ServerUploadApi(this.services, {ByteSender? sender})
    : sender = sender ?? const ByteSender();

  final ShellServices services;
  final ByteSender sender;

  Api get _api {
    final c = services.client;
    if (c == null) throw const OfflineException('No server client');
    return Api(c);
  }

  void _checkOnline() {
    if (Api.simulatedOffline || services.connectivity.forcedOffline) {
      throw const OfflineException('simulated offline');
    }
  }

  @override
  Future<FileUploadStart> create(FileUploadRequest request) {
    _checkOnline();
    return _api.guard((c) => c.drive.createFileUpload(request));
  }

  @override
  Future<void> send(
    String uploadDescription,
    Uint8List bytes, {
    required void Function(int sent) onProgress,
    required UploadAbort abort,
  }) {
    _checkOnline();
    return sender.send(
      uploadDescription,
      bytes,
      onProgress: onProgress,
      abort: abort,
    );
  }

  @override
  Future<DriveItemView> complete(UuidValue itemUuid) {
    _checkOnline();
    return _api.guard((c) => c.drive.completeFileUpload(itemUuid));
  }

  @override
  Future<void> cancel(UuidValue itemUuid) {
    _checkOnline();
    return _api.guard((c) => c.drive.cancelFileUpload(itemUuid));
  }

  @override
  Future<DriveItemView> convert(
    UuidValue fileItemUuid,
    DriveItemKind target,
  ) async {
    _checkOnline();
    final report = await _api.guard(
      (c) => c.drive.convertFile(fileItemUuid, target, DriveImportOptions()),
    );
    try {
      await services.drive.trash([fileItemUuid]);
      await services.drive.deletePermanently([fileItemUuid]);
    } on Object catch (e) {
      // The converted item exists; the original stays (in the trash).
      debugPrint('Removing the converted upload failed: $e');
    }
    return report.item;
  }

  @override
  Future<Set<String>> namesIn(UuidValue? parentUuid) async {
    final names = <String>{};
    String? cursor;
    for (var page = 0; page < 10; page++) {
      final p = await services.drive.list(
        folderUuid: parentUuid,
        filter: DriveListFilter(view: DriveView.folder),
        sort: DriveSort(
          field: DriveSortField.name,
          descending: false,
          foldersFirst: true,
        ),
        cursor: cursor,
        limit: 200,
      );
      for (final i in p.items) {
        if (i.uploadState == null || i.uploadState == FileUploadState.ready) {
          names.add(i.name.toLowerCase());
        }
      }
      cursor = p.nextCursor;
      if (cursor == null) break;
    }
    return names;
  }
}
