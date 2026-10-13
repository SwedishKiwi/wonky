import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart' show JsonSchema;
import 'package:wonky_server/src/platform/ai/assistant_service.dart';
import 'package:wonky_server/src/platform/ai/assistant_tools.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/mcp/wonky_mcp_server.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

void main() {
  group('Given the Write assistant toolset for an editor', () {
    final toolset = AssistantToolset.write(
      WonkyMcpServer.executor,
      canDecideSuggestions: true,
    );
    final names = toolset.tools.map((t) => t.name).toSet();

    test('when built then only allowlisted tools are exposed', () {
      expect(names, contains('write.replace_text'));
      expect(names, contains('comments.create'));
      expect(names, contains('write.accept_suggestion'));
      for (final denied in AssistantToolset.denied) {
        expect(names, isNot(contains(denied)));
      }
      expect(names.where((n) => n.startsWith('ui.')), isEmpty);
      expect(names.where((n) => n.startsWith('drive.')), isEmpty);
    });

    test('when sent to the API then names have no dots and are sorted', () {
      final api = toolset.apiTools.map((t) => t.name).toList();
      expect(api, everyElement(matches(RegExp(r'^[a-zA-Z0-9_-]{1,64}$'))));
      expect(api, orderedEquals([...api]..sort()));
    });

    test('when sent to the API then the document binding is removed', () {
      for (final t in toolset.apiTools) {
        final props = t.inputSchema['properties'] as Map;
        expect(props.containsKey('document_uuid'), isFalse, reason: t.name);
        expect(props.containsKey('uuid'), isFalse, reason: t.name);
        expect(props.containsKey('mode'), isFalse, reason: t.name);
        final required = (t.inputSchema['required'] as List?) ?? const [];
        expect(required, isNot(contains('document_uuid')));
      }
    });

    test('when built then tool names are valid for every provider', () {
      for (final t in toolset.apiTools) {
        expect(t.name, matches(RegExp(r'^[a-zA-Z_][a-zA-Z0-9_-]{0,63}$')));
      }
    });

    test(
      'when binding arguments then the open document and apply mode are '
      'injected and model values are ignored',
      () {
        final tool = toolset.byApiName('write_replace_text')!;
        final item = UuidValue.fromString(
          '0192f000-0000-7000-8000-000000000001',
        );
        final args = toolset.bindArgs(
          tool,
          {
            'document_uuid': '0192f000-0000-7000-8000-00000000dead',
            'mode': 'edit',
            'find': 'a',
            'replace': 'b',
          },
          itemUuid: item,
          applyMode: AiApplyMode.suggest,
        );
        expect(args['document_uuid'], item.uuid);
        expect(args['mode'], 'suggest');
        expect(args['find'], 'a');
      },
    );
  });

  group('Given a commenter', () {
    test('when the toolset is built then suggestion decisions are hidden', () {
      final toolset = AssistantToolset.write(
        WonkyMcpServer.executor,
        canDecideSuggestions: false,
      );
      final names = toolset.tools.map((t) => t.name);
      expect(names, isNot(contains('write.accept_suggestion')));
      expect(names, isNot(contains('write.reject_suggestion')));
      expect(names, contains('write.suggest_edit'));
    });
  });

  group('Given a tool with an open object schema', () {
    test('when converted then the schema is passed on unchanged', () {
      final def = WonkyMcpServer.executor['comments.create']!.definition;
      final toolset = AssistantToolset.of([def]);
      final props = toolset.apiTools.single.inputSchema['properties'] as Map;
      expect(props.keys, isNot(contains('uuid')));
      expect(JsonSchema.empty.toJson()['type'], 'object');
    });
  });

  group('Given the destructive guard', () {
    final doc = Delta()..insert('${'word ' * 1000}\n');

    test('when a change deletes a few words then it passes', () {
      final change = Delta()
        ..retain(10)
        ..delete(20);
      expect(AssistantService.guardViolation(doc, change), isNull);
    });

    test(
      'when a change deletes more than 2,000 characters then it needs '
      'confirmation',
      () {
        final change = Delta()..delete(2500);
        final v = AssistantService.guardViolation(doc, change);
        expect(v?.code, 'needs_confirmation');
        expect((v!.details as Map)['deleted_chars'], 2500);
      },
    );

    test('when a change deletes 30 % of a small document then it asks', () {
      final small = Delta()..insert('${'x' * 999}\n');
      final change = Delta()..delete(400);
      expect(AssistantService.guardViolation(small, change), isNotNull);
    });
  });
}
