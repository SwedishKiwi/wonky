import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/config/sheets_app_config.dart';
import 'package:wonky_sheets/features/import/drive_file_import.dart';
import 'package:wonky_sheets/l10n/sheets_l10n.dart';
import 'package:wonky_sheets_core/model.dart' show ImportLocation;
import 'package:wonky_ui/testing.dart';

/// The Drive file bytes and `drive.convertFile` of the route, recorded.
class _FakeApi implements DriveFileImportApi {
  _FakeApi(this.h);

  final CommandTestHarness h;
  final List<UuidValue> downloaded = [];
  final List<(UuidValue, DriveImportOptions)> converted = [];
  Uint8List bytes = Uint8List.fromList(utf8.encode('a;b\n1;2\n3;4\n'));
  Object? error;

  @override
  Future<Uint8List> download(UuidValue fileItemUuid) async {
    downloaded.add(fileItemUuid);
    return bytes;
  }

  @override
  Future<ImportReportView> convert(
    UuidValue fileItemUuid,
    DriveImportOptions options,
  ) async {
    converted.add((fileItemUuid, options));
    final e = error;
    if (e != null) throw e;
    final file = h.drive.item(fileItemUuid);
    final sheet = h.drive.seed(
      name: file.name.substring(0, file.name.lastIndexOf('.')),
      kind: DriveItemKind.spreadsheet,
      parentUuid: file.parentUuid,
    );
    return ImportReportView(item: sheet, warnings: const []);
  }
}

/// A drive whose items carry an upload state ([views]).
class _Drive extends FakeDriveRepository {
  final Map<UuidValue, DriveItemView> views = {};

  @override
  Future<DriveItemView> get(UuidValue uuid) async =>
      views[uuid] ?? super.get(uuid);
}

/// The handler only shows dialogs on the route page (widget tests below).
class _NoContext implements BuildContext {
  @override
  bool get mounted => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late CommandTestHarness h;
  late _FakeApi api;
  late _Drive drive;

  setUp(() {
    drive = _Drive();
    h = CommandTestHarness(
      config: const SheetsAppConfig(),
      drive: drive,
      storage: FakeStorage.used(0),
    );
    api = _FakeApi(h);
    DriveFileImportApi.install(h.services, api);
  });
  tearDown(() => h.dispose());

  Future<UuidValue?> run(UuidValue file) => importDriveFileAsSpreadsheet(
    _NoContext(),
    h.services,
    ImportRouteRequest(fileItemUuid: file),
  );

  group('Given an item Sheets cannot import (Open with ▸ Wonky Sheets)', () {
    test('when the user is offline then the route explains it', () async {
      final file = h.drive.seed(name: 'orders.csv', kind: DriveItemKind.file);
      h.services.connectivity.forceOffline(true);

      await expectLater(
        run(file.uuid),
        throwsA(
          isA<ImportRouteProblem>().having(
            (p) => p.message,
            'message',
            contains("You're offline"),
          ),
        ),
      );
      expect(api.downloaded, isEmpty);
    });

    test('when it is a legacy .xls file then the route says so', () async {
      final file = h.drive.seed(name: 'old.xls', kind: DriveItemKind.file);

      await expectLater(
        run(file.uuid),
        throwsA(
          isA<ImportRouteProblem>().having(
            (p) => p.message,
            'message',
            contains('Legacy .xls'),
          ),
        ),
      );
    });

    test('when it is a Word file then the route names the file', () async {
      final file = h.drive.seed(name: 'Plan.docx', kind: DriveItemKind.file);

      await expectLater(
        run(file.uuid),
        throwsA(
          isA<ImportRouteProblem>().having(
            (p) => p.message,
            'message',
            'Wonky Sheets can\'t open “Plan.docx”.',
          ),
        ),
      );
      expect(api.downloaded, isEmpty);
    });

    test('when the file is still uploading then the route says so', () async {
      final file = h.drive.seed(name: 'orders.csv', kind: DriveItemKind.file);
      drive.views[file.uuid] = file.copyWith(
        uploadState: FileUploadState.uploading,
      );

      await expectLater(run(file.uuid), throwsA(isA<ImportRouteProblem>()));
    });

    test('when it is a spreadsheet already then it opens as it is', () async {
      final sheet = h.drive.seed(
        name: 'Budget',
        kind: DriveItemKind.spreadsheet,
      );

      expect(await run(sheet.uuid), sheet.uuid);
      expect(api.downloaded, isEmpty);
    });

    test('when the storage is full then the pre-check refuses it before '
        'anything is loaded', () async {
      (h.services.storage as FakeStorage).value = FakeStorage.usageOf(
        50 * 1024 * 1024,
      );
      final file = h.drive.seed(name: 'orders.csv', kind: DriveItemKind.file);
      drive.views[file.uuid] = file.copyWith(sizeBytes: 3 * 1024 * 1024);

      expect(await run(file.uuid), isNull);
      expect(api.downloaded, isEmpty);
      expect(api.converted, isEmpty);
    });
  });

