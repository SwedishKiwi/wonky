@Tags(['property'])
library;

import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_slides_core/maintenance.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';

import '../support/planner_fixture.dart';

/// A random valid-looking operation for [m] (the planner may still refuse
/// it, e.g. a locked element or a limit).
SlidesOperation? _randomOp(Random r, DeckModel m) {
  T pick<T>(List<T> l) => l[r.nextInt(l.length)];
  final slides = m.slides;
  if (slides.isEmpty) return const AddSlides();
  final slide = pick(slides);
  final elements = m.elementsOf(slide.id);
  final free = [
    for (final e in elements)
      if (e.placeholderType == null) e,
  ];
  final tables = [
    for (final e in m.allElementsOf(slide.id))
      if (e.kind == ElementKind.table) e,
  ];
  final groupEls = [
    for (final e in m.allElementsOf(slide.id))
      if (e.kind == ElementKind.group) e,
  ];
  final layouts = [
    for (final t in m.themes)
      for (final ms in m.mastersOf(t.id)) ...m.layoutsOf(ms.id),
  ];
  double n(int max) => r.nextInt(max).toDouble();
  switch (r.nextInt(30)) {
    case 0:
      return AddSlides(afterSlideId: slide.id, count: 1 + r.nextInt(2));
    case 1:
      return DuplicateSlides([slide.id]);
    case 2:
      return slides.length > 1 ? DeleteSlides([slide.id]) : null;
    case 3:
      final other = pick(slides);
      final g = m.groups.isEmpty || r.nextBool() ? null : pick(m.groups);
      return MoveSlides(
        [slide.id],
        g != null
            ? InGroup(g.id)
            : TopLevel(beforeId: other.groupId == null ? other.id : null),
      );
    case 4:
      return CreateGroup({slide.id, pick(slides).id}.toList());
    case 5:
      return m.groups.isEmpty ? null : Ungroup(pick(m.groups).id);
    case 6:
      return m.groups.isEmpty
          ? null
          : SetGroupProps([pick(m.groups).id], skipped: r.nextBool());
    case 7:
      return SetSlideProps([slide.id], skipped: r.nextBool());
    case 8:
      return SetSlideProps([slide.id], layoutId: pick(layouts).id);
    case 9:
      return ResetSlideToLayout([slide.id]);
    case 10:
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
    case 11:
      if (elements.isEmpty) return null;
      final e = pick(elements);
      return UpdateFrames([
        switch (r.nextInt(3)) {
          0 => FrameUpdate(e.id, x: n(1500), y: n(900)),
          1 => FrameUpdate(e.id, width: 10 + n(600), height: 10 + n(600)),
          _ => FrameUpdate(e.id, rotation: n(720) - 360, flipH: r.nextBool()),
        },
      ]);
    case 12:
      if (elements.isEmpty) return null;
      return SetElementProps(
        [pick(elements).id],
        fillJson: Patch(
          '{"v":1,"type":"solid","color":"#${r.nextInt(0xffffff).toRadixString(16).padLeft(6, '0')}"}',
        ),
        hidden: r.nextInt(5) == 0,
        locked: r.nextInt(8) == 0,
      );
    case 13:
      return elements.isEmpty ? null : DeleteElements([pick(elements).id]);
    case 14:
      return elements.isEmpty
          ? null
          : ReorderZ([pick(elements).id], pick(ZOrderOp.values));
    case 15:
      if (free.length < 2) return null;
      return AlignDistribute(
        {pick(free).id, pick(free).id, pick(free).id}.toList(),
        pick(AlignMode.values),
      );
    case 16:
      if (free.length < 2) return null;
      final ids = {pick(free).id, pick(free).id}.toList();
      return ids.length < 2 ? null : GroupElements(ids);
    case 17:
      return groupEls.isEmpty ? null : UngroupElements([pick(groupEls).id]);
    case 18:
      final texts = [
        for (final e in elements)
          if (e.kind.hasText || e.placeholderType != null) e,
      ];
      return texts.isEmpty
          ? null
          : SetText(ElementText(pick(texts).id), deltaOf('T${r.nextInt(100)}'));
    case 19:
      final texts = [
        for (final e in elements)
          if (e.text != null) e,
      ];
      return texts.isEmpty
          ? null
          : FormatText(
              [ElementText(pick(texts).id)],
              {
                pick(const ['bold', 'italic', 'underline']): r.nextBool()
                    ? true
                    : null,
              },
              start: 0,
              length: 1,
            );
    case 20:
      if (tables.isEmpty) return null;
      final t = pick(tables);
      return InsertTableAxes(
        t.id,
        pick(TableAxisDimension.values),
        0,
        count: 1,
      );
    case 21:
      if (tables.isEmpty) return null;
      final t = pick(tables);
      final rows = m.axesOf(t.id, TableAxisDimension.row);
      return rows.length < 2 ? null : DeleteTableAxes(t.id, [pick(rows).id]);
    case 22:
      if (tables.isEmpty) return null;
      final t = pick(tables);
      final rows = m.axesOf(t.id, TableAxisDimension.row);
      final cols = m.axesOf(t.id, TableAxisDimension.column);
      return SetCells(t.id, [
        CellWrite(pick(rows).id, pick(cols).id, {
          'text': deltaOf('c'),
          'fill': r.nextBool() ? '#ff0000' : null,
        }),
      ]);
    case 23:
      if (tables.isEmpty) return null;
      final t = pick(tables);
      final rows = m.axesOf(t.id, TableAxisDimension.row);
      final cols = m.axesOf(t.id, TableAxisDimension.column);
      if (rows.length < 2 || cols.length < 2) return null;
      return MergeCells(
        t.id,
        rowId: rows.first.id,
        columnId: cols.first.id,
        rowSpan: 2,
        colSpan: 1 + r.nextInt(2),
      );
    case 24:
      return elements.isEmpty
          ? null
          : AddBuilds(slide.id, [
              BuildSpec(
                elementId: pick(elements).id,
                kind: SlideBuildKind.buildIn,
                effect: 'fade',
                durationMs: 300,
              ),
            ]);
    case 25:
      return ImportTheme(builtInKey: pick(BuiltInThemes.keys));
    case 26:
      final themes = m.themes;
      return ApplyThemeToSlides(pick(themes).id, [slide.id]);
    case 27:
      return SetDeckProps(
        footerText: Patch(r.nextBool() ? 'F${r.nextInt(9)}' : null),
        showSlideNumbers: r.nextBool(),
      );
    case 28:
      return SetText(NotesText(slide.id), deltaOf('N${r.nextInt(9)}'));
    default:
      return MoveGroups(
        m.groups.isEmpty ? const [] : [pick(m.groups).id],
        beforeId: slides.first.groupId == null ? slides.first.id : null,
      );
  }
}

