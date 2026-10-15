import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import '../../platform/cluster/cluster_bus.dart';
import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../../platform/spaces/space_sync.dart';
import '../changelog/deck_change_log_processor.dart';

/// The server side of `slidesSync.sync` (Slides 02 §9.1, suite 12 §2.5–2.6):
/// the engine's sync over deck spaces + the personal space only
/// ([SpaceSync], patch OS-8) with `onMergeSuccess`, which fans out
/// `slides:merged:<space>` and runs the deck change-log consumer.
abstract final class SlidesSyncService {
  static String mergedChannel(UuidValue space) => 'slides:merged:${space.uuid}';

  /// High-water marks per sync stream (a device that was offline merges
  /// changes with older HLCs than other devices, so marks are per stream).
  static final Expando<Map<String, Hlc>> _lastHlc = Expando(
    'slidesLastMergedHlc',
  );

  /// When true (tests), change-log processing is awaited inside the sync
  /// loop.
  static bool processInline = false;

  static Stream<OfflineSyncStreamEvent> sync(
    Session session,
    Actor actor, {
    required Stream<OfflineSyncStreamEvent> changes,
    bool once = false,
  }) => SpaceSync.sync(
    session,
    actor,
    kind: SpaceKind.deck,
    changes: changes,
    once: once,
    onMergeSuccess: (space, hlc) => onMerged(session, space, hlc),
  );

  /// Called for every space after each sync round of a stream; only reacts
  /// when the space's high-water mark moved on that stream.
  static Future<void> onMerged(
    Session session,
    UuidValue space,
    Hlc hlc,
  ) async {
    final marks = _lastHlc[session] ??= {};
    final key = space.uuid;
    final last = marks[key];
    if (last != null && hlc.compareTo(last) <= 0) return;
    marks[key] = hlc;
    // The Sheets signal model carries a space and an HLC; decks reuse it on
    // their own channel.
    await ClusterBus.post(
      session,
      mergedChannel(space),
      SheetsMergedSignal(spaceUuid: space, hlc: hlc.toString()),
    );
    await process(session, space);
  }

  /// Processes change-log rows that synced before the deck was registered
  /// in the drive (`drive.registerPresentation`).
  static Future<void> afterRegistration(Session session, UuidValue space) =>
      process(session, space);

  /// Runs the deck change-log consumer for [space]: inline when
  /// [processInline], else detached on an internal session.
  static Future<void> process(Session session, UuidValue space) async {
    if (processInline) {
      await DeckChangeLogProcessor.processSpace(session, space);
      return;
    }
    final serverpod = session.serverpod;
    unawaited(() async {
      final internal = await serverpod.createSession(enableLogging: false);
      try {
        await DeckChangeLogProcessor.processSpace(internal, space);
      } on Exception catch (e, st) {
        internal.log(
          'Deck change log processing of $space failed: $e',
          level: LogLevel.error,
          stackTrace: st,
        );
      } finally {
        await internal.close();
      }
    }());
  }
}
