import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/src/drive/drive_location.dart';
import 'package:wonky_app/src/drive/home_screen.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

import '../support/screen_pump.dart';

void main() {
  late CommandTestHarness h;

  setUp(() {
    h = CommandTestHarness();
    h.services.router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/d/:uuid', builder: (_, _) => const SizedBox()),
      ],
    );
    h.drive.seed(name: 'Projects', kind: DriveItemKind.folder);
    h.drive.seed(name: 'Quarterly plan', starred: true);
    h.drive.seed(name: 'Budget', kind: DriveItemKind.spreadsheet);
  });
  tearDown(() => h.dispose());

  Widget home() => DriveHomeScreen(
    services: h.services,
    location: const DriveLocation.myDrive(),
  );

  for (final b in Brightness.values) {
    testWidgets('Given the drive in ${b.name} when it shows then text has '
        'enough contrast and every tap target is labeled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, h, home(), brightness: b);

      await expectAccessible(tester);
      semantics.dispose();
    });

    testWidgets('Given a selected row in ${b.name} when the selection bar '
        'shows then its actions are labeled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, h, home(), brightness: b);
      await tester.tap(find.text('Quarterly plan'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('drive.selectionBar')),
        findsOneWidget,
      );
      await expectAccessible(tester);
      await settleTooltips(tester);
      semantics.dispose();
    });
  }

  for (final size in const [Size(1440, 900), Size(800, 700)]) {
    testWidgets('Given the en_XA pseudo-locale at ${size.width.round()} px '
        'when the drive shows then nothing overflows', (tester) async {
      await pumpScreen(tester, h, home(), locale: pseudoLocale, size: size);

      // Overflows are reported as test failures by the framework.
      expect(find.textContaining('['), findsWidgets);
    });
  }
}
