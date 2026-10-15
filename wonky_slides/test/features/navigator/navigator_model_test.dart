import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/editor_screen/slide_labels.dart';
import 'package:wonky_slides/features/navigator/navigator_drop.dart';
import 'package:wonky_slides/features/navigator/navigator_model.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart' show SlidesPlanner;
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

/// t1 · [Intro: a1 a2 a3] · t2 · [Demo: d1 d2] · [Empty] · t3
class _Fixture {
  _Fixture() {
    t1 = b.slide(title: 't1');
    intro = b.group('Intro', color: 'blue');
    a1 = b.slide(groupId: intro, title: 'a1');
    a2 = b.slide(groupId: intro, title: 'a2');
    a3 = b.slide(groupId: intro, title: 'a3');
    t2 = b.slide(title: 't2');
    demo = b.group('Demo', color: 'green');
    d1 = b.slide(groupId: demo, title: 'd1');
    d2 = b.slide(groupId: demo, title: 'd2');
    empty = b.group('Empty');
    t3 = b.slide(title: 't3');
  }

  final b = DeckBuilder();
  late final String t1, intro, a1, a2, a3, t2, demo, d1, d2, empty, t3;

  MemoryDeck deck([int seed = 5000]) => MemoryDeck(
    model: b.build(),
    userId: testUserId,
    planner: const SlidesPlanner(),
    ids: SequentialIdGenerator(seed),
  );
}

/// The order as `title` / `[group: …]` tokens.
List<String> _shape(DeckModel m) {
  final order = m.indexes.order;
  String title(String id) => SlideLabels.title(m, id);
  final out = <String>[];
  for (final t in order.topLevel) {
    if (!t.isGroup) {
      out.add(title(t.id));
      continue;
    }
    final g = m.group(t.id)!;
    final r = order.range(t.id)!;
    final inner = [
      for (var i = r.start; i < r.end; i++) title(order.entries[i].id),
    ];
    out.add('[${g.title}: ${inner.join(' ')}]');
  }
  return out;
}

void _run(MemoryDeck deck, List<SlidesOperation> ops) {
  for (final op in ops) {
    deck.execute(op);
  }
}

