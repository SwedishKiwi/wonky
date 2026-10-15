import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/interfaces.dart'
    show DeckChangeLogConsumer, DeckChangeLogEntry;

import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../sheets/sync/sync_db.dart';
import '../slides_server.dart';

/// What a deck change-log plugin gets besides the rows (12 §5.7): the
/// session, the deck's drive item and the authors of the rows. The server
/// binds the pure-Dart contract `DeckChangeLogConsumer<C>` to this context
/// (instead of a bare `Session`) so plugins don't look the item up again.
final class DeckConsumerContext {
  DeckConsumerContext(this.session, this.item);

  final Session session;

  /// The deck's drive item (kind `presentation`, `contentRef` = space).
  final DriveItem item;

  /// The deck's space (= `Deck.id` = item uuid).
  UuidValue get deckSpace => item.contentRef!;

  final Map<String, Future<Actor?>> _actors = {};

  /// The author of [entry] as an [Actor] (null when the auth user has no
  /// profile, e.g. deleted).
  Future<Actor?> actorOf(
    DeckChangeLogEntry entry,
  ) => _actors['${entry.userId}|${entry.actorKind}|${entry.sessionId}'] ??=
      () async {
        final profile = await UserProfile.db.findFirstRow(
          session,
          where: (t) => t.authUserId.equals(UuidValue.fromString(entry.userId)),
        );
        if (profile == null) return null;
        return Actor(
          userId: profile.id!,
          authUserId: profile.authUserId,
          kind: ActorKind.values.asNameMap()[entry.actorKind] ?? ActorKind.user,
          sessionId: entry.sessionId,
        );
      }();
}

/// A plugin of the deck change-log consumer on the server.
typedef DeckChangeLogPlugin = DeckChangeLogConsumer<DeckConsumerContext>;

/// The parsed `summaryJson` of a `DeckChangeLog` row (02 §3.10.1), lenient:
/// unknown or malformed content reads as empty.
final class DeckChangeSummaryView {
  DeckChangeSummaryView._(this.json);

  factory DeckChangeSummaryView.parse(String summaryJson) {
    try {
      final v = jsonDecode(summaryJson);
      if (v is Map) return DeckChangeSummaryView._(v.cast<String, Object?>());
    } on FormatException {
      // Malformed: empty.
    }
    return DeckChangeSummaryView._(const {});
  }

  final Map<String, Object?> json;

  List<String> _list(Object? v) => [
    if (v is List)
      for (final e in v)
        if (e is String) e,
  ];

  Set<String> get kinds => _list(json['kinds']).toSet();
  List<String> get slides => _list(json['slides']);
  List<String> get elements => _list(json['elements']);

  /// Deleted ids of [category] (`slides`, `elements`, `groups`, `themes`).
  List<String> deleted(String category) =>
      _list((json['deleted'] as Map?)?[category]);

  /// Revived ids of [category].
  List<String> revived(String category) =>
      _list((json['revived'] as Map?)?[category]);
}

/// Consumes synced `DeckChangeLog` rows after `onMergeSuccess` (Slides 02
/// §3.10, 09 §5, 12 §5.7) with the registered [plugins] (drive mirror,
/// activity, storage size; later comment orphaning, versions, agent cursors,
/// headless cache).
///
/// Exactly once per row and plugin, across instances and restarts: a row is
/// claimed by inserting its [DeckChangeLogReceipt] (unique), each plugin
/// consumes the claimed rows as one batch and is then recorded in the
/// receipt's `doneConsumers`, and the receipt is completed. Rows without a
/// receipt, and rows whose claim is older than [staleClaim] and never
/// completed, are (re)processed — re-claimed rows only run the plugins not
/// yet recorded. A plugin that throws is logged and counted as done (a
/// broken plugin must not block the deck).
abstract final class DeckChangeLogProcessor {
  static const batchSize = 500;

  /// A claim older than this that never completed is processed again.
  static const staleClaim = Duration(minutes: 10);

  static final List<DeckChangeLogPlugin> _plugins = [];

  /// The registered plugins in run order.
  static List<DeckChangeLogPlugin> get plugins => List.unmodifiable(_plugins);

  /// Registers [plugin], replacing a plugin with the same id.
  static void register(DeckChangeLogPlugin plugin) {
    final at = _plugins.indexWhere((p) => p.id == plugin.id);
    if (at >= 0) {
      _plugins[at] = plugin;
    } else {
      _plugins.add(plugin);
    }
  }

  /// Removes the plugin [id] (tests).
  static void unregister(String id) => _plugins.removeWhere((p) => p.id == id);

  static final Map<String, Future<void>> _running = {};
  static final Set<String> _again = {};

  /// Processes the new change-log rows of [deckSpace]; concurrent calls for
  /// the same deck are coalesced on this instance (a call while one runs
  /// triggers one more pass afterwards). Returns the rows consumed.
  static Future<int> processSpace(Session session, UuidValue deckSpace) {
    SlidesServer.ensureRegistered();
    final key = deckSpace.uuid;
    final running = _running[key];
    if (running != null) {
      _again.add(key);
      return running.then((_) => 0);
    }
    final future = () async {
      var total = 0;
      do {
        _again.remove(key);
        total += await _process(session, deckSpace);
      } while (_again.contains(key));
      return total;
    }();
    _running[key] = future.then((_) {});
    return future.whenComplete(() => _running.remove(key));
  }

