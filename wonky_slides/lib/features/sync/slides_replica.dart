import 'package:wonky_client/wonky_client.dart' show Client, UuidValue;
import 'package:wonky_slides_core/schema.dart'
    show SlidesTableSet, SlidesTables;
import 'package:wonky_sync_kit/tables.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

/// Opens the local database of a user (tests pass their own opener).
typedef SlidesReplicaOpener = Future<SlidesReplica> Function(UuidValue user);

/// The signed-in user's Slides replica: `slides_<userId>.db` with the synced
/// deck tables plus the local-only bookkeeping tables (`ReservedSpace`, the
/// dirty marks, the change journal) — Slides 02 §7, §9.1, suite 12 §2.
///
/// The shared kit's [SyncReplica] over `SlidesTableSet.tables` (root table
/// `deck`; the change log is synced but not part of the deck model). Pure
/// Dart (no Flutter): the app's `SlidesSyncController` owns one, and tests
/// open one on a temporary file. Its sync endpoint (`slidesSync.sync`, OS-8
/// filter) only delivers deck spaces and the personal space, so the file
/// never holds spreadsheets (02 §9.2).
class SlidesReplica extends SyncReplica {
  SlidesReplica(super.session, {required super.userUuid})
    : super(tables: slidesTables);

  /// Opens (creating and migrating) the replica at [path].
  static Future<SlidesReplica> open({
    required Client client,
    required String path,
    required UuidValue userUuid,
    bool isDebugMode = false,
  }) async {
    final session = await SyncReplica.openSession(
      client: client,
      path: path,
      userUuid: userUuid,
      isDebugMode: isDebugMode,
    );
    final replica = SlidesReplica(session, userUuid: userUuid);
    await replica.prepare();
    return replica;
  }

  /// The synced tables of Wonky Slides (dependency order, root `deck`).
  static SyncTableSet get slidesTables => SlidesTableSet.tables;

  /// `slides_<userId>.db`.
  static String fileNameFor(String userUuid) =>
      SyncReplica.fileName('slides', userUuid);

  /// Tables loaded into a deck model.
  static List<AnySyncedTable> get modelTables => slidesTables.modelTables;

  /// Whether the deck row of [space] is on the device (the deck arrived).
  Future<bool> hasDeck(UuidValue space) => hasRoot(space);

  /// Visible elements per deck on this device (the device cap of browsers
  /// without OPFS, suite 12 intro).
  Future<Map<UuidValue, int>> elementCountsBySpace() =>
      rowCountsBySpace(SlidesTables.slideElement);
}
