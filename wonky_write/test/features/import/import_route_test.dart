import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_write/features/import/import_route.dart';

/// `drive.convertFile` of the `/import` route, recorded.
class _FakeApi implements WriteDriveFileApi {
  _FakeApi(this.h);

  final CommandTestHarness h;
  final List<UuidValue> converted = [];
  Object? error;

  @override
  Future<ImportReportView> convert(UuidValue fileItemUuid) async {
    converted.add(fileItemUuid);
    final e = error;
    if (e != null) throw e;
    final file = h.drive.item(fileItemUuid);
    final doc = h.drive.seed(
      name: file.name.substring(0, file.name.lastIndexOf('.')),
      parentUuid: file.parentUuid,
    );
    return ImportReportView(item: doc, warnings: const []);
  }
}

/// A drive whose items carry a size and upload state ([sized]).
class _Drive extends FakeDriveRepository {
  final Map<UuidValue, DriveItemView> sized = {};

  @override
  Future<DriveItemView> get(UuidValue uuid) async =>
      sized[uuid] ?? super.get(uuid);
}

void main() {
  late CommandTestHarness h;
  late _FakeApi api;
  late _Drive drive;

  setUp(() {
    drive = _Drive();
    h = CommandTestHarness(drive: drive, storage: FakeStorage.used(0));
    api = _FakeApi(h);
    WriteDriveFileApi.install(h.services, api);
  });
  tearDown(() => h.dispose());

  Future<UuidValue?> run(UuidValue file) => importDriveFileAsDocument(
    _NoContext(),
    h.services,
    ImportRouteRequest(fileItemUuid: file),
  );

  group('Given a Word file in Drive (Open with ▸ Wonky Write)', () {
    test('when the import route runs then the server converts it and the '
        'new document is returned', () async {
      final folder = h.drive.seed(name: 'Docs', kind: DriveItemKind.folder);
      final file = h.drive.seed(
        name: 'Plan.docx',
        kind: DriveItemKind.file,
        parentUuid: folder.uuid,
      );

      final uuid = await run(file.uuid);

      expect(api.converted, [file.uuid]);
      final doc = h.drive.item(uuid!);
      expect(doc.kind, DriveItemKind.document);
      expect(doc.name, 'Plan');
      expect(doc.parentUuid, folder.uuid);
    });

    test('when the user is offline then the route explains it and converts '
        'nothing', () async {
      final file = h.drive.seed(name: 'Plan.md', kind: DriveItemKind.file);
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
      expect(api.converted, isEmpty);
    });

    test(
      'when the file is still uploading then the route explains it',
      () async {
        final file = h.drive.seed(name: 'Plan.md', kind: DriveItemKind.file);
        drive.sized[file.uuid] = file.copyWith(
          uploadState: FileUploadState.uploading,
        );

        await expectLater(run(file.uuid), throwsA(isA<ImportRouteProblem>()));
        expect(api.converted, isEmpty);
      },
    );

    test('when the storage is full then the pre-check refuses it before '
        'the server converts anything', () async {
      (h.services.storage as FakeStorage).value = FakeStorage.usageOf(
        50 * 1024 * 1024,
      );
      final file = h.drive.seed(name: 'Big.docx', kind: DriveItemKind.file);
      drive.sized[file.uuid] = file.copyWith(sizeBytes: 2 * 1024 * 1024);

      expect(await run(file.uuid), isNull);
      expect(api.converted, isEmpty);
    });

    test('when the server refuses it on quota then the route ends quietly '
        '(the Out of storage dialog explains it)', () async {
      final file = h.drive.seed(name: 'Plan.docx', kind: DriveItemKind.file);
      api.error = FakeStorage.quotaError(neededBytes: 1024);

      expect(await run(file.uuid), isNull);
      expect(api.converted, [file.uuid]);
    });
  });

  group('Given an item that Write cannot import', () {
    test('when it is a photo then the route names the file', () async {
      final file = h.drive.seed(name: 'photo.png', kind: DriveItemKind.file);

      await expectLater(
        run(file.uuid),
        throwsA(
          isA<ImportRouteProblem>().having(
            (p) => p.message,
            'message',
            'Wonky Write can\'t open “photo.png”.',
          ),
        ),
      );
      expect(api.converted, isEmpty);
    });

    test('when it is a document already then it is opened as it is', () async {
      final doc = h.drive.seed(name: 'Plan');

      expect(await run(doc.uuid), doc.uuid);
      expect(api.converted, isEmpty);
    });

    test('when it is a folder then the route explains it', () async {
      final folder = h.drive.seed(name: 'Docs', kind: DriveItemKind.folder);

      await expectLater(run(folder.uuid), throwsA(isA<ImportRouteProblem>()));
    });
  });

  group('Given the /import route page', () {
    Future<void> pumpRoute(
      WidgetTester tester,
      String location, {
      bool settle = true,
    }) async {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Text('home', textDirection: TextDirection.ltr),
          ),
          GoRoute(
            path: '/d/:uuid',
            builder: (_, st) => Text(
              'doc ${st.pathParameters['uuid']}',
              textDirection: TextDirection.ltr,
            ),
          ),
          GoRoute(
            path: '/import',
            builder: (_, st) => ImportRoutePage(
              services: h.services,
              handler: importDriveFileAsDocument,
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
        extraDelegates: const [WonkyAppLocalizations.delegate],
        wrap: (context, child) =>
            Provider<ShellServices>.value(value: h.services, child: child!),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        for (var k = 0; k < 5; k++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
    }

    testWidgets('when it imports a Markdown file then the new document opens '
        'in place of the route', (tester) async {
      final file = h.drive.seed(name: 'Notes.md', kind: DriveItemKind.file);

      await pumpRoute(tester, '/import?file=${file.uuid.uuid}');

      final doc = h.drive.items.singleWhere(
        (i) => i.kind == DriveItemKind.document,
      );
      expect(find.text('doc ${doc.uuid.uuid}'), findsOneWidget);
    });

    testWidgets('when the import fails then the app stays and shows its home '
        'with the error', (tester) async {
      final file = h.drive.seed(name: 'photo.png', kind: DriveItemKind.file);
      h.crossApp.hasHistory = true;

      await pumpRoute(tester, '/import?file=${file.uuid.uuid}');

      expect(find.text('home'), findsOneWidget);
      expect(h.crossApp.historyBacks, 0);
    });

    testWidgets('when the Out of storage dialog ends the import then the '
        'browser goes back to Drive', (tester) async {
      final file = h.drive.seed(name: 'Plan.docx', kind: DriveItemKind.file);
      api.error = FakeStorage.quotaError(neededBytes: 1024);
      h.crossApp.hasHistory = true;

      // The dialog (no navigator context in the harness) closes at once;
      // the fake browser history keeps this page (its spinner) shown.
      await pumpRoute(tester, '/import?file=${file.uuid.uuid}', settle: false);

      expect(h.crossApp.historyBacks, 1);
    });
  });
}

/// The handler only passes its context to dialogs it doesn't open here.
class _NoContext implements BuildContext {
  @override
  bool get mounted => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
