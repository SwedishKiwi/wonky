// Journey 6 (specs/11 §1.1, Write part): restore a previous version, then
// undo the restore.
//
//   flutter test integration_test/journey_06_restore_version_undo_test.dart -d macos --run-skipped
@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Given a named version when restoring it and undoing the '
      'restore then the document goes back and forth', (tester) async {
    tester.testTextInput.register();
    final me = await E2eClient.signUp('Vera');
    await launchSignedOut(tester);
    await signInWithUi(tester, email: me.email);

    journeyStep('first draft + named version');
    await createDocumentWithUi(tester);
    final doc = openDocumentUuid(tester);
    await focusEditor(tester);
    await typeInEditor(tester, 'First draft.');
    await pumpUntilTrue(
      tester,
      () async => (await me.documentText(doc)).startsWith('First draft.'),
      reason: 'the first draft on the server',
    );
    final named = await services(tester).dispatcher.invoke(
      'shell.versions.nameCurrent',
      args: {'name': 'Draft 1'},
    );
    expect(named.isOk, isTrue, reason: '$named');
    final versionId = (named.data! as Map)['versionId'] as int;

    journeyStep('second draft');
    await typeInEditor(tester, ' Second thoughts.');
    await pumpUntilTrue(
      tester,
      () async => (await me.documentText(doc)).contains('Second thoughts.'),
      reason: 'the second draft on the server',
    );

    journeyStep('restore');
    await runCommand(
      tester,
      'shell.versions.restore',
      args: {'versionId': versionId, 'confirmed': true},
    );
    await pumpUntilTrue(
      tester,
      () async => (await me.documentText(doc)).trim() == 'First draft.',
      reason: 'the restored version on the server',
    );

    journeyStep('undo the restore');
    await pumpUntilTrue(
      tester,
      () => services(tester).undo.canUndo.value,
      reason: 'the restore to be undoable',
    );
    await runCommand(tester, 'shell.edit.undo');
    await pumpUntilTrue(
      tester,
      () async => (await me.documentText(doc)).contains('Second thoughts.'),
      reason: 'the undone restore on the server',
    );
    await pumpUntil(
      tester,
      find.textContaining('Second thoughts.', findRichText: true),
      reason: 'the undone restore in the editor',
    );

    me.close();
    await endJourney(tester);
  });
}
