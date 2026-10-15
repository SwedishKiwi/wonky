import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show KeyBinding;

import '../bootstrap/platform.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/dialogs.dart';
import 'markdown_edits.dart';
import 'markdown_inline.dart';
import 'wonky_markdown.dart';

/// A Markdown text box with a small toolbar and a *Write | Preview* toggle
/// (specs/16 §7.3): Bold `Mod+B`, Italic `Mod+I`, Code `Mod+E`, Link `Mod+K`
/// (asks for a URL) and Bulleted list wrap the selection with Markdown
/// ([MarkdownEdits]); `Mod+Enter` submits. The preview renders
/// [WonkyMarkdown] with [profile].
///
/// Stable keys, from [fieldKey] (`markdown.composer` by default): the field
/// is `<fieldKey>`, the toolbar buttons `<fieldKey>.bold`, `.italic`,
/// `.code`, `.link`, `.bullets`, the toggle `<fieldKey>.write` /
/// `<fieldKey>.preview` and the rendered preview `<fieldKey>.rendered`.
///
/// Text edits, including the toolbar's, are undone with the text field's
/// own undo (`Mod+Z`).
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
  });

  /// The text (created and owned by the composer when null).
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// The prefix of the stable keys.
  final String fieldKey;

  /// What the preview renders.
  final MarkdownProfile profile;

  /// The placeholder.
  final String? hint;

  /// The maximum length in characters (a counter shows near the limit).
  final int? maxLength;

  /// The height of the field in lines.
  final int minLines;
  final int maxLines;

  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// `Mod+Enter` (null: no shortcut).
  final VoidCallback? onSubmit;

  /// Asks for a link URL (defaults to a dialog); null = cancelled.
  final Future<String?> Function(BuildContext context)? requestLink;

  @override
  State<MarkdownComposer> createState() => MarkdownComposerState();
}

