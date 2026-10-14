import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:uuid/uuid.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';

import '../protocol/messages.dart';
import '../protocol/values.dart';
import 'cell_values.dart';
import 'limits.dart';
import 'model_stores.dart';
import 'services.dart';
import 'workbook_access.dart';

/// Handles the calls of one execution against a [WorkbookAccess] (09 §8.2.5).
///
/// One host per execution: it owns the handle table (handles of other
/// executions are rejected), the counters, the log and the permission
/// checks. Calls are processed strictly in order. [handle] answers
/// synchronously except for UI waits and URL fetches, which return a
/// `Future` (the inline runner reports those as unavailable).
final class ScriptHost {
  /// Creates a host.
  ScriptHost({
    required this.workbook,
    required this.context,
    this.limits = ExecutionLimits.client,
    this.ui,
    PropertyStore? documentProperties,
    PropertyStore? userProperties,
    TriggerStore? triggers,
    this.fetcher,
    this.knownFunctions,
    TimeZoneResolver timeZones = const TzDatabaseResolver(),
    Clock? clock,
    this.onLog,
  }) : _clock = clock ?? const Clock(),
       documentProperties =
           documentProperties ?? ModelDocumentProperties(workbook),
       userProperties = userProperties ?? MemoryPropertyStore(),
       triggers =
           triggers ??
           ModelTriggerStore(
             workbook,
             userId: context.effectiveUser.id,
             isOwner: context.role == Role.owner,
           ) {
    values = CellValueConverter(
      timeZone: workbook.model.spreadsheet.timeZone,
      timeZones: timeZones,
    );
  }

  /// The workbook.
  final WorkbookAccess workbook;

  /// Who runs the script and how.
  final ExecutionContext context;

  /// Limits of the execution.
  final ExecutionLimits limits;

  /// UI of the user's window (client executions only).
  final ScriptUiDelegate? ui;

  /// `PropertiesService.documentProperties`.
  final PropertyStore documentProperties;

  /// `PropertiesService.userProperties`.
  final PropertyStore userProperties;

  /// `ScriptApp`.
  final TriggerStore triggers;

  /// `UrlFetchApp`; null = not available (offline client, tests).
  final UrlFetcher? fetcher;

  /// Exported function names of the build (validates trigger targets).
  final Set<String>? knownFunctions;

  /// Called for every log line (live editor console).
  final void Function(LogEntry entry)? onLog;

  final Clock _clock;

  /// Whether calls that wait asynchronously (alerts, prompts, URL fetches)
  /// can be answered. The inline runner clears it: those calls then fail
  /// after the usual permission checks.
  bool asyncCallsAllowed = true;

  /// Value conversion in the spreadsheet time zone.
  late final CellValueConverter values;

  /// Counters for the execution record.
  final ExecutionCounters counters = ExecutionCounters();

  /// The log of the execution.
  final List<LogEntry> logs = [];

  int _logBytes = 0;
  bool _logTruncated = false;

  final _handles = <int, _Handle>{};
  final _sheetHandles = <String, int>{};
  int _nextHandle = 1;

  WorkbookModel get _model => workbook.model;

  // -------------------------------------------------------------------------
  // Entry point.
  // -------------------------------------------------------------------------

  /// Handles one call. Never throws: errors become [HostReply.error].
  FutureOr<HostReply> handle(HostCall call) {
    counters.calls++;
    try {
      final r = _dispatch(call.target, call.method, call.args);
      if (r is Future<Object?>) {
        return r.then(
          HostReply.ok,
          onError: (Object e, StackTrace s) {
            return HostReply.error(_toError(e));
          },
        );
      }
      return HostReply.ok(r);
    } on Object catch (e) {
      return HostReply.error(_toError(e));
    }
  }

  /// Adds a log line (also used for captured `print` output).
  void log(ScriptLogLevel level, String message) {
    if (_logTruncated) return;
    final size = message.length + 32;
    if (_logBytes + size > limits.maxLogBytes) {
      _logTruncated = true;
      final notice = LogEntry(
        _clock.now(),
        ScriptLogLevel.system,
        'Log truncated (limit ${limits.maxLogBytes ~/ 1024} KB).',
      );
      logs.add(notice);
      onLog?.call(notice);
      return;
    }
    _logBytes += size;
    final entry = LogEntry(_clock.now(), level, message);
    logs.add(entry);
    onLog?.call(entry);
  }

  ScriptError _toError(Object e) {
    if (e is ScriptError) return e;
    if (e is PlanException) {
      return switch (e.code) {
        'invalid_range' => ScriptError.range(e.message),
        'not_found' => ScriptError('not_found', e.message),
        'unsupported' => ScriptError('unsupported', e.message),
        'cell_limit_exceeded' ||
        'limit_exceeded' => ScriptError.quota(e.message),
        _ => ScriptError.invalid(e.message),
      };
    }
    if (e is InvalidRangeException) return ScriptError.range(e.message);
    if (e is FetchFailure) {
      return ScriptError(e.code, e.message, statusCode: e.statusCode);
    }
    if (e is ArgumentError) return ScriptError.invalid('${e.message}');
    if (e is StateError) return ScriptError.invalid(e.message);
    if (e is FormatException) return ScriptError.invalid(e.message);
    if (e is TypeError) {
      return ScriptError.invalid('Invalid argument type: $e');
    }
    return ScriptError('internal', '$e');
  }

  // -------------------------------------------------------------------------
  // Dispatch.
  // -------------------------------------------------------------------------

  static const _pureMethods = {
    'log',
    'app.flush',
    'session.scriptTimeZone',
    'session.activeUserLocale',
    'fetch.fetch',
    'fetch.fetchAll',
    'props.get',
    'props.all',
    'props.keys',
  };

  Object? _dispatch(int target, String method, List<Object?> a) {
    if (method == 'batch') return _batch(a);
    if (context.kind.isCustomFunction &&
        !method.startsWith('util.') &&
        !_pureMethods.contains(method)) {
      throw const ScriptError(
        'side_effect',
        'Custom functions cannot read or change the spreadsheet or show UI. '
            'Pass the data as arguments instead.',
      );
    }
    final dot = method.indexOf('.');
    final area = dot < 0 ? method : method.substring(0, dot);
    return switch (area) {
      'log' => _log(a),
      'app' => _app(method, a),
      'ss' => _spreadsheet(method, a),
      'sheet' => _sheetCall(target, method, a),
      'range' => _rangeCall(target, method, a),
      'ui' => _ui(method, a),
      'session' => _session(method),
      'fetch' => _fetch(method, a),
      'util' => _util(method, a),
      'props' => _props(method, a),
      'triggers' => _triggers(method, a),
      _ => throw ScriptError('not_found', 'Unknown host method $method'),
    };
  }

  /// A write batch from the guest (09 §8.2.4): applied in order; the first
  /// error stops the batch and is returned.
  Object? _batch(List<Object?> a) {
    for (final c in (a[0]! as List).cast<List<Object?>>()) {
      final call = HostCall.fromWire(c);
      final r = handle(call);
      if (r is Future) {
        throw ScriptError.invalid('Asynchronous call in a write batch');
      }
      if (r.isError) throw r.error!;
    }
    return null;
  }

  Object? _log(List<Object?> a) {
    final level = switch (a[0]) {
      'warn' => ScriptLogLevel.warn,
      'error' => ScriptLogLevel.error,
      _ => ScriptLogLevel.info,
    };
    log(level, '${a[1]}');
    return null;
  }

