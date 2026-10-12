import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_write_core/wonky_write_core.dart' as core;

import '../../platform/activity/activity_service.dart';
import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/json.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/files/file_service.dart';
import '../content/write_content.dart';
import '../ot/document_service.dart';
import '../ot/document_store.dart';

/// A file produced by a registered exporter.
class ExportedFile {
  const ExportedFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.pageCount,
    this.warnings = const [],
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final int? pageCount;
  final List<ImportWarningView> warnings;
}

/// Server-side Write exports (Write 07 §10). Text formats (Markdown, plain
/// text) are produced here; the paginated/office formats are produced by
/// the `wonky_write_core` exporters registered in [exporters].
abstract final class WriteExportService {
  static const resultLifetime = Duration(hours: 24);
  static const inlineLimit = 1024 * 1024;
  static const maxConcurrentPerUser = 2;
  static const maxImageBytes = 10 * 1024 * 1024;

  /// Additional exporters by MCP format name (`pdf`, `html`, `docx`, …),
  /// registered when the core exporters are available.
  static final Map<
    String,
    Future<ExportedFile> Function(
      Session session,
      Document document,
      DriveItem item,
      core.Delta content,
      Map<String, Object?> options,
    )
  >
  exporters = {};

  static final Map<int, int> _running = {};

  static const _textFormats = {'md', 'txt'};

  static Future<ExportResultView> export(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    String format,
    String optionsJson, {
    int? revision,
    void Function(String phase, double progress)? onProgress,
  }) async {
    final (doc, item, role) = await DocumentService.require(
      session,
      actor,
      documentUuid,
    );
    if (role < Role.editor && !item.nonEditorsCanExport) {
      throw Errors.forbidden('The owner has disabled downloads for viewers.');
    }
    if (revision != null && revision != doc.headRevision && role < Role.editor) {
      throw Errors.forbidden('Exporting older versions requires edit access.');
    }
    final fmt = format.toLowerCase();
    if (!_textFormats.contains(fmt) && !exporters.containsKey(fmt)) {
      throw Errors.unavailable('Export to "$format" is not available on the server.');
    }
    final running = _running[actor.userId] ?? 0;
    if (running >= maxConcurrentPerUser) {
      throw Errors.busy('Wait for your other exports to finish.');
    }
    _running[actor.userId] = running + 1;
    try {
      onProgress?.call('loading', 0.1);
      final content = await DocumentStore.contentAt(
        session,
        doc,
        revision ?? doc.headRevision,
      );
      final options = decodeObject(optionsJson);
      final original = options['suggestions'] == 'original';
      final view = original
          ? core.SuggestionViewMode.original
          : core.SuggestionViewMode.accepted;
      String fileName;
      String mimeType;
      Uint8List bytes;
      String? inlineText;
      int? pageCount;
      final warnings = <ImportWarningView>[];
      onProgress?.call('packaging', 0.5);
      switch (fmt) {
        case 'md':
          final text = const core.MarkdownCodec().exportMarkdown(
            content,
            view: view,
            frontMatter: options['includeFrontMatter'] == false
                ? null
                : doc.frontMatter,
          );
          fileName = exportFileName(item.name, 'md');
          mimeType = 'text/markdown; charset=utf-8';
          bytes = Uint8List.fromList(utf8.encode(text));
          inlineText = bytes.length <= inlineLimit ? text : null;
        case 'txt':
          final text = core.PlainTextRenderer.render(content, view: view);
          fileName = exportFileName(item.name, 'txt');
          mimeType = 'text/plain; charset=utf-8';
          bytes = Uint8List.fromList(utf8.encode(text));
          inlineText = bytes.length <= inlineLimit ? text : null;
        default:
          final artifact = await exporters[fmt]!(
            session,
            doc,
            item,
            content,
            options,
          );
          fileName = artifact.fileName;
          mimeType = artifact.mimeType;
          bytes = artifact.bytes;
          pageCount = artifact.pageCount;
          warnings.addAll(artifact.warnings);
      }
      onProgress?.call('uploading', 0.8);
      final expires = nowUtc().add(resultLifetime);
      final file = await FileService.storeServerFile(
        session,
        ownerId: actor.userId,
        itemId: item.id,
        kind: StoredFileKind.exportResult,
        fileName: fileName,
        mimeType: mimeType.split(';').first,
        bytes: bytes,
        expiresAt: expires,
      );
      final url = await FileService.getUrl(session, actor, file.fileUuid);
      await ActivityService.log(
        session,
        item.id!,
        actor,
        ActivityType.exported,
        summary: {'format': fmt},
      );
      onProgress?.call('done', 1);
      return ExportResultView(
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: bytes.length,
        pageCount: pageCount,
        downloadUrl: url.url!,
        expiresAt: url.expiresAt ?? expires,
        inlineText: inlineText,
        warnings: warnings,
      );
    } finally {
      _running[actor.userId] = (_running[actor.userId] ?? 1) - 1;
    }
  }

