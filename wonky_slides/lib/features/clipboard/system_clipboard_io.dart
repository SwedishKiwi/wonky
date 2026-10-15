import 'package:flutter/services.dart';

import 'system_clipboard.dart';

SlidesSystemClipboard createSlidesClipboard() => const _FlutterClipboard();

/// Plain text through Flutter's `Clipboard`; the last write (HTML) is kept
/// in memory and returned while the plain text still matches.
class _FlutterClipboard extends SlidesSystemClipboard {
  const _FlutterClipboard();

  static SlidesClipboardData? _lastWrite;

  @override
  Future<void> write(SlidesClipboardData data) async {
    _lastWrite = data;
    try {
      await Clipboard.setData(ClipboardData(text: data.plainText ?? ''));
    } catch (_) {
      // No platform clipboard (tests).
    }
  }

  @override
  Future<SlidesClipboardData?> read() async {
    final ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      return _lastWrite;
    }
    final text = data?.text;
    if (text == null) return null;
    final last = _lastWrite;
    if (last != null && last.plainText == text) return last;
    return SlidesClipboardData(plainText: text);
  }
}
