import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show PresenceHints;
import 'package:wonky_sheets_core/formula.dart' show FValue, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../sheet_editor/sheet_editor_controller.dart';

/// A cell value received as a commit hint (Sheets 10 §2.2).
class HintedCell {
  HintedCell({
    required this.sessionId,
    required this.content,
    required this.value,
    required this.hlcMillis,
    required this.receivedAt,
  });

  final String sessionId;

  /// Stored-form content (null = cleared).
  final String? content;

  /// What the grid shows.
  final FValue value;
  final int hlcMillis;
  final DateTime receivedAt;
}

/// A range that is about to change (big pastes, structure, formats).
class PendingHint {
  PendingHint({
    required this.sessionId,
    required this.sheetId,
    required this.range,
    required this.receivedAt,
  });

  final String sessionId;
  final String sheetId;
  final PresenceRangeIds range;
  final DateTime receivedAt;
}

/// Range bounds by ids.
typedef PresenceRangeIds = ({String r1, String c1, String r2, String c2});

/// Ephemeral commit hints (Sheets 10 §2): [CommitHints] sends the cells of
/// local commits over the presence stream ([CommitHintSender] part) and
/// shows the hints of others until the synced rows arrive or 5 s pass
/// (`CommitHintOverlay` part, hooked into `CellRenderCache.hinted`).
class CommitHints {
  CommitHints(this.editor) {
    editor.model.addListener(_onBatch);
    _remote = editor.session.remoteBatches.listen(_onRemote);
    editor.cells.hinted = _hintedAt;
    editor.editor.text.addListener(_onTypingText);
  }

  /// Receives `typing` hints (live typing preview, Sheets 10 §2.1, P2).
  void Function(
    String sessionId, {
    required String sheetId,
    required String rowId,
    required String colId,
    required String? text,
  })?
  onTyping;

  /// Typing previews are sent at most this often (4/s).
  static const typingInterval = Duration(milliseconds: 250);

  /// Max characters of a typing preview.
  static const typingMaxChars = 200;

  Timer? _typingTimer;
  String? _typingSent;

  void _onTypingText() {
    if (_disposed || _presence == null || !editor.roleCanEdit) return;
    if (_typingTimer?.isActive ?? false) return;
    _sendTyping();
    _typingTimer = Timer(typingInterval, _sendTyping);
  }

  /// Sends the cell editor's current text as a `typing` hint (when it
  /// changed since the last one).
  void _sendTyping() {
    final p = _presence;
    final s = editor.editor.session;
    if (_disposed || p == null || s == null) {
      _typingSent = null;
      return;
    }
    var text = editor.editor.text.text;
    if (text.length > typingMaxChars) {
      text = text.substring(0, typingMaxChars);
    }
    final key = '${s.sheetId}|${s.rowId}|${s.colId}|$text';
    if (key == _typingSent) return;
    _typingSent = key;
    p.sendHints([
      jsonEncode({
        't': 'typing',
        'sheetId': s.sheetId,
        'rowId': s.rowId,
        'colId': s.colId,
        'text': text,
      }),
    ]);
  }

  final SheetEditorController editor;

  /// Max cells per hint message; bigger commits send a `pending` hint.
  static const maxCells = 500;

  /// Hints older than this are dropped.
  static const lifetime = Duration(seconds: 5);

  PresenceSession? _presence;
  StreamSubscription<PresenceHints>? _hintsSub;
  StreamSubscription<WorkbookChangeBatch>? _remote;
  final List<WorkbookChangeBatch> _pending = [];
  final Set<WorkbookChangeBatch> _remoteBatches = Set.identity();
  bool _scheduled = false;
  Timer? _expiry;
  bool _disposed = false;

  /// `sheetId|rowId|colId` → hint.
  final Map<String, HintedCell> cells = {};

  /// Pending ranges (shimmer).
  final List<PendingHint> pending = [];

  /// Sent hint messages (tests, diagnostics).
  int sent = 0;

  void attach(PresenceSession? presence) {
    if (identical(presence, _presence)) return;
    unawaited(_hintsSub?.cancel());
    _hintsSub = null;
    _presence?.removeListener(_onRoster);
    _presence = presence;
    if (presence != null) {
      _hintsSub = presence.hints.listen(receive);
      presence.addListener(_onRoster);
    }
  }

  static String key(String sheetId, String rowId, String colId) =>
      '$sheetId|$rowId|$colId';

  // ------------------------------------------------------------------ send

  void _onBatch(WorkbookChangeBatch batch) {
    if (_disposed || batch.isEmpty) return;
    _pending.add(batch);
    if (_scheduled) return;
    _scheduled = true;
    // Remote batches are announced on `remoteBatches` right after they are
    // applied (delivered in a microtask); decide after those ran.
    Timer.run(_flushLocal);
  }

  void _onRemote(WorkbookChangeBatch batch) {
    _remoteBatches.add(batch);
    _dropSynced(batch);
  }

