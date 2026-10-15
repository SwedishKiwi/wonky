import 'dart:convert';
import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/copy.dart';
import 'package:wonky_slides_core/maintenance.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart';

import '../support/planner_fixture.dart';

const _newDeck = '01923456-789a-7bcd-8ef0-00000000c0de';
final _now = DateTime.utc(2026, 10, 15, 12);

DeckCopy _copy(
  DeckModel m, {
  String deckId = _newDeck,
  int seed = 700000,
  String? title,
  bool rehomeFiles = true,
}) => DeckCopier.copy(
  m,
  deckId: deckId,
  userId: testUserId2,
  now: _now,
  title: title,
  ids: SequentialIdGenerator(seed),
  rehomeFiles: rehomeFiles,
);

DeckModel _model(DeckCopy c) => DeckModel.fromRows(c.deckId, c.rows);

/// Every row id of [m] in the dashed and base-62 forms.
Set<String> _idsOf(DeckModel m) => {
  for (final t in m.dump().values)
    for (final id in t.keys) ...[id, Base62Uuid.encode(id)],
};

/// Every string value in [rows] (JSON columns decoded).
Iterable<String> _strings(List<SlidesRow> rows) sync* {
  Iterable<String> walk(Object? v) sync* {
    switch (v) {
      case final String s:
        yield s;
        if (s.startsWith('[') || s.startsWith('{')) {
          try {
            yield* walk(jsonDecode(s));
          } on FormatException {
            // Not JSON.
          }
        }
        if (s.startsWith('slide:')) yield s.substring(6);
        if (s.startsWith('wonky-file://')) yield s.substring(13);
      case final List<Object?> l:
        for (final x in l) {
          yield* walk(x);
        }
      case final Map<Object?, Object?> m:
        for (final e in m.entries) {
          yield* walk(e.value);
        }
    }
  }

  for (final (_, r) in rows) {
    yield* walk(r);
  }
}

/// The source ids that still appear anywhere in [copy].
Set<String> _leaks(DeckModel source, DeckCopy copy) {
  final old = _idsOf(source);
  return {
    for (final s in _strings(copy.rows))
      if (old.contains(s)) s,
  };
}

/// Every UUID reference column of the copy points at a row of the copy.
List<String> _danglingRefs(DeckCopy copy) {
  final m = _model(copy);
  final ids = {for (final (_, r) in copy.rows) r[SlidesCols.id]};
  const refs = {
    'deckId',
    'slideId',
    'elementId',
    'parentId',
    'themeId',
    'masterId',
    'groupId',
    'layoutId',
    'placeholderOf',
    'rowId',
    'columnId',
  };
  final out = <String>[];
  for (final (t, r) in copy.rows) {
    for (final c in refs) {
      final v = r[c];
      if (v != null && !ids.contains(v)) out.add('$t.$c=$v');
    }
  }
  expect(m.deck, isNotNull);
  return out;
}

