// Journey 8 (specs/11 §1.1, Write part, partial): an MCP client creates a
// document with `drive.create_document` and edits it with
// `write.insert_markdown` over `/mcp`; the app shows the result.
// (`ui.invoke_command` through the UI bridge is not covered yet.)
//
//   flutter test integration_test/journey_08_mcp_test.dart -d macos --run-skipped
@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wonky_client/wonky_client.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Given an MCP client with a token when it creates and edits a '
      'document then the app opens it with that content', (tester) async {
    final me = await E2eClient.signUp('Mia');
    final mcp = E2eMcp(await me.createMcpToken());
    await mcp.initialize();

    journeyStep('MCP creates and edits');
    final created = await mcp.call('drive.create_document', {
      'name': 'Agent notes $runId',
      'markdown': '# Agent notes\n\nWritten over MCP.',
    });
    final uuid = UuidValue.fromString(
      ((created['item'] as Map)['uuid']) as String,
    );
    await mcp.call('write.insert_markdown', {
      'document_uuid': uuid.uuid,
      'markdown': 'Second paragraph from the agent.',
      'at': {'type': 'end'},
    });
    expect(
      await me.documentText(uuid),
      contains('Second paragraph from the agent.'),
    );

    journeyStep('the app shows it');
    await launchSignedOut(tester);
    await signInWithUi(tester, email: me.email);
    services(tester).router.go('/d/${uuid.uuid}');
    await waitForEditor(tester);
    await pumpUntil(
      tester,
      find.textContaining(
        'Second paragraph from the agent.',
        findRichText: true,
      ),
      reason: 'the MCP edit in the editor',
    );
    expect(
      find.textContaining('Written over MCP.', findRichText: true),
      findsOneWidget,
    );

    mcp.close();
    me.close();
    await endJourney(tester);
  });
}
