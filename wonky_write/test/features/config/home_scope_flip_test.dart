import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_write/config/write_app_config.dart';

Future<CommandTestHarness> _pumpHome(
  WidgetTester tester,
  DriveLocation location, {
  void Function(CommandTestHarness h)? seed,
}) async {
  final h = CommandTestHarness(config: const WriteAppConfig());
  addTearDown(h.dispose);
  h.services.router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
  );
  seed?.call(h);
  await pumpWonky(
    tester,
    DriveHomeScreen(services: h.services, location: location),
    size: const Size(1440, 900),
    extraDelegates: const [WonkyAppLocalizations.delegate],
    wrap: (context, child) =>
        Provider<ShellServices>.value(value: h.services, child: child!),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  test('Given Write (v2) then its home is scoped to documents with the '
      'app-home menu, the documents-only New menu and the /new and /import '
      'routes (suite 03 §3.3, D-16)', () {
    const config = WriteAppConfig();
    expect(config.homeScope, const HomeScope.kind(DriveItemKind.document));
    expect(config.homeNav, HomeNavSpec.appHome);
    expect(config.homeNav.myFilesRoute, '/my-files');
    expect(config.homeScope!.newKinds, [DriveItemKind.document]);
    expect(config.homeScope!.showsTypeFilter, isFalse);
    expect(config.homeScope!.showsTemplateStrip, isTrue);
    expect(config.newItemRoute, isNotNull);
    expect(config.importRoute, isNotNull);
  });

  testWidgets('Given the Write home when My files shows then only documents '
      'and folders containing documents are listed', (tester) async {
    await _pumpHome(
      tester,
      const DriveLocation.myDrive(),
      seed: (h) {
        h.drive.seed(name: 'Plan');
        h.drive.seed(name: 'Budget', kind: DriveItemKind.spreadsheet);
        h.drive.seed(name: 'photo.png', kind: DriveItemKind.file);
        final docs = h.drive.seed(name: 'Docs', kind: DriveItemKind.folder);
        h.drive.seed(name: 'Notes', parentUuid: docs.uuid);
        h.drive.seed(name: 'Empty', kind: DriveItemKind.folder);
      },
    );

    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('photo.png'), findsNothing);
    expect(find.text('Empty'), findsNothing);
    expect(find.text('My files'), findsWidgets);
    await settleTooltips(tester);
  });

  testWidgets('Given an empty Write home then the empty state names Wonky '
      'Write and documents', (tester) async {
    await _pumpHome(tester, const DriveLocation.myDrive());

    expect(find.text('Welcome to Wonky Write'), findsOneWidget);
    expect(
      find.text('Create a document or open one shared with you.'),
      findsOneWidget,
    );
    await settleTooltips(tester);
  });
}