  // -------------------------------------------------------------------------
  // Handles.
  // -------------------------------------------------------------------------

  /// A range handle for event objects (`EditEvent.range`).
  int createRangeHandle(String sheetId, GridRect rect) =>
      _rangeHandle(sheetId, rect);

  /// The user value scripts receive (`User`).
  Map<String, Object?> userData(ScriptUser user) => _userMap(user);

  int _sheetHandle(String sheetId) => _sheetHandles.putIfAbsent(sheetId, () {
    final h = _nextHandle++;
    _handles[h] = _SheetHandle(sheetId);
    return h;
  });

  int _rangeHandle(String sheetId, GridRect rect) {
    final s = _model.sheet(sheetId)!;
    final h = _nextHandle++;
    _handles[h] = _RangeHandle(
      sheetId,
      s.rows.idAt(rect.top),
      s.rows.idAt(rect.bottom),
      s.columns.idAt(rect.left),
      s.columns.idAt(rect.right),
    );
    return h;
  }

  SheetModel _sheetOf(int h) {
    final handle = _handles[h];
    if (handle is! _SheetHandle) {
      throw ScriptError.invalid('Invalid sheet handle');
    }
    final s = _model.sheet(handle.sheetId);
    if (s == null) throw ScriptError.range('The sheet was deleted.');
    return s;
  }

  (SheetModel, GridRect) _rangeOf(int h) {
    final handle = _handles[h];
    if (handle is! _RangeHandle) {
      throw ScriptError.invalid('Invalid range handle');
    }
    final s = _model.sheet(handle.sheetId);
    if (s == null) throw ScriptError.range('The sheet was deleted.');
    final top = s.rows.indexOf(handle.topRowId);
    final bottom = s.rows.indexOf(handle.bottomRowId);
    final left = s.columns.indexOf(handle.leftColId);
    final right = s.columns.indexOf(handle.rightColId);
    if (top < 0 || bottom < 0 || left < 0 || right < 0) {
      throw ScriptError.range('The range was deleted.');
    }
    return (
      s,
      GridRect(
        math.min(top, bottom),
        math.min(left, right),
        math.max(top, bottom),
        math.max(left, right),
      ),
    );
  }

  ResolvedRange _resolved(SheetModel s, GridRect r) => ResolvedRange(s.id, r);

  int _rangeFromA1(String a1, String? contextSheetId) {
    final ResolvedRange r;
    try {
      r = _model.parseA1(a1, contextSheetId: contextSheetId);
    } on InvalidRangeException catch (e) {
      throw ScriptError.range('Invalid range "$a1": ${e.message}');
    }
    return _rangeHandle(r.sheetId, r.rect);
  }

  // -------------------------------------------------------------------------
  // Permissions.
  // -------------------------------------------------------------------------

  void _requireWrite(String sheetId, [GridRect? rect]) {
    if (context.role < Role.editor) {
      throw ScriptError.permission(
        'You have ${context.role.name} access to this spreadsheet; '
        'scripts can only change it with edit access.',
      );
    }
    if (context.role == Role.owner) return;
    final s = _model.sheet(sheetId);
    if (s == null) return;
    for (final p in s.protections.values) {
      if (p.warningOnly) continue;
      final editors = _stringList(p.editorsJson);
      if (editors.contains(context.effectiveUser.id) ||
          editors.contains(context.effectiveUser.email)) {
        continue;
      }
      final protectedRects = p.rangeJson == null
          ? [s.gridRect]
          : [
              for (final g in GridRange.parseList('[${p.rangeJson}]'))
                s.resolve(g)?.rect,
            ];
      final except = [
        for (final g in GridRange.parseList(p.exceptRangesJson))
          s.resolve(g)?.rect,
      ];
      if (rect != null &&
          except.any(
            (e) =>
                e != null &&
                e.top <= rect.top &&
                e.left <= rect.left &&
                e.bottom >= rect.bottom &&
                e.right >= rect.right,
          )) {
        continue;
      }
      for (final pr in protectedRects) {
        if (pr == null) continue;
        if (rect == null || pr.intersection(rect) != null) {
          throw ScriptError.permission(
            'The range is protected${p.description == null ? '' : ' (${p.description})'}.',
          );
        }
      }
    }
  }

  static List<String> _stringList(String json) {
    try {
      final v = jsonDecode(json);
      return v is List ? [for (final e in v) '$e'] : const [];
    } on FormatException {
      return const [];
    }
  }

  void _requireScope(String scope, String what) {
    if (!context.hasScope(scope)) {
      throw ScriptError(
        'scope_not_granted',
        '$what needs the "$scope" permission. Run a function from the '
            'script editor or a menu to authorize the script.',
      );
    }
  }

  MutationPlan _apply(SheetsOperation op, {int cells = 0}) {
    counters.cellsWritten += cells;
    if (counters.cellsWritten > limits.maxCellsWritten) {
      throw ScriptError.quota(
        'Too many cells written in one execution (limit ${limits.maxCellsWritten}).',
      );
    }
    return workbook.apply(op);
  }

  void _countRead(int cells) {
    counters.cellsRead += cells;
    if (counters.cellsRead > limits.maxCellsRead) {
      throw ScriptError.quota(
        'Too many cells read in one execution (limit ${limits.maxCellsRead}).',
      );
    }
  }

  // -------------------------------------------------------------------------
  // SpreadsheetApp.
  // -------------------------------------------------------------------------

  String _activeSheetId() {
    final sel = context.selection;
    if (!context.isServer && sel != null && _model.sheet(sel.sheetId) != null) {
      return sel.sheetId;
    }
    final visible = _model.visibleSheets;
    if (visible.isNotEmpty) return visible.first.id;
    if (_model.sheets.isEmpty) throw ScriptError.range('No sheets.');
    return _model.sheets.first.id;
  }

