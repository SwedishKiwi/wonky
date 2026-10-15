import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';
import 'package:wonky_server/src/platform/notifications/email/email_sender.dart';
import 'package:wonky_server/src/platform/notifications/email/notification_emails.dart';

final _anna = UserSummary(
  id: 1,
  uuid: UuidValue.fromString('0190a8a0-0000-7000-8000-000000000001'),
  displayName: 'Anna',
  email: 'anna@example.test',
  avatarColor: '#ff0000',
  colorIndex: 0,
);

NotificationView _n(
  NotificationKind kind, {
  Map<String, Object?> payload = const {},
  DriveItemKind itemKind = DriveItemKind.document,
  String itemName = 'Plan <draft>',
  int id = 1,
  DateTime? at,
}) => NotificationView(
  id: id,
  kind: kind,
  itemUuid: UuidValue.fromString('0190a8a0-0000-7000-8000-00000000000a'),
  itemName: itemName,
  itemKind: itemKind,
  actor: _anna,
  payload: jsonEncode(payload),
  createdAt: at ?? DateTime.utc(2026, 10, 1, 12),
);

void main() {
  final emails = NotificationEmails(
    webOrigin: Uri.parse('https://wonky.example.com'),
  );

  group('Given notification views', () {
    final cases = [
      (
        NotificationKind.mention,
        const <String, Object?>{},
        'Anna mentioned you in “Plan <draft>”',
      ),
      (
        NotificationKind.reply,
        const <String, Object?>{},
        'Anna replied to a comment in “Plan <draft>”',
      ),
      (
        NotificationKind.shared,
        const {'role': 'editor'},
        'Anna shared “Plan <draft>” with you (editor)',
      ),
      (
        NotificationKind.accessRequest,
        const {'role': 'viewer'},
        'Anna requests viewer access to “Plan <draft>”',
      ),
      (
        NotificationKind.suggestion,
        const <String, Object?>{},
        'Anna suggested edits in “Plan <draft>”',
      ),
      (
        NotificationKind.suggestionDecided,
        const {'decision': 'rejected'},
        'Anna rejected your suggestion in “Plan <draft>”',
      ),
    ];
    for (final (kind, payload, expected) in cases) {
      test('when describing a ${kind.name} then it reads "$expected"', () {
        expect(emails.describe(_n(kind, payload: payload)), expected);
      });
    }

    test('when linking a document then the link opens it in Write', () {
      expect(
        emails.linkFor(_n(NotificationKind.mention)).toString(),
        'https://wonky.example.com/write/d/0190a8a0-0000-7000-8000-00000000000a',
      );
    });

    test('when linking a spreadsheet then the link opens it in Sheets', () {
      expect(
        emails
            .linkFor(
              _n(NotificationKind.shared, itemKind: DriveItemKind.spreadsheet),
            )
            .path,
        '/sheets/s/0190a8a0-0000-7000-8000-00000000000a',
      );
    });

    // (v2) Folders open in Wonky Drive (`/drive/f/`), presentations in
    // Slides and files in Drive's preview (suite 03 §2).
    for (final (kind, path) in [
      (DriveItemKind.folder, '/drive/f/'),
      (DriveItemKind.presentation, '/slides/p/'),
      (DriveItemKind.file, '/drive/file/'),
    ]) {
      test('when linking a ${kind.name} then the link is $path<uuid>', () {
        expect(
          emails.linkFor(_n(NotificationKind.shared, itemKind: kind)).path,
          '${path}0190a8a0-0000-7000-8000-00000000000a',
        );
      });
    }

    test('when linking a comment on a presentation then the link opens the '
        'thread (?comment=)', () {
      final link = emails.linkFor(
        _n(
          NotificationKind.mention,
          itemKind: DriveItemKind.presentation,
          payload: {'threadUuid': '0190a8a0-0000-7000-8000-0000000000cc'},
        ),
      );
      expect(link.path, '/slides/p/0190a8a0-0000-7000-8000-00000000000a');
      expect(
        link.queryParameters['comment'],
        '0190a8a0-0000-7000-8000-0000000000cc',
      );
    });

    test('when rendering a mention email then the HTML escapes names and '
        'quotes the comment', () {
      final email = emails.single(
        to: 'bo@example.test',
        displayName: 'Bo',
        notification: _n(
          NotificationKind.mention,
          payload: {'excerpt': 'Is <b>this</b> right?'},
        ),
      );

      expect(email.html, contains('Plan &lt;draft&gt;'));
      expect(email.html, contains('Is &lt;b&gt;this&lt;/b&gt; right?'));
      expect(email.text, contains('> Is <b>this</b> right?'));
      expect(email.text, contains('/write/settings/notifications'));
    });

    test('when rendering a digest of two items then both are listed newest '
        'first', () {
      final email = emails.digest(
        to: 'bo@example.test',
        displayName: 'Bo',
        notifications: [
          _n(NotificationKind.reply, id: 1, at: DateTime.utc(2026, 10, 1)),
          _n(
            NotificationKind.shared,
            id: 2,
            itemName: 'Budget',
            at: DateTime.utc(2026, 10, 2),
          ),
        ],
      );

      expect(email.subject, '2 new notifications in Wonky Work');
      expect(
        email.text.indexOf('Budget'),
        lessThan(email.text.indexOf('Plan <draft>')),
      );
    });
  });

  group('Given the email configuration', () {
    test('when no provider key is set then emails are logged', () {
      final sender = EmailSenders.fromConfig((_) => null);

      expect(sender, isA<LoggingEmailSender>());
      expect(sender.delivers, isFalse);
    });

    test('when the Resend key and sender are set then Resend is used', () {
      final sender = EmailSenders.fromConfig(
        (k) => {'resendApiKey': 're_x', 'emailFrom': 'W <n@example.com>'}[k],
      );

      expect(sender, isA<ResendEmailSender>());
    });
  });

  group('Given the Resend sender', () {
    const email = OutgoingEmail(
      to: 'bo@example.test',
      subject: 'Hi',
      text: 'Text',
      html: '<p>Text</p>',
      category: 'mention',
    );

    test('when sending then it posts the email with the bearer key', () async {
      late http.Request request;
      final sender = ResendEmailSender(
        apiKey: 're_key',
        from: 'Wonky <n@example.com>',
        httpClient: MockClient((r) async {
          request = r;
          return http.Response('{"id":"1"}', 200);
        }),
      );

      await sender.send(_NoSession(), email);

      expect(request.headers['Authorization'], 'Bearer re_key');
      expect(jsonDecode(request.body), {
        'from': 'Wonky <n@example.com>',
        'to': ['bo@example.test'],
        'subject': 'Hi',
        'text': 'Text',
        'html': '<p>Text</p>',
        'tags': [
          {'name': 'category', 'value': 'mention'},
        ],
      });
    });

    test('when the provider rejects the email then it throws', () async {
      final sender = ResendEmailSender(
        apiKey: 're_key',
        from: 'n@example.com',
        httpClient: MockClient((_) async => http.Response('bad', 422)),
      );

      await expectLater(
        sender.send(_NoSession(), email),
        throwsA(
          isA<EmailDeliveryException>().having(
            (e) => e.statusCode,
            'status',
            422,
          ),
        ),
      );
    });
  });
}

/// The Resend sender never touches the session.
class _NoSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Not used');
}
