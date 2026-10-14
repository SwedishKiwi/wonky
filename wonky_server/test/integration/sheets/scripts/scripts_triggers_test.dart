import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/sheets/headless/headless_workbook_provider.dart';
import 'package:wonky_server/src/sheets/scripts/script_service.dart';
import 'package:wonky_server/src/sheets/scripts/script_triggers.dart';
import 'package:wonky_server/src/sheets/scripts/url_fetch_proxy.dart';
import 'package:wonky_server/src/sheets/sync/sync_db.dart';
import 'package:wonky_sheets_core/model.dart'
    show ChangeSummary, GridRange, ChangeKinds;

import '../../../support/mcp_harness.dart';
import '../../../support/sheets_fixtures.dart';
import '../../../support/test_users.dart';
import '../../../support/wonky_serverpod.dart';
import 'script_support.dart';

const _source = r'''
import 'package:wonky/wonky.dart';

void install() {
  ScriptApp.newTrigger('stamp').timeBased().everyMinutes(5).create();
}

void installEdit() {
  ScriptApp.newTrigger('markEdit').forSpreadsheet().onEdit().create();
}

void stamp(TimeEvent e) {
  SpreadsheetApp.active.sheetByName('Data')!.appendRow(['tick', e.triggerUid]);
}

void markEdit(EditEvent e) {
  e.range.offset(0, 4).value = 'edited ${e.range.a1Notation}';
}

Object? fetchIt(Object? url) => UrlFetchApp.fetch(url as String).contentText;
''';

