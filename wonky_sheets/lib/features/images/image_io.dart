import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/sheets_l10n.dart';
import 'image_service.dart';

/// Platform file I/O of images and chart downloads, replaceable in tests.
abstract final class SheetsFileIo {
  /// Picks one image (null when cancelled). Throws [ImageRejected].
  static Future<PickedImage?> Function(SheetsLocalizations l) pickImage =
      _pickImage;

  /// Saves [bytes] as [fileName] (web: browser download in the same tab;
  /// desktop: save dialog). Returns whether it was saved.
  static Future<bool> Function(
    String fileName,
    Uint8List bytes,
    String mimeType,
    SheetsLocalizations l,
  )
  saveBytes = _saveBytes;

  static Future<PickedImage?> _pickImage(SheetsLocalizations l) async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: SheetsImageRules.extensions,
      dialogTitle: l.imagePickTitle,
    );
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    final mime = SheetsImageRules.validate(f.name, bytes);
    return PickedImage(name: f.name, bytes: bytes, mimeType: mime);
  }

  static Future<bool> _saveBytes(
    String fileName,
    Uint8List bytes,
    String mimeType,
    SheetsLocalizations l,
  ) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: l.downloadSaveTitle(fileName),
    );
    return kIsWeb || uri != null;
  }

  /// A file name without characters that file systems reject.
  static String safeName(String name, String extension) {
    var n = name
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (n.isEmpty) n = 'Chart';
    if (n.length > 120) n = n.substring(0, 120).trim();
    return '$n.$extension';
  }
}
