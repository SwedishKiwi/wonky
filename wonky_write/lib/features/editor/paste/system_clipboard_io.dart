import 'package:flutter/services.dart';

import 'clipboard_codec.dart';
import 'system_clipboard.dart';

SystemClipboard createSystemClipboard() => const _FlutterClipboard();

/// Plain-text clipboard through Flutter's `Clipboard`. The Wonky Delta of the
/// last copy is kept in memory so that copy/paste within the app is lossless.
class _FlutterClipboard extends SystemClipboard {
  const _FlutterClipboard();

  static ClipboardContent? _lastWrite;

  @override
  Future<void> write(ClipboardContent content) async {
    _lastWrite = content;
    await Clipboard.setData(ClipboardData(text: content.plainText));
  }

  @override
  Future<ClipboardContent?> read() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return null;
    final last = _lastWrite;
    if (last != null && last.plainText == text) return last;
    return ClipboardContent(plainText: text);
  }
}