void main() {
  withWonkyServerpod('Given a script with installable triggers', (
    sessionBuilder,
    endpoints,
  ) {
    late TestUser anna;
    late McpHarness mcp;
    late String ss;
    late DriveItem item;

    setUpAll(enableScripting);
    tearDownAll(disableScripting);

    setUp(() async {
      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      mcp = await McpHarness.forUser(anna);
      ss = await SheetsFixtures.create(
        mcp,
        name: 'Log',
        sheets: {
          'Data': [
            ['Item', 'Amount'],
            ['Rent', 1000],
          ],
        },
      );
      await mcp.call('sheets.update_script_file', {
        'spreadsheet': ss,
        'name': 'main.dart',
        'source': _source,
        'create_if_missing': true,
      });
      item = (await DriveItem.db.findFirstRow(
        anna.session,
        where: (t) => t.uuid.equals(uuidOf(ss)),
      ))!;
    });
    tearDown(HeadlessWorkbookProvider.clear);

    // The build needs both scopes (triggers and fetches); a run needs a
    // grant covering all of them (09 §11.2).
    Future<void> authorize(TestUser u, List<String> scopes) =>
        ScriptService.authorize(u.session, u.actor, uuidOf(ss), [
          ...scopes,
          'script.triggers',
          'external_request',
        ]);

    test('when installing a trigger without the scope then it fails', () async {
      final r = await mcp.error('sheets.run_function', {
        'spreadsheet': ss,
        'function': 'install',
      });
      expect(r['code'], 'authorization_required');
    });

    test(
      'when a time-driven trigger is due then the scheduler runs it as the installer',
      () async {
        await authorize(anna, ['script.triggers']);
        final r = await mcp.call('sheets.run_function', {
          'spreadsheet': ss,
          'function': 'install',
        });
        expect(r['status'], 'completed', reason: '$r');
        final project = await ScriptService.project(
          anna.session,
          item.contentRef!,
        );
        final triggers = await ScriptTrigger.db.find(
          syncSessionOf(anna.session),
          where: (t) => t.projectId.equals(project!.id),
        );
        expect(triggers.single.functionName, 'stamp');

        final session = anna.session;
        await ScriptTriggerService.tick(session);
        final scheduled = (await _states(session, item)).single;
        expect(scheduled.nextRunAt, isNotNull);
        // Make it due now (moving the clock forward would upset the sync
        // engine's hybrid logical clock).
        final state = await _makeDue(session, scheduled);
        final runs = await ScriptTriggerService.tick(session);
        expect(runs, 1);
        expect(await SheetsFixtures.read(mcp, ss, 'Data!A3'), [
          ['tick'],
        ]);
        final ex = await ScriptExecution.db.find(
          session,
          where: (t) =>
              t.kind.equals(ScriptExecutionKind.timeDriven) &
              t.spreadsheetUuid.equals(item.contentRef!),
        );
        expect(ex.single.status, ScriptExecutionStatus.completed);
        final after = (await _states(session, item)).single;
        expect(after.lastStatus, ScriptExecutionStatus.completed);
        expect(after.nextRunAt!.isAfter(state.nextRunAt!), isTrue);
      },
    );

    test(
      'when the installer loses edit access then the trigger is disabled',
      () async {
        final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
        await SheetsFixtures.share(mcp, ss, bo.email, 'editor');
        await authorize(bo, ['script.triggers']);
        final boMcp = await McpHarness.forUser(bo);
        await boMcp.call('sheets.run_function', {
          'spreadsheet': ss,
          'function': 'install',
        });
        await SheetsFixtures.share(mcp, ss, bo.email, 'viewer');
        final session = anna.session;
        await ScriptTriggerService.tick(session);
        await _makeDue(session, (await _states(session, item)).single);
        await ScriptTriggerService.tick(session);
        final after = (await _states(session, item)).single;
        expect(after.disabledReason, contains('no longer has edit access'));
      },
    );

    test(
      'when a user edit syncs then the installable onEdit trigger runs',
      () async {
        await authorize(anna, ['script.triggers']);
        await mcp.call('sheets.run_function', {
          'spreadsheet': ss,
          'function': 'installEdit',
        });
        final model = (await HeadlessWorkbookProvider.open(
          anna.session,
          item.contentRef!,
        )).model;
        final sheet = model.sheetByName('Data')!;
        final summary = ChangeSummary()
          ..kinds.add(ChangeKinds.values)
          ..addRange(
            GridRange(
              sheetId: sheet.id,
              r1: sheet.rows.idAt(1),
              r2: sheet.rows.idAt(1),
              c1: sheet.columns.idAt(1),
              c2: sheet.columns.idAt(1),
            ).toJson(),
          );
        final now = DateTime.now().toUtc();
        final n = await ScriptTriggerService.fireForChange(
          anna.session,
          item,
          ChangeLog(
            spreadsheetId: item.contentRef!,
            userId: anna.authUserId,
            actorKind: ActorKind.user,
            sessionId: 'test',
            label: 'Edit',
            summaryJson: summary.encode(),
            at: now,
            createdAt: now,
          ),
        );
        expect(n, 1);
        expect(await SheetsFixtures.read(mcp, ss, 'Data!F2'), [
          ['edited B2'],
        ]);
      },
    );

    test(
      'when an agent edit syncs then the onEdit trigger does not run by default',
      () async {
        await authorize(anna, ['script.triggers']);
        await mcp.call('sheets.run_function', {
          'spreadsheet': ss,
          'function': 'installEdit',
        });
        final now = DateTime.now().toUtc();
        final n = await ScriptTriggerService.fireForChange(
          anna.session,
          item,
          ChangeLog(
            spreadsheetId: item.contentRef!,
            userId: anna.authUserId,
            actorKind: ActorKind.mcp,
            sessionId: 'test',
            label: 'Edit',
            summaryJson: (ChangeSummary()..kinds.add(ChangeKinds.values))
                .encode(),
            at: now,
            createdAt: now,
          ),
        );
        expect(n, 0);
      },
    );

    group('and a URL to fetch', () {
      late HttpServer server;
      setUp(() async {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((req) async {
          req.response.write('hello from ${req.uri.path}');
          await req.response.close();
        });
        ScriptService.proxyOverride = UrlFetchProxy(
          allowHttp: true,
          lookup: (_) async => [InternetAddress.loopbackIPv4],
          allowedAddressesForTests: {'127.0.0.1'},
          ports: {server.port},
        );
      });
      tearDown(() async {
        ScriptService.proxyOverride = null;
        await server.close(force: true);
      });

      test(
        'when the user authorized network access then server runs can fetch',
        () async {
          await authorize(anna, ['external_request']);
          final r = await mcp.call('sheets.run_function', {
            'spreadsheet': ss,
            'function': 'fetchIt',
            'args': ['http://api.test:${server.port}/rates'],
          });
          expect(r['result'], 'hello from /rates');
          final usage = await ScriptService.usage(anna.session, anna.id);
          expect(usage.urlFetchCalls, 1);
        },
      );

      test(
        'when a client fetches through the endpoint then it needs the grant',
        () async {
          final request = '{"url": "http://api.test:${server.port}/x"}';
          await expectLater(
            endpoints.script.urlFetch(
              anna.endpointSession,
              uuidOf(ss),
              request,
              customFunction: false,
            ),
            throwsA(isA<WonkyException>()),
          );
          await endpoints.script.authorize(anna.endpointSession, uuidOf(ss), [
            'external_request',
          ]);
          final r = await endpoints.script.urlFetch(
            anna.endpointSession,
            uuidOf(ss),
            request,
            customFunction: false,
          );
          expect(r.statusCode, 200);
          expect(r.contentText, 'hello from /x');
        },
      );

      test(
        'when the URL points to a private address then the fetch is blocked',
        () async {
          ScriptService.proxyOverride = UrlFetchProxy(
            lookup: (_) async => [InternetAddress('10.0.0.5')],
          );
          await authorize(anna, ['external_request']);
          final r = await mcp.call('sheets.run_function', {
            'spreadsheet': ss,
            'function': 'fetchIt',
            'args': ['https://intranet.example.com/'],
          });
          expect((r['error'] as Map)['type'], 'UrlFetchException');
          expect((r['error'] as Map)['message'], contains('Blocked'));
        },
      );
    });

    test(
      'when the user reports client executions then they appear in the log',
      () async {
        final n = await endpoints.script.reportExecutions(
          anna.endpointSession,
          uuidOf(ss),
          [
            ScriptExecution(
              uuid: const Uuid().v7obj(),
              spreadsheetUuid: uuidOf(ss),
              functionName: 'menuThing',
              kind: ScriptExecutionKind.menu,
              userId: 0,
              runAsUserId: 0,
              runtime: ScriptRuntimeKind.clientWeb,
              status: ScriptExecutionStatus.completed,
              buildSourceHash: 'h',
              startedAt: DateTime.now().toUtc(),
              durationMs: 120,
              logs: '',
              cellsRead: 1,
              cellsWritten: 2,
              fetchCalls: 0,
            ),
          ],
        );
        expect(n, 1);
        final list = await endpoints.script.executions(
          anna.endpointSession,
          uuidOf(ss),
          limit: 50,
        );
        expect(list.single.functionName, 'menuThing');
        expect(list.single.userId, anna.id);
      },
    );
  });
}

Future<ScriptTriggerState> _makeDue(Session session, ScriptTriggerState s) =>
    ScriptTriggerState.db.updateRow(
      session,
      s.copyWith(
        nextRunAt: DateTime.now().toUtc().subtract(const Duration(seconds: 5)),
      ),
    );

Future<List<ScriptTriggerState>> _states(Session session, DriveItem item) =>
    ScriptTriggerState.db.find(
      session,
      where: (t) => t.spreadsheetUuid.equals(item.contentRef!),
    );
