/// Wonky Delta Schema v1 attribute keys and typed helpers
/// (specs/wonky_write/02-document-model.md §1).
///
/// Moved to `package:wonky_rich_text` (Drive 05 D-7, v2 review Q4);
/// re-exported here so the `wonky_write_core` API is unchanged.
library;

export 'package:wonky_rich_text/wonky_rich_text.dart'
    show
        WonkyAttr,
        ListKind,
        BlockType,
        BlockFormat,
        SuggestionKind,
        SuggestionMark,
        Attributes;
