import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';
import '../sheet_editor/write_gate.dart';
import 'pivot_layer.dart';
import 'pivot_overlay_service.dart';
import 'ui/pivot_edit_button.dart';

/// Pivot tables of one open spreadsheet (07 §7): the [PivotOverlayService]
/// bound to the editor's engine, the grid layer (header/total fills, the
/// empty-spec message), bold defaults, the write guard of the output
/// (03 §14.9), drill-down on double-click, the floating *Edit* button and
/// the pivot the editor panel shows.
class PivotController extends ChangeNotifier {
  PivotController._(this.editor)
    : service = PivotOverlayService(
        model: editor.model,
        engine: editor.engine,
        hooks: editor.hooks,
      ) {
    service.addListener(_onOutputs);
    service.attach(editor.session.engine.view);
    editor.cells.computedFormat = _computedFormat;
    editor.layers.add(_layer);
    _staleLayer = PivotStaleLayer(this, () => editor.l10n.pivotUpdating);
    editor.layers.add(_staleLayer);
    editor.layers.addWidget(_button);
    editor.writeGates.add(_gate);
    editor.cellDoubleClickHandlers.add(_onDoubleClick);
    editor.selection.addListener(_onSelection);
    editor.services.panels.addListener(_onPanels);
    editor.onDispose(dispose);
  }

  /// The pivot controller of [editor] (installed on first use).
  static PivotController of(SheetEditorController editor) =>
      editor.extension(PivotController, () => PivotController._(editor));

  /// The controller of [editor] if installed.
  static PivotController? maybeOf(SheetEditorController editor) =>
      editor.extensionOrNull<PivotController>(PivotController);

  /// Id of the pivot editor panel (04 §10).
  static const panelId = 'sheets.panel.pivotEditor';

  final SheetEditorController editor;
  final PivotOverlayService service;
  final PivotLayer _layer = PivotLayer();
  late final PivotStaleLayer _staleLayer;
  bool _disposed = false;

  /// The pivot shown in the editor panel.
  final ValueNotifier<String?> editing = ValueNotifier(null);

  /// The output of the edited pivot, or null.
  PivotOutput? get editingOutput {
    final id = editing.value;
    return id == null ? null : service.byId(id);
  }

  /// The pivot at the active cell, or null.
  PivotOutput? get activeOutput {
    final r = editor.selection.resolved;
    return service.outputAt(editor.activeSheetId, r.activeRow, r.activeCol);
  }

  /// The pivot with [id] or, without an id, at the active cell or the one
  /// being edited.
  PivotOutput? resolve(String? id) =>
      id != null ? service.byId(id) : (activeOutput ?? editingOutput);

  /// Opens the editor panel on [pivotId].
  void openEditor(String pivotId) {
    editing.value = pivotId;
    editor.services.panels.open(panelId);
  }

  void _onOutputs() {
    editor.cells.invalidate();
    editor.contentSignal.fire();
    editor.overlaySignal.fire();
    final id = editing.value;
    if (id != null && service.byId(id) == null) editing.value = null;
    notifyListeners();
  }

  void _onSelection() {
    // The open panel follows the selection into another pivot (Sheets).
    if (!editor.services.panels.isOpen(panelId)) return;
    final o = activeOutput;
    if (o != null && o.id != editing.value) editing.value = o.id;
  }

  void _onPanels() {
    if (editor.services.panels.isOpen(panelId) && editing.value == null) {
      final o = activeOutput;
      if (o != null) editing.value = o.id;
    }
  }

  // ---------------------------------------------------------------------------
  // Formats.

  static final ConditionalOverlay _bold = ConditionalOverlay(
    format: CellFormat({FormatAttr.bold: true}),
  );

  ConditionalOverlay? _computedFormat(String sheetId, int row, int col) {
    final o = service.outputAt(sheetId, row, col);
    if (o == null) return null;
    final cell = o.cellAt(row, col);
    if (cell == null || !cell.bold) return null;
    if (editor.model
        .explicitFormatChain(sheetId, row, col)
        .has(FormatAttr.bold)) {
      return null;
    }
    return _bold;
  }

