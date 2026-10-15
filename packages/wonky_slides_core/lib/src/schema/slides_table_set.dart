import 'package:wonky_sync_kit/tables.dart';
import 'package:wonky_sync_models/tables.dart';

import 'slides_schema.dart';

/// The synced tables of Wonky Slides as a `SyncTableSet` of the shared sync
/// kit (Slides 12 §5.1–5.2): the replica, writer, change journal and
/// recovery reader of the Slides app and the server writer take it. A
/// deck's root row is its `deck` row; the change log is synced but not part
/// of the deck model.
abstract final class SlidesTableSet {
  /// The set, in dependency order.
  static final SyncTableSet tables = SyncTableSet(
    SlidesSyncedTables.all,
    nonModelTables: SlidesTables.nonModelTables,
    rootTable: SlidesTables.deck,
  );
}
