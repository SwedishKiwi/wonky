import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

/// Thrown by [FilePreviewApi.fetch] when a download fails (HTTP status or
/// a body larger than allowed).
class PreviewFetchException implements Exception {
  const PreviewFetchException(this.message, {this.tooLarge = false});

  final String message;

  /// The body was larger than the allowed maximum.
  final bool tooLarge;

  @override
  String toString() => 'PreviewFetchException: $message';
}

/// What the file preview needs from the server (Drive 02 §6): the item,
/// its folder's files (prev/next), signed URLs, the bytes and the upload
/// status. The server implementation is [ServerFilePreviewApi]; tests use
/// an in-memory fake.
abstract class FilePreviewApi {
  /// The drive item [uuid] as the caller sees it.
  Future<DriveItemView> item(UuidValue uuid);

  /// The folder [uuid] (for "3 of 12 in "Holiday"").
  Future<DriveItemView> folder(UuidValue uuid);

  /// The `file` items of folder [parentUuid] (all upload states), sorted
  /// by name.
  Future<List<DriveItemView>> filesIn(UuidValue parentUuid);

  /// `drive.fileContentUrl`: the signed preview URL, or with [download]
  /// the download route URL.
  Future<FileUrlView> contentUrl(UuidValue itemUuid, {bool download = false});

  /// The signed URL of a stored file (the server preview image).
  Future<FileUrlView> storedFileUrl(UuidValue fileUuid);

  /// GETs [url] into memory; throws [PreviewFetchException] beyond
  /// [maxBytes] or on an HTTP error, `OfflineException` when unreachable.
  Future<Uint8List> fetch(String url, {int? maxBytes});

  /// `drive.fileUploadStatus`.
  Future<FileUploadProgress> uploadStatus(UuidValue itemUuid);

  /// `drive.updateFileMeta` (PDF page count, Editor+).
  Future<DriveItemView> updateFileMeta(UuidValue itemUuid, String json);
}

/// [FilePreviewApi] on the generated client and the shell's repositories.
class ServerFilePreviewApi implements FilePreviewApi {
  ServerFilePreviewApi(this.services, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final ShellServices services;
  final http.Client _http;

  Api get _api {
    final c = services.client;
    if (c == null) throw const OfflineException('No server client');
    return Api(c);
  }

  @override
  Future<DriveItemView> item(UuidValue uuid) => services.drive.get(uuid);

  @override
  Future<DriveItemView> folder(UuidValue uuid) => services.drive.get(uuid);

  @override
  Future<List<DriveItemView>> filesIn(UuidValue parentUuid) async {
    final out = <DriveItemView>[];
    String? cursor;
    // Folders hold at most a few thousand items; stop after 5 pages.
    for (var page = 0; page < 5; page++) {
      final p = await services.drive.list(
        folderUuid: parentUuid,
        filter: DriveListFilter(
          view: DriveView.folder,
          kinds: const [DriveItemKind.file],
        ),
        sort: DriveSort(
          field: DriveSortField.name,
          descending: false,
          foldersFirst: true,
        ),
        cursor: cursor,
        limit: 200,
      );
      out.addAll(p.items);
      cursor = p.nextCursor;
      if (cursor == null) break;
    }
    return out;
  }

  @override
  Future<FileUrlView> contentUrl(UuidValue itemUuid, {bool download = false}) =>
      _api.guard((c) => c.drive.fileContentUrl(itemUuid, download: download));

  @override
  Future<FileUrlView> storedFileUrl(UuidValue fileUuid) =>
      services.repositories.files.getUrl(fileUuid);

  @override
  Future<Uint8List> fetch(String url, {int? maxBytes}) async {
    if (Api.simulatedOffline) {
      throw const OfflineException('simulated offline');
    }
    final http.StreamedResponse res;
    try {
      res = await _http.send(http.Request('GET', Uri.parse(url)));
    } on http.ClientException catch (e) {
      throw OfflineException(e);
    }
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw PreviewFetchException('HTTP ${res.statusCode}');
    }
    final declared = res.contentLength;
    if (maxBytes != null && declared != null && declared > maxBytes) {
      await res.stream.drain<void>();
      throw const PreviewFetchException('Too large', tooLarge: true);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in res.stream) {
      builder.add(chunk);
      if (maxBytes != null && builder.length > maxBytes) {
        throw const PreviewFetchException('Too large', tooLarge: true);
      }
    }
    return builder.takeBytes();
  }

  @override
  Future<FileUploadProgress> uploadStatus(UuidValue itemUuid) =>
      _api.guard((c) => c.drive.fileUploadStatus(itemUuid));

  @override
  Future<DriveItemView> updateFileMeta(UuidValue itemUuid, String json) =>
      _api.guard((c) => c.drive.updateFileMeta(itemUuid, json));
}
