import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../data/api.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../markdown/markdown_composer.dart';
import '../../markdown/wonky_markdown.dart';
import '../../shell/shell_services.dart';

/// What [lintTaskPrompt] found unusual in a line.
enum PromptLintKind {
  /// A shell command other than `flutter`, `dart`, `serverpod` or `git`.
  command,

  /// A URL outside the repository (`github.com/serverpod/wonky`) and
  /// `wonky.work`.
  url,

  /// "ignore", "secret", "token" or "credential" wording.
  wording,
}

/// One finding of [lintTaskPrompt]: [line] is 1-based, [match] the text
/// that triggered it.
class PromptLint {
  const PromptLint(this.kind, this.line, this.match);

  final PromptLintKind kind;
  final int line;
  final String match;

  @override
  String toString() => '${kind.name}@$line: $match';
}

const _allowedCommands = {'flutter', 'dart', 'serverpod', 'git', 'cd', 'fvm'};

/// Commands that are unusual in a task prompt even in inline code.
const _riskyCommands = {
  'curl', 'wget', 'rm', 'sudo', 'chmod', 'chown', 'bash', 'sh', 'zsh', //
  'python', 'python3', 'node', 'npm', 'npx', 'pip', 'pip3', 'brew', 'apt',
  'apt-get', 'docker', 'ssh', 'scp', 'eval', 'export', 'nc', 'netcat',
  'powershell', 'iex', 'kill', 'dd', 'mkfs', 'crontab', 'base64', 'env',
  'printenv', 'gh', 'source',
};

final _url = RegExp(r'''https?://[^\s<>)\]"'`]+''', caseSensitive: false);
final _words = RegExp(
  r'\b(ignore[sd]?|secrets?|tokens?|credentials?)\b',
  caseSensitive: false,
);
final _inlineCode = RegExp(r'`([^`\n]+)`');
final _shellLangs = {'', 'sh', 'bash', 'shell', 'console', 'zsh', 'terminal'};

bool _allowedUrl(String raw) {
  final u = Uri.tryParse(raw);
  if (u == null) return false;
  final host = u.host.toLowerCase();
  if (host == 'wonky.work' || host.endsWith('.wonky.work')) return true;
  if (host == 'localhost' || host == '127.0.0.1') return true;
  if (host == 'github.com' || host == 'www.github.com') {
    final p = u.path.toLowerCase();
    return p == '/serverpod/wonky' || p.startsWith('/serverpod/wonky/');
  }
  return false;
}

String? _commandOf(String line) {
  var t = line.trim();
  if (t.startsWith(r'$ ')) t = t.substring(2).trim();
  if (t.isEmpty || t.startsWith('#')) return null;
  final first = t.split(RegExp(r'\s+')).first;
  return RegExp(r'^[A-Za-z][\w.+-]*$').hasMatch(first) ? first : null;
}

