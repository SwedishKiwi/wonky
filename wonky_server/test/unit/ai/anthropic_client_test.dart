import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/ai/ai_models.dart';
import 'package:wonky_server/src/platform/ai/anthropic/anthropic_client.dart';
import 'package:wonky_server/src/platform/ai/anthropic/fake_anthropic_client.dart';
import 'package:wonky_server/src/platform/ai/anthropic/sse_parser.dart';
import 'package:wonky_server/src/platform/common/models.dart';

AnthropicRequest _request({String model = AiModels.opus, bool tools = true}) =>
    AnthropicRequest(
      model: model,
      effort: AiEffort.high,
      system: [
        {'type': 'text', 'text': 'System'},
      ],
      tools: tools
          ? [
              const AnthropicTool(
                name: 'write_get_document',
                description: 'Reads',
                inputSchema: {
                  'type': 'object',
                  'properties': <String, Object?>{},
                  'additionalProperties': false,
                },
                strictCompatible: true,
              ),
            ]
          : const [],
      messages: [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Hi'},
          ],
        },
      ],
    );

/// A streamed HTTP response of [body] with [status].
http.StreamedResponse _response(
  String body, {
  int status = 200,
  Map<String, String> headers = const {},
}) => http.StreamedResponse(
  Stream.value(utf8.encode(body)),
  status,
  headers: headers,
);

