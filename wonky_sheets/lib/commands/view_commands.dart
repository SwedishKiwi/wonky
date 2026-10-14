import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/status/selection_stats.dart';
import 'sheets_command.dart';

String _view(SheetsLocalizations l) => l.categoryView;

/// View, mode, statistics and misc commands (03 §19, 04 §3.3, §7).
List<Command<CommandArgs>> viewCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.view.zoom',
    label: (l) => l.cmdViewZoom,
    icon: LucideIcons.zoomIn,
    categoryName: _view,
    keyScope: KeyScope.global,
    argsSchema: const JsonSchema.object(
      properties: {'percent': JsonSchema.integer(minimum: 50, maximum: 200)},
      required: ['percent'],
    ),
    checked: (ed, a) {
      final p = a.integer('percent');
      return p == null ? null : (ed.scroll.zoom * 100).round() == p;
    },
    run: (ctx, ed, a) {
      ed.setZoom((a.integer('percent') ?? 100) / 100);
      return ok();
    },
  ),
  for (final (id, delta, label, key) in [
    ('sheets.view.zoomIn', 1, (SheetsLocalizations l) => l.cmdViewZoomIn, '='),
    (
      'sheets.view.zoomOut',
      -1,
      (SheetsLocalizations l) => l.cmdViewZoomOut,
      '-',
    ),
  ])
    SheetsCommand(
      id,
      label: label,
      icon: delta > 0 ? LucideIcons.zoomIn : LucideIcons.zoomOut,
      categoryName: _view,
      keyScope: KeyScope.global,
      // Browser zoom keys are not overridden on web (03 §19).
      defaultBindings: [KeyBinding(key, mod: true, web: false)],
      run: (ctx, ed, a) {
        const steps = [50, 75, 90, 100, 125, 150, 200];
        final cur = (ed.scroll.zoom * 100).round();
        final next = delta > 0
            ? steps.firstWhere((x) => x > cur, orElse: () => 200)
            : steps.lastWhere((x) => x < cur, orElse: () => 50);
        ed.setZoom(next / 100);
        return ok();
      },
    ),
  SheetsCommand(
    'sheets.view.toggleFormulas',
    label: (l) => l.cmdViewToggleFormulas,
    icon: LucideIcons.squareFunction,
    categoryName: _view,
    defaultBindings: const [
      KeyBinding('`', mod: true, mac: false),
      KeyBinding('`', ctrl: true, mac: true),
    ],
    checked: (ed, a) => ed.showFormulas,
    run: (ctx, ed, a) {
      ed.showFormulas = !ed.showFormulas;
      ed.notifyZoom();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.view.toggleFormulaBar',
    label: (l) => l.cmdViewToggleFormulaBar,
    categoryName: _view,
    checked: (ed, a) => ed.showFormulaBar,
    run: (ctx, ed, a) {
      ed.showFormulaBar = !ed.showFormulaBar;
      ed.notifyZoom();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.formulaBar.toggleExpanded',
    label: (l) => l.cmdFormulaBarToggleExpanded,
    categoryName: _view,
    checked: (ed, a) => ed.formulaBarExpanded,
    run: (ctx, ed, a) {
      ed.formulaBarExpanded = !ed.formulaBarExpanded;
      ed.notifyZoom();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.view.toggleGridlines',
    label: (l) => l.cmdViewToggleGridlines,
    icon: LucideIcons.grid3x3,
    categoryName: _view,
    mutates: true,
    checked: (ed, a) => ed.activeSheet?.record?.showGridlines ?? true,
    run: (ctx, ed, a) {
      final cur = ed.activeSheet?.record?.showGridlines ?? true;
      ed.apply(ctx, SetSheetProperties(ed.activeSheetId, showGridlines: !cur));
      return ok();
    },
  ),
  for (final viewing in [false, true])
    SheetsCommand(
      viewing ? 'sheets.mode.viewing' : 'sheets.mode.editing',
      label: (l) => viewing ? l.cmdModeViewing : l.cmdModeEditing,
      icon: viewing ? LucideIcons.eye : LucideIcons.pencil,
      categoryName: _view,
      checked: (ed, a) => ed.viewMode == viewing,
      enabled: (ed, a) => viewing || ed.roleCanEdit,
      run: (ctx, ed, a) {
        ed.viewMode = viewing;
        return ok();
      },
    ),
  SheetsCommand(
    'sheets.file.saveNoop',
    label: (l) => l.cmdFileSaveNoop,
    categoryName: (l) => l.categoryFile,
    keyScope: KeyScope.global,
    defaultBindings: const [KeyBinding('S', mod: true)],
    run: (ctx, ed, a) {
      s.toasts.show(ed.l10n.toastSavesAutomatically);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.stats.setShown',
    label: (l) => l.cmdStatsSetShown,
    categoryName: _view,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {
        'fn': JsonSchema.string(
          enumValues: [for (final f in SelectionStat.values) f.name],
        ),
      },
      required: const ['fn'],
    ),
    checked: (ed, a) =>
        a.string('fn') == null ? null : ed.shownStat?.name == a.string('fn'),
    run: (ctx, ed, a) {
      ed.shownStat = SelectionStat.values.byName(a.requireString('fn'));
      ed.notifyZoom();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.contextMenu.open',
    label: (l) => l.cmdContextMenuOpen,
    categoryName: _view,
    defaultBindings: const [KeyBinding('F10', shift: true)],
    run: (ctx, ed, a) {
      ed.openContextMenu?.call();
      return ok();
    },
  ),
  // Aliases of the shell's undo/redo (04 §3.2 ids; MCP).
  SheetsCommand(
    'sheets.edit.undo',
    label: (l) => l.cmdEditUndo,
    icon: LucideIcons.undo2,
    categoryName: (l) => l.categoryEditing,
    showInPalette: false,
    // Grid scope: while the grid has focus the hidden editor field holds
    // the primary focus, where the shell's global Mod+Z doesn't apply.
    defaultBindings: const [KeyBinding('Z', mod: true)],
    enabled: (ed, a) => s.undo.canUndo.value,
    run: (ctx, ed, a) async {
      final o = await s.undo.undo();
      return o == null
          ? const CommandResult.cancelled()
          : ok({'undone': o.step.label});
    },
  ),
  SheetsCommand(
    'sheets.edit.redo',
    label: (l) => l.cmdEditRedo,
    icon: LucideIcons.redo2,
    categoryName: (l) => l.categoryEditing,
    showInPalette: false,
    defaultBindings: const [
      KeyBinding('Z', mod: true, shift: true),
      KeyBinding('Y', mod: true, mac: false),
    ],
    enabled: (ed, a) => s.undo.canRedo.value,
    run: (ctx, ed, a) async {
      final o = await s.undo.redo();
      return o == null
          ? const CommandResult.cancelled()
          : ok({'redone': o.step.label});
    },
  ),
];