/// What the model's derived indexes and resolution say (compared between an
/// incrementally patched model and a fresh reload).
Object _signature(DeckModel m, SlideResolver resolver) => [
  for (final e in m.indexes.order.entries)
    [e.id, e.index, e.groupId, e.skipped, e.number, e.orphan],
  for (final g in m.indexes.order.groups) [g.group.id, g.start, g.end],
  for (final s in m.slides) ...[
    resolver.resolve(s.id)!.layout?.id,
    for (final e in resolver.resolve(s.id)!.painted)
      [
        e.id,
        e.frame.x,
        e.frame.y,
        e.frame.width,
        e.frame.height,
        e.rotation,
        e.opacity,
        e.placeholderType?.name,
        e.fieldText,
      ],
  ],
  for (final r in m.records(SlidesTables.slideElement))
    if ((r as SlideElementRec).kind == ElementKind.table)
      [
        r.id,
        for (final x in m.indexes.table(r.id).merges)
          [x.origin.id, x.rowSpan, x.colSpan],
      ],
];

void main() {
  final f = PlannerFixture();

  for (var seed = 1; seed <= 30; seed++) {
    test('Given seed $seed when running random operations then invariants '
        'hold, incremental patching equals a reload and undoing everything '
        'returns to the start', () async {
      final r = Random(seed);
      final deck = f.session(seed: seed * 100000);
      final handler = SlidesRowsUndoHandler(() => deck);
      // A second model patched incrementally with the remote batches.
      final mirror = DeckModel.fromRows(testDeckId, f.rowsOf);
      final mirrorResolver = SlideResolver(mirror);
      mirror.indexes.order; // Build indexes before patching.
      final start = deck.model.dump();
      final entries = <SlidesRowsUndoEntry>[];
      var applied = 0;
      for (var i = 0; i < 40; i++) {
        final op = _randomOp(r, deck.model);
        if (op == null) continue;
        final SlidesPlan plan;
        try {
          plan = deck.execute(op);
        } on PlanException {
          continue;
        }
        if (plan.isEmpty) continue;
        applied++;
        entries.add(SlidesRowsUndoEntry(plan.changes, label: plan.label));
        mirror.applyChanges(plan.changes, origin: DeckChangeOrigin.remote);
        expect(
          DeckMaintenance.detect(deck.model),
          isEmpty,
          reason: 'step $i ${op.name}',
        );
        final fresh = DeckModel.fromRows(testDeckId, [
          for (final t in deck.model.dump().entries)
            for (final row in t.value.values) (t.key, row),
        ]);
        expect(
          _signature(mirror, mirrorResolver),
          _signature(fresh, SlideResolver(fresh)),
          reason: 'step $i ${op.name}',
        );
      }
      for (final e in entries.reversed) {
        await handler.undo(e);
      }

      expect(applied, greaterThan(10));
      expect(deck.model.dump(), start);
    });
  }

  for (var seed = 1; seed <= 20; seed++) {
    test('Given seed $seed when two offline replicas edit at random, sync '
        'and repair then they converge with no violation', () {
      final r = Random(1000 + seed);
      final relay = LwwSyncRelay();
      final a = relay.connect('A', f.session(seed: 100000 + seed * 1000));
      final b = relay.connect(
        'B',
        f.session(seed: 500000 + seed * 1000, userId: testUserId2),
      );
      relay.sync();
      for (var round = 0; round < 4; round++) {
        a.online = b.online = false;
        for (final c in [a, b]) {
          for (var i = 0; i < 6; i++) {
            final op = _randomOp(r, c.deck.model);
            if (op == null) continue;
            try {
              c.deck.execute(op);
            } on PlanException {
              continue;
            }
          }
        }
        a.online = b.online = true;
        relay.sync();
        // Each replica repairs what it sees (debounced in the app), then sync.
        a.online = b.online = false;
        for (final c in [a, b]) {
          final op = DeckMaintenance.repairOp(c.deck.model);
          if (op != null) c.deck.execute(op);
        }
        a.online = b.online = true;
        relay.sync();

        expect(
          a.deck.model.dump(),
          b.deck.model.dump(),
          reason: 'round $round',
        );
        expect(
          DeckMaintenance.detect(a.deck.model),
          isEmpty,
          reason: 'round $round',
        );
      }
    });
  }
}
