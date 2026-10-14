import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/data_tools/data_tools.dart';
import '../features/find/find_controller.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _edit(SheetsLocalizations l) => l.categoryEditing;

FindController _find(SheetEditorController ed) => DataTools.of(ed).find;

const _optionProps = <String, JsonSchema>{
  'scope': JsonSchema.string(enumValues: ['allSheets', 'sheet', 'range']),
  'range': JsonSchema.string(description: 'A1 range of scope "range".'),
  'matchCase': JsonSchema.boolean(),
  'matchEntireCell': JsonSchema.boolean(),
  'useRegex': JsonSchema.boolean(),
  'searchFormulas': JsonSchema.boolean(),
  'searchLinks': JsonSchema.boolean(),
};

/// The [FindReplace] operation of `find`/`replace` arguments.
FindReplace _replaceOp(
  SheetEditorController ed,
  JsonArgs a, {
  (String, int, int)? onlyCell,
}) {
  final o = FindOptions.fromArgs(a.values);
  ResolvedRange? range;
  List<String>? sheets;
  switch (o.scope) {
    case FindScope.allSheets:
      sheets = null;
    case FindScope.sheet:
      sheets = [ed.activeSheetId];
    case FindScope.range:
      final t = o.range;
      if (t == null || t.trim().isEmpty) {
        sheets = [ed.activeSheetId];
      } else {
        range = ed.model.parseA1(t, contextSheetId: ed.activeSheetId);
      }
  }
  return FindReplace(
    find: a.requireString('find'),
    replacement: a.string('replace') ?? '',
    sheetIds: sheets,
    range: range,
    matchCase: o.matchCase,
    matchEntireCell: o.entireCell,
    useRegex: o.regex,
    searchFormulas: o.searchFormulas,
    searchLinks: o.searchLinks,
    onlyCell: onlyCell,
  );
}

/// Find and replace commands (07 §11.5).
List<Command<CommandArgs>> findCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.find.open',
    label: (l) => l.cmdFindOpen,
    icon: LucideIcons.search,
    categoryName: _edit,
    keyScope: KeyScope.global,
    defaultBindings: const [KeyBinding('F', mod: true)],
    argsSchema: const JsonSchema.object(
      properties: {'query': JsonSchema.string()},
    ),
    run: (ctx, ed, a) {
      final f = _find(ed);
      if (ed.editor.isEditing) ed.editor.commitSync();
      f.barOpen.value = true;
      final q = a.string('query');
      if (q != null) f.setQuery(q);
      f.focusRequest.value++;
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.find.openReplace',
    label: (l) => l.cmdFindOpenReplace,
    icon: LucideIcons.replace,
    categoryName: _edit,
    keyScope: KeyScope.global,
    defaultBindings: const [
      KeyBinding('H', mod: true, shift: true, mac: true),
      KeyBinding('H', mod: true, mac: false),
    ],
    argsSchema: const JsonSchema.object(
      properties: {'query': JsonSchema.string()},
    ),
    run: (ctx, ed, a) {
      final f = _find(ed);
      if (ed.editor.isEditing) ed.editor.commitSync();
      final q = a.string('query');
      if (q != null) f.setQuery(q, select: false);
      f.barOpen.value = false;
      f.dialogOpen.value = true;
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.find.close',
    label: (l) => l.cmdFindClose,
    categoryName: _edit,
    showInPalette: false,
    run: (ctx, ed, a) {
      final f = _find(ed);
      f.barOpen.value = false;
      f.dialogOpen.value = false;
      ed.gridFocus.requestFocus();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.find.next',
    label: (l) => l.cmdFindNext,
    icon: LucideIcons.chevronDown,
    categoryName: _edit,
    keyScope: KeyScope.global,
    defaultBindings: const [KeyBinding('G', mod: true)],
    enabled: (ed, a) => _find(ed).query.isNotEmpty,
    run: (ctx, ed, a) {
      final f = _find(ed);
      if (f.matches.isEmpty) f.refresh();
      return f.step()
          ? ok({'match': f.currentMatch?.toString()})
          : CommandResult.failed(ed.l10n.findNoMatches);
    },
  ),
  SheetsCommand(
    'sheets.find.previous',
    label: (l) => l.cmdFindPrevious,
    icon: LucideIcons.chevronUp,
    categoryName: _edit,
    keyScope: KeyScope.global,
    defaultBindings: const [KeyBinding('G', mod: true, shift: true)],
    enabled: (ed, a) => _find(ed).query.isNotEmpty,
    run: (ctx, ed, a) {
      final f = _find(ed);
      if (f.matches.isEmpty) f.refresh();
      return f.step(reverse: true)
          ? ok({'match': f.currentMatch?.toString()})
          : CommandResult.failed(ed.l10n.findNoMatches);
    },
  ),
  SheetsCommand(
    'sheets.find.replace',
    label: (l) => l.cmdFindReplace,
    categoryName: _edit,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'find': JsonSchema.string(),
        'replace': JsonSchema.string(),
        ..._optionProps,
      },
      required: ['find'],
    ),
    run: (ctx, ed, a) {
      final f = _find(ed);
      final sel = ed.selection.resolved;
      final cur = f.currentMatch;
      final cell = cur != null
          ? (cur.sheetId, cur.row, cur.col)
          : (ed.activeSheetId, sel.activeRow, sel.activeCol);
      final plan = ed.apply(ctx, _replaceOp(ed, a, onlyCell: cell));
      f.refresh();
      f.step();
      final n = plan.result['replaced'];
      return ok({'replaced': n});
    },
  ),
  SheetsCommand(
    'sheets.find.replaceAll',
    label: (l) => l.cmdFindReplaceAll,
    categoryName: _edit,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'find': JsonSchema.string(),
        'replace': JsonSchema.string(),
        ..._optionProps,
      },
      required: ['find'],
    ),
    run: (ctx, ed, a) {
      final plan = ed.apply(ctx, _replaceOp(ed, a));
      final msg = plan.result['message'] as String?;
      if (msg != null) s.toasts.show(msg);
      for (final w in plan.warnings) {
        s.toasts.show(w);
      }
      _find(ed).refresh();
      return ok({
        'replaced': plan.result['replaced'],
        'cells': plan.result['cells'],
        'skipped': plan.result['skipped'],
      });
    },
  ),
];
