import 'package:flutter/foundation.dart';

import 'image_clipboard.dart';

ImageClipboard createImageClipboard() => const _NoImageClipboard();

/// Desktop builds: no image clipboard yet (v2 is web only, suite 01 A13).
class _NoImageClipboard extends ImageClipboard {
  const _NoImageClipboard();

  @override
  bool get supported => false;

  @override
  Future<ClipboardImage?> readImage() async => null;

  @override
  Future<bool> writePng(Uint8List png, {String? text}) async => false;
}
