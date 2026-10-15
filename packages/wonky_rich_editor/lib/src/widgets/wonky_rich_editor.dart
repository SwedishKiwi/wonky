import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../codec/inline_codec.dart';
import '../editor/markdown_editing_controller.dart';
import '../editor/rich_editor_reactions.dart';
import 'rich_editor_style.dart';

/// What the link dialog decided: a URL, or none to remove the link.
class RichLinkResult {
  const RichLinkResult(this.url);

  /// The link (null removes it).
  final String? url;
}

/// Asks for a link; [current] is the link being edited (null = a new
/// one). Returns null when cancelled.
typedef RichLinkRequest =
    Future<RichLinkResult?> Function(BuildContext context, String? current);

/// The labels of the editor (tooltips and screen readers); English by
/// default, the shell passes its translations.
class RichEditorLabels {
  const RichEditorLabels({
    this.bold = 'Bold',
    this.italic = 'Italic',
    this.strikethrough = 'Strikethrough',
    this.code = 'Code',
    this.link = 'Link',
    this.bulletedList = 'Bulleted list',
    this.numberedList = 'Numbered list',
    this.taskList = 'Checklist',
    this.quote = 'Quote',
    this.codeBlock = 'Code block',
    this.toolbar = 'Formatting',
    this.length = _length,
  });

  final String bold;
  final String italic;
  final String strikethrough;
  final String code;
  final String link;
  final String bulletedList;
  final String numberedList;
  final String taskList;
  final String quote;
  final String codeBlock;

  /// The toolbar's group label.
  final String toolbar;

  /// The character counter (`120 / 500`).
  final String Function(int count, int max) length;

  static String _length(int count, int max) => '$count / $max';
}

/// A lightweight WYSIWYG Markdown field (specs/16 §7.3): super_editor on
/// the Markdown of a [MarkdownEditingController], styled like the suite's
/// text inputs (shad input border, radius, focus ring, padding) and its
/// Markdown rendering, with a formatting toolbar.
///
/// - **Autoformat while typing** like Write (04 §7): `# ` headings, `- ` /
///   `* ` bullets, `1. ` numbers, `[] ` tasks, `> ` quotes, ```` ``` ````
///   code blocks, `---` rules, `**bold**`, `*italic*`, `~~strike~~`,
///   `` `code` `` and `[text](url)`.
/// - **Shortcuts** (Write 04 §10, §13): `Mod+B` / `I` / `E` (code),
///   `Mod+Shift+X` (strikethrough), `Mod+K` (link), `Mod+Shift+7` / `8` /
///   `9` (numbered, bulleted, checklist), `Mod+Shift+.` (quote), `Tab` /
///   `Shift+Tab` (list levels; elsewhere they move the focus), `Mod+Z` /
///   `Mod+Shift+Z` (the field's own undo), `Mod+V` (Markdown is converted;
///   `Mod+Shift+V` pastes plain text), `Mod+Enter` ([onSubmit]).
/// - The field grows from [minHeight] to [maxHeight] and then scrolls.
///
/// Stable keys from [fieldKey]: the field `<fieldKey>`, the toolbar
/// buttons `<fieldKey>.bold`, `.italic`, `.strike`, `.code`, `.link`,
/// `.bullets`, `.numbers`, `.tasks`, `.quote`, `.codeBlock`, the counter
/// `<fieldKey>.count`.
class WonkyRichEditor extends StatefulWidget {
  const WonkyRichEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.fieldKey = 'markdown.composer',
    this.hint,
    this.minHeight = 76,
    this.maxHeight = 260,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLength,
    this.toolbar = true,
    this.onSubmit,
    this.requestLink,
    this.labels = const RichEditorLabels(),
    this.customStylePhases = const [],
  });

  final MarkdownEditingController controller;
  final FocusNode? focusNode;

  /// The prefix of the stable keys.
  final String fieldKey;

  /// The placeholder of the empty field.
  final String? hint;

  /// The height of the field (the toolbar and counter come on top).
  final double minHeight;
  final double maxHeight;

  final bool autofocus;

  /// Disabled: greyed out, no editing, no toolbar.
  final bool enabled;

  /// Read-only: the text can be selected and copied, not changed.
  final bool readOnly;

  /// The maximum length of the Markdown (a counter shows from 80%).
  final int? maxLength;

  /// Whether the formatting toolbar shows.
  final bool toolbar;

  /// `Mod+Enter` (null: no shortcut).
  final VoidCallback? onSubmit;

  /// Asks for a link (defaults to a small dialog).
  final RichLinkRequest? requestLink;

  final RichEditorLabels labels;

  /// Extra style phases of the document (e.g. spelling squiggles).
  final List<SingleColumnLayoutStylePhase> customStylePhases;

  @override
  State<WonkyRichEditor> createState() => WonkyRichEditorState();
}

