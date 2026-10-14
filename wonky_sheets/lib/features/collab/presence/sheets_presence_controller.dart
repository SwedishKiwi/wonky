import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show Participant, PresenceState;
import 'package:wonky_sheets_core/formula.dart' show CellPos, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../grid/selection/grid_selection.dart';
import '../../sheet_editor/sheet_editor_controller.dart';
import 'presence_cursor.dart';

/// A remote participant's cursor on the grid.
@immutable
class RemoteCursorView {
  const RemoteCursorView({
    required this.participant,
    required this.cursor,
    required this.movedAt,
  });

  final Participant participant;
  final SheetsPresenceCursor cursor;

  /// When the active cell last moved (the name flag shows for 3 s).
  final DateTime movedAt;

  String get sessionId => participant.sessionId;
  int get colorIndex => participant.colorIndex;
  bool get isAgent => participant.actorKind.name != 'user';
  String get displayName => participant.displayName;
}

/// Sheets presence (Sheets 10 §1.6): publishes the local selection, editing
/// state and (while followed) viewport as the `PresenceCursor` JSON through
/// the shell's [PresenceSession]; maps the other participants' cursors for
/// the grid layer, sheet tabs and avatars; jump-to and follow mode.
class SheetsPresenceController extends ChangeNotifier {
  SheetsPresenceController(this.editor) {
    editor.addListener(_onLocal);
    editor.editor.addListener(_onLocal);
    editor.scroll.addListener(_onScroll);
  }

  final SheetEditorController editor;

  /// How long a name flag stays after the cursor moved.
  static const flagDuration = Duration(seconds: 3);

  /// Viewport updates while followed (2/s).
  static const viewportInterval = Duration(milliseconds: 500);

  PresenceSession? _presence;
  SheetsPresenceCursor? _sent;
  final Map<String, RemoteCursorView> _cursors = {};
  final ValueNotifier<List<RemoteCursorView>> cursors = ValueNotifier(const []);

  /// The session we follow (Sheets 10 §1.5), or null.
  final ValueNotifier<String?> following = ValueNotifier(null);

  /// Session whose cursor flashes after a jump, and whether it is lit.
  String? flashSession;
  bool flashOn = false;
  Timer? _flash;
  Timer? _flagTimer;
  Timer? _viewportTimer;
  bool _applying = false;
  (double, double)? _followScroll;
  bool _disposed = false;

  /// Fires when cursors, flags or the flash change (grid layer repaint).
  final GridSignal repaint = GridSignal();

  PresenceSession? get presence => _presence;

  String? get selfSessionId => _presence?.sessionId;

  /// Attaches the shell's presence session (null detaches).
  void attach(PresenceSession? presence) {
    if (identical(presence, _presence)) return;
    _presence?.removeListener(_onRemote);
    if (_presence?.detailOf == _detailOf) _presence?.detailOf = null;
    _presence = presence;
    _sent = null;
    if (presence != null) {
      presence.addListener(_onRemote);
      presence.detailOf = _detailOf;
      _onRemote();
      _publish();
    } else {
      _cursors.clear();
      _emit();
    }
  }

  // ---------------------------------------------------------------- outgoing

  /// The cursor describing the local state.
  SheetsPresenceCursor localCursor({bool withViewport = false}) {
    final sel = editor.selection.selection;
    final session = editor.editor.session;
    return SheetsPresenceCursor(
      sheetId: editor.activeSheetId,
      activeRowId: sel.active.rowId.isEmpty ? null : sel.active.rowId,
      activeColId: sel.active.colId.isEmpty ? null : sel.active.colId,
      ranges: [
        for (final r in sel.ranges.take(SheetsPresenceCursor.maxRanges))
          PresenceRange(
            r1: r.kind == SelectionKind.columns || r.kind == SelectionKind.all
                ? null
                : r.r1,
            r2: r.kind == SelectionKind.columns || r.kind == SelectionKind.all
                ? null
                : r.r2,
            c1: r.kind == SelectionKind.rows || r.kind == SelectionKind.all
                ? null
                : r.c1,
            c2: r.kind == SelectionKind.rows || r.kind == SelectionKind.all
                ? null
                : r.c2,
          ),
      ],
      editing: session != null && session.sheetId == editor.activeSheetId,
      viewport: withViewport ? _viewport() : null,
      following: following.value,
    );
  }

