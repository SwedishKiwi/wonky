import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../features/cell_editor/cell_editor_controller.dart' show EditMode;
import '../features/data_tools/goto_dialog.dart';
import '../features/formatting/sheets_user_defaults.dart';
import '../features/grid/selection/data_edge_finder.dart';
import '../features/grid/selection/grid_selection.dart';
import 'sheets_command.dart';

const _dirs = ['up', 'down', 'left', 'right'];

const _arrowKeys = {
  'up': Keys.arrowUp,
  'down': Keys.arrowDown,
  'left': Keys.arrowLeft,
  'right': Keys.arrowRight,
};

String _nav(SheetsLocalizations l) => l.categoryNavigation;

/// Navigation and selection commands (03 §7.1, §19).
List<Command<CommandArgs>> navCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.nav.move',
    label: (l) => l.cmdNavMove,
    categoryName: _nav,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'dir': JsonSchema.string(enumValues: _dirs),
        'extend': JsonSchema.boolean(),
        'toEdge': JsonSchema.boolean(),
      },
      required: ['dir'],
    ),
    argBindings: [
      for (final d in _dirs) ...[
        ArgsKeyBinding(KeyBinding(_arrowKeys[d]!), {'dir': d}),
        ArgsKeyBinding(KeyBinding(_arrowKeys[d]!, shift: true), {
          'dir': d,
          'extend': true,
        }),
        ArgsKeyBinding(KeyBinding(_arrowKeys[d]!, mod: true), {
          'dir': d,
          'toEdge': true,
        }),
        ArgsKeyBinding(KeyBinding(_arrowKeys[d]!, mod: true, shift: true), {
          'dir': d,
          'toEdge': true,
          'extend': true,
        }),
      ],
    ],
    run: (ctx, ed, a) {
      final d = NavDirection.tryParse(a.string('dir'));
      if (d == null) return const CommandResult.failed('Unknown direction');
      ed.moveActive(
        d,
        extend: a.boolean('extend') ?? false,
        toEdge: a.boolean('toEdge') ?? false,
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.tab',
    label: (l) => l.cmdNavTab,
    categoryName: _nav,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'reverse': JsonSchema.boolean()},
    ),
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.tab), {}),
      ArgsKeyBinding(KeyBinding(Keys.tab, shift: true), {'reverse': true}),
    ],
    run: (ctx, ed, a) {
      ed.tabMove(reverse: a.boolean('reverse') ?? false);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.enter',
    label: (l) => l.cmdNavEnter,
    categoryName: _nav,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'reverse': JsonSchema.boolean()},
    ),
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.enter), {}),
      ArgsKeyBinding(KeyBinding(Keys.enter, shift: true), {'reverse': true}),
    ],
    run: (ctx, ed, a) {
      final reverse = a.boolean('reverse') ?? false;
      // Settings › Sheets › Enter starts editing (per user, 03 §7.1); a
      // multi-cell selection keeps moving inside it.
      final sel = ed.selection.resolved;
      if (!reverse &&
          ed.canEdit &&
          !ed.editor.isEditing &&
          sel.ranges.length == 1 &&
          sel.activeRange.rect.rowCount * sel.activeRange.rect.colCount == 1 &&
          SheetsUserDefaults.of(ed.services).enterStartsEditing) {
        ed.editor.begin(mode: EditMode.edit);
        return ok();
      }
      ed.enterMove(reverse: reverse);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.rowStart',
    label: (l) => l.cmdNavRowStart,
    categoryName: _nav,
    argsSchema: _extendSchema,
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.home), {}),
      ArgsKeyBinding(KeyBinding(Keys.home, shift: true), {'extend': true}),
    ],
    run: (ctx, ed, a) {
      final r = ed.selection.resolved;
      ed.jumpTo(r.activeRow, 0, extend: a.boolean('extend') ?? false);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.rowEnd',
    label: (l) => l.cmdNavRowEnd,
    categoryName: _nav,
    argsSchema: _extendSchema,
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.end), {}),
      ArgsKeyBinding(KeyBinding(Keys.end, shift: true), {'extend': true}),
    ],
    run: (ctx, ed, a) {
      final r = ed.selection.resolved;
      final col = ed.edgeFinder().rowEnd(r.activeRow);
      ed.jumpTo(r.activeRow, col, extend: a.boolean('extend') ?? false);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.sheetStart',
    label: (l) => l.cmdNavSheetStart,
    categoryName: _nav,
    argsSchema: _extendSchema,
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.home, mod: true), {}),
      ArgsKeyBinding(KeyBinding(Keys.home, mod: true, shift: true), {
        'extend': true,
      }),
    ],
    run: (ctx, ed, a) {
      ed.jumpTo(0, 0, extend: a.boolean('extend') ?? false);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.sheetEnd',
    label: (l) => l.cmdNavSheetEnd,
    categoryName: _nav,
    argsSchema: _extendSchema,
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.end, mod: true), {}),
      ArgsKeyBinding(KeyBinding(Keys.end, mod: true, shift: true), {
        'extend': true,
      }),
    ],
    run: (ctx, ed, a) {
      final (r, c) = ed.edgeFinder().lastUsed();
      ed.jumpTo(r, c, extend: a.boolean('extend') ?? false);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.page',
    label: (l) => l.cmdNavPage,
    categoryName: _nav,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'dir': JsonSchema.string(enumValues: ['up', 'down']),
      },
      required: ['dir'],
    ),
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.pageUp), {'dir': 'up'}),
      ArgsKeyBinding(KeyBinding(Keys.pageDown), {'dir': 'down'}),
    ],
    run: (ctx, ed, a) {
      ed.page(a.string('dir') == 'up' ? NavDirection.up : NavDirection.down);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.pageHorizontal',
    label: (l) => l.cmdNavPageHorizontal,
    categoryName: _nav,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'dir': JsonSchema.string(enumValues: ['left', 'right']),
      },
      required: ['dir'],
    ),
    argBindings: const [
      ArgsKeyBinding(KeyBinding(Keys.pageUp, alt: true), {'dir': 'left'}),
      ArgsKeyBinding(KeyBinding(Keys.pageDown, alt: true), {'dir': 'right'}),
    ],
    run: (ctx, ed, a) {
      ed.page(
        a.string('dir') == 'left' ? NavDirection.left : NavDirection.right,
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.scrollToActive',
    label: (l) => l.cmdNavScrollToActive,
    categoryName: _nav,
    defaultBindings: const [KeyBinding(Keys.backspace, mod: true)],
    run: (ctx, ed, a) {
      ed.revealActive();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.nav.goTo',
    label: (l) => l.cmdNavGoTo,
    icon: LucideIcons.locateFixed,
    categoryName: _nav,
    keyScope: KeyScope.global,
    argsSchema: const JsonSchema.object(
      properties: {
        'target': JsonSchema.string(
          description: 'A1 cell/range, Sheet!A1 or a named range.',
        ),
      },
    ),
    defaultBindings: const [KeyBinding('G', mod: true, alt: true)],
    run: (ctx, ed, a) async {
      var t = a.string('target');
      if (t == null && !ed.showFormulaBar) {
        // No name box: the Go to range dialog (04 §11.18).
        final context = ctx.dialogContext;
        if (context == null) return const CommandResult.cancelled();
        t = await showGoToDialog(
          context,
          isValid: (x) {
            try {
              ed.model.parseA1(x, contextSheetId: ed.activeSheetId);
              return true;
            } on Exception {
              return false;
            }
          },
        );
        if (t == null) return const CommandResult.cancelled();
      }
      if (t == null) {
        ed.nameBoxFocus.requestFocus();
        return ok();
      }
      return ed.goTo(t)
          ? ok({'selection': ed.selection.describe()})
          : CommandResult.failed(ed.l10n.toastInvalidRange(t));
    },
  ),
  // ---- Selection ----
  SheetsCommand(
    'sheets.select.range',
    label: (l) => l.cmdSelectRange,
    categoryName: _nav,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'a1': JsonSchema.string(
          description: 'A1 range(s); several ranges separated by commas.',
        ),
      },
      required: ['a1'],
    ),
    run: (ctx, ed, a) {
      final parts = a.requireString('a1').split(',');
      final ranges = <(SelectionKind, GridRect)>[];
      String? sheet;
      for (final p in parts) {
        final rr = ed.model.parseA1(p.trim(), contextSheetId: ed.activeSheetId);
        sheet ??= rr.sheetId;
        if (rr.sheetId != sheet) continue;
        ranges.add((
          rr.wholeSheet
              ? SelectionKind.all
              : rr.wholeRows
              ? SelectionKind.rows
              : rr.wholeColumns
              ? SelectionKind.columns
              : SelectionKind.cells,
          rr.rect,
        ));
      }
      if (ranges.isEmpty) return const CommandResult.failed('Empty range');
      if (sheet != ed.activeSheetId) ed.activateSheet(sheet!);
      ed.selection.setRanges(ranges);
      ed.revealActive();
      return ok({'selection': ed.selection.describe()});
    },
  ),
  SheetsCommand(
    'sheets.select.all',
    label: (l) => l.cmdSelectAll,
    icon: LucideIcons.squareDashed,
    categoryName: _nav,
    defaultBindings: const [KeyBinding('A', mod: true)],
    run: (ctx, ed, a) {
      final r = ed.selection.resolved;
      final region = ed.edgeFinder().region(r.activeRow, r.activeCol);
      final current = r.ranges.length == 1 ? r.ranges.first.rect : null;
      if (region != null &&
          current != region &&
          r.activeRange.kind == SelectionKind.cells) {
        ed.selection.setRanges(
          [(SelectionKind.cells, region)],
          activeRow: r.activeRow,
          activeCol: r.activeCol,
        );
      } else {
        ed.selection.selectAll();
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.select.dataRegion',
    label: (l) => l.cmdSelectDataRegion,
    categoryName: _nav,
    run: (ctx, ed, a) {
      final r = ed.selection.resolved;
      final region = ed.edgeFinder().region(r.activeRow, r.activeCol);
      if (region == null) return const CommandResult.cancelled();
      ed.selection.setRanges(
        [(SelectionKind.cells, region)],
        activeRow: r.activeRow,
        activeCol: r.activeCol,
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.select.rows',
    label: (l) => l.cmdSelectRows,
    categoryName: _nav,
    defaultBindings: const [KeyBinding(Keys.space, shift: true)],
    run: (ctx, ed, a) {
      final r = ed.selection.resolved;
      final rect = r.activeRange.rect;
      if (r.activeRange.kind == SelectionKind.columns) {
        ed.selection.selectAll();
      } else {
        ed.selection.selectRows(rect.top, rect.bottom, activeCol: r.activeCol);
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.select.columns',
    label: (l) => l.cmdSelectColumns,
    categoryName: _nav,
    defaultBindings: const [
      KeyBinding(Keys.space, mod: true, mac: false),
      KeyBinding(Keys.space, ctrl: true, mac: true),
    ],
    run: (ctx, ed, a) {
      final r = ed.selection.resolved;
      final rect = r.activeRange.rect;
      if (r.activeRange.kind == SelectionKind.rows) {
        ed.selection.selectAll();
      } else {
        ed.selection.selectColumns(
          rect.left,
          rect.right,
          activeRow: r.activeRow,
        );
      }
      return ok();
    },
  ),
];

const _extendSchema = JsonSchema.object(
  properties: {'extend': JsonSchema.boolean()},
);
