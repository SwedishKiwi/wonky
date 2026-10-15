import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_slides/features/present/broadcast/memory_present_channel.dart';
import 'package:wonky_slides/features/present/broadcast/present_fast_path.dart';

PresentationState _state(int revision) => PresentationState(
  revision: revision,
  slideId: 's$revision',
  step: 0,
  stepElapsedMs: 0,
  blank: 'none',
  picker: false,
  endScreen: false,
  timerRunning: false,
  timerElapsedMs: 0,
);

/// The same-browser fast path (Slides 10 §5.2; SL-41, on hold): two tabs
/// of one browser exchange the session messages over a channel.
void main() {
  tearDown(MemoryPresentChannel.reset);

  group('Given a presenter and an audience tab of one session', () {
    late List<PresentationEvent> toPresenter;
    late List<PresentationEvent> toAudience;
    late PresentFastPath presenter;
    late PresentFastPath audience;

    setUp(() {
      toPresenter = [];
      toAudience = [];
      presenter = PresentFastPath(
        sessionId: 'S1',
        connectionId: 'p',
        role: PresentationRole.presenter,
        onEvent: toPresenter.add,
        toServerMs: (ms) => ms - 100,
        nowMs: () => 1000,
      );
      audience = PresentFastPath(
        sessionId: 'S1',
        connectionId: 'a',
        role: PresentationRole.audience,
        onEvent: toAudience.add,
        toServerMs: (ms) => ms - 100,
        nowMs: () => 1000,
      );
    });

    tearDown(() {
      presenter.close();
      audience.close();
    });

    test('when the presenter sends state then the audience gets it in '
        'server time, and both see a live peer', () async {
      presenter.send(PresentationStateUpdate(state: _state(3)));
      await pumpEventQueue();

      final e = toAudience.single as PresentationStateEvent;
      expect(e.state.slideId, 's3');
      expect(e.serverTimeMs, 900);
      expect(audience.live, isTrue);
      expect(presenter.live, isTrue);
    });

    test('when the audience sends a command then only the presenter gets '
        'it, and audience state messages are not posted', () async {
      expect(
        audience.send(
          PresentationCommandUpdate(
            command: 'next',
            argsJson: jsonEncode({'_id': 'a.1'}),
          ),
        ),
        isTrue,
      );
      expect(audience.send(PresentationStateUpdate(state: _state(1))), isFalse);
      await pumpEventQueue();

      final c = toPresenter.single as PresentationCommandEvent;
      expect(c.command, 'next');
      expect(c.fromConnectionId, 'a');
      expect(toAudience, isEmpty);
    });

    test(
      'when the presenter ends then the audience gets an ended event',
      () async {
        presenter.send(PresentationEndUpdate());
        await pumpEventQueue();

        expect(
          toAudience.single,
          isA<PresentationEndedEvent>().having(
            (e) => e.reason,
            'reason',
            'ended',
          ),
        );
      },
    );

    test('when another session posts then nothing arrives', () async {
      final other = PresentFastPath(
        sessionId: 'S2',
        connectionId: 'q',
        role: PresentationRole.presenter,
        onEvent: (_) {},
        toServerMs: (ms) => ms,
      );
      other.send(PresentationStateUpdate(state: _state(9)));
      await pumpEventQueue();
      other.close();

      expect(toAudience, isEmpty);
    });
  });

  test(
    'Given a closed channel when posting then nothing is delivered',
    () async {
      final got = <String>[];
      final a = MemoryPresentChannel('x');
      final b = MemoryPresentChannel('x');
      final sub = b.messages.listen(got.add);
      b.close();
      a.post('hi');
      await pumpEventQueue();
      await sub.cancel();
      a.close();

      expect(got, isEmpty);
      expect(MemoryPresentChannel.openCount('x'), 0);
    },
  );
}
