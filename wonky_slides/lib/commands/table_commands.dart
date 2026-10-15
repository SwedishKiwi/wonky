import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext, IconData;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart'
    show ElementCols, SlidesCols, TableCellCols;

import '../features/canvas/canvas_interactions.dart';
import '../features/canvas/slide_canvas_controller.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/elements/element_activation.dart';
import '../features/elements/table/table_cells.dart';
import '../features/format_painter/format_painter.dart';
import '../features/elements/table/table_interaction.dart';
import '../features/text_editing/text_editing_host.dart';
import '../features/text_editing/text_format.dart';
import '../l10n/slides_l10n.dart';
import 'slides_command.dart';

/// The table commands of SL-15 (Slides 03 §6.6, 04 §4.4, §4.5, §11.4):
/// insert with a size, rows and columns (insert, delete, distribute,
/// resize), merges, table options, cell fill, borders, vertical align and
/// padding, and the `slidesTable` scope (cell range selection, Tab /
/// arrows, Enter edits, Delete clears). Commands act on the cell selection
/// (or the cell being edited, or explicit `row`/`column` args), else on
/// the whole table. Each mutating command is one undo step.
List<Command<CommandArgs>> tableCommands(ShellServices s) {
  CanvasInteractions.register(TableCanvasMode.new);
  ElementActivations.register(_tableActivation);
  SlideTextEditing.cellKeys = _cellKeys;
  SlideTextEditing.onCellExit = _cellExit;
  SlideTextEditing.activeCellOf = (ed, id) {
    final cells = TableCellSelection.of(ed);
    return cells.tableId == id ? cells.focus : null;
  };
  TextFormatScope.tableCells = _formatCells;
  ElementStylePayload.textCellOf = (ed, id) {
    final host = textEditingOf(ed);
    return host.elementId == id ? host.cell : null;
  };
  return [
    SlidesCommand(
      'slides.insert.table',
      label: (l) => l.cmdInsertTable,
      icon: LucideIcons.table,
      categoryOf: SlidesCategory.insert,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'rows': JsonSchema.integer(description: '1…50'),
          'cols': JsonSchema.integer(description: '1…20'),
          'x': JsonSchema.number(),
          'y': JsonSchema.number(),
          'width': JsonSchema.number(),
        },
      ),
      enabled: (ed, a) => ed.currentSlideId != null,
      reason: (l, ed) => l.reasonNoSlides,
      run: (ctx, ed, a) async {
        var rows = a.integer('rows'), cols = a.integer('cols');
        if (rows == null || cols == null) {
          final dc = ctx.dialogContext;
          if (dc == null || ctx.source.isAgent) {
            return const CommandResult.failed('rows and cols are required');
          }
          final size = await _askSize(dc);
          if (size == null) return const CommandResult.cancelled();
          (rows, cols) = size;
        }
        return _insertTable(ctx, ed, a, rows, cols);
      },
    ),
    _tableCommand(
      'slides.table.insertRow',
      (l) => l.cmdTableInsertRow,
      LucideIcons.rows3,
      extra: const {
        'below': JsonSchema.boolean(description: 'Below (default) or above.'),
        'count': JsonSchema.integer(),
      },
      run: (ctx, ed, t, a) {
        final below = a.boolean('below') ?? (a.string('position') != 'above');
        final index = below ? t.range.r1 + 1 : t.range.r0;
        ed.apply(
          ctx,
          InsertTableAxes(
            t.id,
            TableAxisDimension.row,
            index,
            count: math.max(1, a.integer('count') ?? 1),
          ),
        );
        return ok({'index': index});
      },
    ),
    _tableCommand(
      'slides.table.insertColumn',
      (l) => l.cmdTableInsertColumn,
      LucideIcons.columns3,
      extra: const {
        'right': JsonSchema.boolean(description: 'Right (default) or left.'),
        'count': JsonSchema.integer(),
      },
      run: (ctx, ed, t, a) {
        final right = a.boolean('right') ?? (a.string('position') != 'left');
        final index = right ? t.range.c1 + 1 : t.range.c0;
        ed.apply(
          ctx,
          InsertTableAxes(
            t.id,
            TableAxisDimension.column,
            index,
            count: math.max(1, a.integer('count') ?? 1),
          ),
        );
        return ok({'index': index});
      },
    ),
    _tableCommand(
      'slides.table.deleteRows',
      (l) => l.cmdTableDeleteRows,
      LucideIcons.trash2,
      needsCells: true,
      run: (ctx, ed, t, a) {
        final ids = [
          for (var r = t.range.r0; r <= t.range.r1; r++) t.ix.rows[r].id,
        ];
        if (ids.length >= t.ix.rows.length) {
          ed.apply(ctx, DeleteElements([t.id]));
          return ok({'deletedTable': true});
        }
        TableCellSelection.of(ed).clear();
        ed.apply(ctx, DeleteTableAxes(t.id, ids));
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.deleteColumns',
      (l) => l.cmdTableDeleteColumns,
      LucideIcons.trash2,
      needsCells: true,
      run: (ctx, ed, t, a) {
        final ids = [
          for (var c = t.range.c0; c <= t.range.c1; c++) t.ix.columns[c].id,
        ];
        if (ids.length >= t.ix.columns.length) {
          ed.apply(ctx, DeleteElements([t.id]));
          return ok({'deletedTable': true});
        }
        TableCellSelection.of(ed).clear();
        ed.apply(ctx, DeleteTableAxes(t.id, ids));
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.delete',
      (l) => l.cmdTableDelete,
      LucideIcons.trash,
      run: (ctx, ed, t, a) {
        TableCellSelection.of(ed).clear();
        ed.apply(ctx, DeleteElements([t.id]));
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.mergeCells',
      (l) => l.cmdTableMergeCells,
      LucideIcons.tableCellsMerge,
      needsCells: true,
      enabled: (t) => !t.range.isSingleCell(t.ix),
      reason: (l) => l.reasonSelectCells,
      run: (ctx, ed, t, a) {
        final r = t.range;
        ed.apply(
          ctx,
          MergeCells(
            t.id,
            rowId: t.ix.rows[r.r0].id,
            columnId: t.ix.columns[r.c0].id,
            rowSpan: r.rows,
            colSpan: r.columns,
          ),
        );
        TableCellSelection.of(ed).selectAt(t.id, r.r0, r.c0);
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.unmergeCells',
      (l) => l.cmdTableUnmergeCells,
      LucideIcons.tableCellsSplit,
      enabled: (t) => _mergesIn(t).isNotEmpty,
      reason: (l) => l.reasonNoMergedCells,
      run: (ctx, ed, t, a) {
        ed.apply(
          ctx,
          UnmergeCells(t.id, [for (final m in _mergesIn(t)) m.origin.id]),
        );
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.distributeRows',
      (l) => l.cmdTableDistributeRows,
      LucideIcons.alignVerticalDistributeCenter,
      run: (ctx, ed, t, a) {
        final heights = _rowHeights(ed, t);
        final r = t.rangeOrAll;
        final avg =
            [
              for (var i = r.r0; i <= r.r1; i++) heights[i],
            ].reduce((x, y) => x + y) /
            r.rows;
        ed.apply(
          ctx,
          ResizeTableAxes(t.id, {
            for (var i = r.r0; i <= r.r1; i++) t.ix.rows[i].id: _round(avg),
          }),
        );
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.distributeColumns',
      (l) => l.cmdTableDistributeColumns,
      LucideIcons.alignHorizontalDistributeCenter,
      run: (ctx, ed, t, a) {
        final widths = _columnWidths(ed, t);
        final r = t.rangeOrAll;
        final avg =
            [
              for (var i = r.c0; i <= r.c1; i++) widths[i],
            ].reduce((x, y) => x + y) /
            r.columns;
        ed.apply(
          ctx,
          ResizeTableAxes(t.id, {
            for (var i = 0; i < t.ix.columns.length; i++)
              t.ix.columns[i].id: _round(
                i >= r.c0 && i <= r.c1 ? avg : widths[i],
              ),
          }),
        );
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.resizeAxes',
      (l) => l.cmdTableResizeAxes,
      LucideIcons.moveHorizontal,
      showInPalette: false,
      extra: const {
        'sizes': JsonSchema.object(
          description:
              'Axis id → size in su (null = even split): column widths '
              '(proportions scaled to the table width) or minimum row '
              'heights.',
          additionalProperties: true,
        ),
      },
      run: (ctx, ed, t, a) {
        final raw = a.values['sizes'];
        if (raw is! Map || raw.isEmpty) {
          return const CommandResult.failed('sizes is required');
        }
        ed.apply(
          ctx,
          ResizeTableAxes(t.id, {
            for (final e in raw.entries)
              '${e.key}': e.value is num ? (e.value as num).toDouble() : null,
          }),
        );
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.setOptions',
      (l) => l.cmdTableSetOptions,
      LucideIcons.tableProperties,
      extra: const {
        'style': JsonSchema.string(enumValues: ['theme', 'none']),
        'headerRow': JsonSchema.boolean(),
        'firstColumn': JsonSchema.boolean(),
        'bandedRows': JsonSchema.boolean(),
        'bandedColumns': JsonSchema.boolean(),
        'totalRow': JsonSchema.boolean(),
        'cellPadding': JsonSchema.array(
          JsonSchema.number(),
          description: 'Default cell padding [t, r, b, l] (su).',
        ),
      },
      run: (ctx, ed, t, a) {
        const keys = [
          'headerRow',
          'firstColumn',
          'bandedRows',
          'bandedColumns',
          'totalRow',
        ];
        final style = a.string('style');
        final pad = a.values['cellPadding'];
        final options = {
          for (final k in keys)
            if (a.boolean(k) != null) k: a.boolean(k),
        };
        if (style == null && pad == null && options.isEmpty) {
          if (ctx.source.isAgent) {
            return const CommandResult.failed('No option given');
          }
          ed.openInspector(InspectorTab.format, section: 'table');
          return ok({'opened': 'inspector'});
        }
        ed.apply(
          ctx,
          SetTableOptions(t.id, {
            'style': ?style,
            if (options.isNotEmpty) 'options': options,
            if (pad is List && pad.length == 4 && pad.every((v) => v is num))
              'defaultCellPadding': [
                for (final v in pad) (v as num).toDouble(),
              ],
          }),
        );
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.setCellFill',
      (l) => l.cmdTableSetCellFill,
      LucideIcons.paintBucket,
      extra: const {
        'color': JsonSchema.string(
          description: 'ColorRef (`theme:accent1`, `#RRGGBB`).',
        ),
        'none': JsonSchema.boolean(
          description: 'Removes the cell fill (back to the table style).',
        ),
      },
      run: (ctx, ed, t, a) {
        final color = a.string('color');
        final none = a.boolean('none') ?? false;
        if (color == null && !none) {
          if (ctx.source.isAgent) {
            return const CommandResult.failed('color is required');
          }
          ed.openInspector(InspectorTab.format, section: 'cell');
          return ok({'opened': 'inspector'});
        }
        _writeCells(ctx, ed, t, {TableCellCols.fill: none ? null : color});
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.setBorders',
      (l) => l.cmdTableSetBorders,
      LucideIcons.grid3x3,
      extra: {
        'edges': const JsonSchema.string(enumValues: borderEdges),
        'width': const JsonSchema.number(description: 'su (default 1)'),
        'style': const JsonSchema.string(
          enumValues: ['solid', 'dashed', 'dotted'],
        ),
        'color': const JsonSchema.string(description: 'ColorRef'),
      },
      run: (ctx, ed, t, a) {
        final edges = a.string('edges');
        if (edges == null) {
          if (ctx.source.isAgent) {
            return const CommandResult.failed('edges is required');
          }
          ed.openInspector(InspectorTab.format, section: 'cell');
          return ok({'opened': 'inspector'});
        }
        final width = (_num(a, 'width') ?? 1).clamp(0.25, 24);
        final value =
            '${_fmt(width.toDouble())}|${a.string('style') ?? 'solid'}|'
            '${a.string('color') ?? 'theme:text1'}';
        final writes = borderWrites(t.ix, t.rangeOrAll, edges, value);
        if (writes.isEmpty) return ok();
        ed.apply(ctx, SetCells(t.id, writes));
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.setCellAlign',
      (l) => l.cmdTableSetCellAlign,
      LucideIcons.alignVerticalJustifyCenter,
      extra: const {
        'vAlign': JsonSchema.string(enumValues: ['top', 'middle', 'bottom']),
      },
      run: (ctx, ed, t, a) {
        final v = a.string('vAlign');
        if (v == null) {
          if (ctx.source.isAgent) {
            return const CommandResult.failed('vAlign is required');
          }
          ed.openInspector(InspectorTab.format, section: 'cell');
          return ok({'opened': 'inspector'});
        }
        _writeCells(ctx, ed, t, {TableCellCols.vAlign: v == 'top' ? null : v});
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.setCellPadding',
      (l) => l.cmdTableSetCellPadding,
      LucideIcons.squareDashed,
      extra: const {
        'padding': JsonSchema.array(
          JsonSchema.number(),
          description: '[t, r, b, l] in su; omit to reset.',
        ),
        'all': JsonSchema.number(description: 'One value for every side.'),
      },
      run: (ctx, ed, t, a) {
        final all = _num(a, 'all');
        final raw = a.values['padding'];
        String? value;
        if (all != null) {
          final v = _fmt(all.clamp(0, 200).toDouble());
          value = '$v,$v,$v,$v';
        } else if (raw is List &&
            raw.length == 4 &&
            raw.every((v) => v is num)) {
          value = [
            for (final v in raw) _fmt((v as num).toDouble().clamp(0, 200)),
          ].join(',');
        }
        _writeCells(ctx, ed, t, {TableCellCols.padding: value});
        return ok();
      },
    ),
    _tableCommand(
      'slides.table.clearCells',
      (l) => l.cmdTableClearCells,
      LucideIcons.eraser,
      needsCells: true,
      keyScope: SlidesKeyScopes.table,
      bindings: const [KeyBinding('Delete'), KeyBinding('Backspace')],
      run: (ctx, ed, t, a) {
        _writeCells(ctx, ed, t, {SlidesCols.text: null});
        return ok();
      },
    ),

    // ---- Cell selection and navigation (view state, `slidesTable`)
    SlidesCommand(
      'slides.table.selectCells',
      label: (l) => l.cmdTableSelectCells,
      icon: LucideIcons.tableCellsMerge,
      categoryOf: SlidesCategory.tables,
      showInPalette: false,
      argsSchema: _rangeSchema(const {}),
      enabled: (ed, a) => _target(ed, a) != null,
      reason: (l, ed) => l.reasonSelectTable,
      run: (ctx, ed, a) {
        final t = _target(ed, a)!;
        final r = t.rangeOrAll;
        selectionOf(ed).select([t.id]);
        final cells = TableCellSelection.of(ed);
        cells.selectAt(t.id, r.r0, r.c0);
        cells.selectAt(t.id, r.r1, r.c1, extend: true);
        ed.canvasFocus.requestFocus();
        return ok({
          'row': r.r0,
          'column': r.c0,
          'rows': r.rows,
          'columns': r.columns,
        });
      },
    ),
    for (final (id, dx, dy, extend, key) in _moves)
      SlidesCommand(
        id,
        label: (l) => l.cmdTableMoveSelection,
        categoryOf: SlidesCategory.tables,
        keyScope: SlidesKeyScopes.table,
        showInPalette: false,
        defaultBindings: [key],
        enabled: (ed, a) => !TableCellSelection.of(ed).isEmpty,
        run: (ctx, ed, a) {
          _moveSelection(ed, dx, dy, extend: extend);
          return ok();
        },
      ),
    SlidesCommand(
      'slides.table.nextCell',
      label: (l) => l.cmdTableNextCell,
      categoryOf: SlidesCategory.tables,
      keyScope: SlidesKeyScopes.table,
      showInPalette: false,
      defaultBindings: const [KeyBinding('Tab')],
      enabled: (ed, a) => !TableCellSelection.of(ed).isEmpty,
      run: (ctx, ed, a) {
        _stepCell(ed, 1);
        return ok();
      },
    ),
    SlidesCommand(
      'slides.table.previousCell',
      label: (l) => l.cmdTablePreviousCell,
      categoryOf: SlidesCategory.tables,
      keyScope: SlidesKeyScopes.table,
      showInPalette: false,
      defaultBindings: const [KeyBinding('Tab', shift: true)],
      enabled: (ed, a) => !TableCellSelection.of(ed).isEmpty,
      run: (ctx, ed, a) {
        _stepCell(ed, -1);
        return ok();
      },
    ),
    SlidesCommand(
      'slides.table.editCell',
      label: (l) => l.cmdTableEditCell,
      icon: LucideIcons.textCursorInput,
      categoryOf: SlidesCategory.tables,
      keyScope: SlidesKeyScopes.table,
      defaultBindings: const [KeyBinding('Enter')],
      argsSchema: _rangeSchema(const {}),
      enabled: (ed, a) => _editTarget(ed, a) != null,
      reason: (l, ed) => l.reasonSelectTable,
      run: (ctx, ed, a) async {
        final (id, cell) = _editTarget(ed, a)!;
        TableCellSelection.of(ed).clear();
        final started = await textEditingOf(ed).begin(id, cell: cell);
        return started
            ? ok({
                'editing': id,
                'rowId': cell.rowId,
                'columnId': cell.columnId,
              })
            : const CommandResult.cancelled();
      },
    ),
    SlidesCommand(
      'slides.table.clearCellSelection',
      label: (l) => l.cmdTableClearCellSelection,
      categoryOf: SlidesCategory.tables,
      keyScope: SlidesKeyScopes.table,
      showInPalette: false,
      defaultBindings: const [KeyBinding('Escape')],
      enabled: (ed, a) => !TableCellSelection.of(ed).isEmpty,
      run: (ctx, ed, a) {
        TableCellSelection.of(ed).clear();
        return ok();
      },
    ),
  ];
}

// ---------------------------------------------------------------- target

/// The table a command acts on and its range.
class _Target {
  _Target(this.table, this.ix, this.range, {required this.explicit});

  final ResolvedElement table;
  final TableIndex ix;

  /// The cells: args, the cell selection or the cell being edited; else
  /// the whole table.
  final TableRange range;

  /// Whether [range] came from args, a selection or editing.
  final bool explicit;

  String get id => table.id;

  TableRange get rangeOrAll => range;
}

ResolvedElement? _find(List<ResolvedElement> list, String id) {
  for (final e in list) {
    if (e.id == id) return e;
    final c = _find(e.children, id);
    if (c != null) return c;
  }
  return null;
}

_Target? _target(DeckEditorController ed, JsonArgs a) {
  final slide = ed.currentSlideId;
  final resolved = slide == null ? null : ed.resolver.resolve(slide);
  if (resolved == null) return null;
  final text = textEditingOf(ed);
  final id =
      a.string('id') ??
      (ed.selectedElementIds.length == 1
          ? ed.selectedElementIds.single
          : null) ??
      (text.cell != null ? text.elementId : null);
  if (id == null) return null;
  final e = _find(resolved.elements, id);
  if (e == null || e.record.kind != ElementKind.table) return null;
  final ix = ed.model.indexes.table(id);
  final all = TableRange.all(ix);
  if (all == null) return null;
  final row = a.integer('row'), col = a.integer('column');
  if (row != null || col != null) {
    final r = (row ?? 0).clamp(0, ix.rows.length - 1);
    final c = (col ?? 0).clamp(0, ix.columns.length - 1);
    final r1 = (r + (a.integer('rowSpan') ?? 1) - 1).clamp(
      r,
      ix.rows.length - 1,
    );
    final c1 = (c + (a.integer('colSpan') ?? 1) - 1).clamp(
      c,
      ix.columns.length - 1,
    );
    return _Target(
      e,
      ix,
      TableRange.spanning(ix, r, c, r1, c1),
      explicit: true,
    );
  }
  final sel = TableCellSelection.of(ed);
  final range = sel.tableId == id ? sel.range : null;
  if (range != null) return _Target(e, ix, range, explicit: true);
  final cell = text.elementId == id ? text.cell : null;
  if (cell != null) {
    final p = TableCellSelection.indexOf(ix, cell);
    if (p != null) {
      return _Target(
        e,
        ix,
        TableRange.spanning(ix, p.$1, p.$2, p.$1, p.$2),
        explicit: true,
      );
    }
  }
  return _Target(e, ix, all, explicit: false);
}

JsonSchema _rangeSchema(Map<String, JsonSchema> extra) => JsonSchema.object(
  properties: {
    'id': const JsonSchema.string(
      description: 'Table element id (default: the selected table).',
    ),
    'row': const JsonSchema.integer(
      description:
          'First row of the cell range (0-based; default: the cell '
          'selection, else the whole table).',
    ),
    'column': const JsonSchema.integer(description: 'First column (0-based).'),
    'rowSpan': const JsonSchema.integer(),
    'colSpan': const JsonSchema.integer(),
    ...extra,
  },
);

SlidesCommand _tableCommand(
  String id,
  SlidesText label,
  IconData icon, {
  required CommandResult Function(
    CommandContext ctx,
    DeckEditorController ed,
    _Target t,
    JsonArgs a,
  )
  run,
  Map<String, JsonSchema> extra = const {},
  bool needsCells = false,
  bool Function(_Target t)? enabled,
  SlidesText? reason,
  bool showInPalette = true,
  KeyScope keyScope = KeyScope.global,
  List<KeyBinding> bindings = const [],
}) => SlidesCommand(
  id,
  label: label,
  icon: icon,
  categoryOf: SlidesCategory.tables,
  mutates: true,
  showInPalette: showInPalette,
  keyScope: keyScope,
  defaultBindings: bindings,
  argsSchema: _rangeSchema(extra),
  enabled: (ed, a) {
    final t = _target(ed, a);
    if (t == null || t.table.locked) return false;
    if (needsCells && !t.explicit) return false;
    return enabled?.call(t) ?? true;
  },
  reason: (l, ed) {
    final t = _target(ed, const JsonArgs());
    if (t == null) return l.reasonSelectTable;
    if (t.table.locked) return l.reasonObjectLocked;
    if (needsCells && !t.explicit) return l.reasonSelectCells;
    return reason?.call(l) ?? l.reasonSelectTable;
  },
  run: (ctx, ed, a) {
    final t = _target(ed, a);
    if (t == null) {
      return CommandResult.failed(slidesL10nOf(ed.services).reasonSelectTable);
    }
    // Pending typing in a cell is its own step first.
    textEditingOf(ed).commit();
    return run(ctx, ed, t, a);
  },
);

double? _num(JsonArgs a, String k) {
  final v = a.values[k];
  return v is num ? v.toDouble() : null;
}

double _round(double v) => (v * 100).roundToDouble() / 100;

String _fmt(double v) {
  final r = _round(v);
  return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
}

List<TableMerge> _mergesIn(_Target t) => [
  for (final m in t.ix.merges)
    if (t.range.contains(m.row, m.column)) m,
];

/// Writes [columns] on every visible cell of the target range.
void _writeCells(
  CommandContext ctx,
  DeckEditorController ed,
  _Target t,
  Map<String, Object?> columns,
) {
  final writes = [
    for (final c in t.rangeOrAll.cells(t.ix))
      CellWrite(c.rowId, c.columnId, columns),
  ];
  if (writes.isNotEmpty) ed.apply(ctx, SetCells(t.id, writes));
}

/// Laid-out row heights (the canvas grid), else the stored minimums.
List<double> _rowHeights(DeckEditorController ed, _Target t) {
  final canvas = SlideCanvasController.of(ed);
  final grid = canvas == null ? null : TableGeometry.gridOf(canvas, t.id);
  if (grid != null && grid.rows == t.ix.rows.length) {
    return [
      for (var i = 0; i < grid.rows; i++) grid.rowY[i + 1] - grid.rowY[i],
    ];
  }
  final h = t.table.frame.height / t.ix.rows.length;
  return [for (final r in t.ix.rows) r.size ?? h];
}

/// Laid-out column widths, else proportional to the stored sizes.
List<double> _columnWidths(DeckEditorController ed, _Target t) {
  final canvas = SlideCanvasController.of(ed);
  final grid = canvas == null ? null : TableGeometry.gridOf(canvas, t.id);
  if (grid != null && grid.columns == t.ix.columns.length) {
    return [
      for (var i = 0; i < grid.columns; i++)
        grid.columnX[i + 1] - grid.columnX[i],
    ];
  }
  final w = t.table.frame.width / t.ix.columns.length;
  return [for (final c in t.ix.columns) c.size ?? w];
}

/// The edges of `slides.table.setBorders` (03 §6.6 `TableBorderPicker`).
const borderEdges = [
  'all',
  'outer',
  'inner',
  'horizontal',
  'vertical',
  'top',
  'bottom',
  'left',
  'right',
  'none',
];

/// The cell writes that put border [value] (`"width|style|color"`) on
/// [edges] of [range] (`none` clears the cell borders of the range, back to
/// the table style). Shared edges are written on one side only: inner
/// horizontal edges on the lower cell's top, inner vertical edges on the
/// right cell's left.
List<CellWrite> borderWrites(
  TableIndex ix,
  TableRange range,
  String edges,
  String value,
) {
  final out = <CellWrite>[];
  for (final c in range.cells(ix)) {
    final m = ix.mergeAt(c.row, c.column);
    final rLast = c.row + (m?.rowSpan ?? 1) - 1;
    final cLast = c.column + (m?.colSpan ?? 1) - 1;
    final top = c.row == range.r0, bottom = rLast == range.r1;
    final left = c.column == range.c0, right = cLast == range.c1;
    final cols = <String, Object?>{};
    void put(String col) => cols[col] = value;
    switch (edges) {
      case 'none':
        cols
          ..[TableCellCols.borderTop] = null
          ..[TableCellCols.borderRight] = null
          ..[TableCellCols.borderBottom] = null
          ..[TableCellCols.borderLeft] = null;
      case 'all':
        put(TableCellCols.borderTop);
        put(TableCellCols.borderLeft);
        if (bottom) put(TableCellCols.borderBottom);
        if (right) put(TableCellCols.borderRight);
      case 'outer':
        if (top) put(TableCellCols.borderTop);
        if (bottom) put(TableCellCols.borderBottom);
        if (left) put(TableCellCols.borderLeft);
        if (right) put(TableCellCols.borderRight);
      case 'inner':
        if (!top) put(TableCellCols.borderTop);
        if (!left) put(TableCellCols.borderLeft);
      case 'horizontal':
        if (!top) put(TableCellCols.borderTop);
      case 'vertical':
        if (!left) put(TableCellCols.borderLeft);
      case 'top':
        if (top) put(TableCellCols.borderTop);
      case 'bottom':
        if (bottom) put(TableCellCols.borderBottom);
      case 'left':
        if (left) put(TableCellCols.borderLeft);
      case 'right':
        if (right) put(TableCellCols.borderRight);
    }
    if (cols.isNotEmpty) out.add(CellWrite(c.rowId, c.columnId, cols));
  }
  return out;
}

// ----------------------------------------------------------------- insert

Future<(int, int)?> _askSize(BuildContext context) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  String? valid(String v, int max) {
    final n = int.tryParse(v.trim());
    return n == null || n < 1 || n > max ? l.tableSizeInvalid(max) : null;
  }

  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.tableInsertDialogTitle,
      dialogKey: 'dialog.slides.insertTable',
      fields: [
        TextFieldSpec(
          id: 'rows',
          label: l.tableRows,
          initial: '3',
          validator: (v) => valid(v, 50),
        ),
        TextFieldSpec(
          id: 'cols',
          label: l.tableColumns,
          initial: '3',
          validator: (v) => valid(v, 20),
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(
          id: 'insert',
          label: l.dialogInsert,
          primary: true,
          validates: true,
        ),
      ],
    ),
  );
  if (r?.buttonId != 'insert') return null;
  return (int.parse(r!.text('rows').trim()), int.parse(r.text('cols').trim()));
}

/// Inserts a [rows] × [cols] table (03 §6.6): 80 % of the slide wide,
/// centered, rows as tall as one line of the theme's table text plus the
/// cell padding, the theme's table style with a header row and banded
/// rows. Selects it.
CommandResult _insertTable(
  CommandContext ctx,
  DeckEditorController ed,
  JsonArgs a,
  int rows,
  int cols,
) {
  final slide = ed.currentSlideId;
  if (slide == null) return const CommandResult.failed('No slide');
  if (rows < 1 || cols < 1 || rows > 50 || cols > 20) {
    return const CommandResult.failed(
      'A table has 1–50 rows and 1–20 columns.',
    );
  }
  final d = ed.model.deck;
  final sw = d?.width ?? 1920, sh = d?.height ?? 1080;
  final theme = ed.resolver.resolve(slide)?.theme;
  final ts = theme?.tableStyle;
  final pad = ts?.cellPadding ?? const [12.0, 16.0, 12.0, 16.0];
  final text = theme?.textStyle(ts?.body.text?.style ?? 'body2');
  final line = (text?.size ?? 28) * (text?.lineHeight ?? 1.2);
  final rowH = _round(line + pad[0] + pad[2]);
  final w = _num(a, 'width') ?? _round(sw * 0.8);
  final h = rowH * rows;
  final x = _num(a, 'x') ?? _round((sw - w) / 2);
  final y = _num(a, 'y') ?? _round(math.max(0, (sh - h) / 2));
  final plan = ed.apply(
    ctx,
    InsertElements(slide, [
      ElementSpec(
        kind: ElementKind.table,
        x: x,
        y: y,
        width: w,
        height: h,
        tableRows: rows,
        tableColumns: cols,
        columns: {
          ElementCols.dataJson: jsonEncode({
            'v': 1,
            'style': 'theme',
            'options': {'headerRow': true, 'bandedRows': true},
          }),
        },
      ),
    ]),
  );
  final ids = plan.result['elementIds'];
  ed.armTool(null);
  final id = ids is List && ids.isNotEmpty ? ids.first as String : null;
  if (id != null) {
    selectionOf(ed).select([id]);
    ed.canvasFocus.requestFocus();
  }
  return ok({'elementId': id});
}

// ------------------------------------------------------------- navigation

const _moves = [
  ('slides.table.selectLeft', -1, 0, false, KeyBinding('ArrowLeft')),
  ('slides.table.selectRight', 1, 0, false, KeyBinding('ArrowRight')),
  ('slides.table.selectUp', 0, -1, false, KeyBinding('ArrowUp')),
  ('slides.table.selectDown', 0, 1, false, KeyBinding('ArrowDown')),
  (
    'slides.table.extendLeft',
    -1,
    0,
    true,
    KeyBinding('ArrowLeft', shift: true),
  ),
  (
    'slides.table.extendRight',
    1,
    0,
    true,
    KeyBinding('ArrowRight', shift: true),
  ),
  ('slides.table.extendUp', 0, -1, true, KeyBinding('ArrowUp', shift: true)),
  ('slides.table.extendDown', 0, 1, true, KeyBinding('ArrowDown', shift: true)),
];

/// Moves (or with [extend] grows) the cell selection by one visible cell.
void _moveSelection(
  DeckEditorController ed,
  int dx,
  int dy, {
  required bool extend,
}) {
  final cells = TableCellSelection.of(ed);
  final id = cells.tableId, f = cells.focus;
  if (id == null || f == null) return;
  final ix = ed.model.indexes.table(id);
  final p = TableCellSelection.indexOf(ix, f);
  if (p == null) return;
  var (r, c) = p;
  // Step over a merge the focus sits in.
  final m = ix.mergeAt(r, c);
  if (m != null) {
    if (dx > 0) c = m.column + m.colSpan - 1;
    if (dy > 0) r = m.row + m.rowSpan - 1;
    if (dx < 0) c = m.column;
    if (dy < 0) r = m.row;
  }
  r = (r + dy).clamp(0, ix.rows.length - 1);
  c = (c + dx).clamp(0, ix.columns.length - 1);
  final target = ix.mergeAt(r, c);
  if (target != null && !extend) (r, c) = (target.row, target.column);
  cells.selectAt(id, r, c, extend: extend);
}

/// The visible cells of table [ix] in reading order.
List<(int, int)> _order(TableIndex ix) {
  final out = <(int, int)>[];
  for (var r = 0; r < ix.rows.length; r++) {
    for (var c = 0; c < ix.columns.length; c++) {
      final m = ix.mergeAt(r, c);
      if (m == null || (m.row == r && m.column == c)) out.add((r, c));
    }
  }
  return out;
}

/// The visible cell [delta] steps from [cell] in reading order, or null at
/// either end.
(int, int)? _stepFrom(TableIndex ix, (int, int) cell, int delta) {
  final order = _order(ix);
  final m = ix.mergeAt(cell.$1, cell.$2);
  final at = order.indexOf(m == null ? cell : (m.row, m.column));
  final next = at + delta;
  if (at < 0 || next < 0 || next >= order.length) return null;
  return order[next];
}

/// Tab / Shift+Tab in the cell selection: the next / previous cell.
void _stepCell(DeckEditorController ed, int delta) {
  final cells = TableCellSelection.of(ed);
  final id = cells.tableId, f = cells.focus;
  if (id == null || f == null) return;
  final ix = ed.model.indexes.table(id);
  final p = TableCellSelection.indexOf(ix, f);
  if (p == null) return;
  final next = _stepFrom(ix, p, delta);
  if (next != null) cells.selectAt(id, next.$1, next.$2);
}

/// The cell `slides.table.editCell` / activation edits: args, the focus of
/// the cell selection, else the first cell.
(String, ({String rowId, String columnId}))? _editTarget(
  DeckEditorController ed,
  JsonArgs a,
) {
  final t = _target(ed, a);
  if (t == null || t.table.locked || !ed.canEdit) return null;
  final cells = TableCellSelection.of(ed);
  if (a.integer('row') == null &&
      a.integer('column') == null &&
      cells.tableId == t.id &&
      cells.focus != null) {
    return (t.id, cells.focus!);
  }
  final r = t.range;
  return (t.id, (rowId: t.ix.rows[r.r0].id, columnId: t.ix.columns[r.c0].id));
}

// --------------------------------------------------- text editing hooks

/// Double-click / Enter on a table (03 §3.4): edit the clicked cell (caret
/// at the click), or with Enter the focused or first cell.
final _tableActivation = ElementActivation(
  applies: (ed, a) {
    final ids = ed.selectedElementIds;
    if (ids.length != 1 || !ed.canEdit) return false;
    final e = ed.model.element(ids.single);
    return e != null && e.kind == ElementKind.table && !e.locked;
  },
  run: (ctx, ed, a) async {
    final id = ed.selectedElementIds.single;
    final x = _num(a, 'x'), y = _num(a, 'y');
    final canvas = SlideCanvasController.of(ed);
    ({String rowId, String columnId})? cell;
    Offset? at;
    if (x != null && y != null && canvas != null) {
      at = Offset(x, y);
      final hit = TableGeometry.cellAt(canvas, id, at);
      if (hit != null) cell = (rowId: hit.rowId, columnId: hit.columnId);
    }
    cell ??= _editTarget(ed, const JsonArgs())?.$2;
    if (cell == null) return const CommandResult.failed('Nothing to edit');
    TableCellSelection.of(ed).clear();
    final started = await textEditingOf(ed).begin(id, at: at, cell: cell);
    return started ? ok({'editing': id}) : const CommandResult.cancelled();
  },
);

/// Esc while editing a cell: the cell becomes the cell selection.
void _cellExit(
  SlideTextEditing host,
  String elementId,
  String rowId,
  String columnId,
) {
  host.end();
  TableCellSelection.of(
    host.editor,
  ).select(elementId, (rowId: rowId, columnId: columnId));
}

/// Keys of a cell being edited (03 §6.6): Tab / Shift+Tab edit the next /
/// previous cell (Tab in the last cell adds a row), arrows at the start or
/// end of the text move to the neighbor cell.
bool _cellKeys(SlideTextEditing host, KeyEvent e) {
  final cell = host.cell;
  final id = host.elementId;
  final c = host.active;
  if (cell == null || id == null || c == null) return false;
  final k = HardwareKeyboard.instance;
  if (k.isMetaPressed || k.isControlPressed || k.isAltPressed) return false;
  final ed = host.editor;
  final ix = ed.model.indexes.table(id);
  final p = TableCellSelection.indexOf(ix, cell);
  if (p == null) return false;
  final key = e.logicalKey;
  (int, int)? next;
  var addRow = false;
  if (key == LogicalKeyboardKey.tab) {
    next = _stepFrom(ix, p, k.isShiftPressed ? -1 : 1);
    if (next == null && !k.isShiftPressed) addRow = true;
    if (next == null && !addRow) return true;
  } else if (!k.isShiftPressed) {
    final sel = c.selectionRange;
    final len = c.json.isEmpty ? 0 : _plainLength(c.json);
    final atStart = sel != null && sel.$1 == 0 && sel.$2 == 0;
    final atEnd = sel != null && sel.$1 == sel.$2 && sel.$2 >= len;
    final firstPara = sel != null && !_hasBreakBefore(c.json, sel.$1);
    final lastPara = sel != null && !_hasBreakAfter(c.json, sel.$2);
    final m = ix.mergeAt(p.$1, p.$2);
    final r0 = m?.row ?? p.$1, c0 = m?.column ?? p.$2;
    final r1 = r0 + (m?.rowSpan ?? 1) - 1, c1 = c0 + (m?.colSpan ?? 1) - 1;
    if (key == LogicalKeyboardKey.arrowLeft && atStart && c0 > 0) {
      next = (r0, c0 - 1);
    } else if (key == LogicalKeyboardKey.arrowRight &&
        atEnd &&
        c1 < ix.columns.length - 1) {
      next = (r0, c1 + 1);
    } else if (key == LogicalKeyboardKey.arrowUp && firstPara && r0 > 0) {
      next = (r0 - 1, c0);
    } else if (key == LogicalKeyboardKey.arrowDown &&
        lastPara &&
        r1 < ix.rows.length - 1) {
      next = (r1 + 1, c0);
    }
  }
  if (next == null && !addRow) return false;
  unawaited(
    _editNext(
      host,
      id,
      next,
      addRow: addRow,
      toEnd: key == LogicalKeyboardKey.arrowLeft,
    ),
  );
  return true;
}

Future<void> _editNext(
  SlideTextEditing host,
  String id,
  (int, int)? next, {
  required bool addRow,
  required bool toEnd,
}) async {
  final ed = host.editor;
  host.commit();
  if (addRow) {
    final r = await ed.invokeCommand('slides.table.insertRow', const {
      'below': true,
    }, InvocationSource.shortcut);
    if (r.status != CommandStatus.ok) return;
    final ix = ed.model.indexes.table(id);
    next = (ix.rows.length - 1, 0);
  }
  final ix = ed.model.indexes.table(id);
  final target = next;
  if (target == null || target.$1 >= ix.rows.length) return;
  final m = ix.mergeAt(target.$1, target.$2);
  final r = m?.row ?? target.$1, c = m?.column ?? target.$2;
  final cell = (rowId: ix.rows[r].id, columnId: ix.columns[c].id);
  host.end(select: false);
  await host.begin(id, cell: cell, caretOffset: toEnd ? null : 0);
}

int _plainLength(String json) {
  try {
    final v = jsonDecode(json);
    if (v is! List) return 0;
    var n = 0;
    for (final op in v) {
      final ins = op is Map ? op['insert'] : null;
      if (ins is String) n += ins.length;
    }
    return math.max(0, n - 1);
  } on FormatException {
    return 0;
  }
}

String _plain(String json) {
  try {
    final v = jsonDecode(json);
    if (v is! List) return '';
    return [
      for (final op in v)
        if (op is Map && op['insert'] is String) op['insert'] as String,
    ].join();
  } on FormatException {
    return '';
  }
}

bool _hasBreakBefore(String json, int offset) {
  final t = _plain(json);
  return t.substring(0, offset.clamp(0, t.length)).contains('\n');
}

bool _hasBreakAfter(String json, int offset) {
  var t = _plain(json);
  if (t.endsWith('\n')) t = t.substring(0, t.length - 1);
  return offset < t.length && t.substring(offset).contains('\n');
}

/// Text format targets of a selected table: the selected cells, else every
/// visible cell (03 §6.6: formatting applies to the cells' whole text).
List<TextFormatTarget> _formatCells(
  DeckEditorController ed,
  ResolvedElement table,
  ResolvedSlide slide,
) {
  final canvas = SlideCanvasController.of(ed);
  final grid = canvas == null ? null : TableGeometry.gridOf(canvas, table.id);
  if (grid == null) return const [];
  final ix = ed.model.indexes.table(table.id);
  final sel = TableCellSelection.of(ed);
  final range =
      (sel.tableId == table.id ? sel.range : null) ?? TableRange.all(ix);
  if (range == null) return const [];
  return [
    for (final c in range.cells(ix))
      if (grid.cellOf(c.rowId, c.columnId) case final g?)
        TextFormatTarget(
          table,
          slide,
          cell: (rowId: c.rowId, columnId: c.columnId),
          cellText: ix.cell(c.rowId, c.columnId)?.text,
          cellStyles: g.styles,
        ),
  ];
}
