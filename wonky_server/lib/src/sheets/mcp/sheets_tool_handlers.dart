import 'package:wonky_core/wonky_core.dart'
    show DriveTools, McpToolDefinition, Role, SheetsTools;
import 'package:wonky_sheets_core/model.dart' show Dimension;

import '../../platform/drive/drive_service.dart';
import '../../platform/drive/templates/builtin_templates.dart';
import '../../platform/mcp/drive_tool_handlers.dart';
import '../../platform/mcp/tool_executor.dart';
import '../../platform/mcp/tool_support.dart';
import 'sheets_mcp_support.dart';
import 'sheets_object_handlers.dart';
import 'sheets_read_handlers.dart';
import 'sheets_rule_handlers.dart';
import 'sheets_structure_handlers.dart';
import 'sheets_value_handlers.dart';

/// The headless `sheets.*` tools (Sheets 12 §3) plus the handler of
/// `drive.create_spreadsheet`, registered in the MCP server like Write's
/// tools.
abstract final class SheetsToolHandlers {
  static List<RegisteredMcpTool> get all => [
    _t(DriveTools.createSpreadsheet, createSpreadsheet),
    _t(SheetsTools.getSpreadsheet, SheetsReadHandlers.getSpreadsheet),
    _t(SheetsTools.describeData, SheetsReadHandlers.describeData),
    _t(SheetsTools.getValues, SheetsReadHandlers.getValues),
    _t(SheetsTools.setValues, SheetsValueHandlers.setValues),
    _t(SheetsTools.batchSetValues, SheetsValueHandlers.batchSetValues),
    _t(SheetsTools.appendRows, SheetsValueHandlers.appendRows),
    _t(SheetsTools.clearRange, SheetsValueHandlers.clearRange),
    _t(SheetsTools.formatRange, SheetsStructureHandlers.formatRange),
    _t(SheetsTools.clearFormats, SheetsStructureHandlers.clearFormats),
    _t(SheetsTools.applyBanding, SheetsStructureHandlers.applyBanding),
    _t(
      SheetsTools.insertRows,
      (c, a) => SheetsStructureHandlers.insertDimension(c, a, Dimension.rows),
    ),
    _t(
      SheetsTools.deleteRows,
      (c, a) => SheetsStructureHandlers.deleteDimension(c, a, Dimension.rows),
    ),
    _t(
      SheetsTools.insertColumns,
      (c, a) =>
          SheetsStructureHandlers.insertDimension(c, a, Dimension.columns),
    ),
    _t(
      SheetsTools.deleteColumns,
      (c, a) =>
          SheetsStructureHandlers.deleteDimension(c, a, Dimension.columns),
    ),
    _t(SheetsTools.moveDimension, SheetsStructureHandlers.moveDimension),
    _t(SheetsTools.resizeDimension, SheetsStructureHandlers.resizeDimension),
    _t(SheetsTools.hideDimension, SheetsStructureHandlers.hideDimension),
    _t(SheetsTools.setFrozen, SheetsStructureHandlers.setFrozen),
    _t(SheetsTools.addSheet, SheetsStructureHandlers.addSheet),
    _t(SheetsTools.renameSheet, SheetsStructureHandlers.renameSheet),
    _t(SheetsTools.deleteSheet, SheetsStructureHandlers.deleteSheet),
    _t(SheetsTools.duplicateSheet, SheetsStructureHandlers.duplicateSheet),
    _t(SheetsTools.reorderSheet, SheetsStructureHandlers.reorderSheet),
    _t(
      SheetsTools.setSheetProperties,
      SheetsStructureHandlers.setSheetProperties,
    ),
    _t(SheetsTools.mergeCells, SheetsStructureHandlers.mergeCells),
    _t(SheetsTools.unmergeCells, SheetsStructureHandlers.unmergeCells),
    _t(SheetsTools.sortRange, SheetsValueHandlers.sortRange),
    _t(SheetsTools.setBasicFilter, SheetsRuleHandlers.setBasicFilter),
    _t(SheetsTools.clearFilter, SheetsRuleHandlers.clearFilter),
    _t(SheetsTools.createFilterView, SheetsRuleHandlers.createFilterView),
    _t(SheetsTools.listFilterViews, SheetsReadHandlers.listFilterViews),
    _t(SheetsTools.deleteFilterView, SheetsRuleHandlers.deleteFilterView),
    _t(
      SheetsTools.addConditionalFormat,
      SheetsRuleHandlers.addConditionalFormat,
    ),
    _t(
      SheetsTools.listConditionalFormats,
      SheetsReadHandlers.listConditionalFormats,
    ),
    _t(
      SheetsTools.updateConditionalFormat,
      SheetsRuleHandlers.updateConditionalFormat,
    ),
    _t(
      SheetsTools.deleteConditionalFormat,
      SheetsRuleHandlers.deleteConditionalFormat,
    ),
    _t(SheetsTools.setDataValidation, SheetsRuleHandlers.setDataValidation),
    _t(SheetsTools.createNamedRange, SheetsRuleHandlers.createNamedRange),
    _t(SheetsTools.listNamedRanges, SheetsReadHandlers.listNamedRanges),
    _t(SheetsTools.updateNamedRange, SheetsRuleHandlers.updateNamedRange),
    _t(SheetsTools.deleteNamedRange, SheetsRuleHandlers.deleteNamedRange),
    _t(SheetsTools.protectRange, SheetsRuleHandlers.protectRange),
    _t(SheetsTools.listProtections, SheetsReadHandlers.listProtections),
    _t(SheetsTools.unprotect, SheetsRuleHandlers.unprotect),
    _t(SheetsTools.createChart, SheetsObjectHandlers.createChart),
    _t(SheetsTools.updateChart, SheetsObjectHandlers.updateChart),
    _t(SheetsTools.deleteChart, SheetsObjectHandlers.deleteChart),
    _t(SheetsTools.getChart, SheetsObjectHandlers.getChart),
    _t(SheetsTools.exportChartPng, SheetsObjectHandlers.exportChartPng),
    _t(SheetsTools.createPivotTable, SheetsObjectHandlers.createPivotTable),
    _t(SheetsTools.updatePivotTable, SheetsObjectHandlers.updatePivotTable),
    _t(SheetsTools.deletePivotTable, SheetsObjectHandlers.deletePivotTable),
    _t(SheetsTools.find, SheetsReadHandlers.find),
    _t(SheetsTools.findReplace, SheetsValueHandlers.findReplace),
    _t(SheetsTools.evaluate, SheetsReadHandlers.evaluate),
    _t(SheetsTools.validateFormula, SheetsReadHandlers.validateFormulaTool),
    _t(SheetsTools.explainFormula, SheetsReadHandlers.explainFormula),
    _t(SheetsTools.getCell, SheetsReadHandlers.getCell),
    _t(SheetsTools.getCellHistory, SheetsReadHandlers.getCellHistory),
    _t(SheetsTools.importCsv, SheetsValueHandlers.importCsv),
  ];

