import 'package:serverpod/serverpod.dart';

import '../../platform/board/github/github_webhook.dart';

/// `POST /api/github/webhook` (specs/16 §13.3): the webhooks of the
/// board's GitHub App. Checks the signature, stores the delivery once and
/// answers `202`; the work runs in a future call.
class GithubWebhookRoute extends Route {
  GithubWebhookRoute() : super(methods: {Method.post});

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final List<int> body;
    try {
      body = await request
          .read(maxLength: GithubWebhook.maxBodyBytes)
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    } on MaxBodySizeExceeded {
      return _status(413);
    }
    final status = await GithubWebhook.receive(
      session,
      headers: {
        for (final e in request.headers.entries) e.key: e.value.join(', '),
      },
      body: body,
    );
    return _status(status);
  }

  static Response _status(int status) => Response(
    status,
    body: Body.fromString(switch (status) {
      202 => 'Accepted',
      400 => 'Bad request',
      401 => 'Unauthorized',
      413 => 'Payload too large',
      _ => 'Error',
    }, mimeType: MimeType.plainText),
  );
}
