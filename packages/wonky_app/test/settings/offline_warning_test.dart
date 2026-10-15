import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemView;
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';

import '../support/screen_pump.dart';

class _Provider extends ChangeNotifier implements OfflineDataProvider {
  @override
  String get id => 'sheets';

  @override
  bool? isAvailableOffline(DriveItemView item) => null;

  @override
  OfflineUsage get usage => const OfflineUsage(
    documents: 2,
    warnings: [
      OfflineWarning(
        title: 'Offline storage is limited in this browser',
        description: 'Only about 200,000 cells stay available offline.',
      ),
    ],
  );

  @override
  Future<void> clear() async {}
}

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

  for (final b in Brightness.values) {
    testWidgets('Given an app reports a storage limit (${b.name}), then '
        'Settings › Offline & storage shows it', (tester) async {
      final p = _Provider();
      OfflineStorage.of(h.services).register(p);
      addTearDown(() => OfflineStorage.of(h.services).unregister(p));
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await pumpScreen(
        tester,
        h,
        SettingsScreen(services: h.services, section: 'offline'),
        brightness: b,
      );

      expect(
        find.byKey(const ValueKey<String>('settings.offline.warning.0')),
        findsOneWidget,
      );
      expect(
        find.text('Offline storage is limited in this browser'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
