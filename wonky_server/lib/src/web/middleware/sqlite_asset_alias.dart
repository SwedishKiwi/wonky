import 'dart:io';

import 'package:serverpod/serverpod.dart';

/// Serves an app's `sqlite3.wasm` and `db_worker.js` for nested paths
/// below the app (specs/01-architecture.md §2.4).
///
/// sqlite3_web resolves `sqlite3.wasm` against the page URL when it opens a
/// database in the page itself (when its worker failed): a page at
/// `/sheets/s/<id>` then asks for `/sheets/s/sqlite3.wasm`, the SPA fallback
/// answered with `index.html` ("Incorrect response MIME type") and the
/// local replica could not open. The URIs come from `sqlite_async`'s
/// defaults inside `serverpod_database`, so they can't be made absolute.
Middleware sqliteAssetAlias(String app, Directory appDir) =>
    (next) => (req) {
      final segments = req.url.pathSegments.where((s) => s.isNotEmpty);
      final name = segments.isEmpty ? '' : segments.last;
      final rel = segments.skipWhile((s) => s == app).toList();
      if (rel.length > 1 && aliasedSqliteAssets.containsKey(name)) {
        final file = File(Uri(path: '${appDir.path}/$name').toFilePath());
        if (file.existsSync()) {
          return Response.ok(
            body: Body.fromData(
              file.readAsBytesSync(),
              mimeType: aliasedSqliteAssets[name],
            ),
          );
        }
      }
      return next(req);
    };

/// The files [sqliteAssetAlias] serves, with their types.
const aliasedSqliteAssets = <String, MimeType>{
  'sqlite3.wasm': MimeType('application', 'wasm'),
  'db_worker.js': MimeType.javascript,
};
