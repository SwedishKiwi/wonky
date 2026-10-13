import 'dart:async';

import 'package:dartantic_ai/dartantic_ai.dart' as ai;
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/ai/assistant_history.dart';
import 'package:wonky_server/src/platform/ai/llm/ai_client.dart';
import 'package:wonky_server/src/platform/ai/llm/dartantic_ai_client.dart';
import 'package:wonky_server/src/platform/common/models.dart' show AiProvider;

ai.ChatResult<ai.ChatMessage> _chunk(
  List<ai.StandardPart> parts, {
  ai.FinishReason finish = ai.FinishReason.unspecified,
  ai.LanguageModelUsage? usage,
  Map<String, Object?> metadata = const {},
}) => ai.ChatResult<ai.ChatMessage>(
  output: ai.ChatMessage(role: ai.ChatMessageRole.model, parts: parts),
  finishReason: finish,
  usage: usage,
  metadata: metadata,
);

void main() {
  group('Given streamed dartantic chunks', () {
    test('when text streams then deltas are reported and joined', () {
      final deltas = <String>[];
      final acc = AiStreamAccumulator(onText: deltas.add)
        ..add(_chunk([const ai.TextPart('Hel')]))
        ..add(_chunk([const ai.TextPart('lo')]))
        ..add(
          _chunk(
            const [],
            finish: ai.FinishReason.stop,
            usage: const ai.LanguageModelUsage(
              promptTokens: 12,
              responseTokens: 3,
            ),
            metadata: const {'model': 'gpt-5'},
          ),
        );

      final r = acc.build();

      expect(deltas, ['Hel', 'lo']);
      expect(r.text, 'Hello');
      expect(r.stopReason, AiStopReason.endTurn);
      expect(r.usage.inputTokens, 12);
      expect(r.usage.outputTokens, 3);
      expect(r.model, 'gpt-5');
    });

    test(
      'when the final chunk repeats the text with tool calls then the text '
      'is not doubled',
      () {
        final deltas = <String>[];
        final acc = AiStreamAccumulator(onText: deltas.add)
          ..add(_chunk([const ai.TextPart('Let me look.')]))
          ..add(
            _chunk([
              const ai.TextPart('Let me look.'),
              const ai.ToolPart.call(
                callId: 'c1',
                toolName: 'write_get_outline',
                arguments: {},
              ),
            ], finish: ai.FinishReason.toolCalls),
          );

        final r = acc.build();

        expect(deltas, ['Let me look.']);
        expect(r.text, 'Let me look.');
        expect(r.stopReason, AiStopReason.toolUse);
        expect(r.toolCalls.single.toolName, 'write_get_outline');
      },
    );

    test('when a tool call arrives in pieces then it is merged by id', () {
      final acc = AiStreamAccumulator()
        ..add(
          _chunk([
            const ai.ToolPart.call(callId: 'c1', toolName: 'x', arguments: {}),
          ]),
        )
        ..add(
          _chunk([
            const ai.ToolPart.call(
              callId: 'c1',
              toolName: '',
              arguments: {'query': 'Budget'},
            ),
          ], finish: ai.FinishReason.stop),
        );

      final r = acc.build();

      expect(r.toolCalls, hasLength(1));
      expect(r.toolCalls.single.toolName, 'x');
      expect(r.toolCalls.single.arguments, {'query': 'Budget'});
      expect(r.stopReason, AiStopReason.toolUse);
    });

    test('when the output limit is hit then the stop reason is max_tokens', () {
      final r =
          (AiStreamAccumulator()
                ..add(_chunk([const ai.TextPart('Cut')]))
                ..add(_chunk(const [], finish: ai.FinishReason.length)))
              .build();

      expect(r.stopReason, AiStopReason.maxTokens);
    });

    test('when the provider filters the answer then it is a refusal', () {
      final r =
          (AiStreamAccumulator()
                ..add(_chunk(const [], finish: ai.FinishReason.contentFilter)))
              .build();

      expect(r.stopReason, AiStopReason.refusal);
    });

    test('when reasoning streams then it is reported as thinking', () {
      final notes = <String>[];
      final r = (AiStreamAccumulator(
        onThinking: notes.add,
      )..add(_chunk([const ai.ThinkingPart('Planning')]))).build();

      expect(notes, ['Planning']);
      expect(r.text, isEmpty);
    });
  });

  group('Given provider errors', () {
    test('when the key is rejected then the error is an auth error', () {
      final e = AiApiException.from(
        Exception('ApiException(401): invalid x-api-key'),
      );

      expect(e.isAuth, isTrue);
    });

    test('when the request times out then the type is timeout', () {
      final e = AiApiException.from(TimeoutException('slow'));

      expect(e.type, 'timeout');
      expect(e.statusCode, 0);
    });
  });

  group('Given a client that is cancelled before it starts', () {
    test('when sending then it throws AiCancelledException', () async {
      final client = DartanticAiClient(
        provider: AiProvider.openai,
        apiKey: 'sk-test-not-used',
      );
      final cancel = AiCancelToken()..cancel();

      await expectLater(
        client.send(
          const AiRequest(model: 'gpt-5', messages: []),
          cancel: cancel,
        ),
        throwsA(isA<AiCancelledException>()),
      );
    });
  });

  group('Given stored history', () {
    test('when a turn is stored then it decodes to the same message', () {
      final m = ai.ChatMessage(
        role: ai.ChatMessageRole.model,
        parts: const [
          ai.TextPart('Done.'),
          ai.ToolPart.call(callId: 'c', toolName: 't', arguments: {'a': 1}),
        ],
      );
      final names = <String, String>{};

      final back = AssistantHistory.decode(
        'assistant',
        AssistantHistory.encode(m),
        names,
      );

      expect(back, m);
      expect(names, {'c': 't'});
    });

    test(
      'when a legacy Anthropic thread is replayed then text, tool calls and '
      'results convert and thinking is dropped',
      () {
        final names = <String, String>{};
        final call = AssistantHistory.decode(
          'assistant',
          '[{"type":"thinking","thinking":"x","signature":"s"},'
              '{"type":"text","text":"Looking."},'
              '{"type":"tool_use","id":"tu","name":"write_search",'
              '"input":{"query":"a"}}]',
          names,
        )!;
        final result = AssistantHistory.decode(
          'user',
          '[{"type":"tool_result","tool_use_id":"tu","content":"[]"}]',
          names,
        )!;

        expect(call.role, ai.ChatMessageRole.model);
        expect(call.text, 'Looking.');
        expect(call.toolCalls.single.arguments, {'query': 'a'});
        expect(result.role, ai.ChatMessageRole.user);
        expect(result.toolResults.single.toolName, 'write_search');
        expect(result.toolResults.single.result, '[]');
      },
    );
  });
}
