import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/dialogs/sheets_dialogs.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _cat(SheetsLocalizations l) => l.categorySheets;

String _sheetArg(SheetEditorController ed, JsonArgs a) =>
    a.string('sheetId') ?? ed.activeSheetId;

const _sheetSchema = JsonSchema.object(
  properties: {'sheetId': JsonSchema.string()},
);

int _visibleCount(SheetEditorController ed) => ed.model.visibleSheets.length;

/// Sheet tab commands (04 §6).
List<Command<CommandArgs>> sheetCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.sheet.add',
    label: (l) => l.cmdSheetAdd,
    icon: LucideIcons.plus,
    categoryName: _cat,
    mutates: true,
    defaultBindings: const [KeyBinding('F11', shift: true)],
    argsSchema: const JsonSchema.object(
      properties: {
        'afterSheetId': JsonSchema.string(),
        'name': JsonSchema.string(),
      },
    ),
    enabled: (ed, a) => ed.model.sheets.length < 200,
    run: (ctx, ed, a) {
      final after = a.string('afterSheetId') ?? ed.activeSheetId;
      final all = ed.model.sheets;
      final i = all.indexWhere((x) => x.id == after);
      final plan = ed.apply(
        ctx,
        AddSheet(name: a.string('name'), index: i < 0 ? null : i + 1),
      );
      final id = plan.result['sheetId'];
      if (id is String) ed.activateSheet(id);
      return ok({'sheetId': id});
    },
  ),
  SheetsCommand(
    'sheets.sheet.delete',
    label: (l) => l.cmdSheetDelete,
    icon: LucideIcons.trash2,
    categoryName: _cat,
    mutates: true,
    argsSchema: _sheetSchema,
    enabled: (ed, a) => _visibleCount(ed) > 1,
    run: (ctx, ed, a) async {
      final id = _sheetArg(ed, a);
      final sheet = ed.model.sheet(id);
      if (sheet == null) return const CommandResult.failed('Unknown sheet');
      final c = ctx.dialogContext;
      final hasContent = sheet.cells.contentCount > 0;
      if (hasContent && c != null && !ctx.source.isAgent) {
        if (!await confirmDeleteSheetDialog(c, sheet.name)) {
          return const CommandResult.cancelled();
        }
      }
      await ed.applyConfirmed(ctx, DeleteSheet(id));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.sheet.duplicate',
    label: (l) => l.cmdSheetDuplicate,
    icon: LucideIcons.copyPlus,
    categoryName: _cat,
    mutates: true,
    argsSchema: _sheetSchema,
    run: (ctx, ed, a) {
      final id = _sheetArg(ed, a);
      final i = ed.model.sheets.indexWhere((x) => x.id == id);
      final plan = ed.apply(ctx, DuplicateSheet(id, index: i + 1));
      final nid = plan.result['sheetId'];
      if (nid is String) ed.activateSheet(nid);
      return ok({'sheetId': nid});
    },
  ),
  SheetsCommand(
    'sheets.sheet.rename',
    label: (l) => l.cmdSheetRename,
    icon: LucideIcons.pencil,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'sheetId': JsonSchema.string(), 'name': JsonSchema.string()},
      required: ['name'],
    ),
    run: (ctx, ed, a) {
      final name = a.requireString('name').trim();
      if (name.isEmpty) {
        return CommandResult.failed(ed.l10n.errorSheetNameEmpty);
      }
      ed.apply(ctx, RenameSheet(_sheetArg(ed, a), name));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.sheet.startRename',
    label: (l) => l.cmdSheetRename,
    icon: LucideIcons.pencil,
    categoryName: _cat,
    argsSchema: _sheetSchema,
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      ed.renamingSheet.value = _sheetArg(ed, a);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.sheet.setColor',
    label: (l) => l.cmdSheetSetColor,
    icon: LucideIcons.palette,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'sheetId': JsonSchema.string(),
        'color': JsonSchema.nullable(JsonSchema.string()),
      },
    ),
    run: (ctx, ed, a) {
      final color = a.string('color');
      ed.apply(
        ctx,
        SetSheetProperties(
          _sheetArg(ed, a),
          tabColor: color,
          clearTabColor: color == null,
        ),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.sheet.hide',
    label: (l) => l.cmdSheetHide,
    icon: LucideIcons.eyeOff,
    categoryName: _cat,
    mutates: true,
    argsSchema: _sheetSchema,
    enabled: (ed, a) => _visibleCount(ed) > 1,
    run: (ctx, ed, a) {
      final id = _sheetArg(ed, a);
      ed.apply(ctx, SetSheetProperties(id, hidden: true));
      if (id == ed.activeSheetId) {
        final next = ed.model.visibleSheets.firstOrNull;
        if (next != null) ed.activateSheet(next.id);
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.sheet.unhide',
    label: (l) => l.cmdSheetUnhide,
    icon: LucideIcons.eye,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {'sheetId': JsonSchema.string()},
      required: ['sheetId'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('sheetId');
      ed.apply(ctx, SetSheetProperties(id, hidden: false));
      ed.activateSheet(id);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.sheet.move',
    label: (l) => l.cmdSheetMove,
    categoryName: _cat,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'sheetId': JsonSchema.string(),
        'beforeSheetId': JsonSchema.nullable(JsonSchema.string()),
      },
    ),
    run: (ctx, ed, a) {
      final id = _sheetArg(ed, a);
      final all = [for (final x in ed.model.sheets) x.id];
      final before = a.string('beforeSheetId');
      final without = all.where((x) => x != id).toList();
      final index = before == null ? without.length : without.indexOf(before);
      ed.apply(ctx, MoveSheet(id, index < 0 ? without.length : index));
      return ok();
    },
  ),
  for (final (id, delta, label) in [
    (
      'sheets.sheet.moveLeft',
      -1,
      (SheetsLocalizations l) => l.cmdSheetMoveLeft,
    ),
    (
      'sheets.sheet.moveRight',
      1,
      (SheetsLocalizations l) => l.cmdSheetMoveRight,
    ),
  ])
    SheetsCommand(
      id,
      label: label,
      categoryName: _cat,
      mutates: true,
      argsSchema: _sheetSchema,
      enabled: (ed, a) {
        final all = ed.model.sheets;
        final i = all.indexWhere((x) => x.id == _sheetArg(ed, a));
        return i >= 0 && i + delta >= 0 && i + delta < all.length;
      },
      run: (ctx, ed, a) {
        final sid = _sheetArg(ed, a);
        final all = ed.model.sheets;
        final i = all.indexWhere((x) => x.id == sid);
        ed.apply(ctx, MoveSheet(sid, i + delta));
        return ok();
      },
    ),
  SheetsCommand(
    'sheets.sheet.activate',
    label: (l) => l.cmdSheetActivate,
    categoryName: _cat,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'sheetId': JsonSchema.string(), 'name': JsonSchema.string()},
    ),
    run: (ctx, ed, a) {
      final name = a.string('name');
      final sheet = name != null
          ? ed.model.sheetByName(name)
          : ed.model.sheet(_sheetArg(ed, a));
      if (sheet == null) return const CommandResult.failed('Unknown sheet');
      ed.activateSheet(sheet.id);
      return ok();
    },
  ),
  for (final (id, delta, label, key) in [
    (
      'sheets.sheet.activateNext',
      1,
      (SheetsLocalizations l) => l.cmdSheetActivateNext,
      Keys.pageDown,
    ),
    (
      'sheets.sheet.activatePrevious',
      -1,
      (SheetsLocalizations l) => l.cmdSheetActivatePrevious,
      Keys.pageUp,
    ),
  ])
    SheetsCommand(
      id,
      label: label,
      categoryName: _cat,
      keyScope: KeyScope.global,
      defaultBindings: [
        KeyBinding(key, mod: true, shift: true, mac: false),
        KeyBinding(
          delta > 0 ? Keys.arrowDown : Keys.arrowUp,
          mod: true,
          alt: true,
          mac: true,
        ),
      ],
      run: (ctx, ed, a) {
        final vis = ed.model.visibleSheets;
        final i = vis.indexWhere((x) => x.id == ed.activeSheetId);
        if (vis.isEmpty) return const CommandResult.cancelled();
        final next = vis[(i + delta) % vis.length];
        ed.activateSheet(next.id);
        return ok();
      },
    ),
];
