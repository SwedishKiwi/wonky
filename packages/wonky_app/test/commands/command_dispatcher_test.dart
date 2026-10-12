import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../support/counter_undo.dart';

void main() {
  late Map<String, int> values;
  late CommandTestHarness h;
  var enabled = true;

  CallbackCommand setCommand({Role role = Role.viewer}) => CallbackCommand(
    id: 'test.counter.set',
    title: (_) => 'Set counter',
    requiredRole: role,
    isUndoable: true,
    undoTarget: UndoTarget.shell,
    argsSchema: const JsonSchema.object(
      properties: {
        'key': JsonSchema.string(),
        'value': JsonSchema.integer(minimum: 0),
      },
      required: ['key', 'value'],
    ),
    enabled: (ctx, a) => enabled,
    run: (ctx, a) async {
      final key = a.string('key')!;
      final to = a.values['value']! as int;
      ctx.record(CounterEntry(key, values[key]!, to));
      values[key] = to;
      return CommandResult.ok({'value': to});
    },
  );

  setUp(() {
    values = {'a': 0};
    enabled = true;
    h = CommandTestHarness(
      config: TestAppConfig(extraCommands: [setCommand()]),
      registerShellCommands: false,
    );
    h.undoService.registerHandler(CounterHandler(values));
  });
  tearDown(() => h.dispose());

  group('Given a registered undoable command', () {
    test(
      'when invoking with valid args then it runs and records one step',
      () async {
        final r = await h.invoke('test.counter.set', {'key': 'a', 'value': 3});

        expect(r.isOk, isTrue);
        expect(values['a'], 3);
        expect(h.undoLabels, hasLength(1));
      },
    );

    test(
      'when an agent invokes it then the undo step is labelled as AI',
      () async {
        await h.invoke('test.counter.set', {'key': 'a', 'value': 3});

        expect(h.undoLabels.single, startsWith('AI: '));
      },
    );

    test('when undoing the invocation then the value is restored', () async {
      await h.invoke('test.counter.set', {'key': 'a', 'value': 3});

      await h.undo();

      expect(values['a'], 0);
    });

    test('when invoking with args that break the schema then '
        'InvalidCommandArgs is thrown and nothing changes', () async {
      await expectLater(
        h.invoke('test.counter.set', {'key': 'a', 'value': -1}),
        throwsA(isA<InvalidCommandArgs>()),
      );
      expect(values['a'], 0);
    });

    test('when it is disabled then CommandDisabled is thrown', () async {
      enabled = false;

      await expectLater(
        h.invoke('test.counter.set', {'key': 'a', 'value': 1}),
        throwsA(isA<CommandDisabled>()),
      );
      expect(
        h.services.dispatcher.stateOf('test.counter.set').enabled,
        isFalse,
      );
    });

    test('when invoked then an event with the result is emitted', () async {
      final events = <CommandInvoked>[];
      final sub = h.services.dispatcher.events.listen(events.add);
      addTearDown(sub.cancel);

      await h.invoke('test.counter.set', {'key': 'a', 'value': 2});
      await pumpEventQueue();

      expect(events.single.id.value, 'test.counter.set');
      expect(events.single.result?.isOk, isTrue);
    });
  });

  test('Given no such command when invoking then UnknownCommand is thrown', () {
    expect(h.invoke('test.nope'), throwsA(isA<UnknownCommand>()));
  });

  test('Given a viewer on the active document when invoking an editor '
      'command then CommandForbidden is thrown', () async {
    final hv = CommandTestHarness(
      config: TestAppConfig(extraCommands: [setCommand(role: Role.editor)]),
      registerShellCommands: false,
    );
    addTearDown(hv.dispose);
    hv.services.activate(
      BasicDocumentController(
        itemUuid: UuidV7Generator().next(),
        kind: DriveItemKind.document,
        title: 'Doc',
        role: Role.viewer,
      ),
    );

    await expectLater(
      hv.invoke('test.counter.set', {'key': 'a', 'value': 1}),
      throwsA(isA<CommandForbidden>()),
    );
  });
}