void main() {
  final f = PlannerFixture();
  late MemoryDeck deck;
  setUp(() => deck = f.session());

  group('Given the rich fixture deck', () {
    test('when copying then every row is copied under new ids, no source id '
        'is left anywhere and every reference points into the copy', () {
      final copy = _copy(deck.model, title: 'Copy of Hello');

      final source = deck.model.dump();
      expect(copy.dropped, isEmpty);
      expect(copy.counts, {
        for (final e in source.entries) e.key: e.value.length,
      });
      final newIds = [for (final (_, r) in copy.rows) r[SlidesCols.id]];
      expect(newIds.toSet(), hasLength(newIds.length), reason: 'no collision');
      expect(_leaks(deck.model, copy), isEmpty);
      expect(_danglingRefs(copy), isEmpty);
      expect(copy.ids, hasLength(newIds.length));
    });

    test('when copying then the deck row takes the new id, title, author and '
        'the remapped default theme', () {
      final copy = _copy(deck.model, title: 'Copy of Hello');
      final m = _model(copy);

      expect(m.deck!.id, _newDeck);
      expect(m.deck!.title, 'Copy of Hello');
      expect(m.deck!.columns[DeckCols.createdBy], testUserId2);
      expect(m.deck!.columns[SlidesCols.createdAt], _now);
      expect(m.deck!.themeId, copy.ids[deck.model.deck!.themeId]);
      expect(m.deck!.width, deck.model.deck!.width);
    });

    test('when copying then the copy has the same slides, order, layouts, '
        'groups, text, tables, builds, code states and chart links', () {
      final copy = _copy(deck.model);
      final m = _model(copy);
      final src = deck.model;

      expect(
        [for (final s in m.slides) s.id],
        [for (final s in src.slides) copy.ids[s.id]],
      );
      for (final s in src.slides) {
        final c = m.slide(copy.ids[s.id]!)!;
        expect(
          m.layout(c.layoutId!)!.key,
          src.layout(s.layoutId!)!.key,
          reason: 'layout of ${s.id}',
        );
        expect(c.groupId, s.groupId == null ? null : copy.ids[s.groupId]);
        expect(c.columns[SlideCols.notes], s.columns[SlideCols.notes]);
        expect(
          [for (final e in m.allElementsOf(c.id)) e.columns[SlidesCols.text]],
          [for (final e in src.allElementsOf(s.id)) e.columns[SlidesCols.text]],
        );
        expect(m.buildsOf(c.id), hasLength(src.buildsOf(s.id).length));
      }
      expect(m.groups.single.title, src.groups.single.title);
      expect(
        m.cellsOf(copy.ids[f.table]!),
        hasLength(src.cellsOf(f.table).length),
      );
      expect(
        [for (final c in m.codeStatesOf(copy.ids[f.code]!)) c.columns['code']],
        [for (final c in src.codeStatesOf(f.code)) c.columns['code']],
      );
      final link = m.chartLinkOf(copy.ids[f.chart]!)!;
      expect(link.id, SlidesIds.chartLinkId(copy.ids[f.chart]!));
      expect(
        link.columns[ChartLinkCols.spreadsheetItemUuid],
        '00000000-0000-4000-8000-0000000000e1',
      );
      expect(DeckMaintenance.detect(m), isEmpty);
    });

    test('when copying then deterministic ids are recomputed for the new '
        'deck: placeholder instances, table cells and the built-in theme '
        'copy (re-applying the built-in adds nothing)', () {
      final copy = _copy(deck.model);
      final m = _model(copy);

      for (final s in m.slides) {
        for (final e in m.elementsOf(s.id)) {
          if (e.placeholderOf == null) continue;
          expect(e.id, SlidesIds.placeholderInstanceId(s.id, e.placeholderOf!));
        }
      }
      for (final c in m.cellsOf(copy.ids[f.table]!)) {
        expect(
          c.id,
          SlidesIds.tableCellId(
            copy.ids[f.table]!,
            c.columns[TableCellCols.rowId]! as String,
            c.columns[TableCellCols.columnId]! as String,
          ),
        );
      }
      final def = BuiltInThemes.defaultTheme;
      final themeId = SlidesIds.themeCopyId(
        _newDeck,
        SlidesIds.builtinThemeSourceKey(def.key, def.version),
      );
      expect(m.theme(themeId), isNotNull);
      final reapply = MemoryDeck(
        model: m,
        userId: testUserId2,
        planner: const SlidesPlanner(),
        ids: SequentialIdGenerator(1),
      ).execute(ImportTheme(builtInKey: def.key));
      expect(reapply.result['themeId'], themeId);
      expect(
        [
          for (final c in reapply.changes)
            if (c.table != SlidesTables.deck) '${c.table}:${c.op.name}',
        ],
        isEmpty,
        reason: 'the copied built-in theme rows are the deterministic ones',
      );
      // The second built-in (imported in the fixture) dedupes too.
      expect(
        m.theme(
          SlidesIds.themeCopyId(
            _newDeck,
            SlidesIds.builtinThemeSourceKey(
              'midnight',
              BuiltInThemes.byKey('midnight')!.version,
            ),
          ),
        ),
        isNotNull,
      );
    });

    test('when copying twice from the same source with the same ids then '
        'the copies are identical (deterministic)', () {
      List<Object?> plain(DeckCopy c) => [
        for (final (t, r) in c.rows) [t, r],
      ];
      expect(plain(_copy(deck.model)), plain(_copy(deck.model)));
    });

    test('when copying then uploaded files get new uuids in every reference '
        'and a re-homing entry; without re-homing they are kept', () {
      const file = '00000000-0000-4000-8000-0000000000f1';
      deck.execute(
        SetElementProps(
          [f.shape],
          fillJson: const Patch(
            '{"v":1,"type":"image","fileUuid":"$file","fit":"cover"}',
          ),
        ),
      );
      final copy = _copy(deck.model);
      final m = _model(copy);

      expect(copy.files, hasLength(1));
      final rehome = copy.files.single;
      expect(rehome.sourceFileUuid, file);
      final image = m.element(copy.ids[f.image]!)!;
      expect(
        jsonDecode(image.columns[ElementCols.dataJson]! as String)['src'],
        'wonky-file://${rehome.newFileUuid}',
      );
      final shape = m.element(copy.ids[f.shape]!)!;
      expect(
        jsonDecode(shape.columns[ElementCols.fillJson]! as String)['fileUuid'],
        rehome.newFileUuid,
      );

      final kept = _copy(deck.model, rehomeFiles: false);
      expect(kept.files, isEmpty);
      expect(
        _model(kept).element(kept.ids[f.image]!)!.columns[ElementCols.dataJson],
        deck.model.element(f.image)!.columns[ElementCols.dataJson],
      );
    });

    test('when elements reference others in JSON and text then connectors, '
        'click links, build options and slide links follow the copy', () {
      final b62Shape = Base62Uuid.encode(f.shape);
      final b62Slide = Base62Uuid.encode(f.title);
      final line = deck.execute(
        InsertElements(f.s3, [
          ElementSpec(
            kind: ElementKind.line,
            x: 10,
            y: 10,
            width: 100,
            height: 100,
            columns: {
              ElementCols.dataJson: jsonEncode({
                'v': 1,
                'routing': 'straight',
                'start': {
                  'x': 0,
                  'y': 0,
                  'connect': {'elementId': b62Shape, 'site': 'right'},
                },
                'end': {'x': 1, 'y': 1, 'connect': null},
              }),
            },
          ),
        ]),
      );
      final lineId = (line.result['elementIds']! as List).single as String;
      deck.execute(
        SetElementProps([
          f.shape2,
        ], linkJson: Patch(jsonEncode({'slideId': b62Slide}))),
      );
      deck.execute(
        SetText(
          ElementText(f.text),
          jsonEncode([
            {
              'insert': 'Back',
              'attributes': {'link': 'slide:$b62Slide'},
            },
            {'insert': '\n'},
          ]),
        ),
      );

      final copy = _copy(deck.model);
      final m = _model(copy);
      final newShape = Base62Uuid.encode(copy.ids[f.shape]!);
      final newSlide = Base62Uuid.encode(copy.ids[f.title]!);
      final data = jsonDecode(
        m.element(copy.ids[lineId]!)!.columns[ElementCols.dataJson]! as String,
      );
      expect(data['start']['connect']['elementId'], newShape);
      expect(
        jsonDecode(
          m.element(copy.ids[f.shape2]!)!.columns[ElementCols.linkJson]!
              as String,
        ),
        containsPair('slideId', newSlide),
      );
      expect(
        m.element(copy.ids[f.text]!)!.columns[SlidesCols.text],
        contains('slide:$newSlide'),
      );
      expect(_leaks(deck.model, copy), isEmpty);
    });

    test('when copying a copy then the second copy equals the first in '
        'content (round trip)', () {
      final first = _copy(deck.model);
      final second = _copy(
        _model(first),
        deckId: '01923456-789a-7bcd-8ef0-00000000c0d2',
        seed: 800000,
      );
      final a = _model(first), b = _model(second);
      expect(second.counts, first.counts);
      expect(
        [for (final s in b.slides) b.layout(s.layoutId!)!.key],
        [for (final s in a.slides) a.layout(s.layoutId!)!.key],
      );
      expect(
        SlidesClipboardCodec.plainText(
          SlidesClipboardCodec.copySlides(
            b,
            slideIds: [for (final s in b.slides) s.id],
          ),
        ),
        SlidesClipboardCodec.plainText(
          SlidesClipboardCodec.copySlides(
            deck.model,
            slideIds: [for (final s in deck.model.slides) s.id],
          ),
        ),
      );
      expect(_leaks(a, second), isEmpty);
    });

    test('when a dependent row has no element then the copy skips it', () {
      final rows = [
        ...f.rowsOf,
        (
          SlidesTables.slideTableAxis,
          {
            SlidesCols.id: '00000000-0000-4000-8000-00000000dead',
            SlidesCols.elementId: '00000000-0000-4000-8000-00000000beef',
            TableAxisCols.dimension: 'row',
            SlidesCols.sortKey: 'a0',
            TableAxisCols.header: false,
          },
        ),
      ];
      final copy = _copy(DeckModel.fromRows(testDeckId, rows));
      expect(copy.dropped, isEmpty, reason: 'unmapped dependents are skipped');
      expect(
        copy.counts[SlidesTables.slideTableAxis],
        deck.model.dump()[SlidesTables.slideTableAxis]!.length,
      );
    });

    test('when the source has no deck row then copying throws', () {
      expect(() => _copy(DeckModel(deckId: testDeckId)), throwsArgumentError);
    });
  });

  group('Given random decks', () {
    for (var seed = 1; seed <= 12; seed++) {
      test('seed $seed: when copying then nothing leaks, nothing collides, '
          'every reference resolves and the copy has the same violations', () {
        final r = Random(seed);
        final d = f.session(seed: seed * 10000);
        for (var i = 0; i < 40; i++) {
          final op = _randomOp(r, d.model, f);
          if (op == null) continue;
          try {
            d.execute(op);
          } on PlanException {
            // Refused ops are part of the run.
          }
        }
        final copy = _copy(d.model, seed: 900000 + seed);
        final ids = [for (final (_, r) in copy.rows) r[SlidesCols.id]];
        expect(ids.toSet(), hasLength(ids.length));
        expect(ids.toSet().intersection(_idsOf(d.model)), isEmpty);
        final leaks = _leaks(d.model, copy);
        expect(leaks, isEmpty);
        expect(_danglingRefs(copy), isEmpty);
        final m = _model(copy);
        expect(
          [for (final v in DeckMaintenance.detect(m)) v.rule],
          [for (final v in DeckMaintenance.detect(d.model)) v.rule],
        );
        expect(m.slides, hasLength(d.model.slides.length));
      });
    }
  });
}

