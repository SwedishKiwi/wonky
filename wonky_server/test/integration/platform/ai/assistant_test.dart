import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_server/src/platform/ai/ai_config.dart';
import 'package:wonky_server/src/platform/ai/ai_usage_service.dart';
import 'package:wonky_server/src/platform/ai/anthropic/fake_anthropic_client.dart';
import 'package:wonky_server/src/platform/ai/assistant_service.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../../support/test_doc_client.dart';
import '../../../support/test_drive.dart';
import '../../../support/test_users.dart';
import '../../../support/wonky_serverpod.dart';

Future<String> _markdown(
  TestEndpoints endpoints,
  TestUser user,
  DriveItemView item,
) async {
  final s = await endpoints.document.getSnapshot(
    user.endpointSession,
    item.contentRef!,
    null,
  );
  return const MarkdownCodec().exportMarkdown(
    Delta.fromJson(jsonDecode(s.deltaJson) as List),
  );
}

AssistantContextHints _hints({
  String? sessionId,
  AiApplyMode mode = AiApplyMode.edit,
  String? selection,
}) => AssistantContextHints(
  documentSessionId: sessionId,
  applyMode: mode,
  selectionText: selection,
  includeComments: false,
);

void main() {
  late FakeAnthropicClient fake;

  setUp(() {
    fake = FakeAnthropicClient();
    AiConfig.current = AiConfig(apiKey: 'test-key', dailyTokenBudget: 1000000);
    AiConfig.clientOverride = fake;
    AssistantService.confirmationTimeout = const Duration(seconds: 20);
  });
  tearDown(() => AiConfig.clientOverride = null);

  withWonkyServerpod('Given a document and the assistant', (
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
        name: 'Plan',
        markdown: '# Plan\n\nThe old plan is fine.\n\n## Budget\n\nTen euros.\n',
      );
    });

    Stream<AssistantEvent> chat(
      String message, {
      int? threadId,
      AssistantContextHints? hints,
      TestUser? as,
    }) => endpoints.assistant.chat(
      (as ?? anna).endpointSession,
      threadId,
      doc.uuid,
      message,
      hints ?? _hints(),
    );

    test(
      'when the model edits with a tool then the edit lands as one AI op on '
      "behalf of the user's session and the run is persisted",
      () async {
        final client = await TestDocClient.connect(
          endpoints,
          anna,
          doc.contentRef!,
        );
        fake
          ..enqueue(
            (SseScript()
                  ..thinking('I will fix the wording.')
                  ..toolUse('tu_1', 'write_replace_text', {
                    'find': 'old plan',
                    'replace': 'new plan',
                    'occurrence': 1,
                  })
                  ..stop('tool_use'))
                .response,
          )
          ..enqueue(
            (SseScript()
                  ..text('I replaced "old plan" with "new plan".')
                  ..usage(cacheRead: 900))
                .response,
          );
        final events = await chat(
          'Use new plan instead of old plan',
          hints: _hints(sessionId: client.init.sessionId),
        ).toList();
        final types = events.map((e) => e.type).toList();
        expect(types.first, AssistantEventType.started);
        expect(types, contains(AssistantEventType.progress));
        expect(types, contains(AssistantEventType.toolStarted));
        expect(types.last, AssistantEventType.done);
        final finished = events.firstWhere(
          (e) => e.type == AssistantEventType.toolFinished,
        );
        expect(finished.toolName, 'write.replace_text');
        expect(finished.toolError, isFalse);
        expect(finished.changeId, isNotNull);
        expect(events.last.text, 'I replaced "old plan" with "new plan".');

        expect(await _markdown(endpoints, anna, doc), contains('new plan'));
        final op = await client.next<DocRemoteOp>();
        expect(op.actorKind, ActorKind.ai);
        expect(op.kind, DocumentOpKind.aiEdit);
        expect(op.onBehalfOfSessionId, client.init.sessionId);
        expect(op.groupId, events.first.runId);
        await client.close();

        // Request shape: tools → system (cached) → snapshot (cached).
        final first = fake.requests.first;
        final tools = (first['tools'] as List).cast<Map>();
        expect(tools.map((t) => t['name']), contains('write_replace_text'));
        expect(tools.map((t) => t['name']), isNot(contains('write_set_markdown')));
        final system = (first['system'] as List).single as Map;
        expect(system['cache_control'], {'type': 'ephemeral'});
        final userBlocks = ((first['messages'] as List).single as Map)['content']
            as List;
        expect((userBlocks.first as Map)['text'], contains('<document '));
        expect((userBlocks.first as Map)['cache_control'], isNotNull);
        expect((userBlocks.last as Map)['text'], contains('<context>'));

        // Both tool results go back in one user message; the assistant
        // turn (with its thinking block) is replayed verbatim.
        final second = fake.requests[1]['messages'] as List;
        expect(second, hasLength(3));
        final assistant = (second[1] as Map)['content'] as List;
        expect((assistant.first as Map)['type'], 'thinking');
        expect((assistant.first as Map)['signature'], 'sig_test');
        final results = (second[2] as Map)['content'] as List;
        expect((results.single as Map)['type'], 'tool_result');
        expect((results.single as Map)['tool_use_id'], 'tu_1');

        final threadId = events.first.threadId!;
        final detail = await endpoints.assistant.getThread(
          anna.endpointSession,
          threadId,
        );
        expect(detail.messages.map((m) => m.role), ['user', 'assistant', 'assistant']);
        final usage = await AiUsageService.usedToday(anna.session, anna.id);
        expect(usage, greaterThan(0));
      },
    );

    test(
      'when the model calls tools in parallel then they run and answer in '
      'one message',
      () async {
        fake
          ..enqueue(
            (SseScript()
                  ..toolUse('a', 'write_get_outline', const {})
                  ..toolUse('b', 'write_get_stats', const {})
                  ..stop('tool_use'))
                .response,
          )
          ..enqueue((SseScript()..text('Two sections.')).response);
        final events = await chat('How long is it?').toList();
        expect(
          events.where((e) => e.type == AssistantEventType.toolFinished),
          hasLength(2),
        );
        final results =
            ((fake.requests[1]['messages'] as List).last as Map)['content']
                as List;
        expect(results.map((r) => (r as Map)['tool_use_id']), ['a', 'b']);
      },
    );

    test(
      'when the model tries a tool outside the allowlist then it is '
      'refused and the document is unchanged',
      () async {
        fake
          ..enqueue(
            (SseScript()
                  ..toolUse('x', 'write_set_markdown', {'markdown': '# Gone'})
                  ..toolUse('y', 'drive_share', {'email': 'eve@example.test'})
                  ..stop('tool_use'))
                .response,
          )
          ..enqueue((SseScript()..text('I cannot do that.')).response);
        final before = await _markdown(endpoints, anna, doc);
        final events = await chat('Replace everything').toList();
        final errors = events.where(
          (e) => e.type == AssistantEventType.toolFinished && e.toolError == true,
        );
        expect(errors, hasLength(2));
        final results =
            ((fake.requests[1]['messages'] as List).last as Map)['content']
                as List;
        for (final r in results.cast<Map>()) {
          expect(r['is_error'], true);
          expect(jsonDecode(r['content'] as String)['code'], 'forbidden');
        }
        expect(await _markdown(endpoints, anna, doc), before);
      },
    );

    test('when the model sends invalid tool JSON then it gets an error result', () async {
      fake
        ..enqueue(
          (SseScript()
                ..toolUse('j', 'write_search', const {}, rawJson: '{"query": "Bu')
                ..stop('tool_use'))
              .response,
        )
        ..enqueue((SseScript()..text('Retrying failed.')).response);
      await chat('Find budget').toList();
      final result =
          (((fake.requests[1]['messages'] as List).last as Map)['content']
                  as List)
              .single as Map;
      expect(result['is_error'], true);
      expect(result['content'], contains('INVALID_JSON'));
    });

    test(
      'when the model refuses then the panel shows the refusal and the turn '
      'is not replayed',
      () async {
        fake
          ..enqueue(
            (SseScript()..stop('refusal', details: {'type': 'refusal'})).response,
          )
          ..enqueue((SseScript()..text('Hello again.')).response);
        final events = await chat('Something').toList();
        expect(
          events.map((e) => e.type),
          contains(AssistantEventType.refusal),
        );
        final threadId = events.first.threadId!;
        await chat('Try again', threadId: threadId).toList();
        final replay = fake.requests.last['messages'] as List;
        expect(replay.map((m) => (m as Map)['role']), ['user', 'user']);
      },
    );

    test(
      'when the answer is cut off during a tool call then the call is not '
      'executed and Continue is offered',
      () async {
        fake.enqueue(
          (SseScript()
                ..toolUse('t', 'write_delete_range', {
                  'range': {'type': 'all'},
                })
                ..stop('max_tokens'))
              .response,
        );
        final before = await _markdown(endpoints, anna, doc);
        final events = await chat('Delete it').toList();
        expect(
          events.map((e) => e.type),
          contains(AssistantEventType.maxTokens),
        );
        expect(await _markdown(endpoints, anna, doc), before);
      },
    );

    test(
      'when a call would delete most of the document then the user must '
      'confirm it',
      () async {
        doc = await TestDrive.document(
          endpoints,
          anna,
          markdown: '# Plan\n\nThe old plan is fine. ${'More words. ' * 60}\n',
        );
        fake
          ..enqueue(
            (SseScript()
                  ..toolUse('d', 'write_delete_range', {
                    'range': {
                      'type': 'heading_section',
                      'heading': 'Plan',
                      'include_heading': true,
                    },
                  })
                  ..stop('tool_use'))
                .response,
          )
          ..enqueue((SseScript()..text('Deleted.')).response);
        final events = <AssistantEvent>[];
        final done = Completer<void>();
        chat('Delete everything').listen(
          (e) {
            events.add(e);
            if (e.type == AssistantEventType.confirmationRequired) {
              unawaited(
                endpoints.assistant.confirm(
                  anna.endpointSession,
                  e.runId!,
                  e.confirmationId!,
                  true,
                ),
              );
            }
          },
          onDone: done.complete,
        );
        await done.future;
        final ask = events.firstWhere(
          (e) => e.type == AssistantEventType.confirmationRequired,
        );
        expect(ask.toolSummary, contains('delete'));
        expect(await _markdown(endpoints, anna, doc), isNot(contains('old plan')));
      },
    );

    test('when the user denies a destructive call then nothing is deleted', () async {
      doc = await TestDrive.document(
        endpoints,
        anna,
        markdown: '# Plan\n\n${'More words. ' * 60}\n',
      );
      fake
        ..enqueue(
          (SseScript()
                ..toolUse('d', 'write_delete_range', {
                  'range': {'type': 'all'},
                })
                ..stop('tool_use'))
              .response,
        )
        ..enqueue((SseScript()..text('Okay, I kept it.')).response);
      final before = await _markdown(endpoints, anna, doc);
      final done = Completer<void>();
      chat('Delete everything').listen((e) {
        if (e.type == AssistantEventType.confirmationRequired) {
          unawaited(
            endpoints.assistant.confirm(
              anna.endpointSession,
              e.runId!,
              e.confirmationId!,
              false,
            ),
          );
        }
      }, onDone: done.complete);
      await done.future;
      expect(await _markdown(endpoints, anna, doc), before);
      final result =
          (((fake.requests[1]['messages'] as List).last as Map)['content']
                  as List)
              .single as Map;
      expect(result['content'], contains('denied_by_user'));
    });

    test(
      'when Suggest mode is on then edits become suggestions authored by the '
      'user',
      () async {
        fake
          ..enqueue(
            (SseScript()
                  ..toolUse('s', 'write_replace_text', {
                    'find': 'Ten euros',
                    'replace': 'Twelve euros',
                    'occurrence': 1,
                  })
                  ..stop('tool_use'))
                .response,
          )
          ..enqueue((SseScript()..text('Suggested.')).response);
        await chat(
          'Raise the budget',
          hints: _hints(mode: AiApplyMode.suggest),
        ).toList();
        final s = await endpoints.document.getSnapshot(
          anna.endpointSession,
          doc.contentRef!,
          null,
        );
        final suggestions = SuggestionIndex.list(
          Delta.fromJson(jsonDecode(s.deltaJson) as List),
        );
        expect(suggestions, isNotEmpty);
      },
    );

    test(
      'when continuing a thread after the document changed then an update '
      'is appended and history is unchanged',
      () async {
        fake.enqueue((SseScript()..text('It is a plan.')).response);
        final first = await chat('What is this?').toList();
        final threadId = first.first.threadId!;
        final firstHistory = jsonEncode(
          (fake.requests.first['messages'] as List).first,
        );
        final client = await TestDocClient.connect(
          endpoints,
          anna,
          doc.contentRef!,
        );
        client.edit(Delta()..insert('Intro\n'));
        await client.processUntilSynchronized();
        await client.close();
        fake.enqueue((SseScript()..text('Now with an intro.')).response);
        await chat('And now?', threadId: threadId).toList();
        final messages = fake.requests.last['messages'] as List;
        expect(jsonEncode(messages.first), firstHistory);
        final last = (messages.last as Map)['content'] as List;
        expect((last.first as Map)['text'], contains('<document_update'));
        expect((last.first as Map)['text'], contains('Intro'));
      },
    );

    test('when the daily budget is spent then chat is refused', () async {
      AiConfig.current = AiConfig(apiKey: 'test-key', dailyTokenBudget: 10);
      fake.enqueue((SseScript()..usage(input: 50, output: 50)..text('Hi')).response);
      await chat('Hello').toList();
      await expectLater(
        chat('Again').toList(),
        throwsA(
          isA<WonkyException>().having(
            (e) => e.code,
            'code',
            WonkyErrorCode.limitExceeded,
          ),
        ),
      );
    });

    test('when stopped then the run ends with done(stopped)', () async {
      fake.beforeResponse = (_) async {
        final run = AssistantService.runsOf(anna.id).single;
        await endpoints.assistant.stop(anna.endpointSession, null, run.runId);
      };
      fake.enqueue((SseScript()..text('Long answer')).response);
      final events = await chat('Write a lot').toList();
      expect(events.last.type, AssistantEventType.done);
      expect(events.last.errorCode, 'stopped');
      expect(AiUsageService.running(anna.id), 0);
    });

    test('when threads are listed and deleted then only own threads show', () async {
      fake.enqueue((SseScript()..text('A')).response);
      final ev = await chat('First').toList();
      final threads = await endpoints.assistant.listThreads(
        anna.endpointSession,
        doc.uuid,
      );
      expect(threads.single.title, 'First');
      final bob = await TestUsers.create(sessionBuilder, name: 'Bob');
      await expectLater(
        endpoints.assistant.getThread(bob.endpointSession, ev.first.threadId!),
        throwsA(isA<WonkyException>()),
      );
      await endpoints.assistant.deleteThread(
        anna.endpointSession,
        ev.first.threadId!,
      );
      expect(
        await endpoints.assistant.listThreads(anna.endpointSession, doc.uuid),
        isEmpty,
      );
    });

    test('when a viewer chats then edit tools are refused', () async {
      final vic = await TestUsers.create(sessionBuilder, name: 'Vic');
      await TestDrive.share(endpoints, doc, anna, vic, AccessRole.viewer);
      fake
        ..enqueue(
          (SseScript()
                ..toolUse('v', 'write_replace_text', {
                  'find': 'old',
                  'replace': 'new',
                  'occurrence': 1,
                })
                ..stop('tool_use'))
              .response,
        )
        ..enqueue((SseScript()..text('No access.')).response);
      final events = await chat('Fix it', as: vic).toList();
      final fin = events.firstWhere(
        (e) => e.type == AssistantEventType.toolFinished,
      );
      expect(fin.toolError, isTrue);
      expect(await _markdown(endpoints, anna, doc), contains('old plan'));
    });
  });

  withWonkyServerpod('Given the assistant status', (sessionBuilder, endpoints) {
    test('when no API key is configured then AI is not available', () async {
      AiConfig.clientOverride = null;
      AiConfig.current = AiConfig();
      final u = await TestUsers.create(sessionBuilder);
      final status = await endpoints.assistant.getStatus(u.endpointSession);
      expect(status.available, isFalse);
      expect(status.reason, 'notConfigured');
      expect(status.message, "AI isn't configured on this server.");
    });

    test('when the server disables AI then it is not available', () async {
      AiConfig.current = AiConfig(apiKey: 'k', enabled: false);
      final u = await TestUsers.create(sessionBuilder);
      final status = await endpoints.assistant.getStatus(u.endpointSession);
      expect(status.reason, 'disabled');
    });

    test('when the user opts out then AI is not available', () async {
      final u = await TestUsers.create(sessionBuilder);
      await endpoints.user.updatePreferences(
        u.endpointSession,
        UserPreferencesPatch(aiEnabled: false),
      );
      final status = await endpoints.assistant.getStatus(u.endpointSession);
      expect(status.reason, 'optedOut');
    });

    test('when the quality changes then it is remembered', () async {
      final u = await TestUsers.create(sessionBuilder);
      final s = await endpoints.assistant.setQuality(
        u.endpointSession,
        AiQuality.fast,
      );
      expect(s.quality, AiQuality.fast);
      fake.enqueue((SseScript(model: 'claude-haiku-5-5')..text('Hi')).response);
      final d = await TestDrive.document(endpoints, u, markdown: 'Hi\n');
      await endpoints.assistant
          .chat(u.endpointSession, null, d.uuid, 'Hi', _hints())
          .toList();
      expect(fake.requests.single['model'], 'claude-haiku-5-5');
      expect((fake.requests.single['output_config'] as Map)['effort'], 'low');
    });
  });
}
