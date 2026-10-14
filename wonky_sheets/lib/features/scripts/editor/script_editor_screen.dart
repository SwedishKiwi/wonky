import 'dart:async';

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_sheets_core/model.dart' show GenericRecord;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../commands/script_commands.dart' show scriptEditorScope;
import '../../../commands/sheets_command.dart' show editorOfServices;
import '../../../l10n/sheets_l10n.dart';
import '../../model/workbook_session.dart';
import '../../sheet_editor/sheet_editor_controller.dart';
import '../executions_panel.dart';
import '../script_project.dart';
import '../script_service.dart';
import '../script_widgets.dart';
import 'problems.dart';
import 'script_code_theme.dart';
import 'script_find_panel.dart';

/// Below this width the file rail collapses into a dropdown (09 §14.1).
const _narrowWidth = 900.0;

/// The script editor `/s/:uuid/script` (09 §14): a child route of the
/// spreadsheet editor (the spreadsheet stays open underneath and shares
/// its sync session, so it works offline). Title row with the build
/// status, toolbar (save, run picker, run on server, triggers, settings,
/// find), file rail with functions, tabs of open files on `re_editor`, and
/// the bottom panel (Problems, Log, Executions).
class ScriptEditorScreen extends StatefulWidget {
  const ScriptEditorScreen({
    super.key,
    required this.services,
    required this.itemUuid,
    this.initialFile,
    this.initialLine,
  });

  final ShellServices services;
  final String itemUuid;

