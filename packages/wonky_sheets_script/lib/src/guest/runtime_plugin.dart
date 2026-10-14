import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';

import '../api/api_source.dart';
import 'cell_error_binding.dart';
import 'guest_bridge.dart';

/// Bridge declarations of `package:wonky/src/host.dart` shared by the
/// compiler plugin and the runtime plugin.
abstract final class WonkyHostDeclarations {
  /// `Object? wonkyHostCall(int target, String method, List<Object?> args)`.
  static const hostCall = BridgeFunctionDeclaration(
    wonkyHostLibrary,
    'wonkyHostCall',
    BridgeFunctionDef(
      returns: BridgeTypeAnnotation(
        BridgeTypeRef(CoreTypes.object),
        nullable: true,
      ),
      params: [
        BridgeParameter(
          'target',
          BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.int)),
          false,
        ),
        BridgeParameter(
          'method',
          BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.string)),
          false,
        ),
        BridgeParameter(
          'args',
          BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.list, [
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.object),
                nullable: true,
              ),
            ]),
          ),
          false,
        ),
      ],
    ),
  );

  /// `List<Object?>? wonkyHostError()`.
  static const hostError = BridgeFunctionDeclaration(
    wonkyHostLibrary,
    'wonkyHostError',
    BridgeFunctionDef(
      returns: BridgeTypeAnnotation(
        BridgeTypeRef(CoreTypes.list, [
          BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.object), nullable: true),
        ]),
        nullable: true,
      ),
    ),
  );
}

/// Holds the bridge of the execution that is currently running in a
/// runtime (a runtime is reused across executions of the same build).
final class GuestBridgeSlot {
  /// The current bridge.
  GuestBridge? current;

  GuestBridge get _bridge =>
      current ??
      (throw StateError('No script execution is running in this runtime.'));
}

/// The runtime half of the Wonky script plugin: registers the host bridge
/// functions, the `CellError` binding and the sandbox guards. Used by every
/// guest (client isolate, inline runner, server worker).
///
/// The compile-time half (`WonkyCompilerPlugin`) lives in
/// `package:wonky_sheets_script/compiler.dart`, which Flutter apps must not
/// import (it pulls in the analyzer).
final class WonkyRuntimePlugin implements EvalPlugin {
  /// Creates the plugin.
  WonkyRuntimePlugin(this.slot, {this.maxListLength = 10000000});

  /// Bridge of the running execution.
  final GuestBridgeSlot slot;

  /// Largest list a script may allocate in one call.
  final int maxListLength;

  @override
  String get identifier => 'wonky';

  @override
  void configureForCompile(BridgeDeclarationRegistry registry) {
    throw UnsupportedError(
      'Use WonkyCompilerPlugin (package:wonky_sheets_script/compiler.dart) '
      'to compile scripts.',
    );
  }

  @override
  void configureForRuntime(Runtime runtime) {
    runtime.registerBridgeFunc(
      wonkyHostLibrary,
      'wonkyHostCall',
      (rt, target, args) => slot._bridge.hostCall(rt, target, args),
    );
    runtime.registerBridgeFunc(
      wonkyHostLibrary,
      'wonkyHostError',
      (rt, target, args) => slot._bridge.hostError(rt, target, args),
    );
    $CellError.configureForRuntime(runtime);
    _configureGuards(runtime);
  }

  /// Allocation guards: `List.filled` / `List.generate` with huge lengths
  /// would exhaust memory before the watchdog notices (09 §21.2). Plugins
  /// run after dart_eval's own, so these registrations win.
  void _configureGuards(Runtime runtime) {
    void check(Object? n) {
      if (n is int && n > maxListLength) {
        throw ScriptAbort(
          'quotaExceeded',
          'Lists are limited to $maxListLength elements (asked for $n).',
        );
      }
    }

    runtime.registerBridgeFunc('dart:core', 'List.filled', (rt, target, args) {
      final length = args[0]?.$value as int;
      check(length);
      final growable = args[2]?.$value as bool? ?? false;
      return $List.wrap(List.filled(length, args[1], growable: growable));
    });
    runtime.registerBridgeFunc('dart:core', 'List.generate', (
      rt,
      target,
      args,
    ) {
      final length = args[0]?.$value as int;
      check(length);
      final generator = args[1]! as EvalCallable;
      final growable = args[2]?.$value as bool? ?? true;
      return $List.wrap(
        List.generate(
          length,
          (index) => generator.call(rt, null, [$int(index)]),
          growable: growable,
        ),
      );
    });
  }
}
