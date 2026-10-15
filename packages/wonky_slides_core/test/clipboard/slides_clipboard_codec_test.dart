import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/copy.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart';

import '../support/planner_fixture.dart';

const _otherDeck = '01923456-789a-7bcd-8ef0-0000000000b2';

/// A blank deck B (other id) with a title slide.
MemoryDeck _deckB({String themeKey = 'wonky'}) {
  final d = MemoryDeck(
    model: DeckModel(deckId: _otherDeck),
    userId: testUserId2,
    planner: const SlidesPlanner(),
    ids: SequentialIdGenerator(3000000),
  );
  d.execute(CreateDeck(deckId: _otherDeck, title: 'B', themeKey: themeKey));
  return d;
}

/// Through the clipboard as text (copy → system clipboard → paste).
Map<String, Object?> _roundTrip(Map<String, Object?> p) =>
    SlidesClipboardCodec.decode(SlidesClipboardCodec.encode(p))!;

String _plain(String? json) => SlidesText.plainText(json).trim();

void main() {
  final f = PlannerFixture();
  late MemoryDeck deck;
  setUp(() => deck = f.session());

  group('Given elements copied from a slide', () {
    test('when encoding and decoding then the payload is lossless and an '
        'element group brings its children', () {
      final p = SlidesClipboardCodec.copyElements(deck.model, [
        f.shape,
        f.grp,
        f.child1, // inside the selected group: not duplicated
      ]);

      expect(p['kind'], 'elements');
      expect(p['sourceDeckId'], testDeckId);
      expect(p['sourceSlideId'], f.s3);
      final ids = [for (final e in p['elements']! as List) (e as Map)['id']];
      expect(ids, unorderedEquals([f.shape, f.grp, f.child1, f.child2]));
      expect(p['builds'], hasLength(1), reason: 'the shape has a build');
      final back = _roundTrip(p);
      expect(back['elements'], hasLength(4));
      expect(
        (back['elements']! as List).cast<Map<String, Object?>>().map(
          (e) => e['text'],
        ),
        (p['elements']! as List).cast<Map<String, Object?>>().map(
          (e) => e['text'],
        ),
      );
    });

    test('when pasting into another deck then they arrive with new ids at '
        'the same positions, with their builds, and match keys kept', () {
      final p = _roundTrip(
        SlidesClipboardCodec.copyElements(deck.model, [f.shape, f.grp]),
      );
      final b = _deckB();
      final slide = b.model.slides.single.id;

      final plan = b.execute(PasteElements(p, slide));

      final pasted = (plan.result['elementIds']! as List).cast<String>();
      expect(pasted, hasLength(2));
      final shape = b.model.element(pasted.first)!;
      expect(shape.id, isNot(f.shape));
      expect(shape.frame!.x, deck.model.element(f.shape)!.frame!.x);
      expect(
        shape.columns[ElementCols.matchKey],
        deck.model.element(f.shape)!.columns[ElementCols.matchKey],
      );
      expect(_plain(shape.columns[SlidesCols.text] as String?), 'Box');
      expect(b.model.buildsOf(slide), hasLength(1));
      expect(
        b.model.allElementsOf(slide).where((e) => e.parentId == pasted[1]),
        hasLength(2),
      );
    });

    test('when pasting on the source slide then the copies are offset by '
        '32 su and get new match keys', () {
      final p = SlidesClipboardCodec.copyElements(deck.model, [f.shape]);
      final plan = deck.execute(PasteElements(p, f.s3));
      final e = deck.model.element(
        (plan.result['elementIds']! as List).single as String,
      )!;
      final src = deck.model.element(f.shape)!;
      expect(e.frame!.x, src.frame!.x + 32);
      expect(
        e.columns[ElementCols.matchKey],
        isNot(src.columns[ElementCols.matchKey]),
      );
    });

    test('when pasting elements and slides then the plans map old to new '
        'ids (comments follow cut objects, 09 §3.2)', () {
      final p = SlidesClipboardCodec.copyElements(deck.model, [f.shape]);
      final plan = deck.execute(PasteElements(p, f.s3));
      final pasted = (plan.result['elementIds']! as List).single as String;

      expect(plan.result['elementIdMap'], {f.shape: pasted});

      final s = SlidesClipboardCodec.copySlides(deck.model, slideIds: [f.s3]);
      final slides = deck.execute(PasteSlides(s));
      final newSlide = (slides.result['slideIds']! as List).single as String;
      final elementMap = slides.result['elementIdMap']! as Map;
      expect(slides.result['slideIdMap'], {f.s3: newSlide});
      expect(elementMap[f.shape], isNotNull);
      expect(
        deck.model.element(elementMap[f.shape] as String)!.slideId,
        newSlide,
      );
    });

    test(
      'when a placeholder instance without a frame is copied then the '
      'payload carries its effective frame and pastes in place elsewhere',
      () {
        final title = deck.model
            .elementsOf(f.title)
            .firstWhere((e) => e.placeholderType != null);
        expect(title.frame, isNull);
        final p = SlidesClipboardCodec.copyElements(deck.model, [title.id]);
        final row = (p['elements']! as List).single as Map;
        expect(row['x'], isA<double>());
        expect(row['width'], greaterThan(0));

        final b = _deckB();
        final plan = b.execute(
          PasteElements(_roundTrip(p), b.model.slides.single.id),
        );
        final e = b.model.element(
          (plan.result['elementIds']! as List).single as String,
        )!;
        expect(e.frame!.x, row['x']);
        expect(e.placeholderType, isNull, reason: 'a regular element');
      },
    );

    test('when a table, a code block and a linked chart are copied then '
        'cells, states and the link paste with deterministic ids', () {
      final p = _roundTrip(
        SlidesClipboardCodec.copyElements(deck.model, [
          f.table,
          f.code,
          f.chart,
        ]),
      );
      expect(p['tableAxes'], hasLength(6));
      expect(p['tableCells'], isNotEmpty);
      expect(p['codeStates'], hasLength(2));
      expect(p['chartLinks'], hasLength(1));

      final b = _deckB();
      final slide = b.model.slides.single.id;
      final ids =
          (b.execute(PasteElements(p, slide)).result['elementIds']! as List)
              .cast<String>();
      final table = ids[0], code = ids[1], chart = ids[2];
      final cells = b.model.cellsOf(table).toList();
      expect(cells, hasLength(deck.model.cellsOf(f.table).length));
      for (final c in cells) {
        expect(
          c.id,
          SlidesIds.tableCellId(
            table,
            c.columns[TableCellCols.rowId]! as String,
            c.columns[TableCellCols.columnId]! as String,
          ),
        );
      }
      expect(b.model.codeStatesOf(code), hasLength(2));
      final link = b.model.chartLinkOf(chart)!;
      expect(link.id, SlidesIds.chartLinkId(chart));
      expect(
        link.columns[ChartLinkCols.chartObjectId],
        '00000000-0000-4000-8000-0000000000e2',
      );
    });
  });

  group('Given slides and groups copied', () {
    test('when copying a group then the payload holds the group with its '
        'slides in order and the theme they use', () {
      final p = SlidesClipboardCodec.copySlides(
        deck.model,
        groupIds: [f.group],
      );

      expect(p['kind'], 'groups');
      final g = (p['groups']! as List).single as Map;
      expect(g['title'], 'Part 1');
      expect(g['color'], 'blue');
      expect(g['slides'], [f.g1, f.g2]);
      expect(
        [for (final s in p['slides']! as List) (s as Map)['id']],
        [f.g1, f.g2],
      );
      final themes = p['themes']! as List;
      expect(themes, hasLength(1));
      expect((themes.single as Map)['layouts'], isNotEmpty);
    });

    test('when pasting into another deck with Keep source formatting twice '
        'then the source theme is copied once and the group arrives', () {
      final p = _roundTrip(
        SlidesClipboardCodec.copySlides(
          deck.model,
          groupIds: [f.group],
          slideIds: [f.s2],
        ),
      );
      final b = _deckB(themeKey: 'midnight');
      final themesBefore = b.model.themes.length;

      b.execute(PasteSlides(p, themeMode: PasteThemeMode.keepSource));
      expect(b.model.themes, hasLength(themesBefore + 1));
      expect(b.model.groups.single.title, 'Part 1');
      expect(b.model.slides, hasLength(1 + 3));

      b.execute(PasteSlides(p, themeMode: PasteThemeMode.keepSource));
      expect(b.model.themes, hasLength(themesBefore + 1), reason: 'dedupe');
      expect(b.model.slides, hasLength(1 + 6));
    });

    test('when pasting with Use destination theme then layouts map by key '
        'into the destination theme', () {
      final p = _roundTrip(
        SlidesClipboardCodec.copySlides(deck.model, slideIds: [f.s2]),
      );
      final b = _deckB(themeKey: 'midnight');
      b.execute(PasteSlides(p));
      final pasted = b.model.slides.last;
      final layout = b.model.layout(pasted.layoutId!)!;
      expect(
        layout.key,
        deck.model.layout(deck.model.slide(f.s2)!.layoutId!)!.key,
      );
      expect(b.model.master(layout.masterId!)!.themeId, b.model.deck!.themeId);
    });

    test('when converting to text then slides become an outline and '
        'Markdown headings with bullets', () {
      final p = SlidesClipboardCodec.copySlides(
        deck.model,
        slideIds: [f.title, f.s2],
      );

      final text = SlidesClipboardCodec.plainText(p);
      expect(text.split('\n').first, 'Hello');
      expect(text.split('\n'), containsAllInOrder(['Agenda', '  One']));
      final md = SlidesClipboardCodec.markdown(p);
      expect(md, startsWith('# Hello'));
      expect(md, contains('# Agenda\n\n- '));
      expect(md, contains('\n- One'));
    });

    test('when converting elements to text then tables become tab-separated '
        'rows and code its first state', () {
      final p = SlidesClipboardCodec.copyElements(deck.model, [
        f.table,
        f.code,
      ]);
      final text = SlidesClipboardCodec.plainText(p);
      expect(text, contains('A1\t\t'));
      expect(text, contains('void main() {}'));
    });
  });

  group('Given untrusted clipboard text', () {
    test('when it is not a Slides payload then decode returns null', () {
      expect(SlidesClipboardCodec.decode('hello'), isNull);
      expect(SlidesClipboardCodec.decode('{"format":"other"}'), isNull);
      expect(
        SlidesClipboardCodec.decode(
          '{"format":"wonky-slides-clipboard","v":2,"kind":"slides"}',
        ),
        isNull,
      );
      expect(
        SlidesClipboardCodec.decode('{"format":"wonky-slides-clipboard",'),
        isNull,
      );
    });

    test('when sanitizing then unknown columns, bad ids, embeds and '
        'orphaned dependents are dropped and text is normalized', () {
      const el = '00000000-0000-4000-8000-0000000000c1';
      final p = SlidesClipboardCodec.sanitize({
        'format': 'wonky-slides-clipboard',
        'v': 1,
        'kind': 'elements',
        'sourceDeckId': 'not-a-uuid',
        'elements': [
          {
            'id': el.toUpperCase(),
            'kind': 'rocket',
            'x': 1.0,
            'evil': 'drop me',
            'text': jsonEncode([
              {
                'insert': {'image': 'x'},
              },
              {
                'insert': 'Hi',
                'attributes': {'bold': true, 'onclick': 'x'},
              },
            ]),
          },
          {'id': 'nope', 'kind': 'shape'},
        ],
        'builds': [
          {
            'id': '00000000-0000-4000-8000-0000000000c2',
            'elementId': '00000000-0000-4000-8000-0000000000c3',
          },
        ],
      });

      expect(p.containsKey('sourceDeckId'), isFalse);
      final e = (p['elements']! as List).single as Map<String, Object?>;
      expect(e['id'], el);
      expect(e['kind'], 'shape');
      expect(e.containsKey('evil'), isFalse);
      expect(e['flipH'], isFalse);
      expect(jsonDecode(e['text']! as String), [
        {
          'insert': 'Hi',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);
      expect(p['builds'], isEmpty);
    });

    test('when a group lists slides that are not in the payload then they '
        'are dropped from it', () {
      final p = SlidesClipboardCodec.copySlides(
        deck.model,
        groupIds: [f.group],
      );
      ((p['groups']! as List).single as Map)['slides'] = [
        f.g1,
        '00000000-0000-4000-8000-0000000000c9',
      ];
      final back = _roundTrip(p);
      expect(((back['groups']! as List).single as Map)['slides'], [f.g1]);
    });

    test('when the payload is too large then sanitize refuses it', () {
      final rows = [
        for (var i = 0; i <= SlidesClipboardCodec.maxRows; i++)
          {'id': SequentialIdGenerator(i + 1).newId(), 'kind': 'shape'},
      ];
      expect(
        () => SlidesClipboardCodec.sanitize({
          'format': 'wonky-slides-clipboard',
          'v': 1,
          'kind': 'elements',
          'elements': rows,
        }),
        throwsFormatException,
      );
    });
  });

  group('Given a payload referencing uploaded files', () {
    test('when re-homing then every reference gets the new uuid and the '
        'copies to make are listed', () {
      const file = '00000000-0000-4000-8000-0000000000f1';
      final p = SlidesClipboardCodec.copyElements(deck.model, [f.image]);
      expect(p['files'], [
        {'fileUuid': file, 'itemUuid': testDeckId},
      ]);
      expect(SlidesClipboardCodec.fileUuids(p), {file});

      final (out, files) = SlidesClipboardCodec.rehomeFiles(
        p,
        ids: SequentialIdGenerator(42),
      );

      expect(files, [FileRehome(file, SequentialIdGenerator(42).newId())]);
      final data = jsonDecode(
        ((out['elements']! as List).single as Map)['dataJson']! as String,
      );
      expect(data['src'], 'wonky-file://${files.single.newFileUuid}');
      expect(
        ((out['files']! as List).single as Map)['fileUuid'],
        files.single.newFileUuid,
      );
      expect(SlidesClipboardCodec.fileUuids(out), {files.single.newFileUuid});
      // The original payload is unchanged.
      expect(SlidesClipboardCodec.fileUuids(p), {file});
    });

    test('when nothing references files then re-homing is a no-op', () {
      final p = SlidesClipboardCodec.copyElements(deck.model, [f.shape]);
      final (out, files) = SlidesClipboardCodec.rehomeFiles(p);
      expect(identical(out, p), isTrue);
      expect(files, isEmpty);
    });
  });

  group('Given a text selection', () {
    test('when copied then the payload is normalized text and its plain '
        'text drops the final newline', () {
      final p = _roundTrip(
        SlidesClipboardCodec.copyText(
          Delta()
            ..insert('Bold', {'bold': true, 'font': 'x' * 100})
            ..insert('\tline\n'),
          sourceDeckId: testDeckId,
        ),
      );
      expect(p['kind'], 'text');
      expect((p['text']! as Map)['delta'], [
        {
          'insert': 'Bold',
          'attributes': {'bold': true},
        },
        {'insert': '    line\n'},
      ]);
      expect(SlidesClipboardCodec.plainText(p), 'Bold    line');
    });
  });

  test('checkLimits refuses more slides than a deck can hold', () {
    expect(
      SlidesClipboardCodec.checkLimits({
        'slides': List.filled(3, const <String, Object?>{}),
      }, limits: const SlidesLimits(maxSlidesPerDeck: 2)),
      contains('at most 2 slides'),
    );
    expect(
      SlidesClipboardCodec.checkLimits(
        SlidesClipboardCodec.copySlides(deck.model, slideIds: [f.s2]),
      ),
      isNull,
    );
  });
}
