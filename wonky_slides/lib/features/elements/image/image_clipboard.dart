import 'package:flutter/foundation.dart';

import 'image_clipboard_io.dart'
    if (dart.library.js_interop) 'image_clipboard_web.dart'
    as platform;

/// An image read from the system clipboard.
@immutable
class ClipboardImage {
  const ClipboardImage({
    required this.bytes,
    required this.mimeType,
    this.hasText = false,
  });

  final Uint8List bytes;
  final String mimeType;

  /// The clipboard also holds non-empty plain text.
  final bool hasText;
}

/// Images on the system clipboard (Slides 03 §6.5.1 *From clipboard*,
/// §12.5; the pattern of Sheets' image clipboard).
///
/// Web: the async Clipboard API (`image/png` items). Desktop builds report
/// no image support (v2 is web only).
abstract class ImageClipboard {
  const ImageClipboard();

  /// The platform clipboard (replaceable in tests).
  static ImageClipboard instance = platform.createImageClipboard();

  /// Whether images can be read and written here.
  bool get supported;

  /// The clipboard image, or null when there is none (or no permission).
  Future<ClipboardImage?> readImage();

  /// Puts [png] on the clipboard, with [text] as the plain-text
  /// representation when given. Returns whether it worked.
  Future<bool> writePng(Uint8List png, {String? text});
}

/// An in-memory image clipboard (tests).
class MemoryImageClipboard extends ImageClipboard {
  MemoryImageClipboard();

  ClipboardImage? image;
  Uint8List? lastPng;
  String? lastText;

  @override
  bool get supported => true;

  @override
  Future<ClipboardImage?> readImage() async => image;

  @override
  Future<bool> writePng(Uint8List png, {String? text}) async {
    lastPng = png;
    lastText = text;
    return true;
  }
}
