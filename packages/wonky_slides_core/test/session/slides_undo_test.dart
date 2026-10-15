import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart' show UndoConflict;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart';

/// A fixture deck: two top-level slides, a group with one slide, a slide
/// with a shape, a text box, an element group, a table with a cell and a
/// build.
final class _Fixture {
  _Fixture() {
    final b = DeckBuilder();
    s1 = b.slide(layoutKey: 'title', title: 'Hello');
    s2 = b.slide(notes: 'Say hi');
    g = b.group('Intro');
    s3 = b.slide(groupId: g);
    shape = b.shape(s2, text: 'Box');
    text = b.textBox(s2, 'Caption');
    grp = '00000000-0000-4000-8000-00000000fff1';
    child = b.shape(s2, parentId: grp);
    b.elementGroup(s2, groupId: grp);
    final t = b.table(s2);
    table = t.$1;
    rows = t.$2;
    cols = t.$3;
    b.cell(table, rows[0], cols[0], 'A1');
    b.build_(s2, shape);
    rowsOf = b.rows;
  }

  late final String s1, s2, g, s3, shape, text, grp, child, table;
  late final List<String> rows, cols;
  late final List<SlidesRow> rowsOf;

  MemoryDeck deck({int seed = 5000, String userId = testUserId}) => MemoryDeck(
    model: DeckModel.fromRows(testDeckId, rowsOf),
    userId: userId,
    planner: const FakeSlidesPlanner(),
    ids: SequentialIdGenerator(seed),
  );
}

