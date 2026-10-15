import 'package:wonky_slides_core/interfaces.dart' show DeckChangeLogEntry;
import 'package:wonky_sync_models/tables.dart' show SlidesSyncedTables;

import '../platform/common/models.dart';
import '../platform/storage/content_sizes.dart';
import 'changelog/deck_activity.dart';
import 'changelog/deck_change_log_processor.dart';
import 'changelog/deck_drive_mirror.dart';

/// The Slides runtime pieces of the server (Slides 12 §4 SL-5): the deck
/// size estimator for the storage counters (Drive 03 §2) and the default
/// deck change-log plugins. Idempotent; called at server start
/// (`registerSlidesHooks` in `server.dart`) and before change-log
/// processing, so tests and internal sessions get them too.
abstract final class SlidesServer {
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    ContentSizes.register(DriveItemKind.presentation, SlidesSizeEstimator());
    DeckChangeLogProcessor.register(DeckDriveMirror());
    DeckChangeLogProcessor.register(DeckActivity());
    DeckChangeLogProcessor.register(DeckStorageSize());
  }
}

/// The Slides estimator (Drive 03 §2): every synced Slides table except the
/// change log (history, like Write's op log and Sheets' change log).
class SlidesSizeEstimator extends SpaceSizeEstimator {
  SlidesSizeEstimator()
    : super([
        for (final s in SlidesSyncedTables.all)
          if (!excluded.contains(s.name)) s.name,
      ]);

  static const excluded = {'deck_change_log'};
}

/// Change-log plugin `storage`: the deck's content size for the owner's
/// storage, throttled per item ([ContentSizes.onSpaceChanged]).
class DeckStorageSize implements DeckChangeLogPlugin {
  static const pluginId = 'storage';

  @override
  String get id => pluginId;

  @override
  Future<void> consume(
    DeckConsumerContext context,
    String deckId,
    List<DeckChangeLogEntry> rows,
  ) => ContentSizes.onSpaceChanged(context.session, context.item);
}
