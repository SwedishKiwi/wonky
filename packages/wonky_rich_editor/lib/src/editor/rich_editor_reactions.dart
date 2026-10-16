/// Markdown autoformat while typing (Write 04 §7, the lightweight subset).
library;

import 'package:super_editor/super_editor.dart';

import '../codec/inline_codec.dart';
import '../codec/markdown_document_codec.dart';
import '../codec/markdown_features.dart';

/// Whether [node] is a literal Markdown block (fenced code, tables, HTML …:
/// no autoformat, no inline styles).
bool isCodeLike(DocumentNode? node) =>
    node is ParagraphNode &&
    node.getMetadataValue(NodeMetadata.blockType) == codeAttribution;

/// Whether [node] is a plain paragraph (not a heading, quote or code).
bool isPlainParagraph(DocumentNode? node) =>
    node is ParagraphNode &&
    node.getMetadataValue(NodeMetadata.blockType) == paragraphAttribution;

/// Markdown block prefixes typed at the start of a paragraph (Write 04
/// §7.1): `# `…`###### `, `- ` `* ` `+ `, `1. ` `1) `, `> `, `[ ] ` `[] `
/// `[x] ` `- [ ] ` and `---` `***` `___` + space. A fence (```` ``` ````)
/// stays text: the editor has no code blocks (specs/16 §7.3).
/// The prefix must be exactly the text before the caret, right after the
/// space that was just typed. A task or heading prefix also converts a list
/// item. Headings, quotes and rules only where [features] allow them.
class BlockPrefixReaction extends EditReaction {
  BlockPrefixReaction(this.features);

  final MarkdownBlockFeatures Function() features;

  static final _heading = RegExp(r'^(#{1,6}) $');
  static final _bullet = RegExp(r'^[-*+] $');
  static final _ordered = RegExp(r'^\d{1,9}[.)] $');
  static final _quote = RegExp(r'^> $');
  static final _task = RegExp(r'^(- )?\[( |x|X)?\] $');
  static final _divider = RegExp(r'^(---|\*\*\*|___) $');

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final insertion = lastTypedCharacter(changeList);
    if (insertion == null || insertion.text.toPlainText() != ' ') return;
    final document = editorContext.document;
    final selection = editorContext.composer.selection;
    if (selection == null ||
        !selection.isCollapsed ||
        selection.extent.nodeId != insertion.nodeId) {
      return;
    }
    final node = document.getNodeById(insertion.nodeId);
    final caret = selection.extent.nodePosition;
    if (node is! TextNode || caret is! TextNodePosition || isCodeLike(node)) {
      return;
    }
    final f = features();
    final prefix = node.text.toPlainText().substring(0, caret.offset);
    final paragraph = isPlainParagraph(node);
    final rest = node.text.copyText(prefix.length);
    final requests = <EditRequest>[];
    var deletePrefix = true;
    Match? match;
    if (f.headings &&
        (match = _heading.firstMatch(prefix)) != null &&
        (paragraph || node is ListItemNode || node is TaskNode)) {
      final level = match!.group(1)!.length;
      final type = MarkdownDocumentCodec.headerAttribution(level);
      if (node is ParagraphNode) {
        requests.add(
          ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: type),
        );
      } else {
        deletePrefix = false;
        requests.add(
          ReplaceNodeRequest(
            existingNodeId: node.id,
            newNode: ParagraphNode(
              id: node.id,
              text: rest,
              metadata: {NodeMetadata.blockType: type},
            ),
          ),
        );
      }
    } else if (_bullet.hasMatch(prefix) && paragraph) {
      requests.add(
        ConvertParagraphToListItemRequest(
          nodeId: node.id,
          type: ListItemType.unordered,
        ),
      );
    } else if (_ordered.hasMatch(prefix) && paragraph) {
      requests.add(
        ConvertParagraphToListItemRequest(
          nodeId: node.id,
          type: ListItemType.ordered,
        ),
      );
    } else if (f.quotes && _quote.hasMatch(prefix) && paragraph) {
      requests.add(
        ChangeParagraphBlockTypeRequest(
          nodeId: node.id,
          blockType: blockquoteAttribution,
        ),
      );
    } else if ((match = _task.firstMatch(prefix)) != null &&
        (paragraph || node is ListItemNode)) {
      deletePrefix = false;
      requests.add(
        ReplaceNodeRequest(
          existingNodeId: node.id,
          newNode: TaskNode(
            id: node.id,
            text: rest,
            isComplete: (match!.group(2) ?? ' ').toLowerCase() == 'x',
            indent: node is ListItemNode ? node.indent : 0,
          ),
        ),
      );
    } else if (f.rules &&
        _divider.hasMatch(prefix) &&
        paragraph &&
        node.text.length == prefix.length) {
      requests.add(
        InsertNodeAtIndexRequest(
          nodeIndex: document.getNodeIndexById(node.id),
          newNode: HorizontalRuleNode(id: Editor.createNodeId()),
        ),
      );
    } else {
      return;
    }

    requestDispatcher.execute([
      if (deletePrefix)
        DeleteContentRequest(
          documentRange: DocumentRange(
            start: DocumentPosition(
              nodeId: node.id,
              nodePosition: const TextNodePosition(offset: 0),
            ),
            end: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: prefix.length),
            ),
          ),
        ),
      ...requests,
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: node.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

/// The last change of [changeList] when it is one typed character (a paste
/// or an IME replacement of several characters is not autoformatted).
TextInsertionEvent? lastTypedCharacter(List<EditEvent> changeList) {
  for (var i = changeList.length - 1; i >= 0; i -= 1) {
    final event = changeList[i];
    if (event is DocumentEdit) {
      final change = event.change;
      return change is TextInsertionEvent && change.text.length == 1
          ? change
          : null;
    }
  }
  return null;
}

