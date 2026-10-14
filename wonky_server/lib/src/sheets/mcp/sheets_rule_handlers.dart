import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput;
import 'package:wonky_sync_models/ids.dart' show FractionalIndex;

import '../../platform/common/models.dart';
import '../../platform/mcp/drive_tool_handlers.dart';
import '../../platform/mcp/tool_support.dart';
import '../../platform/sharing/access_service.dart';
import 'sheets_mcp_support.dart';
import 'sheets_structure_handlers.dart';
import 'sheets_writes.dart';

/// Filters, conditional formatting, data validation, named ranges and
/// protections (Sheets 12 §3.7–3.9).
abstract final class SheetsRuleHandlers {
  static ToolResult _result(
    SheetsWriteOutcome o,
    String summary, [
    Map<String, Object?> extra = const {},
  ]) {
    final id = o.changeId?.uuid;
    return ToolResult(
      {...extra, ...o.toJson(), 'summary': summary},
      text:
          '$summary'
          '${o.preview ? ' (suggested, not applied)' : ''}'
          '${id == null ? '' : ' · change_id $id'}'
          '${o.warnings.isEmpty ? '' : '\nWarnings: ${o.warnings.join(' ')}'}',
    );
  }

  static SheetsPlanStep _op(SheetsOperation Function() op) =>
      (model, pctx) => SheetsWrites.planner.plan(op(), model, pctx);

  // ----------------------------------------------------------- conditions

