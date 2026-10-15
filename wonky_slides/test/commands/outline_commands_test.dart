import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/editor_screen/slide_labels.dart';
import 'package:wonky_slides/features/outline_view/outline_body.dart';
import 'package:wonky_slides/features/outline_view/outline_controller.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../harness/deck_harness.dart';

/// The outline view's commands (Slides 04 §10; SL-34) run headless with
/// explicit lines through the real dispatcher and undo stack.
void main() {
  late DeckBuilder b;
  late String s1, s2, s3, image;
  late DeckHarness d;

  setUp(() {
    b = DeckBuilder(title: 'Outline');
    s1 = b.slide(title: 'Our mission', body: 'Make it easy\nOffline first');
    s2 = b.slide(title: 'The problem', body: 'Too slow');
    s3 = b.slide(title: 'Demo');
    image = b.element(s3, ElementKind.image);
    d = DeckHarness.open(fixture: b);
  });
  tearDown(() => d.dispose());

  DeckModel m() => d.model;
  List<String> titles() => [
    for (final e in m().indexes.order.entries) SlideLabels.title(m(), e.id),
  ];
  List<String> bullets(String slide) =>
      OutlineSlideParts.of(m(), slide).bodyLines.lines;
  List<int> levels(String slide) => [
    for (final p in OutlineSlideParts.of(m(), slide).bodyLines.paragraphs)
      p.level,
  ];
  Object dump() => m().dump();

  Future<void> roundTrip(Object before) async {
    final after = dump();
    await d.undo();
    expect(dump(), before, reason: 'after undo');
    await d.redo();
    expect(dump(), after, reason: 'after redo');
  }

  group('Given a deck with titles and bullets', () {
    test('when a title is set then a bold word in it is kept, in one '
        'undoable step', () async {
      final title = m()
          .elementsOf(s1)
          .firstWhere((e) => e.placeholderType == SlidePlaceholderType.title);
      d.session.execute(
        SetText(
          ElementText(title.id),
          jsonEncode([
            {'insert': 'Our '},
            {
              'insert': 'mission',
              'attributes': {'bold': true},
            },
            {'insert': '\n'},
          ]),
        ),
      );
      final before = dump();

      await d.run('slides.outline.setTitle', {
        'slideId': s1,
        'text': 'Our big mission',
      });

      final runs = OutlineSlideParts.of(m(), s1).titleBody[0].runs;
      expect(runs.map((r) => r.text), ['Our big ', 'mission']);
      expect(runs[0].bold, isFalse);
      expect(runs[1].bold, isTrue);
      expect(d.undoLabels, hasLength(1));
      await roundTrip(before);
    });

    test('when bullets are set as a Delta then the body placeholder holds '
        'them', () async {
      final before = dump();
      final body = OutlineBody([
        OutlineParagraph.plain('A'),
        OutlineParagraph.plain('B', level: 1),
      ]);

      await d.run('slides.outline.setBody', {
        'slideId': s2,
        'delta': body.toJson(),
      });

      expect(bullets(s2), ['A', 'B']);
      expect(levels(s2), [0, 1]);
      await roundTrip(before);
    });

    test('when Enter is pressed inside a title then a new slide follows '
        'with the text after the caret as its title', () async {
      final before = dump();

      final r = await d.run('slides.outline.newSlideAfter', {
        'slideId': s1,
        'index': -1,
        'offset': 4,
      });

      // (Labels are trimmed.)
      expect(titles(), ['Our', 'mission', 'The problem', 'Demo']);
      expect(d.editor.currentSlideId, (r.data as Map)['slideId']);
      expect(d.undoLabels, hasLength(1));
      await roundTrip(before);
    });

    test('when Enter is pressed in a bullet then it splits', () async {
      final before = dump();

      await d.run('slides.outline.newLine', {
        'slideId': s1,
        'index': 0,
        'offset': 4,
      });

      expect(bullets(s1), ['Make', ' it easy', 'Offline first']);
      await roundTrip(before);
    });

    test('when a bullet is indented and outdented then its level '
        'changes', () async {
      await d.run('slides.outline.indent', {'slideId': s1, 'index': 1});
      expect(levels(s1), [0, 1]);

      await d.run('slides.outline.outdent', {'slideId': s1, 'index': 1});
      expect(levels(s1), [0, 0]);
      expect(d.undoLabels, hasLength(2));
    });

    test('when a top-level bullet is outdented then it is promoted to a new '
        'slide carrying the bullets after it', () async {
      await d.run('slides.outline.setBody', {
        'slideId': s1,
        'delta': OutlineBody([
          OutlineParagraph.plain('Keep'),
          OutlineParagraph.plain('Promote me'),
          OutlineParagraph.plain('Child', level: 1),
          OutlineParagraph.plain('Sibling'),
        ]).toJson(),
      });
      final before = dump();

      final r = await d.run('slides.outline.outdent', {
        'slideId': s1,
        'index': 1,
      });

      final id = (r.data as Map)['slideId'] as String;
      expect(titles(), ['Our mission', 'Promote me', 'The problem', 'Demo']);
      expect(bullets(s1), ['Keep']);
      expect(bullets(id), ['Child', 'Sibling']);
      expect(levels(id), [0, 0]);
      await roundTrip(before);
    });

    test('when a slide title is indented then the slide becomes bullets of '
        'the previous slide', () async {
      final before = dump();

      await d.run('slides.outline.indent', {'slideId': s2, 'index': -1});

      expect(titles(), ['Our mission', 'Demo']);
      expect(bullets(s1), [
        'Make it easy',
        'Offline first',
        'The problem',
        'Too slow',
      ]);
      expect(levels(s1), [0, 0, 0, 1]);
      await roundTrip(before);
    });

    test('when a slide with other objects would be demoted then it is '
        'refused', () {
      final st = d.services.dispatcher.stateOf('slides.outline.indent', {
        'slideId': s3,
        'index': -1,
      });
      expect(st.enabled, isFalse);
      expect(m().element(image), isNotNull);
    });

    test('when lines move then bullets swap and slides reorder', () async {
      await d.run('slides.outline.moveDown', {'slideId': s1, 'index': 0});
      expect(bullets(s1), ['Offline first', 'Make it easy']);
      expect(
        d.services.dispatcher.stateOf('slides.outline.moveDown', {
          'slideId': s1,
          'index': 1,
        }).enabled,
        isFalse,
      );

      await d.run('slides.outline.moveUp', {'slideId': s2, 'index': -1});
      expect(titles(), ['The problem', 'Our mission', 'Demo']);
    });

    test('when Backspace joins a bullet then it is appended to the one '
        'above', () async {
      final before = dump();

      await d.run('slides.outline.joinLine', {'slideId': s1, 'index': 1});

      expect(bullets(s1), ['Make it easyOffline first']);
      await roundTrip(before);
    });

    test('when Backspace is pressed in the title of an empty slide then the '
        'slide is deleted', () async {
      final r = await d.run('slides.outline.newSlideAfter', {
        'slideId': s3,
        'title': '',
      });
      final id = (r.data as Map)['slideId'] as String;
      expect(titles(), hasLength(4));

      await d.run('slides.outline.joinLine', {'slideId': id, 'index': -1});

      expect(m().slide(id), isNull);
      expect(d.editor.currentSlideId, s3);
    });

    test('when the outline is copied then Markdown has titles and '
        'bullets', () async {
      final r = await d.h.invoke(
        'slides.outline.copyMarkdown',
        const {},
        InvocationSource.mcp,
      );

      expect(
        (r.data as Map)['markdown'],
        '# Our mission\n\n- Make it easy\n- Offline first\n\n'
        '# The problem\n\n- Too slow\n\n# Demo',
      );
    });
  });

  group('Given no focused outline line', () {
    test('when the keyboard commands are read then they are disabled with '
        'a reason', () {
      for (final id in [
        'slides.outline.newSlideAfter',
        'slides.outline.newLine',
        'slides.outline.indent',
        'slides.outline.outdent',
        'slides.outline.joinLine',
      ]) {
        final st = d.services.dispatcher.stateOf(id);
        expect(st.enabled, isFalse, reason: id);
        expect(st.disabledReason, isNotEmpty, reason: id);
      }
    });
  });

  group('Given a slide without a title placeholder instance', () {
    test('when its title is set then an instance of the layout title is '
        'added (inheriting its frame) in one step', () async {
      final title = m()
          .elementsOf(s2)
          .firstWhere((e) => e.placeholderType == SlidePlaceholderType.title);
      d.session.execute(DeleteElements([title.id]));
      final parts = OutlineSlideParts.of(m(), s2);
      expect(parts.title, isNull);
      expect(parts.titleEditable, isTrue);
      final before = dump();

      await d.run('slides.outline.setTitle', {'slideId': s2, 'text': 'Back'});

      final added = OutlineSlideParts.of(m(), s2).title!;
      expect(added.frame, isNull);
      expect(SlideLabels.title(m(), s2), 'Back');
      expect(d.undoLabels, hasLength(1));
      await roundTrip(before);
    });
  });
}