  static Future<int> _process(Session session, UuidValue deckSpace) async {
    final item = await DriveItem.db.findFirstRow(
      session,
      where: (t) =>
          t.contentRef.equals(deckSpace) &
          t.kind.equals(DriveItemKind.presentation),
    );
    // Unregistered decks are processed once registered.
    if (item == null) return 0;
    final context = DeckConsumerContext(session, item);
    var total = 0;
    final seen = <UuidValue>{};
    while (true) {
      final rows = await session.db.unsafeQuery(
        r'''
        SELECT c.id FROM deck_change_log c
        JOIN offline_sync_spaces s ON s.id = c."spaceId"
        LEFT JOIN deck_change_log_receipt r ON r."changeLogId" = c.id
        WHERE s."uuidSpaceId" = @space::uuid
          AND (r.id IS NULL
            OR (r."completedAt" IS NULL AND r."processedAt" < @stale))
        ORDER BY c.at, c.id
        LIMIT @limit
        ''',
        parameters: QueryParameters.named({
          'space': deckSpace.uuid,
          'limit': batchSize,
          'stale': nowUtc().subtract(staleClaim),
        }),
      );
      final ids = {
        for (final r in rows)
          if (!seen.contains(_uuid(r[0]))) _uuid(r[0]),
      };
      if (ids.isEmpty) break;
      seen.addAll(ids);
      final db = syncSessionOf(session);
      final changes = await DeckChangeLog.db.find(
        db,
        where: (t) => t.id.inSet(ids),
        orderBy: (t) => t.at,
      );
      final visible = {for (final c in changes) c.id};
      for (final id in ids.difference(visible)) {
        // Deleted (pruned) change-log rows: just mark them.
        if (await _claim(session, id, deckSpace)) {
          await _complete(session, {id});
        }
      }
      final claimed = <DeckChangeLog>[];
      for (final change in changes) {
        if (await _claim(session, change.id, deckSpace)) claimed.add(change);
      }
      if (claimed.isNotEmpty) {
        await _consume(context, claimed);
        await _complete(session, {for (final c in claimed) c.id});
        total += claimed.length;
      }
      if (ids.length < batchSize) break;
    }
    return total;
  }

  /// Runs every plugin over the claimed rows it has not consumed yet.
  static Future<void> _consume(
    DeckConsumerContext context,
    List<DeckChangeLog> claimed,
  ) async {
    final session = context.session;
    final receipts = await DeckChangeLogReceipt.db.find(
      session,
      where: (t) => t.changeLogId.inSet({for (final c in claimed) c.id}),
    );
    final done = {
      for (final r in receipts) r.changeLogId.uuid: r.doneConsumers.toSet(),
    };
    for (final plugin in List.of(_plugins)) {
      final pending = [
        for (final c in claimed)
          if (!(done[c.id.uuid]?.contains(plugin.id) ?? false)) c,
      ];
      if (pending.isEmpty) continue;
      try {
        await plugin.consume(context, context.deckSpace.uuid, [
          for (final c in pending) entryOf(c),
        ]);
      } on Exception catch (e, st) {
        session.log(
          'Deck change-log plugin ${plugin.id} failed on '
          '${context.item.uuid}: $e',
          level: LogLevel.error,
          stackTrace: st,
        );
      }
      for (final c in pending) {
        (done[c.id.uuid] ??= {}).add(plugin.id);
      }
      await _markDone(session, pending, done);
    }
  }

  /// Records the plugins done per row (rows with the same set share one
  /// statement; in the normal case that is the whole batch).
  static Future<void> _markDone(
    Session session,
    List<DeckChangeLog> rows,
    Map<String, Set<String>> done,
  ) async {
    final bySet = <String, (List<String>, Set<UuidValue>)>{};
    for (final c in rows) {
      final list = done[c.id.uuid]!.toList()..sort();
      bySet.putIfAbsent(list.join('\u0000'), () => (list, {})).$2.add(c.id);
    }
    for (final (list, ids) in bySet.values) {
      await DeckChangeLogReceipt.db.updateWhere(
        session,
        columnValues: (t) => [t.doneConsumers(list)],
        where: (t) => t.changeLogId.inSet(ids),
      );
    }
  }

  /// The plain-value entry of a change-log row (the core contract).
  static DeckChangeLogEntry entryOf(DeckChangeLog c) => DeckChangeLogEntry(
    id: c.id.uuid,
    deckId: c.deckId.uuid,
    userId: c.userId.uuid,
    actorKind: c.actorKind.name,
    sessionId: c.sessionId,
    label: c.label,
    summaryJson: c.summaryJson,
    detailJson: c.detailJson,
    at: c.at,
  );

  /// Claims [id]; false when another instance already did (and its claim is
  /// not stale).
  static Future<bool> _claim(
    Session session,
    UuidValue id,
    UuidValue deckSpace,
  ) async {
    final now = nowUtc();
    final inserted = await session.db.unsafeExecute(
      r'''
      INSERT INTO deck_change_log_receipt
        ("changeLogId", "deckUuid", "processedAt", "doneConsumers")
      VALUES (@id::uuid, @deck::uuid, @at, '[]')
      ON CONFLICT ("changeLogId") DO UPDATE SET "processedAt" = @at
        WHERE deck_change_log_receipt."completedAt" IS NULL
          AND deck_change_log_receipt."processedAt" < @stale
      ''',
      parameters: QueryParameters.named({
        'id': id.uuid,
        'deck': deckSpace.uuid,
        'at': now,
        'stale': now.subtract(staleClaim),
      }),
    );
    return inserted > 0;
  }

  static Future<void> _complete(Session session, Set<UuidValue> ids) =>
      DeckChangeLogReceipt.db.updateWhere(
        session,
        columnValues: (t) => [t.completedAt(nowUtc())],
        where: (t) => t.changeLogId.inSet(ids),
      );

  static UuidValue _uuid(Object? v) =>
      v is UuidValue ? v : UuidValue.fromString('$v');
}
