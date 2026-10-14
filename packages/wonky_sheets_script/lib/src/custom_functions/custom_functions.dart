import 'dart:async';

import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';

import '../build/script_exports.dart';
import '../host/cell_values.dart';
import '../host/limits.dart';
import '../host/script_host.dart';
import '../host/services.dart';
import '../host/workbook_access.dart';
import '../runner/execution.dart';

/// One pending custom function call.
final class CustomFunctionCall {
  /// Creates a call.
  const CustomFunctionCall(
    this.key,
    this.formulaName,
    this.function,
    this.args,
  );

  /// Cache key (`buildHash|NAME|args`).
  final String key;

  /// Upper-case formula name.
  final String formulaName;

  /// Dart function name.
  final String function;

  /// Arguments as script values (scalars, row-major 2-D lists).
  final List<Object?> args;
}

/// Summary of one evaluated batch (one `ScriptExecution` row with
/// `callCount`, 09 §13.1).
final class CustomFunctionBatchReport {
  /// Creates a report.
  const CustomFunctionBatchReport({
    required this.buildHash,
    required this.calls,
    required this.failures,
    required this.duration,
    required this.results,
  });

  /// Build that ran.
  final String buildHash;

  /// Calls evaluated.
  final int calls;

  /// Calls that failed or timed out.
  final int failures;

  /// Total time.
  final Duration duration;

  /// The individual results.
  final List<ExecutionResult> results;
}

/// Evaluates batches of custom function calls (the "pure guest", 09 §8.8).
abstract interface class CustomFunctionEvaluator {
  /// Evaluates [calls] of [program] sequentially, each with its own time
  /// limit; returns one formula value per call.
  Future<List<FValue>> evaluateBatch(
    ScriptProgram program,
    List<CustomFunctionCall> calls,
  );
}

/// [CustomFunctionEvaluator] on a [ScriptRunner]: every call is a pure
/// execution (no spreadsheet access, no UI, 3 s), whose result is converted
/// with [CellValueConverter.toFormula].
final class RunnerCustomFunctionEvaluator implements CustomFunctionEvaluator {
  /// Creates the evaluator.
  RunnerCustomFunctionEvaluator({
    required this.runner,
    required this.workbook,
    required this.user,
    this.fetcher,
    this.limits = ExecutionLimits.customFunction,
    this.batchLimit = const Duration(seconds: 30),
    this.timeZones = const TzDatabaseResolver(),
    this.onBatch,
  });

  /// Sandbox.
  final ScriptRunner runner;

  /// Workbook (for the time zone and locale only).
  final WorkbookAccess workbook;

  /// The viewer whose client evaluates (custom functions run for everyone).
  final ScriptUser user;

  /// Allowlisted fetches (09 §8.3 rule 8).
  final UrlFetcher? fetcher;

  /// Per-call limits (3 s).
  final ExecutionLimits limits;

  /// Time budget of one batch (30 s); later calls fail with a timeout.
  final Duration batchLimit;

  /// Offsets for date conversion.
  final TimeZoneResolver timeZones;

  /// Called after each batch (executions log).
  final void Function(CustomFunctionBatchReport report)? onBatch;

