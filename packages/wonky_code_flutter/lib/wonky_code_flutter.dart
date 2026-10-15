/// Shared code rendering for Wonky Work (Flutter; Slides 07 §2.3, Write 04
/// §15.5): [CodeView] (read-only highlighted code for Drive previews and
/// Slides), [CodeTextStyler] (palette + mono font → text styles) and
/// `CodeEditorField` (in-place editing on re_editor, Slides 07 §3.5).
///
/// Re-exports `package:wonky_code/wonky_code.dart`.
library;

import 'src/code_text_styler.dart';
import 'src/code_view.dart';

export 'package:wonky_code/wonky_code.dart';

export 'src/code_editor_field.dart';
export 'src/code_text_styler.dart';
export 'src/code_view.dart';
