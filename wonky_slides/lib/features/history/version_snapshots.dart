import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_slides_core/history.dart';

/// Downloads and decodes deck version snapshots (Slides 09 §4.2 step 1):
/// the signed URL from `VersionEndpoint.getSnapshotUrl`, the gzip NDJSON
/// decoded by the core `SlidesSnapshotCodec`. Keeps the last few snapshots
/// in memory (the previous version is needed for the change badges).
abstract final class SlidesVersionSnapshots {
  static const _keep = 4;
  static final Map<String, Future<SlidesSnapshot>> _cache = {};

  /// Overrides the download (tests): the gzip bytes of a version.
  @visibleForTesting
  static Future<List<int>> Function(UuidValue item, int versionId)? fetch;

  /// The snapshot of [versionId] of presentation [item].
  static Future<SlidesSnapshot> load(
    ShellServices services,
    UuidValue item,
    int versionId,
  ) {
    final key = '${item.uuid}/$versionId';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    // Decks are small (50–500 KB snapshots): decoded on this isolate.
    final f = _download(
      services,
      item,
      versionId,
    ).then(SlidesSnapshotCodec.decode);
    _cache[key] = f;
    unawaited(f.then<void>((_) {}, onError: (Object _) => _cache.remove(key)));
    while (_cache.length > _keep) {
      _cache.remove(_cache.keys.first);
    }
    return f;
  }

  static Future<List<int>> _download(
    ShellServices services,
    UuidValue item,
    int versionId,
  ) async {
    final override = fetch;
    if (override != null) return override(item, versionId);
    final client = services.client;
    if (client == null) throw StateError('Not connected');
    if (Api.simulatedOffline) {
      throw const OfflineException('simulated offline');
    }
    final url = await client.version.getSnapshotUrl(item, versionId);
    final u = url.url;
    if (u == null) throw StateError('The snapshot is not available yet.');
    final r = await http.get(Uri.parse(u));
    if (r.statusCode != 200) {
      throw StateError('Snapshot download failed (${r.statusCode}).');
    }
    return r.bodyBytes;
  }

  /// Clears the cache (tests).
  @visibleForTesting
  static void clear() => _cache.clear();
}
