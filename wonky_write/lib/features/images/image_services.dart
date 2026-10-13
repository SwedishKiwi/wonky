import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show FileUrlView, StoredFileKind, StoredFileStatus, UuidValue;
import 'package:wonky_core/wonky_core.dart' show UuidV7Generator;

import '../../l10n/write_l10n.dart';
import '../document/write_document_session.dart';
import '../editor/components/editor_services.dart';
import '../offline/pending_uploads.dart';

/// Picked image bytes.
@immutable
class PickedImage {
  const PickedImage({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

/// Why an image file was rejected.
enum ImageRejectReason { svg, unsupportedFormat, tooLarge }

/// Why an image file was rejected (Write 04 §17.1).
class ImageRejected implements Exception {
  const ImageRejected(this.reason);
  final ImageRejectReason reason;

  /// The message in [l] (shown in toasts).
  String messageIn(WriteLocalizations l) => switch (reason) {
    ImageRejectReason.svg => l.imageRejectedSvg,
    ImageRejectReason.unsupportedFormat => l.imageRejectedFormat,
    ImageRejectReason.tooLarge => l.imageRejectedTooLarge(
      ImageRules.maxBytes ~/ (1024 * 1024),
    ),
  };

  /// The English message; UI code uses [messageIn].
  String get message => messageIn(writeL10nEnglish);

  @override
  String toString() => message;
}

/// Image limits and formats (Write 04 §17.1).
abstract final class ImageRules {
  static const maxBytes = 20 * 1024 * 1024;
  static const extensions = ['png', 'jpg', 'jpeg', 'gif', 'webp'];

  /// The MIME type for [name] / sniffed [bytes]; throws [ImageRejected].
  static String validate(String name, Uint8List bytes) {
    final ext = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    if (ext == 'svg' ||
        _startsWith(bytes, '<svg') ||
        _startsWith(bytes, '<?xml')) {
      throw const ImageRejected(ImageRejectReason.svg);
    }
    final mime = sniff(bytes) ?? _byExtension(ext);
    if (mime == null) {
      throw const ImageRejected(ImageRejectReason.unsupportedFormat);
    }
    if (bytes.length > maxBytes) {
      throw const ImageRejected(ImageRejectReason.tooLarge);
    }
    return mime;
  }

  static bool _startsWith(Uint8List b, String s) {
    if (b.length < s.length) return false;
    for (var i = 0; i < s.length; i++) {
      if (b[i] != s.codeUnitAt(i)) return false;
    }
    return true;
  }

  static String? _byExtension(String ext) => switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    _ => null,
  };

  /// Sniffs PNG, JPEG, GIF and WebP.
  static String? sniff(Uint8List b) {
    if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e) {
      return 'image/png';
    }
    if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
      return 'image/jpeg';
    }
    if (_startsWith(b, 'GIF8')) return 'image/gif';
    if (b.length >= 12 &&
        _startsWith(b, 'RIFF') &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }
}

class _Upload {
  _Upload(this.fileUuid, this.image)
    : status = ValueNotifier(
        ImageUploadStatus(
          ImageUploadPhase.uploading,
          progress: 0,
          localPreview: MemoryImage(image.bytes),
        ),
      );

  final UuidValue fileUuid;
  final PickedImage image;
  final ValueNotifier<ImageUploadStatus?> status;
  int attempts = 0;
  bool cancelled = false;
}

class _Url {
  _Url(this.url, this.expiresAt);
  final String url;
  final DateTime? expiresAt;
}

/// `EditorImageServices` of the Write screen (Write 04 §17): resolves
/// `wonky-file://` sources to signed URLs (cached until 60 s before expiry,
/// polling while another user's upload is pending), uploads picked/pasted
/// images through the files service with progress placeholders, retries and
/// cancel.
///
/// With the offline store (suite 12 §1.1 `LocalPendingUpload`) the bytes are
/// stored before uploading: images inserted offline render from the local
/// bytes (also after a reload) and upload in the background when the server
/// is reachable.
class WriteImageServices extends EditorImageServices {
  WriteImageServices({
    required this.files,
    required this.documentUuid,
    UuidV7Generator? ids,
    this._offlineUploads,
  }) : _ids = ids ?? UuidV7Generator.instance;

  final FileRepository files;

  /// The drive item of the document (uploads are attached to it).
  final UuidValue documentUuid;
  final UuidV7Generator _ids;
  final PendingUploads? Function()? _offlineUploads;
  StreamSubscription<UuidValue>? _completedSub;
  PendingUploads? _watched;

  /// The durable upload queue of the signed-in user, if any.
  PendingUploads? get _queue {
    final q =
        _offlineUploads?.call() ??
        WriteDocumentSession.forItem(documentUuid)?.offline?.uploads;
    if (q != null && !identical(q, _watched)) {
      _watched = q;
      unawaited(_completedSub?.cancel());
      _completedSub = q.completed.listen(_onQueueCompleted);
    }
    return q;
  }

  void _onQueueCompleted(UuidValue fileUuid) {
    final src = '$scheme${fileUuid.uuid}';
    final u = _uploads.remove(src);
    if (u != null) {
      u.cancelled = true;
      u.status.value = null;
      _updatePending();
    }
    _urls.remove(src);
    _resolving.remove(src);
  }

  final Map<String, _Upload> _uploads = {};
  final Map<String, _Url> _urls = {};
  final Map<String, Future<ImageProvider?>> _resolving = {};
  static const _none = _NoStatus();

  /// Number of uploads in progress (status bar "Uploading 2 images…").
  final ValueNotifier<int> pendingUploads = ValueNotifier(0);

  static const scheme = 'wonky-file://';

