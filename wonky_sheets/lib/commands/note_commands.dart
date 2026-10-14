import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/in_cell/in_cell_controller.dart';
import 'sheets_command.dart';

String _edit(SheetsLocalizations l) => l.categoryEditing;

/// Notes (03 §14.5): the note editor popover and clearing notes.
List<Command<CommandArgs>> noteCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.notes.insert',
    label: (l) => l.cmdNotesInsert,
    icon: LucideIcons.stickyNote,
    categoryName: _edit,
    mutates: true,
    defaultBindings: const [KeyBinding('F2', shift: true)],
    argsSchema: const JsonSchema.object(
      properties: {
        'cell': JsonSchema.string(description: 'A1 cell (default: active).'),
        'text': JsonSchema.string(
          description: 'The note; empty deletes it. Omit to open the editor.',
        ),
      },
    ),
    run: (ctx, ed, a) {
      final cell = a.string('cell');
      final ResolvedRange target = cell == null
          ? ed.activeRange
          : ed.model.parseA1(cell, contextSheetId: ed.activeSheetId);
      final sid = target.sheetId;
      final r = cell == null
          ? ed.selection.resolved.activeRow
          : target.rect.top;
      final c = cell == null
          ? ed.selection.resolved.activeCol
          : target.rect.left;
      final text = a.string('text');
      if (text == null) {
        if (ctx.source.isAgent) {
          return const CommandResult.failed('text is required');
        }
        InCellController.of(ed).openNoteEditor(sid, r, c);
        return ok();
      }
      ed.apply(ctx, SetNote(sid, r, c, text.isEmpty ? null : text));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.notes.clear',
    label: (l) => l.cmdNotesClear,
    icon: LucideIcons.eraser,
    categoryName: _edit,
    mutates: true,
    argsSchema: Schemas.ranges,
    run: (ctx, ed, a) {
      ed.apply(ctx, ClearRanges(rangesArg(ed, a), what: ClearWhat.notes));
      return ok();
    },
  ),
];
