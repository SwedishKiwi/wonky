import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_server/src/platform/ai/ai_config.dart';
import 'package:wonky_server/src/platform/ai/anthropic/fake_anthropic_client.dart';
import 'package:wonky_server/src/platform/common/models.dart';

import '../../../support/test_drive.dart';
import '../../../support/test_users.dart';
import '../../../support/wonky_serverpod.dart';

void main() {
  late FakeAnthropicClient fake;

  setUp(() {
    fake = FakeAnthropicClient();
    AiConfig.current = AiConfig(apiKey: 'test-key');
    AiConfig.clientOverride = fake;
  });
  tearDown(() => AiConfig.clientOverride = null);

  withWonkyServerpod('Given a document and inline AI', (
    sessionBuilder,
    endpoints,
  ) {
    late TestUser anna;
    late DriveItemView doc;

    setUp(() async {
      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      doc = await TestDrive.document(
        endpoints,
        anna,
        markdown:
            '# Notes\n\nTeh quick brown fox jumpd over the dog.\n\n'
            '## Ideas\n\nWe should ship it.\n',
      );
    });

    test(
      'when a selection is rewritten then the preview streams and the '
      'final Markdown is cleaned',
      () async {
        fake.enqueue(
          (SseScript()..text('```markdown\nThe quick brown fox jumped.\n```'))
              .response,
        );
        final events = await endpoints.assistant
            .inline(
              anna.endpointSession,
              InlineAiRequest(
                itemUuid: doc.uuid,
                action: 'shorter',
                selectedMarkdown: 'Teh quick brown fox jumpd over the dog.',
                contextAfter: '## Ideas',
              ),
            )
            .toList();
        expect(events.first.type, InlineAiEventType.textDelta);
        expect(events.last.type, InlineAiEventType.done);
        expect(events.last.markdown, 'The quick brown fox jumped.');
        final req = fake.requests.single;
        expect((req['output_config'] as Map)['effort'], 'medium');
        expect(req.containsKey('tools'), isFalse);
        final text =
            (((req['messages'] as List).single as Map)['content'] as List)
                    .single
                as Map;
        expect(text['text'], contains('<selection>Teh quick'));
        expect(text['text'], contains('shorter'));
      },
    );

    test('when refining then the previous output is a prior turn', () async {
      fake.enqueue((SseScript()..text('Formal text.')).response);
      await endpoints.assistant
          .inline(
            anna.endpointSession,
            InlineAiRequest(
              itemUuid: doc.uuid,
              action: 'improve',
              selectedMarkdown: 'We should ship it.',
              previousOutput: 'Let us ship it.',
              instruction: 'more formal',
            ),
          )
          .toList();
      final messages = fake.requests.single['messages'] as List;
      expect(messages.map((m) => (m as Map)['role']), [
        'user',
        'assistant',
        'user',
      ]);
    });

    test('when the model refuses then nothing can be inserted', () async {
      fake.enqueue((SseScript()..stop('refusal')).response);
      final events = await endpoints.assistant
          .inline(
            anna.endpointSession,
            InlineAiRequest(
              itemUuid: doc.uuid,
              action: 'improve',
              selectedMarkdown: 'x',
            ),
          )
          .toList();
      expect(events.last.type, InlineAiEventType.refusal);
    });

    test('when continuing then the text before the caret is the context', () async {
      fake.enqueue((SseScript()..text(' And then it slept.')).response);
      final events = await endpoints.assistant
          .inline(
            anna.endpointSession,
            InlineAiRequest(itemUuid: doc.uuid, action: 'continueWriting', start: 30),
          )
          .toList();
      expect(events.last.markdown, ' And then it slept.');
      final text = jsonEncode(fake.requests.single['messages']);
      expect(text, contains('text_before_caret'));
      expect(text, isNot(contains('We should ship')));
    });

    test('when summarizing the document then the whole document is sent', () async {
      fake.enqueue((SseScript()..text('- A fox.\n- Shipping.')).response);
      final events = await endpoints.assistant
          .inline(
            anna.endpointSession,
            InlineAiRequest(
              itemUuid: doc.uuid,
              action: 'summarizeDocument',
              summaryLength: 'short',
            ),
          )
          .toList();
      expect(events.last.markdown, '- A fox.\n- Shipping.');
      expect(jsonEncode(fake.requests.single), contains('We should ship it.'));
    });

    test(
      'when proofreading then issues are validated against the document',
      () async {
        fake.enqueue(
          (SseScript()
                ..toolUse('p', 'report_issues', {
                  'issues': [
                    {
                      'quote': 'Teh',
                      'occurrence': 1,
                      'replacement': 'The',
                      'category': 'spelling',
                      'explanation': 'Typo.',
                    },
                    {
                      'quote': 'not in the text',
                      'occurrence': 1,
                      'replacement': 'x',
                      'category': 'grammar',
                      'explanation': 'Invented.',
                    },
                  ],
                })
                ..stop('tool_use'))
              .response,
        );
        final events = await endpoints.assistant
            .proofread(anna.endpointSession, doc.uuid, null, null)
            .toList();
        final issues = events
            .where((e) => e.type == 'issues')
            .expand((e) => e.issues!)
            .toList();
        expect(issues, hasLength(1));
        expect(issues.single.quote, 'Teh');
        expect(issues.single.replacement, 'The');
        expect(issues.single.occurrence, 1);
        expect(events.last.type, 'done');
        final tool = (fake.requests.single['tools'] as List).single as Map;
        expect(tool['name'], 'report_issues');
        expect(tool['strict'], true);
      },
    );

    test('when a viewer asks for a rewrite then it is refused', () async {
      final vic = await TestUsers.create(sessionBuilder, name: 'Vic');
      await TestDrive.share(endpoints, doc, anna, vic, AccessRole.viewer);
      await expectLater(
        endpoints.assistant
            .inline(
              vic.endpointSession,
              InlineAiRequest(itemUuid: doc.uuid, action: 'improve'),
            )
            .toList(),
        throwsA(isA<WonkyException>()),
      );
    });
  });
}
