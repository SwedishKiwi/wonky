import 'dart:convert';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/files.dart' show formatStorageBytes;
import 'package:wonky_core/wonky_core.dart' show DriveTools, Role;

import '../common/models.dart';
import '../drive/drive_file_filters.dart';
import '../drive/drive_file_service.dart';
import '../sharing/access_service.dart';
import '../storage/storage_service.dart';
import 'drive_tool_handlers.dart';
import 'tool_executor.dart';
import 'tool_support.dart';

/// The bytes of an uploaded file read for an agent (`drive.download_file`,
/// `wonky://file/<uuid>`).
class McpFileContent {
  McpFileContent(this.item, this.file, this.encoding);

  final DriveItem item;
  final StoredFile file;

  /// The text encoding recorded at upload (`utf-8`, `utf-16le`,
  /// `utf-16be`, `latin1`); null for binary files.
  final String? encoding;

  bool get isText => encoding != null;
  int get sizeBytes => file.sizeBytes;
  String get mimeType => item.mimeType ?? 'application/octet-stream';
}

/// (v2) Headless tools for uploaded files (suite 09 §4, Drive 02, Drive 03
/// §6.6): `drive.upload_file`, `drive.create_upload` /
/// `drive.complete_upload` (bytes through `PUT /files/upload/…`),
/// `drive.download_file`, `drive.convert_file` and `drive.get_storage`.
/// Everything goes through [DriveFileService] and [StorageService], so
/// permissions, rate limits, sniffing and quota are the ones of the app's
/// upload flow; quota refusals surface as `quota_exceeded`.
abstract final class DriveFileToolHandlers {
  static List<RegisteredMcpTool> get all => [
    RegisteredMcpTool(DriveTools.uploadFile, uploadFile),
    RegisteredMcpTool(DriveTools.createUpload, createUpload),
    RegisteredMcpTool(DriveTools.completeUpload, completeUpload),
    RegisteredMcpTool(DriveTools.downloadFile, downloadFile),
    RegisteredMcpTool(DriveTools.convertFile, convertFile),
    RegisteredMcpTool(DriveTools.getStorage, getStorage),
  ];

  /// Largest inline upload (`drive.upload_file`, suite 09 §4: 10 MB).
  /// Tests may lower it.
  static int inlineUploadMaxBytes = 10 * 1024 * 1024;

  /// Largest file returned as text by default (1 MB).
  static int textMaxBytes = 1024 * 1024;

  /// Largest file returned as base64 (2 MB).
  static int base64MaxBytes = 2 * 1024 * 1024;

  // --------------------------------------------------------------- upload

  static Future<ToolResult> uploadFile(ToolContext ctx, ToolArgs a) async {
    final bytes = _content(a);
    final itemUuid = const Uuid().v7obj();
    final fileUuid = const Uuid().v7obj();
    await DriveFileService.createUpload(
      ctx.session,
      ctx.actor,
      FileUploadRequest(
        itemUuid: itemUuid,
        fileUuid: fileUuid,
        parentUuid: a.uuid('parent_uuid'),
        name: a.requireString('name'),
        sizeBytes: bytes.length,
        declaredMimeType: a.string('mime_type'),
      ),
    );
    final DriveItemView view;
    try {
      if (bytes.isNotEmpty) {
        final file = (await StoredFile.db.findFirstRow(
          ctx.session,
          where: (t) => t.fileUuid.equals(fileUuid),
        ))!;
        await ctx.session.storage.storeFile(
          storageId: file.storageId,
          path: file.path,
          byteData: ByteData.sublistView(bytes),
        );
      }
      view = await DriveFileService.completeUpload(
        ctx.session,
        ctx.actor,
        itemUuid,
      );
    } on Object {
      // Releases the reservation and the item (a no-op when completion
      // already failed the upload).
      try {
        await DriveFileService.cancelUpload(ctx.session, ctx.actor, itemUuid);
      } on Object {
        // The original failure matters.
      }
      rethrow;
    }
    return _fileResult(ctx, view, 'Uploaded');
  }

