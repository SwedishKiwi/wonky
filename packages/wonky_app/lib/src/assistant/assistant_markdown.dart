import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../markdown/wonky_markdown.dart';

export '../markdown/markdown_blocks.dart' show MarkdownBlocks, MdBlock, MdKind;

/// Renders assistant Markdown (streamed, so partial input must render):
/// headings, paragraphs, lists, quotes, fenced code with a copy button,
/// rules, tables (as aligned text) and inline bold / italic / strike /
/// code / links. Links are styled but not opened (single window).
///
/// A thin wrapper of [WonkyMarkdown] with [MarkdownProfile.assistant].
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown(this.text, {super.key, this.onCopyCode});

  final String text;

  /// Copies a code block (defaults to the clipboard).
  final void Function(String code)? onCopyCode;

  @override
  Widget build(BuildContext context) => WonkyMarkdown(
    text,
    profile: MarkdownProfile.assistant,
    onCopyCode: onCopyCode,
  );

  /// Inline Markdown as spans.
  static TextSpan inlineSpans(
    String text,
    TextStyle base,
    ShadColorScheme cs,
  ) => WonkyMarkdown.inlineSpans(text, base, cs);
}
