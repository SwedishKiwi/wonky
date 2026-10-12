/// Plain-text import (07 §3.4).
library;

import 'dart:typed_data';

import '../ir/doc_tree.dart';
import 'encoding.dart';
import 'import_api.dart';
import 'import_support.dart';

/// Imports plain text without Markdown interpretation.
///
/// - [ImportOptions.txtLineBreaks] `paragraph` (default): each line becomes
///   a paragraph (blank lines become empty paragraphs). `soft`: blocks
///   separated by blank lines become paragraphs; single line breaks inside a
///   block become soft breaks (U+2028). Paste uses `soft` (07 §3.9).
/// - Tabs → 4 spaces, control characters removed, CRLF/CR → LF.
/// - Title: the file name without extension.
final class TxtImporter implements DocumentImporter {
  /// Creates the importer.
  const TxtImporter();

  @override
  ImportFormat get format => ImportFormat.txt;

  @override
  Future<ImportResult> import(Uint8List bytes, ImportOptions options) async {
    final decoded = ImportTextDecoder.decode(bytes);
    return importText(
      decoded.text,
      options,
      extraWarnings: [?decoded.warning],
    );
  }

  /// Imports already decoded [text] (paste, tests).
  ImportResult importText(
    String text,
    ImportOptions options, {
    List<ImportWarning> extraWarnings = const [],
  }) {
    final warnings = WarningCollector();
    extraWarnings.forEach(warnings.addWarning);
    var source = ImportTextDecoder.normalizeLineEndings(text);
    if (source.startsWith('\uFEFF')) source = source.substring(1);
    source = source.replaceAll('\u2029', '\n');
    final lines = source.split('\n');
    if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
    final blocks = <DocBlock>[];
    ParagraphBlock para(String s) {
      final t = ImportText.inline(s);
      return ParagraphBlock(t.isEmpty ? const [] : [InlineRun(t)]);
    }

    switch (options.txtLineBreaks) {
      case TxtLineBreaks.paragraph:
        for (final l in lines) {
          blocks.add(para(l));
        }
      case TxtLineBreaks.soft:
        final current = <String>[];
        void flush() {
          if (current.isEmpty) return;
          blocks.add(para(current.join(importSoftBreak)));
          current.clear();
        }

        for (final l in lines) {
          if (l.trim().isEmpty) {
            flush();
          } else {
            current.add(l);
          }
        }
        flush();
    }
    if (blocks.isEmpty) blocks.add(const ParagraphBlock([]));
    return buildImportResult(
      blocks,
      options: options,
      warnings: warnings,
      title: fileTitle(options.fileName),
    );
  }
}

/// Whether plain [text] looks like Markdown (07 §3.4): at least 3 of
/// `#` headings, `- ` lists, fenced code, `**` emphasis and `[x](y)` links.
/// Used for the *Import as Markdown* toggle and Markdown-aware paste.
bool looksLikeMarkdown(String text) {
  var score = 0;
  if (RegExp(r'^ {0,3}#{1,6}[ \t]+\S', multiLine: true).hasMatch(text)) {
    score++;
  }
  if (RegExp(r'^ {0,3}[-*+][ \t]+\S', multiLine: true).hasMatch(text)) {
    score++;
  }
  if (RegExp(r'^ {0,3}(```|~~~)', multiLine: true).hasMatch(text)) score++;
  if (RegExp(r'\*\*\S(?:.*?\S)?\*\*').hasMatch(text)) score++;
  if (RegExp(r'\[[^\]\n]+\]\([^)\s]+(?:\s+"[^"]*")?\)').hasMatch(text)) {
    score++;
  }
  return score >= 3;
}
