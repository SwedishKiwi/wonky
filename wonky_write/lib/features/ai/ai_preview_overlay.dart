import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';

import 'write_ai_controller.dart';

/// The inline AI layer over the document canvas (Write 09 §5.3–5.4): the
/// prompt box, the preview card anchored under the selection and the
/// continue-writing ghost text. Not part of the document.
class AiPreviewLayer extends StatefulWidget {
  const AiPreviewLayer({super.key, required this.ai});

  final WriteAiController ai;

  @override
  State<AiPreviewLayer> createState() => _AiPreviewLayerState();
}

class _AiPreviewLayerState extends State<AiPreviewLayer> {
  final _key = GlobalKey();

  WriteAiController get ai => widget.ai;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ai, ai.doc.editor.view]),
      builder: (context, _) {
        final p = ai.preview;
        return Stack(
          key: _key,
          children: [if (p != null) _positioned(context, p)],
        );
      },
    );
  }

  Widget _positioned(BuildContext context, AiPreview p) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    final anchorOffset = p.length == 0 ? p.start : p.start + p.length;
    final rect =
        ai.doc.globalRectForOffset(anchorOffset) ??
        ai.doc.globalRectForOffset(p.start);
    if (box == null || !box.hasSize || rect == null) {
      // First frame: lay out again once the box exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return const SizedBox.shrink();
    }
    final local = box.globalToLocal(rect.bottomLeft);
    final size = box.size;
    final width = (size.width - 24).clamp(260.0, 520.0);
    var left = local.dx - 12;
    if (left + width > size.width - 12) left = size.width - 12 - width;
    if (left < 12) left = 12;
    var top = local.dy + 8;
    if (top > size.height - 120) {
      top = (size.height - 320).clamp(8.0, size.height);
    }
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: p.kind == AiPreviewKind.continuation
          ? _GhostText(ai: ai, preview: p)
          : _PreviewCard(ai: ai, preview: p),
    );
  }
}

/// Continue writing: the continuation as muted ghost text.
class _GhostText extends StatefulWidget {
  const _GhostText({required this.ai, required this.preview});

  final WriteAiController ai;
  final AiPreview preview;

  @override
  State<_GhostText> createState() => _GhostTextState();
}

class _GhostTextState extends State<_GhostText> {
  final _focus = FocusNode(debugLabel: 'write.ai.ghost');

