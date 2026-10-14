import 'package:flutter/services.dart';

import 'system_clipboard.dart';

SystemClipboard createSystemClipboard() => const _FlutterClipboard();

/// Plain text through Flutter's `Clipboard`; HTML of the last copy is kept
/// in memory and returned when the plain text still matches.
class _FlutterClipboard extends SystemClipboard {
  const _FlutterClipboard();

  static SystemClipboardData? _lastWrite;

  @override
  Future<void> write(SystemClipboardData data) async {
    _lastWrite = data;
    await Clipboard.setData(ClipboardData(text: data.plainText));
  }

  @override
  Future<SystemClipboardData?> read() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return null;
    final last = _lastWrite;
    if (last != null && last.plainText == text) return last;
    return SystemClipboardData(plainText: text);
  }
}