  @override
  Future<List<FValue>> evaluateBatch(
    ScriptProgram program,
    List<CustomFunctionCall> calls,
  ) async {
    final watch = Stopwatch()..start();
    final out = <FValue>[];
    final results = <ExecutionResult>[];
    var failures = 0;
    final converter = CellValueConverter(
      timeZone: workbook.model.spreadsheet.timeZone,
      timeZones: timeZones,
    );
    for (final call in calls) {
      if (watch.elapsed > batchLimit) {
        failures++;
        out.add(
          const FError(
            ErrorKind.parse,
            'Exceeded maximum execution time of the recalculation (30 s).',
          ),
        );
        continue;
      }
      final host = ScriptHost(
        workbook: workbook,
        context: ExecutionContext(
          kind: ExecutionKind.customFunction,
          activeUser: user,
          role: Role.viewer,
        ),
        limits: limits,
        fetcher: fetcher,
        timeZones: timeZones,
      );
      final r = await runScript(
        runner: runner,
        host: host,
        program: program,
        functionName: call.function,
        args: call.args,
      );
      results.add(r);
      if (r.ok) {
        out.add(converter.toFormula(r.result));
      } else {
        failures++;
        out.add(FError(ErrorKind.parse, r.error?.message ?? 'Script error'));
      }
    }
    onBatch?.call(
      CustomFunctionBatchReport(
        buildHash: program.buildHash,
        calls: calls.length,
        failures: failures,
        duration: watch.elapsed,
        results: results,
      ),
    );
    return out;
  }
}

/// The formula engine's custom function hook for script custom functions
/// (05 §13.6, 09 §8.6).
///
/// `lookup` answers from the cache synchronously; a miss returns null (the
/// cell shows `#LOADING`), and the misses of one recalculation pass are
/// evaluated as one batch (≤ [maxBatch] calls). Results are cached (LRU,
/// [maxCacheEntries]) and announced on [updates] by function name, so the
/// engine re-evaluates the calling cells.
final class ScriptCustomFunctions implements CustomFunctionProvider {
  /// Creates the provider.
  ScriptCustomFunctions({
    required this.evaluator,
    this.maxCacheEntries = 50000,
    this.maxBatch = 500,
    this.isBuiltin,
    this.disabledReason,
    TimeZoneResolver timeZones = const TzDatabaseResolver(),
    String timeZone = 'UTC',
  }) : _converter = CellValueConverter(
         timeZone: timeZone,
         timeZones: timeZones,
       );

  /// Runs batches.
  final CustomFunctionEvaluator evaluator;

  /// Cache size.
  final int maxCacheEntries;

  /// Calls per batch message.
  final int maxBatch;

  /// Built-ins shadow custom functions (09 §5).
  final bool Function(String upperName)? isBuiltin;

  /// When set (user disabled scripts, 09 §11.3), every call returns
  /// `#ERROR!` with this message.
  String? disabledReason;

  final CellValueConverter _converter;

  ScriptProgram? _program;
  Map<String, ScriptFunctionInfo> _byFormulaName = const {};
  final _cache = <String, FValue>{};
  final _pending = <String, CustomFunctionCall>{};
  final _inFlight = <String>{};
  final _updates = StreamController<String?>.broadcast(sync: false);
  Future<void>? _running;
  bool _scheduled = false;

  /// Names ever seen in a good build (09 §8.6 step 7).
  final Set<String> knownNames = {};

  /// The installed program (last good build).
  ScriptProgram? get program => _program;

  /// Exported custom function names (for autocomplete,
  /// `customFunctionNames` of the formula services).
  Iterable<String> get names => _byFormulaName.keys;

  /// Installs a new build (or none): clears the cache and dirties every
  /// cell with a custom function (05 §13.6).
  void setProgram(ScriptProgram? program) {
    if (program?.buildHash == _program?.buildHash) return;
    _program = program;
    _byFormulaName = {
      for (final e in (program?.exports.customFunctions ?? const {}).entries)
        if (isBuiltin?.call(e.key) != true) e.key: e.value,
    };
    knownNames.addAll(_byFormulaName.keys);
    _cache.clear();
    _pending.clear();
    _updates.add(null);
  }

  /// *Recalculate all*: re-evaluates every custom function call.
  void invalidateAll() {
    _cache.clear();
    _updates.add(null);
  }

  @override
  Stream<String?> get updates => _updates.stream;

  @override
  bool has(String upperName) =>
      _byFormulaName.containsKey(upperName) ||
      (knownNames.contains(upperName) && _program == null);

