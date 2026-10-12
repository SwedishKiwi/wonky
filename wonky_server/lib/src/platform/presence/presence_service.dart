import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import '../common/actor.dart';
import '../common/models.dart';
import '../common/roles.dart';
import '../common/time.dart';
import '../sharing/access_service.dart';
import '../users/user_service.dart';

/// Ephemeral presence (specs/07 §1). Nothing is stored: every joined session
/// keeps its own view of the roster from the `presence:<itemUuid>` channel
/// (global with Redis), so it works across server instances. A new session
/// says `hello`, everyone present answers `here`.
abstract final class PresenceService {
  /// Max hint messages per second and cells per message (Sheets 10 §2.1).
  static const maxHintsPerSecond = 20;
  static const maxHintCells = 500;
  static const maxHintBytes = 64 * 1024;

  static String channel(UuidValue itemUuid) => 'presence:${itemUuid.uuid}';

  static Stream<PresenceEvent> join(
    Session session,
    Actor actor,
    UuidValue itemUuid,
    Stream<PresenceUpdate> updates,
  ) {
    late StreamController<PresenceEvent> out;
    final sessionId = const Uuid().v4();
    final roster = <String, Participant>{};
    final followers = <String, String>{}; // follower → target
    var role = Role.viewer;
    Participant? me;
    StreamSubscription<PresenceUpdate>? input;
    var closed = false;
    var hintWindowStart = DateTime.fromMillisecondsSinceEpoch(0);
    var hintsInWindow = 0;
    String? following;
    final ch = channel(itemUuid);

    void emit(PresenceEvent e) {
      if (!out.isClosed) out.add(e);
    }

    void emitFollowerCount() {
      final count = followers.values.where((t) => t == sessionId).length;
      emit(PresenceFollowerCount(count: count));
    }

    void onBus(SerializableModel model) {
      if (model is! PresenceBusMessage || closed) return;
      final m = model;
      if (m.sessionId == sessionId) return;
      switch (m.type) {
        case 'hello':
          final p = m.participant;
          if (p == null) return;
          roster[p.sessionId] = p;
          emit(PresenceJoined(participant: p));
          if (me != null) {
            unawaited(
              session.messages.postMessage(
                ch,
                PresenceBusMessage(
                  type: 'here',
                  sessionId: sessionId,
                  participant: me,
                  replyTo: m.sessionId,
                ),
              ),
            );
          }
        case 'here':
          if (m.replyTo != sessionId || m.participant == null) return;
          if (!roster.containsKey(m.sessionId)) {
            roster[m.sessionId] = m.participant!;
            emit(PresenceJoined(participant: m.participant!));
          }
        case 'update':
          final p = roster[m.sessionId];
          if (p == null || m.state == null) return;
          roster[m.sessionId] = p.copyWith(
            state: m.state,
            cursorJson: m.cursorJson,
            mode: m.mode,
          );
          emit(
            PresenceUpdated(
              sessionId: m.sessionId,
              state: m.state!,
              cursorJson: m.cursorJson,
              mode: m.mode,
            ),
          );
        case 'hints':
          if (m.hints != null && m.hints!.isNotEmpty) {
            emit(PresenceHints(sessionId: m.sessionId, hints: m.hints!));
          }
        case 'follow':
          final before = followers[m.sessionId];
          if (m.target == null) {
            followers.remove(m.sessionId);
          } else {
            followers[m.sessionId] = m.target!;
          }
          if (before == sessionId || m.target == sessionId) {
            emitFollowerCount();
          }
        case 'bye':
          if (roster.remove(m.sessionId) != null) {
            emit(PresenceLeft(sessionId: m.sessionId));
          }
          if (followers.remove(m.sessionId) == sessionId) emitFollowerCount();
        case 'notice':
          emit(
            PresenceNotice(
              kind: m.noticeKind ?? 'notice',
              payloadJson: m.noticePayloadJson ?? '{}',
            ),
          );
      }
    }

    Future<void> leave() async {
      if (closed) return;
      closed = true;
      session.messages.removeListener(ch, onBus);
      await input?.cancel();
      await session.messages.postMessage(
        ch,
        PresenceBusMessage(type: 'bye', sessionId: sessionId),
      );
    }

    Future<void> handle(PresenceUpdate u) async {
      if (closed || me == null) return;
      me = me!.copyWith(state: u.state, cursorJson: u.cursorJson, mode: u.mode);
      await session.messages.postMessage(
        ch,
        PresenceBusMessage(
          type: 'update',
          sessionId: sessionId,
          state: u.state,
          cursorJson: u.cursorJson,
          mode: u.mode,
        ),
      );
      final hints = u.hints;
      if (hints != null && hints.isNotEmpty && role >= Role.editor) {
        final now = nowUtc();
        if (now.difference(hintWindowStart) > const Duration(seconds: 1)) {
          hintWindowStart = now;
          hintsInWindow = 0;
        }
        final accepted = <String>[];
        for (final h in hints) {
          if (hintsInWindow >= maxHintsPerSecond) break;
          if (h.length > maxHintBytes || !_validHint(h)) continue;
          accepted.add(h);
          hintsInWindow++;
        }
        if (accepted.isNotEmpty) {
          await session.messages.postMessage(
            ch,
            PresenceBusMessage(
              type: 'hints',
              sessionId: sessionId,
              hints: accepted,
            ),
          );
        }
      }
      if (u.followingSessionId != following) {
        following = u.followingSessionId;
        await session.messages.postMessage(
          ch,
          PresenceBusMessage(
            type: 'follow',
            sessionId: sessionId,
            target: following,
          ),
        );
      }
    }

    Future<void> start() async {
      final (item, r) = await AccessService.require(
        session,
        actor,
        itemUuid,
        Role.viewer,
      );
      role = r;
      final profile = await UserService.requireProfile(session, actor.userId);
      final summary = await UserService.summaryOf(session, profile);
      me = Participant(
        sessionId: sessionId,
        userId: actor.userId,
        userUuid: actor.authUserId,
        displayName: summary.displayName,
        avatarUrl: summary.avatarUrl,
        colorIndex: summary.colorIndex,
        role: role.access,
        actorKind: actor.kind,
        state: PresenceState.active,
        joinedAt: nowUtc(),
      );
      session.messages.addListener(ch, onBus);
      await session.messages.postMessage(
        ch,
        PresenceBusMessage(type: 'hello', sessionId: sessionId, participant: me),
      );
      emit(
        PresenceRoster(
          sessionId: sessionId,
          participants: [me!, ...roster.values],
        ),
      );
      input = updates.listen(
        (u) => unawaited(handle(u)),
        onDone: () async {
          await leave();
          if (!out.isClosed) await out.close();
        },
        onError: (Object _) async {
          await leave();
          if (!out.isClosed) await out.close();
        },
      );
      session.addWillCloseListener((_) => leave());
      if (item.trashedAt != null) {
        emit(PresenceNotice(kind: 'trashed', payloadJson: '{}'));
      }
    }

    out = StreamController<PresenceEvent>(
      onListen: () {
        start().catchError((Object e, StackTrace st) {
          if (!out.isClosed) {
            out.addError(e, st);
            unawaited(out.close());
          }
        });
      },
      onCancel: leave,
    );
    return out.stream;
  }

