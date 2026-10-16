/// Wonky Work's lightweight WYSIWYG Markdown editor (specs/16 §7.3): a
/// Markdown ⇄ super_editor document codec ([MarkdownDocumentCodec]), a
/// controller holding the Markdown ([MarkdownEditingController]) and the
/// [WonkyRichEditor] field with its formatting toolbar, and the
/// super_editor spelling glue ([DocumentSpelling], [spellingMenuEntries])
/// shared with Slides.
library;

export 'src/codec/inline_codec.dart'
    show InlineMarkdownCodec, isSafeLink, normalizeLinkTarget;
export 'src/codec/markdown_document_codec.dart';
export 'src/codec/markdown_features.dart';
export 'src/editor/markdown_editing_controller.dart';
export 'src/editor/rich_editor_reactions.dart'
    show BlockPrefixReaction, isCodeLike, isPlainParagraph;
export 'src/spelling/document_spelling.dart';
export 'src/spelling/spelling_menu.dart';
export 'src/widgets/rich_editor_style.dart' show RichEditorStyle;
export 'src/widgets/wonky_rich_editor.dart';
