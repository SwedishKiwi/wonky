import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show CommentAnchorKind, CommentStatus, CommentThreadView;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/formula.dart' show CellPos, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../grid/selection/grid_selection.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'comment_anchor_moves.dart';

/// A Sheets comment anchor (Sheets 10 §3.1): a cell or a range by ids.
@immutable
class SheetsCommentAnchor {
  const SheetsCommentAnchor({
    required this.sheetId,
    required this.r1,
    required this.c1,
    String? r2,
    String? c2,
  }) : r2 = r2 ?? r1,
       c2 = c2 ?? c1;

  final String sheetId;
  final String r1;
  final String c1;
  final String r2;
  final String c2;

  bool get isCell => r1 == r2 && c1 == c2;

  CommentAnchorKind get kind =>
      isCell ? CommentAnchorKind.cell : CommentAnchorKind.range;

  String encode() => jsonEncode(
    isCell
        ? {'v': 1, 'sheetId': sheetId, 'rowId': r1, 'colId': c1}
        : {
            'v': 1,
            'range': {'s': sheetId, 'r1': r1, 'c1': c1, 'r2': r2, 'c2': c2},
          },
  );

  /// Parses `anchorJson` of a cell/range thread (null for other kinds).
  static SheetsCommentAnchor? parse(CommentAnchorKind kind, String json) {
    if (kind != CommentAnchorKind.cell && kind != CommentAnchorKind.range) {
      return null;
    }
    try {
      final j = jsonDecode(json);
      if (j is! Map) return null;
      final range = j['range'];
      if (range is Map) {
        final s = range['s'];
        final ids = [range['r1'], range['c1'], range['r2'], range['c2']];
        if (s is! String || ids.any((x) => x is! String)) return null;
        return SheetsCommentAnchor(
          sheetId: s,
          r1: ids[0]! as String,
          c1: ids[1]! as String,
          r2: ids[2]! as String,
          c2: ids[3]! as String,
        );
      }
      final s = j['sheetId'];
      final r = j['rowId'];
      final c = j['colId'];
      if (s is! String || r is! String || c is! String) return null;
      return SheetsCommentAnchor(sheetId: s, r1: r, c1: c);
    } on FormatException {
      return null;
    }
  }

  /// The anchor's rectangle on [model] (null when its row, column or sheet
  /// is gone: the thread is orphaned or about to be).
  GridRect? resolve(WorkbookModel model) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return null;
    final a = sheet.rows.indexOf(r1);
    final b = sheet.rows.indexOf(r2);
    final c = sheet.columns.indexOf(c1);
    final d = sheet.columns.indexOf(c2);
    if (a < 0 || b < 0 || c < 0 || d < 0) return null;
    return GridRect.normalized(a, c, b, d);
  }
}

/// A thread placed on the grid.
@immutable
class PlacedThread {
  const PlacedThread(this.thread, this.anchor, this.rect);

  final CommentThreadView thread;
  final SheetsCommentAnchor anchor;
  final GridRect rect;

  /// The indicator cell: the range's top-right cell.
  (int, int) get indicator => (rect.top, rect.right);
}

