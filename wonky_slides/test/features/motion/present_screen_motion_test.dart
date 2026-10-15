import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/present/present_sequence.dart';
import 'package:wonky_slides/features/stage/slide_stage.dart';
import 'package:wonky_slides_core/testing.dart';

import '../present/present_rig.dart';
import 'motion_fixture.dart';

void main() {
  testWidgets('Given present mode over a deck with builds when advancing to '
      'the next slide then its transition plays on the stage and the slide '
      'settles (10 AC 3, 06 AC 2)', (tester) async {
    final d = MotionDeck();
    final rig = await pumpPresent(
      tester,
      fixture: d.builder,
      model: d.model(),
      startSlideId: d.a,
    );
    rig.controller.goTo(d.a, 4);
    rig.clock[0] += 5000;
    await tester.pump();

    await rig.press(tester, LogicalKeyboardKey.arrowRight);
    rig.clock[0] += 300;
    await tester.pump(const Duration(milliseconds: 16));

    expect(rig.controller.position, PresentPosition(d.b));
    expect(
      find.byKey(const ValueKey('slides.motion.transition')),
      findsOneWidget,
    );
    rig.clock[0] += 2000;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(const ValueKey('slides.motion.transition')),
      findsNothing,
    );
    expect(find.byType(SlideStage), findsOneWidget);
    expect(rig.controller.animating, isFalse);

    await rig.close(tester);
  });

  testWidgets('Given a running build when the slide is clicked then the '
      'build finishes, and a second click advances (06 AC 4)', (tester) async {
    final d = MotionDeck();
    final rig = await pumpPresent(tester, fixture: d.builder, model: d.model());
    await rig.press(tester, LogicalKeyboardKey.space);
    expect(rig.controller.stepRunning, isTrue);

    await rig.press(tester, LogicalKeyboardKey.space);
    expect(rig.controller.stepRunning, isFalse);
    expect(rig.controller.position, PresentPosition(d.a, 1));
    await rig.press(tester, LogicalKeyboardKey.space);
    expect(rig.controller.position, PresentPosition(d.a, 2));

    await rig.close(tester);
  });

  testWidgets('Given ?kiosk=1 when time passes then it advances by itself, '
      'keys are ignored, and holding Esc for 2 s ends it (10 AC 8)', (
    tester,
  ) async {
    final d = MotionDeck();
    final rig = await pumpPresent(
      tester,
      fixture: d.builder,
      model: d.model(),
      kiosk: true,
    );
    final c = rig.controller;
    expect(c.kiosk, isTrue);

    await rig.press(tester, LogicalKeyboardKey.arrowRight);
    expect(c.position, PresentPosition(d.a));
    rig.clock[0] += 1000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.position, PresentPosition(d.a, 1));

    // A short Esc doesn't end it.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    rig.clock[0] += 500;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('slides.present.kioskExit')),
      findsOneWidget,
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.ended, isFalse);
    expect(
      find.byKey(const ValueKey('slides.present.kioskExit')),
      findsNothing,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    rig.clock[0] += 2000;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await rig.settle(tester);
    expect(rig.location, rig.deckPath);

    await rig.close(tester);
  });

  testWidgets('Given a code element while presenting when its copy button '
      'is clicked then the shown code is copied and the slide does not '
      'advance (07 §3.7)', (tester) async {
    final b = DeckBuilder(title: 'Code');
    final s = b.slide(layoutKey: 'blank');
    b.slide(layoutKey: 'blank');
    final (code, _) = b.codeBlock(s, states: ['print("hi");']);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final rig = await pumpPresent(tester, fixture: b);
    final target = find.byKey(ValueKey('slides.present.codeCopy.$code'));
    expect(target, findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(target));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('slides.present.codeCopy.button')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(copied, 'print("hi");');
    expect(rig.controller.position, PresentPosition(s));
    await gesture.removePointer();
    await tester.pump(const Duration(seconds: 2));
    await rig.close(tester);
  });
}
