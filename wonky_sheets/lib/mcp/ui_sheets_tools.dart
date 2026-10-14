import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_sheets_core/formula.dart' show CellPos, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/ai/agent_highlight_layer.dart';
import '../features/ai/sheets_a1.dart';
import '../features/ai/sheets_ai_controller.dart';
import '../features/cell_editor/cell_editor_controller.dart';
import '../features/explore/explore_panel.dart' show explorePanelId;
import '../features/grid/paint/grid_layer.dart';
import '../features/grid/paint/layers/content_layers.dart';
import '../features/grid/paint/layers/overlay_layers.dart' show HeaderLayer;
import '../features/grid/selection/grid_selection.dart';
import '../features/grid/viewport/grid_geometry.dart';
import '../features/charts/controller/chart_controller.dart'
    show chartDarkOf, chartUiTokensOf;
import '../features/charts/chart_insert.dart' show chartEditorPanelId;
import '../features/charts/editor/chart_editor_mcp.dart';
import '../features/charts/render/chart_painter.dart' show paintChartScene;
import '../features/images/image_object_view.dart' show boxFitOf;
import '../features/images/image_service.dart';
import '../features/objects/objects_controller.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import '../features/sheet_editor/sheets_document_controller.dart';
import '../features/status/selection_stats.dart';
import '../theme/sheets_tokens.dart';
import 'panel_describer.dart';

/// Wonky Sheets' UI-bridge tools (`ui.sheets.*`, Sheets 12 §5), executed in
/// the live window on the open spreadsheet. Writes go through commands
/// (source `mcp`), so they land on the user's undo stack; ranges an agent
/// works on are flashed with its name (agent presence highlight).
abstract final class UiSheetsToolHandlers {
  static Map<String, UiToolHandler> all(ShellServices services) => {
    'ui.sheets.get_selection': getSelection,
    'ui.sheets.select_range': selectRange,
    'ui.sheets.get_visible_range': getVisibleRange,
    'ui.sheets.activate_sheet': activateSheet,
    'ui.sheets.scroll_to': scrollTo,
    'ui.sheets.open_panel': openPanel,
    'ui.sheets.close_panel': closePanel,
    'ui.sheets.describe_panel': describePanel,
    'ui.sheets.set_panel_field': setPanelField,
    'ui.sheets.press_panel_button': pressPanelButton,
    'ui.sheets.start_cell_edit': startCellEdit,
    'ui.sheets.type_in_cell': typeInCell,
    'ui.sheets.screenshot_range': screenshotRange,
    'ui.sheets.highlight_range': highlightRange,
    'ui.sheets.wait_for_recalc': waitForRecalc,
  };

  /// Panel names of `ui.sheets.open_panel` → (command, panel id).
  static const panels = <String, (String?, String)>{
    'chartEditor': ('sheets.chart.edit', 'sheets.panel.chartEditor'),
    'conditionalFormatting': (
      'sheets.cf.openPanel',
      'sheets.panel.conditionalFormatting',
    ),
    'dataValidation': ('sheets.dv.openPanel', 'sheets.panel.dataValidation'),
    'pivotEditor': ('sheets.pivot.openEditor', 'sheets.panel.pivotEditor'),
    'namedRanges': ('sheets.namedRanges.openPanel', 'sheets.panel.namedRanges'),
    'protectedRanges': ('sheets.protect.openPanel', 'sheets.panel.protected'),
    'comments': ('sheets.comments.openPanel', ShellPanels.comments),
    'history': (null, ShellPanels.history),
    'assistant': (null, ShellPanels.assistant),
    'explore': (null, explorePanelId),
    'executions': ('sheets.script.openExecutions', 'sheets.panel.executions'),
    'scriptSidebar': (null, 'sheets.panel.scriptSidebar'),
    'slicer': ('sheets.slicer.add', 'sheets.panel.slicer'),
  };