  void _flushLocal() {
    _scheduled = false;
    final batches = List.of(_pending);
    _pending.clear();
    final local = [
      for (final b in batches)
        if (!_remoteBatches.contains(b)) b,
    ];
    _remoteBatches.clear();
    if (local.isEmpty || _disposed) return;
    // A local edit to a hinted cell wins.
    var dropped = false;
    for (final b in local) {
      for (final e in b.whereType<CellsChanged>()) {
        for (final k in e.contentKeys) {
          dropped |= cells.remove(key(e.sheetId, k.rowId, k.colId)) != null;
        }
      }
    }
    if (dropped) _refresh();
    final hints = buildHints(local);
    if (hints.isEmpty) return;
    final p = _presence;
    if (p == null || !editor.roleCanEdit) return;
    p.sendHints(hints);
    sent += hints.length;
  }

  /// Hint JSON messages for local [batches] (one per sheet; `pending` for
  /// commits of more than [maxCells] cells).
  List<String> buildHints(List<WorkbookChangeBatch> batches) {
    final bySheet = <String, Set<CellKey>>{};
    for (final b in batches) {
      for (final e in b.whereType<CellsChanged>()) {
        if (e.contentKeys.isEmpty) continue;
        bySheet.putIfAbsent(e.sheetId, () => {}).addAll(e.contentKeys);
      }
    }
    final now = clock.now().millisecondsSinceEpoch;
    final out = <String>[];
    for (final entry in bySheet.entries) {
      final sheet = editor.model.sheet(entry.key);
      if (sheet == null) continue;
      final keys = entry.value;
      if (keys.length > maxCells) {
        final rect = _bounds(sheet, keys);
        if (rect == null) continue;
        out.add(
          jsonEncode({
            't': 'pending',
            'sheetId': entry.key,
            'range': {
              'r1': sheet.rows.idAt(rect.top),
              'c1': sheet.columns.idAt(rect.left),
              'r2': sheet.rows.idAt(rect.bottom),
              'c2': sheet.columns.idAt(rect.right),
            },
            'kind': 'values',
            'hlcMillis': now,
          }),
        );
        continue;
      }
      final list = <Map<String, Object?>>[];
      for (final k in keys) {
        final row = sheet.rows.indexOf(k.rowId);
        final col = sheet.columns.indexOf(k.colId);
        if (row < 0 || col < 0) continue;
        final content = sheet.cellAt(row, col)?.content;
        final decoded = CellContent.decode(content);
        String? value;
        if (decoded is FormulaContent) {
          value = CellContent.fromValue(
            editor.engine.valueAt(entry.key, row, col).toCellValue(),
          )?.encode();
        }
        list.add({
          'rowId': k.rowId,
          'colId': k.colId,
          'content': content,
          'v': ?value,
        });
      }
      if (list.isEmpty) continue;
      if (list.length == 1) {
        out.add(
          jsonEncode({
            't': 'cell',
            'sheetId': entry.key,
            ...list.single,
            'hlcMillis': now,
          }),
        );
      } else {
        out.add(
          jsonEncode({
            't': 'range',
            'sheetId': entry.key,
            'cells': list,
            'hlcMillis': now,
          }),
        );
      }
    }
    return out;
  }

  static GridRect? _bounds(SheetModel sheet, Set<CellKey> keys) {
    int? t, l, b, r;
    for (final k in keys) {
      final row = sheet.rows.indexOf(k.rowId);
      final col = sheet.columns.indexOf(k.colId);
      if (row < 0 || col < 0) continue;
      t = t == null || row < t ? row : t;
      b = b == null || row > b ? row : b;
      l = l == null || col < l ? col : l;
      r = r == null || col > r ? col : r;
    }
    return t == null ? null : GridRect(t, l!, b!, r!);
  }

  // --------------------------------------------------------------- receive

  /// Applies hints relayed from another participant.
  void receive(PresenceHints e) {
    if (_disposed) return;
    final now = clock.now();
    var changed = false;
    for (final raw in e.hints) {
      Object? j;
      try {
        j = jsonDecode(raw);
      } on FormatException {
        continue;
      }
      if (j is! Map) continue;
      final sheetId = j['sheetId'];
      if (sheetId is! String || editor.model.sheet(sheetId) == null) continue;
      final hlc = j['hlcMillis'] is int ? j['hlcMillis'] as int : 0;
      switch (j['t']) {
        case 'cell':
          changed |= _put(e.sessionId, sheetId, j, hlc, now);
        case 'range':
          final list = j['cells'];
          if (list is! List) continue;
          for (final c in list.take(maxCells)) {
            if (c is Map) changed |= _put(e.sessionId, sheetId, c, hlc, now);
          }
        case 'typing':
          final rowId = j['rowId'];
          final colId = j['colId'];
          if (rowId is! String || colId is! String) continue;
          final text = j['text'];
          onTyping?.call(
            e.sessionId,
            sheetId: sheetId,
            rowId: rowId,
            colId: colId,
            text: text is String ? text : null,
          );
        case 'pending':
          final r = j['range'];
          if (r is! Map) continue;
          final ids = [r['r1'], r['c1'], r['r2'], r['c2']];
          if (ids.any((x) => x is! String)) continue;
          pending.add(
            PendingHint(
              sessionId: e.sessionId,
              sheetId: sheetId,
              range: (
                r1: ids[0]! as String,
                c1: ids[1]! as String,
                r2: ids[2]! as String,
                c2: ids[3]! as String,
              ),
              receivedAt: now,
            ),
          );
          changed = true;
      }
    }
    if (changed) {
      _refresh();
      _scheduleExpiry();
    }
  }