/// Inline Markdown typed right before the caret becomes styles as soon as
/// the closing delimiter is typed (Write 04 §7.2): `**bold**` `__bold__`,
/// `*italic*` `_italic_` (not inside words), `~~strike~~` `~strike~`,
/// `` `code` `` and `[text](url)` (a link only for a URL the codec accepts,
/// [normalizeLinkTarget]). The delimiters must not be inside inline code,
/// and an opening delimiter starts the text or follows a space or `(`.
class InlineMarkdownReaction extends EditReaction {
  const InlineMarkdownReaction();

  static final _patterns = <(RegExp, Attribution)>[
    (RegExp(r'(?:^|(?<=[\s(]))`([^`]+)`$'), codeAttribution),
    (RegExp(r'(?:^|(?<=[\s(]))\*\*(?=\S)(.+?)(?<=\S)\*\*$'), boldAttribution),
    (RegExp(r'(?:^|(?<=[\s(]))__(?=\S)(.+?)(?<=\S)__$'), boldAttribution),
    (
      RegExp(r'(?:^|(?<=[\s(]))(~~?)(?=[^\s~])(.+?)(?<=[^\s~])\1$'),
      strikethroughAttribution,
    ),
    (
      RegExp(r'(?:^|(?<=[\s(]))\*(?=[^\s*])(.+?)(?<=[^\s*])\*$'),
      italicsAttribution,
    ),
    (
      RegExp(r'(?:^|(?<=[\s(]))_(?=[^\s_])(.+?)(?<=[^\s_])_$'),
      italicsAttribution,
    ),
  ];

  static final _link = RegExp(r'\[([^\[\]]+)\]\(([^()\s]+)\)$');

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    final insertion = lastTypedCharacter(changeList);
    if (insertion == null) return;
    final selection = editorContext.composer.selection;
    if (selection == null ||
        !selection.isCollapsed ||
        selection.extent.nodeId != insertion.nodeId) {
      return;
    }
    final node = editorContext.document.getNodeById(insertion.nodeId);
    final caret = selection.extent.nodePosition;
    if (node is! TextNode || caret is! TextNodePosition || isCodeLike(node)) {
      return;
    }
    final text = node.text;
    // Only the current line counts.
    final plain = text.toPlainText().substring(0, caret.offset);
    final lineStart = plain.lastIndexOf('\n') + 1;
    final before = plain.substring(lineStart);

    int? start;
    AttributedText? replacement;
    final link = _link.firstMatch(before);
    if (link != null) {
      final target = normalizeLinkTarget(link.group(2)!);
      if (target == null) return;
      start = lineStart + link.start;
      final label = text.copyText(start + 1, start + 1 + link.group(1)!.length);
      replacement = label
        ..addAttribution(
          LinkAttribution(target),
          SpanRange(0, label.length - 1),
          overwriteConflictingSpans: true,
        );
    } else {
      for (final (pattern, attribution) in _patterns) {
        final m = pattern.firstMatch(before);
        if (m == null) continue;
        final inner = m.group(m.groupCount)!;
        final s = lineStart + m.start;
        final delimiter = (m.group(0)!.length - inner.length) ~/ 2;
        // `***x**`: the extra delimiter belongs to something else.
        if (s > 0 && plain[s - 1] == m.group(0)![0]) return;
        bool code(int i) =>
            text.hasAttributionAt(i, attribution: codeAttribution);
        if (code(s) || code(caret.offset - 1)) return;
        start = s;
        replacement = text.copyText(
          s + delimiter,
          s + delimiter + inner.length,
        );
        if (attribution == codeAttribution) {
          replacement = AttributedText(replacement.toPlainText());
        }
        replacement.addAttribution(
          attribution,
          SpanRange(0, replacement.length - 1),
        );
        break;
      }
    }
    if (start == null || replacement == null) return;
    final end = DocumentPosition(
      nodeId: node.id,
      nodePosition: TextNodePosition(offset: start + replacement.length),
    );
    requestDispatcher.execute([
      DeleteContentRequest(
        documentRange: DocumentRange(
          start: DocumentPosition(
            nodeId: node.id,
            nodePosition: TextNodePosition(offset: start),
          ),
          end: DocumentPosition(
            nodeId: node.id,
            nodePosition: TextNodePosition(offset: caret.offset),
          ),
        ),
      ),
      InsertAttributedTextRequest(
        DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: start),
        ),
        replacement,
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: end),
        SelectionChangeType.alteredContent,
        SelectionReason.contentChange,
      ),
      ChangeComposingRegionRequest(DocumentRange(start: end, end: end)),
    ]);
    // Typing after the converted text is not styled.
    editorContext.composer.preferences.clearStyles();
  }
}

/// Runs [inner] only while the caret is outside literal blocks
/// (inline Markdown and autolinks don't apply there).
class OutsideCodeReaction extends EditReaction {
  const OutsideCodeReaction(this.inner);

  final EditReaction inner;

  bool _inCode(EditContext context) {
    final selection = context.composer.selection;
    if (selection == null) return false;
    return isCodeLike(context.document.getNodeById(selection.extent.nodeId));
  }

  @override
  void modifyContent(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    if (!_inCode(editorContext)) {
      inner.modifyContent(editorContext, requestDispatcher, changeList);
    }
  }

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    if (!_inCode(editorContext)) {
      inner.react(editorContext, requestDispatcher, changeList);
    }
  }
}