/// Sheets' side of comments (Sheets 10 §3): the `CommentAnchorProvider` of
/// the shell's comments controller (anchors from the selection, labels
/// "Sheet1!B4" computed live from ids, position sort, reveal), and the
/// index of open threads per sheet for the indicator layer, hover cards,
/// next/previous and the docked card.
class SheetsComments extends ChangeNotifier
    implements CommentAnchorProvider, CommentPanelOptions {
  SheetsComments(this.editor) {
    services.comments.addListener(_onControllerChanged);
    editor.model.addListener(_onModel);
    editor.addListener(_onEditor);
    _activeSheet = editor.activeSheetId;
    _onControllerChanged();
    moves = CommentAnchorMoves(this);
  }

  /// Comments moving with cut cells (Sheets 10 §3.2).
  late final CommentAnchorMoves moves;

  String? _activeSheet;

  /// The *This sheet* scope follows the active sheet.
  void _onEditor() {
    if (_activeSheet == editor.activeSheetId) return;
    _activeSheet = editor.activeSheetId;
    final c = _controller;
    if (c != null && c.scope == scopeSheet) c.setScope(scopeSheet);
  }

  /// Comment panel scopes (Sheets 10 §3.5).
  static const scopeSheet = 'sheet';
  static const scopeAll = 'all';

  final SheetEditorController editor;

  ShellServices get services => editor.services;

  CommentsController? _controller;
  Map<String, List<PlacedThread>>? _bySheet;
  bool _disposed = false;

  /// Whether comment indicators are shown (View › Comments ›
  /// Hide comment indicators).
  bool indicatorsOn = true;

  /// Shows or hides the comment indicators (view state, not undoable).
  void setIndicators(bool on) {
    if (on == indicatorsOn) return;
    indicatorsOn = on;
    _onThreads();
  }

  /// Fires when indicators change (grid repaint).
  final GridSignal repaint = GridSignal();

  CommentsController? get controller => _controller;

  WorkbookModel get model => editor.model;

  void _onControllerChanged() {
    final c = services.comments.value;
    final next = c != null && c.itemUuid == editor.session.itemUuid ? c : null;
    if (next != _controller) {
      _controller?.removeListener(_onThreads);
      _controller = next;
      next?.addListener(_onThreads);
      if (next != null) {
        next.anchors = this;
        // Offline comments are queued (Sheets 10 §3.7).
        next.queueOffline = true;
      }
    }
    _onThreads();
  }

  void _onThreads() {
    _bySheet = null;
    if (_disposed) return;
    repaint.fire();
    notifyListeners();
  }

  void _onModel(WorkbookChangeBatch batch) {
    if (batch.whereType<StructureChanged>().isNotEmpty ||
        batch.whereType<SheetsChanged>().isNotEmpty) {
      _onThreads();
    }
  }

  /// Whether the user may see comments (viewers only when the owner allows
  /// it, suite 06).
  bool get visible {
    final item = services.currentItem.value;
    final role = editor.itemRole;
    return role.canComment || (item?.viewersSeeComments ?? false);
  }

  bool get canComment => editor.itemRole >= Role.commenter;

  /// Open threads with a resolvable anchor, per sheet.
  Map<String, List<PlacedThread>> get bySheet => _bySheet ??= _index();

  Map<String, List<PlacedThread>> _index() {
    final out = <String, List<PlacedThread>>{};
    for (final t in _controller?.threads ?? const <CommentThreadView>[]) {
      if (t.status != CommentStatus.open) continue;
      final a = SheetsCommentAnchor.parse(t.anchorKind, t.anchorJson);
      if (a == null) continue;
      final rect = a.resolve(model);
      if (rect == null) continue;
      out.putIfAbsent(a.sheetId, () => []).add(PlacedThread(t, a, rect));
    }
    for (final list in out.values) {
      list.sort((x, y) {
        final r = x.rect.top.compareTo(y.rect.top);
        return r != 0 ? r : x.rect.left.compareTo(y.rect.left);
      });
    }
    return out;
  }

  /// Open threads whose indicator is at (row, col) of [sheetId].
  List<PlacedThread> threadsAt(String sheetId, int row, int col) => [
    for (final p in bySheet[sheetId] ?? const <PlacedThread>[])
      if (p.indicator == (row, col) ||
          (p.rect.isSingleCell && p.rect.top == row && p.rect.left == col))
        p,
  ];

  /// Open threads covering (row, col) (the active cell's threads).
  List<PlacedThread> threadsCovering(String sheetId, int row, int col) => [
    for (final p in bySheet[sheetId] ?? const <PlacedThread>[])
      if (p.rect.contains(row, col)) p,
  ];

  /// Open threads in reading order (sheet order, row, column).
  List<PlacedThread> get readingOrder => [
    for (final s in model.sheets)
      if (!(s.record?.hidden ?? false)) ...?bySheet[s.id],
  ];

  // ------------------------------------------------- CommentAnchorProvider

  @override
  NewCommentAnchor? anchorForSelection() {
    if (!canComment) return null;
    final sheet = editor.activeSheet;
    if (sheet == null || sheet.rows.length == 0) return null;
    final sel = editor.selection.resolved;
    final range = sel.activeRange;
    var rect = range.rect;
    final merge = sheet.mergeAt(sel.activeRow, sel.activeCol);
    final single =
        sel.ranges.length > 1 ||
        range.kind != SelectionKind.cells ||
        rect.isSingleCell ||
        merge == rect;
    if (single) {
      rect = GridRect.cell(
        merge?.top ?? sel.activeRow,
        merge?.left ?? sel.activeCol,
      );
    }
    final anchor = SheetsCommentAnchor(
      sheetId: sheet.id,
      r1: sheet.rows.idAt(rect.top),
      c1: sheet.columns.idAt(rect.left),
      r2: sheet.rows.idAt(rect.bottom),
      c2: sheet.columns.idAt(rect.right),
    );
    final a1 = rect.isSingleCell ? CellPos(rect.top, rect.left).a1 : rect.a1;
    final quoted = rect.isSingleCell
        ? editor.cells.displayAt(sheet.id, rect.top, rect.left)?.text
        : a1;
    return NewCommentAnchor(
      kind: anchor.kind,
      anchorJson: anchor.encode(),
      quotedText: quoted == null || quoted.isEmpty ? null : quoted,
      label: '${sheet.name}!$a1',
    );
  }

  /// "Sheet1!B4" of [t] from its ids (null when not resolvable).
  String? referenceOf(CommentThreadView t) {
    final a = SheetsCommentAnchor.parse(t.anchorKind, t.anchorJson);
    if (a == null) return null;
    final rect = a.resolve(model);
    final sheet = model.sheet(a.sheetId);
    if (rect == null || sheet == null) return null;
    final a1 = rect.isSingleCell ? CellPos(rect.top, rect.left).a1 : rect.a1;
    return '${sheet.name}!$a1';
  }

  @override
  String? labelFor(CommentThreadView thread) {
    final ref = referenceOf(thread);
    final q = thread.quotedText;
    if (ref == null) {
      return thread.status == CommentStatus.orphaned ||
              SheetsCommentAnchor.parse(thread.anchorKind, thread.anchorJson) !=
                  null
          ? editor.l10n.commentAnchorDeleted(q ?? '')
          : q;
    }
    return q == null || q.isEmpty || q == ref ? ref : '$ref · $q';
  }

  @override
  num positionOf(CommentThreadView thread) {
    final a = SheetsCommentAnchor.parse(thread.anchorKind, thread.anchorJson);
    if (a == null) return double.maxFinite;
    final rect = a.resolve(model);
    final sheets = model.sheets;
    final si = sheets.indexWhere((s) => s.id == a.sheetId);
    if (rect == null || si < 0) return double.maxFinite;
    return si * 1e13 + rect.top * 1e5 + rect.left;
  }

  @override
  void reveal(CommentThreadView thread) {
    final a = SheetsCommentAnchor.parse(thread.anchorKind, thread.anchorJson);
    if (a == null) return;
    final rect = a.resolve(model);
    if (rect == null) return;
    if (a.sheetId != editor.activeSheetId) editor.activateSheet(a.sheetId);
    editor.selection.selectCell(rect.top, rect.left);
    if (!rect.isSingleCell) editor.selection.extendTo(rect.bottom, rect.right);
    editor.revealCell(rect.top, rect.left);
  }

  @override
  bool get composesInline => true;

  @override
  Map<String, String> get scopes => {
    scopeSheet: editor.l10n.commentsScopeSheet,
    scopeAll: editor.l10n.commentsScopeAll,
  };

  @override
  String? get defaultScope => scopeAll;

  @override
  bool inScope(CommentThreadView thread, String scope) {
    if (scope != scopeSheet) return true;
    final a = SheetsCommentAnchor.parse(thread.anchorKind, thread.anchorJson);
    return a != null &&
        a.sheetId == editor.activeSheetId &&
        a.resolve(model) != null;
  }

  @override
  String? groupOf(CommentThreadView thread) {
    final a = SheetsCommentAnchor.parse(thread.anchorKind, thread.anchorJson);
    if (a == null) return null;
    final sheet = model.sheet(a.sheetId);
    if (sheet == null || a.resolve(model) == null) {
      return editor.l10n.commentsOrphanedGroup;
    }
    return sheet.name;
  }

  @override
  void onThreadCreated(CommentThreadView thread) => _onThreads();

  @override
  void onThreadDeleted(CommentThreadView thread) => _onThreads();

  @override
  String? get activeThreadUuid {
    final sel = editor.selection.resolved;
    final list = threadsCovering(
      editor.activeSheetId,
      sel.activeRow,
      sel.activeCol,
    );
    return list.isEmpty ? null : list.first.thread.uuid.uuid;
  }

  // ----------------------------------------------------- next / previous

  /// The next (or previous) open thread after the active cell in reading
  /// order, wrapping around (Sheets 10 §3.4).
  PlacedThread? neighbor({required bool forward}) {
    final list = readingOrder;
    if (list.isEmpty) return null;
    final order = [for (final s in model.sheets) s.id];
    final sel = editor.selection.resolved;
    final here = (
      order.indexOf(editor.activeSheetId),
      sel.activeRow,
      sel.activeCol,
    );
    int cmp(PlacedThread p) {
      final k = (order.indexOf(p.anchor.sheetId), p.rect.top, p.rect.left);
      if (k.$1 != here.$1) return k.$1.compareTo(here.$1);
      if (k.$2 != here.$2) return k.$2.compareTo(here.$2);
      return k.$3.compareTo(here.$3);
    }

    if (forward) {
      return list.where((p) => cmp(p) > 0).firstOrNull ?? list.first;
    }
    return list.reversed.where((p) => cmp(p) < 0).firstOrNull ?? list.last;
  }

  @override
  void dispose() {
    _disposed = true;
    moves.dispose();
    editor.removeListener(_onEditor);
    services.comments.removeListener(_onControllerChanged);
    editor.model.removeListener(_onModel);
    _controller?.removeListener(_onThreads);
    if (_controller?.anchors == this) _controller?.anchors = null;
    repaint.dispose();
    super.dispose();
  }
}
