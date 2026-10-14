import 'system_clipboard_io.dart'
    if (dart.library.js_interop) 'system_clipboard_web.dart'
    as platform;

/// What the system clipboard holds: plain text and optional HTML.
class SystemClipboardData {
  const SystemClipboardData({required this.plainText, this.html});

  final String plainText;
  final String? html;
}

/// Reads and writes the system clipboard with `text/plain` + `text/html`
/// (same approach as Wonky Write): the async Clipboard API on web, plain
/// text through Flutter elsewhere (the last written HTML is kept in memory
/// so copy/paste within the app stays lossless).
abstract class SystemClipboard {
  const SystemClipboard();

  factory SystemClipboard.platform() => platform.createSystemClipboard();

  Future<void> write(SystemClipboardData data);

  /// The clipboard content, or null when unavailable or denied.
  Future<SystemClipboardData?> read();
}

/// An in-memory clipboard (tests, headless use).
class MemoryClipboard extends SystemClipboard {
  MemoryClipboard();

  SystemClipboardData? data;

  @override
  Future<void> write(SystemClipboardData data) async => this.data = data;

  @override
  Future<SystemClipboardData?> read() async => data;
}
