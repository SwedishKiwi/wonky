// Journey 2 (specs/11 §1.1): two users co-edit the same paragraph; the
// edits converge and each user undoes only their own edits. The second user
// is a scripted client on the collaboration protocol (specs/15 §9).
//
//   flutter test integration_test/journey_02_co_edit_undo_test.dart -d macos --run-skipped
@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wonky_client/wonky_client.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Given two editors in one paragraph when both type and the app '
      'user undoes then only their own text goes away', (tester) async {
    tester.testTextInput.register();
    final ann = await E2eClient.signUp('Ann');
    final bo = await E2eClient.signUp('Bob');
    await launchSignedOut(tester);
    await signInWithUi(tester, email: ann.email);
    await createDocumentWithUi(tester);
    final doc = openDocumentUuid(tester);
    await ann.share(doc, bo.email, AccessRole.editor);

    journeyStep('Ann types');
    await focusEditor(tester);
    await typeInEditor(tester, 'Alpha ');
    await pumpUntilTrue(
      tester,
      () async => (await ann.documentText(doc)).startsWith('Alpha '),
      reason: "Ann's text on the server",
    );

    journeyStep('Bo appends in the same paragraph');
    await bo.submitOp(
      doc,
      (length) => [
        {'retain': length},
        {'insert': 'Bravo'},
      ],
    );
    await pumpUntil(
      tester,
      find.textContaining('Alpha Bravo', findRichText: true),
      reason: "Bo's text in Ann's editor",
    );
    expect((await bo.documentText(doc)).trim(), 'Alpha Bravo');

    journeyStep('Ann undoes');
    await runCommand(tester, 'shell.edit.undo');
    await pumpUntilTrue(
      tester,
      () async => (await bo.documentText(doc)).trim() == 'Bravo',
      reason: "only Ann's text to be undone",
    );
    await pumpUntil(
      tester,
      find.textContaining('Bravo', findRichText: true),
      reason: 'the converged text in the editor',
    );
    expect(find.textContaining('Alpha', findRichText: true), findsNothing);

    ann.close();
    bo.close();
    await endJourney(tester);
  });
}
