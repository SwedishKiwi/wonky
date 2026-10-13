import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemView;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../ai/ai_panel.dart';
import '../ai/ai_preview_overlay.dart';
import '../ai/write_ai_controller.dart';
import '../import/import_warnings_banner.dart';
import '../../commands/extras_commands.dart';
import '../../commands/screen_commands.dart';
import '../comments/comment_margin.dart';
import '../document/write_document_session.dart';
import '../editor/applier/delta_applier.dart' show DeltaSelection;
import '../editor/components/editor_services.dart';
import '../editor/controller/editor_types.dart';
import '../editor/keyboard/editor_keyboard.dart';
import '../editor/pagination/pagination.dart';
import '../editor/plugins/slash_items.dart';
import '../editor/popovers/editor_popovers.dart';
import '../editor/ui/wonky_editor.dart';
import '../editor/view/focus_mode_chrome.dart';
import '../find_replace/find_panel.dart';
import '../images/image_services.dart';
import '../outline/outline_panel.dart';
import '../suggestions/suggestions_panel.dart';
import '../themes/document_theme.dart';
import '../word_count/word_count_dialog.dart';
import 'command_invoke.dart';
import 'document_menus.dart';
import 'selection_toolbar.dart';
import 'write_document_controller.dart';
import 'write_toolbar.dart';

/// Creates the document session of the screen (tests inject fakes).
typedef WriteSessionFactory =
    WriteDocumentSession Function(ShellServices services, String itemUuid);

/// The document editor screen `/d/:uuid` (Write 05 §3): the shell's
/// `EditorScaffold` (title row, menubar, panels, status bar) around the
/// Write toolbar and document canvas.
class WriteDocumentScreen extends StatefulWidget {
  const WriteDocumentScreen({
    super.key,
    required this.services,
    required this.itemUuid,
    required this.themes,
    this.heading,
    this.sessionFactory,
  });

  final ShellServices services;
  final String itemUuid;
  final WriteThemeCatalog themes;

  /// `?heading=<anchor>`: scroll to this heading once loaded.
  final String? heading;
  final WriteSessionFactory? sessionFactory;

  @override
  State<WriteDocumentScreen> createState() => _WriteDocumentScreenState();
}

