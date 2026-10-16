/// The Markdown text of a [WonkyRichEditor] and the editing operations of
/// its toolbar and shortcuts.
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextAffinity;
import 'package:super_editor/super_editor.dart';

import '../codec/inline_codec.dart';
import '../codec/markdown_document_codec.dart';
import '../codec/markdown_features.dart';
import 'rich_editor_reactions.dart';

/// Inline styles of the toolbar.
enum InlineFormat { bold, italic, strikethrough, code }

/// Block kinds of the toolbar.
enum BlockFormat {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  taskList,
  quote,
}

/// The Markdown of a rich text field, like a `TextEditingController` holds
/// a text field's text (specs/16 §7.3).
///
/// [markdown] reads the document as Markdown ([MarkdownDocumentCodec]):
/// until the user edits, it is exactly the text that was set; afterwards
/// only the edited blocks are rewritten. Setting it replaces the content
/// (one local undo step) and puts the caret at the end.
///
/// Undo and redo are the field's own ([undo], [redo]): typing within a
/// second is one step, every format change and autoformat one more; the
/// shell's undo stack is not involved (suite 08 — text fields keep their
/// own local undo).
///
/// Listeners are notified on every change of the content, the selection
/// and the typing styles (the toolbar's state).
class MarkdownEditingController extends ChangeNotifier {
  MarkdownEditingController({
    String markdown = '',
    MarkdownBlockFeatures features = MarkdownBlockFeatures.all,
  }) : _features = features,
       _source = markdown {
    document = MutableDocument(
      nodes: MarkdownDocumentCodec(features: features).decodeNodes(markdown),
    );
    composer = MutableDocumentComposer();
    editor = Editor(
      editables: {Editor.documentKey: document, Editor.composerKey: composer},
      requestHandlers: [
        _guard,
        (editor, request) => request is ReplaceDocumentRequest
            ? ReplaceDocumentCommand(request.nodes)
            : null,
        _literalNewline,
        ...defaultRequestHandlers.cast<EditRequestHandler>(),
      ],
      reactionPipeline: [
        UpdateComposerTextStylesReaction(),
        const OutsideCodeReaction(LinkifyReaction()),
        BlockPrefixReaction(() => _features),
        const InlineMarkdownReaction(),
        UpdateSubTaskIndentAfterTaskDeletionReaction(),
      ],
      isHistoryEnabled: true,
      historyGroupingPolicy: const _HistoryPolicy(),
    );
    editor.addListener(FunctionalEditListener(_onEdit));
    composer.preferences.addListener(notifyListeners);
  }

  late final MutableDocument document;
  late final MutableDocumentComposer composer;
  late final Editor editor;

  MarkdownBlockFeatures _features;

  /// The blocks the field supports (comments: no headings, quotes, rules).
  MarkdownBlockFeatures get features => _features;
  set features(MarkdownBlockFeatures value) {
    if (value == _features) return;
    final text = markdown;
    _features = value;
    _replace(text);
  }

  MarkdownDocumentCodec get codec => MarkdownDocumentCodec(features: _features);

  /// Refuses edits (the selection still moves).
  bool readOnly = false;

  /// Refuses typing once [markdown] is this long (a paste that would pass
  /// it is refused too).
  int? maxLength;

  String _source;
  bool _edited = false;
  String? _cache;
  bool _external = false;

  /// The content as Markdown.
  String get markdown {
    if (!_edited) return _source;
    return _cache ??= codec.encode(document);
  }

  /// Replaces the content with [value] (caret at the end).
  set markdown(String value) {
    if (value == markdown) return;
    _replace(value);
  }

  /// The length of [markdown].
  int get length => markdown.length;

  /// Whether the content is empty.
  bool get isEmpty => markdown.trim().isEmpty;

