import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/sheets_l10n.dart';

/// Color of a diagnostic severity.
Color problemColor(ShadColorScheme cs, DiagnosticSeverity s) => switch (s) {
  DiagnosticSeverity.error => cs.destructive,
  DiagnosticSeverity.warning => cs.warning,
  _ => cs.info,
};

/// Icon of a diagnostic severity.
IconData problemIcon(DiagnosticSeverity s) => switch (s) {
  DiagnosticSeverity.error => LucideIcons.circleX,
  DiagnosticSeverity.warning => LucideIcons.triangleAlert,
  _ => LucideIcons.info,
};

/// Error/warning markers in the code editor's gutter (09 §14.2); hovering
/// a marker shows the message. The editor updates the line positions
/// during layout, so the markers follow one frame later (post-frame
/// rebuild; a rebuild during layout is not allowed).
class ProblemGutter extends StatefulWidget {
  const ProblemGutter({
    super.key,
    required this.notifier,
    required this.problems,
  });

  final CodeIndicatorValueNotifier notifier;

  /// Diagnostics of the shown file.
  final List<ScriptDiagnostic> problems;

  @override
  State<ProblemGutter> createState() => _ProblemGutterState();
}

class _ProblemGutterState extends State<ProblemGutter> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_changed);
  }

  @override
  void didUpdateWidget(ProblemGutter old) {
    super.didUpdateWidget(old);
    if (old.notifier != widget.notifier) {
      old.notifier.removeListener(_changed);
      widget.notifier.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final byLine = <int, ScriptDiagnostic>{};
    for (final d in widget.problems) {
      final line = (d.line ?? 1) - 1;
      final prev = byLine[line];
      if (prev == null || d.severity.index < prev.severity.index) {
        byLine[line] = d;
      }
    }
    final paragraphs = widget.notifier.value?.paragraphs ?? const [];
    return SizedBox(
      width: 16,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final p in paragraphs)
            if (byLine[p.index] case final d?)
              Positioned(
                top: p.top + (p.preferredLineHeight - 12) / 2,
                left: 2,
                child: ShadTooltip(
                  builder: (_) => Text(d.message),
                  child: Icon(
                    problemIcon(d.severity),
                    key: ValueKey<String>('script.gutter.${p.index + 1}'),
                    size: 12,
                    color: problemColor(cs, d.severity),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// The Problems tab (09 §14.1): one row per diagnostic, click → navigate.
class ProblemsList extends StatelessWidget {
  const ProblemsList({
    super.key,
    required this.problems,
    required this.onOpen,
    this.onFix,
  });

  final List<ScriptDiagnostic> problems;
  final void Function(ScriptDiagnostic d) onOpen;

  /// *Fix with AI* (null when the assistant is unavailable).
  final void Function(int index)? onFix;

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    if (problems.isEmpty) {
      return Center(
        child: Text(
          l.scriptNoProblems,
          key: const ValueKey<String>('script.problems.empty'),
          style: theme.textTheme.muted,
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey<String>('script.problems'),
      itemCount: problems.length,
      itemBuilder: (context, i) {
        final d = problems[i];
        return GestureDetector(
          key: ValueKey<String>('script.problem.$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onOpen(d),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(
                  problemIcon(d.severity),
                  size: 14,
                  color: problemColor(cs, d.severity),
                ),
                const SizedBox(width: 8),
                Text(
                  '${d.file ?? ''}:${d.line ?? 1}:${d.column ?? 1}',
                  style: theme.textTheme.muted.copyWith(
                    fontFamily: WonkyTheme.monoFamily,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${d.message}  (${d.code})',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small,
                  ),
                ),
                if (onFix != null && d.severity == DiagnosticSeverity.error)
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => onFix!(i),
                    child: Text(l.scriptFixWithAi),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
