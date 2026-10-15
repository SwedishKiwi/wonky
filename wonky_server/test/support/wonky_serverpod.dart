import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    hide Protocol;
import 'package:test/test.dart';
import 'package:wonky_server/server.dart' show registerVersionProviders;
import 'package:wonky_server/src/generated/sync_tables.dart';
import 'package:wonky_server/src/sheets/sync/sheets_sync_service.dart';
import 'package:wonky_server/src/slides/slides_server.dart';
import 'package:wonky_server/src/slides/sync/slides_sync_service.dart';
import 'package:wonky_server/src/write/ot/document_cache.dart';
import 'package:wonky_server/src/write/themes/theme_service.dart';

import '../integration/test_tools/serverpod_test_tools.dart';

export '../integration/test_tools/serverpod_test_tools.dart';

/// [withServerpod] with the Wonky runtime pieces the server installs at
/// start: the offline-sync engine, version providers, database cloud
/// storage and the built-in themes.
///
/// The database is not rolled back between tests (sync and OT code run
/// their own transactions); tests stay isolated by using fresh users.
@isTestGroup
void withWonkyServerpod(
  String testGroupName,
  TestClosure<TestEndpoints> testClosure, {
  String? runMode,
}) {
  withServerpod(
    testGroupName,
    (sessionBuilder, endpoints) {
      setUpAll(() async {
        final session = sessionBuilder.build();
        final pod = session.serverpod;
        pod.initializeOfflineSync(syncTables: syncTables);
        if (pod.storage['private'] == null) {
          pod.addCloudStorage(DatabaseCloudStorage('private'));
        }
        if (pod.storage['public'] == null) {
          pod.addCloudStorage(DatabaseCloudStorage('public'));
        }
        registerVersionProviders();
        SheetsSyncService.processInline = true;
        SlidesSyncService.processInline = true;
        SlidesServer.ensureRegistered();
        await ThemeService.upsertBuiltins(session);
      });
      tearDownAll(DocumentCache.clear);
      testClosure(sessionBuilder, endpoints);
    },
    rollbackDatabase: RollbackDatabase.disabled,
    runMode: runMode,
  );
}