  // ---------------------------------------------------------------------------
  // Write guard (03 §14.9, 07 §7.6).

  String get readOnlyMessage => editor.l10n.pivotReadOnlyToast;

  void _gate(CommandContext? ctx, SheetsOperation op) {
    final refusal = _guard(ctx, op);
    if (refusal != null) {
      throw WriteRefused(refusal, code: 'pivot_output');
    }
  }

  String? _guard(CommandContext? ctx, SheetsOperation op) {
    switch (op) {
      case SetCellInputs(:final sheetId, :final row, :final col, :final inputs):
        var width = 1;
        for (final r in inputs) {
          if (r.length > width) width = r.length;
        }
        final rows = inputs.isEmpty ? 1 : inputs.length;
        return _blocked(
          sheetId,
          GridRect(row, col, row + rows - 1, col + width - 1),
        );
      case ClearRanges(:final ranges, :final what)
          when what == ClearWhat.contents || what == ClearWhat.all:
        return _clear(ctx, ranges);
      case PasteClipboard(:final target, :final source, :final mode)
          when source.isCut &&
              mode == PasteMode.all &&
              source.sheetId != null &&
              (source.spreadsheetId == null ||
                  source.spreadsheetId == editor.model.spreadsheetId):
        // Cut/paste moves whole outputs with it (07 §7.6), also to another
        // sheet.
        final h = source.cells.isEmpty ? 1 : source.cells.length;
        final w = source.colCount < 1 ? 1 : source.colCount;
        return _moveBlock(
          ctx,
          source.sheetId!,
          GridRect(
            source.sourceRow,
            source.sourceCol,
            source.sourceRow + h - 1,
            source.sourceCol + w - 1,
          ),
          target.sheetId,
          target.rect.top,
          target.rect.left,
        );
      case PasteClipboard(:final target, :final source, :final mode):
        if (mode == PasteMode.format ||
            mode == PasteMode.conditionalFormatting ||
            mode == PasteMode.dataValidation ||
            mode == PasteMode.columnWidths) {
          return null;
        }
        final t = target.rect;
        final transposed = mode == PasteMode.transposed;
        final h = transposed ? source.colCount : source.cells.length;
        final w = transposed ? source.cells.length : source.colCount;
        final rect = GridRect(
          t.top,
          t.left,
          t.bottom > t.top + h - 1 ? t.bottom : t.top + h - 1,
          t.right > t.left + w - 1 ? t.right : t.left + w - 1,
        );
        return _blocked(target.sheetId, rect);
      case FillSeries(:final sheetId, :final source, :final target):
        return _blockedOutside(sheetId, target, source);
      case MoveRange():
        return _move(ctx, op);
      case RestoreCellValue(:final sheetId, :final rowId, :final colId):
        final s = editor.model.sheet(sheetId);
        if (s == null) return null;
        return _blocked(
          sheetId,
          GridRect.cell(s.rows.indexOf(rowId), s.columns.indexOf(colId)),
        );
      case SortRange(:final range) ||
          RandomizeRange(:final range) ||
          RemoveDuplicates(:final range) ||
          SplitTextToColumns(:final range):
        return _blocked(range.sheetId, range.rect);
      case TrimWhitespace(:final ranges):
        for (final r in ranges) {
          final m = _blocked(r.sheetId, r.rect);
          if (m != null) return m;
        }
        return null;
      default:
        return null;
    }
  }

  String? _blocked(String sheetId, GridRect rect) {
    for (final o in service.outputsOf(sheetId)) {
      if (o.rect.intersects(rect)) return readOnlyMessage;
    }
    return null;
  }

  String? _blockedOutside(String sheetId, GridRect rect, GridRect allowed) {
    for (final o in service.outputsOf(sheetId)) {
      final i = o.rect.intersection(rect);
      if (i != null && !allowed.containsRect(i)) return readOnlyMessage;
    }
    return null;
  }

