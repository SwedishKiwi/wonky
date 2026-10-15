/// Code block tokenization for themed syntax highlighting in exports and
/// print (06 §2.5, §6.3; Write 07).
///
/// Since M10 (Slides SL-35, v2 review Q17/Q25) the exporters tokenize with
/// the shared [DefaultCodeTokenizer] of `package:wonky_code` — TextMate
/// first, highlight.js for the other languages — like Write's editor and
/// Wonky Slides, so exported token colors match the screen. Before M10 they
/// used highlight.js ([HighlightJsTokenizer]) for every language.
library;

import 'dart:async';

import 'package:wonky_code/wonky_code.dart';

export 'package:wonky_code/wonky_code.dart'
    show CodeToken, CodeTokenizer, DefaultCodeTokenizer, HighlightJsTokenizer;

/// A highlighted range of a code string (`CodeToken`).
typedef SyntaxSpan = CodeToken;

/// The tokenizer of Write's exporters (PDF and print, HTML, EPUB, DOCX,
/// ODT, RTF).
///
/// Wraps [DefaultCodeTokenizer] in a small [CachedCodeTokenizer]: a PDF
/// export lays the document out up to three times (table of contents page
/// numbers) and print previews re-export, so the same blocks are tokenized
/// again. Languages are normalized ([CodeLanguages.normalize]) the way the
/// editor stores them, so `JS` in an imported fence highlights like
/// `javascript`.
final class SyntaxHighlighter {
  SyntaxHighlighter._();

  /// The shared highlighter of the exporters.
  static final SyntaxHighlighter instance = SyntaxHighlighter._();

  static final CodeTokenizer _shared = CachedCodeTokenizer(capacity: 32);

  static final Object _zoneKey = Object();

  /// The tokenizer in effect: [_shared] unless [withTokenizer] overrides it.
  CodeTokenizer get tokenizer =>
      (Zone.current[_zoneKey] as CodeTokenizer?) ?? _shared;

  /// Tokens of [code] in [language] (a code block's language as stored):
  /// sorted, disjoint, non-empty ranges; empty for plain text and unknown
  /// languages. Never throws.
  List<SyntaxSpan> tokenize(String code, String language) =>
      tokenizer.tokenize(code, CodeLanguages.normalize(language));

  /// Runs [body] with exports tokenizing through [tokenizer] instead of the
  /// shared one (the export diff review compares tokenizers, SL-35). The
  /// override follows [body]'s asynchronous work (a zone value).
  static T withTokenizer<T>(CodeTokenizer tokenizer, T Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: tokenizer});
}
