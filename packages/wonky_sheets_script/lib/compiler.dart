/// Script compiler (server only, 09 §9): subset lint, exports extraction and
/// dart_eval compilation.
///
/// **Never import this library from Flutter apps**: it depends on the
/// analyzer (`tool/check_dependencies.dart` enforces it).
library;

export 'src/compiler/diagnostics.dart';
export 'src/compiler/script_compiler.dart';
export 'src/compiler/subset_lint.dart' show SubsetLint, allowedDartImports;
