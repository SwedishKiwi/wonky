import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show CommandState;
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/themes/theme_import.dart';
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart';

import '../harness/deck_harness.dart';

/// The theme, layout, background, appearance and page setup commands
/// (Slides 05 §2.4, §4–§5, §7, §9; SL-17) run headless through the real
/// dispatcher and undo stack.
void main() {
  late DeckHarness d;
  late String s1, s2, s3, box;

  setUp(() {
    final b = DeckBuilder();
    s1 = b.slide(layoutKey: 'title', title: 'Q3 review');
    s2 = b.slide(title: 'Mission', body: 'Make it effortless');
    s3 = b.slide(layoutKey: 'twoColumns', title: 'Compare');
    box = b.textBox(s3, 'Free', x: 200, y: 100, width: 800, height: 120);
    d = DeckHarness.open(fixture: b);
  });
  tearDown(() => d.dispose());

  DeckModel m() => d.model;
  DeckEditorController ed() => d.editor;
  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      d.services.dispatcher.stateOf(id, args);

  /// Every row of the deck (undo/redo equality).
  Map<String, Object?> dump() =>
      jsonDecode(jsonEncode(m().dump(), toEncodable: (v) => '$v'))
          as Map<String, Object?>;

  Future<void> undoRedo(Map<String, Object?> before) async {
    final after = dump();
    await d.undo();
    expect(dump(), before, reason: 'undo restores every row');
    await d.redo();
    expect(dump(), after, reason: 'redo re-applies every row');
  }

  String themeOfSlide(String slideId) {
    final s = m().slide(slideId)!;
    final l = m().indexes.themes.effectiveLayout(s)!;
    return m().indexes.themes.themeOfLayout(l)!.id;
  }

  String layoutKeyOf(String slideId) =>
      m().indexes.themes.effectiveLayout(m().slide(slideId)!)!.key!;

  String text(String elementId) =>
      SlidesText.plainText(m().element(elementId)!.text).trim();

  SlideElementRec placeholder(String slideId, SlidePlaceholderType type) =>
      m().elementsOf(slideId).firstWhere((e) => e.placeholderType == type);

  group('Given a three-slide deck in the Wonky theme', () {
    test('when the built-in Paper theme is applied to all slides then it is '
        'copied in, becomes the default, every layout is remapped by key and '
        'all content stays — one undo step (05 AC 3)', () async {
      final before = dump();
      final wonky = m().deck!.themeId!;
      final r = await d.run('slides.theme.apply', {
        'builtin': 'paper',
        'scope': 'all',
      });

      expect(r.isOk, isTrue, reason: r.message);
      final paper = (r.data! as Map)['themeId'] as String;
      expect(m().theme(paper)!.sourceKey, startsWith('builtin:paper@'));
      expect(m().deck!.themeId, paper);
      for (final s in [s1, s2, s3]) {
        expect(themeOfSlide(s), paper);
      }
      expect(layoutKeyOf(s1), 'title');
      expect(layoutKeyOf(s2), 'titleBody');
      expect(layoutKeyOf(s3), 'twoColumns');
      expect(
        text(placeholder(s2, SlidePlaceholderType.body).id),
        contains('effortless'),
      );
      expect(text(placeholder(s1, SlidePlaceholderType.title).id), 'Q3 review');
      // The old theme stays (unused) until removed.
      expect(m().theme(wonky), isNotNull);
      expect(d.undoLabels, hasLength(1));
      await undoRedo(before);
    });

    test('when the same built-in is applied twice then no second copy is '
        'made', () async {
      await d.run('slides.theme.apply', {'builtin': 'midnight'});
      final n = m().count(SlidesTables.deckTheme);
      await d.run('slides.theme.apply', {'builtin': 'midnight'});
      expect(m().count(SlidesTables.deckTheme), n);
    });

    test('when a theme is applied to the selected slides then only they '
        'change and the default theme is kept', () async {
      final wonky = m().deck!.themeId!;
      ed().selectSlides([s2]);
      final r = await d.run('slides.theme.apply', {
        'builtin': 'swiss',
        'scope': 'selected',
      });
      final swiss = (r.data! as Map)['themeId'] as String;

      expect(themeOfSlide(s2), swiss);
      expect(themeOfSlide(s1), wonky);
      expect(themeOfSlide(s3), wonky);
      expect(m().deck!.themeId, wonky);
    });

    test('when an existing deck theme is re-applied by id then nothing is '
        'copied', () async {
      final r = await d.run('slides.theme.apply', {
        'builtin': 'studio',
        'slideIds': [s3],
      });
      final studio = (r.data! as Map)['themeId'] as String;
      final n = m().count(SlidesTables.deckTheme);
      await d.run('slides.theme.apply', {'themeId': studio, 'scope': 'all'});
      expect(m().count(SlidesTables.deckTheme), n);
      expect(m().deck!.themeId, studio);
      expect(themeOfSlide(s1), studio);
    });

    test(
      'when the appearance is switched then one column changes in one '
      'undo step, and the command reports the checked state (05 AC 2)',
      () async {
        final before = dump();
        expect(
          state('slides.deck.setAppearance', {'appearance': 'light'}).checked,
          isTrue,
        );
        await d.run('slides.deck.setAppearance', {'appearance': 'dark'});

        expect(m().deck!.appearance, SlideAppearance.dark);
        expect(
          state('slides.deck.setAppearance', {'appearance': 'dark'}).checked,
          isTrue,
        );
        expect(d.undoLabels, hasLength(1));
        await undoRedo(before);
        // Without an argument it toggles.
        await d.run('slides.deck.setAppearance');
        expect(m().deck!.appearance, SlideAppearance.light);
      },
    );
  });

  group('Given slides with placeholders (05 §5.4)', () {
    test(
      'when the Title layout is applied to a Title and content slide then '
      'the title is re-pointed, the filled body stays as a regular element '
      'in place, and the empty subtitle instance is created (05 AC 5)',
      () async {
        final before = dump();
        final body = placeholder(s2, SlidePlaceholderType.body);
        final titleLayout = m().indexes.themes.layoutByKey(
          m().deck!.themeId!,
          'title',
        )!;
        ed().selectSlides([s2]);
        await d.run('slides.slide.applyLayout', {'layoutId': titleLayout.id});

        expect(m().slide(s2)!.layoutId, titleLayout.id);
        final title = placeholder(s2, SlidePlaceholderType.title);
        expect(m().element(title.placeholderOf!)!.layoutId, titleLayout.id);
        final kept = m().element(body.id)!;
        expect(kept.placeholderOf, isNull);
        expect(kept.placeholderType, isNull);
        expect(kept.x, isNotNull, reason: 'frame materialized');
        expect(text(kept.id), contains('effortless'));
        expect(
          m()
              .elementsOf(s2)
              .where((e) => e.placeholderType == SlidePlaceholderType.subtitle),
          hasLength(1),
        );
        await undoRedo(before);
      },
    );

    test('when a moved title is reset to the layout then its frame '
        'inherits again', () async {
      final title = placeholder(s2, SlidePlaceholderType.title);
      d.registerOp(
        'test.move',
        (a) => UpdateFrames([
          FrameUpdate(title.id, x: 10, y: 20, width: 300, height: 90),
        ]),
      );
      await d.run('test.move');
      expect(m().element(title.id)!.x, isNotNull);
      ed().selectSlides([s2]);
      await d.run('slides.slide.resetToLayout');
      expect(m().element(title.id)!.x, isNull);
    });
  });

  group('Given page setup (05 §7)', () {
    test('when 16:9 becomes 4:3 with Scale content then the size changes, '
        'slide frames are letterboxed and built-in layouts are regenerated '
        'in one undo step (05 AC 6)', () async {
      final before = dump();
      final title = placeholder(s2, SlidePlaceholderType.title);
      final layoutTitle = m().element(title.placeholderOf!)!;
      final r = await d.run('slides.deck.setSize', {
        'preset': 'standard4x3',
        'scaleContent': true,
      });

      expect(r.isOk, isTrue, reason: r.message);
      final deck = m().deck!;
      expect([deck.width, deck.height], [1440, 1080]);
      expect(deck.sizePreset, SlideSizeKind.standard4x3);
      final regenerated = m().element(layoutTitle.id)!;
      expect(regenerated.width, lessThan(layoutTitle.width!));
      expect(regenerated.x! + regenerated.width!, lessThanOrEqualTo(1440));
      // Slide content is letterboxed: s = 0.75, centered vertically.
      final b = m().element(box)!;
      expect([b.x, b.y, b.width, b.height], [150, 210, 600, 90]);
      expect(d.undoLabels, hasLength(1));
      await undoRedo(before);
    });

    test('when Don\'t scale is chosen then layout frames keep their su '
        'values', () async {
      final title = placeholder(s2, SlidePlaceholderType.title);
      final layoutTitle = m().element(title.placeholderOf!)!;
      await d.run('slides.deck.setSize', {
        'preset': 'square',
        'scaleContent': false,
      });
      expect(m().deck!.width, 1080);
      expect(m().element(layoutTitle.id)!.width, layoutTitle.width);
    });

    test('when a custom size is invalid then nothing changes', () async {
      final r = await d.run('slides.deck.setSize', {
        'preset': 'custom',
        'width': 100,
        'height': 1080,
      });
      expect(r.isOk, isFalse);
      expect(m().deck!.width, 1920);
    });

    test('when the numbering is set then the deck columns change in one '
        'step', () async {
      final before = dump();
      await d.run('slides.deck.setNumbering', {
        'showSlideNumbers': true,
        'firstSlideNumber': 0,
        'footerText': 'Confidential',
      });
      final deck = m().deck!;
      expect(deck.showSlideNumbers, isTrue);
      expect(deck.firstSlideNumber, 0);
      expect(deck.footerText, 'Confidential');
      await undoRedo(before);
    });
  });

  group('Given slide backgrounds and master elements (04 §7.4)', () {
    test(
      'when a theme color is set as background then the slide stores a '
      'solid theme fill; reset inherits again; apply to all copies it',
      () async {
        ed().selectSlides([s1]);
        await d.run('slides.slide.setBackground', {'color': 'theme:bg2'});
        final json = jsonDecode(m().slide(s1)!.backgroundJson!) as Map;
        expect((json['fill'] as Map)['color'], 'theme:bg2');

        await d.run('slides.slide.applyBackgroundToAll');
        expect(m().slide(s3)!.backgroundJson, m().slide(s1)!.backgroundJson);

        await d.run('slides.slide.setBackground', {'reset': true});
        expect(m().slide(s1)!.backgroundJson, isNull);
        expect(m().slide(s3)!.backgroundJson, isNotNull);
      },
    );

    test('when an invalid fill is given then the command fails', () async {
      final r = await d.run('slides.slide.setBackground', {
        'fill': {'type': 'bogus'},
      });
      expect(r.isOk, isFalse);
    });

    test('when master elements are hidden then the toggle is checked and '
        'toggles back', () async {
      ed().selectSlides([s2, s3]);
      await d.run('slides.slide.setHideMasterElements');
      expect(m().slide(s2)!.hideMasterElements, isTrue);
      expect(m().slide(s3)!.hideMasterElements, isTrue);
      expect(state('slides.slide.setHideMasterElements').checked, isTrue);
      await d.run('slides.slide.setHideMasterElements');
      expect(m().slide(s2)!.hideMasterElements, isFalse);
    });
  });

  group('Given the deck\'s themes (05 §9 ⋮ menu)', () {
    late String wonky;
    late String paper;

    setUp(() async {
      wonky = m().deck!.themeId!;
      final r = await d.run('slides.theme.apply', {
        'builtin': 'paper',
        'slideIds': [s3],
      });
      paper = (r.data! as Map)['themeId'] as String;
    });

    test('when a theme is renamed, duplicated and set as default then each '
        'is one step', () async {
      await d.run('slides.theme.rename', {'themeId': paper, 'name': 'Brand'});
      expect(m().theme(paper)!.name, 'Brand');

      final r = await d.run('slides.theme.duplicate', {'themeId': paper});
      final copy = (r.data! as Map)['themeId'] as String;
      expect(m().theme(copy)!.name, 'Brand copy');
      expect(
        m().indexes.themes.layoutsOfTheme(copy),
        hasLength(m().indexes.themes.layoutsOfTheme(paper).length),
      );

      expect(
        state('slides.theme.setDefault', {'themeId': wonky}).enabled,
        isFalse,
      );
      await d.run('slides.theme.setDefault', {'themeId': paper});
      expect(m().deck!.themeId, paper);
      expect(d.undoLabels, hasLength(4));
    });

    test('when a used theme is removed then it is refused; unused themes '
        'are removed together, keeping the default', () async {
      expect(state('slides.theme.delete', {'themeId': paper}).enabled, isFalse);
      await d.run('slides.theme.duplicate', {'themeId': paper});
      await d.run('slides.theme.apply', {'builtin': 'mono', 'scope': 'all'});
      // Wonky, Paper and the copy are unused now; Mono is the default.
      expect(state('slides.theme.removeUnused').enabled, isTrue);
      final r = await d.run('slides.theme.removeUnused');
      expect((r.data! as Map)['removed'], 3);
      expect(m().themes, hasLength(1));
      expect(state('slides.theme.removeUnused').enabled, isFalse);
      await d.undo();
      expect(m().themes, hasLength(4));
    });
  });

  group('Given another presentation with a theme (05 §9 import, AC 7)', () {
    late DeckModel source;
    const sourceItem = '01923456-789a-7bcd-8ef0-0000000000ee';
    final copies = <(String, String, String)>[];

    setUp(() {
      final b = DeckBuilder(deckId: sourceItem)..theme('botanical');
      b.slide(layoutKey: 'title', title: 'Garden');
      source = b.build();
      // The master's background is an uploaded image (re-homed).
      final master = source.mastersOf(source.themes.single.id).single;
      final withImage = DeckModel.fromRows(sourceItem, [
        for (final r in b.rows)
          if (r.$2[SlidesCols.id] == master.id)
            (
              r.$1,
              {
                ...r.$2,
                SlidesCols.backgroundJson: jsonEncode({
                  'v': 1,
                  'fill': {
                    'v': 1,
                    'type': 'image',
                    'fileUuid': '0192aaaa-0000-7000-8000-000000000001',
                    'fit': 'cover',
                  },
                }),
              },
            )
          else
            r,
      ]);
      source = withImage;
      copies.clear();
      ThemeImport.debugFetch = (item) async => jsonEncode({
        'v': 1,
        'sourceItemUuid': item.uuid,
        'defaultThemeId': source.deck!.themeId,
        'themes': [
          for (final t in source.themes)
            {...SlidesClipboardCodec.themeEntry(source, t), 'usedBy': 1},
        ],
      });
      ThemeImport.debugCopy = (c, target) async =>
          copies.add((c.sourceFileUuid, c.newFileUuid, target.uuid));
    });
    tearDown(() {
      ThemeImport.debugFetch = null;
      ThemeImport.debugCopy = null;
    });

    test('when its theme is imported and applied then masters, layouts and '
        'decorations arrive with the background image re-homed into this '
        'deck, in one undo step', () async {
      final before = dump();
      final r = await d.run('slides.theme.import', {
        'itemUuid': sourceItem,
        'apply': true,
      });

      expect(r.isOk, isTrue, reason: r.message);
      final id = (r.data! as Map)['themeId'] as String;
      expect(
        id,
        SlidesIds.themeCopyId(
          m().deckId,
          SlidesIds.deckThemeSourceKey(sourceItem, source.themes.single.id),
        ),
      );
      final t = m().theme(id)!;
      expect(t.name, 'Botanical');
      expect(
        m().indexes.themes.layoutsOfTheme(id),
        hasLength(
          source.indexes.themes.layoutsOfTheme(source.themes.single.id).length,
        ),
      );
      expect(m().deck!.themeId, id);
      expect(themeOfSlide(s2), id);
      // The image was copied into this deck and the copy is referenced.
      expect(copies, hasLength(1));
      expect(copies.single.$1, '0192aaaa-0000-7000-8000-000000000001');
      expect(copies.single.$3, m().deckId);
      final master = m().mastersOf(id).single;
      expect(
        master.columns[SlidesCols.backgroundJson],
        contains(copies.single.$2),
      );
      expect(d.undoLabels, hasLength(1));
      await undoRedo(before);
    });

    test(
      'when it is imported twice then the second import adds nothing',
      () async {
        await d.run('slides.theme.import', {'itemUuid': sourceItem});
        final n = m().count(SlidesTables.deckTheme);
        final rows = dump();
        await d.run('slides.theme.import', {'itemUuid': sourceItem});
        expect(m().count(SlidesTables.deckTheme), n);
        expect(dump(), rows);
        // The re-homed copy got the same uuid both times.
        expect(copies.map((c) => c.$2).toSet(), hasLength(1));
      },
    );

    test('when the server can not be reached then the import fails with a '
        'message', () async {
      ThemeImport.debugFetch = (item) async => throw StateError('offline');
      final r = await d.run('slides.theme.import', {'itemUuid': sourceItem});
      expect(r.isOk, isFalse);
    });
  });
}
