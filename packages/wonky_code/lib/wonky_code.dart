/// Shared code highlighting for Wonky Work (pure Dart; Slides 07 §2, Write
/// 04 §15.5): languages, token classes, syntax palettes, the TextMate
/// tokenizer (engine copied from `syntax_highlight`, grammars embedded) and
/// the highlight.js fallback tokenizer; the monospace code grid
/// (`CodeLayout`, `MonoFontMetrics`, box geometry and auto size), line
/// highlight steps, edit scripts, the type-in simulation and the token
/// morph (Slides 07 §3–§5).
///
/// Flutter rendering (`CodeView`, `CodeTextStyler`) is in
/// `package:wonky_code_flutter`.
library;

export 'src/cached_code_tokenizer.dart';
export 'src/code_languages.dart';
export 'src/code_tokenizer.dart';
export 'src/default_code_tokenizer.dart';
export 'src/highlight_js/highlight_js_tokenizer.dart';
export 'src/layout/code_box.dart';
export 'src/layout/code_columns.dart';
export 'src/layout/code_layout.dart';
export 'src/layout/mono_font_metrics.dart';
export 'src/morph/code_lexemes.dart';
export 'src/morph/token_morph_plan.dart';
export 'src/palette/built_in_palettes.dart';
export 'src/palette/syntax_palette.dart';
export 'src/steps/highlight_steps.dart';
export 'src/syntax_token.dart';
export 'src/textmate/scope_classifier.dart';
export 'src/textmate/textmate_tokenizer.dart';
export 'src/typing/code_edit_script.dart';
export 'src/typing/typing_random.dart';
export 'src/typing/typing_script.dart';
export 'src/typing/typing_settings.dart';
