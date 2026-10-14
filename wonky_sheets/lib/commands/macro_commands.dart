import 'dart:async';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../features/macros/macro_dialogs.dart';
import '../features/macros/macro_service.dart';
import '../features/scripts/script_project.dart';
import '../features/scripts/script_service.dart';
import 'sheets_command.dart';

String _cat(SheetsLocalizations l) => l.categoryScripts;

const _slotSchema = JsonSchema.integer(
  minimum: 1,
  maximum: 10,
  description: 'Mod+Alt+Shift+1…9 (10 = 0).',
);

/// Macro commands (09 §15, §17). The per-macro commands
/// `sheets.macro.<id>` are registered dynamically by `MacroService`.
List<Command<CommandArgs>> macroCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.macro.record',
    label: (l) => l.cmdMacroRecord,
    icon: LucideIcons.circleDot,
    categoryName: _cat,
    argsSchema: const JsonSchema.object(
      properties: {
        'mode': JsonSchema.string(enumValues: ['absolute', 'relative']),
      },
    ),
    enabled: (ed, a) =>
        ed.canEdit && !(MacroService.maybeOf(ed)?.recording ?? false),
    run: (ctx, ed, a) {
      MacroService.of(ed).startRecording(
        a.string('mode') == 'relative'
            ? MacroReferenceMode.relative
            : MacroReferenceMode.absolute,
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.macro.cancelRecording',
    label: (l) => l.cmdMacroCancelRecording,
    icon: LucideIcons.x,
    categoryName: _cat,
    enabled: (ed, a) => MacroService.maybeOf(ed)?.recording ?? false,
    run: (ctx, ed, a) {
      MacroService.of(ed).cancelRecording();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.macro.saveRecording',
    label: (l) => l.cmdMacroSaveRecording,
    icon: LucideIcons.save,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {'name': JsonSchema.string(), 'shortcutSlot': _slotSchema},
    ),
    undoLabelOf: (l, a) => l.cmdMacroRecord,
    enabled: (ed, a) => MacroService.maybeOf(ed)?.recording ?? false,
    run: (ctx, ed, a) async {
      var name = a.string('name');
      var slot = a.integer('shortcutSlot');
      final c = ctx.dialogContext;
      if (name == null && c != null && !ctx.source.isAgent) {
        final r = await showSaveMacroDialog(c, ed);
        if (r == null) return const CommandResult.cancelled();
        (name, slot) = r;
      }
      final svc = MacroService.of(ed);
      final id = svc.saveRecording(
        ctx,
        name: name ?? ed.l10n.macroDefaultName(svc.macros.length + 1),
        shortcutSlot: slot,
      );
      unawaited(ScriptService.of(ed).compile());
      return ok({'macroId': id, 'commandId': macroCommandId(id)});
    },
  ),
  SheetsCommand(
    'sheets.macro.import',
    label: (l) => l.cmdMacroImport,
    icon: LucideIcons.import,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'functionName': JsonSchema.string(),
        'name': JsonSchema.string(),
        'shortcutSlot': _slotSchema,
      },
    ),
    enabled: (ed, a) => ScriptService.maybeOf(ed)?.program != null,
    run: (ctx, ed, a) async {
      final svc = ScriptService.of(ed);
      var fn = a.string('functionName');
      var name = a.string('name');
      var slot = a.integer('shortcutSlot');
      final c = ctx.dialogContext;
      if (fn == null && c != null && !ctx.source.isAgent) {
        final r = await showImportMacroDialog(c, ed, svc.exports);
        if (r == null) return const CommandResult.cancelled();
        (fn, name, slot) = r;
      }
      if (fn == null || svc.exports.function(fn) == null) {
        return CommandResult.failed(ed.l10n.scriptUnknownFunction(fn ?? ''));
      }
      final id = ScriptProjectWriter(ed).createMacro(
        ctx,
        name: name ?? fn,
        functionName: fn,
        shortcutSlot: slot,
      );
      return ok({'macroId': id, 'commandId': macroCommandId(id)});
    },
  ),
  SheetsCommand(
    'sheets.macro.manage',
    label: (l) => l.cmdMacroManage,
    icon: LucideIcons.listOrdered,
    categoryName: _cat,
    enabled: (ed, a) => ed.canEdit && scriptProjectOf(ed.model) != null,
    run: (ctx, ed, a) async {
      final c = ctx.dialogContext;
      if (c == null) {
        return ok({
          'macros': [
            for (final m in ScriptService.of(ed).macros)
              {
                'macroId': m.id,
                'commandId': macroCommandId(m.id),
                'name': m.columns[ScriptCols.name],
                'functionName': m.columns[ScriptCols.functionName],
                'shortcutSlot': m.columns[ScriptCols.shortcutSlot],
              },
          ],
        });
      }
      await showManageMacrosDialog(c, ed);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.macro.update',
    label: (l) => l.cmdMacroUpdate,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'macroId': JsonSchema.string(),
        'name': JsonSchema.string(),
        'shortcutSlot': JsonSchema.nullable(_slotSchema),
      },
      required: ['macroId'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('macroId');
      if (ScriptProjectRows.macro(ed.model, id) == null) {
        return CommandResult.failed(ed.l10n.macroNotFound);
      }
      final cols = <String, Object?>{
        if (a.string('name')?.trim().isNotEmpty ?? false)
          ScriptCols.name: a.string('name')!.trim(),
        if (a.values.containsKey('shortcutSlot'))
          ScriptCols.shortcutSlot: a.integer('shortcutSlot'),
      };
      if (cols.isEmpty) return ok();
      ScriptProjectWriter(ed).updateMacro(ctx, id, cols);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.macro.delete',
    label: (l) => l.cmdMacroDelete,
    icon: LucideIcons.trash2,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'macroId': JsonSchema.string()},
      required: ['macroId'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('macroId');
      if (ScriptProjectRows.macro(ed.model, id) == null) {
        return CommandResult.failed(ed.l10n.macroNotFound);
      }
      ScriptProjectWriter(ed).deleteMacro(ctx, id);
      return ok();
    },
  ),
];
