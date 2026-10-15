import 'dart:async';

import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_slides/features/present/presentation_link.dart';

/// An in-memory presentation session server (Slides 10 §6) for client
/// tests: presenters create sessions, audiences join them, state, laser and
/// ink go to the members, commands go to the presenter, `end` ends it.
/// [offline] makes every join fail like a dropped connection.
class FakePresentationHub {
  final Map<String, FakeSession> sessions = {};
  bool offline = false;
  int _ids = 0;
  int serverMs = 5000000;

  PresentationTransport transport() => _FakeTransport(this);

  /// Every update the presenters sent (newest last).
  final List<PresentationUpdate> presenterUpdates = [];

  /// Events a [seed]ed presenter received (commands, roster).
  final List<PresentationEvent> seededPresenterEvents = [];

  /// A live session whose presenter is "on another device" (it only
  /// records what it receives); returns the session id.
  String seed(PresentationState state, {String device = 'Laptop'}) {
    final id = 'Seeded${_ids++}AbCdEfGhIjKlMnOp';
    final out = StreamController<PresentationEvent>();
    out.stream.listen(seededPresenterEvents.add);
    sessions[id] = FakeSession(id)
      ..presenter = FakeConn('seed', PresentationRole.presenter, device, out)
      ..last = state;
    return id;
  }

  /// The seeded presenter publishes [state] to the session's members.
  void publish(String sessionId, PresentationState state) {
    final s = sessions[sessionId]!;
    s.last = state;
    for (final m in s.members) {
      m.add(PresentationStateEvent(serverTimeMs: serverMs, state: state));
    }
  }

  /// The seeded presenter ends the session.
  void end(String sessionId) {
    final s = sessions.remove(sessionId)!;
    for (final m in [...s.members]) {
      m.add(PresentationEndedEvent(serverTimeMs: serverMs, reason: 'ended'));
      unawaited(m.out.close());
    }
  }
}

class FakeSession {
  FakeSession(this.id);

  final String id;
  FakeConn? presenter;
  final List<FakeConn> members = [];
  PresentationState? last;
}

class FakeConn {
  FakeConn(this.id, this.role, this.device, this.out);

  final String id;
  final PresentationRole role;
  final String device;
  final StreamController<PresentationEvent> out;
  StreamSubscription<PresentationUpdate>? sub;

  void add(PresentationEvent e) {
    if (!out.isClosed) out.add(e);
  }
}

class _FakeTransport implements PresentationTransport {
  _FakeTransport(this.hub);

  final FakePresentationHub hub;

  @override
  Future<PresentationSessionInfo?> findSession(UuidValue deckUuid) async {
    for (final s in hub.sessions.values) {
      final p = s.presenter;
      if (p != null) {
        return PresentationSessionInfo(
          sessionId: s.id,
          deviceLabel: p.device,
          startedAtMs: 0,
        );
      }
    }
    return null;
  }

  @override
  Stream<PresentationEvent> join(
    UuidValue deckUuid,
    PresentationJoin join,
    Stream<PresentationUpdate> updates,
  ) {
    if (hub.offline) return Stream.error(StateError('offline'));
    late final StreamController<PresentationEvent> out;
    late final FakeConn conn;
    int now() => hub.serverMs;
    void roster(FakeSession s) => s.presenter?.add(
      PresentationRosterEvent(
        serverTimeMs: now(),
        participants: [
          for (final m in s.members)
            PresentationParticipant(
              connectionId: m.id,
              role: m.role,
              deviceLabel: m.device,
              userId: 1,
              displayName: 'Anna',
            ),
        ],
      ),
    );
    out = StreamController<PresentationEvent>(
      onListen: () {
        final id = 'c${hub._ids++}';
        conn = FakeConn(id, join.role, join.deviceLabel, out);
        if (join.role == PresentationRole.presenter) {
          final sid = join.sessionId ?? 'Session${hub._ids}AbCdEfGhIjKlMn';
          final s = hub.sessions.putIfAbsent(sid, () => FakeSession(sid));
          if (s.presenter != null && join.takeOver != true) {
            conn.add(
              PresentationEndedEvent(
                serverTimeMs: now(),
                reason: 'presenterActive',
              ),
            );
            unawaited(out.close());
            return;
          }
          s.presenter?.add(
            PresentationEndedEvent(serverTimeMs: now(), reason: 'takenOver'),
          );
          s.presenter = conn;
          conn.add(
            PresentationWelcome(
              serverTimeMs: now(),
              sessionId: sid,
              connectionId: id,
              role: join.role,
              presenterConnected: true,
              presenterDevice: join.deviceLabel,
              state: s.last,
            ),
          );
          if (s.members.isNotEmpty) roster(s);
          conn.sub = updates.listen((u) {
            hub.presenterUpdates.add(u);
            switch (u) {
              case PresentationStateUpdate(:final state):
                s.last = state;
                for (final m in s.members) {
                  m.add(
                    PresentationStateEvent(serverTimeMs: now(), state: state),
                  );
                }
              case PresentationLaserUpdate(:final slideId, :final x, :final y):
                for (final m in s.members) {
                  m.add(
                    PresentationLaserEvent(
                      serverTimeMs: now(),
                      slideId: slideId,
                      x: x,
                      y: y,
                    ),
                  );
                }
              case PresentationInkUpdate(
                :final slideId,
                :final op,
                :final strokeId,
                :final strokeJson,
              ):
                for (final m in s.members) {
                  m.add(
                    PresentationInkEvent(
                      serverTimeMs: now(),
                      slideId: slideId,
                      op: op,
                      strokeId: strokeId,
                      strokeJson: strokeJson,
                    ),
                  );
                }
              case PresentationEndUpdate():
                for (final m in [...s.members]) {
                  m.add(
                    PresentationEndedEvent(
                      serverTimeMs: now(),
                      reason: 'ended',
                    ),
                  );
                  unawaited(m.out.close());
                }
                hub.sessions.remove(sid);
              case PresentationCommandUpdate():
                break;
            }
          });
          return;
        }
        final s = hub.sessions[join.sessionId];
        if (s == null) {
          conn.add(
            PresentationEndedEvent(serverTimeMs: now(), reason: 'notFound'),
          );
          unawaited(out.close());
          return;
        }
        s.members.add(conn);
        conn.add(
          PresentationWelcome(
            serverTimeMs: now(),
            sessionId: s.id,
            connectionId: id,
            role: join.role,
            presenterConnected: s.presenter != null,
            presenterDevice: s.presenter?.device,
            state: s.last,
            stateSentAtMs: now(),
          ),
        );
        roster(s);
        conn.sub = updates.listen((u) {
          if (u is PresentationCommandUpdate) {
            s.presenter?.add(
              PresentationCommandEvent(
                serverTimeMs: now(),
                command: u.command,
                argsJson: u.argsJson,
                fromConnectionId: id,
              ),
            );
          }
        });
      },
      onCancel: () async {
        await conn.sub?.cancel();
        for (final s in hub.sessions.values) {
          if (s.members.remove(conn)) roster(s);
          if (identical(s.presenter, conn)) s.presenter = null;
        }
      },
    );
    return out.stream;
  }
}
