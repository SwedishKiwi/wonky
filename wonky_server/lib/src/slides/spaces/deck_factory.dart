import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart' show SlidesPlanner;
import 'package:wonky_slides_core/themes.dart' show BuiltInThemes;
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_models/ids.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/time.dart';
import '../sync/server_slides_writer.dart';

/// Creates deck content server-side in a deck space (Slides 02 §9.3): the
/// rows of the planner's `CreateDeck` — the `deck` row (id = space), a
/// copy of a built-in theme with the deterministic ids of 02 §2.1 and one
/// slide with layout `title` and its placeholder instances — plus a
/// `DeckChangeLog` row ("Create presentation"), written through
/// [ServerSlidesWriter]. The same rows a client writes offline (SL-9).
abstract final class DeckFactory {
  /// The label of the creation's change-log row.
  static const createLabel = 'Create presentation';

  /// The rows of a new deck as inserts (dependency order).
  static List<RowChange> rows({
    required UuidValue deckSpace,
    required UuidValue authorUuid,
    required String title,
    String themeKey = BuiltInThemes.defaultKey,
    String? firstLayoutKey = 'title',
    IdGenerator ids = const UuidV7IdGenerator(),
    DateTime? now,
  }) {
    if (BuiltInThemes.byKey(themeKey) == null) {
      throw Errors.invalid('Unknown theme "$themeKey".');
    }
    try {
      final plan = const SlidesPlanner().plan(
        CreateDeck(
          deckId: deckSpace.uuid,
          title: title,
          themeKey: themeKey,
          firstLayoutKey: firstLayoutKey,
        ),
        DeckModel(deckId: deckSpace.uuid),
        SlidesPlanContext(
          userId: authorUuid.uuid,
          now: now ?? nowUtc(),
          ids: ids,
          isOwner: true,
        ),
      );
      return plan.changes;
    } on PlanException catch (e) {
      throw Errors.invalid(e.message);
    }
  }

  /// Writes a new deck into [deckSpace] as [actor] (a readWrite member).
  static Future<void> write(
    Session session, {
    required Actor actor,
    required UuidValue deckSpace,
    required String title,
    String themeKey = BuiltInThemes.defaultKey,
  }) => ServerSlidesWriter.write(
    session,
    actor: actor,
    deckSpace: deckSpace,
    changes: rows(
      deckSpace: deckSpace,
      authorUuid: actor.authUserId,
      title: title,
      themeKey: themeKey,
    ),
    label: createLabel,
    // The drive item may not exist yet; its registration runs the consumer.
    consume: false,
  );
}
