import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/src/auth/screens/auth_layout.dart';
import 'package:wonky_app/src/auth/screens/sign_in_screen.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';

void main() {
  late FakeAuthRepository auth;
  late CommandTestHarness h;
  setUp(() {
    auth = FakeAuthRepository(signedIn: false);
    h = CommandTestHarness(auth: auth);
  });
  tearDown(() => h.dispose());

  Future<void> pump(WidgetTester tester) => pumpWonky(
    tester,
    SignInScreen(services: h.services),
    extraDelegates: const [WonkyAppLocalizations.delegate],
    wrap: (context, child) =>
        Provider<ShellServices>.value(value: h.services, child: child!),
  );

  final google = find.byKey(const ValueKey('auth.google'));

  group('Given Google sign-in is offered', () {
    setUp(() => auth.offersGoogleSignIn = true);

    testWidgets('when continuing with Google then the user is signed in', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('or'), findsOneWidget);

      await tester.tap(google);
      await tester.pumpAndSettle();

      expect(h.services.auth.status, AuthStatus.signedIn);
    });

    testWidgets('when the popup is closed then nothing happens', (
      tester,
    ) async {
      auth.googleOutcome = false;
      await pump(tester);

      await tester.tap(google);
      await tester.pumpAndSettle();

      expect(h.services.auth.status, AuthStatus.signedOut);
      expect(find.byType(AuthErrorBanner), findsNothing);
    });

    testWidgets('when the server has no Google client then an error says so', (
      tester,
    ) async {
      auth.googleOutcome = null;
      await pump(tester);

      await tester.tap(google);
      await tester.pumpAndSettle();

      expect(h.services.auth.status, AuthStatus.signedOut);
      expect(
        find.text("Sign in with Google isn't set up on this server."),
        findsOneWidget,
      );
    });
  });

  testWidgets('Given Google sign-in is not offered then there is no Google '
      'button', (tester) async {
    await pump(tester);

    expect(google, findsNothing);
    expect(find.text('or'), findsNothing);
  });
}
