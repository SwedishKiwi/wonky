import '../../model/schema.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';

/// [AddObject].
MutationPlan planAddObject(PlanBuilder b, AddObject op) {
  final s = b.sheetOf(op.sheetId);
  var z = op.zIndex;
  if (z == null) {
    z = 0;
    for (final o in s.objects.values) {
      if (o.zIndex >= z!) z = o.zIndex + 1;
    }
  }
  final id = op.id ?? b.ctx.ids.newId();
  var title = op.title;
  if (title == null) {
    final prefix = switch (op.kind) {
      EmbeddedObjectKind.chart => 'Chart',
      EmbeddedObjectKind.image => 'Image',
      EmbeddedObjectKind.slicer => 'Slicer',
      EmbeddedObjectKind.drawing => 'Drawing',
    };
    final taken = {
      for (final x in b.model.sheets)
        for (final o in x.objects.values) o.title,
    };
    for (var i = 1; ; i++) {
      if (!taken.contains('$prefix $i')) {
        title = '$prefix $i';
        break;
      }
    }
  }
  b.insert(SheetsTables.embeddedObject, id, {
    Cols.sheetId: s.id,
    'kind': op.kind.name,
    'anchorJson': op.anchorJson,
    'specJson': op.specJson,
    'zIndex': z,
    'title': title,
    'altText': op.altText,
  });
  b.result['objectId'] = id;
  b.summary.sheets.add(s.id);
  final label = switch (op.kind) {
    EmbeddedObjectKind.chart => 'Insert chart',
    EmbeddedObjectKind.image => 'Insert image',
    EmbeddedObjectKind.slicer => 'Add slicer',
    EmbeddedObjectKind.drawing => 'Insert drawing',
  };
  return b.build(label, kinds: [ChangeKinds.objects]);
}

/// [UpdateObject].
MutationPlan planUpdateObject(PlanBuilder b, UpdateObject op) {
  final cur = b.current(SheetsTables.embeddedObject, op.id);
  if (cur == null) throw const PlanException('not_found', 'Object not found');
  if (op.sheetId != null) b.sheetOf(op.sheetId!);
  b.update(SheetsTables.embeddedObject, op.id, {
    if (op.sheetId != null) Cols.sheetId: op.sheetId,
    if (op.anchorJson != null) 'anchorJson': op.anchorJson,
    if (op.specJson != null) 'specJson': op.specJson,
    if (op.zIndex != null) 'zIndex': op.zIndex,
    if (op.title != null) 'title': op.title,
    if (op.altText != null) 'altText': op.altText,
  });
  b.summary.sheets.add(cur[Cols.sheetId] as String);
  final label = op.anchorJson != null && op.specJson == null
      ? 'Move object'
      : op.specJson != null
      ? 'Edit chart'
      : 'Edit object';
  return b.build(label, kinds: [ChangeKinds.objects]);
}

/// [DeleteObject].
MutationPlan planDeleteObject(PlanBuilder b, DeleteObject op) {
  final cur = b.current(SheetsTables.embeddedObject, op.id);
  if (cur == null) throw const PlanException('not_found', 'Object not found');
  b.delete(SheetsTables.embeddedObject, op.id);
  b.summary.sheets.add(cur[Cols.sheetId] as String);
  return b.build('Delete object', kinds: [ChangeKinds.objects]);
}

/// [AddPivotTable].
MutationPlan planAddPivotTable(PlanBuilder b, AddPivotTable op) {
  final s = b.sheetOf(op.sheetId);
  final src = b.sheetOf(op.source.sheetId);
  final id = op.id ?? b.ctx.ids.newId();
  b.insert(SheetsTables.pivotTable, id, {
    Cols.sheetId: s.id,
    'anchorRowId': s.rows.idAt(op.anchorRow),
    'anchorColId': s.columns.idAt(op.anchorCol),
    'sourceRangeJson': b.rangeJson(
      src,
      op.source.rect,
      wholeRows: op.source.wholeRows,
      wholeColumns: op.source.wholeColumns,
    ),
    'specJson': op.specJson,
  });
  b.result['pivotId'] = id;
  b.summary.sheets.add(s.id);
  return b.build('Insert pivot table', kinds: [ChangeKinds.objects]);
}

/// [UpdatePivotTable].
MutationPlan planUpdatePivotTable(PlanBuilder b, UpdatePivotTable op) {
  final cur = b.current(SheetsTables.pivotTable, op.id);
  if (cur == null) {
    throw const PlanException('not_found', 'Pivot table not found');
  }
  final s = b.sheetOf(cur[Cols.sheetId] as String);
  final writes = <String, Object?>{
    if (op.specJson != null) 'specJson': op.specJson,
    if (op.anchorRow != null) 'anchorRowId': s.rows.idAt(op.anchorRow!),
    if (op.anchorCol != null) 'anchorColId': s.columns.idAt(op.anchorCol!),
  };
  if (op.source != null) {
    final src = b.sheetOf(op.source!.sheetId);
    writes['sourceRangeJson'] = b.rangeJson(
      src,
      op.source!.rect,
      wholeRows: op.source!.wholeRows,
      wholeColumns: op.source!.wholeColumns,
    );
  }
  b.update(SheetsTables.pivotTable, op.id, writes);
  b.summary.sheets.add(s.id);
  return b.build('Edit pivot table', kinds: [ChangeKinds.objects]);
}

/// [DeletePivotTable].
MutationPlan planDeletePivotTable(PlanBuilder b, DeletePivotTable op) {
  final cur = b.current(SheetsTables.pivotTable, op.id);
  if (cur == null) {
    throw const PlanException('not_found', 'Pivot table not found');
  }
  b.delete(SheetsTables.pivotTable, op.id);
  b.summary.sheets.add(cur[Cols.sheetId] as String);
  return b.build('Delete pivot table', kinds: [ChangeKinds.objects]);
}

/// [GenericRowWrite].
MutationPlan planGenericRowWrite(PlanBuilder b, GenericRowWrite op) {
  if (op.delete) {
    b.delete(op.table, op.id);
  } else if (b.current(op.table, op.id) == null) {
    b.insert(op.table, op.id, op.columns);
  } else {
    b.update(op.table, op.id, op.columns);
  }
  final isScript =
      op.table.startsWith('script') || op.table == SheetsTables.macro;
  return b.build(
    op.label ?? (isScript ? 'Edit script' : 'Edit'),
    kinds: [if (isScript) ChangeKinds.scripts],
  );
}
