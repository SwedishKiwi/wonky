import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

/// An email to send (notification digests, mention emails).
class OutgoingEmail {
  const OutgoingEmail({
    required this.to,
    required this.subject,
    required this.text,
    required this.html,
    this.category = 'notification',
  });

  final String to;
  final String subject;

  /// Plain-text body.
  final String text;

  /// HTML body (inline styles only).
  final String html;

  /// A tag for the provider and the logs (`digest`, `mention`, …).
  final String category;
}

/// Delivers [OutgoingEmail]s (specs/07 §4). Pluggable: the server picks one
/// from the configuration ([EmailSenders.fromConfig]); tests install a fake
/// with `NotificationService.emailSender = …`.
abstract interface class EmailSender {
  /// Whether emails really leave the server (false for the logging sender).
  bool get delivers;

  /// Sends [email]; throws [EmailDeliveryException] when the provider
  /// rejects it.
  Future<void> send(Session session, OutgoingEmail email);
}

class EmailDeliveryException implements Exception {
  const EmailDeliveryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'EmailDeliveryException(${statusCode ?? '-'}): $message';
}

/// Development fallback: logs the email instead of sending it. Used when no
/// provider is configured.
class LoggingEmailSender implements EmailSender {
  const LoggingEmailSender();

  @override
  bool get delivers => false;

  @override
  Future<void> send(Session session, OutgoingEmail email) async {
    session.log(
      'Email (${email.category}) to ${email.to} not sent, no mail provider '
      'is configured: "${email.subject}"\n${email.text}',
    );
  }
}

/// Sends through the Resend HTTP API (https://resend.com/docs/api-reference),
/// configured with the passwords `resendApiKey` and `emailFrom`.
class ResendEmailSender implements EmailSender {
  ResendEmailSender({
    required this.apiKey,
    required this.from,
    http.Client? httpClient,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client(),
       endpoint = endpoint ?? Uri.parse('https://api.resend.com/emails');

  final String apiKey;

  /// Sender address, e.g. `Wonky Work <notifications@example.com>`.
  final String from;
  final Uri endpoint;
  final Duration timeout;
  final http.Client _http;

  @override
  bool get delivers => true;

  @override
  Future<void> send(Session session, OutgoingEmail email) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'from': from,
              'to': [email.to],
              'subject': email.subject,
              'text': email.text,
              'html': email.html,
              'tags': [
                {'name': 'category', 'value': email.category},
              ],
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const EmailDeliveryException('The mail provider timed out.');
    } on http.ClientException catch (e) {
      throw EmailDeliveryException(e.message);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw EmailDeliveryException(
      response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body,
      statusCode: response.statusCode,
    );
  }
}

abstract final class EmailSenders {
  /// The configured sender: Resend when the passwords `resendApiKey` and
  /// `emailFrom` are set, otherwise [LoggingEmailSender].
  static EmailSender fromConfig(String? Function(String key) password) {
    final key = password('resendApiKey');
    final from = password('emailFrom');
    if (key != null && key.isNotEmpty && from != null && from.isNotEmpty) {
      return ResendEmailSender(apiKey: key, from: from);
    }
    return const LoggingEmailSender();
  }

  /// [fromConfig] with the running server's passwords.
  static EmailSender fromServer() {
    try {
      final pod = Serverpod.instance;
      return fromConfig(pod.getPassword);
    } on Object {
      return const LoggingEmailSender();
    }
  }
}
