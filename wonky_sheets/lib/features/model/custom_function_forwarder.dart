import 'dart:async';

import 'package:wonky_sheets_core/formula.dart';

/// The formula engine's custom function hook (09 §8.6) for an open
/// spreadsheet: created with the session (the engine takes its provider at
/// construction) and pointed at the script session's provider once the
/// script's last good build is installed. Without a [target] no name is a
/// custom function (`#NAME?` as before).
class ForwardingCustomFunctionProvider implements CustomFunctionProvider {
  final _updates = StreamController<String?>.broadcast(sync: true);
  CustomFunctionProvider? _target;
  StreamSubscription<String?>? _sub;

  /// The provider calls are forwarded to (the `ScriptSession`'s).
  CustomFunctionProvider? get target => _target;

  /// Names of the custom functions (formula autocomplete; the provider
  /// interface has no listing). Set with [target].
  Iterable<String> names = const [];

  set target(CustomFunctionProvider? value) {
    if (identical(value, _target)) return;
    unawaited(_sub?.cancel());
    _sub = null;
    _target = value;
    if (value == null) names = const [];
    if (value != null) _sub = value.updates.listen(_forward);
    // Every caller re-evaluates: names may have appeared or disappeared.
    _forward(null);
  }

  void _forward(String? name) {
    if (!_updates.isClosed) _updates.add(name);
  }

  @override
  bool has(String upperName) => _target?.has(upperName) ?? false;

  @override
  FunctionHelp help(String upperName) => _target!.help(upperName);

  @override
  CustomFunctionResult? lookup(
    String upperName,
    List<FValue> args,
    String callerCellId,
  ) => _target?.lookup(upperName, args, callerCellId);

  @override
  Stream<String?> get updates => _updates.stream;

  /// Detaches and closes the stream.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _target = null;
    names = const [];
    await _updates.close();
  }
}