  /// The bytes of `text` or `content_base64` (exactly one), at most
  /// [inlineUploadMaxBytes].
  static Uint8List _content(ToolArgs a) {
    final text = a.string('text');
    final b64 = a.string('content_base64');
    if ((text == null) == (b64 == null)) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'Pass exactly one of text or content_base64.',
      );
    }
    final max = inlineUploadMaxBytes;
    final Uint8List bytes;
    if (b64 != null) {
      // Refuse before decoding a huge string.
      if (b64.length ~/ 4 * 3 > max + 3) throw _inlineTooLarge(max);
      try {
        bytes = base64Decode(b64.replaceAll(RegExp(r'\s'), ''));
      } on FormatException {
        throw McpToolException(McpErrorCode.invalidArgs, 'Invalid base64.');
      }
    } else {
      bytes = Uint8List.fromList(utf8.encode(text!));
    }
    if (bytes.length > max) throw _inlineTooLarge(max);
    return bytes;
  }

  static McpToolException _inlineTooLarge(int max) => McpToolException(
    McpErrorCode.tooLarge,
    'Inline uploads can be at most ${formatStorageBytes(max)}. Use '
    'drive.create_upload for larger files.',
    details: {'max_bytes': max},
  );

  static Future<ToolResult> createUpload(ToolContext ctx, ToolArgs a) async {
    final itemUuid = const Uuid().v7obj();
    final start = await DriveFileService.createUpload(
      ctx.session,
      ctx.actor,
      FileUploadRequest(
        itemUuid: itemUuid,
        fileUuid: const Uuid().v7obj(),
        parentUuid: a.uuid('parent_uuid'),
        name: a.requireString('name'),
        sizeBytes: a.integer('size_bytes')!,
        declaredMimeType: a.string('mime_type'),
      ),
    );
    final ({String url, DateTime expiresAt}) target;
    try {
      target = await DriveFileService.uploadUrl(
        ctx.session,
        ctx.actor,
        itemUuid,
      );
    } on Object {
      await DriveFileService.cancelUpload(ctx.session, ctx.actor, itemUuid);
      rethrow;
    }
    final size = a.integer('size_bytes')!;
    return ToolResult(
      {
        'item_uuid': itemUuid.uuid,
        'item': DriveToolHandlers.itemJson(start.item),
        'upload_url': target.url,
        'method': 'PUT',
        'headers': {'Content-Type': 'application/octet-stream'},
        'max_bytes': size,
        'expires_at': target.expiresAt,
        'storage': DriveToolHandlers.storageOf(start.storage),
      },
      text:
          'PUT the ${formatStorageBytes(size)} of "${start.item.name}" to '
          '${target.url} (until ${target.expiresAt.toIso8601String()}), '
          'then call drive.complete_upload with item_uuid '
          '${itemUuid.uuid}.',
    );
  }

  static Future<ToolResult> completeUpload(ToolContext ctx, ToolArgs a) async {
    final itemUuid = a.requireUuid('item_uuid');
    final item = await AccessService.findItem(ctx.session, itemUuid);
    if (item == null ||
        item.kind != DriveItemKind.file ||
        item.ownerId != ctx.actor.userId) {
      throw McpToolException(
        McpErrorCode.notFound,
        'No upload of yours with this item_uuid (uploads expire after '
        '24 hours).',
      );
    }
    if (item.uploadState == FileUploadState.uploading) {
      final file = item.contentRef == null
          ? null
          : await StoredFile.db.findFirstRow(
              ctx.session,
              where: (t) => t.fileUuid.equals(item.contentRef!),
            );
      // Completing before the PUT would fail (and delete) the upload.
      if (file != null && !await _received(ctx.session, file)) {
        throw McpToolException(
          McpErrorCode.conflict,
          'No bytes have been received yet: PUT the whole file to the '
          'upload_url of drive.create_upload first.',
          details: {'expected_bytes': file.sizeBytes},
        );
      }
    }
    final view = await DriveFileService.completeUpload(
      ctx.session,
      ctx.actor,
      itemUuid,
    );
    return _fileResult(ctx, view, 'Uploaded');
  }

  /// Whether the bytes of a pending upload are in storage (an empty file
  /// always is).
  static Future<bool> _received(Session session, StoredFile file) async {
    if (file.sizeBytes == 0) return true;
    try {
      if (await session.storage.fileExists(
        storageId: file.storageId,
        path: file.path,
      )) {
        return true;
      }
      // A Serverpod `FileUploader` upload is stored unverified.
      return await session.storage.verifyUpload(
        storageId: file.storageId,
        path: file.path,
      );
    } on Exception {
      return false;
    }
  }

  static Future<ToolResult> _fileResult(
    ToolContext ctx,
    DriveItemView view,
    String verb,
  ) async => ToolResult(
    {
      'item': DriveToolHandlers.itemJson(view),
      'storage': await DriveToolHandlers.storageJson(ctx),
    },
    text:
        '$verb "${view.name}" (${view.mimeType}, '
        '${formatStorageBytes(view.sizeBytes)}, ${view.uuid.uuid})',
  );

  // ------------------------------------------------------------- download

  /// A ready file [ctx]'s user may download (Viewer+; viewers and
  /// commenters only when the owner allows downloads).
  static Future<McpFileContent> readable(
    ToolContext ctx,
    UuidValue uuid,
  ) async {
    final (item, role) = await AccessService.require(
      ctx.session,
      ctx.actor,
      uuid,
      Role.viewer,
    );
    if (item.kind != DriveItemKind.file) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'This is a ${item.kind.name}, not an uploaded file. Use drive.export '
        '(or write.get_document / sheets.get_values) for it.',
      );
    }
    if (!DriveFileFilters.listable(item, ctx.actor.userId)) {
      throw McpToolException(McpErrorCode.notFound, 'Not found.');
    }
    if (item.uploadState != FileUploadState.ready) {
      throw McpToolException(
        McpErrorCode.conflict,
        'The file is still uploading.',
      );
    }
    if (role < Role.editor && !item.nonEditorsCanExport) {
      throw McpToolException(
        McpErrorCode.forbidden,
        'The owner has disabled downloads for viewers.',
      );
    }
    final file = item.contentRef == null
        ? null
        : await StoredFile.db.findFirstRow(
            ctx.session,
            where: (t) => t.fileUuid.equals(item.contentRef!),
          );
    if (file == null) {
      throw McpToolException(McpErrorCode.notFound, 'The file has no bytes.');
    }
    return McpFileContent(item, file, _encodingOf(item));
  }

  static String? _encodingOf(DriveItem item) {
    final raw = item.fileMetaJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      final meta = jsonDecode(raw);
      final e = meta is Map ? meta['encoding'] : null;
      return e is String ? e : null;
    } on FormatException {
      return null;
    }
  }

  /// The stored bytes of [c].
  static Future<Uint8List> bytesOf(Session session, McpFileContent c) async {
    final data = await session.storage.retrieveFile(
      storageId: c.file.storageId,
      path: c.file.path,
    );
    return Uint8List.sublistView(data);
  }

  /// Decodes text bytes with the encoding recorded at upload (BOMs
  /// removed; invalid sequences replaced).
  static String decodeText(Uint8List bytes, String encoding) {
    switch (encoding) {
      case 'utf-16le':
      case 'utf-16be':
        final le = encoding == 'utf-16le';
        var start = 0;
        if (bytes.length >= 2 &&
            ((le && bytes[0] == 0xFF && bytes[1] == 0xFE) ||
                (!le && bytes[0] == 0xFE && bytes[1] == 0xFF))) {
          start = 2;
        }
        final units = <int>[
          for (var i = start; i + 1 < bytes.length; i += 2)
            le
                ? bytes[i] | (bytes[i + 1] << 8)
                : (bytes[i] << 8) | bytes[i + 1],
        ];
        return String.fromCharCodes(units);
      case 'latin1':
        return latin1.decode(bytes);
      default:
        final text = utf8.decode(bytes, allowMalformed: true);
        return text.startsWith('﻿') ? text.substring(1) : text;
    }
  }

  static Future<ToolResult> downloadFile(ToolContext ctx, ToolArgs a) async {
    final uuid = a.requireUuid('uuid');
    final c = await readable(ctx, uuid);
    final size = c.sizeBytes;
    final mode =
        a.string('as') ??
        (c.isText && size <= textMaxBytes
            ? 'text'
            : size <= base64MaxBytes
            ? 'base64'
            : 'url');
    final common = <String, Object?>{
      'uuid': uuid.uuid,
      'file_name': c.item.name,
      'mime_type': c.mimeType,
      'size_bytes': size,
    };
    switch (mode) {
      case 'text':
        if (!c.isText) {
          throw McpToolException(
            McpErrorCode.invalidArgs,
            '"${c.item.name}" is not a text file (${c.mimeType}). Use as: '
            'base64 or url.',
          );
        }
        if (size > textMaxBytes) {
          throw McpToolException(
            McpErrorCode.tooLarge,
            'Text is returned for files up to '
            '${formatStorageBytes(textMaxBytes)}; use as: url.',
            details: {'max_bytes': textMaxBytes},
          );
        }
        final text = decodeText(await bytesOf(ctx.session, c), c.encoding!);
        return ToolResult({
          ...common,
          'encoding': c.encoding,
          'text': text,
        }, text: text);
      case 'base64':
        if (size > base64MaxBytes) {
          throw McpToolException(
            McpErrorCode.tooLarge,
            'Base64 content is returned for files up to '
            '${formatStorageBytes(base64MaxBytes)}; use as: url.',
            details: {'max_bytes': base64MaxBytes},
          );
        }
        final b64 = base64Encode(await bytesOf(ctx.session, c));
        return ToolResult(
          {...common, 'content_base64': b64},
          text:
              '"${c.item.name}" (${c.mimeType}, ${formatStorageBytes(size)}) '
              'as base64 in content_base64.',
        );
      default:
        final url = await DriveFileService.contentUrl(
          ctx.session,
          ctx.actor,
          uuid,
          download: true,
        );
        return ToolResult(
          {...common, 'download_url': url.url, 'expires_at': url.expiresAt},
          text:
              'Download "${c.item.name}" (${formatStorageBytes(size)}): '
              '${url.url} (valid until ${url.expiresAt?.toIso8601String()})',
        );
    }
  }

  // -------------------------------------------------------------- convert

  static Future<ToolResult> convertFile(ToolContext ctx, ToolArgs a) async {
    final target = a.requireString('target') == 'spreadsheet'
        ? DriveItemKind.spreadsheet
        : DriveItemKind.document;
    final options = a.object('options');
    final report = await DriveFileService.convert(
      ctx.session,
      ctx.actor,
      a.requireUuid('uuid'),
      target,
      DriveImportOptions(
        format: a.string('format'),
        name: a.string('name'),
        parentUuid: a.uuid('parent_uuid'),
        optionsJson: options == null ? null : jsonEncode(options),
      ),
    );
    final view = report.item;
    return ToolResult(
      {
        'item': DriveToolHandlers.itemJson(view),
        'warnings': [for (final w in report.warnings) w.toJson()],
        'storage': await DriveToolHandlers.storageJson(ctx),
      },
      text:
          'Converted to ${target.name} "${view.name}" (${view.uuid.uuid}); '
          'open it at ${DriveToolHandlers.urlOf(view)}',
    );
  }

  // -------------------------------------------------------------- storage

  /// `drive.get_storage` / `wonky://drive/storage` (Drive 03 §3).
  static Map<String, Object?> usageJson(StorageUsage u) => {
    'quota_bytes': u.quotaBytes,
    'used_bytes': u.bytesUsed,
    'reserved_bytes': u.reservedBytes,
    'available_bytes': u.availableBytes,
    'over_quota': u.overQuota,
    'max_file_upload_bytes': u.maxFileUploadBytes,
    'calculating': u.calculating,
    'by_kind': {
      'documents': u.documentsBytes,
      'spreadsheets': u.spreadsheetsBytes,
      'presentations': u.presentationsBytes,
      'files': u.filesBytes,
      'trash': u.trashBytes,
    },
    'counts': {
      'documents': u.documents,
      'spreadsheets': u.spreadsheets,
      'presentations': u.presentations,
      'files': u.files,
      'folders': u.folders,
    },
  };

  static Future<ToolResult> getStorage(ToolContext ctx, ToolArgs a) async {
    final u = await StorageService.instance.usage(
      ctx.session,
      ctx.actor.userId,
    );
    final percent = u.quotaBytes <= 0
        ? 0
        : (u.bytesUsed * 100 / u.quotaBytes).round();
    return ToolResult(
      usageJson(u),
      text: u.calculating
          ? 'Storage is still being calculated.'
          : '${formatStorageBytes(u.bytesUsed)} of '
                '${formatStorageBytes(u.quotaBytes)} used ($percent %), '
                '${formatStorageBytes(u.availableBytes)} available'
                '${u.overQuota ? ' — over quota' : ''}.',
    );
  }
}
