import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';

import '../features/data_tools/data_tools.dart';
import '../features/grid/selection/grid_selection.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _view(SheetsLocalizations l) => l.categoryView;

const _idsSchema = JsonSchema.object(
  properties: {
    'ids': JsonSchema.array(
      JsonSchema.string(),
      description: 'Row/column ids (default: the selection).',
    ),
  },
);

const _dimensionSchema = JsonSchema.object(
  properties: {
    'dimension': JsonSchema.string(enumValues: ['rows', 'columns']),
  },
);

/// The index span of the selection (or of `ids`) on [d].
(int, int)? _span(SheetEditorController ed, JsonArgs a, Dimension d) {
  final s = ed.activeSheet;
  if (s == null) return null;
  final axis = d == Dimension.rows ? s.rows : s.columns;
  final ids = a.strings('ids');
  if (ids.isNotEmpty) {
    final idx = [
      for (final id in ids)
        if (axis.indexOf(id) >= 0) axis.indexOf(id),
    ]..sort();
    return idx.isEmpty ? null : (idx.first, idx.last);
  }
  final r = ed.selection.resolved.activeRange.rect;
  final last = axis.length - 1;
  return d == Dimension.rows
      ? (r.top.clamp(0, last), r.bottom.clamp(0, last))
      : (r.left.clamp(0, last), r.right.clamp(0, last));
}

String _spanLabel(SheetEditorController ed, Dimension d) {
  final span = _span(ed, const JsonArgs(), d);
  if (span == null) return '';
  final (a, z) = span;
  if (d == Dimension.rows) return a == z ? '${a + 1}' : '${a + 1} – ${z + 1}';
  final ca = ColumnLetters.fromIndex(a);
  final cz = ColumnLetters.fromIndex(z);
  return a == z ? ca : '$ca – $cz';
}

bool _inGroup(SheetEditorController ed, Dimension d) {
  final span = _span(ed, const JsonArgs(), d);
  if (span == null) return false;
  for (final g in DataTools.of(ed).groups.spans(ed.activeSheetId, d)) {
    if (g.intersects(span.$1, span.$2)) return true;
  }
  return false;
}

Dimension _dimensionArg(JsonArgs a) =>
    a.string('dimension') == 'columns' ? Dimension.columns : Dimension.rows;

/// Row/column group (outline) commands (07 §16.2).
List<Command<CommandArgs>> groupCommands(ShellServices s) {
  SheetsCommand span(
    String id,
    Dimension d,
    GroupAction action, {
    required SheetsText label,
    required String Function(SheetsLocalizations l, String span) dynamic,
    required bool Function(SheetEditorController ed) enabled,
    List<KeyBinding> bindings = const [],
  }) => SheetsCommand(
    id,
    label: label,
    dynamicLabel: (l, ed) => dynamic(l, _spanLabel(ed, d)),
    icon: action == GroupAction.group
        ? LucideIcons.listTree
        : LucideIcons.listX,
    categoryName: _view,
    mutates: true,
    repeatable: true,
    defaultBindings: bindings,
    argsSchema: _idsSchema,
    enabled: (ed, a) => a.strings('ids').isNotEmpty || enabled(ed),
    run: (ctx, ed, a) {
      final sp = _span(ed, a, d);
      if (sp == null) return const CommandResult.cancelled();
      final plan = ed.apply(
        ctx,
        GroupOperation(ed.activeSheetId, d, action, start: sp.$1, end: sp.$2),
      );
      return ok({'groupId': ?plan.result['groupId']});
    },
  );

  SheetsCommand all(
    String id,
    GroupAction action, {
    required SheetsText label,
  }) => SheetsCommand(
    id,
    label: label,
    categoryName: _view,
    mutates: true,
    argsSchema: _dimensionSchema,
    enabled: (ed, a) => ed.activeSheet?.groups.isNotEmpty ?? false,
    run: (ctx, ed, a) {
      ed.apply(ctx, GroupOperation(ed.activeSheetId, _dimensionArg(a), action));
      return ok();
    },
  );

  SelectionKind kind(SheetEditorController ed) =>
      ed.selection.resolved.activeRange.kind;

  return [
    span(
      'sheets.group.groupColumns',
      Dimension.columns,
      GroupAction.group,
      label: (l) => l.cmdGroupColumns,
      dynamic: (l, x) => l.cmdGroupColumnsSpan(x),
      enabled: (ed) => kind(ed) == SelectionKind.columns,
      bindings: const [KeyBinding(Keys.arrowRight, alt: true, shift: true)],
    ),
    span(
      'sheets.group.groupRows',
      Dimension.rows,
      GroupAction.group,
      label: (l) => l.cmdGroupRows,
      dynamic: (l, x) => l.cmdGroupRowsSpan(x),
      enabled: (ed) => kind(ed) != SelectionKind.columns,
      bindings: const [KeyBinding(Keys.arrowRight, alt: true, shift: true)],
    ),
    span(
      'sheets.group.ungroupColumns',
      Dimension.columns,
      GroupAction.ungroup,
      label: (l) => l.cmdUngroupColumns,
      dynamic: (l, x) => l.cmdUngroupColumnsSpan(x),
      enabled: (ed) =>
          kind(ed) == SelectionKind.columns && _inGroup(ed, Dimension.columns),
      bindings: const [KeyBinding(Keys.arrowLeft, alt: true, shift: true)],
    ),
    span(
      'sheets.group.ungroupRows',
      Dimension.rows,
      GroupAction.ungroup,
      label: (l) => l.cmdUngroupRows,
      dynamic: (l, x) => l.cmdUngroupRowsSpan(x),
      enabled: (ed) =>
          kind(ed) != SelectionKind.columns && _inGroup(ed, Dimension.rows),
      bindings: const [KeyBinding(Keys.arrowLeft, alt: true, shift: true)],
    ),
    SheetsCommand(
      'sheets.group.toggle',
      label: (l) => l.cmdGroupToggle,
      categoryName: _view,
      mutates: true,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {'groupId': JsonSchema.string()},
        required: ['groupId'],
      ),
      run: (ctx, ed, a) {
        final id = a.requireString('groupId');
        final rec = ed.activeSheet?.groups[id];
        if (rec == null) return const CommandResult.failed('Group not found');
        ed.apply(
          ctx,
          GroupOperation(
            ed.activeSheetId,
            rec.dimension,
            GroupAction.toggle,
            groupId: id,
          ),
        );
        return ok({'collapsed': !rec.collapsed});
      },
    ),
    SheetsCommand(
      'sheets.group.collapseToLevel',
      label: (l) => l.cmdGroupCollapseToLevel,
      categoryName: _view,
      mutates: true,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'dimension': JsonSchema.string(enumValues: ['rows', 'columns']),
          'level': JsonSchema.integer(),
        },
        required: ['level'],
      ),
      run: (ctx, ed, a) {
        ed.apply(
          ctx,
          GroupOperation(
            ed.activeSheetId,
            _dimensionArg(a),
            GroupAction.collapseToLevel,
            level: a.integer('level'),
          ),
        );
        return ok();
      },
    ),
    all(
      'sheets.group.expandAll',
      GroupAction.expandAll,
      label: (l) => l.cmdGroupExpandAll,
    ),
    all(
      'sheets.group.collapseAll',
      GroupAction.collapseAll,
      label: (l) => l.cmdGroupCollapseAll,
    ),
    all(
      'sheets.group.removeAll',
      GroupAction.removeAll,
      label: (l) => l.cmdGroupRemoveAll,
    ),
  ];
}