  @override
  void didUpdateWidget(_GhostText old) {
    super.didUpdateWidget(old);
    if (widget.preview.canApply && !_focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ai = widget.ai;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.tab || k == LogicalKeyboardKey.enter) {
      ai.insert();
      ai.doc.focusEditor();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      ai.discard();
      ai.doc.focusEditor();
      return KeyEventResult.handled;
    }
    final ch = e.character;
    if (ch != null && ch.isNotEmpty && ch.codeUnitAt(0) >= 0x20) {
      // Typing discards the suggestion and types.
      ai.discard();
      ai.doc.focusEditor();
      ai.doc.commands.insertText(ch, label: 'Typing');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final p = widget.preview;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Container(
        key: const ValueKey<String>('write.ai.ghost'),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: cs.popover.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (p.status == AiPreviewStatus.streaming && p.markdown.isEmpty)
              Row(
                children: [
                  const SizedBox(width: 12, height: 12, child: ShadSpinner()),
                  const SizedBox(width: 8),
                  Text('Writing…', style: theme.textTheme.muted),
                ],
              )
            else if (p.error != null)
              Text(p.error!, style: theme.textTheme.muted)
            else
              Text(
                p.markdown.trim(),
                style: theme.textTheme.p.copyWith(
                  color: cs.mutedForeground,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.canApply
                        ? 'Tab or Enter to accept · Esc to discard'
                        : 'Esc to discard',
                    style: theme.textTheme.muted.copyWith(fontSize: 11),
                  ),
                ),
                if (p.canApply)
                  ShadButton.ghost(
                    key: const ValueKey<String>('write.ai.ghost.accept'),
                    size: ShadButtonSize.sm,
                    onPressed: () {
                      widget.ai.insert();
                      widget.ai.doc.focusEditor();
                    },
                    child: const Text('Accept'),
                  ),
                ShadButton.ghost(
                  key: const ValueKey<String>('write.ai.ghost.discard'),
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    widget.ai.discard();
                    widget.ai.doc.focusEditor();
                  },
                  child: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The prompt box and the rewrite / generate preview.
class _PreviewCard extends StatefulWidget {
  const _PreviewCard({required this.ai, required this.preview});

  final WriteAiController ai;
  final AiPreview preview;

  @override
  State<_PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<_PreviewCard> {
  final _prompt = TextEditingController();
  final _promptFocus = FocusNode(debugLabel: 'write.ai.prompt');
  final _refine = TextEditingController();
  final _refineFocus = FocusNode(debugLabel: 'write.ai.refine');
  final _cardFocus = FocusNode(debugLabel: 'write.ai.preview');
  AiPreviewStatus? _lastStatus;

  WriteAiController get ai => widget.ai;
  AiPreview get p => widget.preview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (p.kind == AiPreviewKind.prompt) {
        _promptFocus.requestFocus();
      } else {
        _cardFocus.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(_PreviewCard old) {
    super.didUpdateWidget(old);
    if (p.status != _lastStatus) {
      _lastStatus = p.status;
      if (p.status == AiPreviewStatus.done && !_promptFocus.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_refineHasFocus) _cardFocus.requestFocus();
        });
      }
    }
    if (!identical(old.preview, widget.preview) &&
        widget.preview.kind != AiPreviewKind.prompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cardFocus.requestFocus();
      });
    }
  }

  bool get _refineHasFocus => _refineFocus.hasFocus;

  @override
  void dispose() {
    _prompt.dispose();
    _promptFocus.dispose();
    _refine.dispose();
    _refineFocus.dispose();
    _cardFocus.dispose();
    super.dispose();
  }

  void _close() {
    ai.discard();
    ai.doc.focusEditor();
  }

  void _primary() {
    if (!p.canApply) return;
    final ok = p.kind == AiPreviewKind.rewrite && !p.originalChanged
        ? ai.replace()
        : ai.insert(below: p.kind == AiPreviewKind.rewrite);
    if (ok) ai.doc.focusEditor();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (node == _cardFocus &&
        (e.logicalKey == LogicalKeyboardKey.enter ||
            e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _primary();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Focus(
      focusNode: _cardFocus,
      onKeyEvent: _onKey,
      child: Container(
        key: const ValueKey<String>('write.ai.preview'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.popover,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x29000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: p.kind == AiPreviewKind.prompt
            ? _promptBox(context)
            : _result(context),
      ),
    );
  }

  Widget _promptBox(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.sparkles,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(p.title, style: theme.textTheme.small)),
          ],
        ),
        Focus(
          onKeyEvent: _onKey,
          child: ShadInput(
            key: const ValueKey<String>('write.ai.prompt.input'),
            controller: _prompt,
            focusNode: _promptFocus,
            placeholder: Text(
              p.length == 0
                  ? 'Tell AI what to write…'
                  : 'Tell AI how to change the selection…',
            ),
            onSubmitted: (v) => unawaited(ai.submitPrompt(v)),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (p.length == 0)
              ShadButton.outline(
                key: const ValueKey<String>('write.ai.prompt.continue'),
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.penLine, size: 13),
                onPressed: () {
                  ai.discard();
                  unawaited(ai.continueWriting());
                },
                child: const Text('Continue writing'),
              ),
            ShadButton(
              key: const ValueKey<String>('write.ai.prompt.submit'),
              size: ShadButtonSize.sm,
              onPressed: () => unawaited(ai.submitPrompt(_prompt.text)),
              child: const Text('Generate'),
            ),
            ShadButton.ghost(
              key: const ValueKey<String>('write.ai.prompt.cancel'),
              size: ShadButtonSize.sm,
              onPressed: _close,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final streaming = p.status == AiPreviewStatus.streaming;
    final rewrite = p.kind == AiPreviewKind.rewrite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Row(
          children: [
            Icon(LucideIcons.sparkles, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (streaming)
              const SizedBox(width: 12, height: 12, child: ShadSpinner()),
            if (rewrite && p.canApply)
              ShadButton.ghost(
                key: const ValueKey<String>('write.ai.preview.diff'),
                size: ShadButtonSize.sm,
                onPressed: ai.toggleDiff,
                child: Text(p.showDiff ? 'Hide changes' : 'Show changes'),
              ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: p.error != null
                ? Text(
                    p.error!,
                    key: const ValueKey<String>('write.ai.preview.error'),
                    style: theme.textTheme.muted,
                  )
                : p.showDiff
                ? _WordDiff(before: p.originalText, after: p.markdown)
                : p.markdown.trim().isEmpty && streaming
                ? Text('Writing…', style: theme.textTheme.muted)
                : AssistantMarkdown(p.markdown),
          ),
        ),
        if (p.originalChanged)
          Text(
            'The original text changed.',
            key: const ValueKey<String>('write.ai.preview.changed'),
            style: theme.textTheme.muted.copyWith(color: cs.destructive),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (rewrite && !p.originalChanged)
              ShadButton(
                key: const ValueKey<String>('write.ai.preview.replace'),
                size: ShadButtonSize.sm,
                enabled: p.canApply && ai.canWrite,
                onPressed: _primary,
                child: Text(ai.suggestMode ? 'Suggest' : 'Replace'),
              ),
            if (rewrite)
              ShadButton.outline(
                key: const ValueKey<String>('write.ai.preview.insertBelow'),
                size: ShadButtonSize.sm,
                enabled: p.canApply && ai.canWrite,
                onPressed: () {
                  if (ai.insert(below: true)) ai.doc.focusEditor();
                },
                child: const Text('Insert below'),
              )
            else
              ShadButton(
                key: const ValueKey<String>('write.ai.preview.insert'),
                size: ShadButtonSize.sm,
                enabled: p.canApply && ai.canWrite,
                onPressed: _primary,
                child: const Text('Insert'),
              ),
            if (!p.originalChanged)
              ShadButton.ghost(
                key: const ValueKey<String>('write.ai.preview.retry'),
                size: ShadButtonSize.sm,
                enabled: !streaming,
                leading: const Icon(LucideIcons.refreshCw, size: 13),
                onPressed: () => unawaited(ai.retry()),
                child: const Text('Try again'),
              ),
            ShadButton.ghost(
              key: const ValueKey<String>('write.ai.preview.copy'),
              size: ShadButtonSize.sm,
              enabled: p.markdown.isNotEmpty,
              onPressed: () => unawaited(ai.copy()),
              child: const Text('Copy'),
            ),
            ShadButton.ghost(
              key: const ValueKey<String>('write.ai.preview.discard'),
              size: ShadButtonSize.sm,
              onPressed: _close,
              child: const Text('Discard'),
            ),
          ],
        ),
        if (p.canApply && !p.originalChanged)
          ShadInput(
            key: const ValueKey<String>('write.ai.preview.refine'),
            controller: _refine,
            focusNode: _refineFocus,
            placeholder: const Text('Refine: “Make it more formal”'),
            onSubmitted: (v) {
              final t = v.trim();
              if (t.isEmpty) return;
              _refine.clear();
              unawaited(ai.refine(t));
            },
          ),
        if (p.canApply)
          Text(
            'Enter to ${rewrite && !p.originalChanged ? 'replace' : 'insert'} · Esc to discard',
            style: theme.textTheme.muted.copyWith(fontSize: 11),
          ),
      ],
    );
  }
}

/// A word diff between the original text and the result.
class _WordDiff extends StatelessWidget {
  const _WordDiff({required this.before, required this.after});

  final String before;
  final String after;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final ops = wordDiff(before, _plain(after));
    return Text.rich(
      TextSpan(
        children: [
          for (final (kind, text) in ops)
            TextSpan(
              text: text,
              style: switch (kind) {
                -1 => TextStyle(
                  color: cs.destructive,
                  decoration: TextDecoration.lineThrough,
                ),
                1 => TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                _ => null,
              },
            ),
        ],
      ),
      key: const ValueKey<String>('write.ai.preview.diffText'),
      style: theme.textTheme.small,
    );
  }

  static String _plain(String md) => md
      .replaceAll(RegExp(r'(\*\*|__|~~|`)'), '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
}

/// Word-level diff: (kind, text) with -1 deleted, 0 same, 1 inserted.
List<(int, String)> wordDiff(String a, String b) {
  final x = RegExp(r'\s+|[^\s]+').allMatches(a).map((m) => m[0]!).toList();
  final y = RegExp(r'\s+|[^\s]+').allMatches(b).map((m) => m[0]!).toList();
  if (x.length * y.length > 400000) {
    return [(-1, a), (1, b)];
  }
  final n = x.length;
  final m = y.length;
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = x[i] == y[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final out = <(int, String)>[];
  void add(int k, String t) {
    if (out.isNotEmpty && out.last.$1 == k) {
      out[out.length - 1] = (k, out.last.$2 + t);
    } else {
      out.add((k, t));
    }
  }

  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (x[i] == y[j]) {
      add(0, x[i]);
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      add(-1, x[i++]);
    } else {
      add(1, y[j++]);
    }
  }
  while (i < n) {
    add(-1, x[i++]);
  }
  while (j < m) {
    add(1, y[j++]);
  }
  return out;
}