  static SheetEditorController _editor(UiToolContext c) {
    final d = c.services.activeDocument.value;
    final ed = d is SheetsDocumentController ? d.editor : null;
    if (ed == null) {
      throw const UiToolException(
        'no_document',
        'No Wonky Sheets spreadsheet is open (or it is still loading) in '
            'this window. Open one with ui.navigate {"open_item_uuid": …}.',
      );
    }
    return ed;
  }

  static ResolvedRange _parse(SheetEditorController ed, String a1) {
    try {
      return ed.model.parseA1(a1, contextSheetId: ed.activeSheetId);
    } on InvalidRangeException catch (e) {
      throw UiToolException('invalid_range', e.message);
    }
  }

  static String _agent(UiToolContext c) => c.agentName ?? 'MCP agent';

  /// Flashes [rr] with the agent's name (presence highlight).
  static void _flash(
    UiToolContext c,
    SheetEditorController ed,
    ResolvedRange rr, {
    Duration duration = const Duration(seconds: 5),
    Color color = AgentHighlightLayer.agentColor,
  }) {
    SheetsAiController.of(ed).highlights.flash(
      AgentHighlight(
        sheetId: rr.sheetId,
        rect: _clip(ed, rr),
        label: _agent(c),
        color: color,
      ),
      duration: duration,
    );
  }

  /// Whole rows/columns clipped to the used range (at least A1).
  static GridRect _clip(SheetEditorController ed, ResolvedRange rr) {
    if (!rr.wholeRows && !rr.wholeColumns) return rr.rect;
    final used = ed.model.sheet(rr.sheetId)?.usedRect();
    if (used == null) {
      return GridRect(rr.rect.top, rr.rect.left, rr.rect.top, rr.rect.left);
    }
    return rr.rect.intersection(used) ?? used;
  }

  static String _rangeA1(SheetEditorController ed, ResolvedRange rr) =>
      qualifiedA1(
        ed.sheetName(rr.sheetId),
        rectA1(rr.rect, wholeRows: rr.wholeRows, wholeColumns: rr.wholeColumns),
      );

  // ---------------------------------------------------------------- state

  /// The selection JSON of [ed].
  static Map<String, Object?> selectionOf(SheetEditorController ed) {
    final sel = ed.selection.resolved;
    final sheet = ed.activeSheet;
    final values = <List<String>>[];
    final rect = sel.activeRange.rect;
    final grid = sheet?.gridRect;
    final shown = grid == null ? null : rect.intersection(grid);
    var cells = 0;
    if (sheet != null && shown != null) {
      for (var r = shown.top; r <= shown.bottom && cells < 100; r++) {
        final row = <String>[];
        for (var c = shown.left; c <= shown.right && cells < 100; c++) {
          row.add(ed.cells.displayAt(sheet.id, r, c)?.text ?? '');
          cells++;
        }
        values.add(row);
      }
    }
    final multi = selectionIsMulti(ed);
    final stats = multi ? SelectionStats.of(ed, cap: 200000) : null;
    final object = ObjectsController.maybeOf(ed)?.selectedId;
    return {
      'sheet': sheet?.name,
      'sheet_id': ed.activeSheetId,
      'active_cell': CellPos(sel.activeRow, sel.activeCol).a1,
      'ranges': [
        for (final x in sel.ranges)
          rectA1(
            x.rect,
            wholeRows: x.kind == SelectionKind.rows,
            wholeColumns: x.kind == SelectionKind.columns,
          ),
      ],
      'editing': ed.editor.isEditing,
      if (ed.editor.isEditing) 'editor_text': ed.editor.text.text,
      'object_selected': ?(object == null ? null : {'object_id': object}),
      'values_preview': values,
      'values_truncated': rect.cellCount > cells,
      if (stats != null && stats.count > 0) ...{
        'sum': stats.sum,
        'average': stats.average,
        'count': stats.count,
        'count_numbers': stats.countNumbers,
        'min': stats.min,
        'max': stats.max,
      },
      'can_edit': ed.canEdit,
    };
  }

