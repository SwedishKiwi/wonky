import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_clipboard.dart';

ImageClipboard createImageClipboard() => const _ChannelImageClipboard();

/// macOS: `wonky.sheets/clipboard` in `MainFlutterWindow.swift`
/// (NSPasteboard). Elsewhere: unsupported.
class _ChannelImageClipboard extends ImageClipboard {
  const _ChannelImageClipboard();

  static const _channel = MethodChannel('wonky.sheets/clipboard');

  @override
  bool get supported => !kIsWeb && Platform.isMacOS;

  @override
  Future<ClipboardImage?> readImage() async {
    if (!supported) return null;
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('readImage');
      final bytes = r?['png'];
      if (bytes is! Uint8List || bytes.isEmpty) return null;
      return ClipboardImage(
        bytes: bytes,
        mimeType: 'image/png',
        hasText: r?['hasText'] == true,
      );
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('Reading a clipboard image failed: $e');
      return null;
    }
  }

  @override
  Future<bool> writePng(Uint8List png, {String? text}) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('writeImage', {
            'png': png,
            'text': ?text,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('Writing a clipboard image failed: $e');
      return false;
    }
  }
}
