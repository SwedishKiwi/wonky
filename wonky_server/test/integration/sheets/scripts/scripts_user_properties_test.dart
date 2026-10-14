import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show OfflineSyncSpace;
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/sheets/headless/headless_workbook_provider.dart';
import 'package:wonky_server/src/sheets/sync/sync_db.dart';

import '../../../support/mcp_harness.dart';
import '../../../support/sheets_fixtures.dart';
import '../../../support/test_users.dart';
import '../../../support/wonky_serverpod.dart';
import 'script_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

Object? bump() {
  final p = PropertiesService.userProperties;
  final n = int.parse(p.getProperty('n') ?? '0') + 1;
  p.setProperty('n', '$n');
  return n;
}

Object? forget() {
  PropertiesService.userProperties.deleteProperty('n');
  return PropertiesService.userProperties.getProperty('n');
}
''';

/// `PropertiesService.userProperties` of server runs: `ScriptUserProperty`
/// rows in the run-as user's personal space (Sheets 09 §6.9, A-09-4).
void main() {
  withWonkyServerpod('Given a script that keeps a per-user counter', (
    sessionBuilder,
    endpoints,
  ) {
    late TestUser anna;
    late TestUser bo;
    late McpHarness annaMcp;
    late String ss;

    setUpAll(enableScripting);
    tearDownAll(disableScripting);

    setUp(() async {
      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      annaMcp = await McpHarness.forUser(anna);
      ss = await SheetsFixtures.create(
        annaMcp,
        name: 'Counter',
        sheets: {
          'Data': [
            ['x'],
          ],
        },
      );
      final r = await annaMcp.call('sheets.update_script_file', {
        'spreadsheet': ss,
        'name': 'main.dart',
        'source': _main,
        'create_if_missing': true,
      });
      expect((r['build'] as Map)['status'], 'ok', reason: '$r');
    });
    tearDown(HeadlessWorkbookProvider.clear);

    Future<Object?> run(McpHarness mcp, String fn) async =>
        (await mcp.call('sheets.run_function', {
          'spreadsheet': ss,
          'function': fn,
        }))['result'];

    test('when it runs twice then the value persists between runs in the '
        "user's personal space", () async {
      expect(await run(annaMcp, 'bump'), 1);
      expect(await run(annaMcp, 'bump'), 2);

      final session = sessionBuilder.build();
      final rows = await ScriptUserProperty.db.find(
        syncSessionOf(session),
        where: (t) => t.spreadsheetId.equals(uuidOf(ss)),
      );
      expect(rows.single.key, 'n');
      expect(rows.single.value, '2');
      final space = await OfflineSyncSpace.db.findById(
        session,
        rows.single.spaceId!,
      );
      expect(space?.uuidSpaceId, anna.authUserId);
    });

    test('when another user runs it then they get their own value', () async {
      await run(annaMcp, 'bump');
      await run(annaMcp, 'bump');
      await SheetsFixtures.share(annaMcp, ss, bo.email, 'editor');
      final boMcp = await McpHarness.forUser(bo);

      expect(await run(boMcp, 'bump'), 1);
      expect(await run(annaMcp, 'bump'), 3);
    });

    test('when the property is deleted then it is gone', () async {
      await run(annaMcp, 'bump');

      expect(await run(annaMcp, 'forget'), isNull);
      expect(await run(annaMcp, 'bump'), 1);
    });
  });
}