void main() {
  setUp(HttpAnthropicClient.disabledFeatures.clear);

  group('Given SSE text', () {
    test(
      'when parsed then comments are skipped, multi-line data joins and '
      'unknown events are ignored',
      () async {
        const sse =
            ': keep-alive\n'
            'event: message_start\n'
            'data: {"type":"message_start","message":{"id":"m1","model":"x",\n'
            'data: "usage":{"input_tokens":5}}}\n'
            '\n'
            'event: brand_new_event\n'
            'data: {"type":"brand_new_event"}\n'
            '\n'
            'event: ping\n'
            'data: {"type":"ping"}\n'
            '\n';
        final events = await SseParser.parseLines(
          Stream.fromIterable(const LineSplitter().convert(sse)),
        ).toList();
        expect(events, hasLength(2));
        final start = events.first as MessageStartEvent;
        expect(start.id, 'm1');
        expect(start.usage.inputTokens, 5);
        expect(events.last, isA<PingEvent>());
      },
    );
  });

  group('Given a streamed message with text, thinking and a tool use', () {
    late AnthropicMessage msg;
    final texts = <String>[];
    final thinking = <String>[];

    setUp(() async {
      texts.clear();
      thinking.clear();
      final sse = (SseScript()
            ..thinking('Looking up the heading')
            ..text('Done.')
            ..toolUse('tu_1', 'write_search', {'query': 'Budget'})
            ..stop('tool_use')
            ..usage(input: 50, output: 9, cacheRead: 40))
          .build();
      msg = await FakeAnthropicClient([FakeResponse.sse(sse)]).send(
        _request(),
        onText: texts.add,
        onThinking: (_, t) => thinking.add(t),
      );
    });

    test('when accumulated then every block is kept verbatim', () {
      expect(msg.stopReason, 'tool_use');
      expect(msg.content.map((b) => b['type']), [
        'thinking',
        'text',
        'tool_use',
      ]);
      expect(msg.content.first['signature'], 'sig_test');
      expect(msg.toolUses.single['input'], {'query': 'Budget'});
      expect(msg.text, 'Done.');
      expect(msg.usage.cacheReadTokens, 40);
      expect(msg.usage.outputTokens, 9);
    });

    test('when streaming then deltas are reported as they arrive', () {
      expect(texts.join(), 'Done.');
      expect(thinking, ['Looking up the heading']);
    });
  });

  group('Given a tool use with invalid streamed JSON', () {
    test('when accumulated then the raw input is reported as invalid', () async {
      final sse = (SseScript()
            ..toolUse('tu_1', 'write_search', const {}, rawJson: '{"query": "Bud')
            ..stop('tool_use'))
          .build();
      final msg = await FakeAnthropicClient([FakeResponse.sse(sse)]).send(
        _request(),
      );
      expect(msg.invalidToolInputs['tu_1'], '{"query": "Bud');
      expect(msg.toolUses.single['input'], isEmpty);
    });
  });

  group('Given a response after a server-side fallback', () {
    test(
      'when replayed then model-internal blocks before the marker are '
      'dropped and text is kept',
      () async {
        final sse = (SseScript()
              ..thinking('declined attempt')
              ..text('Partial ')
              ..fallback(AiModels.opus, 'claude-opus-5')
              ..thinking('fallback thinking', signature: 'sig_2')
              ..text('answer'))
            .build();
        final msg = await FakeAnthropicClient([FakeResponse.sse(sse)]).send(
          _request(),
        );
        expect(msg.replayContent.map((b) => b['type']), [
          'text',
          'thinking',
          'text',
        ]);
        expect(msg.replayContent[1]['signature'], 'sig_2');
      },
    );
  });

  group('Given a request', () {
    test(
      'when serialized then it uses adaptive thinking, effort, auto tool '
      'choice, caching and the refusal fallback',
      () {
        final req = _request();
        final json = req.toJson(AnthropicFeature.values.toSet());
        expect(json['model'], AiModels.opus);
        expect(json['stream'], true);
        expect(json['max_tokens'], 64000);
        expect(json['thinking'], {
          'type': 'adaptive',
          'display': 'updates',
          'block_binding': {'prefix_mismatch_behavior': 'drop_block'},
        });
        expect(json['output_config'], {'effort': 'high'});
        expect(json['tool_choice'], {'type': 'auto'});
        expect(json['fallbacks'], 'default');
        expect(json['cache_control'], {'type': 'ephemeral'});
        expect(json.containsKey('temperature'), isFalse);
        expect(json.containsKey('top_p'), isFalse);
        final tool = (json['tools'] as List).single as Map;
        expect(tool['strict'], true);
        expect(tool['eager_input_streaming'], true);
        expect(req.betas(AnthropicFeature.values.toSet()), [
          'server-side-fallback-2026-07-01',
          'thinking-display-updates-2026-08-18',
          'thinking-binding-controls-2026-08-01',
        ]);
      },
    );

    test('when the model is Haiku then no fallback or display is sent', () {
      final req = _request(model: AiModels.haiku);
      final json = req.toJson(AnthropicFeature.values.toSet());
      expect(json.containsKey('fallbacks'), isFalse);
      expect((json['thinking'] as Map).containsKey('display'), isFalse);
      expect(
        req.betas(AnthropicFeature.values.toSet()),
        isNot(contains('server-side-fallback-2026-07-01')),
      );
    });
  });

  group('Given the HTTP client', () {
    final ok = (SseScript()..text('Hello')).build();

    test(
      'when the API is overloaded then it retries honouring retry-after',
      () async {
        final sleeps = <Duration>[];
        var calls = 0;
        final client = HttpAnthropicClient(
          apiKey: 'key',
          sleep: (d) async => sleeps.add(d),
          httpClient: () => MockClient.streaming((req, body) async {
            calls++;
            if (calls == 1) {
              return _response(
                '{"type":"error","error":{"type":"overloaded_error",'
                '"message":"Overloaded"}}',
                status: 529,
                headers: {'retry-after': '2'},
              );
            }
            return _response(ok);
          }),
        );
        final msg = await client.send(_request());
        expect(msg.text, 'Hello');
        expect(calls, 2);
        expect(sleeps, [const Duration(seconds: 2)]);
      },
    );

    test('when the key is rejected then it fails without retrying', () async {
      var calls = 0;
      final client = HttpAnthropicClient(
        apiKey: 'bad',
        sleep: (_) async {},
        httpClient: () => MockClient.streaming((req, body) async {
          calls++;
          return _response(
            '{"type":"error","error":{"type":"authentication_error",'
            '"message":"invalid x-api-key"}}',
            status: 401,
          );
        }),
      );
      await expectLater(
        client.send(_request()),
        throwsA(
          isA<AnthropicApiException>().having((e) => e.isAuth, 'isAuth', true),
        ),
      );
      expect(calls, 1);
    });

    test(
      'when a beta parameter is rejected then the request is retried '
      'without it',
      () async {
        final bodies = <Map<String, Object?>>[];
        final headers = <Map<String, String>>[];
        final client = HttpAnthropicClient(
          apiKey: 'key',
          sleep: (_) async {},
          httpClient: () => MockClient.streaming((req, body) async {
            final bytes = await body.toList();
            bodies.add(
              jsonDecode(utf8.decode(bytes.expand((b) => b).toList()))
                  as Map<String, Object?>,
            );
            headers.add(req.headers);
            if (bodies.length == 1) {
              return _response(
                '{"type":"error","error":{"type":"invalid_request_error",'
                '"message":"fallbacks: Extra inputs are not permitted"}}',
                status: 400,
              );
            }
            return _response(ok);
          }),
        );
        await client.send(_request());
        expect(bodies.first['fallbacks'], 'default');
        expect(bodies.last.containsKey('fallbacks'), isFalse);
        expect(headers.first['x-api-key'], 'key');
        expect(headers.first['anthropic-version'], '2023-06-01');
        expect(
          headers.last['anthropic-beta'] ?? '',
          isNot(contains('server-side-fallback')),
        );
      },
    );

    test('when the connection drops before any event then it retries', () async {
      var calls = 0;
      final client = HttpAnthropicClient(
        apiKey: 'key',
        sleep: (_) async {},
        httpClient: () => MockClient.streaming((req, body) async {
          calls++;
          if (calls == 1) throw http.ClientException('reset');
          return _response(ok);
        }),
      );
      expect((await client.send(_request())).text, 'Hello');
      expect(calls, 2);
    });

    test('when cancelled then the request stops', () async {
      final cancel = AiCancelToken()..cancel();
      final client = HttpAnthropicClient(
        apiKey: 'key',
        sleep: (_) async {},
        httpClient: () => MockClient.streaming(
          (req, body) async => _response(ok),
        ),
      );
      await expectLater(
        client.send(_request(), cancel: cancel),
        throwsA(isA<AiCancelledException>()),
      );
    });
  });

  group('Given the retry policy', () {
    test('when parsing retry headers then ms and seconds are read', () {
      expect(
        AnthropicRetryPolicy.retryAfterOf({'retry-after-ms': '1500'}),
        const Duration(milliseconds: 1500),
      );
      expect(
        AnthropicRetryPolicy.retryAfterOf({'retry-after': '3'}),
        const Duration(seconds: 3),
      );
    });

    test('when backing off then delays grow and are capped', () {
      const p = AnthropicRetryPolicy();
      final d0 = p.delay(0);
      final d5 = p.delay(8);
      expect(d0.inMilliseconds, inInclusiveRange(800, 1200));
      expect(d5.inSeconds, lessThanOrEqualTo(34));
    });
  });

  group('Given the quality tiers', () {
    test('when mapped then they follow the suite table', () {
      expect(AiTier.chat(AiQuality.best).toString(), '${AiModels.opus}/high');
      expect(
        AiTier.chat(AiQuality.balanced).toString(),
        '${AiModels.opus}/medium',
      );
      expect(AiTier.chat(AiQuality.fast).toString(), '${AiModels.haiku}/low');
      expect(AiTier.rewrite(AiQuality.best).effort, AiEffort.medium);
      expect(AiTier.continueWriting(AiQuality.best).effort, AiEffort.low);
    });
  });
}
