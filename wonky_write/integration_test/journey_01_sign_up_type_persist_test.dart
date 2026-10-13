// Journey 1 (specs/11 §1.1): sign up → verify → create a document → type
// with formatting → reload → the content persists.
//
// Run against `serverpod start`:
//   flutter test integration_test/journey_01_sign_up_type_persist_test.dart -d macos
@Tags(['e2e'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Given a new user when they sign up, write a formatted '
      'sentence and reopen the document then it persists', (tester) async {
    tester.testTextInput.register();
    await launchSignedOut(tester);
    final email = e2eEmail('ada');

    journeyStep('signing up');
    // Sign up.
    await tester.tap(
      find.byKey(const ValueKey<String>('auth.signIn.createAccount')),
    );
    await pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('auth.signUp.submit')),
    );
    await enterField(tester, 'auth.signUp.name', 'Ada E2E');
    await enterField(tester, 'auth.signUp.email', email);
    await enterField(tester, 'auth.signUp.password', e2ePassword);
    await tester.tap(find.byKey(const ValueKey<String>('auth.signUp.terms')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('auth.signUp.submit')));

    // Verify with the code the server recorded for the address.
    await pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('auth.verify.code')),
      reason: 'the verification screen',
    );
    final code = await E2eClient.verificationCode(
      services(tester).client!,
      email,
    );
    await enterField(tester, 'auth.verify.code', code);
    await pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('shell.notifications')),
      timeout: const Duration(seconds: 45),
      reason: 'the home screen after verifying',
    );

    journeyStep('creating a document');
    // Create a document and type "Hello **world**".
    await createDocumentWithUi(tester);
    final docUuid = openDocumentUuid(tester);
    await focusEditor(tester);
    await typeInEditor(tester, 'Hello ');
    await runCommand(tester, 'write.format.bold');
    await typeInEditor(tester, 'world');

    journeyStep('checking the server');
    // The server has it (ops are sent within ~2 s).
    final other = await E2eClient.signIn(email);
    await pumpUntilTrue(
      tester,
      () async => (await other.documentText(docUuid)).startsWith('Hello world'),
      reason: 'the text to reach the server',
    );
    final delta = await other.documentDelta(docUuid);
    expect(
      delta,
      contains(
        allOf(
          containsPair('insert', 'world'),
          containsPair('attributes', containsPair('bold', true)),
        ),
      ),
    );

    journeyStep('reopening');
    // "Reload": back to the drive and open the document again.
    services(tester).router.go('/');
    await pumpUntil(tester, find.byKey(const ValueKey<String>('drive.new')));
    services(tester).router.go('/d/${docUuid.uuid}');
    await waitForEditor(tester);
    await pumpUntil(
      tester,
      find.textContaining('Hello world', findRichText: true),
      reason: 'the persisted text in the editor',
    );
    other.close();
    await endJourney(tester);
  });
}
