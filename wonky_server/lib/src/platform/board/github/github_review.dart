import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../../common/models.dart';
import '../../common/time.dart';
import '../ai/board_ai.dart';
import '../ai/board_ai_ledger.dart';
import '../ai/jev_gemini_board_ai.dart';
import '../board_common.dart';
import '../board_config.dart';
import 'board_github.dart';
import 'github_client.dart';
import 'github_gate.dart';
import 'github_review_ai.dart';
import 'github_review_facts.dart';

/// The advisory check "Wonky task review" (specs/16 §13.5): after the gate
/// passes and on every new head commit, debounced; one Gemini call against
/// the task's acceptance criteria; a comment updated in place, a neutral
/// check and the stored result on the PR row (shown on the task page).
/// The server only reads the diff through the API; it never checks out,
/// builds or runs PR code.
abstract final class GithubReview {
  static const checkName = 'Wonky task review';
  static const marker = '<!-- wonky-task-review -->';
  static const debounce = Duration(minutes: 2);

  /// A scheduled run this late is picked up by the sweep (its future call
  /// was lost, or it was postponed to the next day).
  static const sweepGrace = Duration(minutes: 5);
  static const retryDelay = Duration(minutes: 30);

  /// Unrelated changes above this many changed lines count as major
  /// (blocking mode only).
  static const majorUnrelatedLines = 200;

  // ------------------------------------------------------------ schedule

  /// Schedules a review of [sha] in [debounce] (the latest SHA wins; the
  /// superseded run is cancelled and, if it still fires, dropped). A SHA
  /// already reviewed is skipped unless [force] (a re-run request).
  static Future<void> schedule(
    Session session,
    BoardPullRequest row,
    String sha, {
    bool force = false,
    Duration delay = debounce,
  }) async {
    if (sha.isEmpty) return;
    if (!force && (row.lastReviewSha == sha || row.reviewPendingSha == sha)) {
      return;
    }
    final at = nowUtc().add(delay);
    await BoardPullRequest.db.updateRow(
      session,
      row.copyWith(reviewPendingSha: sha, reviewDueAt: at),
      columns: (t) => [t.reviewPendingSha, t.reviewDueAt],
    );
    try {
      await BoardGithub.reviewScheduler(session, row.prNumber, sha, at);
    } on Object catch (e) {
      // The sweep picks it up.
      session.log(
        'board.github: could not schedule the review of #${row.prNumber}: $e',
        level: LogLevel.warning,
      );
    }
  }

  /// A maintainer pressed *Re-run* on the review check.
  static Future<void> rerequest(Session session, int prNumber) async {
    final row = await BoardPullRequest.db.findFirstRow(
      session,
      where: (t) => t.prNumber.equals(prNumber),
    );
    if (row == null || row.state != 'open' || row.taskId == null) return;
    if (row.gateState != GithubGate.passed &&
        row.gateState != GithubGate.exempt) {
      return;
    }
    await schedule(
      session,
      row,
      row.headSha,
      force: true,
      delay: Duration.zero,
    );
  }

