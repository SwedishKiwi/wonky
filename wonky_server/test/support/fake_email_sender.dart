import 'package:serverpod/serverpod.dart';
import 'package:wonky_server/src/platform/notifications/email/email_sender.dart';

/// Records sent emails; set [failWith] to make the next sends fail.
class FakeEmailSender implements EmailSender {
  final sent = <OutgoingEmail>[];
  EmailDeliveryException? failWith;

  @override
  bool get delivers => true;

  /// Emails sent to [address].
  List<OutgoingEmail> to(String address) => [
    for (final e in sent)
      if (e.to == address) e,
  ];

  @override
  Future<void> send(Session session, OutgoingEmail email) async {
    final failure = failWith;
    if (failure != null) throw failure;
    sent.add(email);
  }
}
