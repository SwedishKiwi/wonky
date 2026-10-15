import 'dart:convert';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/config/slides_features.dart';
import 'package:wonky_slides/features/builds/animate_canvas_layer.dart';
import 'package:wonky_slides/features/builds/animate_view.dart';
import 'package:wonky_slides/features/inspector/animate/order_tab.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../support/deck_screen.dart';

/// A deck with two slides: the first with a title, a bulleted body and a
/// shape; the second a copy-like slide.
({DeckBuilder b, String s1, String s2, String title, String body, String shape})
_deck({bool withBuilds = true}) {
  final b = DeckBuilder(title: 'Motion');
  final s1 = b.slide(layoutKey: 'blank');
  final title = b.textBox(s1, 'Pricing', y: 80);
  final body = b.textBox(s1, 'One\nTwo\nThree', y: 300, height: 300);
  final shape = b.shape(s1, x: 1200, y: 400);
  final s2 = b.slide(layoutKey: 'blank');
  b.textBox(s2, 'Pricing', y: 120);
  if (withBuilds) {
    b.build_(s1, title, effect: 'fade');
    b.build_(
      s1,
      body,
      effect: 'rise',
      durationMs: 600,
      easing: 'spring(0.6,0)',
      optionsJson: jsonEncode({
        'v': 1,
        'delivery': {'by': 'paragraph'},
      }),
    );
    b.build_(
      s1,
      shape,
      kind: SlideBuildKind.emphasis,
      effect: 'pulse',
      trigger: SlideBuildTrigger.withPrevious,
    );
  }
  return (b: b, s1: s1, s2: s2, title: title, body: body, shape: shape);
}

