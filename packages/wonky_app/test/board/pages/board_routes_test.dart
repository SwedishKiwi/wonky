import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/auth/screens/sign_in_screen.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';

import 'support/board_pump.dart';

/// The board routes are public (specs/16 §4.3, §15 Router): signed-out
/// visitors reach `/improvements…`; every other route still redirects.
void main() {
  BoardTest? current;
  BoardTest t() => current!;
  tearDown(() async {
    await current?.dispose();
    current = null;
  });

  Future<void> signedOut(WidgetTester tester, String location) async {
    final board = FakeBoardRepository()..seedPost(title: 'Public idea');
    current = await pumpBoard(tester, location, board: board, signedIn: false);
  }

  for (final path in const [
    '/improvements',
    '/improvements/bugs',
    '/improvements/tasks',
    '/improvements/done',
    '/improvements/contribute',
    '/improvements/p/1',
  ]) {
    testWidgets('Given a signed-out visitor when $path opens then it is '
        'shown without sign-in', (tester) async {
      await signedOut(tester, path);

      expect(t().location, path);
      expect(find.byType(SignInScreen), findsNothing);
      await settleTooltips(tester);
    });
  }

  testWidgets('Given a signed-out visitor when a task page opens then it is '
      'public too', (tester) async {
    final board = FakeBoardRepository()..seedTask(title: 'Open task');
    current = await pumpBoard(
      tester,
      '/improvements/t/1',
      board: board,
      signedIn: false,
    );

    expect(t().location, '/improvements/t/1');
    expect(find.text('Open task'), findsOneWidget);
    await settleTooltips(tester);
  });

  for (final path in const ['/', '/recent', '/settings/account']) {
    testWidgets('Given a signed-out visitor when $path opens then it still '
        'redirects to sign-in', (tester) async {
      await signedOut(tester, path);

      expect(t().location, startsWith('/signin'));
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  }

  testWidgets('Given the board signed out when Sign in is pressed then '
      'sign-in comes back to the board', (tester) async {
    await signedOut(tester, '/improvements/bugs');

    await tester.tap(byKey('board.signIn'));
    await tester.pumpAndSettle();

    expect(t().location, '/signin?next=%2Fimprovements%2Fbugs');
  });

  testWidgets('Given sign-in from the board when the visitor creates an '
      'account instead then sign-up and verification keep the target and '
      'land on the board', (tester) async {
    await signedOut(tester, '/signin?next=%2Fimprovements');
    final auth = t().h.services.auth.repository as FakeAuthRepository;

    await tester.tap(byKey('auth.signIn.createAccount'));
    await tester.pumpAndSettle();
    expect(t().location, '/signup?next=%2Fimprovements');

    await tester.enterText(byKey('auth.signUp.name'), 'Cleo');
    await tester.enterText(byKey('auth.signUp.email'), 'cleo@example.test');
    await tester.enterText(byKey('auth.signUp.password'), 'Correct-Horse-42!');
    await tester.tap(byKey('auth.signUp.terms'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(byKey('auth.signUp.submit'));
    await tester.tap(byKey('auth.signUp.submit'));
    await tester.pumpAndSettle();
    expect(t().location, '/signup/verify?next=%2Fimprovements');

    await t().h.services.auth.verifySignUp(auth.lastCode!);
    await tester.pumpAndSettle();

    expect(t().location, '/improvements');
    await settleTooltips(tester);
  });

  testWidgets('Given a next target that leaves the app when signing up then '
      'it is dropped', (tester) async {
    await signedOut(tester, '/signin?next=%2F%2Fevil.example');

    await tester.tap(byKey('auth.signIn.createAccount'));
    await tester.pumpAndSettle();

    expect(t().location, '/signup');
    await settleTooltips(tester);
  });

  testWidgets('Given a page visited before the board when Back is pressed '
      'on a post then the last non-board route opens', (tester) async {
    final board = FakeBoardRepository()..seedPost();
    current = await pumpBoard(tester, '/recent', board: board);
    for (final l in ['/recent', '/improvements', '/improvements/p/1']) {
      t().s.recordLocation(l);
    }
    await t().go(tester, '/improvements/p/1');

    await tester.tap(byKey('shell.page.back'));
    await tester.pumpAndSettle();

    expect(t().location, '/recent');
    await settleTooltips(tester);
  });

  test('isBoardLocation matches the board routes only', () {
    expect(isBoardLocation('/improvements'), isTrue);
    expect(isBoardLocation('/improvements/p/3'), isTrue);
    expect(isBoardLocation('/improvements?x=1'), isTrue);
    expect(isBoardLocation('/improvementsx'), isFalse);
    expect(isBoardLocation('/settings/account'), isFalse);
  });
}
