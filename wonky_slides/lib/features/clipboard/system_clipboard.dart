import 'package:flutter/foundation.dart';

import 'system_clipboard_io.dart'
    if (dart.library.js_interop) 'system_clipboard_web.dart'
    as platform;

/// What the system clipboard holds (Slides 03 §12.1): plain text, HTML
/// and the first image.
@immutable
class SlidesClipboardData {
  const SlidesClipboardData({
    this.plainText,
    this.html,
    this.image,
    this.imageType,
  });

  final String? plainText;
  final String? html;

  /// Image bytes (`image/png` and other image types) and their type.
  final Uint8List? image;
  final String? imageType;

  bool get isEmpty =>
      (plainText == null || plainText!.isEmpty) &&
      (html == null || html!.isEmpty) &&
      image == null;
}

/// The system clipboard of Wonky Slides (03 §12.1, the approach of Write
/// and Sheets): the async Clipboard API on the web writes `text/plain`,
/// `text/html` (with the embedded Slides payload) and optionally
/// `image/png`, and reads text, HTML and images; desktop builds use plain
/// text through Flutter (the last write is kept in memory, so copy/paste
/// in the app stays lossless).
abstract class SlidesSystemClipboard {
  const SlidesSystemClipboard();

  /// The platform clipboard (replaceable in tests).
  static SlidesSystemClipboard instance = platform.createSlidesClipboard();

  Future<void> write(SlidesClipboardData data);

  /// The clipboard content, or null when unavailable or denied.
  Future<SlidesClipboardData?> read();

  /// Whether the last [read] was refused by the browser (clipboard
  /// permission), as opposed to an empty clipboard.
  bool get readBlocked => false;
}

/// An in-memory clipboard (tests).
class MemorySlidesClipboard extends SlidesSystemClipboard {
  MemorySlidesClipboard([this.data]);

  SlidesClipboardData? data;

  @override
  bool readBlocked = false;

  /// Writes seen (newest last).
  final List<SlidesClipboardData> writes = [];

  @override
  Future<void> write(SlidesClipboardData data) async {
    writes.add(data);
    this.data = data;
  }

  @override
  Future<SlidesClipboardData?> read() async => readBlocked ? null : data;
}
