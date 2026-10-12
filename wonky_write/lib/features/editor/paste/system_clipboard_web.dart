import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'clipboard_codec.dart';
import 'system_clipboard.dart';

SystemClipboard createSystemClipboard() => const _WebClipboard();

/// The async Clipboard API: writes `text/html` + `text/plain`, reads both.
class _WebClipboard extends SystemClipboard {
  const _WebClipboard();

  static ClipboardContent? _lastWrite;

  @override
  Future<void> write(ClipboardContent content) async {
    _lastWrite = content;
    final clipboard = web.window.navigator.clipboard;
    try {
      final items = <String, JSAny>{
        'text/plain': web.Blob(
          [content.plainText.toJS].toJS,
          web.BlobPropertyBag(type: 'text/plain'),
        ),
        if (content.html != null)
          'text/html': web.Blob(
            [content.html!.toJS].toJS,
            web.BlobPropertyBag(type: 'text/html'),
          ),
      };
      await clipboard
          .write([web.ClipboardItem(items.jsify() as JSObject)].toJS)
          .toDart;
    } catch (_) {
      await clipboard.writeText(content.plainText).toDart;
    }
  }

  @override
  Future<ClipboardContent?> read() async {
    final clipboard = web.window.navigator.clipboard;
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
      if (plain == null && html == null) return null;
      final last = _lastWrite;
      if (last != null && last.plainText == plain) return last;
      return ClipboardContent(plainText: plain ?? '', html: html);
    } catch (_) {
      try {
        final text = (await clipboard.readText().toDart).toDart;
        return ClipboardContent(plainText: text);
      } catch (_) {
        return null;
      }
    }
  }
}
