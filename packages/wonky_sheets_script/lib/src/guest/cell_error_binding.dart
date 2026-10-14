// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';

import '../api/api_source.dart';
import '../protocol/values.dart';

/// dart_eval wrapper of [CellError] (`CellError` in `package:wonky`).
final class $CellError implements $Instance {
  /// Wraps [$value].
  $CellError.wrap(this.$value);

  /// Compile-time type.
  static const $type = BridgeTypeRef(
    BridgeTypeSpec(wonkyHostLibrary, 'CellError'),
  );

  /// Compile-time declaration.
  static const $declaration = BridgeClassDef(
    BridgeClassType($type),
    constructors: {
      '': BridgeConstructorDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation($type),
          params: [
            BridgeParameter(
              'code',
              BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.string)),
              false,
            ),
            BridgeParameter(
              'message',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.string),
                nullable: true,
              ),
              true,
            ),
          ],
        ),
      ),
    },
    getters: {
      'code': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.string)),
        ),
      ),
      'message': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.string),
            nullable: true,
          ),
        ),
      ),
    },
    methods: {
      'toString': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.string)),
        ),
      ),
      '==': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.bool)),
          params: [
            BridgeParameter(
              'other',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.object),
                nullable: true,
              ),
              false,
            ),
          ],
        ),
      ),
    },
    wrap: true,
  );

  /// Registers the constructor in [runtime].
  static void configureForRuntime(Runtime runtime) {
    runtime.registerBridgeFunc(
      wonkyHostLibrary,
      'CellError.',
      (rt, target, args) => $CellError.wrap(
        CellError(
          args[0]!.$value as String,
          args.length > 1 ? args[1]?.$value as String? : null,
        ),
      ),
    );
  }

  @override
  final CellError $value;

  @override
  CellError get $reified => $value;

  late final $Instance _superclass = $Object($value);

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'code':
        return $String($value.code);
      case 'message':
        final m = $value.message;
        return m == null ? const $null() : $String(m);
      case 'toString':
        return $Function((rt, target, args) => $String($value.code));
      case '==':
        return $Function((rt, target, args) {
          final other = args.isEmpty ? null : args[0];
          return $bool(other is $CellError && other.$value == $value);
        });
    }
    return _superclass.$getProperty(runtime, identifier);
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) =>
      _superclass.$setProperty(runtime, identifier, value);

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType($type.spec!);
}
