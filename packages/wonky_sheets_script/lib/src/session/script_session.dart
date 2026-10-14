import 'dart:async';

import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';

import '../build/script_exports.dart';
import '../custom_functions/custom_functions.dart';
import '../guest/guest_runtime.dart';
import '../host/limits.dart';
import '../host/script_host.dart';
import '../host/services.dart';
import '../host/workbook_access.dart';
import '../protocol/messages.dart';
import '../runner/execution.dart';

/// Everything one open spreadsheet needs to run its script (09 §8.4, §8.8):
/// the last good program, a UI runner for functions/menus/macros/simple
/// triggers, a pure runner for custom functions, and the custom function
/// provider for the formula engine.
///
/// The app's `ScriptService` owns one session per open spreadsheet, feeds it
/// builds (`setProgram`), the selection and events, persists
/// [ExecutionResult.applied] (one undo step "Script: fn") and uploads results
/// from [executions]. The server uses the same class without a UI delegate.
final class ScriptSession {
  /// Creates a session.
  ScriptSession({
    required this.workbook,
    required this.uiRunner,
    ScriptRunner? pureRunner,
    required this.user,
    required this.role,
    this.ui,
    this.fetcher,
    PropertyStore? userProperties,
    this.grantedScopes = const {},
    this.authorized = true,
    this.isServer = false,
    this.spreadsheetUrl = '',
    this.limits = ExecutionLimits.client,
    this.timeZones = const TzDatabaseResolver(),
    this.maxQueued = 10,
  }) : pureRunner = pureRunner ?? uiRunner,
       userProperties = userProperties ?? MemoryPropertyStore() {
    customFunctions = ScriptCustomFunctions(
      evaluator: RunnerCustomFunctionEvaluator(
        runner: this.pureRunner,
        workbook: workbook,
        user: user,
        fetcher: fetcher,
        timeZones: timeZones,
        onBatch: (r) => _batches.add(r),
      ),
      isBuiltin: (n) => FunctionRegistry.standard.lookup(n) != null,
      timeZones: timeZones,
      timeZone: workbook.model.spreadsheet.timeZone,
    );
  }

  /// The workbook.
  final WorkbookAccess workbook;

  /// Runner for everything but custom functions.
  final ScriptRunner uiRunner;

  /// Runner for custom functions (warm, pure).
  final ScriptRunner pureRunner;

  /// The running user.
  final ScriptUser user;

  /// Role of [user].
  Role role;

  /// UI delegate (null on the server).
  final ScriptUiDelegate? ui;

  /// URL fetches.
  final UrlFetcher? fetcher;

  /// The user's properties for this spreadsheet.
  final PropertyStore userProperties;

  /// Scopes the user authorized (09 §11.2).
  Set<String> grantedScopes;

  /// Whether the user authorized the project at all.
  bool authorized;

  /// Server-side session.
  final bool isServer;

  /// `Spreadsheet.url`.
  final String spreadsheetUrl;

  /// Limits of functions, menus and macros.
  final ExecutionLimits limits;

  /// Time zone offsets.
  final TimeZoneResolver timeZones;

  /// Max queued executions (09 §8.4).
  final int maxQueued;

  /// The formula engine's custom function hook.
  late final ScriptCustomFunctions customFunctions;

  /// Current selection of the user's window.
  ScriptSelection? selection;

  /// Menus registered by the last `onOpen` (`ScriptMenuRegistry` input).
  final List<ScriptMenu> menus = [];

  ScriptProgram? _program;
  final _executions = StreamController<ExecutionResult>.broadcast();
  final _batches = StreamController<CustomFunctionBatchReport>.broadcast();
  final _queue = <_Queued>[];
  bool _running = false;

  /// The installed program (last good build).
  ScriptProgram? get program => _program;

  /// Finished executions (for the executions log upload).
  Stream<ExecutionResult> get executions => _executions.stream;

  /// Finished custom function batches.
  Stream<CustomFunctionBatchReport> get customFunctionBatches =>
      _batches.stream;

  /// Installs the last good build (from `ScriptBuild.lastGood*`). Returns
  /// false when the build needs a newer app (`apiVersion`, 09 §9.4).
  bool setProgram(ScriptProgram? program, {int supportedApiVersion = 1}) {
    if (program != null && program.exports.apiVersion > supportedApiVersion) {
      _program = null;
      customFunctions.setProgram(null);
      return false;
    }
    _program = program;
    customFunctions.setProgram(program);
    return true;
  }

  /// Whether the build needs scopes the user has not granted.
  Set<String> missingScopes() {
    final p = _program;
    if (p == null) return const {};
    return {
      for (final s in p.exports.scopes)
        if (!ScriptScopes.implicit.contains(s) && !grantedScopes.contains(s)) s,
    };
  }

