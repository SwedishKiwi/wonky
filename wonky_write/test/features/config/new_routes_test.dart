import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart' show WonkyMenuItem;
import 'package:wonky_write/config/write_app_config.dart';
import 'package:wonky_write/config/write_menus.dart';

void main() {
  late CommandTestHarness h;

  setUp(() => h = CommandTestHarness(config: const WriteAppConfig()));
  tearDown(() => h.dispose());

  group('Given File › New in the Write editor (Write 05 §7.1, v2)', () {
    test('when listing it then Document, Spreadsheet, Presentation and From '
        'template are offered', () {
      final menus = writeMenus(
        ShellMenus(lookupWonkyAppLocalizations(const Locale('en'))),
      );
      final file = menus.children.first as MenuSubmenu;
      final newMenu =
          file.children.firstWhere((c) => c.effectiveId == ShellMenuIds.fileNew)
              as MenuSubmenu;

      expect(
        [for (final c in newMenu.children) c.effectiveId],
        [
          'file.new.document',
          'file.new.spreadsheet',
          'file.new.presentation',
          'shell.file.newFromTemplate',
        ],
      );
      final presentation =
          newMenu.children[2] as MenuCommand; // Opens Wonky Slides.
      expect(presentation.commandId, 'shell.file.new');
      expect(presentation.args, {'kind': 'presentation'});
    });

    test('when New ▸ Presentation runs then Wonky Slides opens its /new '
        'route in this tab', () async {
      final r = await h.invoke('shell.file.new', {'kind': 'presentation'});

      expect(r.status, CommandStatus.ok);
      expect(h.crossApp.opened, [(WonkyAppKind.slides, '/new')]);
    });

    test('when New ▸ Spreadsheet runs then Wonky Sheets opens its /new '
        'route in this tab', () async {
      await h.invoke('shell.file.new', {'kind': 'spreadsheet'});

      expect(h.crossApp.opened, [(WonkyAppKind.sheets, '/new')]);
    });
  });

  group('Given the /new route of Write (suite 03 §2)', () {
    Future<void> pumpRoute(WidgetTester tester, String location) async {
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/d/:uuid',
            builder: (_, st) => Text('doc ${st.pathParameters['uuid']}'),
          ),
          GoRoute(
            path: '/new',
            builder: (_, st) => NewItemRoutePage(
              services: h.services,
              handler: h.services.config.newItemRoute!,
              request: NewItemRequest.fromQuery(st.uri.queryParameters),
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
      await tester.pumpAndSettle();
    }

    testWidgets('when Drive opens /new?folder= then a document is created in '
        'that folder and its editor replaces the route', (tester) async {
      final folder = h.drive.seed(name: 'Docs', kind: DriveItemKind.folder);

      await pumpRoute(tester, '/new?folder=${folder.uuid.uuid}');

      final doc = h.drive.items.singleWhere(
        (i) => i.kind == DriveItemKind.document,
      );
      expect(doc.parentUuid, folder.uuid);
      expect(find.text('doc ${doc.uuid.uuid}'), findsOneWidget);
    });
  });

  group('Given the Write home New menu (suite 05 §3.0)', () {
    testWidgets('when it opens then it offers Document, From template and '
        'Import file…, but no folder or other kinds', (tester) async {
      h.services.router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
      );
      late BuildContext ctx;
      await pumpWonky(
        tester,
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
        extraDelegates: const [WonkyAppLocalizations.delegate],
        wrap: (context, child) =>
            Provider<ShellServices>.value(value: h.services, child: child!),
      );

      final entries = homeNewMenuEntries(ctx, h.services);
      final labels = [
        for (final e in entries)
          if (e is WonkyMenuItem) e.label,
      ];

      expect(labels, ['Document', 'From template…', 'Import file…']);
    });
  });
}
