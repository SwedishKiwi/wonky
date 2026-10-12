import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/mcp/tool_support.dart';
import 'package:wonky_server/src/platform/mcp/ui_bridge/ui_bridge_hub.dart';

import '../../../support/mcp_harness.dart';
import '../../../support/test_users.dart';
import '../../../support/wonky_serverpod.dart';

/// A fake app window on `uiBridge.connect`.
class _FakeWindow {
  _FakeWindow(this.input, this.queue);

  final StreamController<UiBridgeMessage> input;
  final StreamQueue<UiBridgeMessage> queue;
  late String sessionId;

  static Future<_FakeWindow> connect(
    TestEndpoints endpoints,
    TestUser user, {
    bool focused = true,
    String route = '/',
    List<String> tools = const [
      'ui.get_state',
      'ui.invoke_command',
      'ui.screenshot',
      'ui.write.get_selection',
    ],
  }) async {
    final input = StreamController<UiBridgeMessage>();
    final stream = endpoints.uiBridge.connect(
      user.endpointSession,
      input.stream,
    );
    final w = _FakeWindow(input, StreamQueue(stream));
    input.add(
      UiBridgeHello(
        app: 'write',
        deviceLabel: 'Test browser',
        platform: 'web',
        route: route,
        focused: focused,
        tools: tools,
      ),
    );
    final welcome = await w.queue.next.timeout(const Duration(seconds: 5));
    w.sessionId = (welcome as UiBridgeWelcome).sessionId;
    return w;
  }

  Future<UiBridgeRequest> nextRequest() async {
    while (true) {
      final m = await queue.next.timeout(const Duration(seconds: 5));
      if (m is UiBridgeRequest) return m;
    }
  }

  void respond(UiBridgeRequest r, Object? result, {String? image}) => input.add(
    UiBridgeResponse(
      requestId: r.requestId,
      ok: true,
      resultJson: jsonEncode(result),
      text: 'done',
      imageBase64: image,
    ),
  );

  Future<void> close() async {
    await input.close();
    await queue.cancel(immediate: true);
  }
}

void main() {
  withWonkyServerpod('Given app windows on the UI bridge', (
    sessionBuilder,
    endpoints,
  ) {
    late TestUser anna;
    late McpHarness mcp;
    setUp(() async {
      UiBridgeHub.clear();
      anna = await TestUsers.create(sessionBuilder, name: 'Anna');
      mcp = await McpHarness.forUser(anna);
    });

    test(
      'when no window is connected then ui calls fail with no_session',
      () async {
        final sessions = await mcp.call('ui.list_sessions');
        final e = await mcp.error('ui.get_state');

        expect(sessions['sessions'], isEmpty);
        expect(e['code'], 'no_session');
      },
    );

    test(
      'when a window is connected then it is listed and receives calls',
      () async {
        final w = await _FakeWindow.connect(endpoints, anna, route: '/d/x');

        final sessions = await mcp.call('ui.list_sessions');
        final pending = mcp.call('ui.invoke_command', {
          'command_id': 'write.format.bold',
        });
        final req = await w.nextRequest();
        w.respond(req, {'status': 'ok'});
        final r = await pending;

        final listed = (sessions['sessions'] as List).single as Map;
        expect(listed['session_id'], w.sessionId);
        expect(listed['route'], '/d/x');
        expect(req.tool, 'ui.invoke_command');
        expect(jsonDecode(req.argsJson), {'command_id': 'write.format.bold'});
        expect(req.agentName, 'Test agent (MCP)');
        expect(r, containsPair('status', 'ok'));
        expect(r['session_id'], w.sessionId);
        await w.close();
      },
    );

    test(
      'when two windows are open then the most recently focused one is used',
      () async {
        final a = await _FakeWindow.connect(endpoints, anna);
        final b = await _FakeWindow.connect(endpoints, anna);
        a.input.add(UiBridgeStatus(route: '/', focused: true));
        await pumpEventQueue();

        final pending = mcp.call('ui.get_state');
        final req = await a.nextRequest();
        a.respond(req, {'route': '/'});
        await pending;

        expect(UiBridgeHub.windowsOf(anna.id).first.sessionId, a.sessionId);
        await a.close();
        await b.close();
      },
    );

    test('when a session id is given then that window is used', () async {
      final a = await _FakeWindow.connect(endpoints, anna);
      final b = await _FakeWindow.connect(endpoints, anna, focused: false);

      final pending = mcp.call('ui.get_state', {'session_id': b.sessionId});
      final req = await b.nextRequest();
      b.respond(req, {'route': '/b'});

      expect(await pending, containsPair('route', '/b'));
      await a.close();
      await b.close();
    });

    test(
      'when the app reports an error then the tool error is structured',
      () async {
        final w = await _FakeWindow.connect(endpoints, anna);

        final pending = mcp.error('ui.invoke_command', {
          'command_id': 'write.nope',
        });
        final req = await w.nextRequest();
        w.input.add(
          UiBridgeResponse(
            requestId: req.requestId,
            ok: false,
            errorCode: 'not_found',
            errorMessage: 'Unknown command',
          ),
        );

        expect(await pending, containsPair('code', 'not_found'));
        await w.close();
      },
    );

    test(
      'when a screenshot is returned then it becomes image content',
      () async {
        final w = await _FakeWindow.connect(endpoints, anna);

        final outcome = mcp.call('ui.screenshot');
        final req = await w.nextRequest();
        w.respond(req, {'width': 1, 'height': 1}, image: 'iVBORw0KGgo=');
        await outcome;

        expect(req.tool, 'ui.screenshot');
        await w.close();
      },
    );

    test('when the window does not answer then the call times out', () async {
      final w = await _FakeWindow.connect(endpoints, anna);

      final call = UiBridgeHub.call(
        anna.id,
        'ui.get_state',
        const {},
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        call,
        throwsA(
          isA<McpToolException>().having((e) => e.code, 'code', 'timeout'),
        ),
      );
      await w.close();
    });

    test(
      'when the user presses Stop then pending and new calls fail',
      () async {
        final w = await _FakeWindow.connect(endpoints, anna);

        final pending = mcp.error('ui.get_state');
        await w.nextRequest();
        w.input.add(UiBridgeStop(pauseMs: 60000));
        final first = await pending;
        final next = await mcp.error('ui.get_state');

        expect(first['code'], 'stopped_by_user');
        expect(next['code'], 'stopped_by_user');
        await w.close();
      },
    );

    test('when the window disconnects then it leaves the list', () async {
      final w = await _FakeWindow.connect(endpoints, anna);

      await w.close();
      await pumpEventQueue();

      final sessions = await mcp.call('ui.list_sessions');
      expect(sessions['sessions'], isEmpty);
    });

    test('when another user has a window then it is not reachable', () async {
      final bo = await TestUsers.create(sessionBuilder, name: 'Bo');
      final w = await _FakeWindow.connect(endpoints, bo);

      final e = await mcp.error('ui.get_state');

      expect(e['code'], 'no_session');
      await w.close();
    });

    test(
      'when no window implements the tool then no session is found',
      () async {
        final w = await _FakeWindow.connect(
          endpoints,
          anna,
          tools: const ['ui.get_state'],
        );

        final e = await mcp.error('ui.write.get_selection');

        expect(e['code'], 'no_session');
        await w.close();
      },
    );
  });
}