  /// `NUMBER_GREATER` / `number_greater` / `numberGreater` → a
  /// [ConditionType].
  static ConditionType conditionType(String raw) {
    var id = raw.trim();
    if (id.contains('_') || id == id.toUpperCase()) {
      final parts = id.toLowerCase().split('_').where((p) => p.isNotEmpty);
      id = [
        for (final (i, p) in parts.indexed)
          i == 0 ? p : '${p[0].toUpperCase()}${p.substring(1)}',
      ].join();
    }
    id = switch (id) {
      'numberGreaterThanEq' || 'numberGreaterThanOrEqual' => 'numberGreaterEq',
      'numberLessThanEq' || 'numberLessThanOrEqual' => 'numberLessEq',
      'numberGreaterThan' => 'numberGreater',
      'numberLessThan' => 'numberLess',
      'numberEqual' => 'numberEq',
      'numberNotEqual' => 'numberNotEq',
      'textEqual' => 'textEq',
      'email' || 'textEmail' => 'textIsEmail',
      'url' || 'textUrl' => 'textIsUrl',
      'dateIsBefore' => 'dateBefore',
      'dateIsAfter' => 'dateAfter',
      'isBlank' => 'blank',
      'isNotBlank' || 'notEmpty' => 'notBlank',
      'formula' => 'customFormula',
      _ => id,
    };
    final t = ConditionType.byId(id);
    if (t == null) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'Unknown condition type "$raw".',
      );
    }
    return t;
  }

  /// The stored condition JSON of a tool condition `{type, values}`;
  /// formula values are relative to ([row], [col]) of [sheetId].
  static Map<String, Object?> conditionJson(
    SheetsTarget t,
    Map<String, dynamic> c, {
    required String sheetId,
    required int row,
    required int col,
    ConditionUse? use,
  }) {
    final type = conditionType('${c['type']}');
    if (use != null && !type.usableIn(use)) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'The condition ${c['type']} is not available here.',
      );
    }
    final raw = [for (final v in (c['values'] as List?) ?? const []) '$v'];
    if (raw.length < type.arity) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        '${c['type']} needs ${type.arity} value(s).',
      );
    }
    return {
      'type': type.id,
      'values': [
        for (final v in raw.take(type.arity == 0 ? 0 : type.arity))
          _conditionValue(t, v, type, sheetId: sheetId, row: row, col: col),
      ],
    };
  }

  static Map<String, Object?> _conditionValue(
    SheetsTarget t,
    String v,
    ConditionType type, {
    required String sheetId,
    required int row,
    required int col,
  }) {
    if (type.acceptsRelativeDates) {
      final rel = RelativeDate.byName(
        v
            .toLowerCase()
            .split('_')
            .indexed
            .map(
              (e) => e.$1 == 0
                  ? e.$2
                  : '${e.$2[0].toUpperCase()}${e.$2.substring(1)}',
            )
            .join(),
      );
      if (rel != null) return {'rel': rel.name};
    }
    if (v.length > 1 && v.startsWith('=')) {
      final check = validateFormula(v);
      if (!check.ok) {
        throw McpToolException(
          SheetsErrorCode.formulaParseError,
          check.error?.message ?? 'Formula parse error.',
          details: {'formula': v},
        );
      }
      final stored = t.wb.hooks.toStored(
        v,
        sheetId: sheetId,
        row: row,
        col: col,
      );
      return {'v': stored.startsWith('=') ? stored : '=$stored'};
    }
    return {'v': v};
  }

  // ---------------------------------------------------------- filters

  static (String?, String?) _filterJson(
    SheetsTarget t,
    SheetModel s,
    GridRect rect,
    Map<String, dynamic>? criteria,
    Map<String, dynamic>? sort,
  ) {
    String? criteriaJson;
    if (criteria != null && criteria.isNotEmpty) {
      final out = <String, Object?>{};
      for (final e in criteria.entries) {
        final col = SheetsMcp.index(e.key, name: 'criteria key');
        if (col < rect.left || col > rect.right) {
          throw SheetsMcp.invalidRange(
            'Filter column ${e.key} is outside ${rect.a1}.',
          );
        }
        final spec = (e.value as Map).cast<String, dynamic>();
        out[s.columns.idAt(col)] = {
          if (spec['hidden_values'] is List)
            'hiddenValues': [
              for (final v in spec['hidden_values'] as List) '$v',
            ],
          if (spec['condition'] is Map)
            'condition': conditionJson(
              t,
              (spec['condition'] as Map).cast<String, dynamic>(),
              sheetId: s.id,
              row: rect.top + 1,
              col: col,
              use: ConditionUse.filter,
            ),
        };
      }
      criteriaJson = jsonEncode(out);
    }
    String? sortJson;
    if (sort != null) {
      final col = SheetsMcp.index(sort['column'], name: 'sort.column');
      sortJson = jsonEncode([
        {'colId': s.columns.idAt(col), 'ascending': sort['ascending'] != false},
      ]);
    }
    return (criteriaJson, sortJson);
  }

  static Future<ToolResult> setBasicFilter(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final r = SheetsMcp.range(t, a.requireString('range'));
    final s = t.model.sheet(r.sheetId)!;
    final rect = SheetsMcp.clipToUsed(s, r);
    final (criteria, sort) = _filterJson(
      t,
      s,
      rect,
      a.object('criteria'),
      a.object('sort'),
    );
    final a1 = SheetsMcp.a1(t.model, s.id, rect);
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.set_basic_filter',
      label: SheetsMcp.label(ctx, 'sheets.set_basic_filter', a1),
      ranges: [a1],
      structural: 'Filter $a1',
      intents: (model) => [FilterWrite(s.id, rect)],
      steps: [
        _op(
          () => SetBasicFilter(
            s.id,
            rect,
            criteriaJson: criteria,
            sortJson: sort,
          ),
        ),
      ],
    );
    return _result(o, 'Set the filter of "${s.name}" on $a1');
  }

  static Future<ToolResult> clearFilter(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final s = SheetsMcp.sheet(t, a.requireString('sheet'));
    final f = s.basicFilter;
    if (f == null) {
      throw McpToolException(
        McpErrorCode.notFound,
        '"${s.name}" has no filter.',
      );
    }
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.clear_filter',
      label: SheetsMcp.label(ctx, 'sheets.clear_filter', s.name),
      structural: 'Remove the filter of "${s.name}"',
      intents: (model) => [
        if (s.gridRect != null) FilterWrite(s.id, s.gridRect!),
      ],
      steps: [_op(() => RemoveBasicFilter(s.id))],
    );
    return _result(o, 'Removed the filter of "${s.name}"');
  }

  static Future<ToolResult> createFilterView(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final r = SheetsMcp.range(t, a.requireString('range'));
    final s = t.model.sheet(r.sheetId)!;
    final rect = SheetsMcp.clipToUsed(s, r);
    final (criteria, sort) = _filterJson(
      t,
      s,
      rect,
      a.object('criteria'),
      a.object('sort'),
    );
    final name = a.requireString('name');
    final id = const Uuid().v7();
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.create_filter_view',
      label: SheetsMcp.label(ctx, 'sheets.create_filter_view', '"$name"'),
      structural: 'Create filter view "$name"',
      steps: [
        _op(
          () => CreateFilterView(
            s.id,
            rect,
            name: name,
            criteriaJson: criteria,
            sortJson: sort,
            viewId: id,
          ),
        ),
      ],
    );
    return _result(o, 'Created filter view "$name"', {
      'filter_view_id': id,
      'url': '${t.url(DriveToolHandlers.webBase)}?fv=$id',
    });
  }

  static Future<ToolResult> deleteFilterView(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('filter_view_id');
    final rec = t.model.record(SheetsTables.filterView, id);
    if (rec == null) {
      throw McpToolException(McpErrorCode.notFound, 'No filter view $id.');
    }
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.delete_filter_view',
      label: SheetsMcp.label(ctx, 'sheets.delete_filter_view', id),
      structural: 'Delete a filter view',
      steps: [_op(() => DeleteFilterView(id))],
    );
    return _result(o, 'Deleted the filter view');
  }

  // ---------------------------------------------- conditional formatting

  static (SheetModel, List<GridRect>) _ruleRanges(
    SheetsTarget t,
    List<String> ranges,
  ) {
    SheetModel? sheet;
    final rects = <GridRect>[];
    for (final a1 in ranges) {
      final r = SheetsMcp.range(t, a1, contextSheetId: sheet?.id);
      if (sheet != null && r.sheetId != sheet.id) {
        throw SheetsMcp.invalidRange(
          'All ranges of a rule must be on one sheet.',
        );
      }
      sheet ??= t.model.sheet(r.sheetId);
      rects.add(r.rect);
    }
    return (sheet!, rects);
  }

  static String cfRuleJson(
    SheetsTarget t,
    Map<String, dynamic> rule,
    SheetModel s,
    GridRect anchor,
  ) {
    final type = rule['type'];
    if (type == 'color_scale' || type == 'colorScale') {
      Map<String, Object?>? point(String key) {
        final p = (rule[key] as Map?)?.cast<String, dynamic>();
        if (p == null) return null;
        final kind = CfValueKind.byName(p['type']);
        if (kind == null) {
          throw McpToolException(
            McpErrorCode.invalidArgs,
            '$key.type must be min, max, number, percent or percentile.',
          );
        }
        return {
          'kind': kind.name,
          if (p['value'] != null) 'value': '${p['value']}',
          'color': SheetsStructureHandlers.color(p['color'], '$key.color'),
        };
      }

      final min = point('min_point');
      final max = point('max_point');
      if (min == null || max == null) {
        throw McpToolException(
          McpErrorCode.invalidArgs,
          'A color scale needs min_point and max_point.',
        );
      }
      return jsonEncode({
        'v': 1,
        'type': 'colorScale',
        'points': [min, ?point('mid_point'), max],
      });
    }
    final condition = (rule['condition'] as Map?)?.cast<String, dynamic>();
    if (condition == null) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'A boolean rule needs a condition.',
      );
    }
    final f = (rule['format'] as Map?)?.cast<String, dynamic>() ?? const {};
    return jsonEncode({
      'v': 1,
      'type': 'boolean',
      'condition': conditionJson(
        t,
        condition,
        sheetId: s.id,
        row: anchor.top,
        col: anchor.left,
        use: ConditionUse.conditionalFormat,
      ),
      'format': {
        if (f['bold'] != null) 'bold': f['bold'],
        if (f['italic'] != null) 'italic': f['italic'],
        if (f['underline'] != null) 'underline': f['underline'],
        if (f['strikethrough'] != null) 'strikethrough': f['strikethrough'],
        if (f['text_color'] != null)
          'textColor': SheetsStructureHandlers.color(
            f['text_color'],
            'text_color',
          ),
        if (f['fill_color'] != null)
          'fillColor': SheetsStructureHandlers.color(
            f['fill_color'],
            'fill_color',
          ),
      },
      'stopIfTrue': true,
    });
  }

  static List<CfRuleRecord> _orderedRules(SheetModel s) =>
      s.cfRules.values.toList()..sort(
        (a, b) => FractionalIndex.compare(a.sortKey, a.id, b.sortKey, b.id),
      );

  static Future<ToolResult> addConditionalFormat(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final (s, rects) = _ruleRanges(t, a.list('ranges')!.cast<String>());
    final ruleJson = cfRuleJson(t, a.object('rule')!, s, rects.first);
    final ordered = _orderedRules(s);
    final index = a.integer('index') ?? 0;
    final before = index < ordered.length ? ordered[index].id : null;
    final id = const Uuid().v7();
    final a1s = [for (final r in rects) SheetsMcp.a1(t.model, s.id, r)];
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.add_conditional_format',
      label: SheetsMcp.label(
        ctx,
        'sheets.add_conditional_format',
        a1s.join(', '),
      ),
      ranges: a1s,
      structural: 'Add conditional formatting to ${a1s.join(', ')}',
      intents: (model) => [RuleWrite(s.id, RuleKind.conditionalFormat, rects)],
      steps: [
        _op(
          () => AddCfRule(
            s.id,
            rects,
            ruleJson,
            beforeRuleId: before,
            ruleId: id,
          ),
        ),
      ],
    );
    return _result(o, 'Added a conditional format rule to ${a1s.join(', ')}', {
      'rule_id': id,
    });
  }

  static CfRuleRecord _cfRule(SheetsTarget t, String id) {
    for (final s in t.model.sheets) {
      final r = s.cfRules[id];
      if (r != null) return r;
    }
    throw McpToolException(
      McpErrorCode.notFound,
      'No conditional format rule $id.',
    );
  }

  static Future<ToolResult> updateConditionalFormat(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('rule_id');
    final rec = _cfRule(t, id);
    final s = t.model.sheet(rec.sheetId)!;
    List<GridRect>? rects;
    if (a.has('ranges')) {
      final (rs, rr) = _ruleRanges(t, a.list('ranges')!.cast<String>());
      if (rs.id != s.id) {
        throw SheetsMcp.invalidRange('A rule cannot move to another sheet.');
      }
      rects = rr;
    }
    final anchor =
        rects?.first ?? s.ruleRects(RuleKind.conditionalFormat, id).firstOrNull;
    final ruleJson = a.has('rule')
        ? cfRuleJson(t, a.object('rule')!, s, anchor ?? GridRect.cell(0, 0))
        : null;
    final enabled = a.boolean('enabled');
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.update_conditional_format',
      label: SheetsMcp.label(ctx, 'sheets.update_conditional_format', id),
      structural: 'Change a conditional format rule',
      intents: (model) => [
        if (rects != null) RuleWrite(s.id, RuleKind.conditionalFormat, rects),
      ],
      steps: [
        if (rects != null || ruleJson != null)
          _op(() => UpdateCfRule(id, ranges: rects, ruleJson: ruleJson)),
        if (enabled != null) _op(() => SetCfEnabled(id, enabled: enabled)),
      ],
    );
    return _result(o, 'Updated the conditional format rule', {'rule_id': id});
  }

  static Future<ToolResult> deleteConditionalFormat(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('rule_id');
    _cfRule(t, id);
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.delete_conditional_format',
      label: SheetsMcp.label(ctx, 'sheets.delete_conditional_format', id),
      structural: 'Delete a conditional format rule',
      steps: [_op(() => DeleteCfRule(id))],
    );
    return _result(o, 'Deleted the conditional format rule');
  }

  // ---------------------------------------------------- data validation

  static Future<ToolResult> setDataValidation(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final (s, rects) = _ruleRanges(t, a.list('ranges')!.cast<String>());
    final criteria = a.object('criteria');
    String? criteriaJson;
    if (criteria != null) {
      criteriaJson = jsonEncode(_dvCriteria(t, criteria, s, rects.first));
    }
    var displayStyle = a.string('display_style');
    if (a.boolean('show_dropdown') == false) displayStyle = 'plain';
    final a1s = [for (final r in rects) SheetsMcp.a1(t.model, s.id, r)];
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.set_data_validation',
      label: SheetsMcp.label(ctx, 'sheets.set_data_validation', a1s.join(', ')),
      ranges: a1s,
      structural: criteria == null
          ? 'Remove data validation from ${a1s.join(', ')}'
          : 'Data validation on ${a1s.join(', ')}',
      intents: (model) => [RuleWrite(s.id, RuleKind.dataValidation, rects)],
      steps: [
        _op(
          () => SetDataValidation(
            s.id,
            rects,
            criteriaJson,
            strict: a.boolean('strict') ?? false,
            displayStyle: displayStyle,
            helpText: a.string('help_text'),
          ),
        ),
      ],
    );
    return _result(
      o,
      criteria == null
          ? 'Removed data validation from ${a1s.join(', ')}'
          : 'Set data validation on ${a1s.join(', ')}',
      {if (o.result['ruleId'] != null) 'rule_id': o.result['ruleId']},
    );
  }

  static Map<String, Object?> _dvCriteria(
    SheetsTarget t,
    Map<String, dynamic> c,
    SheetModel s,
    GridRect anchor,
  ) {
    final type = '${c['type']}'.trim();
    final values = [for (final v in (c['values'] as List?) ?? const []) '$v'];
    switch (type) {
      case 'list_of_items' || 'one_of_list' || 'oneOfList':
        if (values.isEmpty) {
          throw McpToolException(
            McpErrorCode.invalidArgs,
            'list_of_items needs values (the items).',
          );
        }
        return {
          'type': 'oneOfList',
          'options': [
            for (final v in values) {'value': v},
          ],
          'allowMultiple': false,
        };
      case 'list_from_range' || 'one_of_range' || 'oneOfRange':
        if (values.isEmpty) {
          throw McpToolException(
            McpErrorCode.invalidArgs,
            'list_from_range needs values: ["Sheet1!A2:A20"].',
          );
        }
        final r = SheetsMcp.range(t, values.first, contextSheetId: s.id);
        final rs = t.model.sheet(r.sheetId)!;
        return {
          'type': 'oneOfRange',
          'range': rs
              .gridRange(
                r.rect,
                wholeRows: r.wholeRows,
                wholeColumns: r.wholeColumns,
              )
              .toJson(),
          'allowMultiple': false,
        };
      case 'checkbox':
        return {
          'type': 'checkbox',
          if (c['checked_value'] != null) 'checked': '${c['checked_value']}',
          if (c['unchecked_value'] != null)
            'unchecked': '${c['unchecked_value']}',
        };
    }
    return conditionJson(
      t,
      {'type': type, 'values': values},
      sheetId: s.id,
      row: anchor.top,
      col: anchor.left,
      use: ConditionUse.dataValidation,
    );
  }

  // --------------------------------------------------------- named ranges

  static NamedRangeRecord _named(SheetsTarget t, String name) {
    final n = t.model.namedRange(name);
    if (n == null) {
      throw McpToolException(McpErrorCode.notFound, 'No named range "$name".');
    }
    return n;
  }

  static Future<ToolResult> createNamedRange(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final name = a.requireString('name').trim();
    if (t.model.namedRange(name) != null) {
      throw McpToolException(
        SheetsErrorCode.duplicateName,
        'The name "$name" is already used.',
      );
    }
    final range = a.has('range')
        ? SheetsMcp.range(t, a.string('range')!)
        : null;
    String? formula;
    if (range == null) {
      final f = a.string('formula');
      if (f == null) {
        throw McpToolException(
          McpErrorCode.invalidArgs,
          'Pass range or formula.',
        );
      }
      final text = f.startsWith('=') ? f : '=$f';
      final check = validateFormula(text);
      if (!check.ok) {
        throw McpToolException(
          SheetsErrorCode.formulaParseError,
          check.error?.message ?? 'Formula parse error.',
        );
      }
      final first = t.model.sheets.first;
      formula = t.wb.hooks.toStored(text, sheetId: first.id, row: 0, col: 0);
    }
    final id = const Uuid().v7();
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.create_named_range',
      label: SheetsMcp.label(ctx, 'sheets.create_named_range', name),
      structural: 'Name "$name"',
      steps: [
        _op(() => AddNamedRange(name, range: range, formula: formula, id: id)),
      ],
    );
    return _result(o, 'Created the named range "$name"', {
      'named_range_id': id,
    });
  }

  static Future<ToolResult> updateNamedRange(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final n = _named(t, a.requireString('name'));
    final newName = a.string('new_name')?.trim();
    if (newName != null) {
      final other = t.model.namedRange(newName);
      if (other != null && other.id != n.id) {
        throw McpToolException(
          SheetsErrorCode.duplicateName,
          'The name "$newName" is already used.',
        );
      }
    }
    final range = a.has('range')
        ? SheetsMcp.range(t, a.string('range')!)
        : null;
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.update_named_range',
      label: SheetsMcp.label(ctx, 'sheets.update_named_range', n.name),
      structural: 'Change the named range "${n.name}"',
      steps: [_op(() => UpdateNamedRange(n.id, name: newName, range: range))],
    );
    return _result(o, 'Updated the named range "${newName ?? n.name}"');
  }

  static Future<ToolResult> deleteNamedRange(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final n = _named(t, a.requireString('name'));
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.delete_named_range',
      label: SheetsMcp.label(ctx, 'sheets.delete_named_range', n.name),
      structural: 'Delete the named range "${n.name}"',
      steps: [_op(() => DeleteNamedRange(n.id))],
    );
    return _result(o, 'Deleted the named range "${n.name}"');
  }

  // ---------------------------------------------------------- protections

  static Future<ToolResult> protectRange(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    SheetModel s;
    GridRect? rect;
    if (a.has('range')) {
      final r = SheetsMcp.range(t, a.string('range')!);
      s = t.model.sheet(r.sheetId)!;
      rect = r.rect;
    } else if (a.has('sheet')) {
      s = SheetsMcp.sheet(t, a.string('sheet')!);
    } else {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'Pass range (a protected range) or sheet (a protected sheet).',
      );
    }
    final except = [
      for (final e in a.list('except_ranges') ?? const [])
        SheetsMcp.range(t, '$e', contextSheetId: s.id).rect,
    ];
    final editors = await _editorIds(
      ctx,
      t,
      [for (final e in a.list('editors') ?? const []) '$e'],
    );
    final id = const Uuid().v7();
    final what = rect == null
        ? 'sheet "${s.name}"'
        : SheetsMcp.a1(t.model, s.id, rect);
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.protect_range',
      label: SheetsMcp.label(ctx, 'sheets.protect_range', what),
      structural: 'Protect $what',
      steps: [
        _op(
          () => AddProtection(
            s.id,
            range: rect,
            exceptRanges: except,
            description: a.string('description'),
            warningOnly: a.boolean('warning_only') ?? false,
            editors: editors,
            id: id,
          ),
        ),
      ],
    );
    return _result(o, 'Protected $what', {'protection_id': id});
  }

  /// Auth user ids of [emails]; each must have edit access.
  static Future<List<String>> _editorIds(
    ToolContext ctx,
    SheetsTarget t,
    List<String> emails,
  ) async {
    final out = <String>[];
    for (final email in emails) {
      final p = await UserProfile.db.findFirstRow(
        ctx.session,
        where: (u) => u.email.equals(email.trim().toLowerCase()),
      );
      final role = p == null
          ? null
          : await AccessService.effectiveRole(ctx.session, p.id!, t.item);
      if (p == null || role == null || !(role >= Role.editor)) {
        throw McpToolException(
          McpErrorCode.invalidArgs,
          '$email does not have edit access to this spreadsheet.',
        );
      }
      out.add(p.authUserId.uuid.toLowerCase());
    }
    return out;
  }

  static Future<ToolResult> unprotect(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a, min: Role.editor);
    final id = a.requireString('protection_id');
    ProtectedRangeRecord? p;
    for (final s in t.model.sheets) {
      p ??= s.protections[id];
    }
    if (p == null) {
      throw McpToolException(McpErrorCode.notFound, 'No protection $id.');
    }
    if (!ProtectionGuard.canManage(
      p,
      ctx.actor.authUserId.uuid,
      isOwner: t.isOwner,
    )) {
      throw McpToolException(
        McpErrorCode.forbidden,
        'Only the owner and the editors of this protection can remove it.',
      );
    }
    final o = await SheetsWrites.run(
      ctx,
      t,
      tool: 'sheets.unprotect',
      label: SheetsMcp.label(ctx, 'sheets.unprotect', id),
      structural: 'Remove a protection',
      steps: [_op(() => DeleteProtection(id))],
    );
    return _result(o, 'Removed the protection');
  }
}