  /// Takes the scheduled review of [sha] for [prNumber] if it is still the
  /// latest and due: clears it atomically, so one run wins.
  static Future<BoardPullRequest?> _claim(
    Session session,
    int prNumber,
    String sha,
  ) async {
    final now = nowUtc();
    final rows = await BoardPullRequest.db.updateWhere(
      session,
      columnValues: (t) => [t.reviewPendingSha(null), t.reviewDueAt(null)],
      where: (t) =>
          t.prNumber.equals(prNumber) &
          t.reviewPendingSha.equals(sha) &
          (t.reviewDueAt <= now.add(const Duration(seconds: 5))),
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Sweep: due reviews whose future call didn't run (postponed to the
  /// next day, lost) run now. Returns the count.
  static Future<int> runDue(Session session) async {
    final now = nowUtc();
    final rows = await BoardPullRequest.db.find(
      session,
      where: (t) =>
          t.reviewPendingSha.notEquals(null) &
          (t.reviewDueAt <= now.subtract(sweepGrace)) &
          t.state.equals('open'),
      limit: 20,
    );
    var count = 0;
    for (final r in rows) {
      try {
        await run(session, r.prNumber, r.reviewPendingSha!);
        count++;
      } on Exception catch (e) {
        session.log(
          'board.github: review of #${r.prNumber} failed: $e',
          level: LogLevel.warning,
        );
      }
    }
    return count;
  }

  // ----------------------------------------------------------------- run

  /// The scheduled review of [sha] (the future call and the sweep). Drops
  /// superseded runs.
  static Future<void> run(Session session, int prNumber, String sha) async {
    if (!BoardConfig.current.github.enabled) return;
    final row = await _claim(session, prNumber, sha);
    if (row == null) return;
    try {
      await _review(session, row, sha);
    } on Exception {
      // GitHub or the database failed midway: try again later.
      await _setPending(session, prNumber, sha, nowUtc().add(retryDelay));
      rethrow;
    }
  }

  static Future<void> _review(
    Session session,
    BoardPullRequest row,
    String sha,
  ) async {
    final prNumber = row.prNumber;
    if (row.state != 'open' || row.taskId == null) return;
    if (row.gateState != GithubGate.passed &&
        row.gateState != GithubGate.exempt) {
      return;
    }
    final task = await BoardTask.db.findById(session, row.taskId!);
    if (task == null || task.prNumber != prNumber) return;
    final api = BoardGithub.api;
    final pr = await api.getPullRequest(prNumber);
    // A newer commit arrived: its own review is scheduled by the gate.
    if (pr.state != 'open' || pr.headSha != sha || pr.draft) return;

    final config = BoardConfig.current.github;
    final now = nowUtc();
    final today = BoardAiLedger.day(now);
    final count = row.reviewDay == today ? row.reviewCount : 0;
    if (count >= config.reviewsPerPrPerDay) {
      await _postpone(
        session,
        row,
        sha,
        'Review postponed: the daily limit of '
        '${config.reviewsPerPrPerDay} reviews for this pull request is '
        'reached',
      );
      return;
    }
    final reviewer = PrReviewer.instance;
    if (!reviewer.configured) {
      await api.createCheckRun(
        name: checkName,
        headSha: sha,
        status: 'completed',
        conclusion: 'neutral',
        title: 'Review unavailable',
        summary: 'The board AI is not configured on the server.',
      );
      return;
    }

    final checkId = await api.createCheckRun(
      name: checkName,
      headSha: sha,
      status: 'in_progress',
      title: 'Reviewing against T-${task.id}',
      summary: 'The review of this commit against the task is running.',
      detailsUrl: GithubGate.taskUrl(task.id!),
    );
    final files = await api.listPullRequestFiles(prNumber);
    final facts = PrFacts.of(files);
    String rawDiff;
    try {
      rawDiff = await api.getPullRequestDiff(prNumber);
    } on GithubApiException catch (e) {
      // Too large for GitHub's diff media type: build it from the patches.
      if (e is GithubRateLimitException) rethrow;
      rawDiff = PrDiff.fromFiles(files);
    }
    final diff = PrDiff.filter(rawDiff, maxTokens: config.maxDiffTokens);
    final posts = await BoardPost.db.find(
      session,
      where: (t) => t.taskId.equals(task.id!) & t.deletedAt.equals(null),
      orderBy: (t) => t.id,
    );

    final PrReviewResult result;
    try {
      result = await reviewer.review(
        session,
        PrReviewInput(
          task: task,
          posts: posts,
          prNumber: prNumber,
          prTitle: pr.title,
          prBody: pr.body,
          facts: facts,
          diff: diff,
        ),
      );
    } on BoardAiBudgetException {
      await api.updateCheckRun(
        checkId,
        status: 'completed',
        conclusion: 'neutral',
        title: "Review postponed: today's AI budget is used up",
        summary:
            "Review postponed: today's AI budget is used up. It runs again "
            'tomorrow (UTC).',
      );
      await _setPending(session, prNumber, sha, _nextDay(now));
      return;
    } on BoardAiException catch (e) {
      await _countRun(session, prNumber, today, count);
      await api.updateCheckRun(
        checkId,
        status: 'completed',
        conclusion: 'neutral',
        title: 'Review failed',
        summary: e.retryable
            ? 'The AI review failed; it is retried in '
                  '${retryDelay.inMinutes} minutes.'
            : 'The AI review failed.',
      );
      if (e.retryable) {
        await _setPending(session, prNumber, sha, now.add(retryDelay));
      }
      return;
    }

    await _countRun(session, prNumber, today, count);
    final stored = storedJson(
      result: result,
      facts: facts,
      diff: diff,
      sha: sha,
      at: now,
      taskNumber: task.id!,
    );
    final commentId = await GithubGate.upsertComment(
      session,
      prNumber,
      row.reviewCommentId,
      marker,
      renderComment(
        result: result,
        facts: facts,
        diff: diff,
        sha: sha,
        task: task,
      ),
    );
    final blocking = config.reviewBlocking && isBlocking(result, facts);
    await api.updateCheckRun(
      checkId,
      status: 'completed',
      conclusion: blocking ? 'failure' : 'neutral',
      title: checkTitle(result),
      summary:
          '${_safe(result.summary)}\n\nThe full review is in the '
          'pull request comment. Advisory: CI stays the hard gate.',
    );
    final latest = await BoardPullRequest.db.findFirstRow(
      session,
      where: (t) => t.prNumber.equals(prNumber),
    );
    if (latest != null) {
      await BoardPullRequest.db.updateRow(
        session,
        latest.copyWith(
          lastReviewSha: sha,
          lastReviewJson: jsonEncode(stored),
          lastReviewAt: now,
          reviewCommentId: commentId,
          updatedAt: now,
        ),
        columns: (t) => [
          t.lastReviewSha,
          t.lastReviewJson,
          t.lastReviewAt,
          t.reviewCommentId,
          t.updatedAt,
        ],
      );
    }
    await BoardLive.task(session, task.id!);
  }

  static DateTime _nextDay(DateTime now) {
    final u = now.toUtc();
    return DateTime.utc(u.year, u.month, u.day + 1);
  }

  static Future<void> _countRun(
    Session session,
    int prNumber,
    String today,
    int before,
  ) => BoardPullRequest.db.updateWhere(
    session,
    columnValues: (t) => [t.reviewDay(today), t.reviewCount(before + 1)],
    where: (t) => t.prNumber.equals(prNumber),
  );

  /// Keeps [sha] pending until [at] unless a newer SHA was scheduled
  /// meanwhile.
  static Future<void> _setPending(
    Session session,
    int prNumber,
    String sha,
    DateTime at,
  ) => BoardPullRequest.db.updateWhere(
    session,
    columnValues: (t) => [t.reviewPendingSha(sha), t.reviewDueAt(at)],
    where: (t) => t.prNumber.equals(prNumber) & t.reviewPendingSha.equals(null),
  );

  static Future<void> _postpone(
    Session session,
    BoardPullRequest row,
    String sha,
    String title,
  ) async {
    await BoardGithub.api.createCheckRun(
      name: checkName,
      headSha: sha,
      status: 'completed',
      conclusion: 'neutral',
      title: title,
      summary: '$title. It runs again tomorrow (UTC).',
    );
    await _setPending(session, row.prNumber, sha, _nextDay(nowUtc()));
  }

  // ------------------------------------------------------------ results

  /// Blocking mode (`board.github.reviewBlocking`): a `notMet` criterion,
  /// or unrelated changes over [majorUnrelatedLines] changed lines.
  static bool isBlocking(PrReviewResult r, PrFacts facts) {
    if (r.anyNotMet) return true;
    final unrelated = {for (final u in r.unrelatedChanges) u.path};
    final lines = facts.files
        .where((f) => unrelated.contains(f.path))
        .fold(0, (s, f) => s + f.additions + f.deletions);
    return lines > majorUnrelatedLines;
  }

  static String checkTitle(PrReviewResult r) {
    final met = r.criteria.where((c) => c.verdict == 'met').length;
    return r.criteria.isEmpty
        ? 'Reviewed'
        : '$met of ${r.criteria.length} criteria met';
  }

  /// What the task page reads (`BoardTaskView.reviewJson`).
  static Map<String, Object?> storedJson({
    required PrReviewResult result,
    required PrFacts facts,
    required PrDiff diff,
    required String sha,
    required DateTime at,
    required int taskNumber,
  }) => {
    'version': 1,
    'taskNumber': taskNumber,
    'sha': sha,
    'reviewedAt': at.toUtc().toIso8601String(),
    ...result.toJson(),
    'facts': facts.toJson(),
    'truncatedFiles': diff.truncated,
    'excludedFiles': diff.excluded.length,
  };

  static const _verdictText = {
    'met': 'Met',
    'partly': 'Partly',
    'notMet': 'Not met',
    'cantTell': "Can't tell",
    'added': 'Added',
    'missing': 'Missing',
    'notNeeded': 'Not needed',
    'updated': 'Updated',
  };

  static const _riskText = {
    'security': 'Security',
    'dataLoss': 'Data loss',
    'migration': 'Migration',
    'dependency': 'Dependency',
    'workflow': 'Workflow',
  };

  /// Model text made safe for the comment: no HTML (and so no forged
  /// markers), no @-mentions, one line.
  static String _safe(String s) => s
      .replaceAll(RegExp(r'<!--|-->'), '')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('@', '@​')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// [s] safe inside a table cell.
  static String _cell(String s) => _safe(s).replaceAll('|', r'\|');

  static String _code(String path) =>
      '`${path.replaceAll('`', "'").replaceAll('|', r'\|')}`';

  /// The review comment (one per PR, updated in place).
  static String renderComment({
    required PrReviewResult result,
    required PrFacts facts,
    required PrDiff diff,
    required String sha,
    required BoardTask task,
  }) {
    final b = StringBuffer()
      ..writeln(marker)
      ..writeln(
        '### Wonky task review: '
        '[T-${task.id}: ${GithubGate.linkText(task.title)}]'
        '(${GithubGate.taskUrl(task.id!)})',
      )
      ..writeln()
      ..writeln(_safe(result.summary))
      ..writeln();
    if (result.criteria.isNotEmpty) {
      b
        ..writeln('| Acceptance criterion | Verdict | Evidence | Note |')
        ..writeln('|---|---|---|---|');
      for (final c in result.criteria) {
        final evidence = [
          for (final e in c.evidence)
            e.lines == null
                ? _code(e.path)
                : '${_code(e.path)} (${_cell(e.lines!)})',
        ].join(', ');
        b.writeln(
          '| ${_cell(c.criterion)} | ${_verdictText[c.verdict]} | '
          '$evidence | ${_cell(c.note)} |',
        );
      }
      b.writeln();
    }
    b.writeln('**Scope:**');
    if (result.unrelatedChanges.isEmpty) {
      b.writeln('No unrelated changes found.');
    } else {
      for (final u in result.unrelatedChanges) {
        b.writeln('- ${_code(u.path)}: ${_safe(u.note)}');
      }
    }
    b
      ..writeln()
      ..writeln(
        '**Tests:** ${_verdictText[result.tests.verdict]}'
        '${result.tests.note.isEmpty ? '' : '. ${_safe(result.tests.note)}'}',
      )
      ..writeln()
      ..writeln(
        '**Specs:** ${_verdictText[result.specs.verdict]}'
        '${result.specs.note.isEmpty ? '' : '. ${_safe(result.specs.note)}'}',
      )
      ..writeln();
    if (result.risks.isNotEmpty) {
      b.writeln('**Risks:**');
      for (final r in result.risks) {
        b.writeln(
          '- ${_riskText[r.kind]}${r.path.isEmpty ? '' : ' in ${_code(r.path)}'}'
          ': ${_safe(r.note)}',
        );
      }
      b.writeln();
    }
    b
      ..writeln('<details><summary>Facts</summary>')
      ..writeln()
      ..writeln(
        '- Changed files: ${facts.files.length} '
        '(+${facts.additions} −${facts.deletions})',
      )
      ..writeln('- Tests changed: ${facts.testsChanged ? 'yes' : 'no'}')
      ..writeln('- `specs/` changed: ${facts.specsChanged ? 'yes' : 'no'}')
      ..writeln(
        '- `pubspec.yaml` changed: '
        '${facts.pubspecs.isEmpty ? 'no' : facts.pubspecs.map(_code).join(', ')}',
      )
      ..writeln(
        '- Migrations added: ${facts.migrationsAdded.isEmpty ? 'none' : facts.migrationsAdded.map(_code).join(', ')}',
      )
      ..writeln(
        '- Workflow or tooling changes: ${facts.workflowFiles.isEmpty ? 'none' : facts.workflowFiles.map(_code).join(', ')}',
      )
      ..writeln(
        '- Security-sensitive paths: ${facts.sensitiveFiles.isEmpty ? 'none' : facts.sensitiveFiles.map(_code).join(', ')}',
      );
    if (diff.truncated.isNotEmpty) {
      b.writeln(
        '- Not reviewed (diff too large): '
        '${diff.truncated.map(_code).join(', ')}',
      );
    }
    b
      ..writeln()
      ..writeln('</details>')
      ..writeln()
      ..writeln(
        'Reviewed commit `${sha.length > 12 ? sha.substring(0, 12) : sha}`. '
        'This review is advisory; CI and the maintainers decide.',
      );
    return b.toString();
  }
}
