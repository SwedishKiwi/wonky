import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart'
    show ScriptExecution, ScriptExecutionStatus;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'script_backend.dart' show parseLogLines;
import 'script_service.dart';
import 'script_widgets.dart';

/// Side panel id of the executions log (09 §13.3).
const scriptExecutionsPanelId = 'sheets.panel.scriptExecutions';

/// The executions side panel (*Extensions › Executions*).
SidePanelSpec scriptExecutionsPanelSpec(
  BuildContext context,
  SheetEditorController editor,
) => SidePanelSpec(
  id: scriptExecutionsPanelId,
  title: sheetsL10n(context).cmdScriptOpenExecutions,
  icon: LucideIcons.listChecks,
  showAsTab: false,
  builder: (_) => ScriptExecutionsView(editor: editor, showTitle: true),
);

/// Label of an execution kind.
String executionKindLabel(SheetsLocalizations l, String kind) => switch (kind) {
  'editor' => l.execKindEditor,
  'menu' => l.execKindMenu,
  'macro' => l.execKindMacro,
  'customFunction' => l.execKindCustomFunction,
  'onOpen' || 'onEdit' || 'onSelectionChange' || 'onChange' => kind,
  'timeDriven' => l.execKindTimeDriven,
  'installableOnEdit' ||
  'installableOnChange' ||
  'installableOnOpen' => l.execKindInstallable,
  'mcp' => 'MCP',
  'ai' => 'AI',
  _ => kind,
};

/// Label of an execution status.
String executionStatusLabel(SheetsLocalizations l, String status) =>
    switch (status) {
      'completed' => l.execStatusCompleted,
      'failed' => l.execStatusFailed,
      'timedOut' => l.execStatusTimedOut,
      'cancelled' => l.execStatusCancelled,
      'quotaExceeded' => l.execStatusQuota,
      'skipped' => l.execStatusSkipped,
      _ => status,
    };

/// The executions table (09 §13.3): function, type, started, duration,
/// status; a status filter; a row expands to logs, the error card, stats,
/// *Revert changes* (server runs) and *Open in editor*. Used by the side
/// panel and the script editor's bottom tab.
class ScriptExecutionsView extends StatefulWidget {
  const ScriptExecutionsView({
    super.key,
    required this.editor,
    this.showTitle = false,
    this.onOpenFrame,
  });

  final SheetEditorController editor;
  final bool showTitle;

  /// Opens a stack frame in the script editor (file, line).
  final void Function(String file, int line)? onOpenFrame;

  @override
  State<ScriptExecutionsView> createState() => _ScriptExecutionsViewState();
}

