import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../helpers.dart';
import '../registry.dart';
import 'units.dart';

/// CONVERT (05 §15.15): Excel unit table with metric and binary prefixes.
void registerConvert(FunctionRegistryBuilder b) {
  b.fn(
    'CONVERT',
    'Converts a numeric value to a different unit of measure.',
    [
      P.num('value', 'The numeric value in start_unit to convert to end_unit.'),
      P.text(
        'start_unit',
        'The starting unit, the unit currently assigned to value (case-sensitive, e.g. "km", "lbm", "F", "Gibyte").',
      ),
      P.text(
        'end_unit',
        'The unit of measure into which to convert value. Must be of the same quantity as start_unit.',
      ),
    ],
    (a) {
      final x = a.number(0);
      final fromName = a.text(1), toName = a.text(2);
      final from = resolveUnit(fromName);
      if (from == null) {
        fail(ErrorKind.na, "Invalid units for conversion: '$fromName'.");
      }
      final to = resolveUnit(toName);
      if (to == null) {
        fail(ErrorKind.na, "Invalid units for conversion: '$toName'.");
      }
      final (fu, fBase) = from;
      final (tu, tBase) = to;
      if (fu.quantity != tu.quantity) {
        fail(
          ErrorKind.na,
          "Incompatible units for conversion: '$fromName' and '$toName'.",
        );
      }
      if (fu.quantity == Quantity.temperature) {
        final (fs, fo) = temperatureScales[fBase]!;
        final (ts, to0) = temperatureScales[tBase]!;
        final kelvin = x * fu.factor * fs + fo;
        return stableResult((kelvin - to0) / (ts * tu.factor));
      }
      if (identical(fu, tu)) return numResult(x);
      return stableResult(x * fu.factor / tu.factor);
    },
    examples: [
      'CONVERT(5.1, "g", "kg")',
      'CONVERT(32, "C", "F")',
      'CONVERT(1, "Gibyte", "Mibyte")',
    ],
    seeAlso: ['TO_PURE_NUMBER'],
  );
}
