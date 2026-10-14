import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_server/src/platform/ai/assistant_tools.dart';
import 'package:wonky_server/src/sheets/mcp/sheets_tool_handlers.dart';

void main() {
  group('Given the sheets.* tool catalog', () {
    test('when listing names then every tool has a unique sheets name', () {
      final names = [for (final t in SheetsTools.all) t.name];
      expect(names.toSet(), hasLength(names.length));
      expect(
        names.every((n) => RegExp(r'^sheets\.[a-z_]+$').hasMatch(n)),
        isTrue,
      );
    });

    test('when registering handlers then every definition has one', () {
      final registered = {
        for (final t in SheetsToolHandlers.all) t.definition.name,
      };
      expect(
        registered,
        containsAll([for (final t in SheetsTools.all) t.name]),
      );
      expect(registered, contains('drive.create_spreadsheet'));
    });

    test(
      'when serializing schemas then they are closed objects with the '
      'spreadsheet property',
      () {
        for (final t in SheetsTools.all) {
          final json = jsonDecode(jsonEncode(t.toJson())) as Map;
          final schema = json['inputSchema'] as Map;
          expect(schema['type'], 'object', reason: t.name);
          expect(schema['additionalProperties'], isFalse, reason: t.name);
          if (t.name != 'sheets.validate_formula') {
            expect(
              (schema['required'] as List).first,
              'spreadsheet',
              reason: t.name,
            );
          }
          expect(t.scopes, isNotEmpty, reason: t.name);
          expect(t.description.length, greaterThan(40), reason: t.name);
        }
      },
    );

    test('when mutating tools are declared then they need sheets:edit', () {
      for (final t in SheetsTools.all) {
        expect(
          t.scopes,
          t.annotations.readOnly
              ? {McpScope.sheetsRead}
              : {McpScope.sheetsEdit},
          reason: t.name,
        );
      }
    });

    test('when validating an example then the schema accepts it', () {
      expect(
        SheetsTools.setValues.inputSchema.validate({
          'spreadsheet': 'x',
          'range': 'Sheet1!A1',
          'values': [
            ['Name', 1, true, null, '=SUM(B1:B2)'],
          ],
          'input': 'user_entered',
        }),
        isEmpty,
      );
      expect(
        SheetsTools.setValues.inputSchema.validate({
          'spreadsheet': 'x',
          'range': 'A1',
          'values': [
            [
              {'nested': 1},
            ],
          ],
        }),
        isNotEmpty,
      );
    });

    test(
      'when generating assistant tools then the API names are valid and the '
      'spreadsheet is bound',
      () {
        final toolset = AssistantToolset.of(SheetsTools.all);
        for (final t in toolset.tools) {
          expect(
            RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(t.apiName),
            isTrue,
            reason: t.apiName,
          );
          if (t.definition.inputSchema.properties.containsKey('spreadsheet')) {
            expect(t.bound, contains('spreadsheet'));
            expect(
              (t.api.inputSchema['properties'] as Map).keys,
              isNot(contains('spreadsheet')),
            );
          }
        }
      },
    );
  });
}
