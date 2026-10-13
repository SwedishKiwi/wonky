import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/src/settings/settings_screen.dart';
import 'package:wonky_app/testing.dart';

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

  Widget screen() =>
      SettingsScreen(services: h.services, section: 'notifications');

  testWidgets('Given Settings › Notifications when it shows then every '
      'category and the digest switch are listed', (tester) async {
    await pumpScreen(tester, h, screen());

    for (final k in [
      'mentions',
      'replies',
      'shares',
      'accessRequests',
      'suggestions',
      'digest',
    ]) {
      expect(
        find.byKey(ValueKey<String>('settings.notifications.$k')),
        findsOneWidget,
        reason: k,
      );
    }
  });

  testWidgets('Given the digest switch when turning it off then the '
      'preference is saved', (tester) async {
    await pumpScreen(tester, h, screen());

    final digest = find.byKey(
      const ValueKey<String>('settings.notifications.digest'),
    );
    await tester.ensureVisible(digest);
    await tester.tap(digest);
    await tester.pumpAndSettle();

    expect(h.services.prefs.notificationSettings['digest'], isFalse);
    final saved = await h.users.getPreferences();
    expect(
      jsonDecode(saved.notificationSettings),
      containsPair('digest', false),
    );
  });

  for (final b in Brightness.values) {
    testWidgets('Given Settings › Notifications in ${b.name} then it is '
        'accessible', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, h, screen(), brightness: b);

      await expectAccessible(tester);
      semantics.dispose();
    });
  }
}