  PresenceViewport? _viewport() {
    final s = editor.activeSheet;
    final g = editor.lastGeometry;
    if (s == null || g == null || s.rows.length == 0 || s.columns.length == 0) {
      return null;
    }
    final (top, _) = g.visibleRows;
    final (left, _) = g.visibleCols;
    final r = s.rows.tryIdAt(top);
    final c = s.columns.tryIdAt(left);
    if (r == null || c == null) return null;
    return PresenceViewport(
      topRowId: r,
      leftColId: c,
      zoom: editor.scroll.zoom,
    );
  }

  bool get _followed => (_presence?.followerCount ?? 0) > 0;

  void _publish() {
    final p = _presence;
    if (p == null || _disposed) return;
    final c = localCursor(withViewport: _followed);
    if (c == _sent) return;
    _sent = c;
    p.updateCursor(c.encode());
  }

  void _onLocal() {
    if (_disposed) return;
    if (!_applying && following.value != null) {
      // Any local selection change or sheet switch stops following.
      final sel = editor.selection.selection;
      final last = _lastSelection;
      if (last != null &&
          (last.sheetId != sel.sheetId || last.active != sel.active)) {
        unfollow();
      }
    }
    _lastSelection = editor.selection.selection;
    _publish();
  }

  GridSelection? _lastSelection;

  void _onScroll() {
    if (_disposed) return;
    final f = _followScroll;
    if (!_applying && following.value != null && f != null) {
      final dx = (editor.scroll.x - f.$1).abs();
      final dy = (editor.scroll.y - f.$2).abs();
      if (dx > 2 || dy > 2) unfollow();
    }
    if (_followed && !(_viewportTimer?.isActive ?? false)) {
      _viewportTimer = Timer(viewportInterval, _publish);
    }
  }

  // ---------------------------------------------------------------- incoming

  void _onRemote() {
    final p = _presence;
    if (p == null || _disposed) return;
    final self = p.sessionId;
    final now = DateTime.now();
    final seen = <String>{};
    for (final part in p.participants) {
      if (part.sessionId == self) continue;
      final cursor = SheetsPresenceCursor.tryParse(part.cursorJson);
      if (cursor == null) continue;
      seen.add(part.sessionId);
      final before = _cursors[part.sessionId];
      final moved =
          before == null ||
          before.cursor.activeRowId != cursor.activeRowId ||
          before.cursor.activeColId != cursor.activeColId ||
          before.cursor.sheetId != cursor.sheetId;
      _cursors[part.sessionId] = RemoteCursorView(
        participant: part,
        cursor: cursor,
        movedAt: moved ? now : before.movedAt,
      );
      if (part.sessionId == following.value) _applyFollow(cursor);
    }
    _cursors.removeWhere((k, _) => !seen.contains(k));
    final f = following.value;
    if (f != null && !p.participants.any((x) => x.sessionId == f)) unfollow();
    // The viewport is sent only while followed; the count may have changed.
    _publish();
    _emit();
  }

  void _emit() {
    if (_disposed) return;
    final list = _cursors.values.toList()
      ..sort(
        (a, b) => a.participant.joinedAt.compareTo(b.participant.joinedAt),
      );
    cursors.value = list;
    _scheduleFlagExpiry();
    repaint.fire();
    notifyListeners();
  }

  void _scheduleFlagExpiry() {
    _flagTimer?.cancel();
    final now = DateTime.now();
    Duration? next;
    for (final c in _cursors.values) {
      final left = c.movedAt.add(flagDuration).difference(now);
      if (left > Duration.zero && (next == null || left < next)) next = left;
    }
    if (next != null) {
      _flagTimer = Timer(next + const Duration(milliseconds: 20), repaint.fire);
    }
  }