  /// Delete over a whole pivot deletes it (07 §7.6); over part of it the
  /// write is refused.
  String? _clear(CommandContext? ctx, List<ResolvedRange> ranges) {
    final delete = <String>{};
    for (final r in ranges) {
      for (final o in service.outputsOf(r.sheetId)) {
        if (!o.rect.intersects(r.rect)) continue;
        if (r.rect.containsRect(o.rect)) {
          delete.add(o.id);
        } else {
          return readOnlyMessage;
        }
      }
    }
    if (ctx == null) return delete.isEmpty ? null : readOnlyMessage;
    for (final id in delete) {
      editor.apply(ctx, DeletePivotTable(id));
    }
    return null;
  }

  /// Cut/paste or drag of the whole output moves the pivot (07 §7.6).
  String? _move(CommandContext? ctx, MoveRange op) => _moveBlock(
    ctx,
    op.source.sheetId,
    op.source.rect,
    op.destSheetId,
    op.destRow,
    op.destCol,
    copy: op.copy,
  );

  /// Moves the pivots whose whole output lies in [srcRect] of [srcSheetId]
  /// to ([destRow], [destCol]) of [destSheetId] (re-created on another
  /// sheet); refuses partial outputs and destinations over other outputs.
  String? _moveBlock(
    CommandContext? ctx,
    String srcSheetId,
    GridRect srcRect,
    String destSheetId,
    int destRow,
    int destCol, {
    bool copy = false,
  }) {
    final src = ResolvedRange(srcSheetId, srcRect);
    final op = (destSheetId: destSheetId, destRow: destRow, destCol: destCol);
    final dest = GridRect(
      op.destRow,
      op.destCol,
      op.destRow + src.rect.rowCount - 1,
      op.destCol + src.rect.colCount - 1,
    );
    final moving = <PivotOutput>[];
    if (!copy) {
      for (final o in service.outputsOf(src.sheetId)) {
        if (!o.rect.intersects(src.rect)) continue;
        if (!src.rect.containsRect(o.rect)) return readOnlyMessage;
        moving.add(o);
      }
    }
    for (final o in service.outputsOf(op.destSheetId)) {
      if (moving.contains(o)) continue;
      if (o.rect.intersects(dest)) return readOnlyMessage;
    }
    if (ctx == null) return moving.isEmpty ? null : readOnlyMessage;
    for (final o in moving) {
      final row = o.anchorRow - src.rect.top + op.destRow;
      final col = o.anchorCol - src.rect.left + op.destCol;
      if (op.destSheetId == src.sheetId) {
        editor.apply(
          ctx,
          UpdatePivotTable(o.id, anchorRow: row, anchorCol: col),
        );
        continue;
      }
      // Another sheet: the pivot is re-created there (same source and
      // spec, same step); the editor panel follows it.
      final source = o.source;
      if (source == null) return readOnlyMessage;
      editor.apply(ctx, DeletePivotTable(o.id));
      final plan = editor.apply(
        ctx,
        AddPivotTable(op.destSheetId, row, col, source, o.record.specJson),
      );
      final id = plan.result['pivotId'];
      if (editing.value == o.id && id is String) editing.value = id;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Drill-down on double-click (07 §7.9).

  bool _onDoubleClick(int row, int col) {
    final o = service.outputAt(editor.activeSheetId, row, col);
    final cell = o?.cellAt(row, col);
    if (o == null || cell == null || !cell.isValue || !editor.canEdit) {
      return false;
    }
    editor.selection.selectCell(row, col);
    unawaited(
      editor.invokeCommand('sheets.pivot.drillDown', {
        'pivotId': o.id,
        'cell': GridRect.cell(row, col).a1,
      }),
    );
    return true;
  }

  // ---------------------------------------------------------------------------

  Widget _button(BuildContext context) => PivotEditButton(controller: this);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    editor.selection.removeListener(_onSelection);
    editor.services.panels.removeListener(_onPanels);
    editor.writeGates.remove(_gate);
    editor.cellDoubleClickHandlers.remove(_onDoubleClick);
    editor.layers.remove(_layer);
    editor.layers.remove(_staleLayer);
    editor.layers.removeWidget(_button);
    if (editor.cells.computedFormat == _computedFormat) {
      editor.cells.computedFormat = null;
    }
    service
      ..removeListener(_onOutputs)
      ..dispose();
    editing.dispose();
    super.dispose();
  }
}