  /// A new `wonky-file://` source and its upload for [image]; the embed is
  /// inserted by the caller with the returned src right away (works offline,
  /// one undo step), the bytes upload in the background.
  String startUpload(PickedImage image) {
    final uuid = UuidValue.withValidation(_ids.nextString());
    final src = '$scheme${uuid.uuid}';
    final upload = _Upload(uuid, image);
    _uploads[src] = upload;
    _updatePending();
    unawaited(_run(src, upload));
    return src;
  }

  Future<void> _run(String src, _Upload u) async {
    final queue = _queue;
    if (queue != null && u.attempts == 0) {
      try {
        await queue.add(
          fileUuid: u.fileUuid,
          itemUuid: documentUuid,
          bytes: u.image.bytes,
          mimeType: u.image.mimeType,
          fileName: u.image.name,
        );
      } catch (e) {
        debugPrint('Storing the image on this device failed: $e');
      }
    }
    queue?.claim(u.fileUuid);
    while (!u.cancelled) {
      u.attempts++;
      u.status.value = ImageUploadStatus(
        ImageUploadPhase.uploading,
        progress: 0.15,
        localPreview: MemoryImage(u.image.bytes),
      );
      try {
        final view = await files.upload(
          fileUuid: u.fileUuid,
          itemUuid: documentUuid,
          fileName: u.image.name,
          mimeType: u.image.mimeType,
          bytes: u.image.bytes,
          kind: StoredFileKind.image,
        );
        if (u.cancelled) return;
        _remember(src, view);
        u.status.value = null;
        _uploads.remove(src);
        _updatePending();
        unawaited(queue?.complete(u.fileUuid));
        return;
      } catch (e) {
        debugPrint('Image upload failed (attempt ${u.attempts}): $e');
        final retryable = isOfflineError(e);
        if (retryable && queue != null && queue.contains(u.fileUuid)) {
          // Stored on this device: the queue uploads it once online.
          u.status.value = ImageUploadStatus(
            ImageUploadPhase.uploading,
            localPreview: MemoryImage(u.image.bytes),
          );
          queue.release(u.fileUuid);
          return;
        }
        if (!retryable || u.attempts >= 5) {
          u.status.value = ImageUploadStatus(
            ImageUploadPhase.failed,
            localPreview: MemoryImage(u.image.bytes),
          );
          _updatePending();
          return;
        }
        final wait = Duration(seconds: (2 << (u.attempts - 1)).clamp(2, 300));
        await Future<void>.delayed(wait);
      }
    }
  }

  void _updatePending() => pendingUploads.value = _uploads.values
      .where((u) => u.status.value?.phase == ImageUploadPhase.uploading)
      .length;

  void _remember(String src, FileUrlView view) {
    final url = view.url;
    if (view.status == StoredFileStatus.ready && url != null) {
      _urls[src] = _Url(url, view.expiresAt);
    }
  }

  @override
  ValueListenable<ImageUploadStatus?> uploadStatus(String src) =>
      _uploads[src]?.status ?? _none;

  @override
  void retry(String src) {
    final u = _uploads[src];
    if (u != null) {
      u.attempts = 0;
      unawaited(_run(src, u));
      return;
    }
    _urls.remove(src);
    _resolving.remove(src);
  }

  @override
  void cancel(String src) {
    final u = _uploads.remove(src);
    if (u == null) return;
    u.cancelled = true;
    u.status.value = null;
    _updatePending();
    unawaited(_queue?.cancel(u.fileUuid));
  }

  @override
  FutureOr<ImageProvider?> resolve(String src, {double? displayWidth}) {
    if (src.startsWith('https://')) return NetworkImage(src);
    if (!src.startsWith(scheme)) return null;
    final local = _uploads[src];
    if (local != null) return MemoryImage(local.image.bytes);
    final queue = _queue;
    UuidValue? fileUuid;
    try {
      fileUuid = UuidValue.withValidation(src.substring(scheme.length));
    } catch (_) {}
    if (queue != null && fileUuid != null && queue.contains(fileUuid)) {
      // Inserted on this device and not uploaded yet: the local bytes.
      return queue
          .bytesOf(fileUuid)
          .then((b) => b == null ? null : MemoryImage(b));
    }
    final cached = _urls[src];
    final now = clock.now();
    if (cached != null &&
        (cached.expiresAt == null ||
            cached.expiresAt!.isAfter(now.add(const Duration(seconds: 60))))) {
      return NetworkImage(cached.url);
    }
    return _resolving.putIfAbsent(src, () async {
      try {
        final uuid = UuidValue.withValidation(src.substring(scheme.length));
        var delay = const Duration(seconds: 2);
        final deadline = now.add(const Duration(hours: 24));
        while (true) {
          final view = await files.getUrl(uuid);
          if (view.status == StoredFileStatus.ready && view.url != null) {
            _remember(src, view);
            return NetworkImage(view.url!);
          }
          if (view.status == StoredFileStatus.failed ||
              clock.now().isAfter(deadline)) {
            return null;
          }
          await Future<void>.delayed(delay);
          delay = delay * 2 > const Duration(seconds: 60)
              ? const Duration(seconds: 60)
              : delay * 2;
        }
      } catch (e) {
        debugPrint('Resolving $src failed: $e');
        return null;
      } finally {
        unawaited(Future(() => _resolving.remove(src)));
      }
    });
  }

  /// The local bytes of an upload (download before the upload finished).
  Uint8List? localBytes(String src) => _uploads[src]?.image.bytes;

  void dispose() {
    unawaited(_completedSub?.cancel());
    for (final u in _uploads.values) {
      u.cancelled = true;
      _watched?.release(u.fileUuid);
    }
    pendingUploads.dispose();
  }
}

class _NoStatus implements ValueListenable<ImageUploadStatus?> {
  const _NoStatus();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  ImageUploadStatus? get value => null;
}