  ScriptHost _host(ExecutionKind kind, {required bool limited}) {
    final effectiveLimits = kind == ExecutionKind.onSelectionChange
        ? ExecutionLimits.selectionChange
        : limits;
    return ScriptHost(
      workbook: workbook,
      context: ExecutionContext(
        kind: kind,
        activeUser: user,
        role: role,
        grantedScopes: grantedScopes,
        authorized: authorized && !limited,
        isServer: isServer,
        selection: selection,
        spreadsheetUrl: spreadsheetUrl,
      ),
      limits: effectiveLimits,
      ui: isServer || ui == null ? null : _MenuCapture(ui, menus),
      fetcher: fetcher,
      userProperties: userProperties,
      knownFunctions: {
        for (final f
            in _program?.exports.functions ?? const <ScriptFunctionInfo>[])
          f.name,
      },
      timeZones: timeZones,
    );
  }

  /// Runs [functionName] (editor, menu, macro, MCP UI bridge). Executions of
  /// one session run one at a time; at most [maxQueued] wait, and the oldest
  /// queued `onSelectionChange` is dropped first.
  Future<ExecutionResult> run(
    String functionName, {
    ExecutionKind kind = ExecutionKind.editor,
    ScriptEvent? event,
    List<Object?> args = const [],
  }) {
    final program = _program;
    if (program == null) {
      return Future.value(
        _notRun(functionName, kind, 'There is no successful build yet.'),
      );
    }
    final c = Completer<ExecutionResult>();
    final q = _Queued(functionName, kind, event, args, c);
    if (_queue.length >= maxQueued) {
      final drop = _queue.indexWhere(
        (x) => x.kind == ExecutionKind.onSelectionChange,
      );
      final victim = _queue.removeAt(drop < 0 ? 0 : drop);
      victim.completer.complete(
        _notRun(victim.function, victim.kind, 'Too many queued executions.'),
      );
    }
    _queue.add(q);
    unawaited(_pump());
    return c.future;
  }

  /// Runs the simple trigger [kind] if the build declares it; returns null
  /// otherwise. Unauthorized users run in `AuthMode.limited` (09 §8.7.1).
  Future<ExecutionResult?> fireSimpleTrigger(
    ExecutionKind kind,
    ScriptEvent event,
  ) async {
    final name = switch (kind) {
      ExecutionKind.onOpen => 'onOpen',
      ExecutionKind.onEdit => 'onEdit',
      ExecutionKind.onSelectionChange => 'onSelectionChange',
      ExecutionKind.onChange => 'onChange',
      _ => throw ArgumentError('$kind is not a simple trigger'),
    };
    final p = _program;
    if (p == null || !p.exports.hasTrigger(name)) return null;
    if (kind == ExecutionKind.onOpen) menus.clear();
    return run(name, kind: kind, event: event);
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final q = _queue.removeAt(0);
        final program = _program;
        if (program == null) {
          q.completer.complete(_notRun(q.function, q.kind, 'No build.'));
          continue;
        }
        final limited = q.kind.isSimpleTrigger && missingScopes().isNotEmpty;
        final host = _host(q.kind, limited: limited);
        try {
          final r = await runScript(
            runner: uiRunner,
            host: host,
            program: program,
            functionName: q.function,
            args: q.args,
            event: q.event,
          );
          _executions.add(r);
          q.completer.complete(r);
        } on Object catch (e, s) {
          q.completer.completeError(e, s);
        }
      }
    } finally {
      _running = false;
    }
  }

  ExecutionResult _notRun(String fn, ExecutionKind kind, String why) =>
      ExecutionResult(
        executionId: '',
        functionName: fn,
        kind: kind,
        status: ExecutionStatus.skipped,
        error: ScriptFailure(type: 'ScriptException', message: why),
        startedAt: DateTime.now(),
        duration: Duration.zero,
        counters: ExecutionCounters(),
        logs: [LogEntry(DateTime.now(), ScriptLogLevel.system, why)],
      );

  /// Releases runners and streams.
  Future<void> close() async {
    await uiRunner.close();
    if (!identical(pureRunner, uiRunner)) await pureRunner.close();
    await customFunctions.dispose();
    await _executions.close();
    await _batches.close();
  }
}

final class _Queued {
  _Queued(this.function, this.kind, this.event, this.args, this.completer);
  final String function;
  final ExecutionKind kind;
  final ScriptEvent? event;
  final List<Object?> args;
  final Completer<ExecutionResult> completer;
}

/// Records menus of `onOpen` in the session and forwards to the app.
final class _MenuCapture implements ScriptUiDelegate {
  _MenuCapture(this.inner, this.menus);
  final ScriptUiDelegate? inner;
  final List<ScriptMenu> menus;

  ScriptUiDelegate get _inner =>
      inner ?? (throw StateError('No UI in this session.'));

  @override
  void activateSheet(String sheetId) => inner?.activateSheet(sheetId);

  @override
  void addMenu(ScriptMenu menu) {
    if (menus.length >= 10) {
      throw ArgumentError('A script can add at most 10 menus.');
    }
    menus.add(menu);
    inner?.addMenu(menu);
  }

  @override
  void select(ResolvedRange range) => inner?.select(range);

  @override
  Future<ScriptDialogResponse> showDialog(ScriptDialogRequest request) =>
      _inner.showDialog(request);

  @override
  void showToast(String message, {String? title, double timeoutSeconds = 5}) =>
      inner?.showToast(message, title: title, timeoutSeconds: timeoutSeconds);
}
