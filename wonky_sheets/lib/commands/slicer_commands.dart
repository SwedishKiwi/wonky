import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/data_tools/data_tools.dart';
import '../features/objects/objects_controller.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import '../features/slicers/slicer_controller.dart';
import '../features/slicers/slicer_panel.dart';
import '../features/slicers/slicer_spec.dart';
import 'sheets_command.dart';
import 'sort_commands.dart' show dataRangeFor;

String _data(SheetsLocalizations l) => l.categoryData;

const _idProp = JsonSchema.string(description: 'Slicer object id.');

/// A slicer command whose effect is a synced write for editors (one undo
/// step) but local state for viewers (07 §5): always opens an undo
/// transaction (empty ones are dropped).
class _SlicerCommand extends SheetsCommand {
  _SlicerCommand(
    super.id, {
    required super.label,
    required super.run,
    super.argsSchema,
  }) : super(categoryName: _data, showInPalette: false);

  @override
  bool get isUndoable => true;
}

(SheetModel, EmbeddedObjectRecord, SlicerSpec) _slicer(
  SheetEditorController ed,
  JsonArgs a,
) {
  final id =
      a.string('objectId') ??
      switch (ObjectsController.of(ed).selected) {
        final o? when o.kind == EmbeddedObjectKind.slicer => o.id,
        _ => null,
      };
  final f = id == null ? null : SlicerController.of(ed).find(id);
  final spec = f == null ? null : SlicerSpec.tryParse(f.$2.specJson);
  if (f == null || spec == null) {
    throw const PlanException('not_found', 'Slicer not found');
  }
  return (f.$1, f.$2, spec);
}

void _write(
  CommandContext ctx,
  SheetEditorController ed,
  EmbeddedObjectRecord o,
  SlicerSpec spec,
) => ed.apply(ctx, UpdateObject(o.id, specJson: spec.encode()));

/// Slicer commands (07 §5, P2).
List<Command<CommandArgs>> slicerCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.slicer.add',
    label: (l) => l.cmdSlicerAdd,
    icon: LucideIcons.slidersHorizontal,
    categoryName: _data,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'range': JsonSchema.string(
          description:
              'Data range incl. its header row (default: the '
              'basic filter range or the data region).',
        ),
        'colId': JsonSchema.string(),
      },
    ),
    run: (ctx, ed, a) {
      final sheet = ed.activeSheet!;
      GridRect? rect;
      if (a.string('range') != null) {
        rect = rangeArg(ed, a).rect;
      } else {
        final sel = ed.selection.resolved;
        final basic = DataTools.of(ed).filters.basicFilter(sheet.id);
        rect =
            basic != null && basic.range.contains(sel.activeRow, sel.activeCol)
            ? basic.range
            : dataRangeFor(ed);
      }
      if (rect == null || rect.rowCount < 2) {
        return CommandResult.failed(ed.l10n.slicerNeedsData);
      }
      final active = ed.selection.resolved.activeCol;
      final colId =
          a.string('colId') ??
          sheet.columns.idAt(
            active >= rect.left && active <= rect.right ? active : rect.left,
          );
      final spec = SlicerSpec(dataRange: sheet.gridRange(rect), colId: colId);
      final col = (rect.right + 1).clamp(0, sheet.columns.length - 1);
      final anchor = ObjectAnchor.atCell(
        rect.top,
        col,
        width: 220,
        height: 56,
        rows: sheet.rows,
        columns: sheet.columns,
        dx: 8,
      );
      final plan = ed.apply(
        ctx,
        AddObject(
          sheet.id,
          EmbeddedObjectKind.slicer,
          anchorJson: anchor.encode(),
          specJson: spec.encode(),
        ),
      );
      final id = plan.result['objectId']! as String;
      ObjectsController.of(ed).select(id);
      if (ctx.source != InvocationSource.mcp) s.panels.open(slicerPanelId);
      return ok({'objectId': id});
    },
  ),
  SheetsCommand(
    'sheets.slicer.edit',
    label: (l) => l.cmdSlicerEdit,
    icon: LucideIcons.pencil,
    categoryName: _data,
    showInPalette: false,
    argsSchema: const JsonSchema.object(properties: {'objectId': _idProp}),
    run: (ctx, ed, a) {
      final (_, o, _) = _slicer(ed, a);
      ObjectsController.of(ed).select(o.id);
      s.panels.open(slicerPanelId);
      return ok({'objectId': o.id});
    },
  ),
  SheetsCommand(
    'sheets.slicer.update',
    label: (l) => l.cmdSlicerUpdate,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'objectId': _idProp,
        'spec': JsonSchema.object(additionalProperties: true),
      },
      required: ['spec'],
    ),
    run: (ctx, ed, a) {
      final (_, o, _) = _slicer(ed, a);
      final raw = a.values['spec'];
      final spec = SlicerSpec.tryParse(raw is String ? raw : jsonEncode(raw));
      if (spec == null) return const CommandResult.failed('Invalid spec');
      _write(ctx, ed, o, spec);
      return ok();
    },
  ),
  _SlicerCommand(
    'sheets.slicer.setCriteria',
    label: (l) => l.cmdSlicerSetCriteria,
    argsSchema: const JsonSchema.object(
      properties: {
        'objectId': _idProp,
        'criteria': JsonSchema.object(
          additionalProperties: true,
          description: '{hiddenValues, condition}; null shows all.',
        ),
      },
    ),
    run: (ctx, ed, a) {
      final (_, o, spec) = _slicer(ed, a);
      final raw = a.values['criteria'];
      final c = raw == null
          ? null
          : ColumnCriteria.fromJson(raw is String ? jsonDecode(raw) : raw);
      final criteria = c == null || c.isEmpty ? null : c;
      final slicers = SlicerController.of(ed);
      if (!ed.canEdit) {
        // Viewers: local only, never formulas (07 §5).
        slicers.setOverride(o.id, criteria);
        return ok({'local': true});
      }
      slicers.setOverride(o.id, null, clear: true);
      _write(ctx, ed, o, spec.copyWith(criteria: () => criteria));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.slicer.setDefault',
    label: (l) => l.cmdSlicerSetDefault,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(properties: {'objectId': _idProp}),
    run: (ctx, ed, a) {
      final (_, o, spec) = _slicer(ed, a);
      final slicers = SlicerController.of(ed);
      if (!slicers.hasOverride(o.id)) return ok();
      final c = slicers.criteriaOf(o);
      slicers.setOverride(o.id, null, clear: true);
      _write(ctx, ed, o, spec.copyWith(criteria: () => c));
      return ok();
    },
  ),
  _SlicerCommand(
    'sheets.slicer.reset',
    label: (l) => l.cmdSlicerReset,
    argsSchema: const JsonSchema.object(properties: {'objectId': _idProp}),
    run: (ctx, ed, a) {
      final (_, o, spec) = _slicer(ed, a);
      final slicers = SlicerController.of(ed);
      slicers.setOverride(o.id, null, clear: true);
      if (ed.canEdit && spec.criteria != null) {
        _write(ctx, ed, o, spec.copyWith(criteria: () => null));
      }
      return ok();
    },
  ),
];
