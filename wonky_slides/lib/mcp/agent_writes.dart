import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart' show DeckChangeLog, Participant;

import '../features/collab/slides_collab.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/model/synced_deck_session.dart';
import '../l10n/slides_l10n.dart';
import 'agent_flash.dart';

/// Reads the deck's `DeckChangeLog` rows written at or after a time.
typedef DeckChangeLogSource =
    Future<List<DeckChangeLog>> Function(DateTime since);

/// Flashes the elements that headless agent writes touched (Slides 11 §1.3,
/// AC 5: "live editors see headless writes … with the agent flash on
/// touched elements"): when remote batches arrive, the new `DeckChangeLog`
/// rows of MCP writes (and of AI runs by other users) are read from the
/// replica and their summary's elements — or slides — flash with the
/// agent's tag ([SlidesAgentFlash]). Mirrors Sheets' `ExternalAgentWrites`.
///
/// The server also shows the agent as a participant for 5 s
/// (`DeckAgentPresence`), so its selection outline can show next to the
/// flash.
class SlidesAgentWrites {
  SlidesAgentWrites(
    this.editor, {
    DeckChangeLogSource? source,
    SlidesAgentFlash? flash,
  }) : source = source ?? _syncedSource(editor),
       flash = flash ?? SlidesAgentFlash.of(editor) {
    if (this.source == null) return;
    _since = clock.now().subtract(const Duration(seconds: 10));
    _sub = editor.session.remoteBatches.listen((_) => _schedule());
  }

  final DeckEditorController editor;
  final DeckChangeLogSource? source;
  final SlidesAgentFlash flash;

  /// Rows older than this are not flashed (offline writes synced late).
  static const maxAge = Duration(minutes: 2);

  /// Remote batches arrive in bursts: read the log once after.
  static const debounce = Duration(milliseconds: 400);

  /// Elements flashed per change at most.
  static const maxElements = 30;

  StreamSubscription<Object?>? _sub;
  Timer? _timer;
  late DateTime _since;
  final Set<String> _seen = {};
  bool _disposed = false;
  Future<void>? _running;

  static DeckChangeLogSource? _syncedSource(DeckEditorController editor) {
    final session = editor.session;
    if (session is! SyncedDeckSession) return null;
    return (since) => DeckChangeLog.db.find(
      session.host.replica.session,
      where: (t) => t.deckId.equals(session.spaceUuid) & (t.at >= since),
      limit: 200,
    );
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(poll()));
  }

  /// Reads new change-log rows and flashes the agent writes among them.
  Future<void> poll() async {
    if (_disposed || source == null) return;
    await _running;
    final run = _poll();
    _running = run;
    await run;
  }

  Future<void> _poll() async {
    List<DeckChangeLog> rows;
    try {
      rows = await source!(_since.subtract(const Duration(seconds: 5)));
    } catch (e) {
      debugPrint('Reading agent writes failed: $e');
      return;
    }
    if (_disposed) return;
    rows.sort((a, b) => a.at.compareTo(b.at));
    final now = clock.now();
    for (final r in rows) {
      if (!_seen.add(r.id.uuid)) continue;
      if (r.at.isAfter(_since)) _since = r.at;
      if (now.difference(r.at) > maxAge) continue;
      final label = labelOf(r);
      if (label == null) continue;
      _flash(r, label);
    }
    if (_seen.length > 5000) _seen.clear();
  }

  /// The tag of [r], or null when it is not an agent write to flash
  /// (user edits; the user's own AI runs, which the app previews itself).
  String? labelOf(DeckChangeLog r) {
    if (!r.sessionId.startsWith('server:')) return null;
    final own = r.userId.uuid == editor.session.userId;
    final collab = SlidesCollab.of(editor);
    final participants = collab?.session?.participants ?? const <Participant>[];
    String? name(String kind) {
      for (final p in participants) {
        if (p.userUuid.uuid == r.userId.uuid && p.actorKind.name == kind) {
          return p.displayName;
        }
      }
      return null;
    }

    final l = slidesL10nOf(editor.services);
    final user =
        name('user') ??
        (own ? editor.services.currentUser.value?.summary.displayName : null);
    switch (r.actorKind.name) {
      case 'mcp':
        return name('mcp') ?? l.actorViaMcp(user ?? 'MCP');
      case 'ai':
        if (own) return null;
        return name('ai') ?? l.actorViaAi(user ?? '…');
      default:
        return null;
    }
  }

  void _flash(DeckChangeLog r, String label) {
    Map<String, Object?> s;
    try {
      s = (jsonDecode(r.summaryJson) as Map).cast<String, Object?>();
    } on Object {
      return;
    }
    final model = editor.model;
    final elements = [
      for (final id in (s['elements'] as List? ?? const []).whereType<String>())
        if (model.element(id) != null) id,
    ];
    // Per slide (or layout/master): one highlight with its elements.
    final bySurface = <String, List<String>>{};
    for (final id in elements) {
      final owner = model.element(id)!.ownerId;
      if (owner == null) continue;
      final list = bySurface.putIfAbsent(owner, () => []);
      if (list.length < maxElements) list.add(id);
    }
    for (final MapEntry(key: surface, value: ids) in bySurface.entries) {
      flash.flash(label: label, slideId: surface, elementIds: ids);
    }
    if (bySurface.isEmpty) {
      // Slide-level changes (added slides, backgrounds, notes): outline
      // the slides.
      for (final id in (s['slides'] as List? ?? const []).whereType<String>()) {
        if (model.slide(id) != null) flash.flash(label: label, slideId: id);
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_sub?.cancel());
  }
}
