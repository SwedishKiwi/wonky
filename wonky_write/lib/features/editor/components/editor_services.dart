import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Upload state of an image embed (Write 04 §17.3).
enum ImageUploadPhase {
  /// This client is uploading the bytes ([ImageUploadStatus.progress]).
  uploading,

  /// The server knows the file but no bytes arrived yet (another user uploads).
  pending,

  /// The upload failed (Retry / Remove).
  failed,

  /// The server refused the upload because the storage quota is full
  /// (Drive 03 §6.3): "Not uploaded — out of storage" with Retry / Remove;
  /// the local bytes stay on this device.
  outOfStorage,
}

@immutable
class ImageUploadStatus {
  const ImageUploadStatus(
    this.phase, {
    this.progress,
    this.uploaderName,
    this.localPreview,
  });

  final ImageUploadPhase phase;

  /// 0–1 while [ImageUploadPhase.uploading].
  final double? progress;

  /// Display name of the uploader (shown to others).
  final String? uploaderName;

  /// Local bytes shown as a preview to the uploader.
  final ImageProvider? localPreview;
}

/// Services the editor needs from the app for images (Write 04 §17).
abstract class EditorImageServices {
  const EditorImageServices();

  /// Resolves an image `src` (`wonky-file://<uuid>` via `FileEndpoint.getUrl`,
  /// or `https://`) to an image provider; `null` while unavailable.
  FutureOr<ImageProvider?> resolve(String src, {double? displayWidth});

  /// The upload status for an image `src`, or a listenable holding `null` when
  /// the image is not being uploaded.
  ValueListenable<ImageUploadStatus?> uploadStatus(String src) =>
      const _NoUpload();

  /// Retries a failed upload or a broken URL.
  void retry(String src) {}

  /// Cancels an upload (the embed is removed by the caller).
  void cancel(String src) {}
}

/// Default image services: `https://` sources load from the network,
/// `wonky-file://` sources are unavailable.
class NetworkImageServices extends EditorImageServices {
  const NetworkImageServices();

  @override
  FutureOr<ImageProvider?> resolve(String src, {double? displayWidth}) {
    if (src.startsWith('https://') || src.startsWith('http://')) {
      return NetworkImage(src);
    }
    return null;
  }
}

class _NoUpload implements ValueListenable<ImageUploadStatus?> {
  const _NoUpload();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  ImageUploadStatus? get value => null;
}

/// Callbacks for block-level UI the host app provides (table editor, language
/// picker, image toolbar, block menu…).
@immutable
class EditorBlockCallbacks {
  const EditorBlockCallbacks({
    this.onEditTable,
    this.onCodeLanguageTap,
    this.onCopyCode,
    this.onImageDoubleTap,
    this.onImageTap,
    this.onRemoveImage,
  });

  /// "Edit table" button / double-click on a table (opens `TableEditorPopover`).
  final void Function(String nodeId, {int? row, int? column})? onEditTable;

  /// The code block language chip was tapped (opens the language picker).
  final void Function(String nodeId, Rect globalChipRect)? onCodeLanguageTap;

  /// The code block copy button was tapped (`write.code.copy`).
  final void Function(String nodeId)? onCopyCode;

  /// Double-click on an image (lightbox, `write.image.preview`).
  final void Function(String nodeId)? onImageDoubleTap;

  /// Click on an image in read-only views (Viewing mode): the lightbox.
  final void Function(String nodeId)? onImageTap;

  /// Remove a failed upload's image.
  final void Function(String nodeId)? onRemoveImage;
}
