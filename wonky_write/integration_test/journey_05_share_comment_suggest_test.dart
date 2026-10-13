// Journey 5 (specs/11 §1.1): share with a commenter; the commenter comments
// and suggests; the owner accepts the suggestion. The owner uses the app,
// the commenter is a scripted second client (specs/15 §9).
//
//   flutter test integration_test/journey_05_share_comment_suggest_test.dart -d macos --run-skipped
@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wonky_client/wonky_client.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Given a shared document when the commenter comments and '
      'suggests then the owner sees both and accepts the suggestion', (
    tester,
  ) async {
    tester.testTextInput.register();
    final owner = await E2eClient.signUp('Olga');
    final bo = await E2eClient.signUp('Bo');
    await launchSignedOut(tester);
    await signInWithUi(tester, email: owner.email);

    journeyStep('owner writes and shares');
    await createDocumentWithUi(tester);
    final doc = openDocumentUuid(tester);
    await focusEditor(tester);
    await typeInEditor(tester, 'The fox jumps.');
    await pumpUntilTrue(
      tester,
      () async => (await owner.documentText(doc)).startsWith('The fox jumps.'),
      reason: 'the owner text on the server',
    );
    await owner.share(doc, bo.email, AccessRole.commenter);

    journeyStep('commenter comments');
    final thread = await bo.client.comment.createThread(
      const Uuid().v7obj(),
      doc,
      CommentAnchorKind.document,
      '{"v":1}',
      null,
      'Nice opening, maybe a bit short?',
      [],
      null,
    );
    expect(thread.comments.single.body, 'Nice opening, maybe a bit short?');

    journeyStep('commenter suggests');
    const suggestionId = 'e2e-quick';
    await bo.submitOp(
      doc,
      (_) => [
        {'retain': 4},
        {
          'insert': 'quick ',
          'attributes': {
            'sug_$suggestionId': {
              't': 'ins',
              'by': bo.profile.summary.uuid.uuid,
              'at': DateTime.now().millisecondsSinceEpoch,
            },
          },
        },
      ],
    );
    await pumpUntil(
      tester,
      find.textContaining('The quick fox jumps.', findRichText: true),
      reason: 'the suggestion in the owner editor',
    );

    journeyStep('owner accepts');
    await runCommand(
      tester,
      'write.suggestions.accept',
      args: {
        'suggestionIds': [suggestionId],
      },
    );
    await pumpUntilTrue(tester, () async {
      final delta = await owner.documentDelta(doc);
      final text = [
        for (final op in delta)
          if (op['insert'] is String) op['insert'],
      ].join();
      final pending = delta.any(
        (op) => (op['attributes'] as Map? ?? const {}).keys.any(
          (k) => '$k'.startsWith('sug_'),
        ),
      );
      return text.startsWith('The quick fox jumps.') && !pending;
    }, reason: 'the accepted suggestion on the server');

    // The commenter's comment reached the owner too.
    final threads = await owner.client.comment.listThreads(
      doc,
      CommentFilter.all,
    );
    expect(
      threads.expand((t) => t.comments).map((c) => c.body),
      contains('Nice opening, maybe a bit short?'),
    );

    owner.close();
    bo.close();
    await endJourney(tester);
  });
}
