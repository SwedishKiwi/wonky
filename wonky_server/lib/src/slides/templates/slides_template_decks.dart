import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/model.dart' show SlidesText;
import 'package:wonky_slides_core/templates.dart';
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

import '../../platform/common/actor.dart';
import '../../platform/common/time.dart';
import '../spaces/deck_factory.dart';
import '../sync/server_slides_writer.dart';

/// The built-in presentation templates on the server (Slides 04 §15,
/// SL-22): the decks are the core's `SlidesTemplates` (planner operations
/// on built-in themes), written into a new deck space by
/// `drive.createPresentation(templateUuid)`; the gallery's preview text and
/// size estimate come from a preview build.
abstract final class SlidesTemplateDecks {
  static final Map<String, SlidesTemplateDeck> _previews = {};

  /// A build of [t] with fixed ids and time (previews, estimates; never
  /// written).
  static SlidesTemplateDeck preview(SlidesTemplate t) =>
      _previews[t.key] ??= t.build(
        deckId: '00000000-0000-4000-8000-000000000000',
        userId: '00000000-0000-4000-8000-000000000001',
        now: DateTime.utc(2026),
        ids: SequentialIdGenerator(1),
      );

  static final Map<String, int> _sizes = {};

  /// The pre-check size of a deck made from [t] (Drive 03 §6.5): the JSON
  /// size of its rows (the stored size is measured after creation).
  static int estimate(SlidesTemplate t) => _sizes[t.key] ??= () {
    var n = 0;
    for (final c in preview(t).inserts) {
      n += utf8
          .encode(
            jsonEncode(
              c.columnsAfter,
              toEncodable: (v) =>
                  v is DateTime ? v.toIso8601String() : v.toString(),
            ),
          )
          .length;
    }
    return n;
  }();

  /// The card text of [t]: the title slide's title as a `# ` heading line,
  /// then its subtitle (`TemplateView.previewText`, suite 05 §3.1).
  static String previewText(SlidesTemplate t) {
    final m = preview(t).model;
    final first = m.slides.first;
    final lines = <String>[];
    for (final e in m.elementsOf(first.id)) {
      final text = SlidesText.plainText(e.text).trim();
      if (text.isEmpty) continue;
      lines.add(lines.isEmpty ? '# $text' : text);
    }
    return lines.join('\n');
  }

  /// Writes the deck of [template] titled [title] into the new deck space
  /// [deckSpace] as [actor] (the creation's change-log row says "Create
  /// presentation", like a blank deck).
  static Future<void> write(
    Session session, {
    required Actor actor,
    required UuidValue deckSpace,
    required SlidesTemplate template,
    required String title,
  }) {
    final deck = template.build(
      deckId: deckSpace.uuid,
      userId: actor.authUserId.uuid,
      now: nowUtc(),
      title: title,
    );
    return ServerSlidesWriter.write(
      session,
      actor: actor,
      deckSpace: deckSpace,
      changes: deck.inserts,
      label: DeckFactory.createLabel,
      // The drive item doesn't exist yet; its registration runs it.
      consume: false,
    );
  }
}
