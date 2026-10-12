import 'package:serverpod/serverpod.dart';

import '../common/errors.dart';
import '../common/models.dart';
import '../common/time.dart';
import '../users/user_service.dart';

/// "Report a problem" and client error reports (specs/03, 11 §5).
class FeedbackEndpoint extends Endpoint {
  static const maxMessage = 20000;
  static const maxStack = 50000;

  Future<void> submit(Session session, FeedbackSubmission feedback) =>
      _store(session, feedback);

  /// Client error reports (anonymized state, no document content).
  Future<void> reportError(Session session, FeedbackSubmission report) =>
      _store(session, report.copyWith(kind: FeedbackKind.errorReport));

  Future<void> _store(Session session, FeedbackSubmission f) async {
    if (f.message.trim().isEmpty) throw Errors.invalid('The message is empty.');
    int? userId;
    if (session.authenticated != null) {
      userId = (await UserService.actorOf(session)).userId;
    }
    String cap(String s, int n) => s.length > n ? s.substring(0, n) : s;
    await FeedbackReport.db.insertRow(
      session,
      FeedbackReport(
        userId: userId,
        kind: f.kind,
        message: cap(f.message, maxMessage),
        app: cap(f.app, 32),
        appVersion: cap(f.appVersion, 64),
        platform: cap(f.platform, 64),
        route: f.route == null ? null : cap(f.route!, 500),
        stackTrace: f.stackTrace == null ? null : cap(f.stackTrace!, maxStack),
        contextJson: f.contextJson == null
            ? null
            : cap(f.contextJson!, maxMessage),
        createdAt: nowUtc(),
      ),
    );
    session.log(
      'Feedback (${f.kind.name}) from ${f.app} ${f.appVersion} on ${f.platform}',
      level: f.kind == FeedbackKind.errorReport
          ? LogLevel.warning
          : LogLevel.info,
    );
  }
}
