import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show PresentationState;
import 'package:wonky_slides/features/collab/follow_presenter.dart';
import 'package:wonky_slides/features/collab/slides_presence_cursor.dart';
import 'package:wonky_slides/features/present/active_presentation.dart';
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides/features/present/presentation_link.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/testing.dart' show DeckBuilder;

import '../../support/slides_harness.dart';
import 'collab_rig.dart';

/// Following a presenter (Slides 09 §1.6, 10 §6.3; SL-37): the follower
/// view tracks the presenter's slide and step, never controls, may browse
/// away and return.

PresentationState _state(int revision, String slideId, {int step = 0}) =>
    PresentationState(
      revision: revision,
      slideId: slideId,
      step: step,
      stepElapsedMs: 0,
      blank: 'none',
      picker: false,
      endScreen: false,
      timerRunning: false,
      timerElapsedMs: 0,
    );

PresentController _follower(DeckModel model) => PresentController(
  model: model,
  view: PresentView.follower,
  timelineOf: (id) => SlideTimeline(slideId: id),
  nowMs: () => 0,
  burstMs: 0,
);

class _Handle implements PresentHandle {
  _Handle(this.controller);

  @override
  final PresentController controller;

  @override
  PresentationLink? get link => null;

  @override
  PresentView get view => PresentView.follower;

  @override
  Future<void> openOnAnotherDevice() async {}

  @override
  Future<void> toggleFullscreen() async {}
}

void main() {
  const session = 'AbCdEfGhIjKlMnOpQrStUv';

  test('Given the follow view name when parsed then it is the follower '
      'view, a member of the session like the audience', () {
    expect(PresentView.fromName('follow'), PresentView.follower);
    expect(PresentView.fromName('audience'), PresentView.audience);
    expect(PresentView.follower.isMember, isTrue);
    expect(PresentView.presenter.isMember, isFalse);
  });

  group('Given a follower view of a three-slide deck', () {
    late DeckModel model;
    late List<String> ids;
    setUp(() {
      final f = TextCanvasIds.build();
      model = f.$1;
      ids = f.$2;
    });

    test('when the presenter moves then the view follows slide and step', () {
      final c = _follower(model);
      expect(c.position, isNull);

      c.applyState(_state(1, ids[1]));
      expect(c.position?.slideId, ids[1]);
      c.applyState(_state(2, ids[2]));

      expect(c.position?.slideId, ids[2]);
      expect(c.mirrors, isTrue);
      expect(c.kiosk, isFalse);
      c.dispose();
    });

    test('when the follower navigates then it browses away locally, keeps '
        'its slide while the presenter moves, and returns to the '
        'presenter\'s latest slide', () {
      final c = _follower(model);
      c.applyState(_state(1, ids[1]));

      expect(c.previous(), isTrue);
      expect(c.browsing, isTrue);
      expect(c.position?.slideId, ids[0]);

      c.applyState(_state(2, ids[2]));
      expect(c.position?.slideId, ids[0]);

      c.returnToPresenter();
      expect(c.browsing, isFalse);
      expect(c.position?.slideId, ids[2]);
      c.dispose();
    });

    test('when the follower tries to blank the screen then nothing happens '
        '(followers can\'t control)', () {
      final c = _follower(model);
      c.applyState(_state(1, ids[0]));

      c.setBlank(PresentBlank.black);

      expect(c.blank, PresentBlank.none);
      c.dispose();
    });
  });

  group('Given Anna presenting and this window following her', () {
    for (final brightness in Brightness.values) {
      testWidgets('when the follower bar shows (${brightness.name}) then it '
          'names her, and after browsing away Return to presenter goes '
          'back', (tester) async {
        final r = await CollabRig.pump(tester, brightness: brightness);
        await r.join(
          tester,
          CollabRig.anna,
          SlidesPresenceCursor(
            route: 'present',
            slideId: r.f.slide,
            presenting: PresentingState(
              presentationId: session,
              slideId: r.f.slide,
            ),
          ),
        );
        final c = _follower(r.model);
        c.applyState(_state(1, r.f.placeholders));
        activePresentation.value = _Handle(c);
        addTearDown(() {
          activePresentation.value = null;
          c.dispose();
        });
        await pumpSlides(
          tester,
          r.d.h,
          Center(
            child: FollowerBar(
              services: r.d.services,
              controller: c,
              sessionId: session,
              fullscreen: false,
              onFullscreen: () {},
            ),
          ),
          brightness: brightness,
          size: const Size(360, 640),
        );

        expect(find.text('Following Anna — press Esc to stop'), findsOneWidget);
        expect(presenterOfSession(r.d.services, session)?.sessionId, 'anna');

        c.previous();
        await tester.pump();
        expect(find.text('You left Anna\'s slide'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('slides.present.followerBar.return')),
        );
        await tester.pump();

        expect(c.browsing, isFalse);
        expect(c.position?.slideId, r.f.placeholders);
        expect(tester.takeException(), isNull);
        await r.close(tester);
      });
    }
  });
}

/// A deck of three slides for the controller tests.
abstract final class TextCanvasIds {
  static (DeckModel, List<String>) build() {
    final b = DeckBuilder(title: 'Follow');
    final ids = [
      b.slide(layoutKey: 'title', title: 'One'),
      b.slide(title: 'Two'),
      b.slide(title: 'Three'),
    ];
    return (b.build(), ids);
  }
}
