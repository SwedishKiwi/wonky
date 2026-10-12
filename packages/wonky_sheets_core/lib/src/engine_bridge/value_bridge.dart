import '../content/cell_content.dart';
import '../formula/values/errors.dart';
import '../formula/values/fvalue.dart';

/// Conversions between the formula engine's [FValue] and the model's scalar
/// [CellValue] (used by the number formatter, CF, filters, charts, exports).
extension FValueToCellValue on FValue {
  /// The scalar seen by consumers: arrays → top-left, rich values → their
  /// scalar, references/lambdas → errors, pending → `#LOADING`.
  CellValue toCellValue() {
    final v = this;
    return switch (v) {
      FNumber(:final v) => v.isFinite ? NumberValue(v) : const ErrorValue(CellErrorKind.num),
      FText(:final v) => TextValue(v),
      FBool(:final v) => BoolValue(v),
      FError(:final kind, :final message, :final pending) => ErrorValue(
        pending ? CellErrorKind.loading : _kindOf(kind),
        message,
      ),
      FEmpty() || FOmitted() => const EmptyValue(),
      FArray() => v.topLeft.toCellValue(),
      FRich(:final scalar) => scalar.toCellValue(),
      FRef() => const ErrorValue(CellErrorKind.value),
      FLambda() => const ErrorValue(CellErrorKind.calc),
    };
  }
}

/// [CellValue] → [FValue].
extension CellValueToFValue on CellValue {
  /// The engine value.
  FValue toFValue() {
    final v = this;
    return switch (v) {
      EmptyValue() => FEmpty.instance,
      NumberValue(:final number) => FNumber(number),
      TextValue(:final text) => FText(text),
      BoolValue(:final value) => FBool(value),
      ErrorValue(:final kind, :final message) => switch (kind) {
        CellErrorKind.loading => const FError.pending(),
        CellErrorKind.blocked => FError(ErrorKind.ref, message ?? 'Blocked'),
        _ => FError(ErrorKind.values.byName(kind.name), message),
      },
    };
  }
}

CellErrorKind _kindOf(ErrorKind k) {
  for (final c in CellErrorKind.values) {
    if (c.name == k.name) return c;
  }
  return CellErrorKind.value;
}
