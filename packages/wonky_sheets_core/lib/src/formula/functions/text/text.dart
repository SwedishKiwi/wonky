import '../registry.dart';
import 'basic.dart';
import 'format.dart';
import 'join_split.dart';
import 'regex.dart';
import 'substrings.dart';

/// Text functions (05 §15.5). ROMAN and ARABIC are registered with the math functions.
void registerText(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.text;
  registerTextBasic(b);
  registerSubstrings(b);
  registerJoinSplit(b);
  registerRegex(b);
  registerTextFormat(b);
}