  @override
  FunctionHelp help(String upperName) {
    final f = _byFormulaName[upperName];
    if (f == null) {
      return FunctionHelp(summary: 'Script function', syntax: '$upperName()');
    }
    final args = [
      for (final p in f.params)
        ArgHelp(p.name, p.doc ?? '', optional: p.optional),
    ];
    return FunctionHelp(
      summary: f.doc ?? 'Custom function from the spreadsheet script.',
      syntax:
          '$upperName(${f.params.map((p) => p.optional ? '[${p.name}]' : p.name).join(', ')})',
      args: args,
      examples: f.customFunction?.examples ?? const [],
      notes: f.customFunction?.returnDoc,
    );
  }

  @override
  CustomFunctionResult? lookup(
    String upperName,
    List<FValue> args,
    String callerCellId,
  ) {
    final reason = disabledReason;
    if (reason != null) {
      return CustomFunctionResult(FError(ErrorKind.parse, reason));
    }
    final program = _program;
    final f = _byFormulaName[upperName];
    if (program == null || f == null) return null; // stays #LOADING
    final key = '${program.buildHash}|$upperName|${_argsKey(args)}';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // LRU touch
      return CustomFunctionResult(hit);
    }
    if (!_pending.containsKey(key) && !_inFlight.contains(key)) {
      _pending[key] = CustomFunctionCall(key, upperName, f.name, [
        for (final a in args) _converter.argToScript(a),
      ]);
      _schedule();
    }
    return null;
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    // After the current recalculation pass: one batch for all its misses.
    scheduleMicrotask(() {
      _scheduled = false;
      _running = (_running ?? Future.value()).then((_) => _drainPending());
    });
  }

  Future<void> _drainPending() async {
    while (_pending.isNotEmpty) {
      final program = _program;
      if (program == null) {
        _pending.clear();
        return;
      }
      final batch = _pending.values.take(maxBatch).toList();
      for (final c in batch) {
        _pending.remove(c.key);
        _inFlight.add(c.key);
      }
      final List<FValue> values;
      try {
        values = await evaluator.evaluateBatch(program, batch);
      } on Object catch (e) {
        for (final c in batch) {
          _inFlight.remove(c.key);
          _store(c.key, FError(ErrorKind.parse, 'Script error: $e'));
        }
        _announce(batch);
        continue;
      }
      for (var i = 0; i < batch.length; i++) {
        _inFlight.remove(batch[i].key);
        if (program.buildHash == _program?.buildHash) {
          _store(batch[i].key, values[i]);
        }
      }
      _announce(batch);
    }
  }

  void _announce(List<CustomFunctionCall> batch) {
    for (final name in {for (final c in batch) c.formulaName}) {
      _updates.add(name);
    }
  }

  void _store(String key, FValue value) {
    _cache[key] = value;
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Completes when no evaluation is pending (headless reads, tests).
  Future<void> idle() async {
    while (_scheduled || _pending.isNotEmpty || _inFlight.isNotEmpty) {
      await (_running ?? Future<void>.delayed(Duration.zero));
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Closes the update stream.
  Future<void> dispose() => _updates.close();

  static String _argsKey(List<FValue> args) {
    final b = StringBuffer();
    void write(FValue v) {
      switch (v) {
        case FNumber(:final v):
          b.write('n$v');
        case FText(:final v):
          b
            ..write('s${v.length}:')
            ..write(v);
        case FBool(:final v):
          b.write(v ? 'T' : 'F');
        case FError(:final kind, :final pending):
          b.write('e${kind.name}${pending ? '~' : ''}');
        case FArray():
          b.write('a${v.rows}x${v.cols}[');
          for (var r = 0; r < v.rows; r++) {
            for (var c = 0; c < v.cols; c++) {
              write(v.at(r, c));
              b.write(',');
            }
          }
          b.write(']');
        case FRich(:final scalar):
          write(scalar);
        default:
          b.write('_');
      }
    }

    for (final a in args) {
      write(a);
      b.write(';');
    }
    return b.toString();
  }
}
