import '../common/models.dart';
import 'ai/board_ai.dart';
import 'board_config.dart';

/// What a triage result means for a post (specs/16 §6.2, §6.3).
class BoardTriageOutcome {
  const BoardTriageOutcome({
    required this.moderation,
    required this.needsCheck,
    required this.kind,
    this.area,
    this.size,
    this.possibleDuplicateOfId,
    this.reason,
    this.holdReasons = const [],
    this.reviewReasons = const [],
  });

  /// `visible` or `held`.
  final BoardModeration moderation;

  /// A score in the review band: listed in the admin Check section.
  final bool needsCheck;

  /// The kind after correction (the author's pick otherwise).
  final BoardPostKind kind;
  final BoardArea? area;
  final BoardSize? size;
  final int? possibleDuplicateOfId;

  /// Shown to the author of a held post.
  final String? reason;

  /// The decisions (question ids) in the hold and review bands.
  final List<String> holdReasons;
  final List<String> reviewReasons;

  bool get held => moderation == BoardModeration.held;
}

/// Moderation bands of a set of scores (specs/16 §6.2 table).
class BoardModerationBands {
  const BoardModerationBands(this.hold, this.review);

  /// Question ids at or above their hold threshold.
  final List<String> hold;

  /// Question ids in the review band (below hold).
  final List<String> review;
}

/// The author-facing text of a held post or comment.
String boardHoldReason(List<String> decisions) {
  const texts = {
    'security': 'it may describe a security issue',
    'offensive': 'it may be offensive',
    'personal_data': 'it may contain personal data',
    'spam': 'it may be spam',
    'not_actionable': 'it may not describe anything to fix or build',
    'off_topic': 'it may not be about Wonky Work',
  };
  final first = decisions.isEmpty ? null : texts[decisions.first];
  return first == null ? 'Waiting for review.' : 'Waiting for review: $first.';
}

/// Applies the hold / review thresholds to [scores]. [junk] includes the
/// post-only decisions `spam`, `not_actionable` and `off_topic`; comments
/// are checked for `offensive`, `spam`, `personal_data` and `security`
/// only (specs/16 §6.3 step 6).
BoardModerationBands moderationBands(
  BoardModerationScores scores,
  BoardAiThresholds t, {
  bool post = true,
}) {
  final hold = <String>[];
  final review = <String>[];
  void band(String id, double p, double holdAt, double reviewAt) {
    if (p >= holdAt) {
      hold.add(id);
    } else if (p >= reviewAt) {
      review.add(id);
    }
  }

  band('security', scores.security, t.securityHold, t.securityReview);
  band('offensive', scores.offensive, t.harmHold, t.harmReview);
  band('personal_data', scores.personalData, t.harmHold, t.harmReview);
  band('spam', scores.spam, t.junkHold, t.junkReview);
  if (post) {
    band('not_actionable', scores.notActionable, t.junkHold, t.junkReview);
    band('off_topic', scores.offTopic, t.junkHold, t.junkReview);
  }
  return BoardModerationBands(hold, review);
}

/// The effect of a Jev [triage] on a post whose author picked
/// [reportedKind] (specs/16 §6.2, §6.3), as a pure function:
///
/// - any moderation score in its *hold* band holds the post; a score in a
///   *review* band keeps it visible and lists it under *Check*;
/// - the kind is corrected when the other kind wins with at least
///   `kindCorrection` (the author's pick stays in `reportedKind`);
/// - area and size are taken as returned (null when Jev was unsure);
/// - the most likely duplicate at or above `duplicate` becomes the admin
///   hint.
BoardTriageOutcome applyTriage(
  BoardTriage triage,
  BoardAiThresholds thresholds, {
  required BoardPostKind reportedKind,
}) {
  final bands = moderationBands(triage.scores, thresholds);
  final held = bands.hold.isNotEmpty;
  final kind =
      triage.kind != reportedKind &&
          triage.kindConfidence >= thresholds.kindCorrection
      ? triage.kind
      : reportedKind;
  int? duplicate;
  var best = 0.0;
  for (final e in triage.duplicates.entries) {
    if (e.value >= thresholds.duplicate && e.value > best) {
      best = e.value;
      duplicate = e.key;
    }
  }
  return BoardTriageOutcome(
    moderation: held ? BoardModeration.held : BoardModeration.visible,
    needsCheck: !held && bands.review.isNotEmpty,
    kind: kind,
    area: triage.area,
    size: triage.size,
    possibleDuplicateOfId: duplicate,
    reason: held ? boardHoldReason(bands.hold) : null,
    holdReasons: bands.hold,
    reviewReasons: bands.review,
  );
}

/// The effect of a comment check (specs/16 §6.3 step 6).
({BoardModeration moderation, bool needsCheck, String? reason})
applyCommentCheck(BoardModerationScores scores, BoardAiThresholds t) {
  final bands = moderationBands(scores, t, post: false);
  final held = bands.hold.isNotEmpty;
  return (
    moderation: held ? BoardModeration.held : BoardModeration.visible,
    needsCheck: !held && bands.review.isNotEmpty,
    reason: held ? boardHoldReason(bands.hold) : null,
  );
}
