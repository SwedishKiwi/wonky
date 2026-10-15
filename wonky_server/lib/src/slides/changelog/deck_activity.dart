import 'package:wonky_slides_core/interfaces.dart' show DeckChangeLogEntry;

import '../../platform/activity/activity_service.dart';
import '../../platform/common/actor.dart';
import 'deck_change_log_processor.dart';

/// Change-log plugin `activity` (Slides 09 §5): one edit event per author
/// and 10-minute window (`ActivityService.logEdit` aggregates), with the
/// counters `changes` (change-log rows), `slides` (slides touched per
/// batch), `slidesDeleted` and `themes` (theme changes), and the set
/// `slideIds` (distinct slides of the event, SL-39).
class DeckActivity implements DeckChangeLogPlugin {
  static const pluginId = 'activity';

  @override
  String get id => pluginId;

  @override
  Future<void> consume(
    DeckConsumerContext context,
    String deckId,
    List<DeckChangeLogEntry> rows,
  ) async {
    // One logEdit per actor and batch (typing produces many rows).
    final byActor = <String, (Actor, Map<String, num>, Set<String>)>{};
    for (final row in rows) {
      final actor = await context.actorOf(row);
      if (actor == null) continue;
      final summary = DeckChangeSummaryView.parse(row.summaryJson);
      final entry = byActor.putIfAbsent(
        '${actor.userId}|${actor.kind.name}',
        () => (actor, <String, num>{}, <String>{}),
      );
      final counters = entry.$2;
      void count(String key, num n) {
        if (n == 0) return;
        counters[key] = (counters[key] ?? 0) + n;
      }

      count('changes', 1);
      entry.$3.addAll(summary.slides);
      count('slidesDeleted', summary.deleted('slides').length);
      if (summary.kinds.contains('theme')) count('themes', 1);
    }
    for (final (actor, counters, slides) in byActor.values) {
      if (slides.isNotEmpty) counters['slides'] = slides.length;
      await ActivityService.logEdit(
        context.session,
        context.item.id!,
        actor,
        counters: counters,
        // Distinct slides of the 10-minute event (09 §5; SL-39).
        sets: {if (slides.isNotEmpty) 'slideIds': slides},
      );
    }
  }
}
