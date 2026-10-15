import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets/config/sheets_app_config.dart';
import 'package:wonky_sheets/l10n/sheets_l10n.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart' show WonkyMenuItem;

void main() {
  late CommandTestHarness h;

  setUp(() {
    h = CommandTestHarness(config: const SheetsAppConfig());
    h.services.router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    );
  });
  tearDown(() => h.dispose());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await pumpWonky(
      tester,
      child,
      size: const Size(1440, 900),
      extraDelegates: const [
        WonkyAppLocalizations.delegate,
        SheetsLocalizations.delegate,
      ],
      wrap: (context, child) =>
          Provider<ShellServices>.value(value: h.services, child: child!),
    );
    await tester.pumpAndSettle();
  }

  test('Given Sheets (v2) then its home is scoped to spreadsheets with the '
      'app-home menu and the /new and /import routes (04 §12, D-16)', () {
    const config = SheetsAppConfig();
    expect(config.homeScope, const HomeScope.kind(DriveItemKind.spreadsheet));
    expect(config.homeNav, HomeNavSpec.appHome);
    expect(config.homeScope!.newKinds, [DriveItemKind.spreadsheet]);
    expect(config.homeScope!.showsTypeFilter, isFalse);
    expect(config.newItemRoute, isNotNull);
    expect(config.importRoute, isNotNull);
  });

  testWidgets('Given the Sheets home when My files shows then only '
      'spreadsheets and folders containing spreadsheets are listed', (
    tester,
  ) async {
    h.drive.seed(name: 'Budget', kind: DriveItemKind.spreadsheet);
    h.drive.seed(name: 'Plan');
    final data = h.drive.seed(name: 'Data', kind: DriveItemKind.folder);
    h.drive.seed(
      name: 'Sales',
      kind: DriveItemKind.spreadsheet,
      parentUuid: data.uuid,
    );
    final docs = h.drive.seed(name: 'Docs', kind: DriveItemKind.folder);
    h.drive.seed(name: 'Notes', parentUuid: docs.uuid);

    await pump(
      tester,
      DriveHomeScreen(
        services: h.services,
        location: const DriveLocation.myDrive(),
      ),
    );

    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Plan'), findsNothing);
    expect(find.text('Docs'), findsNothing);
    await settleTooltips(tester);
  });

  testWidgets('Given an empty Sheets home then the empty state names Wonky '
      'Sheets and spreadsheets', (tester) async {
    await pump(
      tester,
      DriveHomeScreen(
        services: h.services,
        location: const DriveLocation.myDrive(),
      ),
    );

    expect(find.text('Welcome to Wonky Sheets'), findsOneWidget);
    expect(
      find.text('Create a spreadsheet or open one shared with you.'),
      findsOneWidget,
    );
    await settleTooltips(tester);
  });

  testWidgets('Given the Sheets home New menu then it offers Spreadsheet, '
      'From template and Import file…', (tester) async {
    late BuildContext ctx;
    await pump(
      tester,
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    );

    final labels = [
      for (final e in homeNewMenuEntries(ctx, h.services))
        if (e is WonkyMenuItem) e.label,
    ];

    expect(labels, ['Spreadsheet', 'From template…', 'Import file…']);
  });

  test('Given the Sheets editor when New ▸ Presentation runs then Wonky '
      'Slides opens its /new route in this tab', () async {
    await h.invoke('shell.file.new', {'kind': 'presentation'});

    expect(h.crossApp.opened, [(WonkyAppKind.slides, '/new')]);
  });
}
