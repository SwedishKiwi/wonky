import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart'
    show SheetsAiCellRequest, SheetsAiCellResult, UuidValue;
import 'package:wonky_sheets_core/formula.dart';

import 'sheets_ai_api.dart';

/// The `=AI(prompt, ranges…)` cell function (Sheets 12 §6.8) on the client:
/// the formula engine's external data provider for `AI`. A call shows
/// `#LOADING` while its value is fetched in batches from
/// `sheetsAi.evaluateAiCells`; the server caches values by prompt and
/// referenced values, so a cell is only recomputed when its inputs change
/// or the user runs *Refresh AI cells*. Failures show `#N/A` with the
/// reason as tooltip (`#AI_ERROR!` in the spec); viewers see cached values
/// or keep "Waiting for an editor to calculate".
class AiCellsProvider implements ExternalDataProvider {
  AiCellsProvider({required SheetsAiApi Function() api, required this.itemUuid})
    // ignore: prefer_initializing_formals
    : _api = api;

  final SheetsAiApi Function() _api;
  final UuidValue itemUuid;

  /// Calls per request (`evaluateAiCells` limit).
  static const batch = 20;

  /// Requests arriving within this window are sent together.
  static const debounce = Duration(milliseconds: 250);

  static const waitingMessage = 'Waiting for an editor to calculate';

  final _updates = StreamController<ExternalKey>.broadcast(sync: true);
  final Map<ExternalKey, ExternalResult> _results = {};
  final Map<ExternalKey, ExternalRequest> _queue = {};
  final Set<ExternalKey> _inFlight = {};
  final Set<ExternalKey> _waiting = {};
  Timer? _timer;
  bool _refresh = false;
  bool _disposed = false;

  /// Calls sent so far (tests).
  @visibleForTesting
  int sentBatches = 0;

  @override
  ExternalResult? lookup(ExternalKey key) => _results[key];

  @override
  void request(ExternalKey key, ExternalRequest req) {
    if (_disposed || key.function != 'AI') return;
    if (_inFlight.contains(key) || _waiting.contains(key)) return;
    _queue[key] = req;
    _timer ??= Timer(debounce, () => unawaited(flush()));
  }

  @override
  Stream<ExternalKey> get updates => _updates.stream;

  /// Recomputes every `AI()` call (*Refresh AI cells*): drops the values
  /// and makes the engine ask again, bypassing the server cache.
  void refreshAll() {
    if (_disposed) return;
    final keys = {..._results.keys, ..._waiting};
    _results.clear();
    _waiting.clear();
    _refresh = true;
    for (final k in keys) {
      _updates.add(k);
    }
  }

  /// Sends the queued calls now.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _queue.isEmpty) return;
    final entries = _queue.entries.toList();
    _queue.clear();
    final refresh = _refresh;
    _refresh = false;
    for (var i = 0; i < entries.length; i += batch) {
      final part = entries.sublist(
        i,
        i + batch > entries.length ? entries.length : i + batch,
      );
      await _send(part, refresh: refresh);
    }
  }

  Future<void> _send(
    List<MapEntry<ExternalKey, ExternalRequest>> part, {
    required bool refresh,
  }) async {
    final byId = <String, ExternalKey>{};
    final requests = <SheetsAiCellRequest>[];
    for (final e in part) {
      final id = '${e.key.function}:${e.key.argsHash}';
      byId[id] = e.key;
      _inFlight.add(e.key);
      final args = e.value.args;
      requests.add(
        SheetsAiCellRequest(
          id: id,
          prompt: args.isEmpty ? '' : _text(args.first),
          valuesJson: jsonEncode([for (final a in args.skip(1)) _json(a)]),
        ),
      );
    }
    sentBatches++;
    List<SheetsAiCellResult> results;
    try {
      results = await _api().evaluateAiCells(
        itemUuid,
        requests,
        refresh: refresh,
      );
    } catch (e) {
      results = [
        for (final r in requests)
          SheetsAiCellResult(
            id: r.id,
            error: 'The AI service could not be reached.',
            cached: false,
          ),
      ];
    }
    if (_disposed) return;
    final answered = <ExternalKey>{};
    for (final r in results) {
      final key = byId[r.id];
      if (key == null) continue;
      answered.add(key);
      _inFlight.remove(key);
      final error = r.error;
      final value = r.value;
      if (error != null) {
        _results[key] = ExternalResult(FError(ErrorKind.na, error));
      } else if (value == null) {
        // Viewers: no cached value yet.
        _waiting.add(key);
        continue;
      } else {
        _results[key] = ExternalResult(valueOf(value));
      }
      _updates.add(key);
    }
    for (final key in byId.values) {
      if (!answered.contains(key)) _inFlight.remove(key);
    }
  }

  /// The cell value of a model answer: numbers stay numbers.
  static FValue valueOf(String text) {
    final t = text.trim();
    final n = double.tryParse(t);
    if (n != null && RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t)) return FNumber(n);
    if (t.toUpperCase() == 'TRUE') return FBool.t;
    if (t.toUpperCase() == 'FALSE') return FBool.f;
    return t.isEmpty ? FEmpty.instance : FText(t);
  }

  static String _text(FValue v) => switch (v) {
    FText(:final v) => v,
    FNumber(:final v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v',
    FBool(:final v) => v ? 'TRUE' : 'FALSE',
    FArray() => [
      for (var r = 0; r < v.rows; r++)
        [for (var c = 0; c < v.cols; c++) _text(v.at(r, c))].join('\t'),
    ].join('\n'),
    _ => '',
  };

  /// Canonical JSON of an argument (2-D arrays of primitives).
  static Object? _json(FValue v) => switch (v) {
    FArray() => [
      for (var r = 0; r < v.rows; r++)
        [for (var c = 0; c < v.cols; c++) _json(v.at(r, c))],
    ],
    FText(:final v) => v,
    FNumber(:final v) => v == v.roundToDouble() ? v.toInt() : v,
    FBool(:final v) => v,
    FError() => v.kind.literal,
    _ => null,
  };

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_updates.close());
  }
}