  static Future<UiToolResult> getSelection(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final s = selectionOf(_editor(c));
    final ranges = (s['ranges']! as List).join(', ');
    return UiToolResult(
      s,
      text: '${s['sheet']}!$ranges (active ${s['active_cell']})',
    );
  }

  static Future<UiToolResult> selectRange(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final texts = [for (final r in a['ranges']! as List) '$r'];
    final sheetArg = a['sheet'] as String?;
    if (sheetArg != null) {
      final sh = _sheetByNameOrId(ed, sheetArg);
      if (sh.id != ed.activeSheetId) ed.activateSheet(sh.id);
    }
    final parsed = [for (final t in texts) _parse(ed, t)];
    final sheetId = parsed.first.sheetId;
    if (parsed.any((p) => p.sheetId != sheetId)) {
      throw const UiToolException(
        'invalid_range',
        'All ranges must be on one sheet.',
      );
    }
    if (ed.editor.isEditing) ed.editor.commitSync(move: CommitMove.none);
    if (sheetId != ed.activeSheetId) ed.activateSheet(sheetId);
    ed.selection.setRanges([
      for (final p in parsed)
        (
          p.wholeSheet
              ? SelectionKind.all
              : p.wholeRows
              ? SelectionKind.rows
              : p.wholeColumns
              ? SelectionKind.columns
              : SelectionKind.cells,
          p.rect,
        ),
    ]);
    final activeText = a['active_cell'] as String?;
    if (activeText != null) {
      final act = _parse(ed, activeText);
      final sel = ed.selection.resolved;
      var idx = sel.ranges.indexWhere(
        (r) => r.rect.contains(act.rect.top, act.rect.left),
      );
      if (idx < 0) {
        throw const UiToolException(
          'invalid_args',
          'active_cell must lie inside one of the ranges.',
        );
      }
      ed.selection.setActiveInSelection(idx, act.rect.top, act.rect.left);
    }
    final r = ed.selection.resolved;
    ed.revealCell(r.activeRow, r.activeCol);
    for (final p in parsed) {
      _flash(c, ed, p);
    }
    await uiSettle();
    return UiToolResult(selectionOf(ed), text: 'Selected ${texts.join(', ')}');
  }

  static SheetModel _sheetByNameOrId(SheetEditorController ed, String s) {
    final byId = ed.model.sheet(s);
    if (byId != null) return byId;
    for (final sh in ed.model.sheets) {
      if (sh.name.toLowerCase() == s.toLowerCase()) return sh;
    }
    throw UiToolException(
      'not_found',
      'No sheet "$s". Sheets: ${[for (final x in ed.model.sheets) x.name].join(', ')}.',
    );
  }

  static Future<UiToolResult> getVisibleRange(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    await uiSettle();
    final g = ed.lastGeometry;
    final sheet = ed.activeSheet;
    String? range;
    if (g != null && !g.main.isEmpty) {
      final (r0, r1) = g.visibleRows;
      final (c0, c1) = g.visibleCols;
      range = GridRect(
        g.frozenRows > 0 ? 0 : r0,
        g.frozenCols > 0 ? 0 : c0,
        r1,
        c1,
      ).a1;
    }
    return UiToolResult({
      'sheet': sheet?.name,
      'range': range,
      'frozen': {
        'rows': sheet?.record?.frozenRows ?? 0,
        'columns': sheet?.record?.frozenColumns ?? 0,
      },
      'zoom': (ed.scroll.zoom * 100).round(),
    }, text: '${sheet?.name}!$range');
  }

  static Future<UiToolResult> activateSheet(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final sh = _sheetByNameOrId(ed, a['sheet']! as String);
    if (sh.record?.hidden ?? false) {
      throw UiToolException(
        'disabled',
        'Sheet "${sh.name}" is hidden. Unhide it with ui.invoke_command '
            '{"command_id": "sheets.sheet.unhide", "args": {"sheetId": '
            '"${sh.id}"}}.',
      );
    }
    ed.activateSheet(sh.id);
    await uiSettle();
    return UiToolResult({
      'sheet': sh.name,
      'sheet_id': sh.id,
    }, text: 'Activated ${sh.name}');
  }

