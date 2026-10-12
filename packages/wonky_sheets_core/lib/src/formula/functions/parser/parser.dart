import '../registry.dart';
import 'convert.dart';
import 'to_functions.dart';

/// Parser functions (05 §15.15): CONVERT and the TO_* format conversions.
void registerParser(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.parser;
  registerConvert(b);
  registerToFunctions(b);
}
