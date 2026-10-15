import 'package:serverpod/serverpod.dart';

import '../../common/models.dart';
import '../../common/time.dart';

/// Usage accounting of the board AI (specs/16 §6.1): one [BoardAiUsage]
/// row per UTC day, provider, model and feature. Separate from the in-app
/// `ai_usage` table, which the board never writes.
abstract final class BoardAiLedger {
  static const jev = 'jev';
  static const gemini = 'gemini';

  /// `yyyy-mm-dd` of [at] (default: now) in UTC.
  static String day([DateTime? at]) {
    final u = (at ?? nowUtc()).toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)}';
  }

  /// Adds one request with its tokens to today's row (an upsert, safe
  /// under concurrency through the unique index).
  static Future<void> record(
    Session session, {
    required String provider,
    required String model,
    required String feature,
    required int inputTokens,
    required int outputTokens,
  }) => session.db.unsafeExecute(
    'INSERT INTO board_ai_usage ("day", "provider", "model", "feature", '
    '"requests", "inputTokens", "outputTokens") '
    'VALUES (@day, @provider, @model, @feature, 1, @input, @output) '
    'ON CONFLICT ("day", "provider", "model", "feature") DO UPDATE SET '
    '"requests" = board_ai_usage."requests" + 1, '
    '"inputTokens" = board_ai_usage."inputTokens" + EXCLUDED."inputTokens", '
    '"outputTokens" = board_ai_usage."outputTokens" + EXCLUDED."outputTokens"',
    parameters: QueryParameters.named({
      'day': day(),
      'provider': provider,
      'model': model,
      'feature': feature,
      'input': inputTokens,
      'output': outputTokens,
    }),
  );

  /// Input plus output tokens of [provider] today (all models, features).
  static Future<int> usedToday(Session session, String provider) async {
    final rows = await BoardAiUsage.db.find(
      session,
      where: (t) => t.day.equals(day()) & t.provider.equals(provider),
    );
    var sum = 0;
    for (final r in rows) {
      sum += r.inputTokens + r.outputTokens;
    }
    return sum;
  }
}
