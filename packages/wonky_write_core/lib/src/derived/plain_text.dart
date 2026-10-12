/// Plain-text rendering for search indexes and AI context (02 §5).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../collab/suggestion_view.dart';
import '../delta/delta_utils.dart';
import '../delta/document.dart';
import '../delta/embeds.dart';
import '../markdown/inline_markdown.dart';

/// Renders documents as readable plain text.
abstract final class PlainTextRenderer {
  /// Plain text of [document]: one line per line, soft breaks as `"\n"`,
  /// images as `[image: alt]`, dividers as `---`, tables as TSV (cells as
  /// plain text). Suggestions rendered per [view].
  static String render(
    Delta document, {
    SuggestionViewMode view = SuggestionViewMode.accepted,
  }) {
    final viewed = view == SuggestionViewMode.raw
        ? document
        : SuggestionView.render(document, view);
    final doc = WonkyDocument(viewed);
    final out = <String>[];
    for (final line in doc.lines) {
      if (line.isEmbedLine) {
        final e = line.embed;
        switch (e) {
          case ImageEmbed(:final alt):
            out.add(alt.isEmpty ? '[image]' : '[image: $alt]');
          case DividerEmbed():
            out.add('---');
          case TableEmbed():
            for (final row in e.padded().rows) {
              out.add(
                row
                    .map(
                      (c) =>
                          InlineMarkdown.toPlainText(c).replaceAll('\t', ' '),
                    )
                    .join('\t'),
              );
            }
          case null:
            break;
        }
        continue;
      }
      out.add(line.text.replaceAll(softBreak, '\n').replaceAll(embedChar, ''));
    }
    return out.join('\n');
  }
}
