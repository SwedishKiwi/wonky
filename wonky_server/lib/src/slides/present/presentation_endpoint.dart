import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import 'presentation_service.dart';

/// The presentation session of Wonky Slides (Slides 10 §6, A-10-5): the
/// presenter view in this window drives the audience view on another
/// device or browser (v2 is single-window, v2 review Q5/Q29).
class PresentationEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Joins a session on [deckUuid] (a presenter without a session id
  /// creates one). The first event is a [PresentationWelcome], or a
  /// [PresentationEndedEvent] when the session can't be joined.
  Stream<PresentationEvent> join(
    Session session,
    UuidValue deckUuid,
    PresentationJoin join,
    Stream<PresentationUpdate> updates,
  ) async* {
    final actor = await UserService.actorOf(session);
    yield* PresentationService.join(session, actor, deckUuid, join, updates);
  }

  /// The caller's own live presenter session on [deckUuid], or null.
  Future<PresentationSessionInfo?> findSession(
    Session session,
    UuidValue deckUuid,
  ) async => PresentationService.find(
    session,
    await UserService.actorOf(session),
    deckUuid,
  );

  /// The remote route of a typed six-digit pairing [code] (Slides 10 §6.4,
  /// SL-41), or null when no presenter issued it (or it expired). Needs ≥
  /// viewer on the deck; rate-limited per user.
  Future<PresentationPairingTarget?> resolvePairingCode(
    Session session,
    String code,
  ) async => PresentationService.resolveCode(
    session,
    await UserService.actorOf(session),
    code,
  );
}
