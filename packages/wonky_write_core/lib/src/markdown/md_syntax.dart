/// The `package:markdown` configuration used by the codec.
///
/// Moved to `package:wonky_rich_text` (Drive 05 D-7, v2 review Q4);
/// re-exported here so the `wonky_write_core` API is unchanged.
library;

export 'package:wonky_rich_text/wonky_rich_text.dart'
    show wonkyGfm, parseMarkdownAst, decodeMdEntities;
