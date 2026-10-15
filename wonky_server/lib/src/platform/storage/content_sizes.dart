import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_sync_models/tables.dart' show SyncedTables;
import 'package:wonky_write_core/wonky_write_core.dart' show Delta;

import '../../generated/future_calls.dart';
import '../../write/ot/document_store.dart';
import '../common/models.dart';
import 'storage_service.dart';

/// The counted content size of a Write document (Drive 03 §2): the UTF-8
/// length of the current Delta JSON (the document as it is now; the op log
/// is history and is not counted).
abstract final class DocumentSize {
  static int of(Delta content) =>
      utf8.encode(jsonEncode(content.toJson())).length;
}

/// Estimates the counted content size of an item of one kind (Drive 03
/// §2). Estimates are deterministic: the same content gives the same
/// number. Slides registers its deck estimator with
/// [ContentSizes.register] (a [SpaceSizeEstimator] over its synced tables).
abstract interface class ContentSizeEstimator {
  /// The content size of [item] in bytes, or null when it can't be
  /// measured (missing content).
  Future<int?> estimate(Session session, DriveItem item);
}

/// Documents: [DocumentSize] of the head.
class DocumentSizeEstimator implements ContentSizeEstimator {
  const DocumentSizeEstimator();

  @override
  Future<int?> estimate(Session session, DriveItem item) async {
    final doc = await DocumentStore.byItem(session, item.id!);
    if (doc == null) return null;
    return DocumentSize.of(await DocumentStore.head(session, doc));
  }
}

/// Offline-first spaces (spreadsheets, decks): `sum(pg_column_size(row))`
/// over the live rows of the space in each of [tables] (Drive 03 §2). Rows
/// hidden by the sync engine (deleted, cascaded) don't count. Every synced
/// row has its `crdt_data_rows` entry (written by the sync engine), which
/// gives the visibility and an index by space.
class SpaceSizeEstimator implements ContentSizeEstimator {
  const SpaceSizeEstimator(this.tables);

  /// The synced table names that hold the content.
  final List<String> tables;

  /// The sync engine's last visible `crdt_data_rows.visibility` index
  /// (`CrdtDataRowVisibility.foreignKeyRestrictRestore`); larger = hidden.
  static const _lastVisible = 2;

  static final _identifier = RegExp(r'^[a-z_][a-z0-9_]*$');

  @override
  Future<int?> estimate(Session session, DriveItem item) async {
    final space = item.contentRef;
    if (space == null) return null;
    return estimateSpace(session, space);
  }

  /// The size of [spaceUuid]'s content; null when the space is missing.
  Future<int?> estimateSpace(Session session, UuidValue spaceUuid) async {
    final ids = await session.db.unsafeQuery(
      'SELECT id FROM offline_sync_spaces WHERE "uuidSpaceId" = @u::uuid',
      parameters: QueryParameters.named({'u': spaceUuid.uuid}),
    );
    if (ids.isEmpty) return null;
    final spaceId = ids.first[0] as int;
    final parts = <String>[];
    for (final t in tables) {
      if (!_identifier.hasMatch(t)) throw ArgumentError.value(t, 'table');
      // Driven by the engine's (spaceId, tblId, uuidRowId) index, so the
      // cost follows the space's size, not the table's (S-D3).
      parts.add('''
        SELECT coalesce(sum(pg_column_size(t.*)), 0)::bigint AS n
        FROM crdt_data_rows r
        JOIN "$t" t ON t.id = r."uuidRowId" AND t."spaceId" = r."spaceId"
        WHERE r."spaceId" = @space
          AND r."tblId" = (SELECT id FROM crdt_schema_tables WHERE name = '$t')
          AND r.visibility <= $_lastVisible''');
    }
    if (parts.isEmpty) return 0;
    final rows = await session.db.unsafeQuery(
      'SELECT coalesce(sum(n), 0)::bigint FROM (${parts.join(' UNION ALL ')}) x',
      parameters: QueryParameters.named({'space': spaceId}),
    );
    return rows.first[0] as int;
  }
}