  static Future<UiToolResult> scrollTo(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final rr = _parse(ed, a['cell']! as String);
    if (rr.sheetId != ed.activeSheetId) ed.activateSheet(rr.sheetId);
    final row = rr.rect.top;
    final col = rr.rect.left;
    await uiSettle();
    final g = ed.lastGeometry;
    final align = a['align'] as String?;
    if (g != null && align != null) {
      final geom = g;
      final sheet = ed.activeSheet!;
      final x =
          (sheet.columns.offsetOf(col) -
              sheet.columns.offsetOf(geom.frozenCols)) *
          geom.zoom;
      final y =
          (sheet.rows.offsetOf(row) - sheet.rows.offsetOf(geom.frozenRows)) *
          geom.zoom;
      final dx = align == 'center' ? geom.main.rect.width / 2 : 0.0;
      final dy = align == 'center' ? geom.main.rect.height / 2 : 0.0;
      ed.scroll.jumpTo(
        math.max(0, math.min(geom.maxScrollX, x - dx)),
        math.max(0, math.min(geom.maxScrollY, y - dy)),
      );
    } else {
      ed.revealCell(row, col);
    }
    _flash(c, ed, rr, duration: const Duration(seconds: 2));
    await uiSettle();
    return UiToolResult({
      'cell': _rangeA1(ed, rr),
    }, text: 'Scrolled to ${a['cell']}');
  }

  static Future<UiToolResult> openPanel(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final name = a['panel']! as String;
    final entry = panels[name];
    if (entry == null) {
      throw UiToolException('invalid_args', 'Unknown panel "$name".');
    }
    final (command, panelId) = entry;
    final target = (a['target'] as Map?)?.cast<String, Object?>() ?? const {};
    final s = c.services;
    var opened = false;
    if (command != null && s.registry.byId(command) != null) {
      final args = <String, Object?>{
        if (target['chart_id'] != null) 'objectId': target['chart_id'],
        if (target['pivot_id'] != null) 'pivotId': target['pivot_id'],
        if (target['rule_id'] != null) 'ruleId': target['rule_id'],
      };
      final state = s.dispatcher.stateOf(command, args);
      if (state.enabled) {
        final r = await s.dispatcher.invoke(
          command,
          args: args,
          source: InvocationSource.mcp,
          context: c.context,
        );
        opened = r.isOk;
      }
    }
    if (!opened) {
      s.panels.open(panelId);
      await uiSettle();
      opened = s.panels.isOpen(panelId);
    }
    if (!opened) {
      throw UiToolException(
        'unsupported',
        'The $name panel is not available in this spreadsheet.',
      );
    }
    await uiSettle();
    ed.overlaySignal.fire();
    return UiToolResult({
      'panel': name,
      'panel_id': s.panels.activePanelId,
    }, text: 'Opened $name');
  }

  static Future<UiToolResult> closePanel(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    _editor(c);
    final s = c.services;
    final name = a['panel'] as String?;
    final id = name == null ? s.panels.activePanelId : panels[name]?.$2;
    if (id != null) s.panels.close(id);
    await uiSettle();
    return UiToolResult({'closed': id}, text: 'Closed ${name ?? id ?? '—'}');
  }

  /// The open panel (or `panel`, when it is the open one) for the
  /// describe/set/press tools.
  static PanelDescriber _panel(UiToolContext c, Map<String, Object?> a) {
    _editor(c);
    final name = a['panel'] as String?;
    final id = name == null ? null : (panels[name]?.$2 ?? name);
    final p = PanelDescriber.of(c.services, panelId: id);
    if (p == null) {
      throw UiToolException(
        'not_found',
        id == null
            ? 'No side panel is open. Open one with ui.sheets.open_panel.'
            : 'The panel "$name" is not open. Open it with '
                  'ui.sheets.open_panel.',
      );
    }
    return p;
  }

