import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_rich_editor/wonky_rich_editor.dart';

import '../l10n/wonky_app_localizations.dart';
import '../shell/form_dialog.dart';
import '../shell/shell_scope.dart';
import '../spellcheck/shell_spelling.dart';
import 'markdown_inline.dart';
import 'wonky_markdown.dart';

/// The corner radius of the [MarkdownComposer] (the suite's text inputs:
/// the shad input and textarea decoration), for placeholders that open
/// into one, like the collapsed *Add a comment* field.
BorderRadius composerRadius(ShadThemeData theme) {
  final decoration = (theme.inputTheme.decoration ?? const ShadDecoration())
      .merge(theme.textareaTheme.decoration);
  final radius = decoration.border?.radius;
  return radius is BorderRadius ? radius : theme.radius;
}

/// The suite's Markdown composer (specs/16 §7.3): a WYSIWYG field
/// ([WonkyRichEditor], `wonky_rich_editor`) over the Markdown in
/// [controller], with a formatting toolbar — Bold `Mod+B`, Italic `Mod+I`,
/// Strikethrough `Mod+Shift+X`, Code `Mod+E`, Link `Mod+K` (asks for an
/// http(s) or mailto URL), Bulleted / Numbered / Checklist
/// (`Mod+Shift+8` / `7` / `9`) and Quote — and Write's Markdown autoformat
/// while typing. `Mod+Enter` submits. There are no code blocks (inline code
/// stays): a fence is text, and fenced code set or pasted as Markdown is a
/// literal block written back as it was.
///
/// The text stays Markdown: [controller] holds it, exactly as set until
/// the user edits, and only the edited blocks are rewritten afterwards. The
/// [profile] decides the blocks (comments have no headings, quotes or
/// rules; those stay text, as the comment renderer shows them).
///
/// Stable keys, from [fieldKey] (`markdown.composer` by default): the field
/// is `<fieldKey>`, the toolbar buttons `<fieldKey>.bold`, `.italic`,
/// `.strike`, `.code`, `.link`, `.bullets`, `.numbers`, `.tasks`, `.quote`,
/// the counter `<fieldKey>.count`. (The *Write | Preview*
/// toggle and its keys `.write`, `.preview`, `.rendered` are gone: the
/// field is the preview.) Tests type with `enterMarkdown`
/// (`package:wonky_rich_editor/testing.dart`).
///
/// Edits, including the toolbar's, are undone with the field's own undo
/// (`Mod+Z`, `Mod+Shift+Z`), never the shell's. `Mod+C` / `Mod+X` copy the
/// selection as Markdown, and pasting it gives the same content back.
///
/// With [spellcheck] (and a shell around it) misspelled words are
/// underlined and a right-click offers suggestions, *Ignore* and *Add to
/// dictionary* ([ShellSpelling]: the user's *Check spelling* setting,
/// personal dictionary and device language).
class MarkdownComposer extends StatefulWidget {
  const MarkdownComposer({
    super.key,
    this.controller,
    this.focusNode,
    this.fieldKey = 'markdown.composer',
    this.profile = MarkdownProfile.comment,
    this.hint,
    this.maxLength,
    this.minLines = 3,
    this.maxLines = 12,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmit,
    this.requestLink,
    this.spellcheck = true,
  });

  /// The Markdown (created and owned by the composer when null). Setting
  /// its text replaces the content; its selection is not used.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// The prefix of the stable keys.
  final String fieldKey;

  /// Which blocks the field supports (posts: all; comments: no headings,
  /// quotes or rules).
  final MarkdownProfile profile;

  /// The placeholder.
  final String? hint;

  /// The maximum length of the Markdown (a counter shows near the limit).
  final int? maxLength;

  /// The height of the field in lines.
  final int minLines;
  final int maxLines;

  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// `Mod+Enter` (null: no shortcut).
  final VoidCallback? onSubmit;

  /// Asks for a link URL (defaults to a dialog that can also remove a
  /// link); null = cancelled.
  final Future<String?> Function(BuildContext context)? requestLink;

  /// Whether misspelled words are underlined (when the user's setting is
  /// on; needs the shell's services).
  final bool spellcheck;

  /// The block features of [profile].
  static MarkdownBlockFeatures featuresOf(MarkdownProfile profile) =>
      MarkdownBlockFeatures(
        headings: profile.headings,
        quotes: profile.quotes,
        rules: profile.rules,
      );

  @override
  State<MarkdownComposer> createState() => MarkdownComposerState();
}

class MarkdownComposerState extends State<MarkdownComposer> {
  TextEditingController? _ownController;
  late final MarkdownEditingController _rich;
  final _editor = GlobalKey<WonkyRichEditorState>();
  bool _syncing = false;
  ShellSpelling? _spelling;

