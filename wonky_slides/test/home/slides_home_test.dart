import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

import '../support/slides_harness.dart';

/// The Slides home (Slides 04 §15, suite 03 §3.3): the shell's app home
/// scoped to presentations, with the app-home left menu.
void main() {
  late CommandTestHarness h;

  setUp(() {
    h = slidesHarness();
    h.services.router = GoRouter(
      routes: [
        for (final p in const [
          '/',
          '/my-files',
          '/my-drive',
          '/shared',
          '/starred',
          '/offline',
          '/trash',
          '/f/:uuid',
          '/p/:uuid',
          '/templates',
          '/settings/app',
          '/settings/:section',
        ])
          GoRoute(path: p, builder: (_, _) => const SizedBox()),
      ],
    );
  });
  tearDown(() => h.dispose());

  /// My files with a presentation, a document, a spreadsheet, an image, a
  /// folder with a presentation and a folder with only a document.
  void seed() {
    h.drive.seed(name: 'Pitch', kind: DriveItemKind.presentation);
    h.drive.seed(name: 'Plan');
    h.drive.seed(name: 'Budget', kind: DriveItemKind.spreadsheet);
    h.drive.seed(
      name: 'photo.png',
      kind: DriveItemKind.file,
      fileCategory: FileCategory.image,
    );
    final decks = h.drive.seed(name: 'Decks', kind: DriveItemKind.folder);
    h.drive.seed(
      name: 'Q3 review',
      kind: DriveItemKind.presentation,
      parentUuid: decks.uuid,
    );
    final docs = h.drive.seed(name: 'Docs', kind: DriveItemKind.folder);
    h.drive.seed(name: 'Notes', parentUuid: docs.uuid);
  }

  Widget home([DriveLocation location = const DriveLocation.myDrive()]) =>
      DriveHomeScreen(services: h.services, location: location);

  Finder key(String k) => find.byKey(ValueKey<String>(k));

  for (final brightness in Brightness.values) {
    group('Given the Slides home in the ${brightness.name} theme', () {
      testWidgets('when My files shows then only presentations and the '
          'folders containing presentations are listed', (tester) async {
        seed();

        await pumpSlides(tester, h, home(), brightness: brightness);

        expect(find.text('Pitch'), findsOneWidget);
        expect(find.text('Decks'), findsOneWidget);
        for (final hidden in ['Plan', 'Budget', 'photo.png', 'Docs']) {
          expect(find.text(hidden), findsNothing, reason: hidden);
        }
        expect(key('drive.filter.type'), findsNothing);
        await settleTooltips(tester);
      });

      testWidgets('when the left menu shows then it has the four apps and '
          'the app-home navigation', (tester) async {
        await pumpSlides(tester, h, home(), brightness: brightness);

        for (final app in WonkyAppKind.values) {
          expect(key('home.app.${app.name}'), findsOneWidget);
        }
        for (final d in [
          'recent',
          'myFiles',
          'shared',
          'starred',
          'offline',
          'trash',
        ]) {
          expect(key('drive.nav.$d'), findsOneWidget, reason: d);
        }
        expect(key('drive.nav.storage'), findsNothing);
        expect(key('drive.nav.tree'), findsNothing);
        await settleTooltips(tester);
      });
    });
  }

  group('Given a user without presentations', () {
    testWidgets('when the Slides home opens then it shows the empty state', (
      tester,
    ) async {
      h.drive.seed(name: 'Plan');

      await pumpSlides(tester, h, home(const DriveLocation.home()));

      expect(find.text('Plan'), findsNothing);
      expect(key('drive.empty'), findsOneWidget);
      await settleTooltips(tester);
    });
  });
}
