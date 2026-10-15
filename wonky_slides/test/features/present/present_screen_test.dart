import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show PresentationCommandEvent, PresentationState;
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides/features/present/present_ink.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';
import 'package:wonky_ui/testing.dart';

import 'package:wonky_slides_core/model.dart';

import '../../support/deck_screen.dart' show sampleDeck;

import 'fake_presentation_hub.dart';
import 'present_rig.dart';

PresentationState _state(
  int revision,
  String slideId, {
  String blank = 'none',
}) => PresentationState(
  revision: revision,
  slideId: slideId,
  step: 0,
  stepElapsedMs: 0,
  blank: blank,
  picker: false,
  endScreen: false,
  timerRunning: true,
  timerElapsedMs: 0,
);

/// The sample deck's slide ids (the same in every build of it).
List<String> sampleIds() => [
  for (final e in sampleDeck().build().indexes.order.entries) e.id,
];

/// Present mode and the presenter view (Slides 10 §1–§5; SL-19) over the
/// deck editor: the key and clicker map incl. skipped slides and groups,
/// *Go to slide n*, black/white, the picker, laser and ink, the help
/// overlay, ending, and the presenter view's layout in light, dark and at
/// 360 px — online with a session and offline.
void main() {
  final l = slidesL10nEnglish;
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  testWidgets('Given present mode when every navigation key is pressed then '
      'it steps through the deck, skipping the skipped slide', (tester) async {
    final r = await pumpPresent(tester);
    final ids = r.ids; // title, Mission, Problem (skipped), Demo
    final s0 = ids[0], s1 = ids[1], s2 = ids[2], s3 = ids[3];
    expect(r.shown, s0);
    expect(key('slides.present.present'), findsOneWidget);

    final steps = <(LogicalKeyboardKey, bool, String)>[
      (LogicalKeyboardKey.arrowRight, false, s1),
      (LogicalKeyboardKey.arrowDown, false, s3),
      (LogicalKeyboardKey.arrowLeft, false, s1),
      (LogicalKeyboardKey.arrowUp, false, s0),
      (LogicalKeyboardKey.space, false, s1),
      (LogicalKeyboardKey.backspace, false, s0),
      (LogicalKeyboardKey.pageDown, false, s1),
      (LogicalKeyboardKey.pageUp, false, s0),
      (LogicalKeyboardKey.keyN, false, s1),
      (LogicalKeyboardKey.keyP, false, s0),
      (LogicalKeyboardKey.enter, false, s1),
      (LogicalKeyboardKey.space, true, s0),
      (LogicalKeyboardKey.bracketRight, false, s1),
      (LogicalKeyboardKey.bracketLeft, false, s0),
      (LogicalKeyboardKey.arrowRight, true, s1),
      (LogicalKeyboardKey.arrowLeft, true, s0),
      (LogicalKeyboardKey.end, false, s3),
      (LogicalKeyboardKey.home, false, s0),
    ];
    for (final (k, shift, expected) in steps) {
      await r.press(tester, k, shift: shift);
      expect(r.shown, expected, reason: '$k shift=$shift');
    }

    // Go to slide 3 (the skipped one) by number, then Next skips past it.
    await r.press(tester, LogicalKeyboardKey.digit3);
    expect(find.text(l.presentGoToNumber('3')), findsOneWidget);
    await r.press(tester, LogicalKeyboardKey.enter);
    expect(r.shown, s2);
    await r.press(tester, LogicalKeyboardKey.arrowRight);
    expect(r.shown, s3);
    expect(tester.takeException(), isNull);
    await r.close(tester);
  });

  testWidgets('Given the last slide when advancing then the end screen shows '
      'and the next advance returns to the editor at the shown slide', (
    tester,
  ) async {
    final r = await pumpPresent(tester);
    final last = r.ids.last;
    await r.press(tester, LogicalKeyboardKey.end);

    await r.press(tester, LogicalKeyboardKey.arrowRight);
    expect(key('slides.present.endScreen'), findsOneWidget);
    expect(find.text(l.presentEndScreen), findsOneWidget);
    await r.press(tester, LogicalKeyboardKey.arrowRight);

    expect(r.location, r.deckPath);
    expect(r.editor.currentSlideId, last);
    await r.close(tester);
  });

  testWidgets('Given present mode when Esc is pressed then the presentation '
      'ends at the shown slide', (tester) async {
    final r = await pumpPresent(tester);
    await r.press(tester, LogicalKeyboardKey.arrowRight);
    final shown = r.shown;

    await r.press(tester, LogicalKeyboardKey.escape);

    expect(r.location, r.deckPath);
    expect(r.editor.currentSlideId, shown);
    await r.close(tester);
  });

  testWidgets('Given present mode when B, ".", W and "," are pressed then '
      'black and white screens toggle and navigation returns first', (
    tester,
  ) async {
    final r = await pumpPresent(tester);
    final c = r.controller;

    await r.press(tester, LogicalKeyboardKey.keyB);
    expect(c.blank, PresentBlank.black);
    await r.press(tester, LogicalKeyboardKey.keyB);
    expect(c.blank, PresentBlank.none);
    await r.press(tester, LogicalKeyboardKey.period);
    expect(c.blank, PresentBlank.black);
    await r.press(tester, LogicalKeyboardKey.keyW);
    expect(c.blank, PresentBlank.white);
    await r.press(tester, LogicalKeyboardKey.comma);
    expect(c.blank, PresentBlank.none);
    await r.press(tester, LogicalKeyboardKey.keyW);
    await r.press(tester, LogicalKeyboardKey.arrowRight);
    expect(c.blank, PresentBlank.none);
    expect(r.shown, r.ids[0]);
    await tester.pump(const Duration(milliseconds: 300));
    await r.close(tester);
  });

  testWidgets('Given the slide picker when opened with G then groups and the '
      'skipped slide show, picking the skipped slide shows it and Next '
      'continues after it', (tester) async {
    final r = await pumpPresent(tester);

    await r.press(tester, LogicalKeyboardKey.keyG);
    expect(key('slides.present.picker'), findsOneWidget);
    final intro = r.editor.model.groups.single;
    expect(key('slides.present.picker.group.${intro.id}'), findsOneWidget);
    expect(find.text('Intro'), findsWidgets);

    await tester.tap(key('slides.present.picker.slide.${r.ids[2]}'));
    await tester.pump();
    expect(key('slides.present.picker'), findsNothing);
    expect(r.shown, r.ids[2]);

    await r.press(tester, LogicalKeyboardKey.arrowRight);
    expect(r.shown, r.ids[3]);

    // "-" opens it too; typing filters (no shortcuts run); Esc closes it,
    // and the next Esc ends the presentation.
    await r.press(tester, LogicalKeyboardKey.minus);
    expect(key('slides.present.picker'), findsOneWidget);
    await tester.enterText(key('slides.present.picker.filter'), 'mission');
    await tester.pump();
    expect(key('slides.present.picker.slide.${r.ids[1]}'), findsOneWidget);
    expect(key('slides.present.picker.slide.${r.ids[3]}'), findsNothing);
    await r.press(tester, LogicalKeyboardKey.escape);
    expect(key('slides.present.picker'), findsNothing);
    expect(r.location, isNot(r.deckPath));
    await settleTooltips(tester);
    await r.close(tester);
  });

  testWidgets('Given the tools when L, D, H, E, C, Mod+Z and Esc are used then '
      'laser and ink work on the slide', (tester) async {
    final r = await pumpPresent(tester);
    final c = r.controller;
    final stage = key('slides.present.stage');
    final center = tester.getCenter(stage);

    await r.press(tester, LogicalKeyboardKey.keyL);
    expect(c.tool, PresentTool.laser);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: center);
    await mouse.moveTo(center + const Offset(10, 10));
    await tester.pump();
    expect(c.laser, isNotNull);

    await r.press(tester, LogicalKeyboardKey.keyD);
    expect(c.tool, PresentTool.pen);
    await tester.dragFrom(center, const Offset(120, 40));
    await tester.pump();
    expect(c.ink.strokesOf(r.shown!), hasLength(1));

    await r.press(tester, LogicalKeyboardKey.keyH);
    expect(c.tool, PresentTool.highlighter);
    await tester.dragFrom(center + const Offset(0, 100), const Offset(120, 0));
    await tester.pump();
    expect(c.ink.strokesOf(r.shown!), hasLength(2));

    await r.press(tester, LogicalKeyboardKey.keyZ, mod: true);
    expect(c.ink.strokesOf(r.shown!), hasLength(1));

    await r.press(tester, LogicalKeyboardKey.keyE);
    expect(c.tool, PresentTool.eraser);
    await r.press(tester, LogicalKeyboardKey.keyC);
    expect(c.ink.strokesOf(r.shown!), isEmpty);

    await r.press(tester, LogicalKeyboardKey.escape);
    expect(c.tool, PresentTool.arrow);
    expect(r.location, isNot(r.deckPath));
    await mouse.removePointer();
    await r.close(tester);
  });

  testWidgets('Given present mode when "/" is pressed then the help overlay '
      'lists the present shortcuts', (tester) async {
    final r = await pumpPresent(tester);

    await r.press(tester, LogicalKeyboardKey.slash);

    expect(key('slides.present.help'), findsOneWidget);
    expect(find.text(l.presentHelpTitle), findsOneWidget);
    expect(find.text(l.presentBlackScreen), findsOneWidget);
    expect(find.text(l.cmdPresentNextSlide), findsOneWidget);
    await r.press(tester, LogicalKeyboardKey.escape);
    expect(key('slides.present.help'), findsNothing);
    await r.close(tester);
  });

  testWidgets('Given present mode when the slide is clicked then it advances, '
      'and the wheel steps back', (tester) async {
    final r = await pumpPresent(tester);
    final stage = key('slides.present.stage');

    r.clock[0] += 200;
    await tester.tap(stage, kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(r.shown, r.ids[1]);

    r.clock[0] += 200;
    final center = tester.getCenter(stage);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, -40)),
    );
    await tester.pump();
    expect(r.shown, r.ids[0]);
    await r.close(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Given the presenter view in ${brightness.name} when it shows '
        'a slide with notes then current, next, notes, timers and the strip '
        'show (offline: no session)', (tester) async {
      final r = await pumpPresent(
        tester,
        view: PresentView.presenter,
        brightness: brightness,
      );
      await r.press(tester, LogicalKeyboardKey.arrowRight);

      expect(key('slides.presenter'), findsOneWidget);
      expect(key('slides.presenter.currentSlide'), findsOneWidget);
      expect(key('slides.presenter.nextSlide'), findsOneWidget);
      expect(find.text('Say hello first'), findsOneWidget);
      expect(find.text(l.presenterNextSlide('Demo')), findsOneWidget);
      expect(find.text(l.presenterSlideOf(2, 4)), findsOneWidget);
      expect(key('slides.presenter.strip.${r.ids[2]}'), findsOneWidget);
      expect(find.text(l.presentOfflineNoDevices), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The strip goes to any slide (skipped ones too).
      await tester.tap(key('slides.presenter.strip.${r.ids[2]}'));
      await tester.pump();
      expect(r.shown, r.ids[2]);

      // Black screen from the presenter view shows the audience state.
      await r.press(tester, LogicalKeyboardKey.keyB);
      expect(find.text(l.presenterAudienceBlack), findsOneWidget);
      await tester.tap(key('slides.presenter.showSlide'));
      await tester.pump();
      expect(r.controller.blank, PresentBlank.none);
      await settleTooltips(tester);
      await r.close(tester);
    });
  }

  testWidgets('Given the presenter view at 360 px then it stacks without '
      'overflow', (tester) async {
    final r = await pumpPresent(
      tester,
      view: PresentView.presenter,
      size: const Size(360, 720),
    );

    expect(key('slides.presenter'), findsOneWidget);
    expect(find.text(l.presenterViewTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await settleTooltips(tester);
    await r.close(tester);
  });

  testWidgets('Given the presenter view with a session when Other device is '
      'pressed then the audience link and its QR code show', (tester) async {
    final hub = FakePresentationHub();
    final r = await pumpPresent(
      tester,
      view: PresentView.presenter,
      transport: hub.transport(),
    );
    await r.settle(tester);
    expect(find.text(l.presentAudienceDevices(0)), findsOneWidget);

    await tester.tap(key('slides.presenter.openOnDevice'));
    await r.settle(tester, 3);

    expect(key('dialog.slides.openOnDevice'), findsOneWidget);
    expect(key('dialog.slides.openOnDevice.qr'), findsOneWidget);
    final sid = hub.sessions.keys.single;
    expect(
      find.textContaining('present?view=audience&session=$sid'),
      findsOneWidget,
    );
    final dialog = r.services.openDialogs.single;
    expect(dialog.describe()['title'], l.presentOpenOnDeviceTitle);
    expect(dialog.press('done'), isTrue);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(key('dialog.slides.openOnDevice'), findsNothing);
    await settleTooltips(tester);
    await r.close(tester);
  });

  testWidgets('Given an audience view of a live session then it follows the '
      'presenter, sends its clicker as commands, and ends with the '
      'presentation', (tester) async {
    final hub = FakePresentationHub();
    final ids = (sampleIds()).toList();
    final sid = hub.seed(_state(1, ids[1]), device: 'MacBook · Chrome');

    final r = await pumpPresent(
      tester,
      view: PresentView.audience,
      sessionId: sid,
      transport: hub.transport(),
    );
    await r.settle(tester);

    expect(key('slides.present.audience'), findsOneWidget);
    expect(key('slides.present.audienceStart'), findsOneWidget);
    expect(
      find.text(l.presentAudienceBodyFrom('MacBook · Chrome')),
      findsOneWidget,
    );
    expect(r.shown, r.ids[1]);
    await tester.tap(key('slides.present.audienceStart.stay'));
    await tester.pump();
    expect(key('slides.present.audienceStart'), findsNothing);

    hub.publish(sid, _state(2, r.ids[3], blank: 'black'));
    await r.settle(tester, 2);
    expect(r.shown, r.ids[3]);
    expect(r.controller.blank, PresentBlank.black);

    await r.press(tester, LogicalKeyboardKey.pageDown);
    await r.settle(tester, 2);
    final cmd = hub.seededPresenterEvents
        .whereType<PresentationCommandEvent>()
        .single;
    expect(cmd.command, 'next');

    hub.end(sid);
    await r.settle(tester, 3);
    expect(r.location, r.deckPath);
    await tester.pump(const Duration(seconds: 5));
    await r.close(tester);
  });

  testWidgets('Given an audience link of an unknown session then it says the '
      'presentation is not running', (tester) async {
    final hub = FakePresentationHub();
    final r = await pumpPresent(
      tester,
      view: PresentView.audience,
      sessionId: 'NoSuchSession0000000000',
      transport: hub.transport(),
    );
    await r.settle(tester);

    expect(key('slides.present.audienceUnavailable'), findsOneWidget);
    expect(find.text(l.presentAudienceNotFound), findsOneWidget);
    await r.close(tester);
  });
}