/// The Sheets estimator: every synced Sheets table except the change log
/// (history, like Write's op log) and script builds (bytecode), which
/// don't count (Drive 03 §2).
class SheetsSizeEstimator extends SpaceSizeEstimator {
  SheetsSizeEstimator()
    : super([
        for (final s in SyncedTables.all)
          if (!excluded.contains(s.name)) s.name,
      ]);

  static const excluded = {'change_log', 'script_build'};
}

/// Content size estimation and its cadence (Drive 03 §2): documents with
/// the OT service's throttled search-text update and on create/copy/
/// import; spaces after server writes and, from the change-log consumer,
/// at most every [spaceInterval] per item (trailing).
abstract final class ContentSizes {
  static final Map<DriveItemKind, ContentSizeEstimator> _estimators = {
    DriveItemKind.document: const DocumentSizeEstimator(),
    DriveItemKind.spreadsheet: SheetsSizeEstimator(),
  };

  /// Registers the estimator of [kind] (Slides: `presentation`).
  static void register(DriveItemKind kind, ContentSizeEstimator estimator) =>
      _estimators[kind] = estimator;

  static ContentSizeEstimator? estimatorOf(DriveItemKind kind) =>
      _estimators[kind];

  /// The minimum time between two estimates of one space from the
  /// change-log consumer (S-D3, Drive 03 §2).
  static Duration spaceInterval = const Duration(minutes: 5);

  static final Map<int, DateTime> _lastRun = {};
  static final Set<int> _pending = {};

  /// Schedules a trailing refresh of item [itemId] after [delay]
  /// (replaceable in tests; default: `StorageFutureCall.refreshItemSize`).
  static Future<void> Function(Session session, int itemId, Duration delay)
  scheduleRefresh = _scheduleViaFutureCall;

  static Future<void> _scheduleViaFutureCall(
    Session session,
    int itemId,
    Duration delay,
  ) => session.serverpod.futureCalls
      .callWithDelay(delay)
      .storage
      .refreshItemSize(itemId);

  /// The estimate of [item]'s content, or null (folders, files: their
  /// size is exact and set on upload).
  static Future<int?> estimate(Session session, DriveItem item) async {
    final estimator = _estimators[item.kind];
    if (estimator == null) return null;
    return estimator.estimate(session, item);
  }

  /// Estimates [item] now and stores the size through [StorageService]
  /// (never throws for quota; may put the owner over quota). Errors are
  /// logged, not thrown: sizes are bookkeeping.
  static Future<void> refresh(Session session, DriveItem item) async {
    if (item.id == null) return;
    _lastRun[item.id!] = clock.now();
    try {
      final size = await estimate(session, item);
      if (size == null) return;
      await StorageService.instance.setItemSize(session, item, size);
    } on Exception catch (e, st) {
      session.log(
        'Size estimate of item ${item.id} failed: $e',
        level: LogLevel.warning,
        stackTrace: st,
      );
    }
  }

  /// [refresh] by id (the trailing FutureCall).
  static Future<void> refreshById(Session session, int itemId) async {
    _pending.remove(itemId);
    final item = await DriveItem.db.findById(session, itemId);
    if (item != null) await refresh(session, item);
  }

  /// The change-log consumer processed new rows of [item]'s space: refresh
  /// now when the last estimate is older than [spaceInterval], else once
  /// at the end of the interval.
  static Future<void> onSpaceChanged(Session session, DriveItem item) async {
    final id = item.id;
    if (id == null) return;
    final last = _lastRun[id];
    final now = clock.now();
    if (last == null || now.difference(last) >= spaceInterval) {
      await refresh(session, item);
      return;
    }
    if (!_pending.add(id)) return;
    try {
      await scheduleRefresh(
        session,
        id,
        last.add(spaceInterval).difference(now),
      );
    } on Object catch (e) {
      _pending.remove(id);
      session.log(
        'Could not schedule the size estimate of item $id: $e',
        level: LogLevel.warning,
      );
    }
  }

  /// Forgets the cadence state (tests).
  static void reset() {
    _lastRun.clear();
    _pending.clear();
  }
}
