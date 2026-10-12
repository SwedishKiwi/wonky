import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/src/drive/drive_location.dart';
import 'package:wonky_app/src/drive/home_screen.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';

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
  });
  tearDown(() => h.dispose());

  Future<void> pumpHome(WidgetTester tester) async {
    await pumpWonky(
      tester,
      DriveHomeScreen(
        services: h.services,
        location: const DriveLocation.myDrive(),
      ),
      size: const Size(1440, 900),
      extraDelegates: const [WonkyAppLocalizations.delegate],
      wrap: (context, child) =>
          Provider<ShellServices>.value(value: h.services, child: child!),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Given the drive list when a row is selected then the rows do '
      'not move', (tester) async {
    final a = h.drive.seed(name: 'Alpha');
    h.drive.seed(name: 'Beta');
    await pumpHome(tester);
    final row = find.byKey(ValueKey<String>('drive.item.${a.uuid.uuid}'));
    final before = tester.getTopLeft(row);

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('drive.selectionBar')),
      findsOneWidget,
    );
    expect(tester.getTopLeft(row), before);
    await settleTooltips(tester);
  });

  testWidgets('Given the drive list when double-clicking a row then the '
      'document opens', (tester) async {
    final a = h.drive.seed(name: 'Alpha');
    await pumpHome(tester);
    final row = find.byKey(ValueKey<String>('drive.item.${a.uuid.uuid}'));

    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      h.services.router.routeInformationProvider.value.uri.path,
      '/d/${a.uuid.uuid}',
    );
    await settleTooltips(tester);
  });
}
