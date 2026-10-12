import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/src/auth/screens/sign_up_screen.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';

void main() {
  late CommandTestHarness h;
  setUp(() => h = CommandTestHarness());
  tearDown(() => h.dispose());

  testWidgets('Given sign-up errors when editing a field then its error '
      'goes away', (tester) async {
    await pumpWonky(
      tester,
      SignUpScreen(services: h.services),
      extraDelegates: const [WonkyAppLocalizations.delegate],
      wrap: (context, child) =>
          Provider<ShellServices>.value(value: h.services, child: child!),
    );
    await tester.tap(find.byKey(const ValueKey('auth.signUp.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
    final before = find.text('Required').evaluate().length;

    await tester.enterText(
      find.byKey(const ValueKey('auth.signUp.name')),
      'Anna',
    );
    await tester.pumpAndSettle();

    expect(find.text('Required').evaluate().length, before - 1);
    await settleTooltips(tester);
  });
}
