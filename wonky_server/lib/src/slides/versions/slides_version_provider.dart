import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/history.dart';
import 'package:wonky_slides_core/schema.dart' show SlidesTables;

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/files/file_service.dart';
import '../../platform/presence/presence_service.dart';
import '../../platform/users/user_service.dart';
import '../../platform/versions/version_service.dart';
import '../../sheets/sync/sync_db.dart';
import '../headless/headless_deck_cache.dart';
import '../sync/server_slides_writer.dart';

/// Slides versions (Slides 09 §4.1, §4.4): a gzip NDJSON snapshot of every
/// synced deck row in cloud storage (`snapshot.wsd.gz`, not counted toward
/// the quota) with a `SlidesSnapshotIndex` (slide list, who changed what);
/// a restore applies the row diff as normal forward writes recorded as a
/// `ServerChangeRecord` (`slides.serverChange` undo).
class SlidesVersionProvider implements VersionProvider {
  const SlidesVersionProvider();

  /// Max change-log rows read for one version's attribution.
  static const maxLogRows = 20000;

  @override
  DriveItemKind get kind => DriveItemKind.presentation;

  /// Every visible row of [space] (admin read) by table and id.
  static Future<DeckRowsByTable> readSpace(Session session, UuidValue space) =>
      HeadlessDeckCache.readSpace(session, space);

  /// The rows of [rows] as `(table, columns)` in dependency order.
  static List<(String, Map<String, Object?>)> listOf(DeckRowsByTable rows) => [
    for (final t in SlidesTables.dependencyOrder)
      for (final r in rows[t]?.values ?? const <Map<String, Object?>>[]) (t, r),
  ];

  @override
  Future<CapturedVersion> capture(Session session, DriveItem item) async {
    final space = item.contentRef!;
    final rows = await readSpace(session, space);
    if (rows[SlidesTables.deck]?.isEmpty ?? true) {
      throw Errors.notFound('Presentation');
    }
    final bytes = SlidesSnapshotCodec.encode(
      listOf(rows),
      deckId: space.uuid,
      capturedAt: nowUtc(),
    );
    final file = await FileService.storeServerFile(
      session,
      ownerId: item.ownerId,
      itemId: item.id,
      kind: StoredFileKind.snapshot,
      fileName: 'snapshot.wsd.gz',
      mimeType: 'application/gzip',
      bytes: bytes,
    );
    return CapturedVersion(
      storageKind: VersionStorage.snapshotFile,
      snapshotFileId: file.fileUuid,
      sizeBytes: bytes.length,
    );
  }

  /// The decoded snapshot of [version].
  static Future<SlidesSnapshot> snapshotOf(
    Session session,
    ItemVersion version,
  ) async {
    final fileId = version.snapshotFileId;
    if (fileId == null) throw Errors.invalid('The version has no snapshot.');
    final file = await FileService.byUuid(session, fileId);
    if (file == null) throw Errors.expired('The snapshot is no longer stored.');
    final bytes = await FileService.readBytes(session, file);
    try {
      return SlidesSnapshotCodec.decode(
        Uint8List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } on FormatException catch (e) {
      throw Errors.invalid('The snapshot is damaged (${e.message}).');
    }
  }

  @override
  Future<void> afterCapture(
    Session session,
    DriveItem item,
    ItemVersion version,
  ) async {
    final snapshot = await snapshotOf(session, version);
    final changes = await changesOf(session, item, version);
    await SlidesSnapshotIndex.db.insertRow(
      session,
      SlidesSnapshotIndex(
        itemVersionId: version.id!,
        slidesJson: SnapshotSlideEntry.encodeList(snapshot.toModel()),
        changesJson: changes.encode(),
        authorIds: version.authors,
      ),
    );
  }

  /// The capture window of [version]: from the previous version of its
  /// item (exclusive) to its own capture.
  static Future<(DateTime?, DateTime)> windowOf(
    Session session,
    ItemVersion version,
  ) async {
    final prev = await ItemVersion.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(version.itemId) & (t.id < version.id!),
      orderBy: (t) => t.id.desc(),
    );
    return (prev?.createdAt, version.createdAt);
  }

  /// Who changed what in [version]'s window: the deck change-log rows
  /// consumed (their receipts' `processedAt`) after the previous capture,
  /// oldest first (offline edits that synced later belong to the version
  /// that consumed them; 09 §4.1). Empty on errors.
  static Future<SlidesVersionChanges> changesOf(
    Session session,
    DriveItem item,
    ItemVersion version,
  ) async {
    try {
      final (from, to) = await windowOf(session, version);
      final receipts = await DeckChangeLogReceipt.db.find(
        session,
        where: (t) =>
            t.deckUuid.equals(item.contentRef!) &
            (from == null ? Constant.bool(true) : t.processedAt > from) &
            (t.processedAt <= to),
        orderBy: (t) => t.processedAt,
        limit: maxLogRows,
      );
      final builder = SlidesVersionChangesBuilder();
      if (receipts.length >= maxLogRows) builder.markApprox();
      if (receipts.isEmpty) return builder.build();
      final logs = await DeckChangeLog.db.find(
        syncSessionOf(session),
        where: (t) => t.id.inSet({for (final r in receipts) r.changeLogId}),
        orderBy: (t) => t.at,
      );
      if (logs.length < receipts.length) builder.markApprox(); // pruned
      final profiles = await UserProfile.db.find(
        session,
        where: (t) => t.authUserId.inSet({for (final l in logs) l.userId}),
      );
      final byAuth = {for (final p in profiles) p.authUserId.uuid: p.id!};
      for (final l in logs) {
        final user = byAuth[l.userId.uuid];
        if (user == null) continue;
        builder.add(l.summaryJson, user, actorKind: l.actorKind.name);
      }
      return builder.build();
    } on Exception catch (e) {
      session.log('Version changes failed: $e', level: LogLevel.warning);
      return const SlidesVersionChanges(approx: true);
    }
  }

  @override
  Future<RestoredVersion> restore(
    Session session,
    Actor actor,
    DriveItem item,
    ItemVersion version,
  ) async {
    final target = (await snapshotOf(session, version)).byTable();
    final current = await readSpace(session, item.contentRef!);
    final changes = SlidesRestoreChanges.between(current, target);
    final label =
        'Restore version "${version.name ?? version.createdAt.toIso8601String()}"';
    final write = await ServerSlidesWriter.applyRecorded(
      session,
      actor: actor,
      item: item,
      changes: changes,
      label: label,
      // Slides and elements deleted since the version come back.
      revives: true,
      lifetime: const Duration(days: 7),
    );
    try {
      final profile = await UserService.requireProfile(session, actor.userId);
      final who = await UserService.summaryOf(session, profile);
      await PresenceService.notice(session, item.uuid, 'versionRestored', {
        'userId': actor.userId,
        'name': who.displayName,
        'versionId': version.id,
      });
    } on Exception catch (e) {
      session.log('Restore notice failed: $e', level: LogLevel.warning);
    }
    return RestoredVersion(changeId: write.changeId);
  }

  @override
  Future<void> discard(Session session, ItemVersion version) async {
    if (version.snapshotFileId != null) {
      await FileService.deleteFile(session, version.snapshotFileId!);
    }
  }
}