class MarkdownComposerState extends State<MarkdownComposer> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  bool _preview = false;

  TextEditingController get controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get focusNode =>
      widget.focusNode ??
      (_ownFocus ??= FocusNode(debugLabel: 'MarkdownComposer'));

  /// Whether the preview is shown.
  bool get previewing => _preview;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onText);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !focusNode.hasFocus) focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(MarkdownComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onText);
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  int _length = 0;
  void _onText() {
    final n = controller.text.length;
    if (widget.maxLength != null && n != _length) setState(() => _length = n);
    _length = n;
  }

  /// Applies a toolbar transform to the text.
  void apply(TextEditingValue Function(TextEditingValue) edit) {
    if (!widget.enabled) return;
    if (_preview) setState(() => _preview = false);
    final next = edit(controller.value);
    final max = widget.maxLength;
    if (max != null && next.text.length > max) return;
    controller.value = next;
    widget.onChanged?.call(next.text);
    focusNode.requestFocus();
  }

  Future<void> insertLink() async {
    if (!widget.enabled) return;
    final before = controller.value;
    final url = await (widget.requestLink ?? _askLink)(context);
    if (!mounted || url == null || url.trim().isEmpty) {
      if (mounted) focusNode.requestFocus();
      return;
    }
    controller.value = before;
    apply((v) => MarkdownEdits.link(v, url.trim()));
  }

  Future<String?> _askLink(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return showTextInputDialog(
      context,
      title: l.markdownLinkTitle,
      label: l.markdownLinkUrl,
      confirmLabel: l.markdownLinkInsert,
      placeholder: 'https://',
      dialogKey: 'dialog.markdown.link',
      maxLength: 2000,
      validator: (v) => MarkdownInline.safeUrl(_withScheme(v)) == null
          ? l.markdownLinkInvalid
          : null,
    ).then((v) => v == null ? null : _withScheme(v));
  }

  /// `example.com` → `https://example.com`; `a@b.c` → `mailto:a@b.c`.
  static String _withScheme(String v) {
    final t = v.trim();
    if (t.isEmpty || RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*:').hasMatch(t)) {
      return t;
    }
    if (RegExp(r'^[^\s@/]+@[^\s@/]+\.[^\s@/]+$').hasMatch(t)) {
      return 'mailto:$t';
    }
    return 'https://$t';
  }

  void _setPreview(bool on) {
    if (on == _preview) return;
    setState(() => _preview = on);
    if (!on) focusNode.requestFocus();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    final mac = currentKeyPlatform.isMac;
    SingleActivator mod(LogicalKeyboardKey k) =>
        SingleActivator(k, meta: mac, control: !mac);
    return {
      mod(LogicalKeyboardKey.keyB): () => apply(MarkdownEdits.bold),
      mod(LogicalKeyboardKey.keyI): () => apply(MarkdownEdits.italic),
      mod(LogicalKeyboardKey.keyE): () => apply(MarkdownEdits.code),
      mod(LogicalKeyboardKey.keyK): insertLink,
      if (widget.onSubmit != null) ...{
        mod(LogicalKeyboardKey.enter): widget.onSubmit!,
        mod(LogicalKeyboardKey.numpadEnter): widget.onSubmit!,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final platform = currentKeyPlatform;
    String tip(String label, String? key) => key == null
        ? label
        : '$label (${KeyBinding(key, mod: true).format(platform)})';
    Widget tool(
      String id,
      IconData icon,
      String label,
      String? key,
      VoidCallback onPressed,
    ) => ShadTooltip(
      builder: (_) => Text(tip(label, key)),
      child: ShadIconButton.ghost(
        key: ValueKey<String>('${widget.fieldKey}.$id'),
        width: 28,
        height: 28,
        iconSize: 15,
        semanticLabel: label,
        icon: Icon(icon),
        onPressed: widget.enabled ? onPressed : null,
      ),
    );
    Widget tab(String id, String label, bool selected, VoidCallback onTap) =>
        Semantics(
          selected: selected,
          child: selected
              ? ShadButton.secondary(
                  key: ValueKey<String>('${widget.fieldKey}.$id'),
                  size: ShadButtonSize.sm,
                  height: 28,
                  onPressed: onTap,
                  child: Text(label),
                )
              : ShadButton.ghost(
                  key: ValueKey<String>('${widget.fieldKey}.$id'),
                  size: ShadButtonSize.sm,
                  height: 28,
                  onPressed: onTap,
                  child: Text(label),
                ),
        );
    const lineHeight = 20.0;
    final minHeight = widget.minLines * lineHeight + 16;
    final maxHeight = widget.maxLines * lineHeight + 16;
    final max = widget.maxLength;
    final length = controller.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            tab('write', l.markdownWrite, !_preview, () => _setPreview(false)),
            const SizedBox(width: 2),
            tab(
              'preview',
              l.markdownPreview,
              _preview,
              () => _setPreview(true),
            ),
            // The tools wrap (right-aligned) when the box is narrow (360 px).
            Expanded(
              child: _preview
                  ? const SizedBox.shrink()
                  : Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        tool('bold', LucideIcons.bold, l.markdownBold, 'B', () {
                          apply(MarkdownEdits.bold);
                        }),
                        tool(
                          'italic',
                          LucideIcons.italic,
                          l.markdownItalic,
                          'I',
                          () {
                            apply(MarkdownEdits.italic);
                          },
                        ),
                        tool('code', LucideIcons.code, l.markdownCode, 'E', () {
                          apply(MarkdownEdits.code);
                        }),
                        tool(
                          'link',
                          LucideIcons.link,
                          l.markdownLink,
                          'K',
                          insertLink,
                        ),
                        tool(
                          'bullets',
                          LucideIcons.list,
                          l.markdownBulletedList,
                          null,
                          () => apply(MarkdownEdits.bullets),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_preview)
          Container(
            key: ValueKey<String>('${widget.fieldKey}.rendered'),
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: cs.border),
              borderRadius: theme.radius,
            ),
            child: controller.text.trim().isEmpty
                ? Text(l.markdownPreviewEmpty, style: theme.textTheme.muted)
                : WonkyMarkdown(controller.text, profile: widget.profile),
          )
        else
          CallbackShortcuts(
            bindings: _shortcuts,
            child: ShadTextarea(
              key: ValueKey<String>(widget.fieldKey),
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              minHeight: minHeight,
              maxHeight: maxHeight,
              maxLength: max,
              placeholder: widget.hint == null ? null : Text(widget.hint!),
              onChanged: widget.onChanged,
            ),
          ),
        if (max != null && length >= max * 0.8) ...[
          const SizedBox(height: 2),
          Text(
            l.markdownLength(length, max),
            key: ValueKey<String>('${widget.fieldKey}.count'),
            textAlign: TextAlign.end,
            style: theme.textTheme.muted.copyWith(
              fontSize: 11,
              color: length >= max ? cs.destructive : null,
            ),
          ),
        ],
      ],
    );
  }
}