  static Stream<ExportProgressEvent> exportWithProgress(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    String format,
    String optionsJson, {
    int? revision,
  }) {
    final controller = StreamController<ExportProgressEvent>();
    unawaited(() async {
      try {
        final result = await export(
          session,
          actor,
          documentUuid,
          format,
          optionsJson,
          revision: revision,
          onProgress: (phase, progress) {
            if (controller.isClosed) return;
            controller.add(
              ExportProgressEvent(
                kind: ExportProgressKind.phase,
                phase: phase,
                progress: progress,
              ),
            );
          },
        );
        controller.add(
          ExportProgressEvent(kind: ExportProgressKind.done, result: result),
        );
      } on WonkyException catch (e) {
        controller.add(
          ExportProgressEvent(
            kind: ExportProgressKind.error,
            errorCode: e.code.name,
            message: e.message,
          ),
        );
      } finally {
        await controller.close();
      }
    }());
    return controller.stream;
  }

  /// Converts an uploaded file for *Import into this document*.
  static Future<ConvertForInsertResult> convertForInsert(
    Session session,
    Actor actor,
    UuidValue uploadId,
    String format,
    String optionsJson,
  ) async {
    final file = await FileService.requireOwnReadyFile(
      session,
      actor,
      uploadId,
      kind: StoredFileKind.importSource,
    );
    final bytes = await FileService.readBytes(session, file);
    final text = utf8.decode(
      bytes.buffer.asUint8List(0, bytes.lengthInBytes),
      allowMalformed: true,
    );
    final fmt = format.toLowerCase();
    final ({core.Delta delta, List<ImportWarningView> warnings}) result;
    switch (fmt) {
      case 'md' || 'markdown':
        final md = WriteContent.fromMarkdown(text);
        result = (delta: md.delta, warnings: md.warnings);
      case 'txt' || 'text':
        result = WriteContent.fromPlainText(
          text,
          softBreaks: decodeObject(optionsJson)['lineBreaks'] == 'soft',
        );
      default:
        throw Errors.unavailable('Converting "$format" is not available.');
    }
    await FileService.deleteFile(session, file.fileUuid);
    return ConvertForInsertResult(
      deltaJson: jsonEncode(result.delta.toJson()),
      warnings: result.warnings,
    );
  }

  /// Proxy for remote images blocked by CORS during client exports
  /// (SSRF-protected: https only, public addresses, 10 s, 10 MB, images).
  static Future<ByteData> fetchImage(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    String src,
  ) async {
    await DocumentService.require(session, actor, documentUuid);
    final uri = Uri.tryParse(src);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw Errors.invalid('Only https images can be fetched.');
    }
    if (uri.hasPort && uri.port != 443) {
      throw Errors.invalid('Only the default https port is allowed.');
    }
    final addresses = await InternetAddress.lookup(uri.host);
    if (addresses.isEmpty || addresses.any(_isPrivate)) {
      throw Errors.forbidden('This address cannot be fetched.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Errors.notFound('Image');
      }
      final type = response.headers.contentType?.mimeType ?? '';
      if (!type.startsWith('image/') || type == 'image/svg+xml') {
        throw Errors.invalid('The URL is not an image.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        builder.add(chunk);
        if (builder.length > maxImageBytes) {
          throw Errors.tooLarge('The image is larger than 10 MB.');
        }
      }
      return ByteData.sublistView(builder.takeBytes());
    } on TimeoutException {
      throw Errors.unavailable('The image did not load in time.');
    } finally {
      client.close(force: true);
    }
  }

  /// Sanitized file name (no `/\\:*?"<>|`, ≤ 120 chars) with [extension].
  static String exportFileName(String name, String extension) {
    var n = name
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (n.isEmpty) n = 'Untitled';
    if (n.length > 120) n = n.substring(0, 120).trim();
    return '$n.$extension';
  }

  static bool _isPrivate(InternetAddress a) {
    if (a.isLoopback || a.isLinkLocal || a.isMulticast) return true;
    final b = a.rawAddress;
    if (a.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          b[0] == 0 ||
          b[0] == 127 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168) ||
          (b[0] == 169 && b[1] == 254) ||
          (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
    }
    // IPv6 unique local (fc00::/7) and IPv4-mapped private ranges.
    if ((b[0] & 0xfe) == 0xfc) return true;
    return false;
  }
}
