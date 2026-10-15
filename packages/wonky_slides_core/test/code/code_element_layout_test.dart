import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';

import '../support/scene_fixture.dart';

const _testNow = '2026-10-15T00:00:00.000Z';

/// A deck with one code element (two states) on a slide with
/// [slideBackground] (hex), and the element [data].
(SceneFixture, DeckModel, String) _deck({
  String? slideBackground,
  Map<String, Object?> data = const {},
}) {
  final f = SceneFixture();
  final code = f.element(
    ElementKind.code,
    w: 800,
    h: 400,
    columns: {
      ElementCols.dataJson: jsonEncode({'v': 1, 'language': 'dart', ...data}),
    },
  );
  SlidesRow state(String id, String key, String src, {String? highlight}) => (
    SlidesTables.codeState,
    {
      for (final c in SlidesTables.columns[SlidesTables.codeState]!) c: null,
      SlidesCols.id: id,
      SlidesCols.elementId: code,
      SlidesCols.sortKey: key,
      CodeStateCols.code: src,
      CodeStateCols.highlight: highlight,
      SlidesCols.createdAt: _testNow,
    },
  );
  final rows = [
    for (final (t, m) in f.b.rows)
      if (t == SlidesTables.slide &&
          m[SlidesCols.id] == f.slideId &&
          slideBackground != null)
        (
          t,
          {
            ...m,
            SlidesCols.backgroundJson: jsonEncode({
              'v': 1,
              'fill': {'v': 1, 'type': 'solid', 'color': slideBackground},
            }),
          },
        )
      else
        (t, m),
    state(
      '00000000-0000-7000-8000-00000000c001',
      'a0',
      'void main() {}',
      highlight: '1',
    ),
    state(
      '00000000-0000-7000-8000-00000000c002',
      'a1',
      'void main() {\n  print(1);\n}',
    ),
  ];
  return (f, DeckModel.fromRows(f.b.deckId, rows), code);
}

CodeScene _codeScene(
  SceneFixture f,
  DeckModel model,
  String id, {
  ScenePurpose purpose = ScenePurpose.edit,
}) => f
    .scene(model: model, purpose: purpose)
    .nodesOf(id)
    .whereType<GroupNode>()
    .first
    .children
    .whereType<CodeNode>()
    .single
    .scene;

void main() {
  group('Given the auto palette', () {
    test('when the slide background is light then the light palette is '
        'used', () {
      final (f, model, id) = _deck(slideBackground: '#ffffff');

      final scene = _codeScene(f, model, id);

      expect(scene.darkPalette, isFalse);
      expect(scene.paletteId, 'wonky-light');
    });

    test('when the slide background is dark then the dark palette is used '
        '(a light deck)', () {
      final (f, model, id) = _deck(slideBackground: '#101820');

      final scene = _codeScene(f, model, id);

      expect(scene.darkPalette, isTrue);
      expect(scene.paletteId, 'wonky-dark');
    });

    test(
      'when the element has its own dark box background then it decides',
      () {
        final (f, model, id) = _deck(
          slideBackground: '#ffffff',
          data: {
            'box': {'background': '#000000'},
          },
        );

        final scene = _codeScene(f, model, id);

        expect(scene.darkPalette, isTrue);
        expect(scene.background, 0xff000000);
      },
    );
  });

  group('Given a fixed palette', () {
    test('when the palette is "dark" then the theme pair\'s dark palette is '
        'used on a light slide', () {
      final (f, model, id) = _deck(data: {'palette': 'dark'});

      expect(_codeScene(f, model, id).darkPalette, isTrue);
    });

    test('when the palette is an id then that palette is used', () {
      final (f, model, id) = _deck(data: {'palette': 'dracula'});

      expect(_codeScene(f, model, id).paletteId, 'dracula');
    });
  });

  group('Given purposes', () {
    test('when editing then the first state is shown without dimming', () {
      final (f, model, id) = _deck();

      final scene = _codeScene(f, model, id);

      expect(scene.stateIndex, 0);
      expect(scene.step, isNull);
    });

    test('when printing then the last state is shown', () {
      final (f, model, id) = _deck();

      final scene = _codeScene(f, model, id, purpose: ScenePurpose.print);

      expect(scene.stateIndex, 1);
      expect(scene.lines, hasLength(3));
    });
  });

  group('Given an element shadow override', () {
    test('when box.shadow is none then the element group has no shadow', () {
      final (f, model, id) = _deck(
        data: {
          'box': {'shadow': 'none'},
        },
      );

      final g = SceneFixture.groupOf(f.scene(model: model), id);

      expect(g.effects.shadows, isEmpty);
    });
  });

  group('Given the theme', () {
    test('when resolving the style then the code font is JetBrains Mono with '
        'its measured metrics', () {
      final theme = DeckThemeResolver().resolve(
        BuiltInThemes.package(BuiltInThemes.defaultKey)!.theme,
        SlideAppearance.light,
      );

      final style = CodeElementLayout.styleOf(
        CodeElementData.fromJson(null),
        theme,
      );

      expect(style.fontFamily, 'JetBrains Mono');
      expect(style.metrics, MonoFontMetrics.jetBrainsMono);
    });
  });

  group('Given the bundled JetBrains Mono file', () {
    test(
      'when reading its tables then they match the built-in metrics',
      () async {
        final lib = await Isolate.resolvePackageUri(
          Uri.parse('package:wonky_fonts/wonky_fonts.dart'),
        );
        final file = File.fromUri(
          lib!.resolve('../fonts/JetBrainsMono-Regular.ttf'),
        );

        final m = MonoFontMetrics.fromTtf(
          'JetBrains Mono',
          file.readAsBytesSync(),
        )!;

        expect(m, MonoFontMetrics.jetBrainsMono);
      },
    );
  });
}
