import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/interfaces.dart' show DeckChangeLogEntry;
import 'package:wonky_slides_core/model.dart'
    show DeckModelIndexes, DeckReader, SlidesText;
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../../platform/comments/comment_service.dart';
import '../../platform/common/models.dart';
import '../headless/headless_deck_cache.dart';
import 'deck_change_log_processor.dart';

/// The ids of a Slides comment anchor (Slides 09 §3.1): `slide` anchors
/// `{"v":1,"slideId":…}`, `element` anchors `{"v":1,"slideId":…,
/// "elementId":…}` — the element id is authoritative, the slide id a hint.
final class DeckCommentAnchorIds {
  const DeckCommentAnchorIds({this.slideId, this.elementId});

  /// Parses a slide or element anchor (null for other kinds and malformed
  /// JSON).
  static DeckCommentAnchorIds? of(CommentAnchorKind kind, String json) {
    if (kind != CommentAnchorKind.slide && kind != CommentAnchorKind.element) {
      return null;
    }
    try {
      final j = jsonDecode(json);
      if (j is! Map) return null;
      final slide = j['slideId'];
      final element = j['elementId'];
      return DeckCommentAnchorIds(
        slideId: slide is String ? slide : null,
        elementId: kind == CommentAnchorKind.element && element is String
            ? element
            : null,
      );
    } on FormatException {
      return null;
    }
  }

  final String? slideId;
  final String? elementId;
}

/// Change-log plugin `comments` (Slides 09 §3.2): open threads anchored to
/// a deleted slide or element become `orphaned` (`orphanReasonJson {kind:
/// slide|element, id, changeLogId}`); when the deletion is undone (the ids
/// come back in `summaryJson.revived`) the previous status is restored.
/// Element anchors orphan on the element's deletion (the element id is
/// authoritative: an element moved to another slide survives that slide);
/// the reason says `slide` when its slide went with it.
class DeckCommentOrphans implements DeckChangeLogPlugin {
  static const pluginId = 'comments';

  @override
  String get id => pluginId;

  @override
  Future<void> consume(
    DeckConsumerContext context,
    String deckId,
    List<DeckChangeLogEntry> rows,
  ) async {
    final session = context.session;
    final item = context.item;
    for (final row in rows) {
      final summary = DeckChangeSummaryView.parse(row.summaryJson);
      final deletedSlides = summary.deleted('slides').toSet();
      final deletedElements = summary.deleted('elements').toSet();
      final revived = {
        ...summary.revived('slides'),
        ...summary.revived('elements'),
      };
      if (deletedSlides.isEmpty && deletedElements.isEmpty && revived.isEmpty) {
        continue;
      }
      final threads = await CommentThread.db.find(
        session,
        where: (t) =>
            t.itemId.equals(item.id!) &
            t.anchorKind.inSet({
              CommentAnchorKind.slide,
              CommentAnchorKind.element,
            }),
      );
      for (final thread in threads) {
        if (thread.status == CommentStatus.orphaned) {
          final reason = _reasonId(thread.orphanReasonJson);
          if (reason != null && revived.contains(reason)) {
            await CommentService.revive(session, thread, item);
          }
          continue;
        }
        final a = DeckCommentAnchorIds.of(thread.anchorKind, thread.anchorJson);
        if (a == null) continue;
        final element = a.elementId;
        final (String, String)? reason;
        if (element != null) {
          reason = !deletedElements.contains(element)
              ? null
              : a.slideId != null && deletedSlides.contains(a.slideId)
              ? ('slide', a.slideId!)
              : ('element', element);
        } else {
          reason = a.slideId != null && deletedSlides.contains(a.slideId)
              ? ('slide', a.slideId!)
              : null;
        }
        if (reason == null) continue;
        await CommentService.orphan(
          session,
          thread,
          item,
          reason: {'kind': reason.$1, 'id': reason.$2, 'changeLogId': row.id},
        );
      }
    }
  }

  static String? _reasonId(String? json) {
    if (json == null) return null;
    try {
      final j = jsonDecode(json);
      return j is Map && j['id'] is String ? j['id'] as String : null;
    } on FormatException {
      return null;
    }
  }
}

/// Notification payload extras of deck comments (Slides 09 §3.6):
/// `slideNumber` (1-based, presentation order) and `slideTitle` of the
/// anchor's slide (the element's current slide for element anchors), from
/// the server's deck cache. Empty for other anchors or unresolvable ones.
abstract final class DeckCommentPayload {
  static Future<Map<String, Object?>> extras(
    Session session,
    DriveItem item,
    CommentThread thread,
  ) async {
    final a = DeckCommentAnchorIds.of(thread.anchorKind, thread.anchorJson);
    final space = item.contentRef;
    if (a == null || space == null) return const {};
    final deck = (await HeadlessDeckCache.open(session, space)).model;
    final elementSlide = a.elementId == null
        ? null
        : deck.element(a.elementId!)?.slideId;
    final slideId = elementSlide ?? a.slideId;
    if (slideId == null) return const {};
    final index = deck.indexes.order.indexOf(slideId);
    if (index < 0) return const {};
    return {'slideNumber': index + 1, 'slideTitle': titleOf(deck, slideId)};
  }

  /// The plain text of [slideId]'s title placeholder ('' without one).
  static String titleOf(DeckReader deck, String slideId) {
    for (final e in deck.elementsOf(slideId)) {
      if (e.placeholderType == SlidePlaceholderType.title) {
        return SlidesText.plainText(e.text).trim();
      }
    }
    return '';
  }
}
