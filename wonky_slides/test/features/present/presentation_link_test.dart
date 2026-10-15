import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_slides/features/present/present_controller.dart';
import 'package:wonky_slides/features/present/present_ink.dart';
import 'package:wonky_slides/features/present/presentation_link.dart';

import '../../support/deck_screen.dart' show sampleDeck;
import 'fake_presentation_hub.dart';

/// Delivers pending stream events. The tests run in `testWidgets`' fake
/// async zone, so retry timers and the presenter's end delay elapse only
/// through [WidgetTester.pump] — no real time (specs/15 §4).
Future<void> _flush(WidgetTester tester) => tester.pump();

/// The presentation session on the client (Slides 10 §6): the presenter
/// view publishes, an audience view on another device follows (state,
/// black screen, laser, ink), its navigation reaches the presenter as
/// commands, and ending ends the audience. Presenting works offline.
void main() {
  final deck = sampleDeck();
  final deckUuid = UuidValue.fromString(deck.deckId);
  var now = 1000000;
  int clock() => now;

  setUp(() => now = 1000000);

  ({PresentController c, PresentationLink link}) presenter(
    FakePresentationHub hub,
  ) {
    final link = PresentationLink(
      transport: hub.transport(),
      deckUuid: deckUuid,
      role: PresentationRole.presenter,
      deviceLabel: 'Laptop',
      nowMs: clock,
      retryDelays: const [Duration(milliseconds: 5)],
    );
    final c = PresentController(
      model: deck.build(),
      view: PresentView.presenter,
      link: link,
      nowMs: clock,
      inkPrefix: 'p',
    );
    return (c: c, link: link);
  }

  ({PresentController c, PresentationLink link}) audience(
    FakePresentationHub hub,
    String sessionId,
  ) {
    final link = PresentationLink(
      transport: hub.transport(),
      deckUuid: deckUuid,
      role: PresentationRole.audience,
      deviceLabel: 'Projector',
      sessionId: sessionId,
      nowMs: clock,
    );
    final c = PresentController(
      model: deck.build(),
      view: PresentView.audience,
      link: link,
      nowMs: clock,
    );
    return (c: c, link: link);
  }

  testWidgets(
    'Given a presenter view and an audience device when the presenter '
    'navigates, blanks, points and draws then the audience follows',
    (tester) async {
      final hub = FakePresentationHub();
      final p = presenter(hub);
      p.link.start();
      await _flush(tester);
      expect(p.link.status, PresentationLinkStatus.connected);
      final sid = p.link.sessionId!;

      final a = audience(hub, sid);
      a.link.start();
      await _flush(tester);

      expect(a.link.status, PresentationLinkStatus.connected);
      expect(a.link.presenterDevice, 'Laptop');
      expect(p.link.participants.single.deviceLabel, 'Projector');
      expect(a.c.position, p.c.position);

      now += 500;
      p.c.next();
      await _flush(tester);
      expect(a.c.position, p.c.position);

      p.c.setBlank(PresentBlank.black);
      await _flush(tester);
      expect(a.c.blank, PresentBlank.black);
      now += 500;
      p.c.next();
      await _flush(tester);
      expect(a.c.blank, PresentBlank.none);

      p.c.setTool(PresentTool.laser);
      now += 50;
      p.c.pointerMove(const Offset(300, 200));
      await _flush(tester);
      expect(a.c.laser, const Offset(300, 200));

      p.c.setTool(PresentTool.pen);
      p.c.pointerDown(const Offset(10, 10));
      now += 16;
      p.c.pointerMove(const Offset(90, 10));
      p.c.pointerUp();
      await _flush(tester);
      final slide = p.c.position!.slideId;
      expect(a.c.ink.strokesOf(slide), hasLength(1));
      p.c.clearInk();
      await _flush(tester);
      expect(a.c.ink.strokesOf(slide), isEmpty);

      p.c.dispose();
      a.c.dispose();
      p.link.dispose();
      a.link.dispose();
    },
  );

  testWidgets('Given an audience device when its clicker advances then the '
      'presenter applies the command and the audience follows', (tester) async {
    final hub = FakePresentationHub();
    final p = presenter(hub);
    p.link.start();
    await _flush(tester);
    final a = audience(hub, p.link.sessionId!);
    a.link.start();
    await _flush(tester);
    final before = p.c.position;

    now += 500;
    expect(a.c.next(), isTrue);
    await _flush(tester);

    expect(p.c.position, isNot(before));
    expect(a.c.position, p.c.position);
    p.c.dispose();
    a.c.dispose();
    p.link.dispose();
    a.link.dispose();
  });

  testWidgets('Given an audience device when the presenter ends then the '
      'audience session ends', (tester) async {
    final hub = FakePresentationHub();
    final p = presenter(hub);
    p.link.start();
    await _flush(tester);
    final a = audience(hub, p.link.sessionId!);
    a.link.start();
    await _flush(tester);

    p.c.end();
    // The presenter lets the end reach the server before closing.
    await tester.pump(const Duration(milliseconds: 80));

    expect(a.link.status, PresentationLinkStatus.ended);
    expect(a.link.endedReason, 'ended');
    a.c.dispose();
    a.link.dispose();
    p.c.dispose();
    p.link.dispose();
  });

  testWidgets('Given an unknown session when an audience joins then it ends '
      'with notFound', (tester) async {
    final hub = FakePresentationHub();
    final a = audience(hub, 'NoSuchSession0000000000');
    a.link.start();
    await _flush(tester);

    expect(a.link.status, PresentationLinkStatus.ended);
    expect(a.link.endedReason, 'notFound');
    a.c.dispose();
    a.link.dispose();
  });

  testWidgets('Given no connection when the presenter view starts then '
      'presenting works offline and the session joins once online', (
    tester,
  ) async {
    final hub = FakePresentationHub()..offline = true;
    final p = presenter(hub);
    p.link.start();
    await _flush(tester);

    expect(p.link.status, PresentationLinkStatus.offline);
    now += 500;
    expect(p.c.next(), isTrue);
    expect(p.c.position, isNotNull);

    hub.offline = false;
    // The next retry (5 ms) joins.
    await tester.pump(const Duration(milliseconds: 30));
    expect(p.link.status, PresentationLinkStatus.connected);
    // The full state was published after (re)joining.
    expect(
      hub.presenterUpdates
          .whereType<PresentationStateUpdate>()
          .last
          .state
          .slideId,
      p.c.position!.slideId,
    );
    p.c.dispose();
    p.link.dispose();
  });

  group('ClockOffset', () {
    test('Given samples with network delay then the smallest delay wins and '
        'elapsed times are derived in the local clock', () {
      final c = ClockOffset();
      // The local clock is 2,000 ms ahead; delays of 80, 20 and 50 ms.
      c.sample(10000, 12080);
      c.sample(11000, 13020);
      c.sample(12000, 14050);

      expect(c.offsetMs, 2020);
      expect(c.serverNow(15020), 13000);
      expect(c.sinceServer(12500, 15020), 500);
      expect(c.sinceServer(14000, 15020), 0);
    });
  });
}