  static String? _panelTitle(UiToolContext c, String id) {
    for (final e in panels.entries) {
      if (e.value.$2 == id) return e.key;
    }
    return null;
  }

  /// `ui.sheets.describe_panel` (12 §5, P1).
  static Future<UiToolResult> describePanel(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    await uiSettle();
    final p = _panel(c, a);
    final d = p.describe(title: _panelTitle(c, p.panelId));
    // The chart editor also describes its fields by spec path (08 §8.4).
    if (p.panelId == chartEditorPanelId) {
      final chart = ChartEditorMcp.describe(_editor(c));
      if (chart != null) d['chart'] = chart;
    }
    final fields = (d['fields']! as List).length;
    final buttons = (d['buttons']! as List).length;
    return UiToolResult(
      d,
      text: 'Panel ${p.panelId}: $fields fields, $buttons buttons',
    );
  }

  /// `ui.sheets.set_panel_field` (12 §5, P1).
  static Future<UiToolResult> setPanelField(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final p = _panel(c, a);
    final id = a['field_id']! as String;
    // Chart editor fields by spec path (`title.text`, `series.<key>.color`,
    // see `chart.fields` of describe_panel; 08 §8.4).
    if (p.panelId == chartEditorPanelId) {
      final ed = _editor(c);
      final fields = ChartEditorMcp.describe(ed)?['fields'] as List?;
      if (fields != null && fields.any((f) => (f as Map)['id'] == id)) {
        final error = await ChartEditorMcp.setField(ed, id, a['value']);
        if (error != null) {
          throw UiToolException('invalid_args', error);
        }
        await uiSettle();
        return UiToolResult({
          'set': id,
          'chart': ChartEditorMcp.describe(ed),
        }, text: 'Set $id');
      }
    }
    final error = p.setField(id, a['value']);
    if (error != null) {
      throw UiToolException(
        'invalid_args',
        error,
        details: {'panel': p.describe()},
      );
    }
    await uiSettle();
    final after = PanelDescriber.of(c.services);
    return UiToolResult({
      'set': id,
      'panel': after?.describe(),
    }, text: 'Set $id');
  }

  /// `ui.sheets.press_panel_button` (12 §5, P1).
  static Future<UiToolResult> pressPanelButton(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final p = _panel(c, a);
    final id = a['button_id']! as String;
    final error = p.press(id);
    if (error != null) {
      throw UiToolException(
        'invalid_args',
        error,
        details: {'panel': p.describe()},
      );
    }
    await uiSettle();
    c.events.add('panel', {'pressed': id, 'panel': p.panelId});
    final after = PanelDescriber.of(c.services);
    return UiToolResult({
      'pressed': id,
      'panel': after?.describe(),
    }, text: 'Pressed $id');
  }

  // ------------------------------------------------------------- editing

  static Future<SheetEditorController> _beginAt(
    UiToolContext c,
    String? cell,
    String? text,
  ) async {
    final ed = _editor(c);
    if (!ed.canEdit) {
      throw const UiToolException(
        'forbidden',
        'The spreadsheet cannot be edited in the current mode or role.',
      );
    }
    if (ed.editor.isEditing) ed.editor.cancel();
    if (cell != null) {
      final rr = _parse(ed, cell);
      if (rr.sheetId != ed.activeSheetId) ed.activateSheet(rr.sheetId);
      ed.selection.selectCell(rr.rect.top, rr.rect.left);
      _flash(c, ed, rr, duration: const Duration(seconds: 3));
    }
    ed.gridFocus.requestFocus();
    ed.editor.begin(initialText: text, mode: EditMode.edit);
    await uiSettle();
    if (!ed.editor.isEditing) {
      throw const UiToolException(
        'forbidden',
        'The cell cannot be edited (protected or a pivot/spill area).',
      );
    }
    return ed;
  }

