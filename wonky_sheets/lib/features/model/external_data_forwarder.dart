import 'dart:async';

import 'package:wonky_sheets_core/formula.dart';

/// The formula engine's external data hook (05 §13.1) for an open
/// spreadsheet, created with the session (the engine takes its provider at
/// construction) and pointed at the `AI()` cell provider by the AI feature
/// (Sheets 12 §6.8). Without a [target], and for functions the target does
/// not serve, external functions keep their offline `#N/A`.
class ForwardingExternalDataProvider implements ExternalDataProvider {
  final _updates = StreamController<ExternalKey>.broadcast(sync: true);
  ExternalDataProvider? _target;
  StreamSubscription<ExternalKey>? _sub;

  /// Functions the target serves (upper case).
  Set<String> functions = const {};

  static const _offline = ExternalResult(
    FError(ErrorKind.na, ErrorMessages.offline),
  );

  ExternalDataProvider? get target => _target;

  /// Points the hook at [value] for [served] functions.
  void attach(ExternalDataProvider? value, {Set<String> served = const {}}) {
    if (identical(value, _target)) return;
    unawaited(_sub?.cancel());
    _sub = null;
    _target = value;
    functions = value == null ? const {} : served;
    if (value != null) _sub = value.updates.listen(_forward);
  }

  void _forward(ExternalKey key) {
    if (!_updates.isClosed) _updates.add(key);
  }

  bool _serves(String function) => functions.contains(function);

  /// Functions that are not built yet answer `#NAME?` like without a
  /// provider (`web.dart`).
  static const _notYet = {'GOOGLETRANSLATE'};

  @override
  ExternalResult? lookup(ExternalKey key) {
    if (_serves(key.function)) return _target!.lookup(key);
    if (_notYet.contains(key.function)) {
      return ExternalResult(
        FError(ErrorKind.name, ErrorMessages.notAvailableYet(key.function)),
      );
    }
    return _offline;
  }

  @override
  void request(ExternalKey key, ExternalRequest req) {
    if (_serves(key.function)) _target!.request(key, req);
  }

  @override
  Stream<ExternalKey> get updates => _updates.stream;

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _target = null;
    await _updates.close();
  }
}