class _WriteDocumentScreenState extends State<WriteDocumentScreen> {
  late final WriteDocumentSession session;
  late final WriteDocumentController doc;
  late final WriteAiController ai;
  final _editorKey = GlobalKey<WonkyEditorState>();
  final _toolbar = WonkyToolbarController();
  final _scroll = ScrollController();
  bool _headingHandled = false;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    session =
        widget.sessionFactory?.call(s, widget.itemUuid) ??
        WriteDocumentSession(services: s, itemUuid: widget.itemUuid);
    doc = WriteDocumentController(
      services: s,
      session: session,
      themes: widget.themes,
    );
    doc.revealOffset = _reveal;
    doc.focusToolbar = _toolbar.focus;
    ai = WriteAiController(services: s, session: session, doc: doc);
    unawaited(session.open());
    session.phase.addListener(_onPhase);
    s.panels.addListener(_onPanels);
    if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
  }

  @override
  void dispose() {
    session.phase.removeListener(_onPhase);
    s.panels.removeListener(_onPanels);
    if (kIsWeb) unawaited(BrowserContextMenu.enableContextMenu());
    if (s.panels.isOpen(WritePanels.find)) s.panels.close(WritePanels.find);
    _pagination?.removeListener(_onPages);
    ai.dispose();
    doc.dispose();
    session.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reveal(int offset) => _editorKey.currentState?.revealOffset(offset);

  PaginationController? _pagination;

  /// Mirrors the editor's page count into the controller (status bar, word
  /// count dialog).
  void _attachPagination() {
    final p = _editorKey.currentState?.pagination;
    if (p == null || identical(p, _pagination)) return;
    _pagination?.removeListener(_onPages);
    _pagination = p..addListener(_onPages);
    _onPages();
  }

  void _onPages() {
    final n = _pagination?.pageCount;
    if (mounted) doc.pageCount.value = n == null || n < 1 ? null : n;
  }

  void _onPanels() {
    if (doc.find.isActive && !s.panels.isOpen(WritePanels.find)) {
      doc.find.close();
    }
  }

  void _onPhase() {
    if (session.phase.value != WriteSessionPhase.ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final heading = widget.heading;
      if (heading != null && !_headingHandled) {
        _headingHandled = true;
        doc.insights.refresh();
        final i = doc.insights.outline.indexWhere((e) => e.anchorId == heading);
        if (i >= 0) doc.goToHeading(i);
      } else if (doc.editor.selection == null && doc.editable) {
        doc.focusEditor();
      }
    });
  }

  void _invoke(String id, [Map<String, Object?> args = const {}]) =>
      unawaited(invokeWith(s, id, args: args, context: context));

  @override
  Widget build(BuildContext context) {
    return EditorScaffold(
      key: ValueKey<String>('write.screen.${widget.itemUuid}'),
      services: s,
      itemUuid: widget.itemUuid,
      controller: doc,
      toolbar: (context) =>
          WriteToolbar(services: s, doc: doc, controller: _toolbar),
      body: (context, item) => _body(context, item),
      statusLeft: (context) => [WordCountStatus(doc: doc)],
      statusRight: (context) => [
        _UploadsStatus(images: doc.images),
        LayoutStatus(doc: doc),
        ZoomStatus(doc: doc),
        ModeStatus(doc: doc),
      ],
      panels: [
        SidePanelSpec(
          id: WritePanels.outline,
          title: 'Outline',
          icon: LucideIcons.listTree,
          defaultWidth: 280,
          minWidth: 220,
          builder: (context) => OutlinePanel(
            insights: doc.insights,
            view: doc.outlineView,
            onClose: () {
              s.panels.close(WritePanels.outline);
              doc.focusEditor();
            },
          ),
        ),
        SidePanelSpec(
          id: WritePanels.find,
          title: 'Find and replace',
          icon: LucideIcons.search,
          defaultWidth: 340,
          minWidth: 300,
          builder: (context) => ListenableBuilder(
            listenable: doc,
            builder: (context, _) => FindPanel(
              controller: doc.find,
              editable: doc.editable,
              onClose: () => _invoke('write.find.close'),
            ),
          ),
        ),
        suggestionsPanelSpec(session),
        writeAssistantPanelSpec(ai),
      ],
    );
  }

  Widget _body(BuildContext context, DriveItemView item) {
    return ValueListenableBuilder<WriteSessionPhase>(
      valueListenable: session.phase,
      builder: (context, phase, _) {
        switch (phase) {
          case WriteSessionPhase.noAccess:
            return NoAccessPage(services: s, itemUuid: widget.itemUuid);
          case WriteSessionPhase.failed:
            return _failed(context);
          case WriteSessionPhase.loading:
            return const _CanvasLoading();
          case WriteSessionPhase.ready:
            return ImportWarningsBanner(
              services: s,
              documentUuid: item.contentRef,
              child: _canvas(context, item),
            );
        }
      },
    );
  }

  Widget _failed(BuildContext context) {
    final err = session.error;
    return WonkyEmptyState(
      illustration: err != null && isOfflineError(err)
          ? EmptyIllustration.offline
          : EmptyIllustration.error,
      title: err != null && isOfflineError(err)
          ? "This document isn't available offline"
          : 'Something went wrong opening this document',
      description: err == null ? null : errorMessage(err),
      actions: [
        ShadButton.outline(
          onPressed: () => unawaited(session.retry()),
          child: const Text('Try again'),
        ),
        ShadButton.ghost(
          onPressed: () => s.router.go('/'),
          child: const Text('Go back'),
        ),
      ],
    );
  }

  Widget _canvas(BuildContext context, DriveItemView item) {
    final brightness = ShadTheme.of(context).brightness;
    final ui = CommandUi(context, s);
    return ListenableBuilder(
      listenable: Listenable.merge([doc.documentTheme, doc.viewPrefs, session]),
      builder: (context, _) {
        final theme = doc.documentTheme.editorTheme(brightness);
        final suggesting = doc.editor.mode == EditorMode.suggesting;
        final editor = WonkyEditor(
          key: _editorKey,
          controller: doc.editor,
          commands: doc.commands,
          clipboard: doc.clipboard,
          theme: theme,
          documentTitle: item.name,
          imageServices: doc.images,
          scrollController: _scroll,
          keymap: (event) =>
              s.keymap.handle(event, KeyScope.editor, context: context) ==
              KeyEventResult.handled,
          shortcutCallbacks: EditorShortcutCallbacks(
            onUndo: () => _invoke('shell.edit.undo'),
            onRedo: () => _invoke('shell.edit.redo'),
            onInsertLink: () => _invoke('write.link.insert'),
            onCopy: () => _invoke('write.edit.copy'),
            onCut: () => _invoke('write.edit.cut'),
            onPaste: () => _invoke('write.edit.paste'),
            onPasteWithoutFormatting: () =>
                _invoke('write.edit.pasteWithoutFormatting'),
            onFind: () => _invoke('write.find.open'),
          ),
          slashHost: SlashHost(
            onInsertImage: () => _invoke('write.insert.image'),
            onInsertImageFromUrl: () => _invoke('write.insert.imageFromUrl'),
            onInsertLink: () => _invoke('write.link.insert'),
            onTableInserted: (id) =>
                _invoke('write.table.editCell', {'nodeId': id}),
            onComment: () => _invoke('shell.comments.create'),
            onEmoji: () => _invoke('write.insert.emoji'),
            onSpecialCharacter: () =>
                _invoke('write.insert.specialCharacter'),
            onAskAi: ai.shown ? () => _invoke('write.ai.inline') : null,
            onContinueWriting: ai.shown
                ? () => _invoke('write.ai.continue')
                : null,
          ),
          blockCallbacks: EditorBlockCallbacks(
            onEditTable: (nodeId, {row, column}) => _invoke(
              'write.table.edit',
              {'nodeId': nodeId, 'row': ?row, 'col': ?column},
            ),
            onCodeLanguageTap: (nodeId, rect) =>
                PopupMenuHost.maybeOf(_menuContext ?? context)?.show(
                  rect.bottomLeft,
                  () => codeLanguageEntries(ui, doc, nodeId: nodeId),
                ),
            onCopyCode: (nodeId) =>
                _invoke('write.code.copy', {'nodeId': nodeId}),
            onImageDoubleTap: (nodeId) =>
                _invoke('write.image.preview', {'nodeId': nodeId}),
            onImageTap: (nodeId) =>
                _invoke('write.image.preview', {'nodeId': nodeId}),
            onBlockHandleTap: (nodeId, rect) => PopupMenuHost.maybeOf(
              _menuContext ?? context,
            )?.show(rect.bottomLeft, () => blockMenuEntries(ui, doc, nodeId)),
            onRemoveImage: (nodeId) {
              final data = doc.embedData('image', nodeId);
              if (data != null) doc.images.cancel('${data['src']}');
              _invoke('write.block.delete', {'nodeId': nodeId});
            },
          ),
          mentionCandidates: _mentionCandidates,
          emojiSuggestions: _emoji,
          onDropFiles: (files, index) => unawaited(
            handleDroppedFiles(s, doc, files, index, context: context),
          ),
          onOpenLink: (url) =>
              unawaited(openWriteLink(s, doc, url, context: context)),
          onEditLink: () => _invoke('write.link.edit'),
          hint: doc.editable
              ? 'Type / for commands, @ to mention, or just start writing'
              : '',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _attachPagination();
        });
        return PopupMenuHost(
          child: Builder(
            builder: (context) {
              _menuContext = context;
              final stack = Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: (e) {
                        if (e.buttons == kSecondaryMouseButton) {
                          _openContextMenu(context, e.position);
                        }
                      },
                      child: SelectionToolbarLayer(
                        doc: doc,
                        ui: ui,
                        // Material ancestor for the editor's checkbox and
                        // text-selection widgets (the shell is shad-only).
                        child: Material(
                          type: MaterialType.transparency,
                          child: editor,
                        ),
                      ),
                    ),
                  ),
                  // Inline AI prompt, preview and ghost text (Write 09 §5.3).
                  Positioned.fill(child: AiPreviewLayer(ai: ai)),
                ],
              );
              return LayoutBuilder(
                builder: (context, c) => ListenableBuilder(
                  listenable: doc.editor.view,
                  builder: (context, _) => FocusModeChrome(
                    enabled: doc.editor.view.focusMode,
                    setChromeHidden: s.viewState.setFullScreen,
                    child: _withCue(
                      context,
                      _withMargin(context, c, stack),
                      suggesting: suggesting,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The suggesting-mode cue: a 2 px success-colored line across the whole
  /// canvas, comment margin included (Write 05 §3).
  Widget _withCue(
    BuildContext context,
    Widget canvas, {
    required bool suggesting,
  }) {
    if (!suggesting) return canvas;
    return Stack(
      children: [
        Positioned.fill(child: canvas),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 2,
          child: ColoredBox(
            key: const ValueKey<String>('write.canvas.suggestingCue'),
            color: ShadTheme.of(context).colorScheme.success,
          ),
        ),
      ],
    );
  }

  /// Width of the comment margin column including its padding.
  static const double _marginColumn = 300 + 8 + 16;

  /// The canvas with the comment margin beside it when there are cards and
  /// the page (at the current zoom) still fits next to it with gutters —
  /// otherwise cards live in the panels only (Write 05 §3).
  Widget _withMargin(BuildContext context, BoxConstraints c, Widget stack) {
    final theme = doc.documentTheme.editorTheme(
      ShadTheme.of(context).brightness,
    );
    final view = doc.editor.view;
    final pages = view.layout == LayoutMode.pages;
    final pageWidth = view.pageSetup.size.width * view.zoom;
    final hasCards =
        session.comments.anchoredOpenThreads.isNotEmpty ||
        session.suggestions.pending.isNotEmpty;
    final margin =
        hasCards &&
        doc.viewPrefs.showCommentMargin &&
        c.maxWidth >= math.max(1080, pageWidth + 2 * 32 + _marginColumn);
    if (!margin) return stack;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: stack),
        ColoredBox(
          color: pages ? theme.canvasColor : theme.paperColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
            child: CommentMargin(
              key: const ValueKey<String>('write.commentMargin'),
              session: session,
              width: 300,
              scrollController: _scroll,
            ),
          ),
        ),
      ],
    );
  }

  BuildContext? _menuContext;

  late final _emoji = emojiSuggester(s);

  void _openContextMenu(BuildContext context, Offset global) {
    final layout = doc.editor.documentLayout;
    if (layout != null) {
      final local = layout.getDocumentOffsetFromAncestorOffset(global);
      final position = layout.getDocumentPositionNearestToOffset(local);
      final offset = position == null
          ? null
          : doc.editor.mirror.offsetOf(position);
      final sel = doc.editor.selection;
      if (offset != null &&
          (sel == null ||
              sel.isCollapsed ||
              offset < sel.start ||
              offset > sel.end)) {
        doc.editor.select(DeltaSelection.collapsed(offset));
      }
    }
    final ui = CommandUi(context, s);
    PopupMenuHost.maybeOf(context)?.show(
      global,
      () => contextMenuEntries(ui, doc),
      onClosed: doc.focusEditor,
    );
  }

  Future<List<MentionCandidate>> _mentionCandidates(String query) async {
    try {
      final users = await s.repositories.users.searchUsers(query, limit: 8);
      return [
        for (final u in users)
          MentionCandidate(
            userUuid: u.uuid.uuid,
            displayName: u.displayName,
            email: u.email,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

class _CanvasLoading extends StatelessWidget {
  const _CanvasLoading();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ShadTheme.of(context).colorScheme.canvas,
    child: LoadingShimmer.documentPage(),
  );
}

// ---------------------------------------------------------------------------
// Status bar (Write 05 §11).

/// "1,234 words" / "56 of 1,234 words" (+ "Page 2 of 7").
class WordCountStatus extends StatelessWidget {
  const WordCountStatus({super.key, required this.doc});

  final WriteDocumentController doc;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        doc.insights,
        doc.viewPrefs,
        doc.pageCount,
      ]),
      builder: (context, _) {
        if (!doc.viewPrefs.showWordCount) return const SizedBox.shrink();
        final stats = doc.insights.stats;
        final label = wordCountLabel(stats, doc.insights.selectionStats);
        final pages = doc.view.layout == LayoutMode.pages
            ? doc.pageCount.value
            : null;
        return ShadTooltip(
          builder: (_) => Text(
            '${formatCount(stats.characters)} characters · '
            '${readingTime(stats)} read',
          ),
          child: GestureDetector(
            key: const ValueKey<String>('write.status.wordCount'),
            onTap: () => unawaited(
              invokeWith(
                ShellScope.of(context),
                'write.tools.wordCount',
                context: context,
              ),
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                pages == null || pages < 1
                    ? label
                    : '$label · $pages ${pages == 1 ? 'page' : 'pages'}',
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UploadsStatus extends StatelessWidget {
  const _UploadsStatus({required this.images});

  final WriteImageServices images;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: images.pendingUploads,
      builder: (context, n, _) => n == 0
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: ShadSpinner(size: 12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    n == 1 ? 'Uploading 1 image…' : 'Uploading $n images…',
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Pages / Pageless toggle (editors) or indicator.
class LayoutStatus extends StatelessWidget {
  const LayoutStatus({super.key, required this.doc});

  final WriteDocumentController doc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: doc,
      builder: (context, _) {
        final pages = doc.view.layout == LayoutMode.pages;
        final ui = CommandUi(context, ShellScope.of(context));
        return WonkyDropdownMenu(
          anchor: const ShadAnchor(
            childAlignment: AlignmentDirectional.topEnd,
            overlayAlignment: AlignmentDirectional.bottomEnd,
            offset: Offset(0, -4),
          ),
          entries: () => [
            ui.item(
              'write.doc.setLayout',
              args: {'layout': 'pages'},
              label: 'Pages',
              radio: true,
              keyName: 'layout.pages',
            ),
            ui.item(
              'write.doc.setLayout',
              args: {'layout': 'pageless'},
              label: 'Pageless',
              radio: true,
              keyName: 'layout.pageless',
            ),
            const WonkyMenuSeparator(),
            ui.item('write.doc.pageSetup', label: 'Page setup…'),
          ],
          builder: (context, c) => ShadButton.ghost(
            key: const ValueKey<String>('write.status.layout'),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            leading: Icon(
              pages ? LucideIcons.fileText : LucideIcons.scrollText,
              size: 13,
            ),
            onPressed: c.toggle,
            child: Text(
              pages ? 'Pages' : 'Pageless',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ),
        );
      },
    );
  }
}

/// − 100% + (Write 05 §11).
class ZoomStatus extends StatelessWidget {
  const ZoomStatus({super.key, required this.doc});

  final WriteDocumentController doc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: doc.view,
      builder: (context, _) {
        final s = ShellScope.of(context);
        final ui = CommandUi(context, s);
        final zoom = (doc.view.zoom * 100).round();
        Widget icon(String key, IconData i, String id, String label) =>
            ShadTooltip(
              builder: (_) => ToolbarTooltipContent(
                label: label,
                shortcut: s.keymap.labelsOf(id),
              ),
              child: ShadIconButton.ghost(
                key: ValueKey<String>(key),
                width: 22,
                height: 22,
                iconSize: 13,
                semanticLabel: label,
                icon: Icon(i),
                onPressed: () => ui.run(id),
              ),
            );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon(
              'write.status.zoomOut',
              LucideIcons.minus,
              'write.view.zoomOut',
              'Zoom out',
            ),
            WonkyDropdownMenu(
              anchor: const ShadAnchor(
                childAlignment: AlignmentDirectional.topCenter,
                overlayAlignment: AlignmentDirectional.bottomCenter,
                offset: Offset(0, -4),
              ),
              constraints: const BoxConstraints(minWidth: 120),
              entries: () => [
                for (final p in zoomPresets)
                  WonkyMenuRadioItem(
                    key: ValueKey<String>('menu.statusZoom.$p'),
                    label: '$p%',
                    selected: p == zoom,
                    onSelected: () =>
                        ui.run('write.view.zoomSet', {'percent': p}),
                  ),
                const WonkyMenuSeparator(),
                ui.item(
                  'write.view.zoomFit',
                  args: {'mode': 'width'},
                  label: 'Fit width',
                  keyName: 'status.fitWidth',
                ),
              ],
              builder: (context, c) => ShadButton.ghost(
                key: const ValueKey<String>('write.status.zoom'),
                height: 22,
                width: 48,
                padding: EdgeInsets.zero,
                onPressed: c.toggle,
                child: Text(
                  '$zoom%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            icon(
              'write.status.zoomIn',
              LucideIcons.plus,
              'write.view.zoomIn',
              'Zoom in',
            ),
          ],
        );
      },
    );
  }
}

/// Mode icon (pencil / suggest / eye) that opens the mode menu.
class ModeStatus extends StatelessWidget {
  const ModeStatus({super.key, required this.doc});

  final WriteDocumentController doc;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: doc,
      builder: (context, _) {
        final ui = CommandUi(context, ShellScope.of(context));
        final (icon, label, _) = ModeSwitcher.describe(doc.editor.mode);
        final cs = ShadTheme.of(context).colorScheme;
        return WonkyDropdownMenu(
          anchor: const ShadAnchor(
            childAlignment: AlignmentDirectional.topEnd,
            overlayAlignment: AlignmentDirectional.bottomEnd,
            offset: Offset(0, -4),
          ),
          entries: () => modeEntries(ui, doc),
          builder: (context, c) => ShadTooltip(
            builder: (_) => Text('$label mode'),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('write.status.mode'),
              width: 22,
              height: 22,
              iconSize: 13,
              semanticLabel: '$label mode',
              icon: Icon(
                icon,
                color: doc.editor.mode == EditorMode.suggesting
                    ? cs.success
                    : null,
              ),
              onPressed: c.toggle,
            ),
          ),
        );
      },
    );
  }
}