  group('Given a CSV file in Drive and the /import route', () {
    Future<void> pumpRoute(WidgetTester tester, UuidValue file) async {
      final router = GoRouter(
        initialLocation: '/import?file=${file.uuid}',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/s/:uuid',
            builder: (_, st) => Text('sheet ${st.pathParameters['uuid']}'),
          ),
          GoRoute(
            path: '/import',
            builder: (_, st) => ImportRoutePage(
              services: h.services,
              handler: importDriveFileAsSpreadsheet,
              request: ImportRouteRequest.fromQuery(st.uri.queryParameters),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      h.services.router = router;
      await pumpWonky(
        tester,
        Router.withConfig(config: router),
        size: const Size(1200, 900),
        extraDelegates: const [
          WonkyAppLocalizations.delegate,
          SheetsLocalizations.delegate,
        ],
        wrap: (context, child) =>
            Provider<ShellServices>.value(value: h.services, child: child!),
      );
      // Download, dialog and CSV analysis.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('when the import dialog is confirmed then the server imports '
        'the stored file as a new spreadsheet with the chosen options and it '
        'opens', (tester) async {
      final folder = h.drive.seed(name: 'Data', kind: DriveItemKind.folder);
      final file = h.drive.seed(
        name: 'orders.csv',
        kind: DriveItemKind.file,
        parentUuid: folder.uuid,
      );

      await pumpRoute(tester, file.uuid);

      expect(find.byKey(const ValueKey('dialog.import')), findsOneWidget);
      expect(api.downloaded, [file.uuid]);
      // Only *Create new spreadsheet*: nothing is open to import into, and
      // the Drive file can't be swapped for another one (D-18: *Change file*
      // was offered, but the server converts the Drive file).
      for (final loc in ImportLocation.values) {
        expect(
          find.byKey(ValueKey('dialog.import.loc.${loc.name}')),
          loc == ImportLocation.createNew ? findsOneWidget : findsNothing,
          reason: loc.name,
        );
      }
      expect(find.byKey(const ValueKey('dialog.import.change')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('dialog.import.confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.converted, hasLength(1));
      final (uuid, options) = api.converted.single;
      expect(uuid, file.uuid);
      final json = jsonDecode(options.optionsJson!) as Map<String, dynamic>;
      expect(json['location'], 'createNew');
      final sheet = h.drive.items.singleWhere(
        (i) => i.kind == DriveItemKind.spreadsheet,
      );
      expect(sheet.name, 'orders');
      expect(sheet.parentUuid, folder.uuid);
      await tester.pumpAndSettle();
      expect(find.text('sheet ${sheet.uuid.uuid}'), findsOneWidget);
    });

    testWidgets('when the import dialog is cancelled then nothing is imported '
        'and the browser goes back to Drive', (tester) async {
      final file = h.drive.seed(name: 'orders.csv', kind: DriveItemKind.file);
      h.crossApp.hasHistory = true;

      await pumpRoute(tester, file.uuid);
      await tester.tap(find.byKey(const ValueKey('dialog.import.cancel')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(api.converted, isEmpty);
      expect(h.crossApp.historyBacks, 1);
    });
  });
}
