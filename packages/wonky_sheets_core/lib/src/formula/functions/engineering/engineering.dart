import '../registry.dart';
import 'base_conversion.dart';
import 'bitwise.dart';
import 'complex.dart';
import 'erf.dart';

/// Engineering functions (05 §15.13).
void registerEngineering(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.engineering;
  registerBaseConversion(b);
  registerBitwise(b);
  registerErfAndSteps(b);
  registerComplex(b);
}
