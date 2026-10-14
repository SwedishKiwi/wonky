import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_server/src/platform/cluster/cluster_bus.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/sheets/headless/headless_workbook_provider.dart';
import 'package:wonky_server/src/sheets/mcp/sheets_bulk_writer.dart';
import 'package:wonky_server/src/sheets/mcp/sheets_mcp_support.dart';
import 'package:wonky_server/src/sheets/sync/sheets_sync_service.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput;
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    as core
    show CellInput;

import '../../../support/mcp_harness.dart';
import '../../../support/sheets_fixtures.dart';
import '../../../support/test_users.dart';
import '../../../support/wonky_serverpod.dart';

void main() {
  withWonkyServerpod('Given a cached headless workbook', (
    sessionBuilder,
    endpoints,
  ) {
    late TestUser anna;
    late McpHarness mcp;
    late String ss;
    late UuidValue space;

    setUp(() async {
      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      mcp = await McpHarness.forUser(anna);
      ss = await SheetsFixtures.create(
        mcp,
        sheets: {
          'Data': [
            ['a', 1],
          ],
        },
      );
      final (item, _) = await SheetsMcp.resolveItem(
        anna.session,
        mcp.ctx,
        ss,
        min: Role.viewer,
      );
      space = item.contentRef!;
      // Warm the cache.
      await SheetsFixtures.read(mcp, ss, 'Data!A1');
    });
    tearDown(() {
      HeadlessWorkbookProvider.clear();
      HeadlessWorkbookProvider.recheckAfter = const Duration(seconds: 60);
      HeadlessWorkbookProvider.budgetBytes = 2048 * 1024 * 1024;
    });

    /// Writes [text] into Data!A1 like another client would: straight to
    /// the synced tables, without touching the cache.
    Future<void> writeBehindTheCache(String text, {bool signal = true}) async {
      final wb = HeadlessWorkbookProvider.peek(space)!;
      final s = wb.model.sheetByName('Data')!;
      final plan = const SheetsMutationPlanner().plan(
        SetCellInputs(
          sheetId: s.id,
          row: 0,
          col: 0,
          inputs: [
            [core.CellInput.user(text)],
          ],
        ),
        wb.model,
        PlanContext(
          userId: anna.authUserId.uuid,
          now: clock.now().toUtc(),
          formulas: wb.hooks,
        ),
      );
      await SheetsBulkWriter.apply(
        anna.session,
        actor: anna.actor,
        spaceUuid: space,
        changes: plan.changes,
        label: 'Client edit',
        plans: [plan],
      );
      if (signal) {
        await ClusterBus.post(
          anna.session,
          SheetsSyncService.mergedChannel(space),
          SheetsMergedSignal(spaceUuid: space, hlc: 'client'),
        );
      }
    }

    test(
      'when a merge is signaled then the next read is patched, not reloaded',
      () async {
        final loads = HeadlessWorkbookProvider.loads;
        final patches = HeadlessWorkbookProvider.peek(space)!.patches;
        await writeBehindTheCache('from a client');
        expect(HeadlessWorkbookProvider.peek(space)!.stale, isTrue);
        expect(await SheetsFixtures.read(mcp, ss, 'Data!A1'), [
          ['from a client'],
        ]);
        expect(HeadlessWorkbookProvider.loads, loads);
        expect(HeadlessWorkbookProvider.peek(space)!.patches, patches + 1);
      },
    );

    test(
      'when nothing signals but the entry is due for a re-check then it is '
      'patched',
      () async {
        await writeBehindTheCache('silent', signal: false);
        expect(await SheetsFixtures.read(mcp, ss, 'Data!A1'), [
          ['a'],
        ]);
        HeadlessWorkbookProvider.recheckAfter = Duration.zero;
        expect(await SheetsFixtures.read(mcp, ss, 'Data!A1'), [
          ['silent'],
        ]);
      },
    );

    test('when the instance writes itself then no patch is needed', () async {
      final patches = HeadlessWorkbookProvider.peek(space)!.patches;
      await mcp.call('sheets.set_values', {
        'spreadsheet': ss,
        'range': 'Data!A1',
        'values': [
          ['tool'],
        ],
      });
      expect(HeadlessWorkbookProvider.peek(space)!.stale, isFalse);
      expect(await SheetsFixtures.read(mcp, ss, 'Data!A1'), [
        ['tool'],
      ]);
      expect(HeadlessWorkbookProvider.peek(space)!.patches, patches);
    });

    test(
      'when a revert deletes cells then the patched model drops them',
      () async {
        final w = await mcp.call('sheets.set_values', {
          'spreadsheet': ss,
          'range': 'Data!C3',
          'values': [
            ['temp'],
          ],
        });
        await mcp.call('changes.revert', {'change_id': w['change_id']});
        expect(await SheetsFixtures.read(mcp, ss, 'Data!C3'), isEmpty);
      },
    );

    test(
      'when the memory budget is exceeded then the LRU entry is evicted',
      () async {
        final other = await SheetsFixtures.create(mcp, name: 'Other');
        HeadlessWorkbookProvider.budgetBytes = 1;
        await SheetsFixtures.read(mcp, other, 'A1');
        expect(HeadlessWorkbookProvider.peek(space), isNull);
        expect(HeadlessWorkbookProvider.cachedSpaces, hasLength(1));
      },
    );
  });
}
