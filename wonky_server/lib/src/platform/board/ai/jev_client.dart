import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;

import 'board_ai.dart';

/// One typed question of a Jev request (TypeSafe System One, specs/16 §6.2).
class JevQuestion {
  const JevQuestion._(this.type, this.instructions, this.criteria);

  /// A yes/no question; [yes] and [no] describe what each answer means.
  factory JevQuestion.noul(Object instructions, {Object? yes, Object? no}) =>
      JevQuestion._(
        'noul',
        instructions,
        yes == null && no == null ? null : {'true': yes, 'false': no},
      );

  /// One option of [options] (option → description, in order).
  factory JevQuestion.choice(
    Object instructions,
    Map<String, Object?> options,
  ) => JevQuestion._('choice', instructions, options);

  /// A rating over ordered [levels].
  factory JevQuestion.score(Object instructions, List<Object?> levels) =>
      JevQuestion._('score', instructions, levels);

  /// `noul`, `choice` or `score`.
  final String type;

  /// A string, or an object holding the question and the data it refers to.
  final Object instructions;
  final Object? criteria;

  Map<String, Object?> toJson() => {
    'type': type,
    'instructions': instructions,
    if (criteria != null) 'criteria': criteria,
  };
}

/// The typed answer to one [JevQuestion].
class JevAnswer {
  const JevAnswer({
    required this.type,
    this.noul,
    this.choice,
    this.probabilities = const {},
    this.confidence,
    this.score,
  });

  factory JevAnswer.fromJson(Map<String, Object?> j) {
    double? d(Object? v) => v is num ? v.toDouble() : null;
    final probs = j['probabilities'];
    return JevAnswer(
      type: '${j['type'] ?? ''}',
      noul: d(j['noul']),
      choice: j['choice'] is String ? j['choice'] as String : null,
      probabilities: probs is Map
          ? {
              for (final e in probs.entries)
                if (e.value is num) '${e.key}': (e.value as num).toDouble(),
            }
          : const {},
      confidence: d(j['confidence']),
      score: d(j['score']),
    );
  }

  final String type;

  /// Noul: probability of yes (0–1).
  final double? noul;

  /// Choice: the most probable option.
  final String? choice;

  /// Choice/Score: option (or level) → probability.
  final Map<String, double> probabilities;

  /// Choice/Score: how certain the model is (0–1).
  final double? confidence;

  /// Score: probability-weighted level.
  final double? score;

  Map<String, Object?> toJson() => {
    'type': type,
    'noul': ?noul,
    'choice': ?choice,
    if (probabilities.isNotEmpty) 'probabilities': probabilities,
    'confidence': ?confidence,
    'score': ?score,
  };
}