  /// Cursors drawn on [sheetId]: not away, on the grid route.
  List<RemoteCursorView> cursorsOn(String sheetId) => [
    for (final c in cursors.value)
      if (c.cursor.sheetId == sheetId &&
          c.cursor.route == 'grid' &&
          c.participant.state != PresenceState.away &&
          c.participant.state != PresenceState.offline)
        c,
  ];

  /// Participants per sheet (sheet tab dots).
  Map<String, List<RemoteCursorView>> get bySheet {
    final out = <String, List<RemoteCursorView>>{};
    for (final c in cursors.value) {
      if (c.participant.state == PresenceState.offline) continue;
      out.putIfAbsent(c.cursor.sheetId, () => []).add(c);
    }
    return out;
  }

  /// Whether the name flag of [c] shows (3 s after moving, while editing,
  /// while flashing).
  bool flagVisible(RemoteCursorView c, DateTime now) =>
      c.cursor.editing ||
      now.difference(c.movedAt) < flagDuration ||
      c.sessionId == flashSession;

  // ------------------------------------------------------------ id mapping

  /// The grid rectangle of [r] on [sheet]; open bounds span the sheet, an
  /// unknown bound falls back to the known one (Sheets 10 §1.1). Null when
  /// nothing of the range is known.
  static GridRect? rectOf(SheetModel sheet, PresenceRange r) {
    final rows = sheet.rows;
    final cols = sheet.columns;
    if (rows.length == 0 || cols.length == 0) return null;
    (int, int)? span(AxisIndex axis, String? a, String? b) {
      if (a == null && b == null) return (0, axis.length - 1);
      final i = a == null ? -1 : axis.indexOf(a);
      final j = b == null ? -1 : axis.indexOf(b);
      if (i < 0 && j < 0) return null;
      final x = i < 0 ? j : i;
      final y = j < 0 ? i : j;
      return x <= y ? (x, y) : (y, x);
    }

    final rs = span(rows, r.r1, r.r2);
    final cs = span(cols, r.c1, r.c2);
    if (rs == null || cs == null) return null;
    return GridRect(rs.$1, cs.$1, rs.$2, cs.$2);
  }

  /// The active cell of [c] on [sheet] (null when unknown).
  static (int, int)? activeOf(SheetModel sheet, SheetsPresenceCursor c) {
    if (!c.hasActiveCell) return null;
    final r = sheet.rows.indexOf(c.activeRowId!);
    final col = sheet.columns.indexOf(c.activeColId!);
    if (r < 0 || col < 0) return null;
    return (r, col);
  }

  /// "Sheet1!B4" of a cursor's active cell (or the sheet name).
  String? locationOf(SheetsPresenceCursor c) {
    final sheet = editor.model.sheet(c.sheetId);
    if (sheet == null) return null;
    final a = activeOf(sheet, c);
    if (a == null) return sheet.name;
    return '${sheet.name}!${CellPos(a.$1, a.$2).a1}';
  }

  String? _detailOf(Participant p) {
    if (p.sessionId == selfSessionId) return null;
    if (p.state == PresenceState.idle ||
        p.state == PresenceState.away ||
        p.state == PresenceState.offline) {
      return null;
    }
    final c = SheetsPresenceCursor.tryParse(p.cursorJson);
    if (c == null) return null;
    final l = editor.l10n;
    final loc = locationOf(c);
    String? detail;
    if (c.route == 'script') {
      detail = l.presenceInScriptEditor;
    } else if (loc == null) {
      detail = null;
    } else if (c.editing) {
      detail = l.presenceTypingIn(loc);
    } else if (p.mode == 'viewing') {
      detail = l.presenceViewingSheet(editor.model.sheet(c.sheetId)!.name);
    } else {
      detail = l.presenceEditingCell(loc);
    }
    if (c.following != null && c.following == selfSessionId) {
      return detail == null
          ? l.presenceFollowingYou
          : '$detail · ${l.presenceFollowingYou}';
    }
    return detail;
  }