void main() {
  setUp(
    () => SlidesFeatures.enabled = {
      ...SlidesFeatures.shipped,
      SlidesFeature.animations,
    },
  );
  tearDown(SlidesFeatures.reset);

  for (final brightness in Brightness.values) {
    testWidgets('Given builds when the Order tab opens in ${brightness.name} '
        'then steps, rows and badges show and a row selects its object', (
      tester,
    ) async {
      final f = _deck();
      final rig = await pumpDeckScreen(
        tester,
        fixture: f.b,
        brightness: brightness,
      );
      await rig.run('slides.panel.animate', {'tab': 'order'});
      await tester.pumpAndSettle();
      expect(find.byKey(OrderTabKeys.list), findsOneWidget);
      expect(find.text('Click 1'), findsOneWidget);
      expect(find.text('Click 4'), findsOneWidget);
      final rows = rig.session.model.buildsOf(f.s1);
      for (final r in rows) {
        expect(find.byKey(OrderTabKeys.row(r.id)), findsOneWidget);
      }
      // Build order badges on the canvas (06 §5.5).
      expect(find.byKey(AnimateCanvasKeys.badge(f.body)), findsOneWidget);
      await tester.tap(find.byKey(OrderTabKeys.row(rows[1].id)));
      await tester.pumpAndSettle();
      expect(rig.editor.selectedElementIds, [f.body]);
      expect(AnimateView.of(rig.editor).selectedBuildIds, [rows[1].id]);
      expect(tester.takeException(), isNull);
      await rig.close(tester);
    });
  }

  testWidgets('Given a selected row when Mod+Alt+↓ is pressed in the Order '
      'list then the build moves down; Delete removes it', (tester) async {
    final f = _deck();
    final rig = await pumpDeckScreen(tester, fixture: f.b);
    await rig.run('slides.panel.animate', {'tab': 'order'});
    await tester.pumpAndSettle();
    final ids = [for (final b in rig.session.model.buildsOf(f.s1)) b.id];
    await tester.tap(find.byKey(OrderTabKeys.row(ids[0])));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      [for (final b in rig.session.model.buildsOf(f.s1)) b.id],
      [ids[1], ids[0], ids[2]],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(
      [for (final b in rig.session.model.buildsOf(f.s1)) b.id],
      [ids[1], ids[2]],
    );
    await rig.close(tester);
  });

  testWidgets('Given the Order list when a row is dragged below another then '
      'one reorder command runs', (tester) async {
    final f = _deck();
    final rig = await pumpDeckScreen(tester, fixture: f.b);
    await rig.run('slides.panel.animate', {'tab': 'order'});
    await tester.pumpAndSettle();
    final ids = [for (final b in rig.session.model.buildsOf(f.s1)) b.id];
    final from = tester.getCenter(find.byKey(OrderTabKeys.row(ids[0])));
    final target = tester.getRect(find.byKey(OrderTabKeys.row(ids[2])));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(from + const Offset(0, 10));
    await tester.pump();
    await g.moveTo(target.center + Offset(0, target.height / 2 - 2));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(
      [for (final b in rig.session.model.buildsOf(f.s1)) b.id],
      [ids[1], ids[2], ids[0]],
    );
    await rig.close(tester);
  });

  testWidgets('Given a selected shape when Rise is picked on the Build tab '
      'then a build is added with its timing and parameters', (tester) async {
    final f = _deck(withBuilds: false);
    final rig = await pumpDeckScreen(
      tester,
      fixture: f.b,
      size: const Size(1440, 1800),
    );
    rig.editor.selectElements([f.shape]);
    await rig.run('slides.panel.animate', {'tab': 'build'});
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('slides.animate.buildTab')),
      findsOneWidget,
    );
    // Typewriter needs text: shapes have text, so it is enabled; Draw line
    // is listed under Shape.
    await tester.tap(find.byKey(const ValueKey('slides.animate.tile.rise')));
    await tester.pumpAndSettle();
    final b = rig.session.model.buildsOf(f.s1).single;
    expect((b.elementId, b.effect), (f.shape, 'rise'));
    expect(
      find.byKey(const ValueKey('slides.animate.buildDetails')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('slides.animate.settle')), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    // Auto-preview plays the new build on the canvas.
    expect(find.byKey(AnimateCanvasKeys.preview), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(AnimateCanvasKeys.preview), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('slides.animate.removeBuild')),
    );
    await tester.tap(find.byKey(const ValueKey('slides.animate.removeBuild')));
    await tester.pumpAndSettle();
    expect(rig.session.model.buildsOf(f.s1), isEmpty);
    await rig.close(tester);
  });

  testWidgets('Given the Transition tab when Push is picked and the arrow pad '
      'points up then the slide has a push up', (tester) async {
    final f = _deck(withBuilds: false);
    final rig = await pumpDeckScreen(
      tester,
      fixture: f.b,
      size: const Size(1440, 1800),
    );
    rig.editor.setCurrentSlide(f.s2);
    await rig.run('slides.panel.animate', {'tab': 'transition'});
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('slides.animate.transition.tile.push')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('slides.animate.transition.direction.up')),
    );
    await tester.tap(
      find.byKey(const ValueKey('slides.animate.transition.direction.up')),
    );
    await tester.pumpAndSettle();
    final spec = TransitionSpec.decode(
      rig.session.model.slide(f.s2)!.transitionJson,
    ).value;
    expect((spec.type, spec.params['direction']), ('push', 'up'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('slides.animate.transition.advance.true')),
    );
    await tester.tap(
      find.byKey(const ValueKey('slides.animate.transition.advance.true')),
    );
    await tester.pumpAndSettle();
    expect(
      TransitionSpec.decode(
        rig.session.model.slide(f.s2)!.transitionJson,
      ).value.advance.auto,
      isTrue,
    );
    await rig.close(tester);
  });

  testWidgets('Given a Magic Move slide when the Transition tab is open then '
      'it counts the matches and the canvas badges them', (tester) async {
    final f = _deck(withBuilds: false);
    final rig = await pumpDeckScreen(tester, fixture: f.b);
    await rig.run('slides.slide.duplicateForMagicMove');
    await rig.run('slides.panel.animate', {'tab': 'transition'});
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('slides.animate.magicMove.count')),
      findsOneWidget,
    );
    expect(find.text('3 objects match the previous slide'), findsOneWidget);
    final copy = rig.editor.currentSlideId!;
    final ids = [for (final e in rig.session.model.elementsOf(copy)) e.id];
    expect(find.byKey(AnimateCanvasKeys.match(ids.first)), findsOneWidget);
    await rig.close(tester);
  });

  testWidgets('Given the Order tab when Preview is pressed then the slide '
      'plays on the canvas step by step and the edit frame returns', (
    tester,
  ) async {
    final f = _deck();
    final rig = await pumpDeckScreen(tester, fixture: f.b);
    await rig.run('slides.panel.animate', {'tab': 'order'});
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('slides.animate.order.Preview')),
    );
    await tester.pump();
    final p = AnimateView.of(rig.editor).preview;
    expect(p.active, isTrue);
    expect(find.byKey(AnimateCanvasKeys.preview), findsOneWidget);
    expect(find.byKey(AnimateCanvasKeys.previewBar), findsOneWidget);
    // Four clicks of builds with pauses: well under 10 s.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(p.active, isFalse);
    expect(find.byKey(AnimateCanvasKeys.preview), findsNothing);
    expect(tester.takeException(), isNull);
    await rig.close(tester);
  });

  testWidgets('Given a selected object when an effect tile is hovered then '
      'the effect previews on the canvas until the pointer leaves', (
    tester,
  ) async {
    final f = _deck(withBuilds: false);
    final rig = await pumpDeckScreen(
      tester,
      fixture: f.b,
      size: const Size(1440, 1800),
    );
    rig.editor.selectElements([f.shape]);
    await rig.run('slides.panel.animate', {'tab': 'build'});
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('slides.animate.tile.pop'))),
    );
    await tester.pump(const Duration(milliseconds: 450));
    final p = AnimateView.of(rig.editor).preview;
    expect((p.active, p.key), (true, 'pop'));
    expect(rig.session.model.buildsOf(f.s1), isEmpty);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 50));
    expect(p.active, isFalse);
    await rig.close(tester);
  });

  testWidgets('Given the Transition tab when a tile is focused then its live '
      'preview of the previous slide → this slide plays inside it', (
    tester,
  ) async {
    final f = _deck(withBuilds: false);
    final rig = await pumpDeckScreen(tester, fixture: f.b);
    rig.editor.setCurrentSlide(f.s2);
    await rig.run('slides.panel.animate', {'tab': 'transition'});
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('slides.animate.transition.tile.cube')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('slides.animate.transition.live.cube')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('slides.animate.transition.live.cube')),
      findsNothing,
    );
    await rig.close(tester);
  });

  testWidgets('Given a 360 px window when the Animate tab shows each sub-tab '
      'then nothing overflows', (tester) async {
    final f = _deck();
    final rig = await pumpDeckScreen(
      tester,
      fixture: f.b,
      size: const Size(360, 780),
    );
    rig.editor.selectElements([f.body]);
    for (final tab in ['transition', 'build', 'order']) {
      await rig.run('slides.panel.animate', {'tab': tab});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    await rig.close(tester);
  });

  testWidgets('Given the narrowest inspector (260 px) when each sub-tab shows '
      'then nothing overflows', (tester) async {
    final f = _deck();
    final rig = await pumpDeckScreen(tester, fixture: f.b);
    rig.editor.resizePane('inspector', 260, commit: true);
    rig.editor.selectElements([f.body]);
    for (final tab in ['transition', 'build', 'order']) {
      await rig.run('slides.panel.animate', {'tab': tab});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    await rig.close(tester);
  });
}
