import 'clipboard_codec.dart';
import 'system_clipboard_io.dart' if (dart.library.js_interop) 'system_clipboard_web.dart' as platform;

/// Reads and writes the system clipboard with multiple representations
/// (Write 04 §23). On web this uses the async Clipboard API (`text/html` +
/// `text/plain`); elsewhere plain text only.
abstract class SystemClipboard {
  const SystemClipboard();

  /// The platform clipboard.
  factory SystemClipboard.platform() => platform.createSystemClipboard();

  Future<void> write(ClipboardContent content);

  /// The current clipboard content, or `null` when unavailable or denied.
  Future<ClipboardContent?> read();
}

/// An in-memory clipboard (tests, headless use).
class MemoryClipboard extends SystemClipboard {
  MemoryClipboard();

  ClipboardContent? content;

  @override
  Future<void> write(ClipboardContent content) async => this.content = content;

  @override
  Future<ClipboardContent?> read() async => content;
}
