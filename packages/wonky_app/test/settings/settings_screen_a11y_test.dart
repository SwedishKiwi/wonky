import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/src/settings/settings_catalog.dart';
import 'package:wonky_app/src/settings/settings_screen.dart';

import '../support/screen_pump.dart';

void main() {
  late CommandTestHarness h;

  setUp(() {
    h = CommandTestHarness();
    h.services.router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        GoRoute(
          path: '/settings/:section',
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
  });
  tearDown(() => h.dispose());

  // Every Wonky Work section (suite 04 §4.1).
  const sections = workSettingsSectionIds;

  // Contrast failures of the shared theme (wonky_ui), not of the screens.
  const themeContrastIssues = <String>{};

  for (final b in Brightness.values) {
    for (final section in sections) {
      testWidgets('Given Settings › $section in ${b.name} when it shows then '
          'text has enough contrast and every tap target is labeled', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpScreen(
          tester,
          h,
          SettingsScreen(services: h.services, section: section),
          brightness: b,
        );

        expect(
          find.byKey(ValueKey<String>('settings.section.$section')),
          findsOneWidget,
        );
        await expectAccessible(
          tester,
          contrast: !themeContrastIssues.contains('$section/${b.name}'),
        );
        semantics.dispose();
      });
    }
  }

  for (final section in sections) {
    testWidgets('Given the en_XA pseudo-locale when Settings › $section '
        'shows then nothing overflows', (tester) async {
      await pumpScreen(
        tester,
        h,
        SettingsScreen(services: h.services, section: section),
        locale: pseudoLocale,
        size: const Size(1024, 768),
      );

      // Overflows are reported as test failures by the framework.
      expect(find.textContaining('['), findsWidgets);
    });
  }
}