  static bool _validHint(String json) {
    try {
      final value = jsonDecode(json);
      if (value is! Map) return false;
      final cells = value['cells'];
      if (cells is List && cells.length > maxHintCells) return false;
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Shows an agent (MCP/AI) as a transient participant on [itemUuid] for
  /// [ttl] (specs/07 §1.1). Returns its session id.
  static Future<String> injectAgent(
    Session session,
    UuidValue itemUuid, {
    required Actor actor,
    required String displayName,
    Duration ttl = const Duration(seconds: 30),
  }) async {
    final sessionId = 'agent-${const Uuid().v4()}';
    final participant = Participant(
      sessionId: sessionId,
      userId: actor.userId,
      userUuid: actor.authUserId,
      displayName: displayName,
      colorIndex: UserService.colorIndexFor(actor.authUserId),
      role: AccessRole.editor,
      actorKind: actor.kind,
      state: PresenceState.active,
      joinedAt: nowUtc(),
    );
    final ch = channel(itemUuid);
    await session.messages.postMessage(
      ch,
      PresenceBusMessage(
        type: 'hello',
        sessionId: sessionId,
        participant: participant,
      ),
    );
    final messages = session.serverpod.server.messageCentral;
    Timer(ttl, () {
      messages.postMessage(
        ch,
        PresenceBusMessage(type: 'bye', sessionId: sessionId),
      );
    });
    return sessionId;
  }

  /// Broadcasts a system notice to everyone on [itemUuid].
  static Future<void> notice(
    Session session,
    UuidValue itemUuid,
    String kind,
    Map<String, Object?> payload,
  ) => session.messages.postMessage(
    channel(itemUuid),
    PresenceBusMessage(
      type: 'notice',
      sessionId: 'system',
      noticeKind: kind,
      noticePayloadJson: jsonEncode(payload),
    ),
  );
}