/// A small random operation (structure, elements, themes, paste).
SlidesOperation? _randomOp(Random r, DeckModel m, PlannerFixture f) {
  T pick<T>(List<T> l) => l[r.nextInt(l.length)];
  final slides = m.slides;
  if (slides.isEmpty) return const AddSlides();
  final slide = pick(slides);
  final elements = [
    for (final e in m.elementsOf(slide.id))
      if (e.placeholderType == null) e,
  ];
  final layouts = [
    for (final t in m.themes)
      for (final ms in m.mastersOf(t.id)) ...m.layoutsOf(ms.id),
  ];
  double n(int max) => r.nextInt(max).toDouble();
  switch (r.nextInt(12)) {
    case 0:
      return AddSlides(afterSlideId: slide.id, count: 1 + r.nextInt(2));
    case 1:
      return DuplicateSlides([slide.id]);
    case 2:
      return slides.length > 1 ? DeleteSlides([slide.id]) : null;
    case 3:
      return CreateGroup({slide.id, pick(slides).id}.toList());
    case 4:
      return SetSlideProps([slide.id], layoutId: pick(layouts).id);
    case 5:
      return InsertElements(slide.id, [
        ElementSpec(
          kind: pick(const [
            ElementKind.shape,
            ElementKind.text,
            ElementKind.table,
            ElementKind.code,
          ]),
          x: n(1500),
          y: n(800),
          width: 50 + n(400),
          height: 50 + n(300),
          tableRows: 1 + r.nextInt(3),
          tableColumns: 1 + r.nextInt(3),
        ),
      ]);
    case 6:
      return elements.isEmpty ? null : DeleteElements([pick(elements).id]);
    case 7:
      if (elements.length < 2) return null;
      return GroupElements({pick(elements).id, pick(elements).id}.toList());
    case 8:
      return ImportTheme(builtInKey: pick(BuiltInThemes.keys));
    case 9:
      // Keep source formatting from another deck (deck-sourced theme).
      return PasteSlides(
        clipboardOf(
          f.session().model,
          kind: 'slides',
          slideIds: [f.s2, f.s3],
          withThemes: true,
          sourceDeckId: '01923456-789a-7bcd-8ef0-0000000000aa',
        ),
        afterSlideId: slide.id,
        themeMode: PasteThemeMode.keepSource,
      );
    case 10:
      return elements.isEmpty
          ? null
          : PasteElements(
              SlidesClipboardCodec.copyElements(m, [pick(elements).id]),
              pick(slides).id,
            );
    default:
      return SetText(NotesText(slide.id), '[{"insert":"n${r.nextInt(9)}\\n"}]');
  }
}
