import 'package:wonky_app/spellcheck.dart';

import '../text_editing/slide_text_editor.dart' show SlideTextEditAddon;
import 'slides_spelling.dart';

export 'package:wonky_app/spellcheck.dart' show spellingErrorColor;

/// Spelling squiggles of one super_editor document (Slides 03 §14): the
/// text being edited on the canvas (text boxes, shapes, placeholders and
/// table cells — SL-13's overlay) and the speaker notes being edited.
///
/// The suite's [DocumentSpelling] (`wonky_rich_editor`, shared with the
/// Markdown composer) over the deck's [SlidesSpelling], as an addon of a
/// text editing session: changed paragraphs are checked after the frame
/// that changed them, the word being typed is held back, links and inline
/// code are skipped; with *Underline errors* off nothing is underlined.
class EditorSpelling extends DocumentSpelling implements SlideTextEditAddon {
  EditorSpelling({
    required super.document,
    required super.composer,
    required SlidesSpelling spelling,
  }) : super(checker: spelling);

  /// The deck's spell checker.
  SlidesSpelling get spelling => checker as SlidesSpelling;
}
