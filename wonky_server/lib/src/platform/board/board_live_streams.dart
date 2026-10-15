import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import 'board_access.dart';
import 'board_common.dart';

/// Live streams of the board (specs/16 §7.6).
abstract final class BoardStreams {
  /// Changes of post #[number] for a caller who can see it; ends with
  /// `postRemoved` when the post is gone or hidden from the caller.
  static Stream<BoardPostEvent> watchPost(Session session, int number) async* {
    final c = await BoardAccess.caller(session);
    final post = await BoardAccess.post(session, c, number);
    final signals = session.messages.createStream<BoardSignal>(
      BoardLive.postChannel(post.id!),
    );
    await for (final signal in signals) {
      final current = await BoardPost.db.findById(session, post.id!);
      if (current == null || !BoardAccess.canSeePost(c, current)) {
        yield BoardPostEvent(kind: BoardEventKind.postRemoved, number: number);
        return;
      }
      yield BoardPostEvent(kind: signal.kind, number: number);
    }
  }

  /// Task changes (claims, status) for the Up for grabs tab.
  static Stream<BoardPostEvent> watchTasks(Session session) async* {
    final c = await BoardAccess.caller(session);
    final signals = session.messages.createStream<BoardSignal>(
      BoardLive.tasksChannel,
    );
    await for (final signal in signals) {
      final task = await BoardTask.db.findById(session, signal.number);
      if (task != null && !BoardAccess.canSeeTask(c, task)) continue;
      yield BoardPostEvent(kind: signal.kind, number: signal.number);
    }
  }
}
