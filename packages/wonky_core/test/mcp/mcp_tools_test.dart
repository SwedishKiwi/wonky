import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  group('Given the shared MCP tool catalog', () {
    test('when listing names then they are unique and snake_case', () {
      final names = McpToolCatalog.write.map((t) => t.name).toList();
      expect(names.toSet().length, names.length);
      for (final n in names) {
        expect(n, matches(RegExp(r'^[a-z]+(\.[a-z_]+)+$')), reason: n);
      }
    });

    test('when serialized then every tool has an object input schema', () {
      for (final t in McpToolCatalog.write) {
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

    test('when validating a quote range then the shape is accepted', () {
      final schema = WriteTools.replaceRange.inputSchema;
      expect(
        schema.accepts({
          'document_uuid': '0192a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b',
          'range': {'type': 'quote', 'quote': 'old plan'},
          'markdown': 'new plan',
        }),
        isTrue,
      );
      expect(
        schema.accepts({
          'document_uuid': '0192a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b',
          'range': {'type': 'quote'},
          'markdown': 'x',
        }),
        isFalse,
      );
    });

    test('when validating replace_text then occurrence is required', () {
      final schema = WriteTools.replaceText.inputSchema;
      const base = {
        'document_uuid': '0192a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b',
        'find': 'a',
        'replace': 'b',
      };
      expect(schema.accepts(base), isFalse);
      expect(schema.accepts({...base, 'occurrence': 'all'}), isTrue);
      expect(schema.accepts({...base, 'occurrence': 2}), isTrue);
    });
  });
}
