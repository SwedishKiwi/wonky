/// Shared code highlighting for Wonky Work (pure Dart; Slides 07 §2, Write
/// 04 §15.5): languages, token classes, syntax palettes, the TextMate
/// tokenizer (engine copied from `syntax_highlight`, grammars embedded) and
/// the highlight.js fallback tokenizer.
///
/// Flutter rendering (`CodeView`, `CodeTextStyler`) is in
/// `package:wonky_code_flutter`.
library;

export 'src/code_languages.dart';
export 'src/code_tokenizer.dart';
export 'src/default_code_tokenizer.dart';
export 'src/highlight_js/highlight_js_tokenizer.dart';
export 'src/palette/built_in_palettes.dart';
export 'src/palette/syntax_palette.dart';
export 'src/syntax_token.dart';
export 'src/textmate/scope_classifier.dart';
export 'src/textmate/textmate_tokenizer.dart';
