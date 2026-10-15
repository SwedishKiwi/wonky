@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import '../../support/screen_pump.dart';

/// Goldens of the left menu (`HomeSidebar`) and a scoped home in light and
/// dark (D-10, Drive 04 §15 AC-D4.7). Masters are made and compared on CI
/// Linux only (specs/15 §7): run locally with `-x golden`.
void main() {
  late CommandTestHarness h;
  tearDown(() => h.dispose());

  void setUpHarness(WonkyAppKind app, HomeScope scope) {
    h = CommandTestHarness(
      config: TestAppConfig(app: app, scope: scope),
      storage: FakeStorage.used((12.3 * 1024 * 1024).round()),
    );
    h.services.router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    );
    final folder = h.drive.seed(name: 'Team', kind: DriveItemKind.folder);
    h.drive.seed(name: 'Q3 planning', parentUuid: folder.uuid);
    h.drive.seed(name: 'Notes', starred: true);
    h.drive.seed(name: 'Budget 2026', kind: DriveItemKind.spreadsheet);
  }

  for (final b in Brightness.values) {
    for (final (name, app, scope) in [
      ('drive', WonkyAppKind.drive, const HomeScope.all()),
      (
        'write',
        WonkyAppKind.write,
        const HomeScope.kind(DriveItemKind.document),
      ),
    ]) {
      testWidgets('home sidebar $name ${b.name}', (tester) async {
        setUpHarness(app, scope);
        await pumpScreen(
          tester,
          h,
          SizedBox(
            width: HomeSidebar.width,
            height: 760,
            child: HomeSidebar(
              services: h.services,
              location: const DriveLocation.myDrive(),
            ),
          ),
          brightness: b,
          size: const Size(HomeSidebar.width, 760),
        );
        await expectLater(
          find.byType(HomeSidebar),
          matchesGoldenFile('home_sidebar_${name}_${b.name}.png'),
        );
      });

      testWidgets('scoped home $name ${b.name}', (tester) async {
        setUpHarness(app, scope);
        await pumpScreen(
          tester,
          h,
          DriveHomeScreen(
            services: h.services,
            location: const DriveLocation.myDrive(),
          ),
          brightness: b,
        );
        await expectLater(
          find.byType(DriveHomeScreen),
          matchesGoldenFile('scoped_home_${name}_${b.name}.png'),
        );
      });
    }
  }
}