  bool _put(String session, String sheetId, Map j, int hlc, DateTime now) {
    final rowId = j['rowId'];
    final colId = j['colId'];
    if (rowId is! String || colId is! String) return false;
    final sheet = editor.model.sheet(sheetId)!;
    // Unknown ids (rows the sender created that haven't synced) are ignored.
    if (!sheet.rows.contains(rowId) || !sheet.columns.contains(colId)) {
      return false;
    }
    final content = j['content'] is String ? j['content'] as String : null;
    final shown = j['v'] is String
        ? j['v'] as String
        : (CellContent.decode(content) is FormulaContent ? null : content);
    final decoded = CellContent.decode(shown);
    if (shown != null && decoded == null) return false;
    // Formulas without a sent value can't be shown yet.
    if (content != null && shown == null) return false;
    final value = decoded?.literalValue ?? const EmptyValue();
    cells[key(sheetId, rowId, colId)] = HintedCell(
      sessionId: session,
      content: content,
      value: value.toFValue(),
      hlcMillis: hlc,
      receivedAt: now,
    );
    return true;
  }

  void _dropSynced(WorkbookChangeBatch batch) {
    var changed = false;
    for (final e in batch.whereType<CellsChanged>()) {
      for (final k in e.contentKeys) {
        changed |= cells.remove(key(e.sheetId, k.rowId, k.colId)) != null;
      }
      if (pending.isNotEmpty && e.contentKeys.isNotEmpty) {
        final before = pending.length;
        pending.removeWhere((p) => p.sheetId == e.sheetId);
        changed |= before != pending.length;
      }
    }
    if (pending.isNotEmpty && batch.whereType<StructureChanged>().isNotEmpty) {
      pending.clear();
      changed = true;
    }
    if (changed) _refresh();
  }

  void _onRoster() {
    final p = _presence;
    if (p == null) return;
    final present = {for (final x in p.participants) x.sessionId};
    final before = cells.length + pending.length;
    cells.removeWhere((_, h) => !present.contains(h.sessionId));
    pending.removeWhere((h) => !present.contains(h.sessionId));
    if (before != cells.length + pending.length) _refresh();
  }

  /// Drops hints older than [lifetime].
  void expire() {
    final cutoff = clock.now().subtract(lifetime);
    final before = cells.length + pending.length;
    cells.removeWhere((_, h) => !h.receivedAt.isAfter(cutoff));
    pending.removeWhere((h) => !h.receivedAt.isAfter(cutoff));
    if (before != cells.length + pending.length) _refresh();
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    if (cells.isEmpty && pending.isEmpty) return;
    DateTime? oldest;
    for (final h in cells.values) {
      if (oldest == null || h.receivedAt.isBefore(oldest)) {
        oldest = h.receivedAt;
      }
    }
    for (final h in pending) {
      if (oldest == null || h.receivedAt.isBefore(oldest)) {
        oldest = h.receivedAt;
      }
    }
    final wait = oldest!.add(lifetime).difference(clock.now());
    _expiry = Timer(
      wait.isNegative ? Duration.zero : wait + const Duration(milliseconds: 10),
      expire,
    );
  }

  FValue? _hintedAt(String sheetId, int row, int col) {
    if (cells.isEmpty) return null;
    final sheet = editor.model.sheet(sheetId);
    final r = sheet?.rows.tryIdAt(row);
    final c = sheet?.columns.tryIdAt(col);
    if (r == null || c == null) return null;
    return cells[key(sheetId, r, c)]?.value;
  }

  void _refresh() {
    if (_disposed) return;
    editor.cells.invalidate();
    editor.contentSignal.fire();
    editor.overlaySignal.fire();
  }

  void dispose() {
    _disposed = true;
    _typingTimer?.cancel();
    editor.editor.text.removeListener(_onTypingText);
    editor.model.removeListener(_onBatch);
    if (editor.cells.hinted == _hintedAt) editor.cells.hinted = null;
    unawaited(_remote?.cancel());
    unawaited(_hintsSub?.cancel());
    _presence?.removeListener(_onRoster);
    _expiry?.cancel();
  }
}