/// The prompt lint of specs/16 §10.2: instructions that are unusual for a
/// task. A warning list for the admin, never a block.
List<PromptLint> lintTaskPrompt(String text) {
  final out = <PromptLint>[];
  final lines = text.split('\n');
  String? fence;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final n = i + 1;
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```')) {
      fence = fence == null ? trimmed.substring(3).trim().toLowerCase() : null;
      continue;
    }
    // Shell lines: inside a shell (or untyped) fence, or `$ cmd`.
    final inShell = fence != null && _shellLangs.contains(fence);
    if (inShell || trimmed.startsWith(r'$ ')) {
      final c = _commandOf(line);
      if (c != null && !_allowedCommands.contains(c.toLowerCase())) {
        out.add(PromptLint(PromptLintKind.command, n, line.trim()));
      }
    } else if (fence == null) {
      for (final m in _inlineCode.allMatches(line)) {
        final c = _commandOf(m[1]!);
        if (c != null && _riskyCommands.contains(c.toLowerCase())) {
          out.add(PromptLint(PromptLintKind.command, n, m[1]!.trim()));
        }
      }
    }
    if (RegExp(r'\|\s*(sudo\s+)?(ba|z)?sh\b').hasMatch(line) &&
        !out.any((x) => x.line == n && x.kind == PromptLintKind.command)) {
      out.add(PromptLint(PromptLintKind.command, n, line.trim()));
    }
    for (final m in _url.allMatches(line)) {
      final u = m[0]!.replaceFirst(RegExp(r'[.,;:]+$'), '');
      if (!_allowedUrl(u)) out.add(PromptLint(PromptLintKind.url, n, u));
    }
    for (final m in _words.allMatches(line)) {
      out.add(PromptLint(PromptLintKind.wording, n, m[0]!));
    }
  }
  return out;
}

/// The result of [showPromptEditor].
class PromptEditorResult {
  const PromptEditorResult(this.body, {this.publish = false});

  final String body;

  /// *Publish* was pressed (save, then publish the draft).
  final bool publish;
}

/// The prompt editor of specs/16 §10.2 (`dialog.board.prompt`): a
/// `MarkdownComposer` on the prompt body with a large preview, the lint,
/// *Regenerate* (with the changes against the text before) and, for
/// drafts, *Publish*. The composer keeps its own text undo.
Future<PromptEditorResult?> showPromptEditor(
  BuildContext context,
  ShellServices s, {
  required BoardTaskView task,
}) => showShadDialog<PromptEditorResult>(
  context: context,
  builder: (_) => PromptEditorDialog(services: s, task: task),
);

class PromptEditorDialog extends StatefulWidget {
  const PromptEditorDialog({
    super.key,
    required this.services,
    required this.task,
  });

  final ShellServices services;
  final BoardTaskView task;

  @override
  State<PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<PromptEditorDialog> {
  late final _body = TextEditingController(text: widget.task.promptBody);
  bool _regenerating = false;

  /// The text before the last *Regenerate* (shown as a diff).
  String? _beforeRegenerate;

  @override
  void initState() {
    super.initState();
    _body.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _body
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  Future<void> _regenerate() async {
    final s = widget.services;
    setState(() => _regenerating = true);
    try {
      final r = await s.dispatcher.invoke(
        'shell.board.admin.regeneratePrompt',
        args: {'taskNumber': widget.task.number},
      );
      final body = (r.data as Map?)?['promptBody'] as String?;
      if (r.isOk && body != null && mounted) {
        _beforeRegenerate = _body.text;
        _body.text = body;
      }
    } catch (e) {
      final l = s.l10n;
      if (l != null) {
        s.toasts.error(l.errorGeneric, description: errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  void _close({bool publish = false}) {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    Navigator.of(context).pop(PromptEditorResult(body, publish: publish));
  }

  String _lintText(WonkyAppLocalizations l, PromptLint x) => switch (x.kind) {
    PromptLintKind.command => l.boardLintCommand(x.line, x.match),
    PromptLintKind.url => l.boardLintUrl(x.line, x.match),
    PromptLintKind.wording => l.boardLintWording(x.line, x.match),
  };

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900;
    final lint = lintTaskPrompt(_body.text);
    final draft = widget.task.status == BoardTaskStatus.draft;
    final mono = theme.textTheme.small.copyWith(
      fontFamily: 'monospace',
      fontWeight: FontWeight.normal,
    );
    final editor = MarkdownComposer(
      fieldKey: 'dialog.board.prompt.body',
      controller: _body,
      profile: MarkdownProfile.post,
      minLines: 14,
      maxLines: 24,
      maxLength: 50000,
    );
    final preview = Container(
      key: const ValueKey<String>('dialog.board.prompt.preview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: WonkyMarkdown(_body.text, profile: MarkdownProfile.post),
      ),
    );
    final before = _beforeRegenerate;
    final diff = before == null ? null : _lineDiff(before, _body.text);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: ShadDialog(
        key: const ValueKey<String>('dialog.board.prompt'),
        constraints: BoxConstraints(
          maxWidth: (size.width - 48).clamp(320.0, 1100.0) + 48,
        ),
        title: Text(l.boardPromptEditorTitle(widget.task.number)),
        description: Text(l.boardPromptEditorHint),
        actions: [
          ShadButton.outline(
            key: const ValueKey<String>('dialog.board.prompt.regenerate'),
            enabled: !_regenerating,
            onPressed: _regenerate,
            leading: const Icon(LucideIcons.refreshCw, size: 16),
            child: Text(l.cmdBoardRegeneratePrompt),
          ),
          ShadButton.outline(
            key: const ValueKey<String>('dialog.board.prompt.cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.actionCancel),
          ),
          ShadButton.outline(
            key: const ValueKey<String>('dialog.board.prompt.save'),
            onPressed: _close,
            child: Text(l.actionSave),
          ),
          if (draft)
            ShadButton(
              key: const ValueKey<String>('dialog.board.prompt.publish'),
              onPressed: () => _close(publish: true),
              child: Text(l.boardActionSavePublish),
            ),
        ],
        child: SizedBox(
          width: (size.width - 48).clamp(320.0, 1100.0),
          height: (size.height - 260).clamp(320.0, 720.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          Expanded(child: SingleChildScrollView(child: editor)),
                          Expanded(child: preview),
                        ],
                      )
                    : SingleChildScrollView(child: editor),
              ),
              if (lint.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: Container(
                    key: const ValueKey<String>('dialog.board.prompt.lint'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.warning.withValues(alpha: 0.1),
                      border: Border.all(color: theme.colorScheme.warning),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Row(
                            spacing: 6,
                            children: [
                              Icon(
                                LucideIcons.triangleAlert,
                                size: 16,
                                color: theme.colorScheme.warning,
                              ),
                              Expanded(
                                child: Text(
                                  l.boardLintTitle(lint.length),
                                  style: theme.textTheme.small,
                                ),
                              ),
                            ],
                          ),
                          for (final x in lint)
                            Text(_lintText(l, x), style: mono),
                        ],
                      ),
                    ),
                  ),
                ),
              if (diff != null && diff.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    key: const ValueKey<String>('dialog.board.prompt.diff'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.boardPromptDiffTitle,
                          style: theme.textTheme.small,
                        ),
                        for (final (added, line) in diff)
                          Text(
                            '${added ? '+' : '−'} $line',
                            style: mono.copyWith(
                              color: added
                                  ? theme.colorScheme.success
                                  : theme.colorScheme.destructive,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lines only in [b] (added) and only in [a] (removed), in order.
List<(bool, String)> _lineDiff(String a, String b) {
  final al = a.split('\n');
  final bl = b.split('\n');
  final inA = {...al};
  final inB = {...bl};
  return [
    for (final x in al)
      if (!inB.contains(x) && x.trim().isNotEmpty) (false, x),
    for (final x in bl)
      if (!inA.contains(x) && x.trim().isNotEmpty) (true, x),
  ];
}
