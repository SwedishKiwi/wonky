import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  group('Given the slides tool catalog', () {
    test('when listing names then they are unique, snake_case and in the '
        'slides, drive or ui.slides namespace', () {
      final names = McpToolCatalog.slides.map((t) => t.name).toList();

      expect(names.toSet().length, names.length);
      for (final n in names) {
        expect(
          n,
          matches(RegExp(r'^(ui\.slides|slides|drive)\.[a-z_]+$')),
          reason: n,
        );
      }
      final all = [
        ...McpToolCatalog.write,
        ...McpToolCatalog.sheets,
        ...McpToolCatalog.drive,
        ...McpToolCatalog.slides,
      ].map((t) => t.name);
      expect(all.toSet().length, all.length);
    });

    test('when serialized then every tool has a closed object schema with '
        'a required deck (except drive and spreadsheet tools) and a scope', () {
      for (final t in SlidesTools.all) {
        final json = t.toJson()['inputSchema']! as Map;
        expect(json['type'], 'object', reason: t.name);
        expect(json['additionalProperties'], isFalse, reason: t.name);
        expect(t.scopes, isNotEmpty, reason: t.name);
        if (t.name.startsWith('slides.') && t != SlidesTools.listSheetCharts) {
          expect(json['required'], contains('deck'), reason: t.name);
        }
      }
    });

    test('when validating slide and element refs then ids, positions and '
        'placeholders are accepted', () {
      final schema = SlidesTools.setText.inputSchema;
      const deck = '0192a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b';

      expect(
        schema.accepts({
          'deck': deck,
          'element': {'slide': 3, 'placeholder': 'title'},
          'text': '**Hello**',
        }),
        isTrue,
      );
      expect(
        schema.accepts({
          'deck': deck,
          'element': 'abc',
          'text': {'markdown': 'x'},
        }),
        isTrue,
      );
      expect(
        schema.accepts({
          'deck': deck,
          'element': {'slide': 0, 'placeholder': 'title'},
          'text': 'x',
        }),
        isFalse,
      );
      expect(
        schema.accepts({
          'deck': deck,
          'element': {'slide': 1, 'placeholder': 'sidebar'},
          'text': 'x',
        }),
        isFalse,
      );
    });

    test('when validating builds then kind and effect are required', () {
      final schema = SlidesTools.setBuilds.inputSchema;
      const deck = '0192a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b';

      expect(
        schema.accepts({
          'deck': deck,
          'slide': 1,
          'builds': [
            {
              'element': {'slide': 1, 'placeholder': 'body'},
              'kind': 'build_in',
              'effect': 'fade',
              'delivery': {'by': 'paragraph'},
            },
          ],
        }),
        isTrue,
      );
      expect(
        schema.accepts({
          'deck': deck,
          'slide': 1,
          'builds': [
            {'element': 'x', 'effect': 'fade'},
          ],
        }),
        isFalse,
      );
    });

    test('when looking up a slides tool by name then it is found', () {
      expect(McpToolCatalog.byName('slides.add_slides'), isNotNull);
      expect(McpToolCatalog.byName('drive.create_presentation'), isNotNull);
    });
  });

  group('Given the ui.slides tools (Slides 11 §5)', () {
    test('when serialized then every tool has a closed object schema with an '
        'optional session_id and the ui:control scope', () {
      for (final t in UiSlidesTools.all) {
        final json = t.toJson()['inputSchema']! as Map;
        expect(json['type'], 'object', reason: t.name);
        expect(json['additionalProperties'], isFalse, reason: t.name);
        expect((json['properties']! as Map).keys, contains('session_id'));
        expect(
          json['required'] ?? const <String>[],
          isNot(contains('session_id')),
        );
        expect(t.scopes, {McpScope.uiControl}, reason: t.name);
        expect(McpToolCatalog.byName(t.name), same(t));
      }
    });

    test('when validating arguments then slide refs, steps, zoom and '
        'present actions follow the schema', () {
      expect(UiSlidesTools.goToSlide.inputSchema.accepts({'slide': 3}), isTrue);
      expect(UiSlidesTools.goToSlide.inputSchema.accepts({}), isFalse);
      expect(
        UiSlidesTools.select.inputSchema.accepts({
          'elements': [
            'abc',
            {'slide': 2, 'placeholder': 'title'},
          ],
        }),
        isTrue,
      );
      final shot = UiSlidesTools.screenshotSlide.inputSchema;
      expect(shot.accepts({'step': 'final', 'scale': 0.5}), isTrue);
      expect(shot.accepts({'step': 2}), isTrue);
      expect(shot.accepts({'step': 'first'}), isFalse);
      expect(shot.accepts({'scale': 4}), isFalse);
      final view = UiSlidesTools.setView.inputSchema;
      expect(view.accepts({'zoom': 'fit', 'view_mode': 'grid'}), isTrue);
      expect(view.accepts({'zoom': 5}), isFalse);
      final control = UiSlidesTools.presentControl.inputSchema;
      expect(control.accepts({'action': 'go_to', 'slide': 4}), isTrue);
      expect(control.accepts({'action': 'rewind'}), isFalse);
      expect(
        UiSlidesTools.present.inputSchema.accepts({'from': 'start'}),
        isTrue,
      );
      expect(UiSlidesTools.present.inputSchema.accepts({'from': 2}), isTrue);
      expect(
        UiSlidesTools.openPanel.inputSchema.accepts({'panel': 'layers'}),
        isTrue,
      );
      expect(
        UiSlidesTools.openPanel.inputSchema.accepts({'panel': 'outline'}),
        isFalse,
      );
    });
  });
}
