import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show CommandState;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/editor_screen/slide_labels.dart';
import 'package:wonky_slides/features/navigator/navigator_clipboard.dart';
import 'package:wonky_slides/features/navigator/navigator_controller.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

import '../harness/deck_harness.dart';

/// t1 · [Intro (blue): a1 a2 a3] · t2 · [Demo (green): d1 d2] · t3
class _Deck {
  _Deck({String deckId = testDeckId, int seed = 1}) {
    b = DeckBuilder(deckId: deckId, ids: SequentialIdGenerator(seed));
    t1 = b.slide(title: 't1');
    intro = b.group('Intro', color: 'blue');
    a1 = b.slide(groupId: intro, title: 'a1');
    a2 = b.slide(groupId: intro, title: 'a2');
    a3 = b.slide(groupId: intro, title: 'a3');
    t2 = b.slide(title: 't2');
    demo = b.group('Demo', color: 'green');
    d1 = b.slide(groupId: demo, title: 'd1');
    d2 = b.slide(groupId: demo, title: 'd2');
    t3 = b.slide(title: 't3');
  }

  late final DeckBuilder b;
  late final String t1, intro, a1, a2, a3, t2, demo, d1, d2, t3;
}

/// The order as `title` / `[Group: …]` tokens.
List<String> shape(DeckModel m) {
  final order = m.indexes.order;
  final out = <String>[];
  for (final t in order.topLevel) {
    if (!t.isGroup) {
      out.add(SlideLabels.title(m, t.id));
      continue;
    }
    final r = order.range(t.id)!;
    final inner = [
      for (var i = r.start; i < r.end; i++)
        SlideLabels.title(m, order.entries[i].id),
    ];
    out.add('[${m.group(t.id)!.title}: ${inner.join(' ')}]');
  }
  return out;
}