  /// The Markdown text.
  TextEditingController get controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  /// The rich editor's controller (selection, formatting, local undo).
  MarkdownEditingController get editor => _rich;

  @override
  void initState() {
    super.initState();
    _rich = MarkdownEditingController(
      markdown: controller.text,
      features: MarkdownComposer.featuresOf(widget.profile),
    )..addListener(_fromEditor);
    controller.addListener(_fromText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpelling();
  }

  /// One checker per composer, over the services' preferences.
  void _syncSpelling() {
    final prefs = widget.spellcheck ? ShellScope.maybeOf(context)?.prefs : null;
    if (identical(prefs, _spelling?.prefs)) return;
    _spelling?.dispose();
    _spelling = prefs == null ? null : ShellSpelling(prefs);
  }

  @override
  void didUpdateWidget(MarkdownComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_fromText);
      controller.addListener(_fromText);
      _fromText();
    }
    _rich.features = MarkdownComposer.featuresOf(widget.profile);
    if (oldWidget.spellcheck != widget.spellcheck) _syncSpelling();
  }

  @override
  void dispose() {
    _spelling?.dispose();
    controller.removeListener(_fromText);
    _rich
      ..removeListener(_fromEditor)
      ..dispose();
    _ownController?.dispose();
    super.dispose();
  }

  /// The editor changed: the text follows.
  void _fromEditor() {
    final markdown = _rich.markdown;
    if (_syncing || markdown == controller.text) return;
    _syncing = true;
    try {
      controller.value = TextEditingValue(
        text: markdown,
        selection: TextSelection.collapsed(offset: markdown.length),
      );
    } finally {
      _syncing = false;
    }
    widget.onChanged?.call(markdown);
  }

  /// The text was set from outside (cleared after sending, a new draft):
  /// the editor follows.
  void _fromText() {
    if (_syncing || controller.text == _rich.markdown) return;
    _syncing = true;
    try {
      _rich.markdown = controller.text;
    } finally {
      _syncing = false;
    }
  }

  /// Focuses the field.
  void focus() => _editor.currentState?.focus();

  Future<RichLinkResult?> _requestLink(
    BuildContext context,
    String? current,
  ) async {
    final custom = widget.requestLink;
    if (custom != null) {
      final url = await custom(context);
      return url == null || url.trim().isEmpty
          ? null
          : RichLinkResult(url.trim());
    }
    final l = WonkyAppLocalizations.of(context);
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: current == null ? l.markdownLinkTitle : l.markdownLinkEditTitle,
        dialogKey: 'dialog.markdown.link',
        fields: [
          TextFieldSpec(
            id: 'url',
            label: l.markdownLinkUrl,
            initial: current ?? '',
            placeholder: 'https://',
            maxLength: 2000,
            validator: (v) {
              final target = normalizeLinkTarget(v);
              return target == null || MarkdownInline.safeUrl(target) == null
                  ? l.markdownLinkInvalid
                  : null;
            },
          ),
        ],
        buttons: [
          DialogButtonSpec(id: 'cancel', label: l.actionCancel),
          if (current != null)
            DialogButtonSpec(
              id: 'remove',
              label: l.markdownLinkRemove,
              validates: false,
            ),
          DialogButtonSpec(
            id: 'ok',
            label: current == null ? l.markdownLinkInsert : l.actionSave,
            primary: true,
          ),
        ],
      ),
    );
    return switch (r?.buttonId) {
      'ok' => RichLinkResult(r!.text('url').trim()),
      'remove' => const RichLinkResult(null),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    // The renderer's line height (14 × 1.45) plus the field's padding.
    const lineHeight = 20.3;
    return WonkyRichEditor(
      key: _editor,
      controller: _rich,
      focusNode: widget.focusNode,
      fieldKey: widget.fieldKey,
      hint: widget.hint,
      minHeight: widget.minLines * lineHeight + 16,
      maxHeight: widget.maxLines * lineHeight + 16,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      onSubmit: widget.onSubmit,
      requestLink: _requestLink,
      spellChecker: _spelling,
      labels: RichEditorLabels(
        bold: l.markdownBold,
        italic: l.markdownItalic,
        strikethrough: l.markdownStrikethrough,
        code: l.markdownCode,
        link: l.markdownLink,
        bulletedList: l.markdownBulletedList,
        numberedList: l.markdownNumberedList,
        taskList: l.markdownTaskList,
        quote: l.markdownQuote,
        toolbar: l.markdownToolbar,
        length: l.markdownLength,
        cut: l.cmdCut,
        copy: l.cmdCopy,
        paste: l.cmdPaste,
        spelling: SpellingMenuLabels(
          noSuggestions: l.spellingNoSuggestions,
          ignore: l.spellingIgnore,
          addToDictionary: (_) => l.spellingAddToDictionary,
        ),
      ),
    );
  }
}
