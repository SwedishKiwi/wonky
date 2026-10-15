import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

import 'support/storage_pump.dart';

/// The storage meter of the left menu (D-11, Drive 03 §6.1): text, colors,
/// "Calculating storage…", over quota, opening the Storage page, keyboard,
/// light/dark, 360 px and en_XA.
void main() {
  late CommandTestHarness h;
  tearDown(() => h.dispose());

  Widget meter({bool large = false}) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 240,
      child: StorageMeter(
        services: h.services,
        large: large,
        onOpen: () => h.services.dispatcher.invoke('shell.storage.open'),
      ),
    ),
  );

  Color barColor(WidgetTester tester) =>
      tester.widget<ShadProgress>(find.byType(ShadProgress)).color!;

  ShadColorScheme scheme(WidgetTester tester) =>
      ShadTheme.of(tester.element(find.byType(StorageMeter))).colorScheme;

  for (final b in Brightness.values) {
    group('Given ${b.name} mode', () {
      testWidgets('when 12.3 MB of 50 MB are used then the meter says so in '
          'the primary color', (tester) async {
        h = storageHarness(storage: FakeStorage.used((12.3 * mb).round()));
        await pumpWithShell(tester, h, meter(), brightness: b);

        expect(find.text('12.3 MB of 50 MB used'), findsOneWidget);
        expect(barColor(tester), scheme(tester).primary);
      });

      testWidgets('when 46.1 MB are used (≥ 90 %) then the bar is in the '
          'warning color', (tester) async {
        h = storageHarness(storage: FakeStorage.used((46.1 * mb).round()));
        await pumpWithShell(tester, h, meter(), brightness: b);

        expect(find.text('46.1 MB of 50 MB used'), findsOneWidget);
        expect(barColor(tester), scheme(tester).warning);
      });

      testWidgets('when over quota then the meter says "over quota" in the '
          'destructive color', (tester) async {
        h = storageHarness(storage: FakeStorage.used((50.4 * mb).round()));
        await pumpWithShell(tester, h, meter(), brightness: b);

        expect(find.text('50.4 MB of 50 MB used — over quota'), findsOneWidget);
        expect(barColor(tester), scheme(tester).destructive);
      });
    });
  }

  group('Given the storage meter', () {
    testWidgets('when the usage is unknown then nothing is shown', (
      tester,
    ) async {
      h = storageHarness(storage: FakeStorage());
      await pumpWithShell(tester, h, meter());

      expect(find.byType(ShadProgress), findsNothing);
      expect(find.textContaining('used'), findsNothing);
    });

    testWidgets('when the backfill is calculating then the bar is '
        'indeterminate with "Calculating storage…"', (tester) async {
      h = storageHarness(storage: FakeStorage.used(3 * mb, calculating: true));
      await pumpWithShell(tester, h, meter());

      expect(find.text('Calculating storage…'), findsOneWidget);
      expect(
        tester.widget<ShadProgress>(find.byType(ShadProgress)).value,
        isNull,
      );
    });

    testWidgets('when a storageChanged event arrives then the meter updates '
        'live', (tester) async {
      final storage = FakeStorage.used(10 * mb);
      h = storageHarness(storage: storage);
      await pumpWithShell(tester, h, meter());

      storage.emit(FakeStorage.usageOf(20 * mb));
      await tester.pump();

      expect(find.text('20.0 MB of 50 MB used'), findsOneWidget);
    });

    testWidgets('when clicked in Write then Drive\'s Storage page opens', (
      tester,
    ) async {
      h = storageHarness(storage: FakeStorage.used(10 * mb));
      await pumpWithShell(tester, h, meter());

      await tester.tap(find.byType(StorageMeter));
      await tester.pumpAndSettle();

      expect(h.crossApp.opened, [(WonkyAppKind.drive, '/storage')]);
      await settleTooltips(tester);
    });

    testWidgets('when focused and Enter is pressed then the Storage page '
        'opens', (tester) async {
      h = storageHarness(storage: FakeStorage.used(10 * mb));
      await pumpWithShell(tester, h, meter());

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(h.crossApp.opened, [(WonkyAppKind.drive, '/storage')]);
      await settleTooltips(tester);
    });

    testWidgets('when it is read by a screen reader then the label, the '
        'value and the percentage are announced', (tester) async {
      final semantics = tester.ensureSemantics();
      h = storageHarness(storage: FakeStorage.used((12.3 * mb).round()));
      await pumpWithShell(tester, h, meter());

      expect(
        tester.getSemantics(find.byKey(const ValueKey('storage.meter'))),
        matchesSemantics(
          label: 'Storage',
          value: '12.3 MB of 50 MB used, 25 percent',
          hint: 'Storage is shared by Wonky Drive, Write, Sheets and Slides.',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('when the value is the offline cache then the tooltip says '
        '"(offline)"', (tester) async {
      final storage = FakeStorage.used(10 * mb)..stale = true;
      h = storageHarness(storage: storage);
      await pumpWithShell(tester, h, meter());

      final s = tester.getSemantics(
        find.byKey(const ValueKey('storage.meter')),
      );
      expect(s.hint, endsWith('(offline)'));
    });

    testWidgets('when large (Storage page) then the bar is 8 px', (
      tester,
    ) async {
      h = storageHarness(storage: FakeStorage.used(10 * mb));
      await pumpWithShell(tester, h, meter(large: true));

      expect(
        tester.widget<ShadProgress>(find.byType(ShadProgress)).minHeight,
        8,
      );
    });

    testWidgets('when 360 px wide in en_XA then the text wraps without '
        'overflow', (tester) async {
      h = storageHarness(storage: FakeStorage.used((50.4 * mb).round()));
      await pumpWithShell(
        tester,
        h,
        SizedBox(
          width: 200,
          child: StorageMeter(services: h.services, onOpen: () {}),
        ),
        size: const Size(360, 640),
        locale: pseudoLocale,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('[50.4 MB öƒ 50 MB ûšéð — öṽéŕ ǫûöţå one tw]'),
        findsOneWidget,
      );
    });
  });
}