void main() {
  final f = _Fixture();

  group('Given one client and the slides.rows handler', () {
    final cases = <(String, SlidesOperation)>[
      ('rename the deck', const SetDeckProps(title: 'Renamed')),
      ('set the footer', const SetDeckProps(footerText: Patch('Confidential'))),
      ('add two slides', AddSlides(afterSlideId: f.s1, count: 2)),
      ('delete a slide with dependents', DeleteSlides([f.s2])),
      ('move a slide into a group', MoveSlides([f.s1], InGroup(f.g))),
      ('move a slide to the top', MoveSlides([f.s3], TopLevel(beforeId: f.s1))),
      ('group two slides', CreateGroup([f.s1, f.s2], title: 'Part 1')),
      (
        'insert a group element with a child',
        InsertElements(f.s1, const [
          ElementSpec(
            kind: ElementKind.group,
            x: 0,
            y: 0,
            width: 10,
            height: 10,
            children: [
              ElementSpec(
                kind: ElementKind.shape,
                x: 1,
                y: 1,
                width: 2,
                height: 2,
              ),
            ],
          ),
        ]),
      ),
      (
        'move and resize an element',
        UpdateFrames([FrameUpdate(f.shape, x: 5, y: 6, width: 70, height: 80)]),
      ),
      (
        'recolor and lock elements',
        SetElementProps(
          [f.shape, f.text],
          fillJson: const Patch('{"type":"solid","color":"#ff0000"}'),
          locked: true,
        ),
      ),
      ('delete an element group', DeleteElements([f.grp])),
      ('delete a table', DeleteElements([f.table])),
      ('type into a text box', SetText(ElementText(f.text), deltaOf('New'))),
      ('edit speaker notes', SetText(NotesText(f.s2), deltaOf('Notes'))),
      (
        'type into an empty table cell',
        SetText(CellText(f.table, f.rows[1], f.cols[1]), deltaOf('B2')),
      ),
      (
        'format existing and new cells',
        SetCells(f.table, [
          CellWrite(f.rows[0], f.cols[0], const {'fill': '#00ff00'}),
          CellWrite(f.rows[1], f.cols[0], const {'vAlign': 'middle'}),
        ]),
      ),
    ];

    for (final (what, op) in cases) {
      test('when I $what, undo and redo then the deck returns to the state '
          'before and after', () async {
        final deck = f.deck();
        final handler = SlidesRowsUndoHandler(() => deck);
        final before = deck.model.dump();

        final plan = deck.execute(op);
        final after = deck.model.dump();
        final undone = await handler.undo(
          SlidesRowsUndoEntry(plan.changes, label: plan.label),
        );
        final afterUndo = deck.model.dump();
        await handler.redo(undone);

        expect(plan.isEmpty, isFalse);
        expect(afterUndo, before);
        expect(deck.model.dump(), after);
        expect(deck.writes.map((w) => w.label), [
          plan.label,
          'Undo ${plan.label}',
          'Redo ${plan.label}',
        ]);
      });
    }

    test('when an entry is persisted and decoded then its changes and label '
        'survive', () {
      final deck = f.deck();
      final plan = deck.execute(UpdateFrames([FrameUpdate(f.shape, x: 1)]));
      final entry = SlidesRowsUndoEntry(plan.changes, label: plan.label);

      final decoded = SlidesRowsUndoEntry.fromJson(
        (jsonDecode(jsonEncode(entry.toJson())) as Map).cast(),
      );

      expect(decoded?.changes, entry.changes);
      expect(decoded?.label, 'Move');
      expect(decoded?.domain, slidesRowsDomain);
    });
  });

  group('Given two clients A and B on the same deck', () {
    late MemoryDeck a, b;
    late LwwSyncRelay relay;
    late SlidesRowsUndoHandler undoA;
    late int partials;

    setUp(() {
      a = f.deck(seed: 6000);
      b = f.deck(seed: 7000, userId: testUserId2);
      relay = LwwSyncRelay();
      relay.connect('A', a);
      relay.connect('B', b);
      relay.sync();
      partials = 0;
      undoA = SlidesRowsUndoHandler(() => a, onPartial: () => partials++);
    });

    SlidesRowsUndoEntry run(MemoryDeck d, SlidesOperation op) {
      final plan = d.execute(op);
      return SlidesRowsUndoEntry(plan.changes, label: plan.label);
    }

    test('when A moves a shape, B recolors it and A undoes then the move is '
        'undone and B\'s color stays everywhere', () async {
      final move = run(a, UpdateFrames([FrameUpdate(f.shape, x: 500, y: 400)]));
      run(
        b,
        SetElementProps([
          f.shape,
        ], fillJson: const Patch('{"color":"#123456"}')),
      );
      relay.sync();

      await undoA.undo(move);
      relay.sync();

      for (final d in [a, b]) {
        final e = d.model.element(f.shape)!;
        expect((e.x, e.y), (100.0, 100.0));
        expect(e.fillJson, '{"color":"#123456"}');
      }
      expect(a.model.dump(), b.model.dump());
      expect(partials, 0);
    });

    test('when B resized the shape A moved then A\'s undo skips the whole '
        'frame group (coupled columns) and reports a conflict', () async {
      final move = run(a, UpdateFrames([FrameUpdate(f.shape, x: 500, y: 400)]));
      relay.sync();
      run(
        b,
        UpdateFrames([
          FrameUpdate(f.shape, x: 510, y: 400, width: 300, height: 100),
        ]),
      );
      relay.sync();

      await expectLater(undoA.undo(move), throwsA(isA<UndoConflict>()));

      final e = a.model.element(f.shape)!;
      expect((e.x, e.y, e.width, e.height), (510.0, 400.0, 300.0, 100.0));
    });

    test('when B changed a column A did not write then A\'s undo still '
        'restores A\'s columns', () async {
      final move = run(a, UpdateFrames([FrameUpdate(f.shape, x: 500)]));
      relay.sync();
      run(b, SetElementProps([f.shape], locked: true));
      relay.sync();

      await undoA.undo(move);

      final e = a.model.element(f.shape)!;
      expect(e.x, 100.0);
      expect(e.locked, isTrue);
    });

    test(
      'when A types into a new cell, B fills it and A undoes then the '
      'cell keeps B\'s fill and loses A\'s text (column-wise insert)',
      () async {
        final typing = run(
          a,
          SetText(CellText(f.table, f.rows[1], f.cols[1]), deltaOf('B2')),
        );
        relay.sync();
        run(
          b,
          SetCells(f.table, [
            CellWrite(f.rows[1], f.cols[1], const {'fill': '#00ff00'}),
          ]),
        );
        relay.sync();

        await undoA.undo(typing);
        relay.sync();

        final cellId = SlidesIds.tableCellId(f.table, f.rows[1], f.cols[1]);
        for (final d in [a, b]) {
          final cell = d.model.record(SlidesTables.slideTableCell, cellId);
          expect(cell?[SlidesCols.text], isNull);
          expect(cell?[TableCellCols.fill], '#00ff00');
        }
        expect(partials, 1);
      },
    );

    test('when A deletes a slide and undoes then both clients get it back '
        'with the same ids', () async {
      final del = run(a, DeleteSlides([f.s2]));
      relay.sync();

      await undoA.undo(del);
      relay.sync();

      expect(b.model.slide(f.s2), isNotNull);
      expect(b.model.element(f.shape), isNotNull);
      expect(b.model.cellsOf(f.table), hasLength(1));
      expect(a.model.dump(), b.model.dump());
      expect(relay.dump(), a.model.dump());
    });
  });
}
