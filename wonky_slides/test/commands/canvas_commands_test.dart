import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/snapping.dart';

import '../features/canvas/canvas_rig.dart' show CanvasFixture;
import '../harness/deck_harness.dart';

typedef Dump = Map<String, Map<String, Map<String, Object?>>>;

void main() {
  late CanvasFixture f;
  late DeckHarness d;

  setUp(() {
    f = CanvasFixture();
    d = DeckHarness.open(fixture: f.b);
    d.editor.setCurrentSlide(f.slide);
  });
  tearDown(() => d.dispose());

  ({double x, double y, double w, double h, double r}) frame(String id) {
    final e = d.model.element(id)!;
    return (x: e.x!, y: e.y!, w: e.width!, h: e.height!, r: e.rotation ?? 0);
  }

  void select(List<String> ids) => selectionOf(d.editor).select(ids);

  /// Runs [id] and checks execute → undo → redo returns to the same rows.
  Future<CommandResult> roundTrip(
    String id, [
    Map<String, Object?> args = const {},
  ]) async {
    final before = d.model.dump();
    final r = await d.run(id, args);
    expect(r.status, CommandStatus.ok, reason: '$id: ${r.message}');
    final after = d.model.dump();
    expect(after, isNot(equals(before)), reason: '$id changed nothing');
    await d.undo();
    expect(d.model.dump(), before, reason: '$id undo');
    await d.redo();
    expect(d.model.dump(), after, reason: '$id redo');
    return r;
  }

  group('Given selection commands', () {
    test(
      'when cycling with Tab then elements come in reading order and wrap',
      () async {
        await d.run('slides.select.next');
        final first = d.editor.selectedElementIds.single;
        expect(first, f.a);

        final seen = [first];
        for (var i = 0; i < 7; i++) {
          await d.run('slides.select.next');
          seen.add(d.editor.selectedElementIds.single);
        }

        // a, b, under (row 1 by x), then g, img, c (row 2), the line; locked
        // shapes are skipped; then it wraps.
        expect(seen, [f.a, f.bShape, f.under, f.g, f.img, f.c, f.line, f.a]);
        await d.run('slides.select.previous');
        expect(d.editor.selectedElementIds, [f.line]);
      },
    );

    test('when entering a group then Esc goes back to the group and then '
        'to nothing', () async {
      select([f.g]);

      await d.run('slides.element.activate');
      expect(selectionOf(d.editor).enteredGroupId, f.g);
      expect(d.editor.selectedElementIds, [f.g1]);

      await d.run('slides.select.escape');
      expect(d.editor.selectedElementIds, [f.g]);
      await d.run('slides.select.escape');
      expect(d.editor.selectedElementIds, isEmpty);
    });

    test('when selecting by ids then the selection and the entered group '
        'follow', () async {
      await d.run('slides.select.elements', {
        'ids': [f.g1, f.g2],
      });

      expect(d.editor.selectedElementIds, [f.g1, f.g2]);
      expect(selectionOf(d.editor).enteredGroupId, f.g);
    });

    test('when selecting all then every unlocked visible element of the '
        'scope is selected', () async {
      selectionOf(d.editor).selectAll();

      expect(d.editor.selectedElementIds.toSet(), {
        f.a,
        f.bShape,
        f.c,
        f.g,
        f.under,
        f.img,
        f.line,
      });
    });

    test('when changing the slide and coming back then the selection is '
        'restored', () async {
      select([f.a]);

      d.editor.setCurrentSlide(f.slide2);
      expect(d.editor.selectedElementIds, isEmpty);
      d.editor.setCurrentSlide(f.slide);

      expect(d.editor.selectedElementIds, [f.a]);
    });
  });

  group('Given transform commands', () {
    test(
      'when moving a shape then only x and y change and it round-trips',
      () async {
        await roundTrip('slides.element.move', {
          'ids': [f.a],
          'dx': 50,
          'dy': -20,
        });

        expect(frame(f.a), (x: 150.0, y: 80.0, w: 400.0, h: 200.0, r: 0.0));
        expect(d.undoLabels.first, 'slides.element.move');
      },
    );

    test('when moving a child of a scaled group then the delta is mapped '
        'into the group space', () async {
      // Scale the group 2× horizontally (child space stays 600 wide).
      await d.run('slides.element.resize', {
        'frames': [
          {'id': f.g, 'width': 1200},
        ],
      });

      await roundTrip('slides.element.move', {
        'ids': [f.g1],
        'dx': 100,
        'dy': 0,
      });

      expect(frame(f.g1).x, 150);
    });

    test(
      'when resizing with frames then the given values are written',
      () async {
        await roundTrip('slides.element.resize', {
          'frames': [
            {'id': f.a, 'x': 90, 'y': 95, 'width': 500, 'height': 210},
          ],
        });

        expect(frame(f.a), (x: 90.0, y: 95.0, w: 500.0, h: 210.0, r: 0.0));
      },
    );

    test(
      'when a rotation is written then only x, y and rotation change',
      () async {
        await roundTrip('slides.element.resize', {
          'frames': [
            {'id': f.a, 'x': 100, 'y': 100, 'rotation': 30},
          ],
          'label': 'rotate',
        });

        expect(frame(f.a), (x: 100.0, y: 100.0, w: 400.0, h: 200.0, r: 30.0));
      },
    );

    test('when moving a locked shape then the command fails and nothing '
        'changes', () async {
      final before = d.model.dump();

      final r = await d.run('slides.element.move', {
        'ids': [f.locked],
        'dx': 10,
        'dy': 10,
      });

      expect(r.status, CommandStatus.failed);
      expect(d.model.dump(), before);
    });

    test('when nudging three times within a second then one undo step '
        'restores the start', () async {
      select([f.a]);
      var now = DateTime(2026, 10, 15, 12);
      await withClock(Clock(() => now), () async {
        final steps = d.undoLabels.length;
        for (final (dx, dy) in [(1, 0), (10, 0), (0, -1)]) {
          await d.run('slides.element.nudge', {'dx': dx, 'dy': dy});
          now = now.add(const Duration(milliseconds: 300));
        }
        expect(frame(f.a).x, 111);
        expect(frame(f.a).y, 99);
        expect(d.undoLabels.length, steps + 1);

        now = now.add(const Duration(seconds: 2));
        await d.run('slides.element.nudge', {'dx': 1, 'dy': 0});
        expect(d.undoLabels.length, steps + 2);

        await d.undo();
        expect(frame(f.a).x, 111);
        await d.undo();
        expect((frame(f.a).x, frame(f.a).y), (100, 100));
      });
    });

    test('when adjusting a shape then dataJson.adjust is written', () async {
      await roundTrip('slides.element.adjust', {
        'id': f.a,
        'key': 'radius',
        'value': 0.3,
      });

      final data = jsonDecode(d.model.element(f.a)!.str('dataJson')!) as Map;
      expect(data['adjust'], {'radius': 0.3});
      expect(data['geometry'], 'rect');
    });

    test('when setting line ends onto a shape site then the frame is the '
        'endpoints\' box and the end glues', () async {
      await roundTrip('slides.element.setLineEnds', {
        'id': f.line,
        'start': {'x': 200, 'y': 950},
        'end': {'x': 1300, 'y': 700, 'elementId': f.c, 'site': 'left'},
      });

      expect(frame(f.line), (x: 200.0, y: 700.0, w: 1100.0, h: 250.0, r: 0.0));
      final data = jsonDecode(d.model.element(f.line)!.str('dataJson')!) as Map;
      expect(data['start'], {'x': 0, 'y': 1, 'connect': null});
      expect(data['end'], {
        'x': 1,
        'y': 0,
        'connect': CanvasFixture.glue(f.c, 'left'),
      });
    });
  });

  group('Given arrange commands', () {
    test(
      'when aligning two shapes left then both share the leftmost x',
      () async {
        select([f.bShape, f.c]);

        await roundTrip('slides.arrange.align', {'edge': 'left'});

        expect((frame(f.bShape).x, frame(f.c).x), (700, 700));
      },
    );

    test('when aligning one shape to the center then it centers on the '
        'slide', () async {
      select([f.a]);

      await roundTrip('slides.arrange.align', {'edge': 'center'});

      expect(frame(f.a).x, 760);
    });

    test('when aligning a single child then it aligns to its group', () async {
      select([f.g2]);

      await roundTrip('slides.arrange.align', {'edge': 'left'});

      expect(frame(f.g2).x, 100);
    });

    test('when distributing three shapes horizontally then the gaps are '
        'equal', () async {
      select([f.a, f.bShape, f.under]);
      // a 100–500, b 700–1100, under 1300–1600: gaps 200 and 200 → move b.
      await d.run('slides.element.move', {
        'ids': [f.bShape],
        'dx': 50,
        'dy': 0,
      });

      await roundTrip('slides.arrange.distribute', {'axis': 'horizontal'});

      expect(frame(f.bShape).x, 700);
    });

    test('when distributing two shapes then the command is disabled', () {
      select([f.a, f.bShape]);

      final st = d.services.dispatcher.stateOf('slides.arrange.distribute', {
        'axis': 'horizontal',
      });

      expect(st.enabled, isFalse);
      expect(st.disabledReason, 'Select at least 3 objects');
    });

    test(
      'when centering on the slide then the selection box is centered',
      () async {
        select([f.a]);

        await roundTrip('slides.arrange.centerOnSlide', {'axis': 'both'});

        expect((frame(f.a).x, frame(f.a).y), (760, 440));
      },
    );

    test(
      'when matching size then the others get the first one\'s size',
      () async {
        select([f.c, f.a]);

        await roundTrip('slides.arrange.matchSize', {'dimension': 'both'});

        expect((frame(f.a).w, frame(f.a).h), (300, 200));
      },
    );

    test('when rotating by 90° twice and flipping then rotation and flips '
        'change', () async {
      select([f.a]);

      await roundTrip('slides.arrange.rotate', {'degrees': 90});
      await roundTrip('slides.arrange.rotate', {'degrees': -90});
      expect(frame(f.a).r, 0);
      await roundTrip('slides.arrange.flip', {'axis': 'horizontal'});

      expect(d.model.element(f.a)!.flipH, isTrue);
    });

    test('when bringing a shape to the front and sending it to the back '
        'then its z-order changes', () async {
      select([f.a]);
      String top() => d.model.indexes.tree(f.slide).childrenOf(null).last.id;

      await roundTrip('slides.arrange.order', {'op': 'front'});
      expect(top(), f.a);
      await roundTrip('slides.arrange.order', {'op': 'back'});
      expect(top(), isNot(f.a));
    });
  });

  group('Given lock and hide', () {
    test(
      'when toggling the lock then the selection locks and unlocks',
      () async {
        select([f.a]);

        await roundTrip('slides.element.toggleLock');
        expect(d.model.element(f.a)!.locked, isTrue);
        await roundTrip('slides.element.toggleLock');
        expect(d.model.element(f.a)!.locked, isFalse);
      },
    );

    test('when unlocking all then every locked element of the slide '
        'unlocks', () async {
      await roundTrip('slides.element.unlockAll');

      expect(d.model.element(f.locked)!.locked, isFalse);
    });

    test('when hiding then the element is hidden and deselected; show '
        'brings it back', () async {
      select([f.a, f.c]);

      await roundTrip('slides.element.hide', {
        'ids': [f.a],
      });
      expect(d.model.element(f.a)!.hidden, isTrue);
      expect(d.editor.selectedElementIds, [f.c]);

      await roundTrip('slides.element.show', {
        'ids': [f.a],
      });
      expect(d.model.element(f.a)!.hidden, isFalse);
    });
  });

  group('Given Edit › Delete and Duplicate', () {
    test(
      'when deleting the selection then it is gone; undo brings it back',
      () async {
        select([f.a, f.c]);

        await roundTrip('slides.edit.delete');

        expect(d.model.element(f.a), isNull);
        expect(d.editor.selectedElementIds, isEmpty);
        await d.undo();
        expect(d.model.element(f.a), isNotNull);
      },
    );

    test('when the selection holds a locked element then Delete is '
        'disabled', () {
      select([f.locked]);

      final st = d.services.dispatcher.stateOf('slides.edit.delete');

      expect(st.enabled, isFalse);
      expect(st.disabledReason, 'Unlock the object first');
    });

    test(
      'when duplicating then copies 32 su lower right are selected',
      () async {
        select([f.a]);

        final r = await roundTrip('slides.edit.duplicate');

        final copy = (r.data! as Map)['elementIds'].single as String;
        expect(frame(copy), (x: 132.0, y: 132.0, w: 400.0, h: 200.0, r: 0.0));
        expect(d.editor.selectedElementIds, [copy]);
      },
    );

    test('when the selection is inside a group then Duplicate is disabled', () {
      select([f.g1]);

      expect(
        d.services.dispatcher.stateOf('slides.edit.duplicate').enabled,
        isFalse,
      );
    });

    test('when duplicating with a move (Alt-drag) then the copy lands at the '
        'moved position', () async {
      select([f.a]);

      await roundTrip('slides.element.move', {
        'ids': [f.a],
        'dx': 0,
        'dy': 300,
        'duplicate': true,
      });

      final copy = d.editor.selectedElementIds.single;
      expect((frame(copy).x, frame(copy).y), (100, 400));
      expect(frame(f.a).y, 100);
    });
  });

  group('Given user guides', () {
    List<UserGuide> guides() => UserGuides.decode(d.model.deck!.guidesJson);

    test('when adding, moving, deleting and clearing guides then each is one '
        'undo step', () async {
      await roundTrip('slides.guides.add', {'axis': 'vertical'});
      expect(guides(), [const UserGuide(GuideAxis.vertical, 960)]);
      await roundTrip('slides.guides.add', {'axis': 'horizontal', 'at': 100});
      await roundTrip('slides.guides.move', {'index': 0, 'at': 480});
      expect(guides().first.at, 480);
      await roundTrip('slides.guides.delete', {'index': 1});
      expect(guides(), [const UserGuide(GuideAxis.vertical, 480)]);
      await roundTrip('slides.guides.clear');
      expect(guides(), isEmpty);
      expect(d.editor.guides, isTrue);
    });

    test('when there are no guides then Clear guides is disabled', () {
      expect(
        d.services.dispatcher.stateOf('slides.guides.clear').enabled,
        isFalse,
      );
    });
  });

  group('Given no canvas', () {
    test('when asking to zoom to the selection then it is disabled', () {
      expect(
        d.services.dispatcher.stateOf('slides.view.zoomToSelection').enabled,
        isFalse,
      );
    });
  });
}