  static Future<UiToolResult> startCellEdit(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = await _beginAt(
      c,
      a['cell'] as String?,
      a['initial_text'] as String?,
    );
    return UiToolResult({
      'cell': ed.activeA1,
      'editor_text': ed.editor.text.text,
    }, text: 'Editing ${ed.activeA1}');
  }

  static Future<UiToolResult> typeInCell(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = await _beginAt(c, a['cell']! as String, '');
    final text = a['text']! as String;
    // Through the field's text input, like typing (autocomplete updates).
    final field = ed.editor.text;
    for (final ch in text.characters) {
      final v = field.value;
      final next = v.text + ch;
      field.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
    await uiSettle();
    final commit = a['commit'] as String? ?? 'enter';
    final cell = ed.activeA1;
    var ok = true;
    if (commit != 'none') {
      ok = await ed.editor.commit(
        move: commit == 'tab' ? CommitMove.tab : CommitMove.enter,
      );
    }
    await uiSettle();
    if (!ok) {
      throw UiToolException(
        'rejected',
        'The input was rejected (data validation): ${ed.editor.text.text}',
      );
    }
    final rr = _parse(ed, cell);
    return UiToolResult({
      'cell': cell,
      'committed': commit != 'none',
      'display': ed.cells
          .displayAt(rr.sheetId, rr.rect.top, rr.rect.left)
          ?.text,
      'active_cell': ed.activeA1,
    }, text: 'Typed into $cell');
  }

  // ---------------------------------------------------------- screenshot

  static const _maxPx = 4000.0;

  static Future<UiToolResult> screenshotRange(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final rr = _parse(ed, a['range']! as String);
    final rect = _clip(ed, rr);
    final sheet = ed.model.sheet(rr.sheetId)!;
    final headers = a['include_headers'] == true;
    final scale = ((a['scale'] as num?) ?? 1).toDouble();
    final ctx = c.context;
    final live = ctx != null && ctx.mounted;
    final image = await renderRange(
      ed,
      sheet,
      rect,
      scale: scale,
      includeHeaders: headers,
      chartTokens: live ? chartUiTokensOf(ctx) : null,
      dark: live
          ? chartDarkOf(ctx)
          : WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark,
      tokens: switch (c.context) {
        final BuildContext ctx when ctx.mounted => GridPaintTokens.ofContext(
          ctx,
        ),
        _ => GridPaintTokens.of(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        ),
      },
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final w = image.width;
    final h = image.height;
    image.dispose();
    if (bytes == null) {
      throw const UiToolException('failed', 'Could not encode the image.');
    }
    _flash(c, ed, rr, duration: const Duration(seconds: 2));
    return UiToolResult(
      {'range': _rangeA1(ed, rr), 'width': w, 'height': h},
      text: 'Screenshot of ${_rangeA1(ed, rr)} ($w×$h)',
      imageBase64: base64Encode(bytes.buffer.asUint8List()),
    );
  }

  /// Paints [rect] of [sheet] offscreen with the grid's content layers
  /// (cells, formats, conditional formatting, borders) and the objects over
  /// it (charts through the chart painter, loaded images), independent of
  /// the scroll position; with [includeHeaders], row and column headers too.
  static Future<ui.Image> renderRange(
    SheetEditorController ed,
    SheetModel sheet,
    GridRect rect, {
    required GridPaintTokens tokens,
    double scale = 1,
    bool includeHeaders = false,
    ChartUiTokens? chartTokens,
    bool dark = false,
  }) async {
    final rows = sheet.rows;
    final cols = sheet.columns;
    final w = cols.offsetOf(rect.right + 1) - cols.offsetOf(rect.left);
    final h = rows.offsetOf(rect.bottom + 1) - rows.offsetOf(rect.top);
    if (w <= 0 || h <= 0) {
      throw const UiToolException('invalid_range', 'The range has no size.');
    }
    final frozenRows = sheet.record?.frozenRows ?? 0;
    final frozenCols = sheet.record?.frozenColumns ?? 0;
    // Scroll so that the range starts at the main pane's origin (or keep
    // 0 when it starts inside the frozen panes, which then show it).
    final scrollX = rect.left < frozenCols
        ? 0.0
        : cols.offsetOf(rect.left) - cols.offsetOf(frozenCols);
    final scrollY = rect.top < frozenRows
        ? 0.0
        : rows.offsetOf(rect.top) - rows.offsetOf(frozenRows);
    final probe = GridGeometry(
      sheet: sheet,
      size: const Size(1, 1),
      zoom: 1,
      scrollX: scrollX,
      scrollY: scrollY,
      devicePixelRatio: scale,
    );
    final cropLeft = rect.left < frozenCols
        ? probe.rowHeaderWidth + cols.offsetOf(rect.left)
        : probe.rowHeaderWidth + probe.frozenWidth;
    final cropTop = rect.top < frozenRows
        ? probe.colHeaderHeight + rows.offsetOf(rect.top)
        : probe.colHeaderHeight + probe.frozenHeight;
    final full = Size(cropLeft + w + 1, cropTop + h + 1);
    final g = GridGeometry(
      sheet: sheet,
      size: full,
      zoom: 1,
      scrollX: scrollX,
      scrollY: scrollY,
      devicePixelRatio: scale,
    );
    final hw = includeHeaders ? g.rowHeaderWidth : 0.0;
    final hh = includeHeaders ? g.colHeaderHeight : 0.0;
    final outW = w + hw;
    final outH = h + hh;
    final fit = math.min(1.0, _maxPx / math.max(outW * scale, outH * scale));
    final pr = scale * fit;
    if (pr < 0.1) {
      throw const UiToolException(
        'limit_exceeded',
        'The range is too large for a screenshot (max 4,000 × 4,000 px).',
      );
    }
    final layers = <GridLayer>[
      ...coreContentLayers(),
      ...ed.layers.content,
      if (includeHeaders) const HeaderLayer(),
    ]..sort((x, y) => x.zOrder.compareTo(y.zOrder));
    final ctx = GridPaintContext(controller: ed, geometry: g, tokens: tokens);

    // The whole frame, then the cropped pieces.
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.clipRect(Offset.zero & full);
    for (final l in layers) {
      l.paint(ctx, canvas);
    }
    _paintObjects(
      ed,
      sheet,
      canvas,
      g,
      scrollX: scrollX,
      scrollY: scrollY,
      chartTokens:
          chartTokens ??
          ChartUiTokens(
            card: tokens.sheetBackground.toARGB32(),
            foreground: tokens.autoText.toARGB32(),
            border: tokens.gridLine.toARGB32(),
          ),
      dark: dark,
    );
    final frame = rec.endRecording();

    final out = ui.PictureRecorder();
    final oc = Canvas(out);
    oc.scale(pr);
    void piece(Rect src, Offset dst) {
      oc.save();
      oc.translate(dst.dx - src.left, dst.dy - src.top);
      oc.clipRect(src);
      oc.drawPicture(frame);
      oc.restore();
    }

    final cells = Rect.fromLTWH(cropLeft, cropTop, w, h);
    if (includeHeaders) {
      piece(Rect.fromLTWH(0, 0, hw, hh), Offset.zero);
      piece(Rect.fromLTWH(cropLeft, 0, w, hh), Offset(hw, 0));
      piece(Rect.fromLTWH(0, cropTop, hw, h), Offset(0, hh));
    }
    piece(cells, Offset(hw, hh));
    final picture = out.endRecording();
    final image = await picture.toImage(
      math.max(1, (outW * pr).ceil()),
      math.max(1, (outH * pr).ceil()),
    );
    picture.dispose();
    frame.dispose();
    return image;
  }

  /// Paints the charts and images of [sheet] into the offscreen grid frame
  /// of [g] (objects are widgets on screen, 08 §9).
  static void _paintObjects(
    SheetEditorController ed,
    SheetModel sheet,
    Canvas canvas,
    GridGeometry g, {
    required double scrollX,
    required double scrollY,
    required ChartUiTokens chartTokens,
    required bool dark,
  }) {
    final objects = ObjectsController.maybeOf(ed);
    if (objects == null) return;
    final frozenX = sheet.columns.offsetOf(sheet.record?.frozenColumns ?? 0);
    final frozenY = sheet.rows.offsetOf(sheet.record?.frozenRows ?? 0);
    for (final o in objects.objectsOn(sheet.id)) {
      final r = objects.rectOf(o, ghost: false);
      if (r == null || r.width <= 0 || r.height <= 0) continue;
      final x = g.rowHeaderWidth + r.left - (r.left >= frozenX ? scrollX : 0);
      final y = g.colHeaderHeight + r.top - (r.top >= frozenY ? scrollY : 0);
      final box = Rect.fromLTWH(x, y, r.width, r.height);
      canvas.save();
      canvas.clipRect(box);
      try {
        switch (o.kind) {
          case EmbeddedObjectKind.chart:
            final scene = objects
                .chartOf(o)
                .sceneFor(r.width, r.height, dark: dark, tokens: chartTokens);
            canvas.translate(x, y);
            paintChartScene(canvas, scene);
          case EmbeddedObjectKind.image:
            final spec = ImageSpec.fromJson(o.specJson);
            final src = spec.fileUuid.isNotEmpty
                ? spec.fileUuid
                : (spec.sourceUrl ?? '');
            final img = src.isEmpty
                ? null
                : SheetsImageService.of(ed).decoded(src);
            if (img != null) {
              paintImage(
                canvas: canvas,
                rect: box,
                image: img,
                fit: boxFitOf(spec.fit),
                filterQuality: FilterQuality.medium,
              );
            } else {
              canvas.drawRect(
                box,
                Paint()
                  ..color = Color(chartTokens.border).withValues(alpha: 0.4),
              );
            }
          default:
            break;
        }
      } on Object catch (e) {
        debugPrint('Screenshot: painting object ${o.id} failed: $e');
      }
      canvas.restore();
    }
  }

  // ------------------------------------------------------------- misc

  static Future<UiToolResult> highlightRange(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final rr = _parse(ed, a['range']! as String);
    if (rr.sheetId != ed.activeSheetId) ed.activateSheet(rr.sheetId);
    final rect = _clip(ed, rr);
    ed.revealCell(rect.top, rect.left);
    final color = _color(a['color'] as String?);
    final ms = (a['duration_ms'] as num?)?.toInt() ?? 3000;
    _flash(
      c,
      ed,
      rr,
      duration: Duration(milliseconds: ms),
      color: color ?? AgentHighlightLayer.agentColor,
    );
    await uiSettle();
    return UiToolResult({
      'range': _rangeA1(ed, rr),
      'duration_ms': ms,
    }, text: 'Highlighted ${_rangeA1(ed, rr)}');
  }

  static Color? _color(String? hex) {
    if (hex == null || hex.length != 7) return null;
    final v = int.tryParse(hex.substring(1), radix: 16);
    return v == null ? null : Color(0xff000000 | v);
  }

  static Future<UiToolResult> waitForRecalc(
    UiToolContext c,
    Map<String, Object?> a,
  ) async {
    final ed = _editor(c);
    final timeout = Duration(
      milliseconds: (a['timeout_ms'] as num?)?.toInt() ?? 10000,
    );
    final sw = Stopwatch()..start();
    var idle = ed.engine.isIdle;
    while (!idle && sw.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      idle = ed.engine.isIdle;
    }
    if (idle) {
      await ed.session.flush().timeout(
        timeout - sw.elapsed > Duration.zero
            ? timeout - sw.elapsed
            : Duration.zero,
        onTimeout: () {},
      );
    }
    return UiToolResult({
      'idle': idle,
      'pending': ed.engine.pendingCount,
      'waited_ms': sw.elapsedMilliseconds,
    }, text: idle ? 'Idle' : 'Still calculating');
  }
}
