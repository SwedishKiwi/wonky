import 'package:serverpod/serverpod.dart';

import 'board_github.dart';
import 'github_review.dart';

/// Background work of the GitHub App (specs/16 §13): handling a stored
/// webhook delivery, and the debounced task review.
class BoardGithubFutureCall extends FutureCall {
  Future<void> handle(Session session, String deliveryId) =>
      BoardGithub.handleDelivery(session, deliveryId);

  Future<void> review(Session session, int prNumber, String headSha) async {
    try {
      await GithubReview.run(session, prNumber, headSha);
    } on Exception catch (e, st) {
      session.log(
        'board.github: review of #$prNumber failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }
}
