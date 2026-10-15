import 'package:serverpod/serverpod.dart';

import '../../common/models.dart';

/// The board AI (specs/16 §6): Jev for decisions, Gemini for writing, on
/// internal keys separate from the in-app AI. [BoardAi.instance] is the
/// production implementation; tests replace it with [BoardAi.override].
abstract class BoardAi {
  static BoardAi? override;

  /// Set by the board AI implementation at startup.
  static BoardAi Function()? factory;

  static BoardAi get instance =>
      override ?? (factory != null ? factory!() : const NoBoardAi());

  /// Jev is configured and within today's budget.
  Future<bool> jevAvailable(Session session);

  /// Gemini is configured and within today's budget.
  Future<bool> geminiAvailable(Session session);

  /// Whether the Jev key is set at all (shown in the dialog notice).
  bool get jevConfigured;
  bool get geminiConfigured;

  /// Decides a post (moderation, kind, area, size, duplicates) with Jev.
  /// [candidates] are possible duplicates from full-text search (≤ 5).
  /// Throws [BoardAiException] on provider errors and timeouts.
  Future<BoardTriage> triagePost(
    Session session,
    BoardPost post, {
    List<BoardPost> candidates = const [],
    Duration timeout,
  });

  /// Moderation-only check of a comment body.
  Future<BoardModerationScores> checkComment(
    Session session,
    String body, {
    Duration timeout,
  });

  /// Reorders [candidates] by how likely each describes the same thing as
  /// the draft; returns (post id, probability) pairs, best first.
  Future<List<(int, double)>> rerankSimilar(
    Session session, {
    required String title,
    required String body,
    required List<BoardPost> candidates,
  });

  /// Gemini (fast): a clearer title (null when the current one is fine) and
  /// a ≤ 200 char summary.
  Future<({String? title, String summary})> summarize(
    Session session,
    BoardPost post,
  );

  /// Gemini: groups of related small posts.
  Future<List<BoardBundleProposal>> suggestBundles(
    Session session,
    List<BoardPost> posts,
  );

  /// Gemini: the AI-written body of a task prompt (specs/16 §10.1).
  Future<String> writeTaskPrompt(
    Session session, {
    required BoardTask task,
    required List<BoardPost> posts,
    required Map<int, List<BoardComment>> comments,
    required Uri webOrigin,
  });
}

/// Moderation probabilities (0–1) from Jev Nouls.
class BoardModerationScores {
  const BoardModerationScores({
    this.offensive = 0,
    this.spam = 0,
    this.notActionable = 0,
    this.offTopic = 0,
    this.personalData = 0,
    this.security = 0,
  });

  final double offensive;
  final double spam;
  final double notActionable;
  final double offTopic;
  final double personalData;
  final double security;

  Map<String, double> toJson() => {
    'offensive': offensive,
    'spam': spam,
    'not_actionable': notActionable,
    'off_topic': offTopic,
    'personal_data': personalData,
    'security': security,
  };
}

/// What Jev decided about a post. Labels are null when Jev was not
/// confident enough (`thresholds.labelConfidence`).
class BoardTriage {
  const BoardTriage({
    required this.scores,
    required this.kind,
    required this.kindConfidence,
    this.area,
    this.size,
    this.duplicates = const {},
    this.model = '',
  });

  final BoardModerationScores scores;

  /// The winning kind and its confidence.
  final BoardPostKind kind;
  final double kindConfidence;
  final BoardArea? area;
  final BoardSize? size;

  /// Candidate post id → probability that it is the same.
  final Map<int, double> duplicates;

  /// The model id that answered.
  final String model;

  Map<String, Object?> toJson() => {
    'model': model,
    'scores': scores.toJson(),
    'kind': kind.name,
    'kindConfidence': kindConfidence,
    'area': area?.name,
    'size': size?.name,
    'duplicates': {for (final e in duplicates.entries) '${e.key}': e.value},
  };
}

class BoardBundleProposal {
  const BoardBundleProposal({
    required this.title,
    required this.rationale,
    required this.postIds,
    this.area,
  });

  final String title;
  final String rationale;
  final List<int> postIds;
  final BoardArea? area;
}

class BoardAiException implements Exception {
  BoardAiException(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => 'BoardAiException: $message';
}

/// No board AI configured: every call reports unavailable.
class NoBoardAi implements BoardAi {
  const NoBoardAi();

  @override
  bool get jevConfigured => false;

  @override
  bool get geminiConfigured => false;

  @override
  Future<bool> jevAvailable(Session session) async => false;

  @override
  Future<bool> geminiAvailable(Session session) async => false;

  Never _unavailable() => throw BoardAiException(
    'The board AI is not configured.',
    retryable: false,
  );

  @override
  Future<BoardTriage> triagePost(
    Session session,
    BoardPost post, {
    List<BoardPost> candidates = const [],
    Duration timeout = const Duration(seconds: 60),
  }) async => _unavailable();

  @override
  Future<BoardModerationScores> checkComment(
    Session session,
    String body, {
    Duration timeout = const Duration(seconds: 60),
  }) async => _unavailable();

  @override
  Future<List<(int, double)>> rerankSimilar(
    Session session, {
    required String title,
    required String body,
    required List<BoardPost> candidates,
  }) async => _unavailable();

  @override
  Future<({String? title, String summary})> summarize(
    Session session,
    BoardPost post,
  ) async => _unavailable();

  @override
  Future<List<BoardBundleProposal>> suggestBundles(
    Session session,
    List<BoardPost> posts,
  ) async => _unavailable();

  @override
  Future<String> writeTaskPrompt(
    Session session, {
    required BoardTask task,
    required List<BoardPost> posts,
    required Map<int, List<BoardComment>> comments,
    required Uri webOrigin,
  }) async => _unavailable();
}
