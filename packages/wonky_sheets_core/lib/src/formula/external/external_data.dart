import 'dart:async';

import '../functions/function_spec.dart';
import '../values/fvalue.dart';

/// Normalized identity of an external request (05 §13.1).
final class ExternalKey {
  /// Function name (`IMPORTRANGE`, `IMPORTDATA`, `AI`, `custom:MYFUNC`).
  final String function;

  /// Hash of the normalized arguments.
  final String argsHash;
  const ExternalKey(this.function, this.argsHash);

  @override
  bool operator ==(Object other) =>
      other is ExternalKey &&
      other.function == function &&
      other.argsHash == argsHash;

  @override
  int get hashCode => Object.hash(function, argsHash);

  @override
  String toString() => '$function:$argsHash';
}

/// Request details for an external fetch.
final class ExternalRequest {
  final String function;
  final List<FValue> args;

  /// Calling cell (`sheetId`, `rowId`, `colId`) for per-cell caches (AI).
  final String? callerSheetId;
  final String? callerRowId;
  final String? callerColId;
  const ExternalRequest(
    this.function,
    this.args, {
    this.callerSheetId,
    this.callerRowId,
    this.callerColId,
  });
}

/// A cached external result.
final class ExternalResult {
  /// Value (scalar or array; errors such as `#REF!` "You need to connect these sheets.").
  final FValue value;

  /// Whether the cached value is older than its refresh interval.
  final bool stale;
  const ExternalResult(this.value, {this.stale = false});
}

/// Source of async data for IMPORTRANGE, IMPORT*, AI (05 §13.1). The client implements it
/// over Serverpod with an offline cache; the server over its services; tests with fakes.
abstract interface class ExternalDataProvider {
  /// Returns a cached result if present (fresh or stale), else null.
  ExternalResult? lookup(ExternalKey key);

  /// Schedules a fetch (no-op when offline; the provider returns an offline error via
  /// [lookup] then).
  void request(ExternalKey key, ExternalRequest req);

  /// Keys whose results changed; the engine dirties dependent cells.
  Stream<ExternalKey> get updates;
}

/// Result of a custom function lookup (09 §8.6).
final class CustomFunctionResult {
  final FValue value;
  const CustomFunctionResult(this.value);
}

/// Script custom functions hook (09 §8.6).
abstract interface class CustomFunctionProvider {
  /// Known names (upper case) from the last good build.
  bool has(String upperName);

  /// Help for autocomplete and signature help.
  FunctionHelp help(String upperName);

  /// Cached value, or null after scheduling evaluation (the cell shows "Loading…").
  /// [args] are scalars or [FArray]s (ranges converted row-major). [callerCellId] is
  /// `sheetId:rowId:colId`.
  CustomFunctionResult? lookup(
    String upperName,
    List<FValue> args,
    String callerCellId,
  );

  /// Emits when results arrive or a new build is installed (null = everything changed).
  Stream<String?> get updates;
}

/// An in-memory provider for tests and offline previews.
final class MemoryExternalDataProvider implements ExternalDataProvider {
  final Map<ExternalKey, ExternalResult> results = {};
  final List<(ExternalKey, ExternalRequest)> requests = [];
  final StreamController<ExternalKey> _updates = StreamController.broadcast(
    sync: true,
  );

  @override
  ExternalResult? lookup(ExternalKey key) => results[key];

  @override
  void request(ExternalKey key, ExternalRequest req) =>
      requests.add((key, req));

  /// Completes a request.
  void complete(ExternalKey key, FValue value) {
    results[key] = ExternalResult(value);
    _updates.add(key);
  }

  @override
  Stream<ExternalKey> get updates => _updates.stream;
}

/// Data from pivot tables for GETPIVOTDATA (07 §7.8); implemented by the pivot engine.
abstract interface class PivotDataProvider {
  /// Returns the value or an error for the pivot whose output/anchor contains the cell.
  FValue getPivotData(
    String sheetId,
    int row,
    int col,
    String valueName,
    List<(String field, FValue item)> filters,
  );
}