void main() {
  late _Fixture f;
  late MemoryDeck deck;
  SlideOrder order() => deck.model.indexes.order;

  setUp(() {
    f = _Fixture();
    deck = f.deck();
  });

  group('Given a deck with groups when the navigator rows are built', () {
    test('then headers precede their slides, empty groups get a drop zone and '
        'the last row of a group is marked', () {
      final rows = buildNavRows(order(), const {});
      expect(rows.map((r) => r.key), [
        'slide:${f.t1}',
        'group:${f.intro}',
        'slide:${f.a1}',
        'slide:${f.a2}',
        'slide:${f.a3}',
        'slide:${f.t2}',
        'group:${f.demo}',
        'slide:${f.d1}',
        'slide:${f.d2}',
        'group:${f.empty}',
        'emptyGroup:${f.empty}',
        'slide:${f.t3}',
      ]);
      expect(rows.where((r) => r.lastInGroup).map((r) => r.id), [
        f.a3,
        f.d2,
        f.empty,
      ]);
      expect(rows[2].inGroup, isTrue);
      expect(rows[0].inGroup, isFalse);
    });

    test('then a collapsed group shows only its header', () {
      final rows = buildNavRows(order(), {f.intro, f.empty});
      expect(rows.map((r) => r.id), [
        f.t1,
        f.intro,
        f.t2,
        f.demo,
        f.d1,
        f.d2,
        f.empty,
        f.t3,
      ]);
      expect(rows[1].collapsed, isTrue);
    });
  });

  group('Given a selection of groups and slides', () {
    test('when read then slides of selected groups are implied and the loose '
        'slides keep presentation order', () {
      final sel = NavSelection.of(
        order(),
        slides: [f.t3, f.a2, f.d1, f.t1],
        groups: [f.demo],
      );
      expect(sel.groupIds, [f.demo]);
      expect(sel.slideIds, [f.t1, f.a2, f.t3]);
      expect(sel.allSlideIds(order()), [f.t1, f.a2, f.d1, f.d2, f.t3]);
      expect(NavigatorOps.units(order(), sel).map((u) => u.id), [
        f.t1,
        f.a2,
        f.demo,
        f.t3,
      ]);
    });
  });

  group('Given moves (04 §5.7, §5.10)', () {
    test('when a top-level slide drops between two slides of a group then it '
        'joins the group there', () {
      _run(
        deck,
        NavigatorOps.moveOps(
          order(),
          NavSelection(slideIds: [f.t2]),
          InGroup(f.intro, beforeId: f.a2),
        ),
      );
      expect(_shape(deck.model), [
        't1',
        '[Intro: a1 t2 a2 a3]',
        '[Demo: d1 d2]',
        '[Empty: ]',
        't3',
      ]);
      expect(deck.model.slide(f.t2)!.groupId, f.intro);
    });

    test('when a group and loose slides move to the start then they arrive '
        'as units in visible order', () {
      _run(
        deck,
        NavigatorOps.moveOps(
          order(),
          NavSelection(groupIds: [f.demo], slideIds: [f.a3, f.t3]),
          TopLevel(beforeId: f.t1),
        ),
      );
      expect(_shape(deck.model), [
        'a3',
        '[Demo: d1 d2]',
        't3',
        't1',
        '[Intro: a1 a2]',
        't2',
        '[Empty: ]',
      ]);
    });

    test('when a collapsed group moves then only its own row is written', () {
      final ops = NavigatorOps.moveOps(
        order(),
        NavSelection(groupIds: [f.intro]),
        TopLevel(afterId: f.t3),
      );
      final plans = [for (final op in ops) deck.execute(op)];
      final rows = {
        for (final p in plans)
          for (final c in p.changes) c.rowId,
      };
      expect(rows, {f.intro});
      expect(_shape(deck.model).last, '[Intro: a1 a2 a3]');
    });

    test('when groups would drop inside a group then the move is refused', () {
      expect(
        () => NavigatorOps.moveOps(
          order(),
          NavSelection(groupIds: [f.demo]),
          InGroup(f.intro),
        ),
        throwsA(isA<NavMoveRefused>()),
      );
    });

    test('when the target is the selection\'s own place then nothing is '
        'written', () {
      expect(
        NavigatorOps.moveOps(
          order(),
          NavSelection(slideIds: [f.a2]),
          InGroup(f.intro, afterId: f.a2),
        ),
        isEmpty,
      );
      expect(
        NavigatorOps.moveOps(
          order(),
          NavSelection(groupIds: [f.intro]),
          TopLevel(beforeId: f.t2),
        ),
        isEmpty,
      );
    });

    test('when a slide leaves a group to the top level then groupId and '
        'sortKey are written together (02 P4)', () {
      final ops = NavigatorOps.moveOps(
        order(),
        NavSelection(slideIds: [f.a1]),
        TopLevel(afterId: f.intro),
      );
      final plan = deck.execute(ops.single);
      final c = plan.changes.single;
      expect(c.columnsAfter.keys, containsAll(['groupId', 'sortKey']));
      expect(c.columnsAfter['groupId'], isNull);
      expect(_shape(deck.model).take(3), ['t1', '[Intro: a2 a3]', 'a1']);
    });
  });

  group('Given keyboard steps (⌘↑ / ⌘↓, 04 §5.7)', () {
    SlideTarget? step(
      List<String> slides, {
      bool down = true,
      Set<String>? c,
    }) => NavigatorOps.stepTarget(
      order(),
      NavSelection(slideIds: slides),
      c ?? const {},
      down: down,
    );

    void apply(List<String> slides, SlideTarget t) => _run(
      deck,
      NavigatorOps.moveOps(order(), NavSelection(slideIds: slides), t),
    );

    test('when ⌘↓ on the last slide of a group then it leaves the group '
        'right after it', () {
      apply([f.a3], step([f.a3])!);
      expect(_shape(deck.model).take(4), ['t1', '[Intro: a1 a2]', 'a3', 't2']);
    });

    test('when ⌘↓ on a top-level slide above an expanded group then it '
        'enters the group first', () {
      apply([f.t1], step([f.t1])!);
      expect(_shape(deck.model).first, '[Intro: t1 a1 a2 a3]');
    });

    test('when ⌘↓ on a top-level slide above a collapsed group then it '
        'jumps over the group', () {
      apply([f.t1], step([f.t1], c: {f.intro})!);
      expect(_shape(deck.model).take(3), ['[Intro: a1 a2 a3]', 't1', 't2']);
    });

    test('when ⌘↑ on the first slide of a group then it leaves the group '
        'before it, and inside a group slides swap', () {
      apply([f.d1], step([f.d1], down: false)!);
      expect(_shape(deck.model), contains('[Demo: d2]'));
      expect(
        _shape(deck.model).indexOf('d1'),
        _shape(deck.model).indexOf('[Demo: d2]') - 1,
      );
      apply([f.a2], step([f.a2], down: false)!);
      expect(_shape(deck.model)[1], '[Intro: a2 a1 a3]');
    });

    test('when ⌘↓ on a group then it steps past the next top-level item; '
        'at the end there is no target', () {
      final t = NavigatorOps.stepTarget(
        order(),
        NavSelection(groupIds: [f.intro]),
        const {},
        down: true,
      );
      _run(
        deck,
        NavigatorOps.moveOps(order(), NavSelection(groupIds: [f.intro]), t!),
      );
      expect(_shape(deck.model).take(3), ['t1', 't2', '[Intro: a1 a2 a3]']);
      expect(step([f.t3]), isNull);
    });

    test('when `to` names start, end, a slide or a group index then the '
        'target follows', () {
      final sel = NavSelection(slideIds: [f.t2]);
      final o = order();
      expect(
        NavigatorOps.targetOf(o, sel, const {}, 'start'),
        isA<TopLevel>().having((t) => t.beforeId, 'before', f.t1),
      );
      expect(
        NavigatorOps.targetOf(o, sel, const {}, {'afterId': f.a1}),
        isA<InGroup>()
            .having((t) => t.groupId, 'group', f.intro)
            .having((t) => t.afterId, 'after', f.a1),
      );
      expect(
        NavigatorOps.targetOf(o, sel, const {}, {
          'groupId': f.demo,
          'index': 1,
        }),
        isA<InGroup>().having((t) => t.beforeId, 'before', f.d2),
      );
      expect(NavigatorOps.targetOf(o, sel, const {}, 'sideways'), isNull);
    });
  });

  group('Given drop indicators over the navigator rows (04 §5.10)', () {
    late List<NavRowBox> boxes;
    setUp(() {
      final rows = buildNavRows(order(), {f.demo});
      var y = 0.0;
      boxes = [
        for (final r in rows)
          (
            row: r,
            top: (y += r.isSlide ? 60 : 30) - (r.isSlide ? 60 : 30),
            height: r.isSlide ? 60.0 : 30.0,
          ),
      ];
    });

    NavRowBox box(String key) => boxes.firstWhere((b) => b.row.key == key);

    NavDrop at(String key, double frac, {double x = 60, bool groups = false}) {
      final b = box(key);
      return resolveNavDrop(
        boxes,
        x,
        b.top + b.height * frac,
        draggingGroups: groups,
      );
    }

    test('when between two slides of an expanded group then the indicator '
        'is indented inside the group', () {
      final d = at('slide:${f.a2}', 0.2);
      expect(d.inside, isTrue);
      expect(d.groupId, f.intro);
      expect(
        d.target,
        isA<InGroup>().having((t) => t.beforeId, 'before', f.a2),
      );
      expect(d.y, box('slide:${f.a2}').top);
    });

    test('when below the last slide of a group then x decides: ≥ 24 px '
        'inside (end), else the top level after the group', () {
      final inside = at('slide:${f.a3}', 0.8, x: 40);
      expect(
        inside.target,
        isA<InGroup>().having((t) => t.afterId, 'after', f.a3),
      );
      expect(inside.inside, isTrue);
      final out = at('slide:${f.a3}', 0.8, x: 10);
      expect(
        out.target,
        isA<TopLevel>().having((t) => t.afterId, 'after', f.intro),
      );
      expect(out.inside, isFalse);
      // The same gap from the row below.
      expect(at('slide:${f.t2}', 0.1, x: 10).target, isA<TopLevel>());
    });

    test('when on a header then its middle appends (highlighted) and its '
        'quarters drop before/after the group', () {
      final mid = at('group:${f.demo}', 0.5);
      expect(mid.highlightGroupId, f.demo);
      expect(mid.target, isA<InGroup>().having((t) => t.groupId, 'g', f.demo));
      expect(
        at('group:${f.demo}', 0.1).target,
        isA<TopLevel>().having((t) => t.beforeId, 'before', f.demo),
      );
      expect(
        at('group:${f.demo}', 0.9).target,
        isA<TopLevel>().having((t) => t.afterId, 'after', f.demo),
      );
    });

    test('when groups are dragged inside a group then the drop is refused '
        '(red), and on the empty zone it appends', () {
      expect(at('slide:${f.a2}', 0.2, groups: true).refused, isTrue);
      expect(at('group:${f.demo}', 0.5, groups: true).refused, isTrue);
      expect(at('slide:${f.t2}', 0.8, groups: true).refused, isFalse);
      final zone = at('emptyGroup:${f.empty}', 0.5);
      expect(zone.highlightGroupId, f.empty);
      expect(zone.target, isA<InGroup>());
    });

    test('when below every row then the drop goes to the end', () {
      final d = resolveNavDrop(boxes, 5, 10000, draggingGroups: false);
      expect(d.target, isA<TopLevel>().having((t) => t.afterId, 'after', f.t3));
    });
  });

  group('Given two clients moving the same slides concurrently', () {
    test(
      'when both write their moves and sync then both converge and every '
      'slide sits in exactly one valid place (P4: no torn groupId/sortKey)',
      () {
        final rnd = math.Random(16);
        for (var round = 0; round < 12; round++) {
          final fx = _Fixture();
          final relay = LwwSyncRelay();
          final a = relay.connect('A', fx.deck(1000));
          final c = relay.connect('B', fx.deck(2000));
          relay.sync();
          for (var step = 0; step < 6; step++) {
            for (final client in [a, c]) {
              final o = client.deck.model.indexes.order;
              final slides = [for (final e in o.entries) e.id];
              final pick = slides[rnd.nextInt(slides.length)];
              final rows = buildNavRows(o, const {});
              final targetRow = rows[rnd.nextInt(rows.length)];
              final SlideTarget t = switch (targetRow.kind) {
                NavRowKind.group => TopLevel(afterId: targetRow.id),
                NavRowKind.emptyGroup => InGroup(targetRow.id),
                NavRowKind.slide =>
                  targetRow.groupId == null
                      ? TopLevel(beforeId: targetRow.id)
                      : InGroup(targetRow.groupId!, afterId: targetRow.id),
              };
              _run(
                client.deck,
                NavigatorOps.moveOps(o, NavSelection(slideIds: [pick]), t),
              );
            }
            if (rnd.nextBool()) relay.sync();
          }
          relay.sync();
          final ma = a.deck.model;
          final mb = c.deck.model;
          expect(ma.dump(), mb.dump(), reason: 'round $round');
          final o = ma.indexes.order;
          expect(o.length, 8);
          expect({for (final e in o.entries) e.id}.length, 8);
          for (final e in o.entries) {
            expect(e.orphan, isFalse);
            final g = e.slide.groupId;
            if (g != null) expect(ma.group(g), isNotNull);
          }
        }
      },
    );
  });
}
