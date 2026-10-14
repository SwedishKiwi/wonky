import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show ChangeLog, PresenceNotice;
import 'package:wonky_sheets_core/model.dart';

import '../comments/comment_indicator_layer.dart';
import '../comments/sheets_comments.dart';
import '../history/cell_history.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../sync/synced_workbook_session.dart';
import 'hints/commit_hints.dart';
import 'hints/pending_hint_layer.dart';
import 'presence/remote_presence_layer.dart';
import 'presence/sheets_presence_controller.dart';

/// The collaboration features of one open spreadsheet editor (Sheets 10):
/// presence (cursors, tab dots, jump/follow), commit hints, comments
/// (anchors, indicators, cards), the cell history popover and remote
/// change toasts. Attached to the editor by the editor screen; found with
/// [SheetsCollab.of].
class SheetsCollab {
  SheetsCollab._(this.editor)
    : presence = SheetsPresenceController(editor),
      hints = CommitHints(editor),
      comments = SheetsComments(editor) {
    _presenceLayer = RemotePresenceLayer(
      presence,
      colors,
      typingLabel: () => editor.l10n.presenceTyping,
    );
    _commentLayer = CommentIndicatorLayer(comments);
    _pendingLayer = PendingHintLayer(
      hints,
      colors,
      (id) => presence.presence?.participants
          .where((p) => p.sessionId == id)
          .firstOrNull
          ?.colorIndex,
    );
    editor.layers
      ..add(_presenceLayer)
      ..add(_commentLayer)
      ..add(_pendingLayer);
    editor.selection.addListener(_onSelection);
    editor.onEditedCellDeleted = (s, r, c) =>
        unawaited(editedCellDeleted(s, r, c));
    comments.addListener(_openDeepLinkedComment);
    _deepLinkComment = _commentParam();
  }

  String? _deepLinkComment;

  String? _commentParam() {
    try {
      return services
          .router
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['comment'];
    } catch (_) {
      return null;
    }
  }

  /// `?comment=<threadUuid>` (Sheets 10 §3.4): activates the sheet, scrolls
  /// to the cell and opens the thread once the threads are loaded.
  void _openDeepLinkedComment() {
    final id = _deepLinkComment;
    final c = comments.controller;
    if (id == null || c == null || c.loading) return;
    _deepLinkComment = null;
    if (c.thread(id) == null) return;
    services.panels.open(ShellPanels.comments);
    c.activate(id);
  }

  static final Expando<SheetsCollab> _of = Expando('sheetsCollab');

  /// The collaboration features of [editor] (null when not attached, e.g.
  /// the read-only version grid).
  static SheetsCollab? of(SheetEditorController editor) => _of[editor];

  /// Creates the collaboration features of [editor].
  static SheetsCollab attach(
    SheetEditorController editor, {
    PresenceSession? presence,
  }) {
    final c = SheetsCollab._(editor);
    _of[editor] = c;
    c.setPresence(presence);
    return c;
  }

  final SheetEditorController editor;
  final SheetsPresenceController presence;
  final CommitHints hints;
  final SheetsComments comments;

  /// Theme colors of the layers (set by the overlay widget on build).
  final CollabPaintColors colors = CollabPaintColors();

  /// The cell whose edit history popover is open.
  final ValueNotifier<CellHistoryController?> cellHistory = ValueNotifier(null);

  /// Whether the docked thread card of the active cell is dismissed (until
  /// the active cell changes).
  final ValueNotifier<bool> dockedDismissed = ValueNotifier(false);

  late final RemotePresenceLayer _presenceLayer;
  late final CommentIndicatorLayer _commentLayer;
  late final PendingHintLayer _pendingLayer;
  StreamSubscription<PresenceNotice>? _notices;
  PresenceSession? _session;
  (String, String)? _lastActive;
  bool _disposed = false;

  ShellServices get services => editor.services;

  /// Attaches the shell's presence session of the file (null detaches).
  void setPresence(PresenceSession? session) {
    if (identical(session, _session)) return;
    _session = session;
    presence.attach(session);
    hints.attach(session);
    unawaited(_notices?.cancel());
    _notices = session?.notices.listen(_onNotice);
  }