/// A complete Jev response.
class JevResult {
  const JevResult({
    required this.model,
    required this.answers,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  /// The versioned model id that answered (e.g. `jev-1.13.0`).
  final String model;
  final Map<String, JevAnswer> answers;
  final int inputTokens;
  final int outputTokens;

  /// The Noul probability of [id] (0 when missing).
  double noul(String id) => answers[id]?.noul ?? 0;
}

/// A Jev request: [state] (JSON) plus named [questions].
class JevRequest {
  const JevRequest({required this.state, required this.questions});

  final Object state;
  final Map<String, JevQuestion> questions;

  Map<String, Object?> toJson(String model) => {
    'model': model,
    'state': state,
    'questions': {
      for (final e in questions.entries) e.key: e.value.toJson(),
    },
  };
}

/// The decision model behind the board (TypeSafe Jev, specs/16 §6.1):
/// [HttpJevClient] in production, `FakeJevClient` in tests.
abstract class JevClient {
  /// Evaluates [request] and returns the typed answers. Throws
  /// [BoardAiException] on provider errors and when [timeout] (the whole
  /// call, retries included) runs out.
  Future<JevResult> ask(JevRequest request, {Duration? timeout});
}

/// [JevClient] over HTTP (`POST /v1/systemone`; TypeSafe has no Dart SDK).
///
/// - Sends `Authorization: Bearer <key>` and the pinned [model].
/// - Retries `429`, `529` (and other `5xx`) and connection errors with
///   exponential backoff, honoring `retry-after`, within the deadline.
/// - Maps `400`, `401`, `413`, `415` and `422` to a non-retryable
///   [BoardAiException]. Neither the key nor the request content ever
///   appears in an exception message.
class HttpJevClient implements JevClient {
  HttpJevClient({
    required this._apiKey,
    required this.model,
    http.Client? httpClient,
    Uri? endpoint,
    this.maxAttempts = 4,
    this.baseDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 8),
    this.defaultTimeout = const Duration(seconds: 30),
    Future<void> Function(Duration)? sleep,
  }) : _http = httpClient ?? http.Client(),
       endpoint = endpoint ?? Uri.parse('https://api.typesafe.ai/v1/systemone'),
       _sleep = sleep ?? Future<void>.delayed;

  final String _apiKey;
  final http.Client _http;

  /// The pinned model id (`board.ai.jevModel`), never an alias.
  final String model;
  final Uri endpoint;

  /// Attempts per call, the first one included.
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Used when [ask] gets no timeout.
  final Duration defaultTimeout;
  final Future<void> Function(Duration) _sleep;

  void close() => _http.close();

  @override
  Future<JevResult> ask(JevRequest request, {Duration? timeout}) async {
    final deadline = clock.now().add(timeout ?? defaultTimeout);
    final body = utf8.encode(jsonEncode(request.toJson(model)));
    BoardAiException? last;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final remaining = deadline.difference(clock.now());
      if (remaining <= Duration.zero) break;
      http.Response res;
      try {
        res = await _http
            .post(
              endpoint,
              headers: {
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: body,
            )
            .timeout(remaining);
      } on TimeoutException {
        throw BoardAiException('Jev did not answer in time.');
      } on Object catch (e) {
        // Connection errors (never echo the request).
        last = BoardAiException('Jev connection failed (${e.runtimeType}).');
        if (attempt + 1 < maxAttempts) {
          await _wait(_backoff(attempt), deadline);
        }
        continue;
      }
      final status = res.statusCode;
      if (status >= 200 && status < 300) return _parse(res);
      final error = _errorLabel(res);
      final retryable = status == 429 || status >= 500;
      if (!retryable) {
        throw BoardAiException(
          'Jev rejected the request ($status$error).',
          retryable: false,
        );
      }
      last = BoardAiException('Jev is busy ($status$error).');
      if (attempt + 1 < maxAttempts) {
        await _wait(_retryAfter(res) ?? _backoff(attempt), deadline);
      }
    }
    throw last ?? BoardAiException('Jev did not answer in time.');
  }

  /// Sleeps [wait] unless that passes [deadline] (then throws).
  Future<void> _wait(Duration wait, DateTime deadline) async {
    if (clock.now().add(wait).isAfter(deadline)) {
      throw BoardAiException('Jev is busy; no time left to retry.');
    }
    await _sleep(wait);
  }

  Duration _backoff(int attempt) {
    final ms = baseDelay.inMilliseconds * math.pow(2, attempt);
    return Duration(
      milliseconds: math.min(ms.toInt(), maxDelay.inMilliseconds),
    );
  }

  /// `retry-after` as seconds or an HTTP date, capped at [maxDelay] × 4.
  Duration? _retryAfter(http.Response res) {
    final v = res.headers['retry-after']?.trim();
    if (v == null || v.isEmpty) return null;
    Duration? d;
    final secs = double.tryParse(v);
    if (secs != null) {
      d = Duration(milliseconds: (secs * 1000).round());
    } else {
      try {
        d = parseHttpDate(v).difference(clock.now());
      } on FormatException {
        return null;
      }
    }
    if (d.isNegative) return Duration.zero;
    final cap = maxDelay * 4;
    return d > cap ? cap : d;
  }

  /// A short, content-free label of an error body (`: <type>`), e.g.
  /// `max_tokens_exceeded`. Free-text messages are left out: they may
  /// quote the request.
  static String _errorLabel(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      Object? pick(Object? m) {
        if (m is! Map) return null;
        for (final k in const ['type', 'code']) {
          final v = m[k];
          if (v is String && RegExp(r'^[a-zA-Z0-9_.\-]{1,64}$').hasMatch(v)) {
            return v;
          }
        }
        return pick(m['error']);
      }

      final label = pick(j);
      return label == null ? '' : ': $label';
    } on Object {
      return '';
    }
  }

  JevResult _parse(http.Response res) {
    final Object? j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw BoardAiException('Jev returned an unreadable answer.');
    }
    if (j is! Map) throw BoardAiException('Jev returned an unreadable answer.');
    final answers = j['answers'];
    final usage = j['usage'];
    int tokens(String k) =>
        usage is Map && usage[k] is num ? (usage[k] as num).toInt() : 0;
    return JevResult(
      model: j['model'] is String ? j['model'] as String : model,
      answers: answers is Map
          ? {
              for (final e in answers.entries)
                if (e.value is Map)
                  '${e.key}': JevAnswer.fromJson(
                    (e.value as Map).cast<String, Object?>(),
                  ),
            }
          : const {},
      inputTokens: tokens('input_tokens'),
      outputTokens: tokens('output_tokens'),
    );
  }
}

/// Parses an HTTP date (RFC 7231 IMF-fixdate, e.g.
/// `Wed, 21 Oct 2026 07:28:00 GMT`).
DateTime parseHttpDate(String v) {
  final m = RegExp(
    r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(v);
  if (m == null) throw FormatException('Not an HTTP date', v);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = months.indexOf(m[2]!) + 1;
  if (month == 0) throw FormatException('Not an HTTP date', v);
  return DateTime.utc(
    int.parse(m[3]!),
    month,
    int.parse(m[1]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
    int.parse(m[6]!),
  );
}