  Object? _app(String method, List<Object?> a) {
    switch (method) {
      case 'app.ui':
        if (ui == null || context.isServer) {
          throw const ScriptError(
            'ui_unavailable',
            'SpreadsheetApp.ui is not available in this execution '
                '(server-side or custom function).',
          );
        }
        return true;
      case 'app.activeSheet':
        return _sheetHandle(_activeSheetId());
      case 'app.activeRange':
        final sheetId = _activeSheetId();
        final sel = context.selection;
        final rect =
            !context.isServer &&
                sel != null &&
                sel.sheetId == sheetId &&
                sel.ranges.isNotEmpty
            ? sel.ranges.first
            : const GridRect(0, 0, 0, 0);
        return _rangeHandle(sheetId, rect);
      case 'app.activeRangeList':
        final sheetId = _activeSheetId();
        final sel = context.selection;
        final rects =
            !context.isServer &&
                sel != null &&
                sel.sheetId == sheetId &&
                sel.ranges.isNotEmpty
            ? sel.ranges
            : const [GridRect(0, 0, 0, 0)];
        return [for (final r in rects) _rangeHandle(sheetId, r)];
      case 'app.currentCell':
        final sel = context.selection;
        if (context.isServer || sel == null) {
          return _rangeHandle(_activeSheetId(), const GridRect(0, 0, 0, 0));
        }
        final c = sel.currentCell;
        if (c == null) return null;
        return _rangeHandle(sel.sheetId, GridRect(c.row, c.col, c.row, c.col));
      case 'app.flush':
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  // -------------------------------------------------------------------------
  // Spreadsheet.
  // -------------------------------------------------------------------------

  Object? _spreadsheet(String method, List<Object?> a) {
    final ss = _model.spreadsheet;
    switch (method) {
      case 'ss.id':
        return _model.spreadsheetId;
      case 'ss.name':
        return ss.title;
      case 'ss.setName':
        _requireWrite('');
        _apply(SetSpreadsheetProperties(title: a[0]! as String));
        return null;
      case 'ss.url':
        return context.spreadsheetUrl;
      case 'ss.locale':
        return ss.locale;
      case 'ss.setLocale':
        _requireWrite('');
        _apply(SetSpreadsheetProperties(locale: a[0]! as String));
        return null;
      case 'ss.timeZone':
        return ss.timeZone;
      case 'ss.setTimeZone':
        _requireWrite('');
        _apply(SetSpreadsheetProperties(timeZone: a[0]! as String));
        return null;
      case 'ss.sheets':
        return [for (final s in _model.sheets) _sheetHandle(s.id)];
      case 'ss.sheetByName':
        final s = _model.sheetByName(a[0]! as String);
        return s == null ? null : _sheetHandle(s.id);
      case 'ss.sheetById':
        final s = _model.sheet(a[0]! as String);
        return s == null ? null : _sheetHandle(s.id);
      case 'ss.setActiveSheet':
        final s = _sheetOf(a[0]! as int);
        ui?.activateSheet(s.id);
        return null;
      case 'ss.insertSheet':
        _requireWrite('');
        final name = a[0] as String?;
        final index = a[1] as int?;
        final template = a[2] as int?;
        if (template != null) {
          return _duplicate(_sheetOf(template), name, index);
        }
        final id = workbook.ids.newId();
        _apply(
          AddSheet(
            name: name,
            index: index == null ? null : math.max(0, index - 1),
            sheetId: id,
          ),
        );
        return _sheetHandle(id);
      case 'ss.duplicateSheet':
        _requireWrite('');
        return _duplicate(_sheetOf(a[0]! as int), a[1] as String?, null);
      case 'ss.deleteSheet':
        final s = _sheetOf(a[0]! as int);
        _requireWrite(s.id);
        _apply(DeleteSheet(s.id));
        return null;
      case 'ss.moveSheet':
        final s = _sheetOf(a[0]! as int);
        _requireWrite(s.id);
        _apply(MoveSheet(s.id, math.max(0, (a[1]! as int) - 1)));
        return null;
      case 'ss.getRange':
        return _rangeFromA1(a[0]! as String, _activeSheetId());
      case 'ss.namedRanges':
        final out = <Object?>[];
        for (final n in _model.namedRanges) {
          final r = _namedRangeRect(n);
          if (r == null) continue;
          out.add({'name': n.name, 'range': _rangeHandle(r.sheetId, r.rect)});
        }
        return out;
      case 'ss.getRangeByName':
        final n = _model.namedRange(a[0]! as String);
        final r = n == null ? null : _namedRangeRect(n);
        return r == null ? null : _rangeHandle(r.sheetId, r.rect);
      case 'ss.setNamedRange':
        final (s, rect) = _rangeOf(a[1]! as int);
        _requireWrite(s.id);
        final name = a[0]! as String;
        final existing = _model.namedRange(name);
        if (existing != null) {
          _apply(UpdateNamedRange(existing.id, range: _resolved(s, rect)));
        } else {
          _apply(AddNamedRange(name, range: _resolved(s, rect)));
        }
        return null;
      case 'ss.removeNamedRange':
        _requireWrite('');
        final n = _model.namedRange(a[0]! as String);
        if (n == null) {
          throw ScriptError.range('No named range "${a[0]}".');
        }
        _apply(DeleteNamedRange(n.id));
        return null;
      case 'ss.toast':
        final message = '${a[0]}';
        final title = a[1] as String?;
        final timeout = (a[2] as num?)?.toDouble() ?? 5;
        if (ui == null || context.isServer) {
          log(
            ScriptLogLevel.info,
            'Toast: ${title == null ? '' : '$title — '}$message',
          );
        } else {
          ui!.showToast(message, title: title, timeoutSeconds: timeout);
        }
        return null;
      case 'ss.owner':
        final owner = context.owner ?? context.activeUser;
        return _userMap(owner);
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  ResolvedRange? _namedRangeRect(NamedRangeRecord n) {
    final g = GridRange.tryParse(
      n.rangeJson == null ? null : jsonDecode(n.rangeJson!),
    );
    if (g == null) return null;
    return _model.resolve(g);
  }

  int _duplicate(SheetModel s, String? name, int? index) {
    final before = {for (final x in _model.sheets) x.id};
    final plan = _apply(
      DuplicateSheet(
        s.id,
        name: name,
        index: index == null ? null : math.max(0, index - 1),
      ),
    );
    final id =
        plan.result['sheetId'] as String? ??
        _model.sheets.map((x) => x.id).firstWhere((x) => !before.contains(x));
    return _sheetHandle(id);
  }

  Map<String, Object?> _userMap(ScriptUser u) => {
    'id': u.id,
    'email': context.hasScope(ScriptScopes.userEmail) ? u.email : '',
    'name': u.name,
  };

  // -------------------------------------------------------------------------
  // Sheet.
  // -------------------------------------------------------------------------

  Dimension _dim(Object? v) => v == 'rows' ? Dimension.rows : Dimension.columns;

  List<String> _axisIds(SheetModel s, Dimension d, int position, int count) {
    final axis = s.axis(d);
    final from = position - 1;
    if (from < 0 || count < 1 || from + count > axis.length) {
      throw ScriptError.range(
        '${d == Dimension.rows ? 'Rows' : 'Columns'} $position..${position + count - 1} '
        'are outside the sheet (1..${axis.length}).',
      );
    }
    return [for (var i = from; i < from + count; i++) axis.idAt(i)];
  }

  Object? _sheetCall(int h, String method, List<Object?> a) {
    final s = _sheetOf(h);
    final rec = s.record;
    switch (method) {
      case 'sheet.id':
        return s.id;
      case 'sheet.name':
        return s.name;
      case 'sheet.setName':
        _requireWrite(s.id);
        _apply(RenameSheet(s.id, a[0]! as String));
        return null;
      case 'sheet.index':
        return _model.sheets.indexWhere((x) => x.id == s.id) + 1;
      case 'sheet.isHidden':
        return rec?.hidden ?? false;
      case 'sheet.setHidden':
        _requireWrite(s.id);
        _apply(SetSheetProperties(s.id, hidden: a[0]! as bool));
        return null;
      case 'sheet.tabColor':
        final c = rec?.tabColor;
        return c == null ? null : workbook.formats.color(c);
      case 'sheet.setTabColor':
        _requireWrite(s.id);
        final hex = a[0] as String?;
        _apply(
          SetSheetProperties(s.id, tabColor: hex, clearTabColor: hex == null),
        );
        return null;
      case 'sheet.getRange':
        return _rangeFromA1(a[0]! as String, s.id);
      case 'sheet.getRangeAt':
        final row = a[0]! as int, col = a[1]! as int;
        final nr = a[2]! as int, nc = a[3]! as int;
        return _rangeHandle(s.id, _checkedRect(s, row - 1, col - 1, nr, nc));
      case 'sheet.dataRange':
        final used = s.usedRect();
        return _rangeHandle(
          s.id,
          used == null
              ? const GridRect(0, 0, 0, 0)
              : GridRect(0, 0, used.bottom, used.right),
        );
      case 'sheet.lastRow':
        _countRead(1);
        final used = s.usedRect();
        return used == null ? 0 : used.bottom + 1;
      case 'sheet.lastColumn':
        _countRead(1);
        final used = s.usedRect();
        return used == null ? 0 : used.right + 1;
      case 'sheet.maxRows':
        return s.rows.length;
      case 'sheet.maxColumns':
        return s.columns.length;
      case 'sheet.activeRange':
        final sel = context.selection;
        if (context.isServer || sel == null || sel.sheetId != s.id) return null;
        if (sel.ranges.isEmpty) return null;
        return _rangeHandle(s.id, sel.ranges.first);
      case 'sheet.insert':
        _requireWrite(s.id);
        final d = _dim(a[0]);
        final pos = a[1]! as int, count = a[2]! as int;
        final before = a[3]! as bool;
        final axisLen = s.axis(d).length;
        if (pos < 1 || pos > axisLen || count < 1) {
          throw ScriptError.range('Position $pos is outside the sheet.');
        }
        _apply(
          InsertDimension(
            s.id,
            d,
            before ? pos - 1 : pos,
            count,
            inheritFrom: before ? InheritFrom.after : InheritFrom.before,
          ),
        );
        return null;
      case 'sheet.delete':
        _requireWrite(s.id);
        final d = _dim(a[0]);
        _apply(
          DeleteDimension(s.id, d, _axisIds(s, d, a[1]! as int, a[2]! as int)),
        );
        return null;
      case 'sheet.setDimHidden':
        _requireWrite(s.id);
        final d = _dim(a[0]);
        _apply(
          SetDimensionHidden(
            s.id,
            d,
            _axisIds(s, d, a[1]! as int, a[2]! as int),
            hidden: a[3]! as bool,
          ),
        );
        return null;
      case 'sheet.resize':
        _requireWrite(s.id);
        final d = _dim(a[0]);
        _apply(
          ResizeDimension(
            s.id,
            d,
            _axisIds(s, d, a[1]! as int, a[2]! as int),
            (a[3] as num?)?.toDouble(),
          ),
        );
        return null;
      case 'sheet.frozenRows':
        return rec?.frozenRows ?? 0;
      case 'sheet.frozenColumns':
        return rec?.frozenColumns ?? 0;
      case 'sheet.setFrozen':
        _requireWrite(s.id);
        _apply(SetFrozen(s.id, rows: a[0] as int?, columns: a[1] as int?));
        return null;
      case 'sheet.appendRow':
        _requireWrite(s.id);
        final row = (a[0]! as List).cast<Object?>();
        if (row.isEmpty) return null;
        final used = s.usedRect();
        final r = used == null ? 0 : used.bottom + 1;
        _apply(
          SetCellInputs(
            sheetId: s.id,
            row: r,
            col: 0,
            inputs: [
              [for (final v in row) values.toInput(v, raw: false)],
            ],
            growGrid: true,
            label: 'Append row',
          ),
          cells: row.length,
        );
        _dateFormats(s, r, 0, [row]);
        return null;
      case 'sheet.clear':
        _requireWrite(s.id);
        final contentsOnly = a[0] == true, formatsOnly = a[1] == true;
        final grid = s.gridRect;
        if (grid == null) return null;
        _apply(
          ClearRanges(
            [ResolvedRange(s.id, grid, wholeRows: true, wholeColumns: true)],
            what: contentsOnly
                ? ClearWhat.contents
                : formatsOnly
                ? ClearWhat.formats
                : ClearWhat.all,
          ),
        );
        return null;
      case 'sheet.sort':
        _requireWrite(s.id);
        final col = a[0]! as int;
        if (col < 1 || col > s.columns.length) {
          throw ScriptError.range('Column $col is outside the sheet.');
        }
        final frozen = rec?.frozenRows ?? 0;
        final used = s.usedRect();
        if (used == null || used.bottom < frozen) return null;
        final rect = GridRect(frozen, 0, used.bottom, s.columns.length - 1);
        _apply(
          SortRange(_resolved(s, rect), [
            SortKeySpec(s.columns.idAt(col - 1), ascending: a[1] != false),
          ]),
        );
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  GridRect _checkedRect(SheetModel s, int top, int left, int nr, int nc) {
    if (top < 0 || left < 0 || nr < 1 || nc < 1) {
      throw ScriptError.range(
        'Rows and columns start at 1 and a range has at least one cell.',
      );
    }
    final bottom = top + nr - 1, right = left + nc - 1;
    if (bottom >= s.rows.length || right >= s.columns.length) {
      throw ScriptError.range(
        'The range is outside the sheet (${s.rows.length} rows × '
        '${s.columns.length} columns).',
      );
    }
    return GridRect(top, left, bottom, right);
  }

  // -------------------------------------------------------------------------
  // Range.
  // -------------------------------------------------------------------------

  Object? _rangeCall(int h, String method, List<Object?> a) {
    final (s, rect) = _rangeOf(h);
    switch (method) {
      case 'range.geometry':
        return [rect.top + 1, rect.left + 1, rect.rowCount, rect.colCount];
      case 'range.sheet':
        return _sheetHandle(s.id);
      case 'range.a1':
        return rect.a1;
      case 'range.value':
        return _readValues(
          s,
          GridRect(rect.top, rect.left, rect.top, rect.left),
        ).first.first;
      case 'range.values':
        return _readValues(s, rect);
      case 'range.setValue':
        return _writeValues(
          s,
          GridRect(rect.top, rect.left, rect.top, rect.left),
          [
            [a[0]],
          ],
          raw: false,
        );
      case 'range.setValues':
        return _writeValues(
          s,
          rect,
          (a[0]! as List).cast<Object?>(),
          raw: a[1] == true,
        );
      case 'range.displayValue':
        return _readDisplay(
          s,
          GridRect(rect.top, rect.left, rect.top, rect.left),
        ).first.first;
      case 'range.displayValues':
        return _readDisplay(s, rect);
      case 'range.formula':
        return _readFormulas(
          s,
          GridRect(rect.top, rect.left, rect.top, rect.left),
        ).first.first;
      case 'range.formulas':
        return _readFormulas(s, rect);
      case 'range.setFormula':
        return _writeFormulas(
          s,
          GridRect(rect.top, rect.left, rect.top, rect.left),
          [
            [a[0]],
          ],
        );
      case 'range.setFormulas':
        return _writeFormulas(s, rect, (a[0]! as List).cast<Object?>());
      case 'range.note':
        _countRead(1);
        return s.cellAt(rect.top, rect.left)?.note;
      case 'range.notes':
        _countRead(rect.cellCount);
        return [
          for (var r = rect.top; r <= rect.bottom; r++)
            [
              for (var c = rect.left; c <= rect.right; c++)
                s.cellAt(r, c)?.note,
            ],
        ];
      case 'range.setNote':
        _requireWrite(s.id, rect);
        final note = a[0] as String?;
        for (var r = rect.top; r <= rect.bottom; r++) {
          for (var c = rect.left; c <= rect.right; c++) {
            _apply(SetNote(s.id, r, c, note), cells: 1);
          }
        }
        return null;
      case 'range.setNotes':
        _requireWrite(s.id, rect);
        final grid = _checkGrid((a[0]! as List).cast<Object?>(), rect);
        for (var r = 0; r < rect.rowCount; r++) {
          for (var c = 0; c < rect.colCount; c++) {
            final note = (grid[r] as List)[c] as String?;
            _apply(SetNote(s.id, rect.top + r, rect.left + c, note), cells: 1);
          }
        }
        return null;
      case 'range.formats':
        return _readFormats(s, rect, a[0]! as String);
      case 'range.setFormat':
        _requireWrite(s.id, rect);
        _apply(
          SetFormat([_resolved(s, rect)], _formatValues(a[0]! as String, a[1])),
          cells: rect.cellCount,
        );
        return null;
      case 'range.setFormats':
        _requireWrite(s.id, rect);
        _setFormats(s, rect, a[0]! as String, (a[1]! as List).cast<Object?>());
        return null;
      case 'range.setBorder':
        _requireWrite(s.id, rect);
        _setBorder(s, rect, a);
        return null;
      case 'range.clear':
        _requireWrite(s.id, rect);
        final what = a[0] == true
            ? ClearWhat.contents
            : a[1] == true
            ? ClearWhat.formats
            : a[2] == true
            ? ClearWhat.notes
            : ClearWhat.all;
        _apply(
          ClearRanges([_resolved(s, rect)], what: what),
          cells: rect.cellCount,
        );
        return null;
      case 'range.merge':
        _requireWrite(s.id, rect);
        final mode = switch (a[0]) {
          'horizontal' => MergeMode.horizontal,
          'vertical' => MergeMode.vertical,
          _ => MergeMode.all,
        };
        _apply(MergeCells([_resolved(s, rect)], mode: mode, force: true));
        return null;
      case 'range.breakApart':
        _requireWrite(s.id, rect);
        _apply(UnmergeCells([_resolved(s, rect)]));
        return null;
      case 'range.isMerged':
        return s.mergesIntersecting(rect).isNotEmpty;
      case 'range.isBlank':
        _countRead(rect.cellCount);
        return s.cellsIn(rect, contentOnly: true).isEmpty;
      case 'range.sort':
        _requireWrite(s.id, rect);
        final specs = <SortKeySpec>[];
        for (final k in (a[0]! as List).cast<List<Object?>>()) {
          final col = k[0]! as int;
          if (col < rect.left + 1 || col > rect.right + 1) {
            throw ScriptError.range(
              'Sort column $col is outside the range ${rect.a1}.',
            );
          }
          specs.add(
            SortKeySpec(s.columns.idAt(col - 1), ascending: k[1] != false),
          );
        }
        _apply(SortRange(_resolved(s, rect), specs), cells: rect.cellCount);
        return null;
      case 'range.copyTo':
        final (ds, drect) = _rangeOf(a[0]! as int);
        _requireWrite(
          ds.id,
          GridRect(
            drect.top,
            drect.left,
            drect.top + rect.rowCount - 1,
            drect.left + rect.colCount - 1,
          ),
        );
        _copyTo(
          s,
          rect,
          ds,
          drect,
          contentsOnly: a[1] == true,
          formatsOnly: a[2] == true,
        );
        return null;
      case 'range.moveTo':
        final (ds, drect) = _rangeOf(a[0]! as int);
        _requireWrite(s.id, rect);
        _requireWrite(ds.id, drect);
        _apply(
          MoveRange(_resolved(s, rect), ds.id, drect.top, drect.left),
          cells: rect.cellCount,
        );
        return null;
      case 'range.offset':
        final ro = a[0]! as int, co = a[1]! as int;
        final nr = a[2] as int? ?? rect.rowCount;
        final nc = a[3] as int? ?? rect.colCount;
        return _rangeHandle(
          s.id,
          _checkedRect(s, rect.top + ro, rect.left + co, nr, nc),
        );
      case 'range.cell':
        final r = a[0]! as int, c = a[1]! as int;
        if (r < 1 || c < 1 || r > rect.rowCount || c > rect.colCount) {
          throw ScriptError.range(
            'Cell ($r, $c) is outside the ${rect.rowCount}×${rect.colCount} range.',
          );
        }
        return _rangeHandle(
          s.id,
          GridRect(
            rect.top + r - 1,
            rect.left + c - 1,
            rect.top + r - 1,
            rect.left + c - 1,
          ),
        );
      case 'range.activate':
        ui?.select(_resolved(s, rect));
        return null;
      case 'range.checkboxes':
        _requireWrite(s.id, rect);
        if (a[0] == true) {
          _apply(InsertCheckboxes(s.id, [rect]), cells: rect.cellCount);
        } else {
          _apply(SetDataValidation(s.id, [rect], null), cells: rect.cellCount);
        }
        return null;
      case 'range.trimWhitespace':
        _requireWrite(s.id, rect);
        _apply(TrimWhitespace([_resolved(s, rect)]), cells: rect.cellCount);
        return null;
      case 'range.removeDuplicates':
        _requireWrite(s.id, rect);
        final cols = (a[0] as List?)?.cast<int>();
        _apply(
          RemoveDuplicates(
            _resolved(s, rect),
            colIds: cols == null
                ? null
                : [for (final c in cols) s.columns.idAt(c - 1)],
          ),
          cells: rect.cellCount,
        );
        return h;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  List<Object?> _checkGrid(List<Object?> grid, GridRect rect) {
    if (grid.length != rect.rowCount ||
        grid.any((r) => r is! List || r.length != rect.colCount)) {
      final rows = grid.length;
      final cols = rows == 0 || grid.first is! List
          ? 0
          : (grid.first! as List).length;
      throw ScriptError.range(
        'The data has $rows rows × $cols columns, but the range '
        '${rect.a1} has ${rect.rowCount} × ${rect.colCount}.',
      );
    }
    return grid;
  }

  String _patternAt(SheetModel s, int r, int c) {
    final rf = workbook.formats.resolve(s.id, r, c, includeBanding: false);
    if (rf.numberFormatExplicit) return rf.numberFormat;
    return workbook.engine.numberFormatAt(s.id, r, c) ?? kAutomaticNumberFormat;
  }

  List<List<Object?>> _readValues(SheetModel s, GridRect rect) {
    _countRead(rect.cellCount);
    final engine = workbook.engine;
    return [
      for (var r = rect.top; r <= rect.bottom; r++)
        [
          for (var c = rect.left; c <= rect.right; c++)
            () {
              final v = engine.valueAt(s.id, r, c);
              final isNum =
                  v is FNumber || (v is FArray && v.topLeft is FNumber);
              return values.toScript(
                v,
                isDate: isNum && isDateTimeFormat(_patternAt(s, r, c)),
              );
            }(),
        ],
    ];
  }

  List<List<String>> _readDisplay(SheetModel s, GridRect rect) {
    _countRead(rect.cellCount);
    final engine = workbook.engine;
    final locale = _model.spreadsheet.locale;
    return [
      for (var r = rect.top; r <= rect.bottom; r++)
        [
          for (var c = rect.left; c <= rect.right; c++)
            NumberFormatter.instance.formatText(
              engine.valueAt(s.id, r, c).toCellValue(),
              _patternAt(s, r, c),
              locale: locale,
            ),
        ],
    ];
  }

  List<List<String>> _readFormulas(SheetModel s, GridRect rect) {
    _countRead(rect.cellCount);
    return [
      for (var r = rect.top; r <= rect.bottom; r++)
        [
          for (var c = rect.left; c <= rect.right; c++)
            () {
              final content = s.cellAt(r, c)?.decoded;
              if (content is! FormulaContent) return '';
              return workbook.formulas.toA1(
                content.text,
                sheetId: s.id,
                row: r,
                col: c,
              );
            }(),
        ],
    ];
  }

  Object? _writeValues(
    SheetModel s,
    GridRect rect,
    List<Object?> grid, {
    required bool raw,
  }) {
    _requireWrite(s.id, rect);
    _checkGrid(grid, rect);
    final inputs = <List<CellInput>>[];
    for (final row in grid) {
      final out = <CellInput>[];
      for (final v in row! as List) {
        try {
          out.add(values.toInput(v, raw: raw));
        } on ArgumentError catch (e) {
          throw ScriptError.invalid('${e.message}');
        }
      }
      inputs.add(out);
    }
    _apply(
      SetCellInputs(
        sheetId: s.id,
        row: rect.top,
        col: rect.left,
        inputs: inputs,
      ),
      cells: rect.cellCount,
    );
    _dateFormats(s, rect.top, rect.left, grid);
    return null;
  }

  /// Gives cells that received a `DateTime` a date format when their format
  /// is automatic (like typing a date).
  void _dateFormats(SheetModel s, int top, int left, List<Object?> grid) {
    final dateCells = <ResolvedRange>[];
    final dateTimeCells = <ResolvedRange>[];
    for (var r = 0; r < grid.length; r++) {
      final row = grid[r]! as List;
      for (var c = 0; c < row.length; c++) {
        final v = row[c];
        if (v is! DateTime) continue;
        final rf = workbook.formats.resolve(
          s.id,
          top + r,
          left + c,
          includeBanding: false,
        );
        if (rf.numberFormatExplicit && !rf.isAutomatic) continue;
        final serial = values.serialOf(v);
        final target = serial == serial.truncateToDouble()
            ? dateCells
            : dateTimeCells;
        target.add(ResolvedRange(s.id, GridRect.cell(top + r, left + c)));
      }
    }
    if (dateCells.isNotEmpty) {
      workbook.apply(
        SetFormat(dateCells, {FormatAttr.numberFormat: 'preset:date'}),
      );
    }
    if (dateTimeCells.isNotEmpty) {
      workbook.apply(
        SetFormat(dateTimeCells, {FormatAttr.numberFormat: 'preset:dateTime'}),
      );
    }
  }

  Object? _writeFormulas(SheetModel s, GridRect rect, List<Object?> grid) {
    _requireWrite(s.id, rect);
    _checkGrid(grid, rect);
    final inputs = [
      for (final row in grid)
        [
          for (final f in row! as List)
            () {
              final text = '${f ?? ''}';
              if (text.isEmpty) return const CellInput.raw(null);
              return CellInput.user(text.startsWith('=') ? text : '=$text');
            }(),
        ],
    ];
    _apply(
      SetCellInputs(
        sheetId: s.id,
        row: rect.top,
        col: rect.left,
        inputs: inputs,
      ),
      cells: rect.cellCount,
    );
    return null;
  }

  List<List<Object?>> _readFormats(SheetModel s, GridRect rect, String attr) {
    _countRead(rect.cellCount);
    final f = workbook.formats;
    return [
      for (var r = rect.top; r <= rect.bottom; r++)
        [
          for (var c = rect.left; c <= rect.right; c++)
            () {
              final rf = f.resolve(s.id, r, c);
              return switch (attr) {
                'numberFormat' => rf.numberFormat,
                'background' => f.color(rf.fillColor),
                'fontColor' => f.color(rf.textColor) ?? '#000000',
                'fontWeight' => rf.bold ? 'bold' : 'normal',
                'fontStyle' => rf.italic ? 'italic' : 'normal',
                'fontFamily' => rf.fontFamily,
                'fontSize' => rf.fontSize,
                'horizontalAlignment' => rf.hAlign?.name ?? 'general',
                'verticalAlignment' => rf.vAlign.name,
                _ => throw ScriptError.invalid('Unknown format $attr'),
              };
            }(),
        ],
    ];
  }

  Map<FormatAttr, Object?> _formatValues(String attr, Object? v) {
    switch (attr) {
      case 'numberFormat':
        return {FormatAttr.numberFormat: v as String?};
      case 'background':
        return {FormatAttr.fillColor: _color(v)};
      case 'fontColor':
        return {FormatAttr.textColor: _color(v)};
      case 'fontWeight':
        return {FormatAttr.bold: v == 'bold'};
      case 'fontStyle':
        return {FormatAttr.italic: v == 'italic'};
      case 'fontFamily':
        return {FormatAttr.fontFamily: v as String?};
      case 'fontSize':
        final size = (v as num?)?.toDouble();
        if (size != null && (size < 1 || size > 400)) {
          throw ScriptError.invalid('Font size must be between 1 and 400.');
        }
        return {FormatAttr.fontSize: size};
      case 'horizontalAlignment':
        return {
          FormatAttr.hAlign: switch (v) {
            'left' => HorizontalAlign.left,
            'center' => HorizontalAlign.center,
            'right' => HorizontalAlign.right,
            'general' || null => null,
            _ => throw ScriptError.invalid('Unknown alignment "$v".'),
          },
        };
      case 'verticalAlignment':
        return {
          FormatAttr.vAlign: switch (v) {
            'top' => VerticalAlign.top,
            'middle' => VerticalAlign.middle,
            'bottom' => VerticalAlign.bottom,
            _ => throw ScriptError.invalid('Unknown alignment "$v".'),
          },
        };
      case 'wrapStrategy':
        return {
          FormatAttr.wrap: switch (v) {
            'overflow' => WrapStrategy.overflow,
            'wrap' => WrapStrategy.wrap,
            'clip' => WrapStrategy.clip,
            _ => throw ScriptError.invalid('Unknown wrap strategy "$v".'),
          },
        };
      case 'textDecoration':
        return {
          FormatAttr.underline: v == 'underline',
          FormatAttr.strikethrough: v == 'lineThrough',
        };
    }
    throw ScriptError.invalid('Unknown format $attr');
  }

  static final _hex = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$');

  String? _color(Object? v) {
    if (v == null) return null;
    final s = '$v'.trim();
    if (!_hex.hasMatch(s)) {
      throw ScriptError.invalid('Colors are "#RRGGBB" strings, got "$s".');
    }
    if (s.length == 4) {
      return '#${s[1]}${s[1]}${s[2]}${s[2]}${s[3]}${s[3]}'.toUpperCase();
    }
    return s.toUpperCase();
  }

  void _setFormats(
    SheetModel s,
    GridRect rect,
    String attr,
    List<Object?> grid,
  ) {
    _checkGrid(grid, rect);
    final groups = <Object?, List<ResolvedRange>>{};
    for (var r = 0; r < rect.rowCount; r++) {
      final row = grid[r]! as List;
      for (var c = 0; c < rect.colCount; c++) {
        groups
            .putIfAbsent(row[c], () => [])
            .add(
              ResolvedRange(s.id, GridRect.cell(rect.top + r, rect.left + c)),
            );
      }
    }
    for (final e in groups.entries) {
      _apply(
        SetFormat(e.value, _formatValues(attr, e.key)),
        cells: e.value.length,
      );
    }
  }

  void _setBorder(SheetModel s, GridRect rect, List<Object?> a) {
    final color = a[6] as String?;
    final style = switch (a[7]) {
      'medium' => BorderStyle.medium,
      'thick' => BorderStyle.thick,
      'dashed' => BorderStyle.dashed,
      'dotted' => BorderStyle.dotted,
      'double' => BorderStyle.double,
      _ => BorderStyle.thin,
    };
    final range = [_resolved(s, rect)];
    const presets = [
      BorderPreset.top,
      BorderPreset.left,
      BorderPreset.bottom,
      BorderPreset.right,
      BorderPreset.vertical,
      BorderPreset.horizontal,
    ];
    for (var i = 0; i < presets.length; i++) {
      final v = a[i];
      if (v == true) {
        _apply(
          SetBorders(
            range,
            presets[i],
            style: style,
            color: color == null ? 'auto' : _color(color)!,
          ),
          cells: rect.cellCount,
        );
      } else if (v == false) {
        _clearBorderSide(s, rect, presets[i]);
      }
    }
  }

  void _clearBorderSide(SheetModel s, GridRect rect, BorderPreset side) {
    final (GridRect edge, FormatAttr attr) = switch (side) {
      BorderPreset.top => (
        GridRect(rect.top, rect.left, rect.top, rect.right),
        FormatAttr.borderTop,
      ),
      BorderPreset.bottom => (
        GridRect(rect.bottom, rect.left, rect.bottom, rect.right),
        FormatAttr.borderBottom,
      ),
      BorderPreset.left => (
        GridRect(rect.top, rect.left, rect.bottom, rect.left),
        FormatAttr.borderLeft,
      ),
      BorderPreset.right => (
        GridRect(rect.top, rect.right, rect.bottom, rect.right),
        FormatAttr.borderRight,
      ),
      BorderPreset.vertical => (rect, FormatAttr.borderRight),
      _ => (rect, FormatAttr.borderBottom),
    };
    _apply(
      SetFormat([_resolved(s, edge)], {attr: null}),
      cells: edge.cellCount,
    );
  }

  void _copyTo(
    SheetModel s,
    GridRect rect,
    SheetModel ds,
    GridRect drect, {
    required bool contentsOnly,
    required bool formatsOnly,
  }) {
    if (!contentsOnly && !formatsOnly) {
      _apply(
        MoveRange(_resolved(s, rect), ds.id, drect.top, drect.left, copy: true),
        cells: rect.cellCount,
      );
      return;
    }
    final cells = <List<PasteCell?>>[];
    for (var r = rect.top; r <= rect.bottom; r++) {
      final row = <PasteCell?>[];
      for (var c = rect.left; c <= rect.right; c++) {
        final cell = s.cellAt(r, c);
        final content = cell?.decoded;
        row.add(
          PasteCell(
            storedFormula: content is FormulaContent
                ? workbook.formulas.translate(
                    content.text,
                    fromSheetId: s.id,
                    fromRow: r,
                    fromCol: c,
                    toSheetId: ds.id,
                    toRow: drect.top + r - rect.top,
                    toCol: drect.left + c - rect.left,
                  )
                : null,
            content: content is FormulaContent ? null : content,
            format: _model.explicitFormatChain(s.id, r, c),
          ),
        );
      }
      cells.add(row);
    }
    final target = ResolvedRange(
      ds.id,
      GridRect(
        drect.top,
        drect.left,
        drect.top + rect.rowCount - 1,
        drect.left + rect.colCount - 1,
      ),
    );
    _apply(
      PasteClipboard(
        target,
        PasteSource(cells: cells),
        mode: contentsOnly ? PasteMode.formulas : PasteMode.format,
      ),
      cells: rect.cellCount,
    );
  }

  // -------------------------------------------------------------------------
  // Ui.
  // -------------------------------------------------------------------------

  Object? _ui(String method, List<Object?> a) {
    final delegate = ui;
    switch (method) {
      case 'ui.addMenu':
        if (delegate == null || context.isServer) return null;
        delegate.addMenu(_menu(a[0]! as Map));
        return null;
      case 'ui.alert':
      case 'ui.prompt':
        if (delegate == null || context.isServer) {
          throw const ScriptError(
            'ui_unavailable',
            'Alerts and prompts are not available in this execution.',
          );
        }
        if (context.kind == ExecutionKind.onSelectionChange) {
          throw const ScriptError(
            'ui_unavailable',
            'onSelectionChange may only show toasts.',
          );
        }
        if (!asyncCallsAllowed) {
          throw const ScriptError(
            'ui_unavailable',
            'Alerts and prompts are not available in this browser runtime. '
                'Use toasts, or run the script in the desktop app.',
          );
        }
        final buttons = ScriptButtonSet.values.firstWhere(
          (b) => b.name == a[2],
          orElse: () => ScriptButtonSet.ok,
        );
        final prompt = method == 'ui.prompt';
        final started = _clock.now();
        return withTimeoutOr(
          delegate.showDialog(
            ScriptDialogRequest(
              message: '${a[0]}',
              title: a[1] as String?,
              buttons: buttons,
              prompt: prompt,
            ),
          ),
          limits.maxUiWait,
          const ScriptDialogResponse(ScriptButton.close),
        ).then((r) {
          counters.uiWait += _clock.now().difference(started);
          return prompt ? [r.button.name, r.text] : r.button.name;
        });
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  ScriptMenu _menu(Map<Object?, Object?> tree, [int depth = 1]) {
    if (depth > 3) throw ScriptError.invalid('Menus can be nested 3 levels.');
    final items = <ScriptMenuItem>[];
    for (final i
        in (tree['items'] as List? ?? const []).cast<Map<Object?, Object?>>()) {
      if (i['separator'] == true) {
        items.add(const ScriptMenuItem.separator());
      } else if (i['items'] != null) {
        final sub = _menu(i, depth + 1);
        items.add(ScriptMenuItem.subMenu(sub.caption, sub.items));
      } else {
        items.add(
          ScriptMenuItem.action('${i['caption']}', '${i['functionName']}'),
        );
      }
      if (items.length > 50) {
        throw ScriptError.invalid('A menu can have at most 50 items.');
      }
    }
    return ScriptMenu('${tree['caption']}', items);
  }

  // -------------------------------------------------------------------------
  // Session.
  // -------------------------------------------------------------------------

  Object? _session(String method) => switch (method) {
    'session.activeUser' => _userMap(context.activeUser),
    'session.effectiveUser' => _userMap(context.effectiveUser),
    'session.scriptTimeZone' =>
      context.scriptTimeZone ?? _model.spreadsheet.timeZone,
    'session.activeUserLocale' => context.userLocale,
    _ => throw ScriptError('not_found', 'Unknown host method $method'),
  };

  // -------------------------------------------------------------------------
  // UrlFetchApp.
  // -------------------------------------------------------------------------

  Object? _fetch(String method, List<Object?> a) {
    if (!context.kind.isCustomFunction) {
      _requireScope(ScriptScopes.externalRequest, 'UrlFetchApp');
    }
    if (!asyncCallsAllowed) {
      throw const ScriptError(
        'unsupported',
        'UrlFetchApp is not available in this browser runtime. Use '
            '"Run on server" instead.',
      );
    }
    final f = fetcher;
    if (f == null) {
      throw const ScriptError(
        'offline',
        'URL fetches need a connection to the Wonky server.',
      );
    }
    Future<Map<String, Object?>> one(
      String url,
      Map<String, Object?>? o,
    ) async {
      final req = FetchRequestData.fromApi(url, o);
      counters.fetchCalls++;
      final r = await f.fetch(
        req,
        customFunction: context.kind.isCustomFunction,
      );
      counters.fetchBytes += r.bytes.length;
      if (r.statusCode >= 400 && !req.muteHttpExceptions) {
        throw FetchFailure(
          'Request to $url failed with status ${r.statusCode}. Use '
          'muteHttpExceptions to read the response.',
          statusCode: r.statusCode,
        );
      }
      return r.toApi();
    }

    if (method == 'fetch.fetch') {
      return one(a[0]! as String, (a[1] as Map?)?.cast<String, Object?>());
    }
    if (method == 'fetch.fetchAll') {
      final reqs = (a[0]! as List).cast<List<Object?>>();
      if (reqs.length > limits.maxFetchAll) {
        throw ScriptError.quota(
          'fetchAll takes at most ${limits.maxFetchAll} requests.',
        );
      }
      return Future.wait([
        for (final r in reqs)
          one(r[0]! as String, (r[1] as Map?)?.cast<String, Object?>()),
      ]);
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  // -------------------------------------------------------------------------
  // Utilities.
  // -------------------------------------------------------------------------

  Object? _util(String method, List<Object?> a) {
    switch (method) {
      case 'util.formatDate':
        final date = a[0]! as DateTime;
        final conv = CellValueConverter(
          timeZone: a[1]! as String,
          timeZones: values.timeZones,
        );
        return NumberFormatter.instance.formatText(
          NumberValue(conv.serialOf(date)),
          a[2]! as String,
          locale: _model.spreadsheet.locale,
        );
      case 'util.parseDate':
        final parsed = InputParser.instance.parseValue(
          a[0]! as String,
          locale: _model.spreadsheet.locale,
        );
        final content = parsed?.content;
        if (content is! NumberContent) {
          throw ScriptError.invalid('"${a[0]}" is not a date.');
        }
        final conv = CellValueConverter(
          timeZone: a[1]! as String,
          timeZones: values.timeZones,
        );
        return conv.instantOf(content.number);
      case 'util.uuid':
        return const Uuid().v4();
      case 'util.base64Encode':
        return base64Encode((a[0]! as List).cast<int>());
      case 'util.base64Decode':
        return Uint8List.fromList(base64Decode(a[0]! as String));
      case 'util.digest':
        final bytes = utf8.encode(a[1]! as String);
        final hash = switch ('${a[0]}'.toLowerCase()) {
          'md5' => crypto.md5,
          'sha1' => crypto.sha1,
          'sha256' => crypto.sha256,
          'sha512' => crypto.sha512,
          _ => throw ScriptError.invalid('Unknown digest algorithm ${a[0]}.'),
        };
        return hash.convert(bytes).toString();
      case 'util.hmac':
        final hash = switch ('${a[0]}'.toLowerCase()) {
          'sha256' => crypto.sha256,
          'sha512' => crypto.sha512,
          _ => throw ScriptError.invalid('Unknown HMAC algorithm ${a[0]}.'),
        };
        return crypto.Hmac(
          hash,
          utf8.encode(a[2]! as String),
        ).convert(utf8.encode(a[1]! as String)).toString();
      case 'util.jsonEncode':
        return jsonEncode(_jsonable(a[0]));
      case 'util.jsonDecode':
        return jsonDecode(a[0]! as String);
      case 'util.formatString':
        return formatString(a[0]! as String, (a[1]! as List).cast<Object?>());
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  static Object? _jsonable(Object? v) => switch (v) {
    DateTime d => d.toUtc().toIso8601String(),
    CellError e => e.code,
    Uint8List b => [...b],
    Map<Object?, Object?> m => {
      for (final e in m.entries) '${e.key}': _jsonable(e.value),
    },
    List<Object?> l => [for (final e in l) _jsonable(e)],
    double d when !d.isFinite => null,
    _ => v,
  };

  /// printf-like formatting (`%s`, `%d`, `%f`, `%.2f`, `%%`).
  static String formatString(String template, List<Object?> args) {
    var i = 0;
    return template.replaceAllMapped(RegExp(r'%(\.(\d+))?([sdf%])'), (m) {
      if (m[3] == '%') return '%';
      final v = i < args.length ? args[i++] : null;
      switch (m[3]) {
        case 'd':
          return v is num ? v.truncate().toString() : '$v';
        case 'f':
          final digits = int.tryParse(m[2] ?? '') ?? 6;
          return v is num ? v.toStringAsFixed(digits) : '$v';
        default:
          return '$v';
      }
    });
  }

  // -------------------------------------------------------------------------
  // Properties.
  // -------------------------------------------------------------------------

  Object? _props(String method, List<Object?> a) {
    final scope = a[0];
    final store = scope == 'user' ? userProperties : documentProperties;
    bool write() {
      if (context.kind.isCustomFunction) {
        throw const ScriptError(
          'side_effect',
          'Custom functions cannot change properties.',
        );
      }
      if (scope == 'document' && context.role < Role.editor) {
        throw ScriptError.permission(
          'Only editors can change document properties.',
        );
      }
      return true;
    }

    void checkSize(Map<String, String> next) {
      var total = 0;
      for (final e in next.entries) {
        final size = utf8.encode(e.value).length;
        if (size > limits.maxPropertyValueBytes) {
          throw ScriptError.quota(
            'Property "${e.key}" is larger than '
            '${limits.maxPropertyValueBytes ~/ 1024} KB.',
          );
        }
        total += size + utf8.encode(e.key).length;
      }
      if (total > limits.maxPropertyStoreBytes) {
        throw ScriptError.quota(
          'The property store would exceed '
          '${limits.maxPropertyStoreBytes ~/ 1024} KB.',
        );
      }
    }

    switch (method) {
      case 'props.get':
        return store.all()[a[1]! as String];
      case 'props.all':
        return store.all();
      case 'props.keys':
        return store.all().keys.toList();
      case 'props.set':
        write();
        final next = store.all()..[a[1]! as String] = a[2]! as String;
        checkSize(next);
        store.set(a[1]! as String, a[2]! as String);
        return null;
      case 'props.delete':
        write();
        store.delete(a[1]! as String);
        return null;
      case 'props.setAll':
        write();
        final values = (a[1]! as Map).map((k, v) => MapEntry('$k', '$v'));
        final deleteOthers = a[2] == true;
        final next = deleteOthers ? values : (store.all()..addAll(values));
        checkSize(next);
        if (deleteOthers) {
          for (final k in store.all().keys) {
            if (!values.containsKey(k)) store.delete(k);
          }
        }
        for (final e in values.entries) {
          store.set(e.key, e.value);
        }
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  // -------------------------------------------------------------------------
  // ScriptApp.
  // -------------------------------------------------------------------------

  Object? _triggers(String method, List<Object?> a) {
    _requireScope(ScriptScopes.triggers, 'ScriptApp');
    if (context.role < Role.editor) {
      throw ScriptError.permission('Only editors can manage triggers.');
    }
    switch (method) {
      case 'triggers.create':
        final fn = a[0]! as String;
        final known = knownFunctions;
        if (known != null && !known.contains(fn)) {
          throw ScriptError.invalid('There is no function named "$fn".');
        }
        return triggers
            .create(
              fn,
              a[1]! as String,
              (a[2] as Map?)?.cast<String, Object?>(),
            )
            .toApi();
      case 'triggers.list':
        return [for (final t in triggers.list()) t.toApi()];
      case 'triggers.delete':
        triggers.delete(a[0]! as String);
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }
}

sealed class _Handle {
  const _Handle();
}

final class _SheetHandle extends _Handle {
  const _SheetHandle(this.sheetId);
  final String sheetId;
}

final class _RangeHandle extends _Handle {
  const _RangeHandle(
    this.sheetId,
    this.topRowId,
    this.bottomRowId,
    this.leftColId,
    this.rightColId,
  );
  final String sheetId;
  final String topRowId;
  final String bottomRowId;
  final String leftColId;
  final String rightColId;
}
