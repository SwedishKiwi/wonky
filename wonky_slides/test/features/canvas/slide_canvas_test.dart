import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides/features/canvas/canvas_tokens.dart';
import 'package:wonky_slides/features/canvas/slide_canvas.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides_core/snapping.dart';

import 'canvas_rig.dart';

void main() {
  group('Given the canvas with shapes, a group and a locked shape', () {
    testWidgets('when clicking a shape then it alone is selected', (
      tester,
    ) async {
      final r = await CanvasRig.pump(tester);

      await r.click(tester, 300, 200);

      expect(r.selected, [r.fixture.a]);
    });

    testWidgets('when Shift-clicking a second shape then both are selected, '
        'and Shift-clicking again removes it', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);

      await CanvasRig.holding(tester, LogicalKeyboardKey.shiftLeft, () async {
        await r.click(tester, 900, 200);
      });
      expect(r.selected, [r.fixture.a, r.fixture.bShape]);

      await CanvasRig.holding(tester, LogicalKeyboardKey.shiftLeft, () async {
        await r.click(tester, 900, 200);
      });
      expect(r.selected, [r.fixture.a]);
    });

    testWidgets('when clicking the empty slide then the selection clears', (
      tester,
    ) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);

      await r.click(tester, 1800, 50);

      expect(r.selected, isEmpty);
    });

    testWidgets('when clicking a locked shape then the click goes through to '
        'the shape below', (tester) async {
      final r = await CanvasRig.pump(tester);

      await r.click(tester, 1450, 200);

      expect(r.selected, [r.fixture.under]);
    });

    testWidgets('when clicking a child of a group then the group is selected; '
        'a double click enters it and selects the child; Esc selects the '
        'group again', (tester) async {
      final r = await CanvasRig.pump(tester);

      await r.click(tester, 200, 650);
      expect(r.selected, [r.fixture.g]);

      await r.doubleClick(tester, 600, 850);
      expect(r.selected, [r.fixture.g2]);
      expect(r.controller.selection.enteredGroupId, r.fixture.g);

      await r.click(tester, 200, 650);
      expect(r.selected, [r.fixture.g1]);

      await r.d.run('slides.select.escape');
      expect(r.selected, [r.fixture.g]);
      expect(r.controller.selection.enteredGroupId, isNull);
    });

    testWidgets('when Mod-clicking a child of a group then it is selected '
        'directly (deep select)', (tester) async {
      final r = await CanvasRig.pump(tester);

      await CanvasRig.holding(tester, LogicalKeyboardKey.controlLeft, () async {
        await CanvasRig.holding(tester, LogicalKeyboardKey.metaLeft, () async {
          await r.click(tester, 200, 650);
        });
      });

      expect(r.selected, [r.fixture.g1]);
      expect(r.controller.selection.enteredGroupId, r.fixture.g);
    });

    testWidgets('when dragging a marquee around two shapes then they are '
        'selected (fully inside only)', (tester) async {
      final r = await CanvasRig.pump(tester);

      await r.drag(tester, const Offset(50, 50), const Offset(1150, 350));

      expect(r.selected, unorderedEquals([r.fixture.a, r.fixture.bShape]));
      expect(r.controller.selection.marquee, isNull);
    });

    testWidgets('when dragging a marquee with Alt then touched elements are '
        'selected too', (tester) async {
      final r = await CanvasRig.pump(tester);

      await CanvasRig.holding(tester, LogicalKeyboardKey.altLeft, () async {
        await r.drag(tester, const Offset(50, 50), const Offset(320, 150));
      });

      expect(r.selected, [r.fixture.a]);
    });
  });

  group('Given a selected shape', () {
    testWidgets('when dragging it then it moves with one undo step that '
        'writes only x and y', (tester) async {
      final r = await CanvasRig.pump(tester);
      final before = r.d.undoLabels.length;

      await r.drag(tester, const Offset(300, 200), const Offset(353, 251));

      expect(r.frame(r.fixture.a), (x: 153.0, y: 151.0, w: 400.0, h: 200.0));
      expect(r.d.undoLabels.length, before + 1);
      expect(r.d.undoLabels.first, 'Move');
      final step = r.d.h.services.undo.undoStepsOf(r.d.doc.undoStackKey).last;
      final changes = (step.entries.single as dynamic).changes as List;
      expect(changes.single.columnsAfter.keys.toSet(), {'x', 'y'});

      await r.d.undo();
      expect(r.frame(r.fixture.a), (x: 100.0, y: 100.0, w: 400.0, h: 200.0));
    });

    testWidgets('when dragging it near another shape\'s edge then it snaps '
        'and shows a guide while dragging', (tester) async {
      final r = await CanvasRig.pump(tester);

      // a.left 100 → 703 would align with b.left (700) within 6 px.
      final g = await r.drag(
        tester,
        const Offset(300, 200),
        const Offset(903, 450),
        hold: true,
      );
      final t = r.controller.transform!;
      expect(t.delta.dx, 600);
      expect(t.guides.any((x) => x.axis == SnapAxis.x && x.at == 700), isTrue);
      // Nothing is written while dragging.
      expect(r.frame(r.fixture.a).x, 100);
      await g.up();
      await tester.pumpAndSettle();

      expect(r.frame(r.fixture.a).x, 700);
    });

    testWidgets('when pressing Esc while dragging then the drag is cancelled '
        'and nothing is written', (tester) async {
      final r = await CanvasRig.pump(tester);
      final steps = r.d.undoLabels.length;

      final g = await r.drag(
        tester,
        const Offset(300, 200),
        const Offset(500, 400),
        hold: true,
      );
      expect(r.controller.transform, isNotNull);
      await r.d.run('slides.select.escape');
      await g.moveBy(const Offset(10, 10));
      await g.up();
      await tester.pumpAndSettle();

      expect(r.frame(r.fixture.a).x, 100);
      expect(r.d.undoLabels.length, steps);
      expect(r.selected, [r.fixture.a]);
    });

    testWidgets(
      'when Alt-dragging it (Mod: no snapping) then a copy is moved and the original '
      'stays',
      (tester) async {
        final r = await CanvasRig.pump(tester);
        final count = r.model.allElementsOf(r.fixture.slide).length;

        // Mod (Ctrl off macOS) disables snapping.
        await CanvasRig.holding(
          tester,
          LogicalKeyboardKey.controlLeft,
          () async {
            await CanvasRig.holding(
              tester,
              LogicalKeyboardKey.altLeft,
              () async {
                await r.drag(
                  tester,
                  const Offset(300, 200),
                  const Offset(300, 451),
                );
              },
            );
          },
        );

        expect(r.frame(r.fixture.a).y, 100);
        expect(r.model.allElementsOf(r.fixture.slide).length, count + 1);
        final copy = r.selected.single;
        expect(copy, isNot(r.fixture.a));
        expect(r.frame(copy).y, 351);
      },
    );

    testWidgets('when dragging the bottom-right handle then it resizes in '
        'one undo step', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);
      final h = r.controller.handles().firstWhere(
        (h) => h.resize == ResizeHandle.bottomRight,
      );

      await r.dragFromPx(tester, h.position, const Offset(651, 333));

      final f = r.frame(r.fixture.a);
      expect((f.x, f.y), (100, 100));
      expect(f.w, closeTo(551, 0.01));
      expect(f.h, closeTo(233, 0.01));
      expect(r.d.undoLabels.first, 'Resize');
    });

    testWidgets('when dragging a corner with Shift then the aspect ratio is '
        'kept', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);
      final h = r.controller.handles().firstWhere(
        (h) => h.resize == ResizeHandle.bottomRight,
      );

      await CanvasRig.holding(tester, LogicalKeyboardKey.shiftLeft, () async {
        await r.dragFromPx(tester, h.position, const Offset(931, 333));
      });

      final f = r.frame(r.fixture.a);
      expect(f.w / f.h, closeTo(2, 0.001));
    });

    testWidgets('when dragging the rotation handle with Shift then the angle '
        'snaps to 15° steps', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);
      final h = r.controller.handles().firstWhere(
        (h) => h.kind == CanvasHandleKind.rotate,
      );

      // Center (300, 200): pointing right of the center is 90°; 80° snaps
      // to 75° with Shift.
      await CanvasRig.holding(tester, LogicalKeyboardKey.shiftLeft, () async {
        await r.dragFromPx(tester, h.position, const Offset(600, 147));
      });

      expect(r.model.element(r.fixture.a)!.rotation, 75);
      expect(r.d.undoLabels.first, 'Rotate');
    });

    testWidgets('when the selection is locked then no handles show', (
      tester,
    ) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);
      await r.d.run('slides.element.lock');
      await tester.pump();

      expect(r.controller.handles(), isEmpty);
    });
  });

  group('Given a viewer', () {
    testWidgets('when clicking a shape then it is selected without handles '
        'and a drag writes nothing', (tester) async {
      final r = await CanvasRig.pump(tester, role: Role.viewer);

      await r.click(tester, 300, 200);
      expect(r.selected, [r.fixture.a]);
      expect(r.controller.handles(), isEmpty);

      await r.drag(tester, const Offset(300, 200), const Offset(400, 300));
      expect(r.frame(r.fixture.a).x, 100);
    });
  });

  group('Given a line', () {
    testWidgets('when dragging its end onto a shape\'s site then it glues '
        'there in one step', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 400, 950);
      expect(r.selected, [r.fixture.line]);
      final end = r.controller.handles().firstWhere(
        (h) => h.kind == CanvasHandleKind.lineEnd,
      );

      // c's left site is (1300, 700).
      await r.dragFromPx(tester, end.position, const Offset(1302, 702));

      final data = r.model.element(r.fixture.line)!.str('dataJson')!;
      expect(data, contains('"site":"left"'));
      final e = r.model.element(r.fixture.line)!;
      expect((e.x, e.y, e.width, e.height), (200, 700, 1100, 250));
    });
  });

  group('Given the canvas chrome', () {
    for (final brightness in Brightness.values) {
      testWidgets('when a shape is selected in ${brightness.name} mode then '
          'the handles paint in the theme\'s selection colors', (tester) async {
        final r = await CanvasRig.pump(tester, brightness: brightness);
        await r.click(tester, 300, 200);
        final t = CanvasTokens.forBrightness(brightness);

        expect(
          find.byKey(const ValueKey('slides.canvas.overlay')),
          paints
            ..path(color: t.selection)
            ..rect(color: t.handleFill)
            ..rect(color: t.selection),
        );
      });
    }

    testWidgets('when the canvas is 360 px wide then the slide fits with a '
        'narrow margin and handles keep 16 px touch targets', (tester) async {
      final r = await CanvasRig.pump(tester, size: const Size(360, 640));
      final v = r.controller.viewport;

      expect(v.margin, 16);
      expect(v.scale, closeTo((360 - 32) / 1920, 1e-6));

      await r.click(tester, 300, 200);
      final h = r.controller.handles().firstWhere(
        (h) => h.resize == ResizeHandle.bottomRight,
      );
      expect(r.controller.handleAt(h.position + const Offset(7, 7)), isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('Given rulers and guides', () {
    testWidgets('when dragging from the top ruler then a horizontal guide is '
        'added where it is dropped; dragging it off the slide deletes it', (
      tester,
    ) async {
      final r = await CanvasRig.pump(tester);
      r.d.editor.toggleView('rulers');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('slides.canvas.ruler.horizontal')),
        findsOneWidget,
      );

      final origin = tester.getTopLeft(find.byType(SlideCanvas));
      await r.dragFromPx(tester, const Offset(400, 10), const Offset(900, 300));
      List<UserGuide> guides() => UserGuides.decode(r.model.deck!.guidesJson);
      expect(guides(), [const UserGuide(GuideAxis.horizontal, 300)]);
      expect(r.d.editor.guides, isTrue);

      // Grab the guide (away from elements) and drop it below the slide.
      final y = r.controller.viewport.toViewport(const Offset(0, 300)).dy;
      expect(origin, isNotNull);
      await r.dragFromPx(tester, Offset(985, y), const Offset(1800, 1200));
      expect(guides(), isEmpty);
    });

    testWidgets('when a guide exists then moving a shape snaps to it', (
      tester,
    ) async {
      final r = await CanvasRig.pump(tester);
      await r.d.run('slides.guides.add', {'axis': 'vertical', 'at': 1250});
      await tester.pump();

      // c.left 1300 → 1253 snaps to 1250 (Mod off).
      await r.drag(tester, const Offset(1450, 700), const Offset(1403, 690));

      expect(r.frame(r.fixture.c).x, 1250);
    });
  });

  group('Given an element group', () {
    testWidgets('when resizing the group then only the group row is written '
        '(children scale with it)', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 200, 650);
      expect(r.selected, [r.fixture.g]);
      final child = r.frame(r.fixture.g1);
      final h = r.controller.handles().firstWhere(
        (h) => h.resize == ResizeHandle.right,
      );

      // Groups keep their aspect by default; Shift frees it.
      await CanvasRig.holding(tester, LogicalKeyboardKey.shiftLeft, () async {
        await r.dragFromPx(tester, h.position, const Offset(1300, 750));
      });

      expect(r.frame(r.fixture.g).w, closeTo(1200, 0.01));
      expect(r.frame(r.fixture.g1), child);
      final g1 = r.controller.elements![r.fixture.g1]!;
      expect(g1.frame.width, closeTo(400, 0.01));
    });

    testWidgets('when dragging a child inside the entered group then only the '
        'child moves', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.doubleClick(tester, 200, 650);
      expect(r.selected, [r.fixture.g1]);

      await r.drag(tester, const Offset(200, 650), const Offset(260, 670));

      expect((r.frame(r.fixture.g1).x, r.frame(r.fixture.g1).y), (160, 620));
      expect(r.frame(r.fixture.g2).x, 500);
      expect(r.frame(r.fixture.g).x, 100);
    });
  });
}
