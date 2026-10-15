import 'dart:collection';
import 'dart:typed_data';

import 'preview_content.dart';

/// In-memory LRU of preview bytes by stored-file uuid (Drive 02 §6.1), so
/// prev/next browsing and reopening don't download again; also what the
/// offline state falls back to.
class PreviewByteCache {
  PreviewByteCache({this.maxBytes = PreviewLimits.cacheBytes});

  final int maxBytes;
  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();
  int _bytes = 0;

  /// Bytes held.
  int get sizeBytes => _bytes;

  /// The cached bytes of [key] (marks it most recently used).
  Uint8List? get(String key) {
    final v = _entries.remove(key);
    if (v != null) _entries[key] = v;
    return v;
  }

  /// Caches [bytes] under [key]; evicts the least recently used entries
  /// beyond [maxBytes]. Entries larger than the whole cache are skipped.
  void put(String key, Uint8List bytes) {
    if (bytes.length > maxBytes) return;
    final old = _entries.remove(key);
    if (old != null) _bytes -= old.length;
    _entries[key] = bytes;
    _bytes += bytes.length;
    while (_bytes > maxBytes && _entries.isNotEmpty) {
      final first = _entries.keys.first;
      _bytes -= _entries.remove(first)!.length;
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}