class WonkyRichEditorState extends State<WonkyRichEditor> {
  FocusNode? _ownFocus;
  final _scroll = ScrollController();
  final _layoutKey = GlobalKey();

  FocusNode get focusNode =>
      widget.focusNode ??
      (_ownFocus ??= FocusNode(debugLabel: 'WonkyRichEditor'));

  MarkdownEditingController get controller => widget.controller;

  bool get _editable => widget.enabled && !widget.readOnly;

  static bool get _mac =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _configure();
    focusNode.addListener(_onFocus);
    if (widget.autofocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !focusNode.hasFocus) focus();
      });
    }
  }

  @override
  void didUpdateWidget(WonkyRichEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      focusNode.addListener(_onFocus);
    }
    _configure();
  }

  void _configure() {
    controller
      ..readOnly = !_editable
      ..maxLength = widget.maxLength;
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocus);
    _ownFocus?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  /// Focuses the field (the caret at the end when there was none).
  void focus() {
    if (!widget.enabled) return;
    focusNode.requestFocus();
    if (controller.selection == null) controller.moveCaretToEnd();
  }

  // ------------------------------------------------------------ actions

  void _inline(InlineFormat f) {
    controller.toggleInline(f);
    focus();
  }

  void _block(BlockFormat f) {
    controller.toggleBlock(f);
    focus();
  }

  Future<void> editLink() async {
    if (!_editable || !controller.canLink) return;
    final current = controller.link;
    final selection = controller.selection;
    final result = await (widget.requestLink ?? _defaultLinkDialog)(
      context,
      current,
    );
    if (!mounted) return;
    if (result != null && selection != null) {
      controller.editor.execute([
        ChangeSelectionRequest(
          selection,
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
      controller.setLink(result.url);
    }
    focus();
  }

  Future<void> _paste({bool plain = false}) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted || text == null || text.isEmpty) return;
    controller.paste(text, plain: plain);
  }

  // ----------------------------------------------------------- keyboard

  ExecutionInstruction _keys({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      return ExecutionInstruction.continueExecution;
    }
    final keyboard = HardwareKeyboard.instance;
    final mod = _mac ? keyboard.isMetaPressed : keyboard.isControlPressed;
    final shift = keyboard.isShiftPressed;
    final alt = keyboard.isAltPressed;
    final key = keyEvent.logicalKey;
    ExecutionInstruction run(void Function() action) {
      action();
      return ExecutionInstruction.haltExecution;
    }

    if (mod && !alt) {
      switch (key) {
        case LogicalKeyboardKey.keyB when !shift:
          return run(() => _inline(InlineFormat.bold));
        case LogicalKeyboardKey.keyI when !shift:
          return run(() => _inline(InlineFormat.italic));
        case LogicalKeyboardKey.keyE when !shift:
          return run(() => _inline(InlineFormat.code));
        case LogicalKeyboardKey.keyX when shift:
          return run(() => _inline(InlineFormat.strikethrough));
        case LogicalKeyboardKey.keyK when !shift:
          return run(() => unawaited(editLink()));
        case LogicalKeyboardKey.keyZ:
          return run(shift ? controller.redo : controller.undo);
        case LogicalKeyboardKey.keyY when !_mac:
          return run(controller.redo);
        case LogicalKeyboardKey.keyV:
          return run(() => unawaited(_paste(plain: shift)));
        case LogicalKeyboardKey.digit7 when shift:
          return run(() => _block(BlockFormat.numberedList));
        case LogicalKeyboardKey.digit8 when shift:
          return run(() => _block(BlockFormat.bulletList));
        case LogicalKeyboardKey.digit9 when shift:
          return run(() => _block(BlockFormat.taskList));
        case LogicalKeyboardKey.period when shift:
          return run(() => _block(BlockFormat.quote));
        case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
          final submit = widget.onSubmit;
          if (submit == null) return ExecutionInstruction.continueExecution;
          return run(submit);
      }
      return ExecutionInstruction.continueExecution;
    }
    if (key == LogicalKeyboardKey.tab && !mod && !alt) {
      if (_inCode()) {
        if (!shift && _editable) {
          controller.editor.execute([
            const InsertPlainTextAtCaretRequest('  '),
          ]);
        }
        return ExecutionInstruction.haltExecution;
      }
      if (_editable && controller.indentItems(outdent: shift)) {
        return ExecutionInstruction.haltExecution;
      }
      // Elsewhere Tab leaves the field, like any other input.
      if (shift) {
        focusNode.previousFocus();
      } else {
        focusNode.nextFocus();
      }
      return ExecutionInstruction.haltExecution;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !mod &&
        !shift &&
        !alt &&
        _editable &&
        _enterConversion()) {
      return ExecutionInstruction.haltExecution;
    }
    return ExecutionInstruction.continueExecution;
  }

  bool _inCode() {
    final s = controller.selection;
    if (s == null) return false;
    return isCodeLike(controller.document.getNodeById(s.extent.nodeId));
  }

  /// ```` ```lang ```` + Enter makes a code block, `---` + Enter a rule
  /// (Write 04 §7.1).
  bool _enterConversion() {
    final s = controller.selection;
    if (s == null || !s.isCollapsed) return false;
    final node = controller.document.getNodeById(s.extent.nodeId);
    final p = s.extent.nodePosition;
    if (!isPlainParagraph(node) || p is! TextNodePosition) return false;
    final text = (node as ParagraphNode).text.toPlainText();
    if (p.offset != text.length) return false;
    final whole = DocumentRange(
      start: DocumentPosition(
        nodeId: node.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
      end: s.extent,
    );
    final caret = DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: node.id,
        nodePosition: const TextNodePosition(offset: 0),
      ),
    );
    final fence = RegExp(r'^```([\w+#.\-]*)$').firstMatch(text);
    if (fence != null) {
      controller.editor.execute([
        DeleteContentRequest(documentRange: whole),
        ...BlockPrefixReaction.codeBlockRequests(node.id, fence.group(1)!),
        ChangeSelectionRequest(
          caret,
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
      return true;
    }
    if (controller.features.rules &&
        RegExp(r'^(---|\*\*\*|___)$').hasMatch(text)) {
      controller.editor.execute([
        DeleteContentRequest(documentRange: whole),
        InsertNodeAtIndexRequest(
          nodeIndex: controller.document.getNodeIndexById(node.id),
          newNode: HorizontalRuleNode(id: Editor.createNodeId()),
        ),
        ChangeSelectionRequest(
          caret,
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
      return true;
    }
    return false;
  }

  static final _removedActions = <SuperEditorKeyboardAction>{
    undoWhenCmdZOrCtrlZIsPressed,
    redoWhenCmdShiftZOrCtrlShiftZIsPressed,
    cmdBToToggleBold,
    cmdIToToggleItalics,
    pasteWhenCmdVIsPressed,
    tabToIndentParagraph,
    shiftTabToUnIndentParagraph,
    backspaceToUnIndentParagraph,
    enterToUnIndentParagraph,
    tabToIndentTask,
    shiftTabToUnIndentTask,
    // Esc belongs to the dialog or page around the field.
    collapseSelectionWhenEscIsPressed,
  };

  static final List<SuperEditorKeyboardAction> _imeActions = [
    for (final a in defaultImeKeyboardActions)
      if (!_removedActions.contains(a)) a,
  ];

  // ---------------------------------------------------------- shortcuts

  List<String> _shortcut(String key, {bool shift = false}) =>
      _mac ? [if (shift) '⇧', '⌘', key] : ['Ctrl', if (shift) 'Shift', key];

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final style = RichEditorStyle.of(context);
    final theme = style.theme;
    final decoration = (theme.inputTheme.decoration ?? const ShadDecoration())
        .merge(theme.textareaTheme.decoration);
    final focused = focusNode.hasFocus;
    final max = widget.maxLength;
    final field = ShadDecorator(
      decoration: decoration,
      focused: focused && widget.enabled,
      child: Semantics(
        textField: true,
        multiline: true,
        readOnly: !_editable,
        enabled: widget.enabled,
        label: widget.hint,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerUp: (_) {
            // A tap below the text (inside the field) focuses it too.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !focusNode.hasFocus) focus();
            });
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minHeight,
              maxHeight: widget.maxHeight,
            ),
            child: KeyedSubtree(
              key: ValueKey<String>(widget.fieldKey),
              child: _editor(style),
            ),
          ),
        ),
      ),
    );
    return ShadDisabled(
      disabled: !widget.enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only the toolbar and the counter follow every keystroke.
          if (widget.toolbar) ...[
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _toolbar(context),
            ),
            const SizedBox(height: 4),
          ],
          field,
          if (max != null)
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final length = controller.length;
                if (length < max * 0.8) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.labels.length(length, max),
                    key: ValueKey<String>('${widget.fieldKey}.count'),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.muted.copyWith(
                      fontSize: 11,
                      color: length >= max
                          ? theme.colorScheme.destructive
                          : null,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  ShadThemeData? _styledTheme;
  String? _styledHint;
  late Stylesheet _stylesheet;
  late List<ComponentBuilder> _builders;

  Widget _editor(RichEditorStyle style) {
    final theme = style.theme;
    // A new stylesheet restyles the whole document: only on theme changes.
    if (!identical(theme, _styledTheme) || widget.hint != _styledHint) {
      _styledTheme = theme;
      _styledHint = widget.hint;
      _stylesheet = style.stylesheet();
      _builders = style.componentBuilders(controller.editor, hint: widget.hint);
    }
    // Its own scroll view: super_editor scrolls the nearest vertical
    // Scrollable, which must not be the dialog's or the page's.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: CustomScrollView(
        controller: _scroll,
        shrinkWrap: true,
        slivers: [
          SuperEditor(
            editor: controller.editor,
            focusNode: focusNode,
            documentLayoutKey: _layoutKey,
            inputSource: TextInputSource.ime,
            // Several fields can be on screen (a dialog over a page).
            inputRole: '${widget.fieldKey}#${identityHashCode(this)}',
            gestureMode: DocumentGestureMode.mouse,
            selectionPolicies: const SuperEditorSelectionPolicies(
              clearSelectionWhenEditorLosesFocus: false,
              clearSelectionWhenImeConnectionCloses: false,
            ),
            stylesheet: _stylesheet,
            customStylePhases: widget.customStylePhases,
            componentBuilders: _builders,
            selectionStyle: SelectionStyles(
              selectionColor: theme.colorScheme.selection,
            ),
            documentOverlayBuilders: [
              DefaultCaretOverlayBuilder(
                caretStyle: CaretStyle(
                  width: 2,
                  color: widget.enabled && !widget.readOnly
                      ? theme.colorScheme.primary
                      : const Color(0x00000000),
                ),
              ),
            ],
            keyboardActions: [_keys, ..._imeActions],
            // Links don't open while editing.
            contentTapDelegateFactories: const [],
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final l = widget.labels;
    final c = controller;
    final on = _editable;
    final inline = on && c.canFormatInline;
    final block = c.blockFormat;
    Widget toggle(
      String id,
      IconData icon,
      String label,
      bool value,
      bool enabled,
      VoidCallback action, {
      List<String>? shortcut,
    }) {
      final size = WonkyThemeScope.of(context).toolbarButtonSize;
      // Like wonky_ui's ToolbarToggleButton (Write's toolbar), with a
      // tooltip that wraps instead of overflowing.
      return ShadTooltip(
        builder: (_) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label)),
            if (enabled && shortcut != null) ...[
              const SizedBox(width: 8),
              ShadKbd.group(shortcut, height: 18),
            ],
          ],
        ),
        child: ShadToggle(
          key: ValueKey<String>('${widget.fieldKey}.$id'),
          value: value,
          enabled: enabled,
          onChanged: (_) => action(),
          width: size,
          height: size,
          padding: EdgeInsets.zero,
          semanticLabel: label,
          child: Icon(icon, size: 16),
        ),
      );
    }

    Widget gap() => const SizedBox(width: 6);
    return Semantics(
      container: true,
      label: l.toolbar,
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          toggle(
            'bold',
            LucideIcons.bold,
            l.bold,
            c.isActive(InlineFormat.bold),
            inline,
            () => _inline(InlineFormat.bold),
            shortcut: _shortcut('B'),
          ),
          toggle(
            'italic',
            LucideIcons.italic,
            l.italic,
            c.isActive(InlineFormat.italic),
            inline,
            () => _inline(InlineFormat.italic),
            shortcut: _shortcut('I'),
          ),
          toggle(
            'strike',
            LucideIcons.strikethrough,
            l.strikethrough,
            c.isActive(InlineFormat.strikethrough),
            inline,
            () => _inline(InlineFormat.strikethrough),
            shortcut: _shortcut('X', shift: true),
          ),
          toggle(
            'code',
            LucideIcons.code,
            l.code,
            c.isActive(InlineFormat.code),
            inline,
            () => _inline(InlineFormat.code),
            shortcut: _shortcut('E'),
          ),
          toggle(
            'link',
            LucideIcons.link,
            l.link,
            c.link != null,
            inline,
            () => unawaited(editLink()),
            shortcut: _shortcut('K'),
          ),
          gap(),
          toggle(
            'bullets',
            LucideIcons.list,
            l.bulletedList,
            block == BlockFormat.bulletList,
            on && c.canFormatBlock(BlockFormat.bulletList),
            () => _block(BlockFormat.bulletList),
            shortcut: _shortcut('8', shift: true),
          ),
          toggle(
            'numbers',
            LucideIcons.listOrdered,
            l.numberedList,
            block == BlockFormat.numberedList,
            on && c.canFormatBlock(BlockFormat.numberedList),
            () => _block(BlockFormat.numberedList),
            shortcut: _shortcut('7', shift: true),
          ),
          toggle(
            'tasks',
            LucideIcons.listTodo,
            l.taskList,
            block == BlockFormat.taskList,
            on && c.canFormatBlock(BlockFormat.taskList),
            () => _block(BlockFormat.taskList),
            shortcut: _shortcut('9', shift: true),
          ),
          gap(),
          if (c.features.quotes)
            toggle(
              'quote',
              LucideIcons.quote,
              l.quote,
              block == BlockFormat.quote,
              on && c.canFormatBlock(BlockFormat.quote),
              () => _block(BlockFormat.quote),
              shortcut: _shortcut('.', shift: true),
            ),
          toggle(
            'codeBlock',
            LucideIcons.squareCode,
            l.codeBlock,
            block == BlockFormat.codeBlock,
            on && c.canFormatBlock(BlockFormat.codeBlock),
            () => _block(BlockFormat.codeBlock),
          ),
        ],
      ),
    );
  }

  /// A minimal link dialog when the host provides none.
  Future<RichLinkResult?> _defaultLinkDialog(
    BuildContext context,
    String? current,
  ) => showShadDialog<RichLinkResult>(
    context: context,
    builder: (context) => _LinkDialog(current: current, labels: widget.labels),
  );
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.current, required this.labels});

  final String? current;
  final RichEditorLabels labels;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _url = TextEditingController(text: widget.current ?? 'https://');
  bool _invalid = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _apply() {
    final target = normalizeLinkTarget(_url.text);
    if (target == null || !isSafeLink(target)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(RichLinkResult(target));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadDialog(
      key: const ValueKey<String>('dialog.markdown.link'),
      title: Text(widget.labels.link),
      actions: [
        if (widget.current != null)
          ShadButton.outline(
            key: const ValueKey<String>('dialog.markdown.link.remove'),
            onPressed: () =>
                Navigator.of(context).pop(const RichLinkResult(null)),
            child: const Icon(LucideIcons.unlink, size: 16),
          ),
        ShadButton(
          key: const ValueKey<String>('dialog.markdown.link.ok'),
          onPressed: _apply,
          child: const Icon(LucideIcons.check, size: 16),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            key: const ValueKey<String>('dialog.markdown.link.url'),
            controller: _url,
            autofocus: true,
            onSubmitted: (_) => _apply(),
          ),
          if (_invalid)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'http(s) / mailto',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
