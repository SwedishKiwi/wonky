import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart' show GenericRecord;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../features/scripts/executions_panel.dart';
import '../features/scripts/script_api_reference.dart';
import '../features/scripts/script_project.dart';
import '../features/scripts/script_service.dart';
import '../features/scripts/settings_dialog.dart';
import '../features/scripts/triggers_dialog.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _cat(SheetsLocalizations l) => l.categoryScripts;

/// Key scope of the script editor route (09 §14.2).
const scriptEditorScope = KeyScope('scriptEditor');

ScriptService _svc(SheetEditorController ed) => ScriptService.of(ed);

String _itemPath(SheetEditorController ed) => '/s/${ed.session.itemUuid.uuid}';

/// Whether the spreadsheet has a script project.
bool _hasProject(SheetEditorController ed) => scriptProjectOf(ed.model) != null;

CommandResult _nameError(SheetsLocalizations l, String? code) =>
    CommandResult.failed(switch (code) {
      'duplicate' => l.scriptFileNameDuplicate,
      'limit' => l.scriptFileLimit,
      _ => l.scriptFileNameInvalid,
    });

GenericRecord? _file(SheetEditorController ed, JsonArgs a) {
  final id = a.string('fileId');
  if (id != null) return ScriptProjectRows.file(ed.model, id);
  final name = a.string('name');
  return name == null ? null : ScriptProjectRows.fileNamed(ed.model, name);
}

const _triggerSchema = JsonSchema.object(
  properties: {
    'triggerId': JsonSchema.string(),
    'functionName': JsonSchema.string(),
    'event': JsonSchema.string(
      enumValues: ['timeDriven', 'onEdit', 'onChange', 'installableOnOpen'],
    ),
    'schedule': JsonSchema.object(
      description:
          '{type: minutes|hours|days|weeks|monthly|once, interval, atHour, '
          'weekday, monthDay, at}',
      additionalProperties: true,
    ),
    'enabled': JsonSchema.boolean(),
    'options': JsonSchema.object(
      description: '{fireForMcp, notify: immediately|daily|never}',
      additionalProperties: true,
    ),
  },
);

