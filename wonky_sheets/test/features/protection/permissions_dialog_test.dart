import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/protection/protection_dialogs.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;
  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  const editors = [
    ProtectionEditorOption(userId: 'u-bo', label: 'Bo', email: 'bo@x.com'),
    ProtectionEditorOption(userId: 'u-cy', label: 'Cy', email: 'cy@x.com'),
  ];

  Future<Future<ProtectionPermissions?>> open(
    WidgetTester tester, {
    bool dark = false,
    ProtectionPermissions initial = const ProtectionPermissions(
      warningOnly: false,
    ),
  }) async {
    await pumpSheets(
      tester,
      s,
      dark: dark,
      size: const Size(360, 800),
      child: const SizedBox.expand(),
    );
    final context = tester.element(find.byType(SizedBox).first);
    final r = showProtectionPermissionsDialog(
      context,
      sheet: false,
      initial: initial,
      editors: editors,
    );
    await tester.pumpAndSettle();
    return r;
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('Given the permissions dialog ($theme, 360 px) when switching '
        'modes then who/editors only show for Restrict and Custom', (
      tester,
    ) async {
      final result = await open(tester, dark: dark);
      const k = 'dialog.protectionPermissions';
      expect(find.byKey(const ValueKey('$k.who')), findsOneWidget);
      expect(find.byKey(const ValueKey('$k.editor:u-bo')), findsNothing);

      final dialog = s.services.openDialogs.single;
      expect(dialog.setField('who', 'custom'), isTrue);
      await tester.pump();
      expect(find.byKey(const ValueKey('$k.editor:u-bo')), findsOneWidget);
      expect(find.byKey(const ValueKey('$k.add')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('$k.mode.warning')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('$k.who')), findsNothing);
      expect(find.byKey(const ValueKey('$k.add')), findsNothing);
      expect(
        (dialog.describe()['fields']! as List).map((f) => (f as Map)['id']),
        ['mode'],
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('$k.ok')));
      await tester.pumpAndSettle();
      expect((await result)?.warningOnly, isTrue);
    });

    testWidgets('Given the permissions dialog ($theme) when an agent picks '
        'custom editors and an email then the result lists them', (
      tester,
    ) async {
      final result = await open(tester, dark: dark);
      final dialog = s.services.openDialogs.single;

      expect(dialog.setField('who', 'custom'), isTrue);
      await tester.pump();
      expect(dialog.setField('editor:u-cy', true), isTrue);
      expect(dialog.setField('add', 'new@x.com, nope'), isTrue);
      expect(dialog.press('ok'), isTrue);
      await tester.pumpAndSettle();

      final r = (await result)!;
      expect(r.warningOnly, isFalse);
      expect(r.editors, ['u-cy']);
      expect(r.addEmails, ['new@x.com']);
    });
  }
}
