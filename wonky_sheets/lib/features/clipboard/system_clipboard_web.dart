import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'system_clipboard.dart';

SystemClipboard createSystemClipboard() => const _WebClipboard();

/// The async Clipboard API: writes `text/html` + `text/plain`, reads both.
class _WebClipboard extends SystemClipboard {
  const _WebClipboard();

  static SystemClipboardData? _lastWrite;
  static bool _readBlocked = false;

  @override
  bool get readBlocked => _readBlocked;

  @override
  Future<void> write(SystemClipboardData data) async {
    _lastWrite = data;
    final clipboard = web.window.navigator.clipboard;
    try {
      final items = <String, JSAny>{
        'text/plain': web.Blob(
          [data.plainText.toJS].toJS,
          web.BlobPropertyBag(type: 'text/plain'),
        ),
        if (data.html != null)
          'text/html': web.Blob(
            [data.html!.toJS].toJS,
            web.BlobPropertyBag(type: 'text/html'),
          ),
      };
      await clipboard
          .write([web.ClipboardItem(items.jsify() as JSObject)].toJS)
          .toDart;
    } catch (_) {
      try {
        await clipboard.writeText(data.plainText).toDart;
      } catch (_) {}
    }
  }

  @override
  Future<SystemClipboardData?> read() async {
    final clipboard = web.window.navigator.clipboard;
    _readBlocked = false;
    try {
      final items = (await clipboard.read().toDart).toDart;
      String? plain;
      String? html;
      for (final item in items) {
        final types = item.types.toDart.map((t) => t.toDart).toList();
        if (html == null && types.contains('text/html')) {
          final blob = await item.getType('text/html').toDart;
          html = (await blob.text().toDart).toDart;
        }
        if (plain == null && types.contains('text/plain')) {
          final blob = await item.getType('text/plain').toDart;
          plain = (await blob.text().toDart).toDart;
        }
      }
      if (plain == null && html == null) return _lastWrite;
      return SystemClipboardData(plainText: plain ?? '', html: html);
    } catch (_) {
      try {
        final text = (await clipboard.readText().toDart).toDart;
        final last = _lastWrite;
        if (last != null && last.plainText == text) return last;
        return SystemClipboardData(plainText: text);
      } catch (_) {
        // Both APIs refused: the browser denied clipboard access.
        _readBlocked = true;
        return _lastWrite;
      }
    }
  }
}