  // ------------------------------------------------------------ jump/follow

  RemoteCursorView? cursorOf(String sessionId) => _cursors[sessionId];

  /// Activates the participant's sheet, scrolls their active cell into view
  /// (no selection change) and flashes their cursor twice (Sheets 10 §1.4).
  bool jumpTo(String sessionId) {
    final c = _cursors[sessionId];
    if (c == null) return false;
    _apply(() {
      if (c.cursor.sheetId != editor.activeSheetId) {
        editor.activateSheet(c.cursor.sheetId);
      }
      final sheet = editor.activeSheet;
      final a = sheet == null ? null : activeOf(sheet, c.cursor);
      if (a != null) editor.revealCell(a.$1, a.$2);
    });
    _startFlash(sessionId);
    return true;
  }

  void _startFlash(String sessionId) {
    _flash?.cancel();
    flashSession = sessionId;
    var ticks = 0;
    flashOn = true;
    repaint.fire();
    _flash = Timer.periodic(const Duration(milliseconds: 250), (t) {
      ticks++;
      flashOn = !flashOn;
      if (ticks >= 4) {
        t.cancel();
        flashSession = null;
        flashOn = false;
      }
      repaint.fire();
    });
  }

  /// Follows [sessionId] (Sheets 10 §1.5).
  bool follow(String sessionId) {
    if (sessionId == selfSessionId || !_cursors.containsKey(sessionId)) {
      return false;
    }
    following.value = sessionId;
    _presence?.follow(sessionId);
    HardwareKeyboard.instance.addHandler(_onKey);
    _applyFollow(_cursors[sessionId]!.cursor);
    _publish();
    notifyListeners();
    return true;
  }

  /// Stops following.
  void unfollow() {
    if (following.value == null) return;
    following.value = null;
    _followScroll = null;
    _presence?.follow(null);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _publish();
    if (!_disposed) notifyListeners();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      unfollow();
    }
    return false;
  }

  void _apply(void Function() f) {
    _applying = true;
    try {
      f();
    } finally {
      _applying = false;
    }
  }

  void _applyFollow(SheetsPresenceCursor c) {
    _apply(() {
      if (c.sheetId != editor.activeSheetId &&
          editor.model.sheet(c.sheetId) != null) {
        editor.activateSheet(c.sheetId);
      }
      final sheet = editor.activeSheet;
      if (sheet == null) return;
      final v = c.viewport;
      final top = v == null ? -1 : sheet.rows.indexOf(v.topRowId);
      final left = v == null ? -1 : sheet.columns.indexOf(v.leftColId);
      if (top >= 0 && left >= 0) {
        // Align their top-left; we keep our zoom.
        final z = editor.scroll.zoom;
        final fr = sheet.record?.frozenRows ?? 0;
        final fc = sheet.record?.frozenColumns ?? 0;
        final y = (sheet.rows.offsetOf(top) - sheet.rows.offsetOf(fr)) * z;
        final x =
            (sheet.columns.offsetOf(left) - sheet.columns.offsetOf(fc)) * z;
        editor.scroll.jumpTo(x < 0 ? 0 : x, y < 0 ? 0 : y);
      } else {
        final a = activeOf(sheet, c);
        if (a != null) editor.revealCell(a.$1, a.$2);
      }
    });
    // Scroll may settle after layout; remember where we put it.
    _followScroll = (editor.scroll.x, editor.scroll.y);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (following.value != null) {
        _followScroll = (editor.scroll.x, editor.scroll.y);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    HardwareKeyboard.instance.removeHandler(_onKey);
    editor.removeListener(_onLocal);
    editor.editor.removeListener(_onLocal);
    editor.scroll.removeListener(_onScroll);
    _presence?.removeListener(_onRemote);
    if (_presence?.detailOf == _detailOf) _presence?.detailOf = null;
    _flash?.cancel();
    _flagTimer?.cancel();
    _viewportTimer?.cancel();
    cursors.dispose();
    following.dispose();
    repaint.dispose();
    super.dispose();
  }
}