/// The navigator commands (Slides 04 §5, SL-16) run headless through the
/// real dispatcher and undo stack on the deck harness.
void main() {
  final l = slidesL10nEnglish;
  late _Deck f;
  late DeckHarness d;

  setUp(() {
    SlidesSlideClipboard.debugClear();
    f = _Deck();
    d = DeckHarness.open(fixture: f.b);
  });
  tearDown(() => d.dispose());

  DeckEditorController ed() => d.editor;
  DeckModel model() => d.model;
  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      d.services.dispatcher.stateOf(id, args);

  Future<void> undoRedo(List<String> before, List<String> after) async {
    await d.undo();
    expect(shape(model()), before, reason: 'after undo');
    await d.redo();
    expect(shape(model()), after, reason: 'after redo');
  }

  group('Given slides selected in the navigator (04 §5.6)', () {
    test('when three non-contiguous slides are grouped with ⌘G then they '
        'gather at the first slide\'s position in one undo step', () async {
      final before = shape(model());
      ed().selectSlides([f.t1, f.t2, f.t3]);
      expect(state('slides.group.create').enabled, isTrue);
      final r = await d.run('slides.group.create');

      expect(r.isOk, isTrue);
      final g = (r.data! as Map)['groupId'] as String;
      final group = model().group(g)!;
      expect(group.title, 'Group 1');
      // The next color after the previous group (none: blue).
      expect(group.color, 'blue');
      expect(shape(model()), [
        '[Group 1: t1 t2 t3]',
        '[Intro: a1 a2 a3]',
        '[Demo: d1 d2]',
      ]);
      expect(d.undoLabels, ['slides.group.create']);
      // The new group is selected and its rename field opens.
      expect(ed().selectedGroupIds, {g});
      expect(navigatorOf(ed()).renamingGroupId, g);
      await undoRedo(before, shape(model()));
    });

    test('when a slide inside a group is grouped then the new group goes '
        'right after that group and takes the next color', () async {
      ed().selectSlides([f.a2]);
      final r = await d.run('slides.group.create');
      final g = (r.data! as Map)['groupId'] as String;
      expect(shape(model()), [
        't1',
        '[Intro: a1 a3]',
        '[Group 1: a2]',
        't2',
        '[Demo: d1 d2]',
        't3',
      ]);
      expect(model().group(g)!.color, 'violet');
    });

    test('when the selection is exactly one group\'s slides then Group '
        'slides is disabled with the reason', () {
      ed().selectSlides([f.a1, f.a2, f.a3]);
      final s = state('slides.group.create');
      expect(s.enabled, isFalse);
      expect(s.disabledReason, l.reasonAlreadyGroup);
    });

    test('when New group runs from the empty area then an empty group is '
        'created at the end', () async {
      final r = await d.run('slides.group.create', {'slideIds': <String>[]});
      final g = (r.data! as Map)['groupId'] as String;
      expect(model().indexes.order.topLevel.last.id, g);
      expect(model().slidesInGroup(g), isEmpty);
    });
  });

  group('Given a group (04 §5.4, §5.7)', () {
    test('when renamed, colored and skipped then each is one undo step and '
        'presenting skips its slides', () async {
      await d.run('slides.group.rename', {
        'groupId': f.intro,
        'title': 'Opening',
      });
      await d.run('slides.group.setColor', {
        'groupIds': [f.intro],
        'color': 'red',
      });
      expect(
        state('slides.group.setColor', {
          'groupIds': [f.intro],
          'color': 'red',
        }).checked,
        isTrue,
      );
      await d.run('slides.group.toggleSkip', {
        'groupIds': [f.intro],
      });
      final g = model().group(f.intro)!;
      expect((g.title, g.color, g.skipped), ('Opening', 'red', true));
      final presented = model().indexes.order.presentedIds;
      expect(presented, isNot(contains(f.a1)));
      expect(presented, [f.t1, f.t2, f.d1, f.d2, f.t3]);
      expect(d.undoLabels.length, 3);
      await d.undo();
      expect(model().group(f.intro)!.skipped, isFalse);
      await d.undo();
      expect(model().group(f.intro)!.color, 'blue');
      await d.undo();
      expect(model().group(f.intro)!.title, 'Intro');
    });

    test(
      'when collapsed then nothing is written or undoable, the state is '
      'stored per device and another editor of the deck restores it',
      () async {
        final nav = navigatorOf(ed());
        final rowsBefore = model().dump();
        await d.run('slides.group.collapse', {
          'groupIds': [f.intro],
        });
        expect(nav.isCollapsed(f.intro), isTrue);
        expect(nav.rows.where((r) => r.groupId == f.intro).length, 1);
        expect(d.undoLabels, isEmpty);
        expect(model().dump(), rowsBefore);
        await pumpEventQueue();
        final stored = await d.services.userStore.read(
          'slides.view.${model().deckId}',
        );
        expect(jsonDecode(stored! as String)['collapsedGroups'], [f.intro]);

        // The same user on this device: restored.
        final again = DeckEditorController(
          services: d.services,
          session: d.session,
        );
        final nav2 = navigatorOf(again);
        await pumpEventQueue();
        expect(nav2.isCollapsed(f.intro), isTrue);
        again.dispose();

        // Another client (its own device store): still expanded.
        final other = DeckHarness.open(fixture: _Deck().b);
        expect(navigatorOf(other.editor).isCollapsed(f.intro), isFalse);
        await other.dispose();

        await d.run('slides.group.expandAll');
        expect(nav.collapsed, isEmpty);
        await d.run('slides.group.collapseAll');
        expect(nav.collapsed, {f.intro, f.demo});
      },
    );

    test('when the current slide is set from elsewhere inside a collapsed '
        'group then the group expands', () async {
      final nav = navigatorOf(ed());
      nav.setCollapsed([f.demo], true);
      await d.run('slides.nav.goToSlide', {'slideId': f.d2});
      expect(nav.isCollapsed(f.demo), isFalse);
    });

    test('when the collapsed group moves to the end then one group row is '
        'written in one undo step', () async {
      final before = shape(model());
      final keys = {for (final s in model().slides) s.id: s.sortKey};
      await d.run('slides.group.move', {
        'groupIds': [f.intro],
        'to': 'end',
      });
      expect(shape(model()).last, '[Intro: a1 a2 a3]');
      expect({for (final s in model().slides) s.id: s.sortKey}, keys);
      expect(d.undoLabels, ['slides.group.move']);
      await undoRedo(before, shape(model()));
    });

    test('when Alt-dropped (copy) then a duplicate group lands at the target '
        'and the source stays', () async {
      final r = await d.run('slides.slide.move', {
        'groupIds': [f.demo],
        'to': {'beforeId': f.t1},
        'copy': true,
      });
      expect(r.isOk, isTrue);
      expect(shape(model()).first, '[Demo: d1 d2]');
      expect(shape(model()).where((s) => s == '[Demo: d1 d2]').length, 2);
      expect(d.undoLabels, ['slides.slide.move']);
      await d.undo();
      expect(model().groups.length, 2);
    });

    test(
      'when groups are dropped inside a group then the move is refused',
      () async {
        final s = state('slides.slide.move', {
          'groupIds': [f.demo],
          'to': {'beforeId': f.a2},
        });
        expect(s.enabled, isFalse);
        expect(d.undoLabels, isEmpty);
      },
    );

    test(
      'when ungrouped or deleted with its slides then each is one step',
      () async {
        final before = shape(model());
        await d.run('slides.group.ungroup', {
          'groupIds': [f.intro],
        });
        expect(shape(model()).take(4), ['t1', 'a1', 'a2', 'a3']);
        await undoRedo(before, shape(model()));
        await d.undo();

        final r = await d.h.invoke('slides.group.delete', {
          'groupIds': [f.demo],
          'withSlides': true,
        }, InvocationSource.mcp);
        expect(r.isOk, isTrue);
        expect(shape(model()), ['t1', '[Intro: a1 a2 a3]', 't2', 't3']);
        expect(model().slide(f.d1), isNull);
        await d.undo();
        expect(shape(model()), before);
      },
    );

    test(
      'when deleted without its slides then they stay ungrouped in place',
      () async {
        await d.h.invoke('slides.group.delete', {
          'groupIds': [f.demo],
        }, InvocationSource.mcp);
        expect(shape(model()), [
          't1',
          '[Intro: a1 a2 a3]',
          't2',
          'd1',
          'd2',
          't3',
        ]);
      },
    );

    test('when duplicated then the copy follows the group', () async {
      await d.run('slides.group.duplicate', {
        'groupIds': [f.intro],
      });
      expect(shape(model()).take(3), [
        't1',
        '[Intro: a1 a2 a3]',
        '[Intro: a1 a2 a3]',
      ]);
    });
  });

  group('Given slide operations (04 §5.7)', () {
    test('when a slide is skipped inside a skipped group then its own toggle '
        'is disabled with "Skipped with group"', () async {
      await d.run('slides.group.toggleSkip', {
        'groupIds': [f.intro],
      });
      ed().setCurrentSlide(f.a2);
      final s = state('slides.slide.toggleSkip');
      expect(s.enabled, isFalse);
      expect(s.disabledReason, l.reasonSkippedWithGroup);
      ed().setCurrentSlide(f.t2);
      await d.run('slides.slide.toggleSkip');
      expect(model().slide(f.t2)!.skipped, isTrue);
      expect(state('slides.slide.toggleSkip').checked, isTrue);
    });

    test('when ⌘↓ moves slides then they cross group boundaries as 04 §5.7 '
        'says, one undo step each', () async {
      ed().setCurrentSlide(f.a3);
      await d.run('slides.slide.move', {'to': 'down'});
      expect(shape(model()).take(3), ['t1', '[Intro: a1 a2]', 'a3']);
      ed().setCurrentSlide(f.t2);
      await d.run('slides.slide.move', {'to': 'down'});
      expect(shape(model())[3], '[Demo: t2 d1 d2]');
      ed().setCurrentSlide(f.t1);
      await d.run('slides.slide.move', {'to': 'end'});
      expect(shape(model()).last, 't1');
      expect(d.undoLabels.length, 3);
      ed().setCurrentSlide(f.t1);
      expect(state('slides.slide.move', {'to': 'down'}).enabled, isFalse);
    });

    test('when slides are removed from or added to a group then they land '
        'right after the group / at its end', () async {
      ed().selectSlides([f.a1, f.a3]);
      await d.run('slides.group.removeSlides');
      expect(shape(model()).take(4), ['t1', '[Intro: a2]', 'a1', 'a3']);
      await d.run('slides.group.addSlides', {
        'groupId': f.demo,
        'slideIds': [f.t1],
      });
      expect(shape(model()), contains('[Demo: d1 d2 t1]'));
    });

    test('when New slide runs then it follows the current slide in its group '
        'and becomes current', () async {
      ed().setCurrentSlide(f.a1);
      final r = await d.run('slides.slide.new');
      final id = ((r.data! as Map)['slideIds'] as List).single as String;
      expect(model().slide(id)!.groupId, f.intro);
      expect(model().indexes.order.indexOf(id), 2);
      expect(ed().currentSlideId, id);
    });

    test('when a group and a slide are duplicated and then deleted then each '
        'is one step and the labels count the slides', () async {
      ed().selectSlides([f.d1, f.d2, f.t3], groups: [f.demo]);
      expect(d.services.registry.byId('slides.slide.delete'), isNotNull);
      await d.run('slides.slide.duplicate');
      expect(model().groups.length, 3);
      expect(model().slides.length, 11);
      expect(d.undoLabels.length, 1);
      ed().selectSlides([f.t1, f.t2]);
      await d.run('slides.slide.delete');
      expect(model().slide(f.t1), isNull);
      expect(model().slide(f.t2), isNull);
      await d.undo();
      expect(model().slide(f.t1), isNotNull);
    });
  });

  group('Given the navigator clipboard (04 §5.8)', () {
    test(
      'when two groups are copied from deck A and pasted into deck B then '
      'they arrive expanded with titles, colors, skip flags and slides',
      () async {
        await d.run('slides.group.toggleSkip', {
          'groupIds': [f.demo],
        });
        final copied = await d.run('slides.navigator.copy', {
          'groupIds': [f.intro, f.demo],
        });
        expect(copied.isOk, isTrue);
        expect(SlidesSlideClipboard.hasSlides, isTrue);

        final g = _Deck(
          deckId: '00000000-0000-7000-8000-00000000bbbb',
          seed: 900,
        );
        final b = DeckHarness.open(fixture: g.b);
        addTearDown(b.dispose);
        navigatorOf(b.editor).setCollapsed([g.intro], true);
        b.editor.setCurrentSlide(g.t1);
        final r = await b.run('slides.navigator.paste');
        expect(r.isOk, isTrue, reason: '${r.data}');
        final groups = ((r.data! as Map)['groupIds'] as List).cast<String>();
        expect(groups.length, 2);
        expect(shape(b.model).take(3), [
          't1',
          '[Intro: a1 a2 a3]',
          '[Demo: d1 d2]',
        ]);
        final pasted = [for (final id in groups) b.model.group(id)!];
        expect(
          [for (final p in pasted) (p.title, p.color, p.skipped)],
          [('Intro', 'blue', false), ('Demo', 'green', true)],
        );
        for (final id in groups) {
          expect(navigatorOf(b.editor).isCollapsed(id), isFalse);
        }
        expect(b.undoLabels, ['slides.navigator.paste']);
        await b.undo();
        expect(b.model.groups.length, 2);
      },
    );

    test('when slides are cut then they are gone in one step and paste puts '
        'them back after the selection', () async {
      ed().selectSlides([f.t2]);
      await d.run('slides.navigator.cut');
      expect(model().slide(f.t2), isNull);
      ed().setCurrentSlide(f.t3);
      await d.run('slides.navigator.paste');
      expect(shape(model()).last, 't2');
      expect(d.undoLabels, ['slides.navigator.paste', 'slides.navigator.cut']);
    });

    test('when the navigator owns the clipboard then the shell Edit menu '
        'copies slides', () async {
      ed().setCurrentSlide(f.t3);
      expect(navigatorOwnsClipboard(ed()), isTrue);
      expect(d.doc.canCopy, isTrue);
      await d.doc.copy();
      expect((SlidesSlideClipboard.current!['slides'] as List).length, 1);
      expect(d.doc.canPaste, isTrue);
      await d.doc.paste();
      expect(model().slides.length, 9);
    });
  });
}
