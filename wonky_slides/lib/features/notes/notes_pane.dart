import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart' show WonkyMenuEntry, WonkyPopupMenuHost;
import 'package:wonky_slides_core/model.dart' show SlidesText;

import '../collab/presence_widgets.dart' show NotesLockBanner;
import '../text_editing/text_editing_host.dart'
    show TextLockTarget, textEditingOf;
import '../../commands/navigator_commands.dart' show notesZoomOf;
import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../text_editing/slide_text_editor.dart' show SlideTextEditAddon;
import 'notes_edit_controller.dart';
import 'notes_view.dart';

/// The speaker notes pane below the canvas (Slides 04 §8): a handle bar
/// ("Speaker notes ⌃", `slides.view.toggleNotes`) and the current slide's
/// notes in the `slidesNotes` key scope.
///
/// Editors click the notes (or press Enter on the focused pane) to edit
/// them in place: super_editor on the notes subset of the text schema, in
/// the app UI font at 14 px × the notes zoom (`slides.notes.zoom`), with a
/// mini toolbar (bold, italic, underline, bulleted and numbered lists,
/// link) while editing; typing is written after 300 ms idle and on blur,
/// one undo step per burst. Esc returns to the canvas. Viewers and
/// commenters see the notes read-only.
class NotesPane extends StatefulWidget {
  /// The entries of a right-click at notes position [position] (SL-44:
  /// spelling suggestions of the word under the pointer); no menu when
  /// empty. Set by the spelling feature.
  static List<WonkyMenuEntry> Function(
    DeckEditorController editor,
    NotesEditController edit,
    DocumentPosition position,
  )?
  contextMenuEntries;

  /// Additions to every notes editing session (SL-44: spelling
  /// squiggles), registered by other features; each may return null.
  static final List<
    SlideTextEditAddon? Function(
      DeckEditorController editor,
      NotesEditController edit,
    )
  >
  addonFactories = [];

  const NotesPane({
    super.key,
    required this.services,
    required this.editor,
    required this.expanded,
  });

  final ShellServices services;
  final DeckEditorController editor;

  /// Whether the body shows (collapsed = only the handle bar).
  final bool expanded;

  @override
  State<NotesPane> createState() => _NotesPaneState();
}

class _NotesPaneState extends State<NotesPane> {
  NotesEditController? _edit;
  final _editorFocus = FocusNode(debugLabel: 'slides.notes.editor');
  final _layoutKey = GlobalKey(debugLabel: 'slides.notes.layout');
  final _scroll = ScrollController();

  DeckEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    ed.addListener(_onEditor);
    _editorFocus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(NotesPane old) {
    super.didUpdateWidget(old);
    if (!identical(old.editor, widget.editor)) {
      old.editor.removeListener(_onEditor);
      widget.editor.addListener(_onEditor);
      _stopEditing();
    }
    if (!widget.expanded) _stopEditing();
  }

  @override
  void dispose() {
    ed.removeListener(_onEditor);
    _editorFocus.removeListener(_onFocus);
    final e = _edit;
    if (e != null) {
      textEditingOf(ed).locks.releaseTarget(TextLockTarget.notes(e.slideId));
    }
    _edit?.dispose();
    _editorFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onEditor() {
    final e = _edit;
    // Another slide (or Viewing mode): the edit ends.
    if (e != null && (e.slideId != ed.currentSlideId || !ed.canEdit)) {
      _stopEditing();
    }
  }

  void _onFocus() {
    if (!_editorFocus.hasFocus && _edit != null) _stopEditing();
  }

  Future<void> _startEditing() async {
    final id = ed.currentSlideId;
    if (id == null || !ed.canEdit || _edit != null) return;
    // Soft lock (SL-21, 02 §4.4): notes someone else edits ask first.
    final locks = textEditingOf(ed).locks;
    final target = TextLockTarget.notes(id);
    final allowed = locks.requestTarget(target);
    if (!(allowed is bool ? allowed : await allowed)) return;
    if (!mounted || ed.currentSlideId != id || !ed.canEdit || _edit != null) {
      return;
    }
    final l = slidesL10n(context);
    final edit = NotesEditController(
      session: ed.session,
      slideId: id,
      undo: widget.services.undo,
      undoLabel: l.cmdEditNotes,
    );
    for (final f in NotesPane.addonFactories) {
      final a = f(ed, edit);
      if (a != null) edit.addons.add(a);
    }
    setState(() => _edit = edit);
    locks.claimTarget(
      target,
      activity: edit,
      stop: () {
        if (identical(_edit, edit)) _stopEditing();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _edit != null) _editorFocus.requestFocus();
    });
  }

