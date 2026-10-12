import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  group('Given the shared MCP tool catalog', () {
    test('when listing names then they are unique and snake_case', () {
      final names = McpToolCatalog.shared.map((t) => t.name).toList();
      expect(names.toSet().length, names.length);
      for (final n in names) {
        expect(n, matches(RegExp(r'^[a-z]+\.[a-z_]+$')), reason: n);
      }
    });

    test('when serialized then every tool has an object input schema', () {
      for (final t in McpToolCatalog.shared) {
        final json = t.toJson();
        expect((json['inputSchema'] as Map)['type'], 'object', reason: t.name);
        expect(t.description, isNotEmpty);
        expect(t.scopes, isNotEmpty, reason: t.name);
      }
    });

    test('when validating drive.create_folder args then name is required', () {
      expect(
        DriveTools.createFolder.inputSchema.accepts({'name': 'A'}),
        isTrue,
      );
      expect(DriveTools.createFolder.inputSchema.accepts({}), isFalse);
    });

    test('when looking up a tool by name then it is found', () {
      expect(McpToolCatalog.byName('ui.invoke_command'), isNotNull);
      expect(McpToolCatalog.byName('ui.nope'), isNull);
      expect(UiTools.waitFor.timeout, const Duration(seconds: 120));
    });
  });
}