  /// `?file=utils.dart&line=12`.
  final String? initialFile;
  final int? initialLine;

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

enum _BottomTab { problems, log, executions }

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  SheetEditorController? _ed;
  ScriptService? _svc;
  final Map<String, CodeLineEditingController> _ctl = {};
  final Map<String, CodeFindController> _find = {};
  final List<String> _open = [];
  String? _active;
  _BottomTab _tab = _BottomTab.problems;
  bool _bottomOpen = true;
  double _bottomHeight = 200;
  final Map<String, List<ScriptDiagnostic>> _live = {};
  final Set<String> _staleRemote = {};
  Timer? _analyze;
  Timer? _retry;
  final _scope = FocusNode(debugLabel: 'scriptEditor');

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.activeDocument.addListener(_attach);
    _attach();
  }

  @override
  void dispose() {
    s.activeDocument.removeListener(_attach);
    _svc?.removeListener(_onService);
    _analyze?.cancel();
    _retry?.cancel();
    for (final c in _ctl.values) {
      c.dispose();
    }
    for (final f in _find.values) {
      f.dispose();
    }
    _scope.dispose();
    super.dispose();
  }

  void _attach() {
    if (_ed != null) return;
    final ed = editorOfServices(s);
    if (ed == null ||
        ed.session.itemUuid.uuid != widget.itemUuid ||
        ed.session.loadState.value is! WorkbookReady) {
      _retry?.cancel();
      _retry = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _attach();
      });
      return;
    }
    final svc = ScriptService.of(ed);
    svc.addListener(_onService);
    setState(() {
      _ed = ed;
      _svc = svc;
    });
    final files = svc.files;
    final initial =
        (widget.initialFile == null
            ? null
            : ScriptProjectRows.fileNamed(ed.model, widget.initialFile!)) ??
        (svc.activeFileId == null
            ? null
            : ScriptProjectRows.file(ed.model, svc.activeFileId!)) ??
        files.firstOrNull;
    if (initial != null) _openFile(initial.id, line: widget.initialLine);
  }

  // ------------------------------------------------------------- files

  CodeLineEditingController _controllerFor(String id) {
    final existing = _ctl[id];
    if (existing != null) return existing;
    final svc = _svc!;
    final row = ScriptProjectRows.file(_ed!.model, id);
    final saved = row == null ? '' : ScriptProjectRows.sourceOf(row);
    final c = CodeLineEditingController.fromText(svc.drafts[id] ?? saved);
    if (!svc.drafts.containsKey(id)) svc.markLoaded(id);
    var last = c.text;
    c.addListener(() {
      final t = c.text;
      if (t == last) return;
      last = t;
      svc.setDraft(id, t);
      _scheduleAnalyze(id);
    });
    _find[id] = CodeFindController(c);
    return _ctl[id] = c;
  }

  void _openFile(String id, {int? line}) {
    final c = _controllerFor(id);
    setState(() {
      if (!_open.contains(id)) _open.add(id);
      _active = id;
    });
    _svc?.activeFileId = id;
    if (line != null && line > 0) {
      final index = (line - 1).clamp(0, c.codeLines.length - 1);
      c.selection = CodeLineSelection.collapsed(index: index, offset: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.makeCursorCenterIfInvisible();
      });
    }
  }

  void _openByName(String name, int line) {
    final row = ScriptProjectRows.fileNamed(_ed!.model, name);
    if (row != null) _openFile(row.id, line: line);
  }

  void _close(String id) {
    setState(() {
      _open.remove(id);
      if (_active == id) _active = _open.lastOrNull;
    });
    _svc?.activeFileId = _active;
  }

  void _onService() {
    final ed = _ed;
    final svc = _svc;
    if (ed == null || svc == null || !mounted) return;
    final l = sheetsL10n(context);
    for (final id in List.of(_open)) {
      final row = ScriptProjectRows.file(ed.model, id);
      if (row == null) {
        _open.remove(id);
        _ctl.remove(id)?.dispose();
        _find.remove(id)?.dispose();
        if (_active == id) _active = _open.lastOrNull;
        continue;
      }
      final hash = ScriptProjectRows.hashOf(row);
      final base = svc.baseHashes[id];
      if (base == null || base == hash) continue;
      if (svc.isDirty(id)) {
        _staleRemote.add(id);
      } else {
        // Saved elsewhere and not dirty here: reload silently (09 §14.3).
        _ctl[id]?.text = ScriptProjectRows.sourceOf(row);
        svc.drafts.remove(id);
        svc.markLoaded(id);
        if ('${row.columns['updatedBy']}' != ed.session.userId) {
          s.toasts.show(l.scriptFileUpdated(ScriptProjectRows.nameOf(row)));
        }
      }
    }
    if (_active == null && svc.files.isNotEmpty && _open.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _active == null && svc.files.isNotEmpty) {
          _openFile(svc.files.first.id);
        }
      });
    }
    setState(() {});
  }

  void _reloadRemote(String id) {
    final row = ScriptProjectRows.file(_ed!.model, id);
    if (row == null) return;
    _svc!.drafts.remove(id);
    _ctl[id]?.text = ScriptProjectRows.sourceOf(row);
    _svc!.drafts.remove(id);
    _svc!.markLoaded(id);
    setState(() => _staleRemote.remove(id));
  }

  void _scheduleAnalyze(String id) {
    _analyze?.cancel();
    _analyze = Timer(const Duration(milliseconds: 800), () async {
      final svc = _svc;
      final b = svc?.backend;
      final row = svc == null ? null : ScriptProjectRows.file(_ed!.model, id);
      if (b == null || row == null || !s.connectivity.online) return;
      final name = ScriptProjectRows.nameOf(row);
      try {
        final diags = await b.analyze(svc!.itemUuid, name, _ctl[id]!.text);
        if (!mounted) return;
        setState(
          () => _live[id] = [
            for (final d in diags)
              if (d.file == null || d.file == name) d,
          ],
        );
      } on Object {
        // Offline or the server is busy: the build diagnostics remain.
      }
    });
  }

  /// Problems: live diagnostics of edited files, the build's for the rest.
  List<ScriptDiagnostic> _problems() {
    final ed = _ed;
    final svc = _svc;
    if (ed == null || svc == null) return const [];
    final out = <ScriptDiagnostic>[];
    final build = svc.buildDiagnostics;
    final names = <String>{};
    for (final f in svc.files) {
      final name = ScriptProjectRows.nameOf(f);
      names.add(name);
      final live = svc.isDirty(f.id) ? _live[f.id] : null;
      if (live != null) {
        out.addAll([
          for (final d in live)
            d.file == null
                ? ScriptDiagnostic(
                    severity: d.severity,
                    code: d.code,
                    message: d.message,
                    file: name,
                    line: d.line,
                    column: d.column,
                  )
                : d,
        ]);
      } else {
        out.addAll(build.where((d) => d.file == name));
      }
    }
    out.addAll(build.where((d) => d.file == null || !names.contains(d.file)));
    out.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return out;
  }

  // ------------------------------------------------------------ actions

  Future<void> _invoke(String id, [Map<String, Object?> args = const {}]) =>
      _ed!.invokeCommand(id, args, InvocationSource.ui);

  Future<void> _newFile() async {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final ed = _ed!;
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: l.cmdScriptNewFile,
        dialogKey: 'dialog.scriptNewFile',
        fields: [
          TextFieldSpec(
            id: 'name',
            label: l.scriptFileName,
            initial: 'utils.dart',
            validator: (v) =>
                switch (ScriptProjectWriter(ed).checkName(v.trim())) {
                  null => null,
                  'duplicate' => l.scriptFileNameDuplicate,
                  'limit' => l.scriptFileLimit,
                  _ => l.scriptFileNameInvalid,
                },
          ),
        ],
        buttons: [
          DialogButtonSpec(id: 'cancel', label: la.actionCancel),
          DialogButtonSpec(id: 'ok', label: l.scriptCreate, primary: true),
        ],
      ),
    );
    if (r?.buttonId != 'ok') return;
    final name = r!.text('name').trim();
    await _invoke('sheets.script.newFile', {'name': name});
    final row = ScriptProjectRows.fileNamed(ed.model, name);
    if (row != null) _openFile(row.id);
  }

  Future<void> _renameFile(GenericRecord f) async {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final ed = _ed!;
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: l.cmdScriptRenameFile,
        dialogKey: 'dialog.scriptRenameFile',
        fields: [
          TextFieldSpec(
            id: 'name',
            label: l.scriptFileName,
            initial: ScriptProjectRows.nameOf(f),
            validator: (v) => switch (ScriptProjectWriter(
              ed,
            ).checkName(v.trim(), exceptId: f.id)) {
              null => null,
              'duplicate' => l.scriptFileNameDuplicate,
              _ => l.scriptFileNameInvalid,
            },
          ),
        ],
        buttons: [
          DialogButtonSpec(id: 'cancel', label: la.actionCancel),
          DialogButtonSpec(id: 'ok', label: l.dialogApply, primary: true),
        ],
      ),
    );
    if (r?.buttonId != 'ok') return;
    await _invoke('sheets.script.renameFile', {
      'fileId': f.id,
      'name': r!.text('name').trim(),
    });
  }

  void _openFind() {
    final id = _active;
    if (id == null) return;
    _find[id]?.findMode();
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final ed = _ed;
    final svc = _svc;
    return Material(
      type: MaterialType.transparency,
      child: KeymapScope(
        scope: scriptEditorScope,
        keymap: s.keymap,
        focusNode: _scope,
        autofocus: true,
        child: ColoredBox(
          key: const ValueKey<String>('sheets.scriptEditor'),
          color: cs.background,
          child: ed == null || svc == null
              ? const Center(child: SizedBox.square(dimension: 24))
              : ListenableBuilder(
                  listenable: Listenable.merge([svc, ed]),
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, box) {
                      final narrow = box.maxWidth < _narrowWidth;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _titleRow(context, ed, svc),
                          const ShadSeparator.horizontal(
                            margin: EdgeInsets.zero,
                          ),
                          _toolbar(context, ed, svc, narrow: narrow),
                          const ShadSeparator.horizontal(
                            margin: EdgeInsets.zero,
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!narrow) ...[
                                  SizedBox(
                                    width: 220,
                                    child: _rail(context, ed, svc),
                                  ),
                                  Container(width: 1, color: cs.border),
                                ],
                                Expanded(child: _editorArea(context, ed, svc)),
                              ],
                            ),
                          ),
                          _bottomPanel(context, ed, svc, box.maxHeight),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  String _status(SheetsLocalizations l, ScriptService svc) {
    if (svc.drafts.isNotEmpty) return l.scriptStatusUnsaved;
    final built = svc.builtAt;
    final time = built == null ? '' : DateFormat.Hm().format(built.toLocal());
    return switch (svc.phase) {
      ScriptBuildPhase.building => l.scriptStatusBuilding,
      ScriptBuildPhase.offline => l.scriptStatusOffline,
      ScriptBuildPhase.failed => l.scriptStatusFailed(
        svc.buildDiagnostics
            .where((d) => d.severity == DiagnosticSeverity.error)
            .length,
      ),
      ScriptBuildPhase.ok => l.scriptStatusBuilt(time),
      ScriptBuildPhase.none =>
        svc.program == null ? l.scriptStatusNotBuilt : l.scriptStatusSaved,
    };
  }

  Widget _titleRow(
    BuildContext context,
    SheetEditorController ed,
    ScriptService svc,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final project = svc.project;
    final failed = svc.phase == ScriptBuildPhase.failed;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            scriptIconButton(
              key: const ValueKey<String>('script.back'),
              icon: LucideIcons.arrowLeft,
              tooltip: l.scriptBackToSpreadsheet,
              size: 32,
              onPressed: () => _invoke('sheets.script.closeEditor'),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.code, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l.scriptEditorTitle(ed.model.spreadsheet.title),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.large,
              ),
            ),
            if (project != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ScriptProjectRows.nameOf(project),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted,
                ),
              ),
            ],
            const Spacer(),
            if (!ed.canEdit)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShadBadge.outline(child: Text(l.scriptReadOnly)),
              ),
            Icon(
              failed
                  ? LucideIcons.circleX
                  : svc.phase == ScriptBuildPhase.building
                  ? LucideIcons.loader
                  : LucideIcons.circleCheck,
              size: 14,
              color: failed ? cs.destructive : cs.mutedForeground,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _status(l, svc),
                key: const ValueKey<String>('script.status'),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(
    BuildContext context,
    SheetEditorController ed,
    ScriptService svc, {
    required bool narrow,
  }) {
    final l = sheetsL10n(context);
    final fns = [for (final f in svc.exports.runnableFunctions) f.name];
    final selected = fns.contains(svc.selectedFunction)
        ? svc.selectedFunction!
        : fns.firstOrNull;
    final running = svc.running.isNotEmpty;
    final files = svc.files;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (narrow && files.isNotEmpty) ...[
              SizedBox(
                width: 160,
                child: ShadSelect<String>(
                  key: const ValueKey<String>('script.fileSelect'),
                  initialValue: _active,
                  minWidth: 160,
                  options: [
                    for (final f in files)
                      ShadOption(
                        value: f.id,
                        child: Text(ScriptProjectRows.nameOf(f)),
                      ),
                  ],
                  selectedOptionBuilder: (context, v) => Text(
                    ScriptProjectRows.nameOf(
                      ScriptProjectRows.file(ed.model, v) ?? files.first,
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) _openFile(v);
                  },
                ),
              ),
              const SizedBox(width: 6),
            ],
            ShadButton.outline(
              key: const ValueKey<String>('script.save'),
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.save, size: 15),
              enabled: ed.canEdit && svc.drafts.isNotEmpty,
              onPressed: () => _invoke('sheets.script.saveAll'),
              child: Text(l.scriptSave),
            ),
            const SizedBox(width: 6),
            if (running)
              ShadButton.destructive(
                key: const ValueKey<String>('script.stop'),
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.square, size: 15),
                onPressed: () => _invoke('sheets.script.stop'),
                child: Text(l.cmdScriptStop),
              )
            else
              ShadButton(
                key: const ValueKey<String>('script.run'),
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.play, size: 15),
                enabled: ed.canEdit && selected != null,
                onPressed: () {
                  setState(() {
                    _tab = _BottomTab.log;
                    _bottomOpen = true;
                  });
                  _invoke('sheets.script.run', {'functionName': selected});
                },
                child: Text(l.cmdScriptRun),
              ),
            const SizedBox(width: 4),
            SizedBox(
              width: 180,
              child: ShadSelect<String>(
                key: ValueKey<String>('script.runPicker.${fns.join(',')}'),
                initialValue: selected,
                minWidth: 180,
                enabled: fns.isNotEmpty,
                placeholder: Text(l.scriptNoRunnableFunctions),
                options: [
                  for (final f in fns)
                    ShadOption(
                      value: f,
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontFamily: WonkyTheme.monoFamily,
                        ),
                      ),
                    ),
                ],
                selectedOptionBuilder: (context, v) => Text(
                  v,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: WonkyTheme.monoFamily),
                ),
                onChanged: (v) => svc.selectedFunction = v,
              ),
            ),
            const SizedBox(width: 4),
            scriptIconButton(
              key: const ValueKey<String>('script.runOnServer'),
              icon: LucideIcons.server,
              tooltip: l.scriptRunOnServer,
              onPressed: ed.canEdit && selected != null && !running
                  ? () {
                      setState(() {
                        _tab = _BottomTab.log;
                        _bottomOpen = true;
                      });
                      _invoke('sheets.script.run', {
                        'functionName': selected,
                        'onServer': true,
                      });
                    }
                  : null,
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 20,
              color: ShadTheme.of(context).colorScheme.border,
            ),
            const SizedBox(width: 8),
            ShadButton.ghost(
              key: const ValueKey<String>('script.triggers'),
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.alarmClock, size: 15),
              enabled: ed.canEdit,
              onPressed: () => _invoke('sheets.script.openTriggers'),
              child: Text(l.cmdScriptOpenTriggers),
            ),
            ShadButton.ghost(
              key: const ValueKey<String>('script.executions'),
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.listChecks, size: 15),
              onPressed: () => setState(() {
                _tab = _BottomTab.executions;
                _bottomOpen = true;
              }),
              child: Text(l.cmdScriptOpenExecutions),
            ),
            ShadButton.ghost(
              key: const ValueKey<String>('script.settings'),
              size: ShadButtonSize.sm,
              leading: const Icon(LucideIcons.settings, size: 15),
              onPressed: () => _invoke('sheets.script.openSettings'),
              child: Text(l.scriptSettings),
            ),
            if (s.assistant?.available ?? false)
              ShadButton.ghost(
                key: const ValueKey<String>('script.generate'),
                size: ShadButtonSize.sm,
                leading: const Icon(LucideIcons.sparkles, size: 15),
                enabled: ed.canEdit,
                onPressed: () => _invoke('sheets.script.generateWithAi'),
                child: Text(l.scriptGenerate),
              ),
            scriptIconButton(
              key: const ValueKey<String>('script.find'),
              icon: LucideIcons.search,
              tooltip: l.scriptFind,
              onPressed: _active == null ? null : _openFind,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rail(
    BuildContext context,
    SheetEditorController ed,
    ScriptService svc,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final files = svc.files;
    Widget header(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.mutedForeground,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    final macroFns = {
      for (final m in svc.macros) '${m.columns['functionName']}',
    };
    final functions = svc.exports.functions;
    return ColoredBox(
      color: cs.muted.withValues(alpha: 0.4),
      child: ListView(
        key: const ValueKey<String>('script.rail'),
        children: [
          header(
            l.scriptFiles,
            trailing: scriptIconButton(
              key: const ValueKey<String>('script.newFile'),
              icon: LucideIcons.plus,
              tooltip: l.cmdScriptNewFile,
              onPressed: ed.canEdit ? _newFile : null,
            ),
          ),
          for (final f in files) _fileRow(context, ed, svc, f),
          header(l.scriptFunctions),
          if (functions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l.scriptNoFunctions, style: theme.textTheme.muted),
            ),
          for (final f in functions)
            GestureDetector(
              key: ValueKey<String>('script.function.${f.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _openByName(f.file, f.line),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: Row(
                  children: [
                    Text('ƒ', style: TextStyle(color: cs.mutedForeground)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          fontFamily: WonkyTheme.monoFamily,
                        ),
                      ),
                    ),
                    if (f.customFunction != null)
                      Text(
                        'fx',
                        style: theme.textTheme.muted.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (svc.exports.triggers.containsKey(f.name) &&
                        svc.exports.hasTrigger(f.name))
                      Icon(LucideIcons.zap, size: 13, color: cs.warning),
                    if (macroFns.contains(f.name))
                      Icon(
                        LucideIcons.keyboard,
                        size: 13,
                        color: cs.mutedForeground,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileRow(
    BuildContext context,
    SheetEditorController ed,
    ScriptService svc,
    GenericRecord f,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final active = f.id == _active;
    final name = ScriptProjectRows.nameOf(f);
    return GestureDetector(
      key: ValueKey<String>('script.file.$name'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openFile(f.id),
      onDoubleTap: ed.canEdit ? () => _renameFile(f) : null,
      child: Container(
        color: active ? cs.accent : null,
        padding: const EdgeInsets.only(left: 12, right: 2),
        height: 30,
        child: Row(
          children: [
            Icon(LucideIcons.fileCode, size: 14, color: cs.mutedForeground),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small,
              ),
            ),
            if (svc.isDirty(f.id))
              Container(
                key: ValueKey<String>('script.file.$name.dirty'),
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: cs.foreground,
                  shape: BoxShape.circle,
                ),
              ),
            if (active && ed.canEdit) ...[
              scriptIconButton(
                key: ValueKey<String>('script.file.$name.rename'),
                icon: LucideIcons.pencil,
                tooltip: l.cmdScriptRenameFile,
                size: 24,
                onPressed: () => _renameFile(f),
              ),
              scriptIconButton(
                key: ValueKey<String>('script.file.$name.delete'),
                icon: LucideIcons.trash2,
                tooltip: l.cmdScriptDeleteFile,
                size: 24,
                onPressed: () =>
                    _invoke('sheets.script.deleteFile', {'fileId': f.id}),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editorArea(
    BuildContext context,
    SheetEditorController ed,
    ScriptService svc,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final active = _active;
    final row = active == null
        ? null
        : ScriptProjectRows.file(ed.model, active);
    if (active == null || row == null) {
      return Center(
        child: WonkyEmptyState(
          illustration: EmptyIllustration.documents,
          title: l.scriptNoFileOpen,
          actions: [
            if (ed.canEdit)
              ShadButton.outline(
                onPressed: _newFile,
                child: Text(l.cmdScriptNewFile),
              ),
          ],
        ),
      );
    }
    final name = ScriptProjectRows.nameOf(row);
    final problems = _problems().where((d) => d.file == name).toList();
    final c = _controllerFor(active);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            key: const ValueKey<String>('script.tabs'),
            scrollDirection: Axis.horizontal,
            children: [
              for (final id in _open)
                if (ScriptProjectRows.file(ed.model, id) case final f?)
                  _tabChip(context, svc, f, active: id == active),
            ],
          ),
        ),
        Container(height: 1, color: cs.border),
        if (_staleRemote.contains(active))
          Container(
            key: const ValueKey<String>('script.staleBanner'),
            color: cs.warning.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.scriptNewerVersion,
                    style: theme.textTheme.small,
                  ),
                ),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => _reloadRemote(active),
                  child: Text(l.scriptReload),
                ),
              ],
            ),
          ),
        Expanded(
          child: CodeEditor(
            key: ValueKey<String>('script.code.$active'),
            controller: c,
            findController: _find[active],
            readOnly: !ed.canEdit,
            wordWrap: false,
            autofocus: true,
            style: ScriptCodeTheme.style(cs),
            findBuilder: (context, controller, readOnly) =>
                ScriptFindPanel(controller: controller, readOnly: readOnly),
            shortcutOverrideActions: {
              CodeShortcutSaveIntent: CallbackAction<CodeShortcutSaveIntent>(
                onInvoke: (_) {
                  unawaited(_invoke('sheets.script.saveFile'));
                  return null;
                },
              ),
            },
            indicatorBuilder: (context, editing, chunks, notifier) => Row(
              children: [
                DefaultCodeLineNumber(
                  controller: editing,
                  notifier: notifier,
                  textStyle: TextStyle(
                    fontFamily: WonkyTheme.monoFamily,
                    fontSize: 12,
                    color: cs.mutedForeground,
                  ),
                  focusedTextStyle: TextStyle(
                    fontFamily: WonkyTheme.monoFamily,
                    fontSize: 12,
                    color: cs.foreground,
                  ),
                ),
                ProblemGutter(notifier: notifier, problems: problems),
                DefaultCodeChunkIndicator(
                  width: 14,
                  controller: chunks,
                  notifier: notifier,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabChip(
    BuildContext context,
    ScriptService svc,
    GenericRecord f, {
    required bool active,
  }) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final l = sheetsL10n(context);
    final name = ScriptProjectRows.nameOf(f);
    return GestureDetector(
      key: ValueKey<String>('script.tab.$name'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _openFile(f.id),
      onTertiaryTapUp: (_) => _close(f.id),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: active ? cs.card : null,
          border: Border(
            right: BorderSide(color: cs.border),
            bottom: BorderSide(
              color: active ? cs.primary : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(name, style: theme.textTheme.small),
            if (svc.isDirty(f.id))
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('●', style: TextStyle(color: cs.foreground)),
              ),
            scriptIconButton(
              icon: LucideIcons.x,
              tooltip: l.scriptCloseTab,
              size: 22,
              onPressed: () => _close(f.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomPanel(
    BuildContext context,
    SheetEditorController ed,
    ScriptService svc,
    double maxHeight,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final problems = _problems();
    Widget tab(_BottomTab t, String label) {
      final on = _tab == t && _bottomOpen;
      return ShadButton.ghost(
        key: ValueKey<String>('script.bottom.${t.name}'),
        size: ShadButtonSize.sm,
        backgroundColor: on ? cs.accent : null,
        onPressed: () => setState(() {
          _tab = t;
          _bottomOpen = true;
        }),
        child: Text(label),
      );
    }

    final double height = _bottomHeight.clamp(
      80.0,
      (maxHeight * 0.6).clamp(80.0, 600.0),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _bottomOpen
              ? (d) => setState(
                  () => _bottomHeight = (_bottomHeight - d.delta.dy).clamp(
                    80,
                    600,
                  ),
                )
              : null,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: Container(height: 5, color: cs.border),
          ),
        ),
        Container(
          color: cs.muted.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              tab(_BottomTab.problems, l.scriptProblems(problems.length)),
              tab(_BottomTab.log, l.scriptLog),
              tab(_BottomTab.executions, l.cmdScriptOpenExecutions),
              const Spacer(),
              if (_tab == _BottomTab.log && _bottomOpen)
                scriptIconButton(
                  key: const ValueKey<String>('script.log.clear'),
                  icon: LucideIcons.eraser,
                  tooltip: l.scriptClearLog,
                  onPressed: () {
                    svc.log.clear();
                    setState(() {});
                  },
                ),
              scriptIconButton(
                key: const ValueKey<String>('script.bottom.toggle'),
                icon: _bottomOpen
                    ? LucideIcons.chevronDown
                    : LucideIcons.chevronUp,
                tooltip: _bottomOpen ? l.scriptCollapse : l.scriptExpand,
                onPressed: () => setState(() => _bottomOpen = !_bottomOpen),
              ),
            ],
          ),
        ),
        if (_bottomOpen)
          SizedBox(
            height: height,
            child: switch (_tab) {
              _BottomTab.problems => ProblemsList(
                problems: problems,
                onOpen: (d) => _openByName(d.file ?? '', d.line ?? 1),
                onFix: (s.assistant?.available ?? false) && ed.canEdit
                    ? (i) => _invoke('sheets.script.fixErrorWithAi', {
                        'diagnosticIndex': i,
                      })
                    : null,
              ),
              _BottomTab.log =>
                svc.log.isEmpty
                    ? Center(
                        child: Text(
                          l.scriptLogEmpty,
                          key: const ValueKey<String>('script.log.empty'),
                          style: theme.textTheme.muted,
                        ),
                      )
                    : SingleChildScrollView(
                        key: const ValueKey<String>('script.log'),
                        reverse: true,
                        padding: const EdgeInsets.all(8),
                        child: ScriptLogList(
                          lines: [for (final x in svc.log) x.entry],
                          functions: [for (final x in svc.log) x.function],
                        ),
                      ),
              _BottomTab.executions => ScriptExecutionsView(
                editor: ed,
                onOpenFrame: _openByName,
              ),
            },
          ),
      ],
    );
  }
}
