import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/interfaces.dart' show DeckChangeLogEntry;

import '../../platform/common/models.dart';
import '../../platform/common/time.dart';
import '../../platform/drive/drive_events.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/versions/version_service.dart';
import '../../sheets/sync/sync_db.dart';
import 'deck_change_log_processor.dart';

/// Change-log plugin `drive` (Slides 09 §5, 02 §3.10): per author the
/// drive "last edited" state and the shared version state
/// (`ItemVersionState`, 09 §4.1), `Deck.title` → `DriveItem.name`, and
/// `modifiedAt`/search text throttled to [modifiedThrottle] per deck with
/// one trailing refresh.
class DeckDriveMirror implements DeckChangeLogPlugin {
  static const pluginId = 'drive';
  static const modifiedThrottle = Duration(seconds: 10);
  static const maxSearchText = 100000;
  static const maxSearchElements = 10000;

  @override
  String get id => pluginId;

  static final Map<String, DateTime> _lastTouch = {};
  static final Map<String, Timer> _trailing = {};

  /// Forgets the throttle state (tests).
  static void reset() {
    for (final t in _trailing.values) {
      t.cancel();
    }
    _trailing.clear();
    _lastTouch.clear();
  }

  @override
  Future<void> consume(
    DeckConsumerContext context,
    String deckId,
    List<DeckChangeLogEntry> rows,
  ) async {
    final session = context.session;
    final item = context.item;
    final authors = <int>[];
    for (final row in rows) {
      final actor = await context.actorOf(row);
      if (actor != null && !authors.contains(actor.userId)) {
        authors.add(actor.userId);
      }
    }
    for (final userId in authors) {
      await VersionService.recordEdit(session, item, userId);
      await DriveService.recordEdit(session, userId, item);
    }
    await mirrorTitle(session, item);
    final last = rows.isEmpty ? null : await context.actorOf(rows.last);
    await _touch(session, item, last?.userId);
  }

  /// `Deck.title` → `DriveItem.name` (every batch: renames are rare and must
  /// show at once). Invalid names (empty, too long, with `/`) are not
  /// mirrored.
  static Future<void> mirrorTitle(Session session, DriveItem item) async {
    final db = syncSessionOf(session);
    final deck = await Deck.db.findById(db, item.contentRef!);
    final title = deck?.title.trim();
    if (title == null ||
        title.isEmpty ||
        title.length > 255 ||
        title.contains('/')) {
      return;
    }
    final current = await DriveItem.db.findById(session, item.id!);
    if (current == null || current.name == title) return;
    final updated = await DriveItem.db.updateById(
      session,
      current.id!,
      columnValues: (t) => [t.name(title)],
    );
    if (updated != null) {
      await DriveEvents.notify(session, updated, DriveChangeKind.updated);
    }
  }

  static Future<void> _touch(
    Session session,
    DriveItem item,
    int? userId,
  ) async {
    final key = item.uuid.uuid;
    final now = nowUtc();
    final last = _lastTouch[key];
    if (last == null || now.difference(last) > modifiedThrottle) {
      _lastTouch[key] = now;
      await refreshModified(session, item, userId);
      return;
    }
    if (_trailing[key] != null) return;
    final pod = session.serverpod;
    final itemId = item.id!;
    _trailing[key] = Timer(modifiedThrottle - now.difference(last), () async {
      _trailing.remove(key);
      _lastTouch[key] = nowUtc();
      // Detached from any request: the server (or a test) may have shut
      // the database down meanwhile, which throws errors, not exceptions.
      Session? internal;
      try {
        internal = await pod.createSession(enableLogging: false);
        final fresh = await DriveItem.db.findById(internal, itemId);
        if (fresh != null) await refreshModified(internal, fresh, userId);
      } catch (e) {
        try {
          internal?.log('Trailing refresh of deck $key failed: $e');
        } catch (_) {}
      } finally {
        try {
          await internal?.close();
        } catch (_) {}
      }
    });
  }

  /// `modifiedAt` and the search text of [item].
  static Future<void> refreshModified(
    Session session,
    DriveItem item,
    int? userId,
  ) async {
    await DriveService.touchModified(
      session,
      item,
      userId,
      searchText: await searchText(session, item.contentRef!),
    );
  }

  /// The deck's search text (09 §5): title, group titles, slide text
  /// (elements and table cells of up to [maxSearchElements] rows) and
  /// speaker notes, at most [maxSearchText] characters.
  static Future<String> searchText(Session session, UuidValue deckId) async {
    final db = syncSessionOf(session);
    final out = StringBuffer();
    void add(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return;
      if (out.isNotEmpty) out.write(' ');
      out.write(t);
    }

    final deck = await Deck.db.findById(db, deckId);
    add(deck?.title);
    final groups = await SlideGroup.db.find(
      db,
      where: (t) => t.deckId.equals(deckId),
      orderBy: (t) => t.sortKey,
    );
    for (final g in groups) {
      add(g.title);
    }
    final slides = await Slide.db.find(
      db,
      where: (t) => t.deckId.equals(deckId),
      orderBy: (t) => t.sortKey,
    );
    final slideIds = {for (final s in slides) s.id};
    if (slideIds.isNotEmpty) {
      final elements = await SlideElement.db.find(
        db,
        where: (t) => t.slideId.inSet(slideIds) & t.text.notEquals(null),
        limit: maxSearchElements,
      );
      for (final e in elements) {
        add(plainText(e.text));
      }
      final tables = await SlideElement.db.find(
        db,
        where: (t) =>
            t.slideId.inSet(slideIds) & t.kind.equals(SlideElementKind.table),
        limit: maxSearchElements,
      );
      if (tables.isNotEmpty) {
        final cells = await SlideTableCell.db.find(
          db,
          where: (t) =>
              t.elementId.inSet({for (final e in tables) e.id}) &
              t.text.notEquals(null),
          limit: maxSearchElements,
        );
        for (final c in cells) {
          add(plainText(c.text));
        }
      }
    }
    for (final s in slides) {
      add(plainText(s.notes));
    }
    final text = out.toString();
    return text.length > maxSearchText
        ? text.substring(0, maxSearchText)
        : text;
  }

  /// The plain text of a Delta JSON string (02 §4.1; string inserts only).
  static String? plainText(String? delta) {
    if (delta == null) return null;
    try {
      final ops = jsonDecode(delta);
      if (ops is! List) return null;
      final out = StringBuffer();
      for (final op in ops) {
        if (op is Map && op['insert'] is String) out.write(op['insert']);
      }
      return out.toString().replaceAll('\n', ' ');
    } on FormatException {
      return null;
    }
  }
}