  void _stopEditing() {
    final e = _edit;
    if (e == null) return;
    _edit = null;
    textEditingOf(ed).locks.releaseTarget(TextLockTarget.notes(e.slideId));
    e.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final handle = Semantics(
      button: true,
      expanded: widget.expanded,
      label: l.notesLabel,
      child: GestureDetector(
        key: const ValueKey<String>('slides.notes.handle'),
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.services.dispatcher.invoke(
          'slides.view.toggleNotes',
          source: InvocationSource.ui,
          context: context,
        ),
        child: SizedBox(
          height: 26,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(
                l.notesLabel,
                style: theme.textTheme.small.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                widget.expanded
                    ? LucideIcons.chevronDown
                    : LucideIcons.chevronUp,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
    return DecoratedBox(
      key: const ValueKey<String>('slides.notes'),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: handle),
              if (_edit != null && widget.expanded)
                _MiniToolbar(controller: _edit!, onLink: _editLink),
            ],
          ),
          // "✎ Bo is editing the notes" / the soft-lock question (SL-21).
          if (widget.expanded) NotesLockBanner(editor: ed),
          if (widget.expanded)
            Expanded(
              child: KeymapScope(
                scope: SlidesKeyScopes.notes,
                keymap: widget.services.keymap,
                focusNode: ed.notesFocus,
                child: ValueListenableBuilder<int>(
                  valueListenable: notesZoomOf(ed),
                  builder: (context, zoom, _) => ListenableBuilder(
                    listenable: ed,
                    builder: (context, _) => _body(context, zoom),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _style(BuildContext context, int zoom) {
    final theme = ShadTheme.of(context);
    return theme.textTheme.p.copyWith(
      fontSize: 14 * zoom / 100,
      height: 1.45,
      color: theme.colorScheme.foreground,
    );
  }

  Widget _body(BuildContext context, int zoom) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final edit = _edit;
    final style = _style(context, zoom);
    if (edit != null) return _editorView(context, edit, style);
    final slide = ed.currentEntry?.slide;
    final notes = slide?.notes;
    final empty = notes == null || SlidesText.isBlank(notes);
    final Widget content;
    if (slide == null) {
      content = Text(l.notesNoSlide, style: theme.textTheme.muted);
    } else if (empty) {
      content = Text(
        ed.canEdit ? l.notesPlaceholder : '',
        key: const ValueKey<String>('slides.notes.placeholder'),
        style: theme.textTheme.muted.copyWith(fontSize: style.fontSize),
      );
    } else {
      content = NotesRichView(
        json: notes,
        style: style,
        linkColor: theme.colorScheme.primary,
      );
    }
    return MouseRegion(
      cursor: ed.canEdit && slide != null
          ? SystemMouseCursors.text
          : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (ed.canEdit) {
            _startEditing();
          } else {
            ed.notesFocus.requestFocus();
          }
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, e) {
            if (e is KeyDownEvent &&
                e.logicalKey == LogicalKeyboardKey.enter &&
                ed.notesFocus.hasPrimaryFocus) {
              _startEditing();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: KeyedSubtree(
              key: const ValueKey<String>('slides.notes.text'),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _editorView(
    BuildContext context,
    NotesEditController edit,
    TextStyle style,
  ) {
    final theme = ShadTheme.of(context);
    final stylesheet = Stylesheet(
      documentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      inlineTextStyler: (attributions, base) {
        var s = defaultInlineTextStyler(attributions, base);
        if (attributions.any((a) => a is LinkAttribution)) {
          s = s.copyWith(color: theme.colorScheme.primary);
        }
        return s;
      },
      rules: [
        StyleRule(
          BlockSelector.all,
          (doc, node) => {
            Styles.maxWidth: double.infinity,
            Styles.padding: const CascadingPadding.only(bottom: 2),
            Styles.textStyle: style,
          },
        ),
      ],
    );
    return KeyedSubtree(
      key: const ValueKey<String>('slides.notes.text'),
      child: Listener(
        onPointerDown: (e) {
          if (e.buttons & kSecondaryMouseButton != 0) _contextMenu(edit, e);
        },
        child: _superEditor(edit, stylesheet, theme),
      ),
    );
  }

  /// A right-click on the notes being edited: the spelling menu of the
  /// word under the pointer (SL-44), if any.
  void _contextMenu(NotesEditController edit, PointerDownEvent e) {
    final entries = NotesPane.contextMenuEntries;
    final layout = _layoutKey.currentState;
    if (entries == null || layout is! DocumentLayout) return;
    final doc = layout as DocumentLayout;
    final pos = doc.getDocumentPositionNearestToOffset(
      doc.getDocumentOffsetFromAncestorOffset(e.position),
    );
    if (pos == null) return;
    final list = entries(ed, edit, pos);
    if (list.isEmpty) return;
    WonkyPopupMenuHost.maybeOf(context)?.show(e.position, () => list);
  }

  Widget _superEditor(
    NotesEditController edit,
    Stylesheet stylesheet,
    ShadThemeData theme,
  ) {
    return KeyedSubtree(
      key: const ValueKey<String>('slides.notes.superEditor'),
      child: SuperEditor(
        key: ValueKey<String>('slides.notes.editor.${edit.slideId}'),
        editor: edit.editor,
        documentLayoutKey: _layoutKey,
        customStylePhases: [for (final a in edit.addons) ?a.stylePhase],
        focusNode: _editorFocus,
        inputSource: TextInputSource.ime,
        gestureMode: DocumentGestureMode.mouse,
        stylesheet: stylesheet,
        selectionStyle: SelectionStyles(
          selectionColor: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
        documentOverlayBuilders: [
          DefaultCaretOverlayBuilder(
            caretStyle: CaretStyle(width: 2, color: theme.colorScheme.primary),
          ),
        ],
        keyboardActions: [_hostKeys, ..._imeActions],
        contentTapDelegateFactories: const [],
      ),
    );
  }

  /// Esc returns to the canvas; Mod+Z / Mod+Shift+Z go to the shell's undo
  /// stack (pending typing written first); Mod+B/I/U format.
  ExecutionInstruction _hostKeys({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      return ExecutionInstruction.continueExecution;
    }
    final edit = _edit;
    if (edit == null) return ExecutionInstruction.continueExecution;
    final keyboard = HardwareKeyboard.instance;
    final mod = defaultTargetPlatform == TargetPlatform.macOS
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    final key = keyEvent.logicalKey;
    if (key == LogicalKeyboardKey.escape && !mod) {
      edit.commit();
      ed.canvasFocus.requestFocus();
      return ExecutionInstruction.haltExecution;
    }
    if (!mod) return ExecutionInstruction.continueExecution;
    String? command;
    if (key == LogicalKeyboardKey.keyZ) {
      command = keyboard.isShiftPressed ? 'shell.edit.redo' : 'shell.edit.undo';
    } else if (key == LogicalKeyboardKey.keyY &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      command = 'shell.edit.redo';
    }
    if (command != null) {
      edit.commit();
      widget.services.dispatcher.invoke(
        command,
        source: InvocationSource.shortcut,
      );
      return ExecutionInstruction.haltExecution;
    }
    final attribution = switch (key) {
      LogicalKeyboardKey.keyB => boldAttribution,
      LogicalKeyboardKey.keyI => italicsAttribution,
      LogicalKeyboardKey.keyU => underlineAttribution,
      _ => null,
    };
    if (attribution != null) {
      edit.toggleAttribution(attribution);
      return ExecutionInstruction.haltExecution;
    }
    return ExecutionInstruction.continueExecution;
  }

  static final _removed = <SuperEditorKeyboardAction>{
    undoWhenCmdZOrCtrlZIsPressed,
    redoWhenCmdShiftZOrCtrlShiftZIsPressed,
    collapseSelectionWhenEscIsPressed,
  };

  static final List<SuperEditorKeyboardAction> _imeActions = [
    for (final a in defaultImeKeyboardActions)
      if (!_removed.contains(a)) a,
  ];

  Future<void> _editLink() async {
    final edit = _edit;
    if (edit == null || !edit.hasRange) return;
    final l = slidesL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final current = edit.link;
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: l.notesLinkTitle,
        dialogKey: 'dialog.slides.notesLink',
        fields: [
          TextFieldSpec(
            id: 'url',
            label: l.notesLinkUrl,
            initial: current ?? 'https://',
            validator: (v) {
              final u = Uri.tryParse(v.trim());
              return u != null &&
                      (u.scheme == 'http' || u.scheme == 'https') &&
                      u.host.isNotEmpty
                  ? null
                  : l.notesLinkInvalid;
            },
          ),
        ],
        buttons: [
          DialogButtonSpec(id: 'cancel', label: la.actionCancel),
          if (current != null)
            DialogButtonSpec(
              id: 'remove',
              label: l.notesLinkRemove,
              validates: false,
            ),
          DialogButtonSpec(id: 'apply', label: l.notesLinkApply, primary: true),
        ],
      ),
    );
    if (!mounted || _edit != edit) return;
    switch (r?.buttonId) {
      case 'apply':
        edit.setLink(r!.text('url').trim());
      case 'remove':
        edit.setLink(null);
    }
    _editorFocus.requestFocus();
  }
}

/// The mini toolbar of the notes editor (04 §8): B, I, U, bulleted and
/// numbered lists, link. Its buttons never take focus from the editor.
class _MiniToolbar extends StatelessWidget {
  const _MiniToolbar({required this.controller, required this.onLink});

  final NotesEditController controller;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    return ListenableBuilder(
      listenable: controller.composer,
      builder: (context, _) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(
                context,
                'bold',
                LucideIcons.bold,
                l.notesBold,
                controller.hasAttribution(boldAttribution),
                () => controller.toggleAttribution(boldAttribution),
              ),
              _button(
                context,
                'italic',
                LucideIcons.italic,
                l.notesItalic,
                controller.hasAttribution(italicsAttribution),
                () => controller.toggleAttribution(italicsAttribution),
              ),
              _button(
                context,
                'underline',
                LucideIcons.underline,
                l.notesUnderline,
                controller.hasAttribution(underlineAttribution),
                () => controller.toggleAttribution(underlineAttribution),
              ),
              _button(
                context,
                'bullets',
                LucideIcons.list,
                l.notesBulletList,
                controller.listType == ListItemType.unordered,
                () => controller.toggleList(ListItemType.unordered),
              ),
              _button(
                context,
                'numbers',
                LucideIcons.listOrdered,
                l.notesNumberedList,
                controller.listType == ListItemType.ordered,
                () => controller.toggleList(ListItemType.ordered),
              ),
              _button(
                context,
                'link',
                LucideIcons.link,
                l.notesLink,
                controller.link != null,
                controller.hasRange ? onLink : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String id,
    IconData icon,
    String tooltip,
    bool on,
    VoidCallback? onTap,
  ) {
    final theme = ShadTheme.of(context);
    return ShadTooltip(
      builder: (_) => Text(tooltip),
      child: Semantics(
        button: true,
        toggled: on,
        label: tooltip,
        child: GestureDetector(
          key: ValueKey<String>('slides.notes.toolbar.$id'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 24,
            height: 22,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: on ? theme.colorScheme.accent : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 13,
              color: onTap == null
                  ? theme.colorScheme.mutedForeground.withValues(alpha: 0.5)
                  : theme.colorScheme.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