  void _replace(String value) {
    final nodes = codec.decodeNodes(value);
    _run([
      ReplaceDocumentRequest(nodes),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: _endOf(nodes.last)),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ]);
    _source = value;
    _edited = false;
    _cache = null;
    notifyListeners();
  }

  /// Runs [requests] past the read-only and length guards.
  void _run(List<EditRequest> requests) {
    _external = true;
    try {
      editor.execute(requests);
    } finally {
      _external = false;
    }
  }

  void _onEdit(List<EditEvent> changes) {
    // Undo and redo report no changes.
    final content = changes.isEmpty || changes.any((e) => e is DocumentEdit);
    if (content) {
      _cache = null;
      if (!_external) _edited = true;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- guards

  EditCommand? _guard(Editor editor, EditRequest request) {
    if (_external) return null;
    if (readOnly && !_isNonMutating(request)) return const _NoOpCommand();
    final max = maxLength;
    if (max != null && _isTyping(request) && length >= max) {
      return const _NoOpCommand();
    }
    return null;
  }

  static bool _isNonMutating(EditRequest r) =>
      r is ChangeSelectionRequest ||
      r is ClearSelectionRequest ||
      r is ChangeComposingRegionRequest ||
      r is ClearComposingRegionRequest ||
      r is ChangeInteractionModeRequest ||
      r is RemoveComposerPreferenceStylesRequest;

  static bool _isTyping(EditRequest r) =>
      r is InsertTextRequest ||
      r is InsertCharacterAtCaretRequest ||
      r is InsertPlainTextAtCaretRequest ||
      r is InsertStyledTextAtCaretRequest ||
      r is InsertNewlineAtCaretRequest ||
      r is InsertSoftNewlineAtCaretRequest ||
      r is PasteEditorRequest;

  /// Enter in a literal block inserts a line break at the caret.
  /// super_editor's code-block newline always appends it at the block's end
  /// (and Enter over a selection there did the same); at the end of the
  /// block its rules stay (a second Enter leaves the block).
  EditCommand? _literalNewline(Editor editor, EditRequest request) {
    if (request is! InsertNewlineAtCaretRequest) return null;
    final s = composer.selection;
    if (s == null) return null;
    final base = document.getNodeById(s.base.nodeId);
    final extent = document.getNodeById(s.extent.nodeId);
    if (!isCodeLike(base) && !isCodeLike(extent)) return null;
    return _LiteralNewlineCommand(request.newNodeId);
  }

  // ------------------------------------------------------------ history

  bool _hasContent(CommandTransaction t) =>
      t.changes.any((c) => c is DocumentEdit);

  /// Whether [undo] changes something.
  bool get canUndo => editor.history.any(_hasContent);

  /// Whether [redo] changes something.
  bool get canRedo => editor.future.any(_hasContent);

  /// Undoes the last change of the field.
  void undo() {
    while (editor.history.isNotEmpty) {
      final content = _hasContent(editor.history.last);
      editor.undo();
      if (content) break;
    }
  }

  /// Redoes the last undone change of the field.
  void redo() {
    while (editor.future.isNotEmpty) {
      final content = _hasContent(editor.future.last);
      editor.redo();
      if (content) break;
    }
  }

  // ---------------------------------------------------------- selection

  DocumentSelection? get selection => _liveSelection;

  /// The composer's selection, or null when it points at a node that is no
  /// longer in the document. After a block is deleted (a literal block, a
  /// selection across blocks) the toolbar can rebuild before the editor
  /// moves the selection, and normalizing a stale selection throws.
  DocumentSelection? get _liveSelection {
    final s = composer.selection;
    if (s == null) return null;
    if (document.getNodeById(s.base.nodeId) == null ||
        document.getNodeById(s.extent.nodeId) == null) {
      return null;
    }
    return s;
  }

  static DocumentPosition _endOf(DocumentNode node) =>
      DocumentPosition(nodeId: node.id, nodePosition: node.endPosition);

  /// Puts the caret at the end of the content.
  void moveCaretToEnd() {
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: _endOf(document.last)),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  /// Selects the whole content.
  void selectAll() {
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: document.first.id,
            nodePosition: document.first.beginningPosition,
          ),
          extent: _endOf(document.last),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  DocumentRange? get _range {
    final s = _liveSelection;
    if (s == null || s.isCollapsed) return null;
    return s.normalize(document);
  }

  /// The text nodes of the selection (the caret's node when collapsed).
  List<TextNode> get _selectedTextNodes {
    final s = _liveSelection;
    if (s == null) return const [];
    final r = s.normalize(document);
    return document
        .getNodesInside(r.start, r.end)
        .whereType<TextNode>()
        .toList();
  }

  /// The `[start, end)` offsets of the selection inside [node].
  (int, int) _rangeIn(TextNode node, DocumentRange r) {
    final start = r.start.nodeId == node.id
        ? (r.start.nodePosition as TextNodePosition).offset
        : 0;
    final end = r.end.nodeId == node.id
        ? (r.end.nodePosition as TextNodePosition).offset
        : node.text.length;
    return (start, end);
  }

  // ------------------------------------------------------ inline styles

  static Attribution _attribution(InlineFormat f) => switch (f) {
    InlineFormat.bold => boldAttribution,
    InlineFormat.italic => italicsAttribution,
    InlineFormat.strikethrough => strikethroughAttribution,
    InlineFormat.code => codeAttribution,
  };

  /// Whether inline styles apply at the selection (not in literal blocks).
  bool get canFormatInline {
    final s = _liveSelection;
    if (s == null || readOnly) return false;
    return _selectedTextNodes.any((n) => !isCodeLike(n));
  }

  /// The selected ranges [format] applies to (Write 04 §10.2: not literal
  /// blocks; bold, italic and strikethrough not on inline code), as
  /// document ranges of single text nodes.
  List<DocumentRange> _eligible(InlineFormat format, DocumentRange r) {
    final out = <DocumentRange>[];
    for (final node in _selectedTextNodes) {
      if (isCodeLike(node)) continue;
      final (start, end) = _rangeIn(node, r);
      int? from;
      for (var i = start; i <= end; i++) {
        final ok =
            i < end &&
            (format == InlineFormat.code ||
                !node.text.hasAttributionAt(i, attribution: codeAttribution));
        if (ok) {
          from ??= i;
        } else if (from != null) {
          out.add(
            DocumentRange(
              start: DocumentPosition(
                nodeId: node.id,
                nodePosition: TextNodePosition(offset: from),
              ),
              end: DocumentPosition(
                nodeId: node.id,
                nodePosition: TextNodePosition(offset: i),
              ),
            ),
          );
          from = null;
        }
      }
    }
    return out;
  }

  /// Whether the whole selection (or the typing style at the caret) has
  /// [format] (Write 04 §10.2 `isChecked`).
  bool isActive(InlineFormat format) {
    final a = _attribution(format);
    final r = _range;
    if (r == null) {
      return composer.preferences.currentAttributions.contains(a);
    }
    final ranges = _eligible(format, r);
    if (ranges.isEmpty) return false;
    for (final range in ranges) {
      final node = document.getNodeById(range.start.nodeId)! as TextNode;
      final start = (range.start.nodePosition as TextNodePosition).offset;
      final end = (range.end.nodePosition as TextNodePosition).offset;
      for (var i = start; i < end; i++) {
        if (!node.text.hasAttributionAt(i, attribution: a)) return false;
      }
    }
    return true;
  }

  /// Toggles [format] on the selection, or in the typing style at a caret
  /// (Write 04 §10.2): removed when the whole selection has it, added
  /// otherwise; one undo step. Code removes bold, italic and
  /// strikethrough; those skip inline code.
  void toggleInline(InlineFormat format) {
    if (!canFormatInline) return;
    final a = _attribution(format);
    final r = _range;
    if (r == null) {
      final prefs = composer.preferences;
      if (prefs.currentAttributions.contains(a)) {
        prefs.removeStyle(a);
      } else {
        prefs.addStyle(a);
        if (format == InlineFormat.code) {
          prefs.removeStyles({
            boldAttribution,
            italicsAttribution,
            strikethroughAttribution,
          });
        }
      }
      return;
    }
    final ranges = _eligible(format, r);
    if (ranges.isEmpty) return;
    final remove = isActive(format);
    editor.execute([
      for (final range in ranges) ...[
        if (remove)
          RemoveTextAttributionsRequest(documentRange: range, attributions: {a})
        else ...[
          if (format == InlineFormat.code)
            RemoveTextAttributionsRequest(
              documentRange: range,
              attributions: {
                boldAttribution,
                italicsAttribution,
                strikethroughAttribution,
              },
            ),
          AddTextAttributionsRequest(documentRange: range, attributions: {a}),
        ],
      ],
      ChangeSelectionRequest(
        _liveSelection!,
        SelectionChangeType.alteredContent,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  // ------------------------------------------------------------- blocks

  /// The block kind at the caret (the selection's extent).
  BlockFormat? get blockFormat {
    final s = _liveSelection;
    if (s == null) return null;
    return formatOf(document.getNodeById(s.extent.nodeId));
  }

  /// The block kind of [node] (null for rules and literal blocks).
  static BlockFormat? formatOf(DocumentNode? node) {
    if (node == null) return null;
    return switch (MarkdownDocumentCodec.kindOf(node)) {
      'p' => BlockFormat.paragraph,
      'h1' => BlockFormat.heading1,
      'h2' => BlockFormat.heading2,
      'h3' || 'h4' || 'h5' || 'h6' => BlockFormat.heading3,
      'ul' => BlockFormat.bulletList,
      'ol' => BlockFormat.numberedList,
      'task' => BlockFormat.taskList,
      'quote' => BlockFormat.quote,
      _ => null,
    };
  }

  /// Whether [format] is supported here (features, read-only).
  bool canFormatBlock(BlockFormat format) {
    if (readOnly || _liveSelection == null) return false;
    return switch (format) {
      BlockFormat.heading1 ||
      BlockFormat.heading2 ||
      BlockFormat.heading3 => _features.headings,
      BlockFormat.quote => _features.quotes,
      _ => true,
    };
  }

  /// Turns the selected blocks into [format], or back into paragraphs when
  /// they all are one already (Write 04 §13.2). Literal blocks stay as they
  /// are.
  void toggleBlock(BlockFormat format) {
    if (!canFormatBlock(format)) return;
    final nodes = _selectedTextNodes
        .where((n) => n.getMetadataValue(MarkdownNodeMetadata.raw) != true)
        .toList();
    if (nodes.isEmpty) return;
    final off = nodes.every((n) => formatOf(n) == format);
    final target = off ? BlockFormat.paragraph : format;
    final selection = _liveSelection!;
    editor.execute([
      for (final n in nodes)
        ReplaceNodeRequest(
          existingNodeId: n.id,
          newNode: _convert(n, target, n.text),
        ),
      ChangeSelectionRequest(
        selection,
        SelectionChangeType.alteredContent,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  /// [node] as a [format] block with [text] (same id; list levels kept).
  static TextNode _convert(
    TextNode node,
    BlockFormat format,
    AttributedText text,
  ) {
    final indent = switch (node) {
      ListItemNode(:final indent) => indent,
      TaskNode(:final indent) => indent,
      _ => 0,
    };
    // Literal text has no inline styles.
    final plain = isCodeLike(node) ? AttributedText(text.toPlainText()) : text;
    ParagraphNode paragraph(Attribution type) => ParagraphNode(
      id: node.id,
      text: plain,
      metadata: {NodeMetadata.blockType: type},
    );
    return switch (format) {
      BlockFormat.paragraph => paragraph(paragraphAttribution),
      BlockFormat.heading1 => paragraph(header1Attribution),
      BlockFormat.heading2 => paragraph(header2Attribution),
      BlockFormat.heading3 => paragraph(header3Attribution),
      BlockFormat.quote => paragraph(blockquoteAttribution),
      BlockFormat.bulletList => ListItemNode.unordered(
        id: node.id,
        text: plain,
        indent: indent,
      ),
      BlockFormat.numberedList => ListItemNode.ordered(
        id: node.id,
        text: plain,
        indent: indent,
      ),
      BlockFormat.taskList => TaskNode(
        id: node.id,
        text: plain,
        isComplete: false,
        indent: indent,
      ),
    };
  }

  /// Indents (or with [outdent], outdents) the selected list and task
  /// items; returns whether the selection had any.
  bool indentItems({bool outdent = false}) {
    if (readOnly) return false;
    final items = _selectedTextNodes
        .where((n) => n is ListItemNode || n is TaskNode)
        .toList();
    if (items.isEmpty) return false;
    editor.execute([
      for (final n in items)
        if (n is ListItemNode)
          outdent
              ? UnIndentListItemRequest(nodeId: n.id)
              : IndentListItemRequest(nodeId: n.id)
        else if (outdent)
          UnIndentTaskRequest(n.id)
        else
          IndentTaskRequest(n.id),
    ]);
    return true;
  }

  // -------------------------------------------------------------- links

  /// The link at the selection's start (or the caret), or null.
  String? get link {
    final s = _liveSelection;
    if (s == null) return null;
    final p = _range?.start ?? s.extent;
    final node = document.getNodeById(p.nodeId);
    final np = p.nodePosition;
    if (node is! TextNode || np is! TextNodePosition || node.text.isEmpty) {
      return null;
    }
    // At a link's end the caret is still "on" it.
    for (final o in [np.offset, np.offset - 1]) {
      if (o < 0 || o >= node.text.length) continue;
      final a = node.text
          .getAllAttributionsAt(o)
          .whereType<LinkAttribution>()
          .firstOrNull;
      if (a != null) return a.plainTextUri;
    }
    return null;
  }

  /// Whether a link can be added or edited here.
  bool get canLink => canFormatInline;

  /// Makes the selection a link to [url]; with a caret on a link, changes
  /// (or with null removes) that link; with a caret elsewhere, inserts
  /// [url] as linked text. [url] is made canonical
  /// ([normalizeLinkTarget]); an invalid URL does nothing.
  void setLink(String? url) {
    if (!canLink) return;
    final target = url == null ? null : normalizeLinkTarget(url);
    if (url != null && target == null) return;
    final s = _liveSelection!;
    final range = _range ?? _linkRangeAt(s.extent);
    if (range == null) {
      if (target == null) return;
      final caret = s.extent;
      final text = AttributedText(url!.trim())
        ..addAttribution(
          LinkAttribution(target),
          SpanRange(0, url.trim().length - 1),
        );
      editor.execute([
        InsertAttributedTextRequest(caret, text),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: caret.nodeId,
              nodePosition: TextNodePosition(
                offset:
                    (caret.nodePosition as TextNodePosition).offset +
                    text.length,
              ),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      ]);
      return;
    }
    final existing = <Attribution>{
      for (final node in document.getNodesInside(range.start, range.end))
        if (node is TextNode)
          for (
            var o = _spanIn(node, range).start;
            o <= _spanIn(node, range).end && o < node.text.length;
            o++
          )
            ...node.text.getAllAttributionsAt(o).whereType<LinkAttribution>(),
    };
    editor.execute([
      if (existing.isNotEmpty)
        RemoveTextAttributionsRequest(
          documentRange: range,
          attributions: existing,
        ),
      if (target != null)
        AddTextAttributionsRequest(
          documentRange: range,
          attributions: {LinkAttribution(target)},
        ),
    ]);
  }

  SpanRange _spanIn(TextNode node, DocumentRange r) {
    final (start, end) = _rangeIn(node, r);
    return SpanRange(start, end <= start ? start : end - 1);
  }

  /// The range of the link around [p], or null.
  DocumentRange? _linkRangeAt(DocumentPosition p) {
    final node = document.getNodeById(p.nodeId);
    final np = p.nodePosition;
    if (node is! TextNode || np is! TextNodePosition || node.text.isEmpty) {
      return null;
    }
    for (final o in [np.offset, np.offset - 1]) {
      if (o < 0 || o >= node.text.length) continue;
      final spans = node.text.getAttributionSpansInRange(
        attributionFilter: (a) => a is LinkAttribution,
        range: SpanRange(o, o),
      );
      final span = spans.firstOrNull;
      if (span == null) continue;
      return DocumentRange(
        start: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: span.start),
        ),
        end: DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: span.end + 1),
        ),
      );
    }
    return null;
  }

  // ---------------------------------------------------------- clipboard

  /// The selection as Markdown (copy and cut, specs/16 §7.3), or null when
  /// nothing is selected. Text inside one block is its inline Markdown (the
  /// plain text inside a literal block); a selection across blocks, or a
  /// whole block, keeps the blocks (headings, lists, tasks, quotes, literal
  /// blocks, rules),
  /// cut at the selection's ends. Untouched blocks keep their Markdown
  /// source. [paste] reads it back into the same content.
  String? get selectedMarkdown {
    final r = _range;
    if (r == null) return null;
    final nodes = document.getNodesInside(r.start, r.end);
    if (nodes.isEmpty) return null;
    if (nodes.length == 1 && nodes.single is TextNode) {
      final node = nodes.single as TextNode;
      final (start, end) = _rangeIn(node, r);
      if (start > 0 || end < node.text.length) {
        final text = node.text.copyText(start, end);
        if (isCodeLike(node)) return text.toPlainText();
        final md = codec.encode(
          MutableDocument(
            nodes: [ParagraphNode(id: Editor.createNodeId(), text: text)],
          ),
        );
        return md.isEmpty ? null : md;
      }
    }
    final md = codec.encode(
      MutableDocument(
        nodes: [
          for (final n in nodes)
            if (n is TextNode)
              _cut(n, r)
            else
              n.copyWithAddedMetadata(const {}),
        ],
      ),
    );
    return md.isEmpty ? null : md;
  }

  /// [node] cut to the part inside [r].
  TextNode _cut(TextNode node, DocumentRange r) {
    final (start, end) = _rangeIn(node, r);
    if (start == 0 && end == node.text.length) return node.copyTextNodeWith();
    return node.copyTextNodeWith(text: node.text.copyText(start, end));
  }

  /// Deletes the selection (cut); false when there is none or the field is
  /// read-only.
  bool deleteSelection() {
    if (readOnly || _range == null) return false;
    editor.execute([DeleteSelectionRequest(TextAffinity.downstream)]);
    return true;
  }

  /// Replaces `[start, end)` of text node [nodeId] with [replacement] (a
  /// spelling suggestion) keeping the styles at [start], caret after it;
  /// one undo step. False when refused ([readOnly], a bad range).
  bool replaceText(String nodeId, int start, int end, String replacement) {
    if (readOnly) return false;
    final node = document.getNodeById(nodeId);
    if (node is! TextNode ||
        start < 0 ||
        end > node.text.length ||
        start > end) {
      return false;
    }
    DocumentPosition at(int offset) => DocumentPosition(
      nodeId: nodeId,
      nodePosition: TextNodePosition(offset: offset),
    );
    final styles = start < node.text.length
        ? node.text.getAllAttributionsAt(start)
        : const <Attribution>{};
    // Run past the length guard (a correction may be a little longer),
    // but as an edit of the user's.
    _edited = true;
    _cache = null;
    _run([
      if (end > start)
        DeleteContentRequest(
          documentRange: DocumentRange(start: at(start), end: at(end)),
        ),
      InsertTextRequest(
        documentPosition: at(start),
        textToInsert: replacement,
        attributions: styles,
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: at(start + replacement.length)),
        SelectionChangeType.alteredContent,
        SelectionReason.userInteraction,
      ),
    ]);
    return true;
  }

  // -------------------------------------------------------------- paste

  /// Pastes [text]: Markdown is converted into blocks and styles (in
  /// literal blocks, and with [plain], it is inserted as is; a fenced code
  /// block becomes a literal block). A URL pasted over a
  /// selection makes it a link (Write 04 §11.1). Returns false when the
  /// paste was refused ([readOnly], [maxLength]).
  bool paste(String text, {bool plain = false}) {
    final s = _liveSelection;
    if (s == null || readOnly || text.isEmpty) return false;
    final max = maxLength;
    if (max != null && length + text.length > max) return false;
    final url = text.trim();
    if (!plain &&
        !s.isCollapsed &&
        !url.contains(RegExp(r'\s')) &&
        isSafeLink(url)) {
      setLink(url);
      return true;
    }
    if (!s.isCollapsed) {
      editor.execute([DeleteSelectionRequest(TextAffinity.downstream)]);
    }
    final caret = _liveSelection!.extent;
    final node = document.getNodeById(caret.nodeId);
    if (node is! TextNode) return false;
    if (isCodeLike(node)) {
      final offset = (caret.nodePosition as TextNodePosition).offset;
      editor.execute([
        InsertTextRequest(
          documentPosition: caret,
          textToInsert: text,
          attributions: const {},
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: offset + text.length),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      ]);
      return true;
    }
    if (plain) {
      // Paragraphs at blank lines; other lines stay lines.
      final chunks = text
          .replaceAll('\r\n', '\n')
          .split(RegExp(r'\n\s*\n'))
          .where((c) => c.trim().isNotEmpty)
          .toList();
      if (chunks.isEmpty) return false;
      editor.execute([
        PasteStructuredContentEditorRequest(
          content: MutableDocument(
            nodes: [
              for (final c in chunks)
                ParagraphNode(
                  id: Editor.createNodeId(),
                  text: AttributedText(c),
                ),
            ],
          ),
          pastePosition: caret,
        ),
      ]);
      return true;
    }
    final nodes = codec.decodeNodes(text);
    // A trailing empty paragraph is only there for the caret.
    if (nodes.length > 1 &&
        nodes.last is ParagraphNode &&
        (nodes.last as ParagraphNode).text.isEmpty) {
      nodes.removeLast();
    }
    editor.execute([
      PasteStructuredContentEditorRequest(
        content: MutableDocument(nodes: nodes),
        pastePosition: caret,
      ),
    ]);
    return true;
  }

  @override
  void dispose() {
    composer.preferences.removeListener(notifyListeners);
    editor.dispose();
    super.dispose();
  }
}

/// History grouping of the field: typing within a second is one step, and
/// selection changes join the step before them (undo never only moves the
/// caret).
class _HistoryPolicy implements HistoryGroupingPolicy {
  const _HistoryPolicy();

  static const _typing = MergeRapidTextInputPolicy(Duration(seconds: 1));

  @override
  TransactionMerge shouldMergeLatestTransaction(
    CommandTransaction newTransaction,
    CommandTransaction previousTransaction,
  ) {
    final content = newTransaction.changes.any((c) => c is DocumentEdit);
    if (!content) return TransactionMerge.mergeOnTop;
    return _typing.shouldMergeLatestTransaction(
      newTransaction,
      previousTransaction,
    );
  }
}

/// Enter in (or over a selection touching) a literal block: the selection
/// is deleted, then a line break goes in at the caret; at the end of a
/// literal block, or when the caret is no longer in one, super_editor's
/// rules apply.
class _LiteralNewlineCommand extends EditCommand {
  const _LiteralNewlineCommand(this.newNodeId);

  final String newNodeId;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.undoable;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final composer = context.find<MutableDocumentComposer>(Editor.composerKey);
    if (composer.selection case final s? when !s.isCollapsed) {
      executor.executeCommand(
        DeleteSelectionCommand(affinity: TextAffinity.downstream),
      );
    }
    final s = composer.selection;
    if (s == null) return;
    final node = context.document.getNodeById(s.extent.nodeId);
    final p = s.extent.nodePosition;
    if (node is TextNode &&
        isCodeLike(node) &&
        p is TextNodePosition &&
        p.offset < node.text.length) {
      executor.executeCommand(
        InsertTextCommand(
          documentPosition: s.extent,
          textToInsert: '\n',
          attributions: const {},
        ),
      );
      return;
    }
    executor.executeCommand(
      isCodeLike(node)
          ? InsertNewlineInCodeBlockAtCaretCommand(newNodeId)
          : DefaultInsertNewlineAtCaretCommand(newNodeId),
    );
  }
}

class _NoOpCommand extends EditCommand {
  const _NoOpCommand();

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.nonHistorical;

  @override
  void execute(EditContext context, CommandExecutor executor) {}
}
