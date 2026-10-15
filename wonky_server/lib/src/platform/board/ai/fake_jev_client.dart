import 'dart:collection';

import 'jev_client.dart';

/// A [JevClient] for tests (specs/16 §15): answers from scripted values per
/// question id and records every request. Never calls TypeSafe.
///
/// Unscripted Nouls answer [defaultNoul]; unscripted Choices pick their
/// first option with [defaultConfidence].
class FakeJevClient implements JevClient {
  FakeJevClient({
    Map<String, JevAnswer> answers = const {},
    this.defaultNoul = 0.01,
    this.defaultConfidence = 0.9,
    this.model = 'jev-1.13.0',
    this.inputTokens = 300,
    this.outputTokens = 20,
  }) : answers = {...answers};

  /// Scripted answers by question id (also matched by prefix, e.g.
  /// `duplicate_` for every duplicate question, when no exact id is set).
  final Map<String, JevAnswer> answers;
  final double defaultNoul;
  final double defaultConfidence;
  final String model;
  final int inputTokens;
  final int outputTokens;

  /// The requests made, in order.
  final List<JevRequest> requests = [];

  /// The timeouts passed, in order.
  final List<Duration?> timeouts = [];

  /// Errors thrown by the next calls, in order (e.g. a
  /// `BoardAiException`).
  final Queue<Object> errors = Queue();

  /// Scripts a Noul answer.
  void noul(String id, double p) =>
      answers[id] = JevAnswer(type: 'noul', noul: p);

  /// Scripts a Choice answer.
  void choice(String id, String option, {double confidence = 0.9}) =>
      answers[id] = JevAnswer(
        type: 'choice',
        choice: option,
        confidence: confidence,
        probabilities: {option: (1 + confidence) / 2},
      );

  @override
  Future<JevResult> ask(JevRequest request, {Duration? timeout}) async {
    requests.add(request);
    timeouts.add(timeout);
    if (errors.isNotEmpty) throw errors.removeFirst();
    return JevResult(
      model: model,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      answers: {
        for (final e in request.questions.entries)
          e.key: _answer(e.key, e.value),
      },
    );
  }

  JevAnswer _answer(String id, JevQuestion q) {
    final scripted =
        answers[id] ??
        answers.entries
            .where((e) => e.key.endsWith('_') && id.startsWith(e.key))
            .map((e) => e.value)
            .firstOrNull;
    if (scripted != null) return scripted;
    if (q.type == 'choice') {
      final first = (q.criteria! as Map).keys.first as String;
      return JevAnswer(
        type: 'choice',
        choice: first,
        confidence: defaultConfidence,
        probabilities: {first: (1 + defaultConfidence) / 2},
      );
    }
    if (q.type == 'score') {
      return const JevAnswer(type: 'score', score: 0, confidence: 1);
    }
    return JevAnswer(type: 'noul', noul: defaultNoul);
  }
}
