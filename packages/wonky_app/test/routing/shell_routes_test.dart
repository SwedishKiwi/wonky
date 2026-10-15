import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/routing/router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

import '../support/screen_pump.dart';

/// An app with an `/import` route that "imports" into a fixed new item.
class _ImportingConfig extends TestAppConfig {
  const _ImportingConfig();

  static final imported = UuidValue.fromString(
    '0190a0e0-0000-7000-8000-0000000000aa',
  );

  @override
  ImportRouteHandler? get importRoute =>
      (context, services, request) async => imported;
}

/// The shell routes of D-10 (suite 03 §2): `/f/:uuid` (+ the v1
/// `/drive/:uuid` redirect), `/my-files` ⇄ `/my-drive`, `/new`, `/import`.
/// The settings routes are tested in `test/settings/settings_split_test.dart`.
void main() {
  late CommandTestHarness h;

  Future<void> pumpRouter(
    WidgetTester tester, {
    WonkyAppConfig config = const TestAppConfig(),
    required String initial,
  }) async {
    h = CommandTestHarness(config: config);
    h.services.router = buildShellRouter(h.services);
    await pumpScreen(tester, h, Router.withConfig(config: h.services.router));
    h.services.router.go(initial);
    await tester.pumpAndSettle();
  }

  String location() => h.services.router.state.uri.toString();

  tearDown(() => h.dispose());

  testWidgets('Given a v1 folder link when it opens then it redirects to '
      '/f/:uuid and shows the folder', (tester) async {
    final drive = FakeDriveRepository();
    final folder = drive.seed(name: 'Team', kind: DriveItemKind.folder);
    drive.seed(name: 'Agenda', parentUuid: folder.uuid);
    h = CommandTestHarness(drive: drive);
    h.services.router = buildShellRouter(h.services);
    await pumpScreen(tester, h, Router.withConfig(config: h.services.router));

    h.services.router.go('/drive/${folder.uuid.uuid}');
    await tester.pumpAndSettle();

    expect(location(), '/f/${folder.uuid.uuid}');
    expect(find.byType(DriveHomeScreen), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given an app home when /my-drive opens then it redirects to '
      '/my-files', (tester) async {
    await pumpRouter(
      tester,
      config: const TestAppConfig(
        scope: HomeScope.kind(DriveItemKind.document),
      ),
      initial: '/my-drive',
    );

    expect(location(), '/my-files');
    expect(find.byType(DriveHomeScreen), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given a v1 home or Drive when /my-files opens then it '
      'redirects to /my-drive', (tester) async {
    await pumpRouter(tester, initial: '/my-files');

    expect(location(), '/my-drive');
    await settleTooltips(tester);
  });

  testWidgets('Given an app home in My files when opening it in Drive then '
      'Drive\'s My Drive opens', (tester) async {
    await pumpRouter(
      tester,
      config: const TestAppConfig(
        scope: HomeScope.kind(DriveItemKind.document),
      ),
      initial: '/my-files',
    );

    await h.invoke('shell.nav.openInDrive');
    h.services.router.go('/shared');
    await tester.pumpAndSettle();
    await h.invoke('shell.nav.openInDrive');

    expect(h.crossApp.opened, [
      (WonkyAppKind.drive, '/my-drive'),
      (WonkyAppKind.drive, '/shared'),
    ]);
    await settleTooltips(tester);
  });

  testWidgets('Given /new with a folder when it opens then the item is '
      'created there and its editor replaces the route', (tester) async {
    final drive = FakeDriveRepository();
    final folder = drive.seed(name: 'Team', kind: DriveItemKind.folder);
    h = CommandTestHarness(drive: drive);
    h.services.router = buildShellRouter(h.services);
    await pumpScreen(tester, h, Router.withConfig(config: h.services.router));

    h.services.router.go('/new?folder=${folder.uuid.uuid}');
    await tester.pumpAndSettle();

    final created = h.drive.items.singleWhere(
      (i) => i.kind == DriveItemKind.document,
    );
    expect(created.parentUuid, folder.uuid);
    expect(location(), '/d/${created.uuid.uuid}');
  });

  testWidgets('Given Wonky Drive when /new opens then there is no such '
      'route', (tester) async {
    await pumpRouter(
      tester,
      config: const TestAppConfig(
        app: WonkyAppKind.drive,
        scope: HomeScope.all(),
      ),
      initial: '/new',
    );

    expect(find.byKey(const ValueKey<String>('route.new')), findsNothing);
    expect(find.byType(NotFoundPage), findsOneWidget);
  });

  testWidgets('Given an app with an import route when /import?file= opens '
      'then the imported item opens', (tester) async {
    await pumpRouter(
      tester,
      config: const _ImportingConfig(),
      initial: '/import?file=0190a0e0-0000-7000-8000-000000000001',
    );

    expect(location(), '/d/${_ImportingConfig.imported.uuid}');
  });

  testWidgets('Given an import link without a file when it opens then it '
      'goes home', (tester) async {
    await pumpRouter(
      tester,
      config: const _ImportingConfig(),
      initial: '/import?file=nope',
    );

    expect(location(), '/');
    await settleTooltips(tester);
  });
}
