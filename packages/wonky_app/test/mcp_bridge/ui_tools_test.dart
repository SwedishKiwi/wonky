import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

/// A dialog the bridge can operate.
class _FakeDialog implements McpDescribableDialog {
  final values = <String, Object?>{'name': 'Old'};
  String? pressed;

  @override
  Map<String, Object?> describe() => {
    'title': 'Rename',
    'fields': [
      {'id': 'name', 'type': 'text', 'value': values['name']},
    ],
    'buttons': [
      {'id': 'ok'},
    ],
  };

  @override
  bool setField(String id, Object? value) {
    if (id != 'name' || value is! String) return false;
    values[id] = value;
    return true;
  }

  @override
  bool press(String buttonId) {
    if (buttonId != 'ok') return false;
    pressed = buttonId;
    return true;
  }
}

void main() {
  late CommandTestHarness h;
  late UiToolContext ctx;
  setUp(() {
    h = CommandTestHarness();
    ctx = UiToolContext(
      services: h.services,
      boundaryKey: GlobalKey(),
      events: UiEventLog(),
      agentName: 'Agent (MCP)',
    );
  });
  tearDown(() => h.dispose());

  Future<UiToolResult> call(
    String tool, [
    Map<String, Object?> args = const {},
  ]) => SharedUiTools.all[tool]!(ctx, args);

  group('Given the shared ui.* tools', () {
    test(
      'when invoking a command then it runs with source mcp and is undoable',
      () async {
        final doc = h.drive.seed(name: 'Plan');

        final r = await call('ui.invoke_command', {
          'command_id': 'shell.drive.rename',
          'args': {'uuid': doc.uuid.uuid, 'name': 'Q3'},
        });
        await call('ui.undo');

        expect(r.result['status'], 'ok');
        expect(h.drive.item(doc.uuid).name, 'Plan');
      },
    );

    test(
      'when invoking an unknown command then not_found is reported',
      () async {
        await expectLater(
          call('ui.invoke_command', {'command_id': 'shell.nope.nothing'}),
          throwsA(
            isA<UiToolException>().having((e) => e.code, 'code', 'not_found'),
          ),
        );
      },
    );

    test(
      'when invoking with invalid args then invalid_args is reported',
      () async {
        await expectLater(
          call('ui.invoke_command', {
            'command_id': 'shell.drive.rename',
            'args': {'uuid': 7},
          }),
          throwsA(
            isA<UiToolException>().having(
              (e) => e.code,
              'code',
              'invalid_args',
            ),
          ),
        );
      },
    );

    test('when no dialog is open then get_dialog returns null', () async {
      final r = await call('ui.get_dialog');

      expect(r.result['dialog'], isNull);
    });

    test('when a dialog is open then it can be filled and pressed', () async {
      final dialog = _FakeDialog();
      h.services.openDialogs.add(dialog);

      await call('ui.fill_dialog', {
        'values': {'name': 'New'},
      });
      final pressed = await call('ui.press_dialog_button', {'button_id': 'ok'});

      expect(dialog.values['name'], 'New');
      expect(dialog.pressed, 'ok');
      expect(pressed.result['pressed'], 'ok');
    });

    test('when filling an unknown field then invalid_args lists it', () async {
      h.services.openDialogs.add(_FakeDialog());

      await expectLater(
        call('ui.fill_dialog', {
          'values': {'nope': 1},
        }),
        throwsA(
          isA<UiToolException>().having((e) => e.code, 'code', 'invalid_args'),
        ),
      );
    });

    test(
      'when reading the state then app, theme and undo label are reported',
      () async {
        final doc = h.drive.seed(name: 'Plan');
        await h.invoke('shell.drive.rename', {
          'uuid': doc.uuid.uuid,
          'name': 'X',
        });

        final r = await call('ui.get_state');

        expect(r.result['app'], 'write');
        expect(r.result['theme'], isA<String>());
        expect(r.result['undo_label'], isNotNull);
      },
    );

    test(
      'when pressing a chord with an unknown modifier then invalid_args is reported',
      () async {
        await expectLater(
          call('ui.press_keys', {
            'keys': ['Hyper+B'],
          }),
          throwsA(
            isA<UiToolException>().having(
              (e) => e.code,
              'code',
              'invalid_args',
            ),
          ),
        );
      },
    );

    test('when polling events then only newer events are returned', () async {
      ctx.events.add('route', {'route': '/a'});
      final first = await call('ui.events');
      ctx.events.add('route', {'route': '/b'});

      final next = await call('ui.events', {
        'cursor': first.result['next_cursor'],
      });

      expect(
        (next.result['events'] as List).single,
        containsPair('route', '/b'),
      );
    });
  });

  group('Given the bridge client', () {
    test(
      'when a relayed call runs then the pill shows and the result is JSON',
      () async {
        final bridge = McpBridgeClient(
          h.services,
          boundaryKey: GlobalKey(),
          appTools: {
            'ui.test.echo': (c, a) async {
              expect(h.services.mcp.controlling, isTrue);
              return UiToolResult({'echo': a['value']});
            },
          },
        );

        final r = await bridge.execute(
          UiBridgeRequest(
            requestId: 'r1',
            tool: 'ui.test.echo',
            argsJson: jsonEncode({'value': 42}),
            agentName: 'Agent',
            timeoutMs: 1000,
          ),
        );

        expect(r.ok, isTrue);
        expect(jsonDecode(r.resultJson!), {'echo': 42});
        expect(h.services.mcp.controlling, isFalse);
        expect(bridge.tools.keys, contains('ui.screenshot'));
      },
    );

    test('when a tool is unknown then the response is unsupported', () async {
      final bridge = McpBridgeClient(h.services, boundaryKey: GlobalKey());

      final r = await bridge.execute(
        UiBridgeRequest(
          requestId: 'r2',
          tool: 'ui.nope',
          argsJson: '{}',
          timeoutMs: 1000,
        ),
      );

      expect(r.ok, isFalse);
      expect(r.errorCode, 'unsupported');
    });

    test('when a tool fails then the structured error is forwarded', () async {
      final bridge = McpBridgeClient(
        h.services,
        boundaryKey: GlobalKey(),
        appTools: {
          'ui.test.fail': (c, a) async =>
              throw const UiToolException('forbidden', 'No', details: {'x': 1}),
        },
      );

      final r = await bridge.execute(
        UiBridgeRequest(
          requestId: 'r3',
          tool: 'ui.test.fail',
          argsJson: '{}',
          timeoutMs: 1000,
        ),
      );

      expect(r.errorCode, 'forbidden');
      expect(jsonDecode(r.errorDetailsJson!), {'x': 1});
    });
  });
}