  static RegisteredMcpTool _t(McpToolDefinition d, ToolHandler h) =>
      RegisteredMcpTool(d, h);

  /// `drive.create_spreadsheet` (suite 09 §4): an empty spreadsheet (or a
  /// template copy) whose named sheets are then filled with `values`
  /// through the same pipeline as `sheets.set_values`.
  static Future<ToolResult> createSpreadsheet(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final sheets = (a.list('sheets') ?? const []).cast<Map<String, dynamic>>();
    final name = a.requireString('name');
    final template = a.uuid('template_uuid');
    final view = sheets.isEmpty || template != null
        ? await DriveService.createSpreadsheet(
            ctx.session,
            ctx.actor,
            parentUuid: a.uuid('parent_uuid'),
            name: name,
            templateUuid: template,
          )
        : await DriveService.createSpreadsheetFromSheets(
            ctx.session,
            ctx.actor,
            name: name,
            parentUuid: a.uuid('parent_uuid'),
            sheets: [
              for (final s in sheets)
                TemplateSheet(
                  name: '${s['name']}',
                  rows: const [],
                  boldRows: const {},
                  frozenRows: 0,
                ),
            ],
            summary: {'via': 'mcp'},
          );
    String? changeId;
    final withValues = [
      for (final s in sheets)
        if (s['values'] is List && (s['values'] as List).isNotEmpty) s,
    ];
    if (withValues.isNotEmpty && template == null) {
      final data = [
        for (final s in withValues)
          {
            'range': "'${'${s['name']}'.replaceAll("'", "''")}'!A1",
            'values': s['values'],
          },
      ];
      final r = await SheetsValueHandlers.batchSetValues(
        ctx,
        ToolArgs({'spreadsheet': view.uuid.uuid, 'data': data}),
      );
      changeId = (r.structured as Map?)?['change_id'] as String?;
    }
    final t = await SheetsMcp.resolveItem(
      ctx.session,
      ctx,
      view.uuid.uuid,
      min: Role.viewer,
    );
    return ToolResult(
      {
        'item': DriveToolHandlers.itemJson(view),
        'spreadsheet': t.$1.uuid.uuid,
        'change_id': changeId,
      },
      text: 'Created spreadsheet "${view.name}" (${view.uuid.uuid})',
    );
  }
}