class _ScriptExecutionsViewState extends State<ScriptExecutionsView> {
  late final ScriptService _svc = ScriptService.of(widget.editor);
  final _scroll = ScrollController();
  List<ScriptExecution> _rows = const [];
  bool _loading = false;
  String _status = 'all';
  String? _expanded;
  int _seenRecent = -1;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onService);
    unawaited(_load());
  }

  @override
  void dispose() {
    _svc.removeListener(_onService);
    _scroll.dispose();
    super.dispose();
  }

  void _onService() {
    // Live updates: reload when this window finished a run.
    if (_svc.recent.length != _seenRecent) unawaited(_load());
  }

  Future<void> _load() async {
    _seenRecent = _svc.recent.length;
    setState(() => _loading = true);
    final rows = await _svc.loadExecutions(
      status: _status == 'all'
          ? null
          : ScriptExecutionStatus.values.byName(_status),
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return Column(
      key: const ValueKey<String>('sheets.panel.scriptExecutions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, widget.showTitle ? 12 : 6, 8, 6),
          child: Row(
            children: [
              if (widget.showTitle)
                Expanded(
                  child: Text(
                    l.cmdScriptOpenExecutions,
                    style: theme.textTheme.large,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              SizedBox(
                width: 150,
                child: ShadSelect<String>(
                  key: const ValueKey<String>('executions.status'),
                  initialValue: _status,
                  minWidth: 140,
                  options: [
                    ShadOption(value: 'all', child: Text(l.execStatusAll)),
                    for (final s in ScriptExecutionStatus.values)
                      if (s != ScriptExecutionStatus.queued &&
                          s != ScriptExecutionStatus.running)
                        ShadOption(
                          value: s.name,
                          child: Text(executionStatusLabel(l, s.name)),
                        ),
                  ],
                  selectedOptionBuilder: (context, v) => Text(
                    v == 'all' ? l.execStatusAll : executionStatusLabel(l, v),
                  ),
                  onChanged: (v) {
                    if (v == null) return;
                    _status = v;
                    unawaited(_load());
                  },
                ),
              ),
              scriptIconButton(
                key: const ValueKey<String>('executions.refresh'),
                icon: LucideIcons.refreshCw,
                tooltip: l.execRefresh,
                onPressed: _loading ? null : () => unawaited(_load()),
              ),
            ],
          ),
        ),
        Container(height: 1, color: theme.colorScheme.border),
        Expanded(
          child: _rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _loading ? l.execLoading : l.execEmpty,
                      key: const ValueKey<String>('executions.empty'),
                      style: theme.textTheme.muted,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : WonkyScrollArea(
                  controller: _scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final r in _rows) _row(context, r)],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, ScriptExecution r) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final id = r.uuid.uuid;
    final open = _expanded == id;
    final status = r.status.name;
    final badge = switch (r.status) {
      ScriptExecutionStatus.completed => ShadBadge.secondary(
        child: Text(executionStatusLabel(l, status)),
      ),
      ScriptExecutionStatus.skipped || ScriptExecutionStatus.cancelled =>
        ShadBadge.outline(child: Text(executionStatusLabel(l, status))),
      _ => ShadBadge.destructive(child: Text(executionStatusLabel(l, status))),
    };
    final started = DateFormat.MMMd().add_Hms().format(r.startedAt.toLocal());
    return Column(
      key: ValueKey<String>('executions.row.$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = open ? null : id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 14,
                  color: cs.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.functionName.isEmpty ? '—' : r.functionName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          fontFamily: WonkyTheme.monoFamily,
                        ),
                      ),
                      Text(
                        '${executionKindLabel(l, r.kind.name)} · $started · '
                        '${l.execDuration(r.durationMs)}'
                        '${r.callCount > 1 ? ' · ×${r.callCount}' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                badge,
              ],
            ),
          ),
        ),
        if (open) _detail(context, r),
        Container(height: 1, color: cs.border),
      ],
    );
  }

  Widget _detail(BuildContext context, ScriptExecution r) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final logs = parseLogLines(r.logs);
    final frames = <ScriptStackFrame>[];
    final raw = r.errorStackJson;
    if (raw != null) {
      try {
        for (final f in jsonDecode(raw) as List) {
          frames.add(ScriptStackFrame.fromJson((f as Map).cast()));
        }
      } on Object {
        // Unreadable stack: the message is enough.
      }
    }
    final top = frames.where((f) => f.file != null && f.line != null);
    final changeId = r.changeId?.uuid;
    return Padding(
      key: ValueKey<String>('executions.detail.${r.uuid.uuid}'),
      padding: const EdgeInsets.fromLTRB(32, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.destructive.withValues(alpha: 0.08),
                border: Border.all(
                  color: cs.destructive.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.errorMessage!,
                    style: theme.textTheme.small.copyWith(
                      color: cs.destructive,
                    ),
                  ),
                  for (final f in frames)
                    Text(
                      '  at $f',
                      style: theme.textTheme.muted.copyWith(
                        fontFamily: WonkyTheme.monoFamily,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          Text(
            l.execStats(r.cellsRead, r.cellsWritten, r.fetchCalls),
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (logs.isNotEmpty)
            ScriptLogList(lines: logs, maxHeight: 160)
          else
            Text(l.execNoLogs, style: theme.textTheme.muted),
          if (changeId != null ||
              (top.isNotEmpty && widget.onOpenFrame != null))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                children: [
                  if (changeId != null)
                    ShadButton.outline(
                      key: const ValueKey<String>('executions.revert'),
                      size: ShadButtonSize.sm,
                      onPressed: widget.editor.canEdit
                          ? () => unawaited(
                              widget.editor.invokeCommand(
                                'sheets.script.revertExecution',
                                {
                                  'changeId': changeId,
                                  'functionName': r.functionName,
                                },
                              ),
                            )
                          : null,
                      child: Text(l.execRevert),
                    ),
                  if (top.isNotEmpty && widget.onOpenFrame != null)
                    ShadButton.outline(
                      key: const ValueKey<String>('executions.openInEditor'),
                      size: ShadButtonSize.sm,
                      onPressed: () =>
                          widget.onOpenFrame!(top.first.file!, top.first.line!),
                      child: Text(l.execOpenInEditor),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Log lines in monospace with level colors (09 §13.3).
class ScriptLogList extends StatelessWidget {
  const ScriptLogList({
    super.key,
    required this.lines,
    this.functions,
    this.maxHeight,
  });

  final List<LogEntry> lines;

  /// Function name per line (Log tab of the editor).
  final List<String>? functions;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    Color color(ScriptLogLevel level) => switch (level) {
      ScriptLogLevel.error => cs.destructive,
      ScriptLogLevel.warn => cs.warning,
      ScriptLogLevel.system => cs.mutedForeground,
      ScriptLogLevel.info => cs.foreground,
    };
    final children = [
      for (var i = 0; i < lines.length; i++)
        Text(
          '${DateFormat.Hms().format(lines[i].at.toLocal())}  '
          '${functions == null ? '' : '${functions![i]}  '}'
          '${lines[i].message}',
          style: TextStyle(
            fontFamily: WonkyTheme.monoFamily,
            fontSize: 12,
            height: 1.4,
            color: color(lines[i].level),
          ),
        ),
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    final h = maxHeight;
    return h == null
        ? body
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h),
            child: SingleChildScrollView(child: body),
          );
  }
}
