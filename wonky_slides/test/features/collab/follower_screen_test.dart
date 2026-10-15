import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show PresentationCommandEvent, PresentationRole, PresentationState;
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides_core/model.dart';

import '../present/fake_presentation_hub.dart';
import '../present/present_rig.dart';
import '../../support/deck_screen.dart' show sampleDeck;

PresentationState _state(int revision, String slideId) => PresentationState(
  revision: revision,
  slideId: slideId,
  step: 0,
  stepElapsedMs: 0,
  blank: 'none',
  picker: false,
  endScreen: false,
  timerRunning: true,
  timerElapsedMs: 0,
);

List<String> sampleIds() => [
  for (final e in sampleDeck().build().indexes.order.entries) e.id,
];

/// The follower view of a collaborator's presentation (Slides 09 §1.6,
/// 10 §6.3; SL-37): `?view=follow&session=` joins as `follower`, follows
/// slides, never sends commands, browses away locally and returns.
void main() {
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  testWidgets('Given a follower view of a live session then it joins as a '
      'follower, follows the presenter, browses away without controlling, '
      'returns with Shift+R and ends with the presentation', (tester) async {
    final hub = FakePresentationHub();
    final ids = sampleIds();
    final sid = hub.seed(_state(1, ids[1]), device: 'MacBook · Chrome');

    final r = await pumpPresent(
      tester,
      view: PresentView.follower,
      sessionId: sid,
      transport: hub.transport(),
      size: const Size(360, 640),
    );
    await r.settle(tester);

    expect(key('slides.present.follower'), findsOneWidget);
    expect(key('slides.present.followerBar'), findsOneWidget);
    expect(
      find.text('Following the presenter — press Esc to stop'),
      findsOneWidget,
    );
    expect(hub.sessions[sid]!.members.single.role, PresentationRole.follower);
    expect(r.shown, r.ids[1]);

    hub.publish(sid, _state(2, r.ids[3]));
    await r.settle(tester, 2);
    expect(r.shown, r.ids[3]);

    // Navigation browses away locally; nothing reaches the presenter.
    await r.press(tester, LogicalKeyboardKey.arrowLeft);
    await r.settle(tester, 2);
    expect(r.controller.browsing, isTrue);
    expect(r.shown, isNot(r.ids[3]));
    expect(
      hub.seededPresenterEvents.whereType<PresentationCommandEvent>(),
      isEmpty,
    );
    expect(key('slides.present.followerBar.return'), findsOneWidget);

    hub.publish(sid, _state(3, r.ids[0]));
    await r.settle(tester, 2);
    expect(r.controller.browsing, isTrue);

    await r.press(tester, LogicalKeyboardKey.keyR, shift: true);
    await r.settle(tester, 2);
    expect(r.controller.browsing, isFalse);
    expect(r.shown, r.ids[0]);
    expect(tester.takeException(), isNull);

    hub.end(sid);
    await r.settle(tester, 3);
    expect(r.location, r.deckPath);
    await tester.pump(const Duration(seconds: 5));
    await r.close(tester);
  });

  testWidgets('Given a follower view when Esc is pressed then following '
      'stops and the editor shows again', (tester) async {
    final hub = FakePresentationHub();
    final sid = hub.seed(_state(1, sampleIds()[0]));
    final r = await pumpPresent(
      tester,
      view: PresentView.follower,
      sessionId: sid,
      transport: hub.transport(),
    );
    await r.settle(tester);

    await r.press(tester, LogicalKeyboardKey.escape);
    await r.settle(tester, 2);

    expect(r.location, r.deckPath);
    await tester.pump(const Duration(seconds: 5));
    await r.close(tester);
  });
}
