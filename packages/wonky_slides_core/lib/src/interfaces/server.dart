import '../model/api/deck_model.dart';
import '../ops/change_summary.dart';
import '../ops/operations.dart';

/// A `DeckChangeLog` row as plain values (02 §3.10), for consumers that run
/// on the server after `onMergeSuccess` and in tests.
final class DeckChangeLogEntry {
  /// Creates an entry.
  const DeckChangeLogEntry({
    required this.id,
    required this.deckId,
    required this.userId,
    required this.actorKind,
    required this.sessionId,
    required this.label,
    required this.summaryJson,
    this.detailJson,
    required this.at,
  });

  final String id;
  final String deckId;
  final String userId;

  /// `user`, `mcp`, `ai`, `script`.
  final String actorKind;
  final String sessionId;
  final String label;

  /// 02 §3.10.1.
  final String summaryJson;
  final String? detailJson;
  final DateTime at;
}

/// A plugin of the server's deck change-log consumer (12 §5.7): drive
/// mirror, activity, comment orphaning, versions, agent cursors, headless
/// cache. [C] is the server's request context (`Session`); the server binds
/// it (`DeckChangeLogConsumer<Session>`, SL-5), which keeps this contract
/// pure Dart.
abstract interface class DeckChangeLogConsumer<C> {
  /// Stable plugin id (its cursor key: exactly-once across restarts).
  String get id;

  /// Consumes the new [rows] of [deckId] in `at` order.
  Future<void> consume(C context, String deckId, List<DeckChangeLogEntry> rows);
}

/// A deck opened on the server for headless reads and writes (MCP, AI,
/// templates, restore; SL-8 `HeadlessDeck` over `ServerSlidesWriter`).
abstract interface class HeadlessDeck {
  /// The deck model (read).
  DeckModel get model;

  /// Plans [op] with the shared planner, writes it (one transaction per
  /// ≤ 5,000 changes + `DeckChangeLog`) and applies it to [model]. Throws
  /// `PlanException`.
  Future<SlidesPlan> execute(SlidesOperation op, {String actorKind = 'mcp'});
}

/// Opens [HeadlessDeck]s (12 §5.7); [C] as in [DeckChangeLogConsumer].
abstract interface class HeadlessDeckProvider<C> {
  /// Opens deck [deckId] (= space UUID) for the context's user.
  Future<HeadlessDeck> open(C context, String deckId);
}
