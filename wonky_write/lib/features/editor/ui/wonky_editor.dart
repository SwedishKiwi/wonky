import 'dart:async';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shad/shad.dart' show ShadTheme;
import 'package:super_editor/super_editor.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show SuggestionView;

import '../applier/delta_applier.dart';
import '../commands/write_editor_commands.dart';
import '../components/editor_services.dart';
import '../components/wonky_components.dart';
import '../controller/editor_types.dart';
import '../controller/write_editor_controller.dart';
import '../keyboard/editor_keyboard.dart';
import '../layers/editor_layers.dart';
import '../mapping/delta_document_mapper.dart';
import '../model/document_queries.dart';
import '../pagination/pagination.dart';
import '../paste/editor_clipboard.dart';
import '../plugins/slash_items.dart';
import '../plugins/trigger_queries.dart';
import '../popovers/editor_popovers.dart';
import '../styles/editor_theme.dart';
import '../styles/style_phases.dart';
import '../styles/write_stylesheet.dart';

/// The Write document editor surface (Write 04): `SuperEditor` (Editing,
/// Suggesting) or `SuperReader` (Viewing, suggestion previews) over the
/// [WriteEditorController]'s document, with the Wonky stylesheet, component
/// builders, layers (find matches, remote cursors and selections, block
/// handle), the slash menu, the mention picker, the link hover card, Pages /
/// Pageless layout with pagination, and zoom.
///
/// Chrome (menubar, toolbar, panels) is built by the screen around it; every
/// action goes through [commands] / [controller].
class WonkyEditor extends StatefulWidget {
  const WonkyEditor({
    super.key,
    required this.controller,
    this.commands,
    this.clipboard,
    this.theme,
    this.documentTitle = 'Document',
    this.imageServices = const NetworkImageServices(),
    this.blockCallbacks = const EditorBlockCallbacks(),
    this.shortcutCallbacks,
    this.keymap,
    this.builtInShortcuts = true,
    this.slashHost = const SlashHost(),
    this.mentionCandidates,
    this.onOpenLink,
    this.onEditLink,
    this.autofocus = false,
    this.scrollController,
    this.hint = 'Type / for commands, or just start writing',
  });

  final WriteEditorController controller;

  /// The command layer (created from [controller] when omitted).
  final WriteEditorCommands? commands;

  /// Clipboard actions (created when omitted).
  final EditorClipboard? clipboard;

  /// Document theme; defaults to Wonky Default for the ambient brightness.
  final EditorTheme? theme;

  /// Semantics label of the editor (the document title).
  final String documentTitle;

  final EditorImageServices imageServices;
  final EditorBlockCallbacks blockCallbacks;

  /// Shell actions behind shortcuts (undo/redo, link popover, find…). When
  /// omitted, copy/cut/paste use [clipboard] and the rest is not bound.
  final EditorShortcutCallbacks? shortcutCallbacks;

  /// The shell keymap (`KeymapService`, scope `editor`), tried first.
  final EditorKeyHandler? keymap;

  /// Whether the editor's own default shortcuts apply (disable when the shell
  /// keymap binds every editor command).
  final bool builtInShortcuts;

  final SlashHost slashHost;

  /// People to mention for a query (sharing + contacts + search); `null`
  /// disables the mention picker.
  final Future<List<MentionCandidate>> Function(String query)?
  mentionCandidates;

  /// Opens a link (internal links navigate; external links show the shell's
  /// "Open external link?" confirm). Mod+click in Editing, click in Viewing.
  final void Function(String url)? onOpenLink;

  /// Opens the link popover for the link at the caret (`write.link.edit`).
  final VoidCallback? onEditLink;

  final bool autofocus;
  final ScrollController? scrollController;
  final String hint;

  @override
  State<WonkyEditor> createState() => WonkyEditorState();
}

class WonkyEditorState extends State<WonkyEditor> {
  late WriteEditorCommands _commands;
  late EditorClipboard _clipboard;
  late TriggerQueryTracker _triggers;
  late final WriteStylesheetBuilder _styles = WriteStylesheetBuilder();
  final _pagination = PaginationController();
  late final PaginationStylePhase _paginationPhase = PaginationStylePhase(
    _pagination,
  );
  final _codeHighlight = CodeHighlightStylePhase();
  final _direction = TextDirectionStylePhase();
  final _slashPicker = PickerController<SlashItem>();
  final _mentionPicker = PickerController<MentionCandidate>();
  final _slashItems = defaultSlashItems();
  final _hoveredNode = ValueNotifier<String?>(null);
  final _linkCard = ValueNotifier<LinkRun?>(null);
  late ScrollController _scrollController;
  Timer? _hoverTimer;
  Timer? _previewTimer;
  int _mentionRequest = 0;