/// Script commands (09 §17): editor route, files, save/compile, runs,
/// custom menu items, triggers, executions, settings and authorization.
List<Command<CommandArgs>> scriptCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.script.openEditor',
    label: (l) => l.cmdScriptOpenEditor,
    icon: LucideIcons.code,
    categoryName: _cat,
    argsSchema: const JsonSchema.object(
      properties: {'file': JsonSchema.string(), 'line': JsonSchema.integer()},
    ),
    enabled: (ed, a) => ed.canEdit || _hasProject(ed),
    run: (ctx, ed, a) {
      if (!_hasProject(ed)) {
        // Created lazily on first open (09 §4); infrastructure, not an
        // undo step.
        ScriptProjectWriter(ed).ensureProject(null);
      }
      _svc(ed);
      final q = <String, String>{
        'file': ?a.string('file'),
        if (a.integer('line') != null) 'line': '${a.integer('line')}',
      };
      final path = '${_itemPath(ed)}/script';
      s.router.go(
        q.isEmpty ? path : Uri(path: path, queryParameters: q).toString(),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.closeEditor',
    label: (l) => l.cmdScriptCloseEditor,
    icon: LucideIcons.arrowLeft,
    categoryName: _cat,
    keyScope: KeyScope.global,
    showInPalette: false,
    run: (ctx, ed, a) {
      s.router.go(_itemPath(ed));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.newFile',
    label: (l) => l.cmdScriptNewFile,
    icon: LucideIcons.filePlus,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {'name': JsonSchema.string(description: 'utils.dart')},
      required: ['name'],
    ),
    undoLabelOf: (l, a) => l.undoCreateScriptFile,
    run: (ctx, ed, a) {
      final name = a.requireString('name').trim();
      final w = ScriptProjectWriter(ed)..ensureProject(ctx);
      final err = w.checkName(name);
      if (err != null) return _nameError(ed.l10n, err);
      final id = w.createFile(ctx, name);
      return ok({'fileId': id});
    },
  ),
  SheetsCommand(
    'sheets.script.renameFile',
    label: (l) => l.cmdScriptRenameFile,
    icon: LucideIcons.pencil,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'fileId': JsonSchema.string(), 'name': JsonSchema.string()},
      required: ['fileId', 'name'],
    ),
    run: (ctx, ed, a) {
      final f = _file(ed, JsonArgs({'fileId': a.requireString('fileId')}));
      if (f == null) return CommandResult.failed(ed.l10n.scriptFileNotFound);
      final name = a.requireString('name').trim();
      final w = ScriptProjectWriter(ed);
      final err = w.checkName(name, exceptId: f.id);
      if (err != null) return _nameError(ed.l10n, err);
      w.renameFile(ctx, f.id, name);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.deleteFile',
    label: (l) => l.cmdScriptDeleteFile,
    icon: LucideIcons.trash2,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'fileId': JsonSchema.string()},
      required: ['fileId'],
    ),
    undoLabelOf: (l, a) => l.undoDeleteScriptFile,
    run: (ctx, ed, a) {
      final f = _file(ed, a);
      if (f == null) return CommandResult.failed(ed.l10n.scriptFileNotFound);
      ScriptProjectWriter(ed).deleteFile(ctx, f.id);
      ScriptService.maybeOf(ed)?.drafts.remove(f.id);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.reorderFile',
    label: (l) => l.cmdScriptReorderFile,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'fileId': JsonSchema.string(),
        'index': JsonSchema.integer(minimum: 0),
      },
      required: ['fileId', 'index'],
    ),
    run: (ctx, ed, a) {
      final f = _file(ed, a);
      if (f == null) return CommandResult.failed(ed.l10n.scriptFileNotFound);
      ScriptProjectWriter(ed).reorderFile(ctx, f.id, a.integer('index') ?? 0);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.saveFile',
    label: (l) => l.cmdScriptSaveFile,
    icon: LucideIcons.save,
    categoryName: _cat,
    keyScope: scriptEditorScope,
    defaultBindings: const [KeyBinding('S', mod: true)],
    argsSchema: const JsonSchema.object(
      properties: {
        'fileId': JsonSchema.string(),
        'source': JsonSchema.string(
          description: 'New source (default: the editor draft).',
        ),
      },
    ),
    enabled: (ed, a) => ed.canEdit && _hasProject(ed),
    run: (ctx, ed, a) async {
      final svc = _svc(ed);
      final id = a.string('fileId') ?? svc.activeFileId;
      if (id == null) return CommandResult.failed(ed.l10n.scriptFileNotFound);
      final saved = await svc.save(
        id,
        source: a.string('source'),
        context: ctx.dialogContext,
      );
      return ok({'saved': saved});
    },
  ),
  SheetsCommand(
    'sheets.script.saveAll',
    label: (l) => l.cmdScriptSaveAll,
    categoryName: _cat,
    keyScope: scriptEditorScope,
    defaultBindings: const [KeyBinding('S', mod: true, alt: true)],
    enabled: (ed, a) => ed.canEdit && _hasProject(ed),
    run: (ctx, ed, a) async =>
        ok({'saved': await _svc(ed).saveAll(context: ctx.dialogContext)}),
  ),
  SheetsCommand(
    'sheets.script.compile',
    label: (l) => l.cmdScriptCompile,
    icon: LucideIcons.hammer,
    categoryName: _cat,
    enabled: (ed, a) => ed.canEdit && _hasProject(ed),
    run: (ctx, ed, a) async {
      final r = await _svc(ed).compile();
      if (r == null) return CommandResult.failed(ed.l10n.scriptOffline);
      return ok({
        'ok': r.ok,
        'diagnostics': [for (final d in r.diagnostics) d.toJson()],
      });
    },
  ),
  SheetsCommand(
    'sheets.script.run',
    label: (l) => l.cmdScriptRun,
    icon: LucideIcons.play,
    categoryName: _cat,
    keyScope: scriptEditorScope,
    defaultBindings: const [KeyBinding('Enter', mod: true)],
    argsSchema: const JsonSchema.object(
      properties: {
        'functionName': JsonSchema.string(),
        'onServer': JsonSchema.boolean(),
      },
    ),
    enabled: (ed, a) =>
        ed.canEdit && ScriptService.maybeOf(ed)?.program != null,
    run: (ctx, ed, a) async {
      final svc = _svc(ed);
      final fn = a.string('functionName') ?? svc.selectedFunction;
      if (fn == null) return CommandResult.failed(ed.l10n.scriptPickFunction);
      if (svc.drafts.isNotEmpty && ctx.dialogContext != null) {
        await svc.saveAll(context: ctx.dialogContext);
      }
      if (a.boolean('onServer') == true) {
        final r = await svc.runOnServer(fn);
        if (r == null) return const CommandResult.cancelled();
        return ok({'status': r.status.name, 'error': r.error?.message});
      }
      final r = await svc.run(fn, context: ctx.dialogContext);
      if (r == null) return const CommandResult.cancelled();
      return ok({
        'status': r.status.name,
        'result': _jsonable(r.result),
        'error': r.error?.message,
        'logs': [for (final e in r.logs) e.message],
      });
    },
  ),
  SheetsCommand(
    'sheets.script.stop',
    label: (l) => l.cmdScriptStop,
    icon: LucideIcons.square,
    categoryName: _cat,
    enabled: (ed, a) => ScriptService.maybeOf(ed)?.running.isNotEmpty ?? false,
    run: (ctx, ed, a) async {
      await _svc(ed).stop();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.runMenuItem',
    label: (l) => l.cmdScriptRunMenuItem,
    categoryName: _cat,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'functionName': JsonSchema.string(),
        'caption': JsonSchema.string(),
      },
      required: ['functionName'],
    ),
    run: (ctx, ed, a) async {
      final r = await _svc(ed).run(
        a.requireString('functionName'),
        kind: ExecutionKind.menu,
        context: ctx.dialogContext,
      );
      if (r == null) return const CommandResult.cancelled();
      return r.ok
          ? ok({'status': r.status.name})
          : CommandResult.failed(r.error?.message ?? r.status.name);
    },
  ),
  SheetsCommand(
    'sheets.script.openTriggers',
    label: (l) => l.cmdScriptOpenTriggers,
    icon: LucideIcons.alarmClock,
    categoryName: _cat,
    enabled: (ed, a) => ed.canEdit && _hasProject(ed),
    run: (ctx, ed, a) async {
      final c = ctx.dialogContext;
      if (c == null) {
        return ok({'triggers': describeTriggers(ed)});
      }
      await showTriggersDialog(c, ed);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.addTrigger',
    label: (l) => l.cmdScriptAddTrigger,
    icon: LucideIcons.plus,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: _triggerSchema,
    enabled: (ed, a) => _hasProject(ed),
    run: (ctx, ed, a) async {
      var fn = a.string('functionName');
      var event = a.string('event');
      var schedule = (a.values['schedule'] as Map?)?.cast<String, Object?>();
      var options = (a.values['options'] as Map?)?.cast<String, Object?>();
      final c = ctx.dialogContext;
      if (fn == null && c != null && !ctx.source.isAgent) {
        final d = await showAddTriggerDialog(c, ed);
        if (d == null) return const CommandResult.cancelled();
        fn = d.functionName;
        event = d.event;
        schedule = d.schedule;
        options = d.options;
      }
      if (fn == null || event == null) {
        return CommandResult.failed(ed.l10n.scriptPickFunction);
      }
      final svc = _svc(ed);
      final scopes = {ScriptScopes.triggers};
      if (!svc.grantedScopes.contains(ScriptScopes.triggers) &&
          !await svc.authorize(
            scopes,
            context: c != null && c.mounted ? c : null,
          )) {
        return const CommandResult.cancelled();
      }
      final id = addTrigger(
        ctx,
        ed,
        functionName: fn,
        event: event,
        schedule: schedule,
        options: options,
      );
      return ok({'triggerId': id});
    },
  ),
  SheetsCommand(
    'sheets.script.updateTrigger',
    label: (l) => l.cmdScriptUpdateTrigger,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: _triggerSchema,
    run: (ctx, ed, a) {
      final id = a.requireString('triggerId');
      final cols = <String, Object?>{
        if (a.string('functionName') != null)
          ScriptCols.functionName: a.string('functionName'),
        if (a.string('event') != null) ScriptCols.kind: a.string('event'),
        if (a.values.containsKey('schedule'))
          ScriptCols.scheduleJson: a.values['schedule'] == null
              ? null
              : jsonEncode(a.values['schedule']),
        if (a.boolean('enabled') != null)
          ScriptCols.enabled: a.boolean('enabled'),
        if (a.values.containsKey('options'))
          ScriptCols.optionsJson: a.values['options'] == null
              ? null
              : jsonEncode(a.values['options']),
      };
      final err = updateTrigger(ctx, ed, id, cols);
      return err == null ? ok() : CommandResult.failed(err);
    },
  ),
  SheetsCommand(
    'sheets.script.deleteTrigger',
    label: (l) => l.cmdScriptDeleteTrigger,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'triggerId': JsonSchema.string()},
      required: ['triggerId'],
    ),
    run: (ctx, ed, a) {
      final err = deleteTrigger(ctx, ed, a.requireString('triggerId'));
      return err == null ? ok() : CommandResult.failed(err);
    },
  ),
  SheetsCommand(
    'sheets.script.openExecutions',
    label: (l) => l.cmdScriptOpenExecutions,
    icon: LucideIcons.listChecks,
    categoryName: _cat,
    argsSchema: const JsonSchema.object(
      properties: {
        'filter': JsonSchema.object(
          description: '{function?, status?}',
          additionalProperties: true,
        ),
      },
    ),
    run: (ctx, ed, a) {
      _svc(ed);
      s.panels.open(scriptExecutionsPanelId);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.revertExecution',
    label: (l) => l.cmdScriptRevertExecution,
    icon: LucideIcons.undo2,
    categoryName: _cat,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'changeId': JsonSchema.string(),
        'functionName': JsonSchema.string(),
      },
      required: ['changeId'],
    ),
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) async {
      final done = await _svc(ed).revertServerChange(
        a.requireString('changeId'),
        a.string('functionName') ?? '',
      );
      return done ? ok() : CommandResult.failed(ed.l10n.scriptOffline);
    },
  ),
  SheetsCommand(
    'sheets.script.openSettings',
    label: (l) => l.cmdScriptOpenSettings,
    icon: LucideIcons.settings,
    categoryName: _cat,
    enabled: (ed, a) => _hasProject(ed),
    run: (ctx, ed, a) async {
      final c = ctx.dialogContext;
      if (c == null) return ok({'settings': _svc(ed).settings});
      await showScriptSettingsDialog(c, ed);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.updateSettings',
    label: (l) => l.cmdScriptUpdateSettings,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'patch': JsonSchema.object(
          description:
              '{name?, timeZone?, urlAllowlist?: [host], '
              'showMenusInMenubar?: bool}',
          additionalProperties: true,
        ),
      },
      required: ['patch'],
    ),
    enabled: (ed, a) => _hasProject(ed),
    run: (ctx, ed, a) {
      final patch = (a.values['patch'] as Map).cast<String, Object?>();
      applyScriptSettings(ctx, ed, patch);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.deleteProject',
    label: (l) => l.scriptSettingsDeleteProject,
    icon: LucideIcons.trash2,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    enabled: (ed, a) => _hasProject(ed) && ed.itemRole >= Role.owner,
    run: (ctx, ed, a) {
      deleteScriptProject(ctx, ed);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.script.authorize',
    label: (l) => l.cmdScriptAuthorize,
    icon: LucideIcons.shieldCheck,
    categoryName: _cat,
    enabled: (ed, a) => ScriptService.maybeOf(ed)?.program != null,
    run: (ctx, ed, a) async {
      final svc = _svc(ed);
      final scopes = {...svc.exports.scopes}..removeAll(ScriptScopes.implicit);
      if (scopes.isEmpty) return ok({'scopes': <String>[]});
      final granted = await svc.authorize(scopes, context: ctx.dialogContext);
      return granted
          ? ok({'scopes': svc.grantedScopes.toList()})
          : const CommandResult.cancelled();
    },
  ),
  SheetsCommand(
    'sheets.script.revokeAuthorization',
    label: (l) => l.cmdScriptRevokeAuthorization,
    icon: LucideIcons.shieldOff,
    categoryName: _cat,
    enabled: (ed, a) => _hasProject(ed),
    run: (ctx, ed, a) async {
      final done = await _svc(ed).revokeAuthorization();
      return done ? ok() : CommandResult.failed(ed.l10n.scriptOffline);
    },
  ),
  SheetsCommand(
    'sheets.help.scriptApiReference',
    label: (l) => l.cmdHelpScriptApiReference,
    icon: LucideIcons.bookOpen,
    categoryName: _cat,
    keyScope: KeyScope.global,
    argsSchema: const JsonSchema.object(
      properties: {
        'class': JsonSchema.string(description: 'Class to show first.'),
      },
    ),
    run: (ctx, ed, a) async {
      final c = ctx.dialogContext;
      if (c == null) {
        return ok({
          'classes': [for (final k in ApiIndex.standard.classes) k.name],
        });
      }
      await showScriptApiReference(c, initial: a.string('class'));
      return ok();
    },
  ),
  for (final (id, label, prompt) in <(String, SheetsText, String)>[
    (
      'sheets.script.generateWithAi',
      (l) => l.cmdScriptGenerateWithAi,
      'Write a Wonky Script function (Dart, package:wonky/wonky.dart) for '
          'this spreadsheet: ',
    ),
    (
      'sheets.script.explainWithAi',
      (l) => l.cmdScriptExplainWithAi,
      'Explain what the script file {file} of this spreadsheet does.',
    ),
    (
      'sheets.script.fixErrorWithAi',
      (l) => l.cmdScriptFixErrorWithAi,
      'Fix this problem in the script of this spreadsheet: {problem}',
    ),
  ])
    SheetsCommand(
      id,
      label: label,
      icon: LucideIcons.sparkles,
      categoryName: _cat,
      argsSchema: const JsonSchema.object(
        properties: {
          'prompt': JsonSchema.string(),
          'fileId': JsonSchema.string(),
          'diagnosticIndex': JsonSchema.integer(),
        },
      ),
      enabled: (ed, a) =>
          ed.canEdit && _hasProject(ed) && (s.assistant?.available ?? false),
      run: (ctx, ed, a) async {
        final svc = _svc(ed);
        final file =
            _file(ed, a) ??
            (svc.activeFileId == null
                ? null
                : ScriptProjectRows.file(ed.model, svc.activeFileId!));
        final diags = svc.buildDiagnostics;
        final i = a.integer('diagnosticIndex') ?? 0;
        final problem = i < diags.length
            ? '${diags[i].file}:${diags[i].line}: ${diags[i].message}'
            : '';
        final text =
            prompt
                .replaceAll(
                  '{file}',
                  file == null ? 'main.dart' : ScriptProjectRows.nameOf(file),
                )
                .replaceAll('{problem}', problem) +
            (a.string('prompt') ?? '');
        final hook = s.assistant;
        if (hook == null) return CommandResult.failed(ed.l10n.scriptOffline);
        s.panels.open(hook.panelId);
        await hook.send(text);
        return ok();
      },
    ),
];

Object? _jsonable(Object? v) => switch (v) {
  null || String() || num() || bool() => v,
  DateTime d => d.toUtc().toIso8601String(),
  Map<Object?, Object?> m => {
    for (final e in m.entries) '${e.key}': _jsonable(e.value),
  },
  Iterable<Object?> l => [for (final e in l) _jsonable(e)],
  _ => '$v',
};