  void _onSelection() {
    final sel = editor.selection.selection;
    final key = (sel.sheetId, '${sel.active.rowId}|${sel.active.colId}');
    if (key != _lastActive) {
      _lastActive = key;
      dockedDismissed.value = false;
      final h = cellHistory.value;
      if (h != null) {
        cellHistory.value = null;
        h.dispose();
      }
    }
  }

  void _onNotice(PresenceNotice n) {
    if (_disposed) return;
    Map<String, Object?> p;
    try {
      p = (jsonDecode(n.payloadJson) as Map).cast<String, Object?>();
    } on Object {
      p = const {};
    }
    switch (n.kind) {
      case 'versionRestored':
        if (p['userId'] == services.me?.id) return;
        services.toasts.show(
          editor.l10n.toastVersionRestoredBy('${p['name'] ?? ''}'),
        );
    }
  }

  // ------------------------------------------------- cell history popover

  /// Opens the edit history of the active cell (top-left of a merge).
  bool showCellHistory({int? row, int? col}) {
    final sheet = editor.activeSheet;
    if (sheet == null) return false;
    final sel = editor.selection.resolved;
    var r = row ?? sel.activeRow;
    var c = col ?? sel.activeCol;
    final m = sheet.mergeAt(r, c);
    if (m != null) {
      r = m.top;
      c = m.left;
    }
    final rowId = sheet.rows.tryIdAt(r);
    final colId = sheet.columns.tryIdAt(c);
    if (rowId == null || colId == null) return false;
    final old = cellHistory.value;
    cellHistory.value = cellHistoryFor(
      editor,
      CellHistoryTarget(sheet.id, rowId, colId),
    );
    old?.dispose();
    return true;
  }

  void closeCellHistory() {
    final h = cellHistory.value;
    cellHistory.value = null;
    h?.dispose();
    editor.gridFocus.requestFocus();
  }

  // ---------------------------------------------- remote change toasts

  /// "The row you were editing was deleted by Bo." (03 §15.3): looks up the
  /// deleting user in the synced change log.
  Future<void> editedCellDeleted(
    String sheetId,
    String rowId,
    String colId,
  ) async {
    final l = editor.l10n;
    String? name;
    try {
      name = await _deleterOf(sheetId, rowId, colId);
    } catch (e) {
      debugPrint('Finding who deleted the row failed: $e');
    }
    if (_disposed) return;
    services.toasts.show(
      name == null ? l.toastEditedRowDeleted : l.toastEditedRowDeletedBy(name),
    );
  }

  Future<String?> _deleterOf(String sheetId, String rowId, String colId) async {
    final session = editor.session;
    if (session is! SyncedWorkbookSession) return null;
    final logs = await ChangeLog.db.find(
      session.host.replica.session,
      where: (t) =>
          t.spreadsheetId.equals(session.spaceUuid) &
          (t.at > clock.now().subtract(const Duration(hours: 1))),
      limit: 500,
    );
    logs.sort((a, b) => b.at.compareTo(a.at));
    for (final log in logs) {
      final s = ChangeSummary.parse(log.summaryJson);
      final hit =
          (s.deleted['rows'] ?? const []).contains(rowId) ||
          (s.deleted['cols'] ?? const []).contains(colId) ||
          (s.deleted['sheets'] ?? const []).contains(sheetId);
      if (!hit) continue;
      final uuid = log.userId.uuid;
      if (uuid == session.userId) return null;
      for (final p in presence.presence?.participants ?? const []) {
        if (p.userUuid.uuid == uuid) return p.displayName;
      }
      return editor.l10n.someone;
    }
    return null;
  }

  void dispose() {
    _disposed = true;
    unawaited(_notices?.cancel());
    editor.selection.removeListener(_onSelection);
    comments.removeListener(_openDeepLinkedComment);
    editor.onEditedCellDeleted = null;
    editor.layers
      ..remove(_presenceLayer)
      ..remove(_commentLayer)
      ..remove(_pendingLayer);
    presence.dispose();
    hints.dispose();
    comments.dispose();
    cellHistory.value?.dispose();
    cellHistory.dispose();
    dockedDismissed.dispose();
    _of[editor] = null;
  }
}