  // Read-only preview document (Viewing / suggestion previews).
  Editor? _previewEditor;
  SuggestionPreviewMode? _previewMode;

  WriteEditorController get controller => widget.controller;

  /// The command layer used by this editor.
  WriteEditorCommands get commands => _commands;

  /// The clipboard actions used by this editor.
  EditorClipboard get clipboard => _clipboard;

  /// The pagination state (page count for the status bar).
  PaginationController get pagination => _pagination;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _attach();
  }

  void _attach() {
    _commands = widget.commands ?? WriteEditorCommands(controller);
    _clipboard =
        widget.clipboard ??
        EditorClipboard(controller: controller, commands: _commands);
    _triggers = TriggerQueryTracker(controller);
    _triggers.slash.addListener(_onSlash);
    _triggers.mention.addListener(_onMention);
    controller.addListener(_onControllerChanged);
    controller.view.addListener(_onViewChanged);
    controller.notices.listen(_onNotice);
  }

  void _detach(WriteEditorController old) {
    _triggers.slash.removeListener(_onSlash);
    _triggers.mention.removeListener(_onMention);
    _triggers.dispose();
    old.removeListener(_onControllerChanged);
    old.view.removeListener(_onViewChanged);
  }

  @override
  void didUpdateWidget(WonkyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach(oldWidget.controller);
      _attach();
    }
  }

  @override
  void dispose() {
    _detach(controller);
    _hoverTimer?.cancel();
    _previewTimer?.cancel();
    _paginationPhase.dispose();
    _codeHighlight.dispose();
    _pagination.dispose();
    _slashPicker.dispose();
    _mentionPicker.dispose();
    _hoveredNode.dispose();
    _linkCard.dispose();
    if (widget.scrollController == null) _scrollController.dispose();
    super.dispose();
  }

  void _onNotice(EditorNotice notice) {
    if (!mounted) return;
    if (notice.kind == EditorNoticeKind.announcement &&
        notice.message != null) {
      final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          notice.message!,
          direction,
        ),
      );
    }
  }

  void _onControllerChanged() {
    _updateLinkCardFromCaret();
    if (_previewMode != null) _schedulePreviewRebuild();
    if (mounted) setState(() {});
  }

  void _onViewChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Slash menu and mentions.

  void _onSlash() {
    final query = _triggers.slash.value;
    _slashPicker.items = query == null
        ? const []
        : filterSlashItems(
            _slashItems,
            query.query,
            mode: controller.mode,
          ).take(10).toList();
    if (mounted) setState(() {});
  }

  Future<void> _onMention() async {
    final query = _triggers.mention.value;
    final provider = widget.mentionCandidates;
    if (query == null || provider == null) {
      _mentionPicker.items = const [];
      if (mounted) setState(() {});
      return;
    }
    final request = ++_mentionRequest;
    final candidates = await provider(query.query);
    if (!mounted || request != _mentionRequest) return;
    _mentionPicker.items = candidates.take(8).toList();
    setState(() {});
  }

  void _chooseSlash(SlashItem item) {
    final query = _triggers.slash.value;
    if (query == null) return;
    runSlashItem(
      controller,
      _commands,
      _triggers,
      query,
      item,
      widget.slashHost,
    );
    _triggers.dismiss();
  }

  void _chooseMention(MentionCandidate person) {
    final query = _triggers.mention.value;
    if (query == null) return;
    _commands.insertMention(
      userUuid: person.userUuid,
      displayName: person.displayName,
      email: person.email,
      replaceStart: query.start,
      replaceEnd: query.end,
    );
    _triggers.dismiss();
  }

  bool _popoverKeys(KeyEvent event) {
    if (_triggers.slash.value != null && _slashPicker.items.isNotEmpty) {
      return _slashPicker.handleKey(
        event,
        onChoose: _chooseSlash,
        onClose: _triggers.dismiss,
      );
    }
    if (_triggers.mention.value != null && widget.mentionCandidates != null) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.space &&
          _mentionPicker.items.isEmpty) {
        _triggers.dismiss();
        return false;
      }
      return _mentionPicker.handleKey(
        event,
        onChoose: _chooseMention,
        onClose: _triggers.dismiss,
      );
    }
    if (_linkCard.value != null &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _linkCard.value = null;
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Links.

  void _updateLinkCardFromCaret() {
    final selection = controller.selection;
    if (selection == null || !selection.isCollapsed) {
      if (_linkCard.value != null && _hoverTimer == null) {
        _linkCard.value = null;
      }
      return;
    }
    final run = _commands.linkAt(selection.start);
    final inside =
        run != null && selection.start > run.start && selection.start < run.end;
    _linkCard.value = inside ? run : null;
  }

  void _onHover(PointerHoverEvent event) {
    final layout = controller.documentLayout;
    if (layout == null) return;
    final local = layout.getDocumentOffsetFromAncestorOffset(event.position);
    final position = layout.getDocumentPositionAtOffset(local);
    _hoveredNode.value = position?.nodeId;
    final offset = position == null
        ? null
        : controller.mirror.offsetOf(position);
    final run = offset == null ? null : _commands.linkAt(offset);
    _hoverTimer?.cancel();
    if (run == null) {
      _hoverTimer = Timer(const Duration(milliseconds: 200), () {
        _hoverTimer = null;
        _updateLinkCardFromCaret();
      });
      return;
    }
    _hoverTimer = Timer(const Duration(milliseconds: 400), () {
      _hoverTimer = null;
      _linkCard.value = run;
    });
  }

  // ---------------------------------------------------------------------------
  // Read-only previews (§31).

  SuggestionPreviewMode get _effectivePreview =>
      controller.view.suggestionPreview ??
      (controller.mode == EditorMode.viewing
          ? SuggestionPreviewMode.original
          : SuggestionPreviewMode.show);

  void _schedulePreviewRebuild() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(_rebuildPreview);
    });
  }

  void _rebuildPreview() {
    final mode = _previewMode;
    if (mode == null) {
      _previewEditor = null;
      return;
    }
    final delta = controller.delta;
    final Delta viewed = mode == SuggestionPreviewMode.accepted
        ? SuggestionView.accepted(delta)
        : SuggestionView.original(delta);
    final document = const DeltaDocumentMapper().documentFromDelta(viewed);
    _previewEditor = createDefaultDocumentEditor(
      document: document,
      composer: MutableDocumentComposer(),
    );
  }

  // ---------------------------------------------------------------------------
  // Build.

  EditorTheme _theme(BuildContext context) {
    final explicit = widget.theme;
    if (explicit != null) return explicit;
    final brightness =
        ShadTheme.maybeOf(context)?.brightness ?? Theme.of(context).brightness;
    return EditorTheme.fallback(brightness);
  }

  @override
  Widget build(BuildContext context) {
    // Task checkboxes and the text-selection widgets need a Material
    // ancestor; read-only hosts (history, theme preview) have none.
    if (Material.maybeOf(context) == null) {
      return Material(
        type: MaterialType.transparency,
        child: Builder(builder: _build),
      );
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    final theme = _theme(context);
    final view = controller.view;
    final pages = view.layout == LayoutMode.pages;
    final zoom = view.zoom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    _pagination.configure(view.pageSetup, zoom * textScale);

    final preview = _effectivePreview;
    final readOnly =
        controller.mode == EditorMode.viewing ||
        preview != SuggestionPreviewMode.show;
    final previewMode = preview == SuggestionPreviewMode.show ? null : preview;
    if (previewMode != _previewMode) {
      _previewMode = previewMode;
      _rebuildPreview();
    }

    final style = _styles.build(
      theme: theme,
      zoom: zoom,
      textScale: textScale,
      layout: view.layout,
      contentWidth: view.pageSetup.contentWidth,
      comments: view.comments,
      selfUserUuid: controller.userUuid,
      focused: controller.focusNode.hasFocus,
    );
    final stylesheet = pages
        ? style.stylesheet.copyWith(
            documentPadding: view.pageSetup.margins * (zoom * textScale),
          )
        : style.stylesheet;

    final editorWidget = readOnly
        ? _buildReader(theme, style, stylesheet, previewMode)
        : _buildEditor(theme, style, stylesheet);

    Widget surface = MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      // Material ancestor for the task checkboxes and text-selection
      // widgets: hosts (the editor screen, version history) are shad-only.
      child: Material(type: MaterialType.transparency, child: editorWidget),
    );

    if (pages) {
      final pageWidth = view.pageSetup.size.width * zoom * textScale;
      surface = ColoredBox(
        color: theme.canvasColor,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: pageWidth, child: surface),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _repaginate());
    } else {
      surface = ColoredBox(color: theme.paperColor, child: surface);
    }

    return Semantics(
      textField: true,
      multiline: true,
      readOnly: readOnly,
      label: widget.documentTitle,
      child: MouseRegion(
        onHover: _onHover,
        onExit: (_) {
          _hoveredNode.value = null;
        },
        child: Stack(
          children: [
            Positioned.fill(child: surface),
            ..._buildPopovers(context, theme, readOnly),
          ],
        ),
      ),
    );
  }

  void _repaginate() {
    if (!mounted || controller.view.layout != LayoutMode.pages) return;
    final layout = controller.documentLayout;
    if (layout == null) return;
    _pagination.measure(layout, controller.document);
  }

  List<ComponentBuilder> _componentBuilders(
    EditorTheme theme,
    double zoom, {
    required bool editable,
    Document? document,
  }) {
    return [
      if (editable && controller.document.nodeCount == 1)
        HintComponentBuilder(
          widget.hint,
          (context) => theme.body.copyWith(
            color: theme.mutedColor,
            fontSize: (theme.body.fontSize ?? 14.67) * zoom,
          ),
        ),
      WonkyImageComponentBuilder(
        services: widget.imageServices,
        theme: theme,
        callbacks: widget.blockCallbacks,
      ),
      WonkyTableComponentBuilder(
        theme: theme,
        callbacks: widget.blockCallbacks,
        editable: editable,
      ),
      WonkyTaskComponentBuilder(
        controller.editor,
        editable: editable,
        onToggle: (nodeId) => _commands.toggleChecked(nodeId: nodeId),
      ),
      WonkyParagraphComponentBuilder(
        document: document ?? controller.document,
        theme: theme,
        zoom: zoom,
        callbacks: widget.blockCallbacks,
        editable: editable,
      ),
      WonkyRuleComponentBuilder(theme: theme),
      WonkyEmbedComponentBuilder(theme: theme),
      ...defaultComponentBuilders,
      const MarkdownTableComponentBuilder(),
    ];
  }

  Widget _buildEditor(
    EditorTheme theme,
    WriteEditorStyle style,
    Stylesheet stylesheet,
  ) {
    final callbacks =
        widget.shortcutCallbacks ??
        EditorShortcutCallbacks(
          onCopy: () => unawaited(_clipboard.copy()),
          onCut: () => unawaited(_clipboard.cut()),
          onPaste: () => unawaited(_clipboard.paste()),
          onPasteWithoutFormatting: () =>
              unawaited(_clipboard.paste(plainOnly: true)),
          onInsertLink: widget.onEditLink,
        );
    final pages = controller.view.layout == LayoutMode.pages;
    return SuperEditor(
      key: WonkyEditorKeys.editor,
      editor: controller.editor,
      focusNode: controller.focusNode,
      autofocus: widget.autofocus,
      documentLayoutKey: controller.documentLayoutKey,
      scrollController: _scrollController,
      inputRole: 'write-doc-${controller.documentUuid}',
      inputSource: TextInputSource.ime,
      // Keep the selection while focus is elsewhere (a menubar menu, the
      // find field, the comment box), like a word processor: commands from
      // menus act on it and it comes back when the editor regains focus.
      selectionPolicies: const SuperEditorSelectionPolicies(
        clearSelectionWhenEditorLosesFocus: false,
        clearSelectionWhenImeConnectionCloses: false,
      ),
      stylesheet: stylesheet,
      selectionStyle: style.selectionStyles,
      customStylePhases: [
        if (pages) _paginationPhase,
        _codeHighlight,
        _direction,
      ],
      componentBuilders: _componentBuilders(theme, style.zoom, editable: true),
      documentUnderlayBuilders: [
        if (pages)
          _PageChromeLayerBuilder(pagination: _pagination, theme: theme),
        WonkyHighlightLayerBuilder(controller: controller, theme: theme),
      ],
      documentOverlayBuilders: [
        DefaultCaretOverlayBuilder(caretStyle: style.caretStyle),
        WonkyRemoteCaretLayerBuilder(controller: controller, theme: theme),
        WonkyBlockHandleLayerBuilder(
          controller: controller,
          theme: theme,
          hoveredNodeId: _hoveredNode,
          onTap: (nodeId, rect) =>
              widget.blockCallbacks.onBlockHandleTap?.call(nodeId, rect),
        ),
      ],
      keyboardActions: wonkyKeyboardActions(
        controller: controller,
        commands: _commands,
        keymap: widget.keymap,
        popoverKeys: _popoverKeys,
        builtInShortcuts: widget.builtInShortcuts,
        callbacks: callbacks,
      ),
      contentTapDelegateFactories: [
        (editContext) => WonkyLinkTapHandler(
          document: controller.document,
          composer: controller.composer,
          requireModifier: true,
          onOpenLink: widget.onOpenLink,
        ),
        superEditorAddEmptyParagraphTapHandlerFactory,
      ],
    );
  }

  Widget _buildReader(
    EditorTheme theme,
    WriteEditorStyle style,
    Stylesheet stylesheet,
    SuggestionPreviewMode? preview,
  ) {
    final editor = preview == null
        ? controller.editor
        : (_previewEditor ?? controller.editor);
    final isMain = identical(editor, controller.editor);
    final pages = controller.view.layout == LayoutMode.pages;
    return SuperReader(
      key: const ValueKey<String>('write.editor.reader'),
      editor: editor,
      focusNode: isMain ? controller.focusNode : null,
      documentLayoutKey: isMain ? controller.documentLayoutKey : null,
      scrollController: _scrollController,
      stylesheet: stylesheet,
      customStylePhases: [
        if (pages && isMain) _paginationPhase,
        _codeHighlight,
        _direction,
      ],
      componentBuilders: _componentBuilders(
        theme,
        style.zoom,
        editable: false,
        document: editor.document,
      ),
      documentUnderlayBuilders: [
        if (pages && isMain)
          _ReaderPageChromeLayerBuilder(pagination: _pagination, theme: theme),
        if (isMain)
          WonkyReaderHighlightLayerBuilder(
            controller: controller,
            theme: theme,
          ),
      ],
      documentOverlayBuilders: [
        if (isMain)
          WonkyReaderRemoteCaretLayerBuilder(
            controller: controller,
            theme: theme,
          ),
        ...defaultSuperReaderDocumentOverlayBuilders,
      ],
      contentTapDelegateFactory: (readerContext) => WonkyLinkTapHandler(
        document: editor.document,
        composer: editor.composer,
        requireModifier: false,
        onOpenLink: widget.onOpenLink,
      ),
    );
  }

  List<Widget> _buildPopovers(
    BuildContext context,
    EditorTheme theme,
    bool readOnly,
  ) {
    final widgets = <Widget>[];
    final layout = controller.documentLayout;
    if (layout == null) return widgets;
    final box = context.findRenderObject() as RenderBox?;
    Offset? anchorBelow(int offset) {
      final position = controller.mirror.positionAt(offset);
      if (position == null || box == null || !box.hasSize) return null;
      final rect = layout.getRectForPosition(position);
      if (rect == null) return null;
      final global = layout.getGlobalOffsetFromDocumentOffset(rect.bottomLeft);
      return box.globalToLocal(global) + const Offset(0, 4);
    }

    final slash = _triggers.slash.value;
    if (!readOnly && slash != null && _slashPicker.items.isNotEmpty) {
      final at = anchorBelow(slash.start);
      if (at != null) {
        widgets.add(
          Positioned(
            left: at.dx,
            top: at.dy,
            child: SlashMenu(
              picker: _slashPicker,
              theme: theme,
              onChoose: _chooseSlash,
            ),
          ),
        );
      }
    }
    final mention = _triggers.mention.value;
    if (!readOnly && mention != null && widget.mentionCandidates != null) {
      final at = anchorBelow(mention.start);
      if (at != null) {
        widgets.add(
          Positioned(
            left: at.dx,
            top: at.dy,
            child: MentionPicker(
              picker: _mentionPicker,
              theme: theme,
              onChoose: _chooseMention,
            ),
          ),
        );
      }
    }
    final link = _linkCard.value;
    if (link != null &&
        link.mentionUuid == null &&
        slash == null &&
        mention == null) {
      final at = anchorBelow(link.start);
      if (at != null) {
        widgets.add(
          Positioned(
            left: at.dx,
            top: at.dy,
            child: LinkHoverCard(
              url: link.url,
              theme: theme,
              actions: LinkCardActions(
                onOpen: widget.onOpenLink == null
                    ? null
                    : () => widget.onOpenLink!(link.url),
                onCopy: () =>
                    unawaited(Clipboard.setData(ClipboardData(text: link.url))),
                onEdit: readOnly || widget.onEditLink == null
                    ? null
                    : () {
                        controller.select(DeltaSelection(link.start, link.end));
                        widget.onEditLink!();
                      },
                onRemove: readOnly
                    ? null
                    : () {
                        _commands.removeLink(
                          start: link.start,
                          length: link.end - link.start,
                        );
                        _linkCard.value = null;
                      },
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

/// Opens links: with the Mod key in Editing/Suggesting ("interaction mode"),
/// with a plain click in Viewing (Write 04 §11.6).
class WonkyLinkTapHandler extends ContentTapDelegate {
  WonkyLinkTapHandler({
    required this.document,
    required this.composer,
    required this.requireModifier,
    this.onOpenLink,
  }) {
    composer.isInInteractionMode.addListener(notifyListeners);
  }

  final Document document;
  final DocumentComposer composer;
  final bool requireModifier;
  final void Function(String url)? onOpenLink;

  @override
  void dispose() {
    composer.isInInteractionMode.removeListener(notifyListeners);
    super.dispose();
  }

  bool get _active => !requireModifier || composer.isInInteractionMode.value;

  @override
  MouseCursor? mouseCursorForContentHover(DocumentPosition hoverPosition) =>
      _active && _linkAt(hoverPosition) != null
      ? SystemMouseCursors.click
      : null;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    if (!_active || onOpenLink == null) {
      return TapHandlingInstruction.continueHandling;
    }
    final position = details.documentLayout.getDocumentPositionNearestToOffset(
      details.layoutOffset,
    );
    final url = position == null ? null : _linkAt(position);
    if (url == null) return TapHandlingInstruction.continueHandling;
    onOpenLink!(url);
    return TapHandlingInstruction.halt;
  }

  String? _linkAt(DocumentPosition position) {
    final nodePosition = position.nodePosition;
    final node = document.getNodeById(position.nodeId);
    if (node is! TextNode ||
        nodePosition is! TextNodePosition ||
        nodePosition.offset >= node.text.length) {
      return null;
    }
    for (final attribution in node.text.getAllAttributionsAt(
      nodePosition.offset,
    )) {
      if (attribution is LinkAttribution) return attribution.plainTextUri;
    }
    return null;
  }
}

class _PageChromeLayerBuilder implements SuperEditorLayerBuilder {
  const _PageChromeLayerBuilder({
    required this.pagination,
    required this.theme,
  });

  final PaginationController pagination;
  final EditorTheme theme;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperEditorContext editContext,
  ) => _PageChromeLayer(pagination: pagination, theme: theme);
}

class _ReaderPageChromeLayerBuilder implements SuperReaderDocumentLayerBuilder {
  const _ReaderPageChromeLayerBuilder({
    required this.pagination,
    required this.theme,
  });

  final PaginationController pagination;
  final EditorTheme theme;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperReaderContext readerContext,
  ) => _PageChromeLayer(pagination: pagination, theme: theme);
}

class _PageChromeLayer extends ContentLayerStatelessWidget {
  const _PageChromeLayer({required this.pagination, required this.theme});

  final PaginationController pagination;
  final EditorTheme theme;

  @override
  Widget doBuild(
    BuildContext context,
    Element? contentElement,
    RenderObject? contentLayout,
  ) {
    return IgnorePointer(
      child: CustomPaint(
        painter: PageChromePainter(
          pagination: pagination,
          paperColor: theme.paperColor,
          borderColor: theme.tableBorderColor,
          textStyle: TextStyle(
            fontSize: 11 * pagination.zoom,
            color: theme.mutedColor,
          ),
        ),
      ),
    );
  }
}

/// Keeps the caret visible after keyboard edits (Write 04 §5) — exposed for
/// the screen's scroll helpers.
extension WonkyEditorScrolling on WonkyEditorState {
  /// Scrolls so that Delta [offset] is visible with a 64 px margin.
  void revealOffset(int offset) {
    final layout = controller.documentLayout;
    final position = controller.mirror.positionAt(offset);
    if (layout == null || position == null) return;
    final rect = layout.getRectForPosition(position);
    if (rect == null || !_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;
    double? target;
    if (rect.top - 64 < current) target = rect.top - 64;
    if (rect.bottom + 64 > current + viewport) {
      target = rect.bottom + 64 - viewport;
    }
    if (target != null) {
      _scrollController.jumpTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
      );
    }
  }
}

/// Convenience for screens: the blocks touched by the selection.
extension WonkyEditorBlocks on WriteEditorController {
  List<BlockRef> get selectedBlocks =>
      selection == null ? const [] : mirror.blocksInSelection(selection!);
}
