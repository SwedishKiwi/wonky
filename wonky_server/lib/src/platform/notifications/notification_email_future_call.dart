import 'package:serverpod/serverpod.dart';

import 'notification_service.dart';

/// Sends the email of a single notification right after it was created
/// (mentions and assignments; specs/07 §4).
class NotificationEmailFutureCall extends FutureCall {
  Future<void> send(Session session, int notificationId) async {
    try {
      await NotificationService.sendImmediate(session, notificationId);
    } on Exception catch (e, st) {
      session.log(
        'Notification email $notificationId failed: $e',
        level: LogLevel.error,
        stackTrace: st,
      );
    }
  }
}
