/// Code block tokenization for themed syntax highlighting in exports (06
/// §2.5, §6.3).
///
/// The highlight.js tokenizer moved to `package:wonky_code`
/// (`HighlightJsTokenizer`, Write 04 §15.5); these aliases keep the
/// exporters' API. Exports keep highlight.js until they switch to
/// `DefaultCodeTokenizer` in M10 (v2 review Q17/Q25).
library;

import 'package:wonky_code/wonky_code.dart';

export 'package:wonky_code/wonky_code.dart'
    show CodeToken, HighlightJsTokenizer;

/// The highlight.js tokenizer of the exporters (`HighlightJsTokenizer`).
typedef SyntaxHighlighter = HighlightJsTokenizer;

/// A highlighted range of a code string (`CodeToken`).
typedef SyntaxSpan = CodeToken;
