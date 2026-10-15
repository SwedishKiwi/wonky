import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides/features/comments/comment_badge.dart';
import 'package:wonky_slides/features/comments/comment_pins_layer.dart';

import '../../support/slides_harness.dart';
import 'comments_rig.dart';

void main() {
  for (final brightness in Brightness.values) {
    group('Given comments on the current slide (${brightness.name})', () {
      testWidgets('when the canvas shows then each anchor has a pin, and a '
          'click docks the thread card next to it until Esc', (tester) async {
        final r = (await tester.runAsync(CommentsRig.open))!;
        r.d.editor.selectElements([r.f.box]);
        final id = (await tester.runAsync(
          () => r.comment('Check the number'),
        ))!;
        await tester.runAsync(() => r.comment('And the source'));
        r.d.editor.clearElementSelection();
        r.controller.activate(null);
        await r.pump(tester, brightness: brightness);

        final pin = find.byKey(
          ValueKey<String>('slides.comments.pin.${r.f.box}'),
        );
        expect(pin, findsOneWidget);
        expect(
          tester
              .widget<CommentPin>(
                find.descendant(of: pin, matching: find.byType(CommentPin)),
              )
              .count,
          2,
        );

        await tester.tap(pin);
        await tester.pumpAndSettle();
        expect(r.controller.activeThreadUuid, id);
        expect(find.byKey(ValueKey('slides.comments.docked.$id')), findsOne);
        expect(
          find.byKey(const ValueKey('slides.comments.activeOutline')),
          findsOne,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('slides.comments.docked.$id')),
          findsNothing,
        );
        await r.close(tester);
      });
    });
  }

  testWidgets('when hovering a pin for 300 ms then the hover card shows the '
      'first comment', (tester) async {
    final r = (await tester.runAsync(CommentsRig.open))!;
    await tester.runAsync(() => r.comment('Slide-level remark'));
    r.controller.activate(null);
    await r.pump(tester);
    final pin = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('slides.comments.pin.'),
    );
    expect(pin, findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(pin));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('slides.comments.hoverCard')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('slides.comments.hoverCard')), findsOne);
    expect(find.text('Slide-level remark'), findsOneWidget);
    await r.close(tester);
  });

  testWidgets('when commenting without a body while the panel is closed then '
      'the composer opens next to the pin, and Esc cancels', (tester) async {
    final r = (await tester.runAsync(CommentsRig.open))!;
    await r.pump(tester);
    r.d.editor.selectElements([r.f.shape]);

    await r.run('shell.comments.create');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('slides.comments.composer')), findsOne);
    expect(r.services.panels.isOpen(ShellPanels.comments), isFalse);
    await tester.tap(find.byType(EditableText).first);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(r.controller.draftAnchor, isNull);
    await r.close(tester);
  });

  testWidgets('when the pins are turned off then no pin is drawn', (
    tester,
  ) async {
    final r = (await tester.runAsync(CommentsRig.open))!;
    await tester.runAsync(() => r.comment('Hidden'));
    await r.pump(tester);

    await r.run('slides.view.toggleCommentPins');
    await tester.pump();

    expect(find.byType(CommentPin), findsNothing);
    await r.close(tester);
  });

  testWidgets('when the canvas is 360 px wide then the docked card fits', (
    tester,
  ) async {
    final r = (await tester.runAsync(CommentsRig.open))!;
    r.d.editor.selectElements([r.f.shape]);
    final id = (await tester.runAsync(() => r.comment('Narrow')))!;
    await r.pump(tester, size: const Size(360, 640));

    await r.run('slides.comments.show', {'threadUuid': id});
    await tester.pumpAndSettle();

    final card = find.byKey(ValueKey('slides.comments.docked.$id'));
    expect(card, findsOne);
    expect(tester.getSize(card).width, lessThanOrEqualTo(344));
    expect(tester.takeException(), isNull);
    await r.close(tester);
  });

  testWidgets('when a slide has open comments then its badge counts them and '
      'a click opens the panel scoped to the slide', (tester) async {
    final r = (await tester.runAsync(CommentsRig.open))!;
    await tester.runAsync(() => r.comment('One'));
    await tester.runAsync(() => r.comment('Two'));
    await pumpSlides(
      tester,
      r.d.h,
      Center(
        child: SlideCommentBadge(editor: r.d.editor, slideId: r.f.s1),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 comments'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('slides.comments.badge.${r.f.s1}')));
    await tester.pumpAndSettle();

    expect(r.services.panels.isOpen(ShellPanels.comments), isTrue);
    expect(r.controller.scope, 'slide');
    await r.close(tester);
  });
}
