import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import 'ai/board_ai.dart';
import 'board_common.dart';
import 'board_config.dart';
import 'board_notify.dart';
import 'board_search.dart';
import 'board_triage.dart';

/// The AI pipeline of a post (specs/16 §6.3): inline triage at submit
/// (3 s), the background path with retries, the unchecked path without
/// Jev, and the writing pass (summary, suggested title).
abstract final class BoardPipeline {
  static const inlineTimeout = Duration(seconds: 3);
  static const backgroundTimeout = Duration(seconds: 60);

  /// Delays of the background retries after a failed attempt.
  static const retryDelays = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 30),
  ];

  /// Up to this many unchecked posts are re-triaged per sweep.
  static const retriageBatch = 20;

  /// Runs Jev on [post] and stores the result (moderation, labels unless
  /// an admin confirmed them, duplicate hint, triage JSON). Throws when
  /// the AI fails or times out.
  static Future<BoardPost> triage(
    Session session,
    BoardPost post, {
    Duration timeout = inlineTimeout,
  }) async {
    final candidates = await BoardSearch.similarPosts(
      session,
      '${post.title} ${BoardText.plain(post.body, max: 2000)}',
      limit: 5,
      excludeId: post.id,
    );
    final result = await BoardAi.instance
        .triagePost(session, post, candidates: candidates, timeout: timeout)
        .timeout(timeout + const Duration(milliseconds: 500));
    final o = applyTriage(
      result,
      BoardConfig.current.ai.thresholds,
      reportedKind: post.reportedKind,
    );
    final confirmed = !post.aiLabels;
    final candidateIds = {for (final p in candidates) p.id};
    return BoardPost.db.updateRow(
      session,
      post.copyWith(
        moderation: o.moderation,
        moderationReason: o.reason,
        needsCheck: o.needsCheck,
        kind: confirmed ? post.kind : o.kind,
        area: confirmed ? post.area : o.area,
        size: confirmed ? post.size : o.size,
        possibleDuplicateOfId: candidateIds.contains(o.possibleDuplicateOfId)
            ? o.possibleDuplicateOfId
            : null,
        triageState: BoardTriageState.done,
        triageJson: jsonEncode(result.toJson()),
      ),
    );
  }

  /// After a new post is stored as `checking` (Jev available) or
  /// `visible` (no Jev): the inline triage, or the background path when it
  /// fails. Returns the post as stored now.
  static Future<BoardPost> afterCreate(Session session, BoardPost post) async {
    var current = post;
    if (post.moderation == BoardModeration.checking) {
      try {
        current = await triage(session, post);
      } on Object catch (e) {
        session.log(
          'board: inline triage of #${post.id} failed, continuing in the '
          'background: $e',
          level: LogLevel.info,
        );
        await BoardJobs.schedule(session, BoardJob.triage, post.id!);
        return post;
      }
    }
    if (current.moderation == BoardModeration.visible) {
      await afterVisible(session, current);
    }
    return current;
  }

  /// Re-runs the inline triage after an author's edit (specs/16 §6.3
  /// step 5): a visible post stays visible unless a score reaches hold.
  static Future<BoardPost> afterEdit(Session session, BoardPost post) async {
    if (post.moderation == BoardModeration.checking) return post;
    if (!await BoardAi.instance.jevAvailable(session)) {
      return BoardPost.db.updateRow(
        session,
        post.copyWith(triageState: BoardTriageState.unchecked),
      );
    }
    try {
      return await triage(session, post);
    } on Object catch (e) {
      session.log(
        'board: triage of the edit of #${post.id} failed: $e',
        level: LogLevel.info,
      );
      return BoardPost.db.updateRow(
        session,
        post.copyWith(triageState: BoardTriageState.unchecked),
      );
    }
  }

  /// The writing pass for a post that became visible: a Gemini summary in
  /// the background when available.
  static Future<void> afterVisible(Session session, BoardPost post) async {
    if (await BoardAi.instance.geminiAvailable(session)) {
      await BoardJobs.schedule(session, BoardJob.summarize, post.id!);
    }
  }

  /// `BoardFutureCall.triage`: the background path with retries at 1, 5
  /// and 30 minutes; afterwards the post is published unchecked (or held
  /// when `publishWhenTriageFails` is false).
  static Future<void> backgroundTriage(Session session, int postId) async {
    final post = await BoardPost.db.findById(session, postId);
    if (post == null ||
        post.deletedAt != null ||
        post.moderation != BoardModeration.checking) {
      return;
    }
    if (!await BoardAi.instance.jevAvailable(session)) {
      final published = await BoardPost.db.updateRow(
        session,
        post.copyWith(
          moderation: BoardModeration.visible,
          triageState: BoardTriageState.unchecked,
        ),
      );
      await BoardLive.post(session, postId);
      await afterVisible(session, published);
      return;
    }
    try {
      final updated = await triage(
        session,
        post,
        timeout: backgroundTimeout,
      );
      await BoardLive.post(session, postId);
      if (updated.moderation == BoardModeration.held) {
        await _notifyHeld(session, updated);
      } else {
        await afterVisible(session, updated);
      }
    } on Object catch (e) {
      final attempts = post.triageAttempts + 1;
      if (attempts <= retryDelays.length) {
        session.log(
          'board: triage of #$postId failed (attempt $attempts): $e',
          level: LogLevel.warning,
        );
        await BoardPost.db.updateRow(
          session,
          post.copyWith(triageAttempts: attempts),
          columns: (t) => [t.triageAttempts],
        );
        await BoardJobs.schedule(
          session,
          BoardJob.triage,
          postId,
          delay: retryDelays[attempts - 1],
        );
        return;
      }
      session.log(
        'board: triage of #$postId failed for good: $e',
        level: LogLevel.warning,
      );
      final publish = BoardConfig.current.publishWhenTriageFails;
      final updated = await BoardPost.db.updateRow(
        session,
        post.copyWith(
          triageAttempts: attempts,
          moderation: publish ? BoardModeration.visible : BoardModeration.held,
          moderationReason: publish ? null : boardHoldReason(const []),
          triageState: publish
              ? BoardTriageState.unchecked
              : BoardTriageState.failed,
        ),
      );
      await BoardLive.post(session, postId);
      if (publish) {
        await afterVisible(session, updated);
      } else {
        await _notifyHeld(session, updated);
      }
    }
  }

  static Future<void> _notifyHeld(Session session, BoardPost post) =>
      BoardNotify.postStatus(
        session,
        post,
        'Waiting for review: a moderator will look at '
        '${BoardText.quoted(post.title)}.',
        voters: false,
      );

  /// `BoardFutureCall.summarize`: a clearer title (only kept when it
  /// differs) and a short summary, from Gemini.
  static Future<void> summarize(Session session, int postId) async {
    final post = await BoardPost.db.findById(session, postId);
    if (post == null ||
        post.deletedAt != null ||
        post.moderation != BoardModeration.visible) {
      return;
    }
    if (!await BoardAi.instance.geminiAvailable(session)) return;
    try {
      final r = await BoardAi.instance.summarize(session, post);
      final title = r.title?.trim().replaceAll(RegExp(r'\s+'), ' ');
      String norm(String s) => s.toLowerCase().replaceAll(
        RegExp(r'[^\p{L}\p{N}]+', unicode: true),
        '',
      );
      final differs =
          title != null &&
          title.length >= BoardText.minTitleLength &&
          title.length <= BoardText.maxTitleLength &&
          norm(title) != norm(post.title);
      final summary = BoardText.plain(r.summary, max: 200);
      await BoardPost.db.updateRow(
        session,
        post.copyWith(
          suggestedTitle: differs ? title : null,
          summary: summary.isEmpty ? post.summary : summary,
        ),
        columns: (t) => [t.suggestedTitle, t.summary],
      );
    } on Object catch (e) {
      session.log(
        'board: summary of #$postId failed: $e',
        level: LogLevel.warning,
      );
    }
  }

  /// Sweep: re-triages unchecked visible posts when Jev is available
  /// again. Returns the number checked.
  static Future<int> retriageUnchecked(Session session) async {
    if (!await BoardAi.instance.jevAvailable(session)) return 0;
    final posts = await BoardPost.db.find(
      session,
      where: (t) =>
          t.triageState.equals(BoardTriageState.unchecked) &
          t.moderation.equals(BoardModeration.visible) &
          t.deletedAt.equals(null),
      orderBy: (t) => t.id,
      limit: retriageBatch,
    );
    var count = 0;
    for (final post in posts) {
      try {
        final updated = await triage(
          session,
          post,
          timeout: backgroundTimeout,
        );
        count++;
        if (updated.moderation == BoardModeration.held) {
          await BoardLive.post(session, post.id!);
          await _notifyHeld(session, updated);
        }
      } on Object catch (e) {
        session.log(
          'board: re-triage of #${post.id} failed: $e',
          level: LogLevel.warning,
        );
        break;
      }
    }
    return count;
  }
}
