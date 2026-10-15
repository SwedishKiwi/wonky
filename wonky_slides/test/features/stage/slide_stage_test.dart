import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/stage/scene_painter.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/stage/slide_stage.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

import 'stage_fixture.dart';

Future<SlideRenderer> _pump(
  WidgetTester tester,
  StageFixture f, {
  bool editing = false,
  SlideFrame frame = SlideFrame.edit,
  bool loadImages = false,
}) async {
  final r = f.renderer();
  addTearDown(r.dispose);
  final scene = r.scene(f.slideId, editing: editing)!;
  if (loadImages) {
    await tester.runAsync(() => r.images.preload(scene));
  }
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 640,
          height: 360,
          child: SlideStage(
            scene: scene,
            images: r.images,
            frame: frame,
            drawPrompts: editing,
          ),
        ),
      ),
    ),
  );
  return r;
}

RenderObject _layer(WidgetTester tester, String id) => tester.renderObject(
  find.descendant(
    of: find.byKey(ValueKey(id)),
    matching: find.byType(CustomPaint),
  ),
);

void main() {
  for (final appearance in SlideAppearance.values) {
    group('Given a ${appearance.name} deck', () {
      late StageFixture f;
      setUp(() => f = StageFixture(appearance: appearance));

      ResolvedTheme theme() => SlideResolver(
        f.model,
      ).resolve(f.slideId, appearance: appearance)!.theme;

      testWidgets('when staging then the slide fits the box and the '
          'background is painted in the deck appearance', (tester) async {
        await _pump(tester, f);

        expect(tester.getSize(find.byType(SlideStage)), const Size(640, 360));
        final bg = (theme().themeBackground.fill as ResolvedSolidFill).color;
        final background = tester
            .renderObjectList(
              find.descendant(
                of: find.byType(SlideStage),
                matching: find.byType(CustomPaint),
              ),
            )
            .first;
        expect(background, paints..path(color: Color(bg)));
      });

      testWidgets('when staging a shape with text then its fill and text '
          'are painted', (tester) async {
        final id = f.shape(text: 'Hello');
        await _pump(tester, f);

        final accent = theme().colorOf('accent1')!;
        expect(
          _layer(tester, id),
          paints
            ..path(color: Color(accent))
            ..paragraph(),
        );
      });

      testWidgets('when staging a text box then its paragraph is painted', (
        tester,
      ) async {
        final id = f.text('Plain text');
        await _pump(tester, f);

        expect(_layer(tester, id), paints..paragraph());
      });

      testWidgets('when staging a line with an arrow then the shaft is '
          'stroked and the head filled in the stroke color', (tester) async {
        final id = f.line();
        await _pump(tester, f);

        expect(
          _layer(tester, id),
          paints
            ..path(style: PaintingStyle.stroke, color: const Color(0xff112233))
            ..path(style: PaintingStyle.fill, color: const Color(0xff112233)),
        );
      });

      testWidgets('when staging a connector between shapes then the elbow '
          'route is stroked', (tester) async {
        final a = f.shape(x: 100, y: 100, w: 200, h: 100);
        final b = f.shape(x: 900, y: 500, w: 200, h: 100);
        final id = f.connector(a, b);
        final r = await _pump(tester, f);

        expect(r.scene(f.slideId)!.routes[id]!.length, greaterThan(2));
        expect(_layer(tester, id), paints..path(style: PaintingStyle.stroke));
      });

      testWidgets('when staging an image once decoded then it is drawn', (
        tester,
      ) async {
        final id = f.image();
        await _pump(tester, f, loadImages: true);

        expect(_layer(tester, id), paints..drawImageRect());
      });

      testWidgets('when staging a table then cells are filled and their '
          'text painted', (tester) async {
        final id = f.table();
        await _pump(tester, f);

        expect(
          _layer(tester, id),
          paints
            ..path(color: Color(theme().colorOf('accent1')!))
            ..paragraph()
            ..paragraph(),
        );
      });

      testWidgets('when staging an icon then its glyph is painted', (
        tester,
      ) async {
        final id = f.icon();
        await _pump(tester, f);

        expect(_layer(tester, id), paints..paragraph());
      });

      testWidgets('when staging code then the box and the lines are painted', (
        tester,
      ) async {
        final id = f.code();
        await _pump(tester, f);

        expect(
          _layer(tester, id),
          paints
            ..rrect()
            ..paragraph()
            ..paragraph(),
        );
      });

      testWidgets('when staging a chart without a chart source then the '
          'placeholder bars are painted', (tester) async {
        final id = f.chart();
        await _pump(tester, f);

        expect(
          _layer(tester, id),
          paints
            ..path()
            ..path()
            ..path()
            ..path(),
        );
      });
    });
  }

  group('Given element visual states', () {
    testWidgets('when the frame hides an element then nothing is painted for '
        'it', (tester) async {
      final f = StageFixture();
      final id = f.shape();
      await _pump(
        tester,
        f,
        frame: SlideFrame({id: ElementVisualState(visible: false)}),
      );

      expect(_layer(tester, id), isNot(paints..path()));
    });

    testWidgets('when the frame fades an element then it is painted in a '
        'layer', (tester) async {
      final f = StageFixture();
      final id = f.shape();
      await _pump(
        tester,
        f,
        frame: SlideFrame({id: ElementVisualState(opacity: 0.5)}),
      );

      expect(
        _layer(tester, id),
        paints
          ..something((method, args) => method == #saveLayer)
          ..path(),
      );
    });
  });

  group('Given an empty title placeholder', () {
    testWidgets('when editing then the prompt is drawn with a dashed outline '
        'and when not editing it is not', (tester) async {
      final f = StageFixture();
      final slide = f.b.slide(layoutKey: 'titleBody');
      final model = f.model;
      final title = SlideResolver(model)
          .resolve(slide)!
          .elements
          .firstWhere((e) => e.placeholderType?.name == 'title')
          .id;
      final r = f.renderer();
      addTearDown(r.dispose);

      Future<void> pump(bool editing) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SlideStage(
            scene: r.scene(slide, editing: editing)!,
            drawPrompts: editing,
            scale: 0.5,
          ),
        ),
      );

      await pump(true);
      expect(
        _layer(tester, title),
        paints
          ..path(style: PaintingStyle.stroke)
          ..paragraph(),
      );
      await pump(false);
      expect(_layer(tester, title), isNot(paints..paragraph()));
    });
  });

  group('Given a renderer', () {
    testWidgets('when building a scene then the bundled fonts it uses are '
        'requested from the registry', (tester) async {
      final f = StageFixture();
      f.shape(text: 'Fonts');
      final r = f.renderer();
      addTearDown(r.dispose);

      final scene = r.scene(f.slideId)!;
      await tester.pump();

      final families = SlideScenePainter.fontFamiliesOf(scene);
      expect(families, isNotEmpty);
      for (final fam in families) {
        expect(f.fonts.isLoaded(fam), isTrue, reason: fam);
      }
    });

    testWidgets('when the deck changes then listeners are notified and the '
        'scene is rebuilt with a new revision', (tester) async {
      final f = StageFixture();
      final id = f.shape();
      final r = f.renderer();
      addTearDown(r.dispose);
      var notified = 0;
      r.addListener(() => notified++);
      final before = r.scene(f.slideId)!;

      f.moveElement(id, 700);
      final after = r.scene(f.slideId)!;

      expect(notified, 1);
      expect(identical(before, after), isFalse);
      expect(identical(after, r.scene(f.slideId)), isTrue);
    });

    testWidgets('when an image is missing then the stage paints without it '
        'and remembers the failure', (tester) async {
      final f = StageFixture();
      f.image(src: 'wonky-file://missing');
      final r = await _pump(tester, f, loadImages: true);

      expect(
        r.images.hasFailed(const SlideImageRef('wonky-file://missing')),
        isTrue,
      );
    });
  });
}
