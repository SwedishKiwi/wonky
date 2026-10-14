import 'dart:convert';
import 'dart:math' as math;

import 'package:serverpod/serverpod.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput;

import '../../platform/common/models.dart';
import '../../platform/mcp/drive_tool_handlers.dart';
import '../../platform/mcp/tool_support.dart';
import '../sheets_service.dart';
import 'sheets_mcp_support.dart';
import 'sheets_read_model.dart';

/// The read-only `sheets.*` tools (Sheets 12 §3.1, §3.2, §3.8–3.13).
abstract final class SheetsReadHandlers {
  // ------------------------------------------------------------ metadata

  static Future<ToolResult> getSpreadsheet(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final include =
        a.list('include')?.whereType<String>().toSet() ??
        SheetsReadModel.defaultInclude;
    final info = SheetsReadModel.spreadsheetInfo(t.wb, include: include);
    if (include.contains('protections')) {
      await _protectionEditors(ctx, t, info['protections'] as List);
    }
    final out = <String, Object?>{
      'spreadsheet': t.item.uuid.uuid,
      ...info,
      'name': t.item.name,
      'url': t.url(DriveToolHandlers.webBase),
      'role': t.role.name,
    };
    final sheets = (info['sheets'] as List?) ?? const [];
    return ToolResult(
      out,
      text:
          '"${t.item.name}" (${t.model.spreadsheet.locale}, ${t.role.name}): '
          '${sheets.map((s) => '${(s as Map)['name']} [${s['used_range'] ?? 'empty'}]').join(', ')}',
    );
  }

  static Future<void> _protectionEditors(
    ToolContext ctx,
    SheetsTarget t,
    List<Object?> out,
  ) async {
    final userId = ctx.actor.authUserId.uuid;
    final ids = <String>{};
    final records = <String, ProtectedRangeRecord>{};
    for (final s in t.model.sheets) {
      for (final p in s.protections.values) {
        records[p.id] = p;
        ids.addAll(ProtectionGuard.editorsOf(p));
      }
    }
    final emails = await _emails(ctx.session, ids);
    for (final o in out) {
      if (o is! Map) continue;
      final p = records[o['protection_id']];
      if (p == null) continue;
      o['editors'] = [
        for (final e in ProtectionGuard.editorsOf(p)) emails[e] ?? e,
      ];
      o['can_edit'] = ProtectionGuard.canEdit(p, userId, isOwner: t.isOwner);
    }
  }

  /// Emails by lower-case auth user uuid.
  static Future<Map<String, String>> _emails(
    Session session,
    Set<String> authIds,
  ) async {
    if (authIds.isEmpty) return const {};
    final uuids = <UuidValue>{
      for (final id in authIds)
        if (UuidValue.withValidation(id) case final UuidValue u) u,
    };
    final profiles = await UserProfile.db.find(
      session,
      where: (p) => p.authUserId.inSet(uuids),
    );
    return {
      for (final p in profiles) p.authUserId.uuid.toLowerCase(): p.email,
    };
  }

  static Future<ToolResult> describeData(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final rangeArg = a.string('range');
    SheetModel s;
    GridRect rect;
    if (rangeArg != null) {
      final r = SheetsMcp.range(t, rangeArg);
      s = t.model.sheet(r.sheetId)!;
      rect = SheetsMcp.clipToUsed(s, r);
    } else {
      s = SheetsMcp.sheetOrFirst(t, a.string('sheet'));
      final tables = SheetsReadModel.detectTables(t.wb, s);
      final used = s.usedRect();
      rect = tables.isNotEmpty ? tables.first : used ?? GridRect.cell(0, 0);
    }
    final out = SheetsReadModel.describe(
      t.wb,
      s,
      rect,
      sampleRows: a.integer('sample_rows') ?? 5,
      maxColumns: a.integer('max_columns') ?? 50,
    );
    final cols = (out['columns'] as List).cast<Map<String, Object?>>();
    return ToolResult(
      out,
      text:
          '${out['range']}: ${out['rows']} rows; '
          '${cols.map((c) => '${c['column']}${c['header'] == null ? '' : ' "${c['header']}"'} ${c['type']}').join(', ')}',
    );
  }

  // --------------------------------------------------------------- values

  static Future<ToolResult> getValues(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final ranges = a.list('ranges')!.cast<String>();
    final render = switch (a.string('render')) {
      'unformatted' => ValueRender.unformatted,
      'formula' => ValueRender.formula,
      _ => ValueRender.formatted,
    };
    final dates = switch (a.string('date_render')) {
      'serial' => DateRender.serial,
      'formatted' => DateRender.formatted,
      _ => DateRender.iso,
    };
    final byColumns = a.string('major_dimension') == 'columns';
    final budget = (a.integer('max_cells') ?? SheetsLimits.defaultReadPage)
        .clamp(1, SheetsLimits.cellsReadPerCall);
    var startRange = 0;
    var startRow = 0;
    final cursor = a.string('cursor');
    if (cursor != null) {
      final parts = cursor.split(':');
      startRange = int.tryParse(parts.first) ?? 0;
      startRow = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    }
    var remaining = budget;
    final out = <Map<String, Object?>>[];
    String? nextCursor;
    for (var i = startRange; i < ranges.length; i++) {
      final r = SheetsMcp.range(t, ranges[i]);
      final s = t.model.sheet(r.sheetId)!;
      final clipped = SheetsMcp.clipToUsed(s, r);
      final width = clipped.colCount;
      final offset = i == startRange ? startRow : 0;
      final top = clipped.top + offset;
      if (top > clipped.bottom) {
        out.add({
          'range': SheetsMcp.a1(t.model, s.id, clipped),
          'values': const <Object?>[],
          'truncated': false,
        });
        continue;
      }
      final maxRows = math.max(1, remaining ~/ math.max(1, width));
      final bottom = math.min(clipped.bottom, top + maxRows - 1);
      var values = SheetsReadModel.readRect(
        t.wb,
        s.id,
        GridRect(top, clipped.left, bottom, clipped.right),
        render: render,
        dates: dates,
      );
      if (byColumns) values = _transpose(values);
      final truncated = bottom < clipped.bottom;
      remaining -= (bottom - top + 1) * width;
      final entry = <String, Object?>{
        'range': SheetsMcp.a1(t.model, s.id, clipped),
        if (offset > 0 || truncated)
          'rows_returned': SheetsMcp.a1(
            t.model,
            s.id,
            GridRect(top, clipped.left, bottom, clipped.right),
          ),
        'values': values,
        'truncated': truncated,
      };
      if (truncated) {
        nextCursor = '$i:${bottom - clipped.top + 1}';
        entry['next_cursor'] = nextCursor;
        out.add(entry);
        break;
      }
      out.add(entry);
      if (remaining <= 0 && i + 1 < ranges.length) {
        nextCursor = '${i + 1}:0';
        break;
      }
    }
    final text = StringBuffer();
    for (final r in out) {
      text.writeln('${r['range']}:');
      for (final row in (r['values'] as List).take(50)) {
        text.writeln((row as List).map((v) => v ?? '').join('\t'));
      }
      if ((r['values'] as List).length > 50) text.writeln('…');
    }
    if (nextCursor != null) text.writeln('[truncated: cursor "$nextCursor"]');
    return ToolResult({
      'ranges': out,
      'next_cursor': nextCursor,
    }, text: text.toString().trimRight());
  }

  static List<List<Object?>> _transpose(List<List<Object?>> rows) {
    final width = rows.fold(0, (w, r) => math.max(w, r.length));
    return [
      for (var c = 0; c < width; c++)
        [for (final r in rows) c < r.length ? r[c] : null],
    ];
  }

  // ------------------------------------------------- find and evaluation

  static FindQuery query(SheetsTarget t, ToolArgs a) {
    final rangeArg = a.string('range');
    final sheetArg = a.string('sheet');
    FindScope scope = FindScope.allSheets;
    String? sheetId;
    GridRect? rect;
    if (rangeArg != null) {
      final r = SheetsMcp.range(t, rangeArg);
      scope = FindScope.range;
      sheetId = r.sheetId;
      rect = r.rect;
    } else if (sheetArg != null && a.boolean('all_sheets') != true) {
      scope = FindScope.sheet;
      sheetId = SheetsMcp.sheet(t, sheetArg).id;
    }
    return FindQuery(
      a.requireString('query'),
      matchCase: a.boolean('match_case') ?? false,
      entireCell: a.boolean('match_entire_cell') ?? false,
      regex: a.boolean('use_regex') ?? false,
      searchFormulas: a.boolean('search_formulas') ?? false,
      scope: scope,
      sheetId: sheetId,
      range: rect,
    );
  }

  /// Find over computed values; formulas are searched in the spreadsheet
  /// locale's syntax (as the app's Find & Replace).
  static FindEngine findEngine(SheetsTarget t) => FindEngine(
    t.model,
    CellTextReader(t.wb.engine, t.wb.display),
    hooks: t.wb.hooks,
  );

  static Future<ToolResult> find(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final q = query(t, a);
    final limit = (a.integer('limit') ?? 100).clamp(
      1,
      SheetsLimits.findMatches,
    );
    final FindResult result;
    try {
      result = findEngine(t).find(
        q,
        startSheetId: q.sheetId ?? t.model.visibleSheets.firstOrNull?.id,
        includeStart: true,
      );
    } on FindPatternException catch (e) {
      throw McpToolException(McpErrorCode.invalidArgs, e.message);
    }
    final matches = result.matches.take(limit).toList()
      ..sort((x, y) {
        final sx = t.model.sheets.indexWhere((s) => s.id == x.sheetId);
        final sy = t.model.sheets.indexWhere((s) => s.id == y.sheetId);
        if (sx != sy) return sx - sy;
        if (x.row != y.row) return x.row - y.row;
        return x.col - y.col;
      });
    final out = [
      for (final m in matches)
        {
          'a1': SheetsMcp.cellA1(t.model, m.sheetId, m.row, m.col),
          'value': t.wb.displayAt(m.sheetId, m.row, m.col),
          if (t.wb.formulaAt(m.sheetId, m.row, m.col) case final String f)
            'formula': f,
        },
    ];
    return ToolResult(
      {
        'matches': out,
        'total': result.matches.length,
        'truncated': result.matches.length > limit || result.capped,
      },
      text: out.isEmpty
          ? 'No matches'
          : '${result.matches.length} match(es): '
                '${out.take(20).map((m) => m['a1']).join(', ')}',
    );
  }

  static Future<ToolResult> evaluate(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final formula = a.requireString('formula');
    final text = formula.startsWith('=') ? formula : '=$formula';
    final check = validateFormula(text);
    if (!check.ok) {
      throw McpToolException(
        SheetsErrorCode.formulaParseError,
        check.error?.message ?? 'Formula parse error.',
        details: {
          'position': (check.error?.offset ?? 0) + 1,
          'length': check.error?.length,
        },
      );
    }
    var sheet = a.has('sheet') ? SheetsMcp.sheet(t, a.string('sheet')!) : null;
    var row = 0, col = 0;
    final cell = a.string('cell');
    if (cell != null) {
      final r = SheetsMcp.range(t, cell, contextSheetId: sheet?.id);
      sheet = t.model.sheet(r.sheetId);
      row = r.rect.top;
      col = r.rect.left;
    }
    sheet ??= SheetsMcp.sheetOrFirst(t, null);
    final stored = t.wb.hooks.toStored(
      text,
      sheetId: sheet.id,
      row: row,
      col: col,
    );
    final v = t.wb.engine.evaluateStored(
      stored,
      sheetId: sheet.id,
      row: row,
      col: col,
    );
    final out = valueResult(t, v, sheet.id, row, col);
    return ToolResult(out, text: '${out['formatted'] ?? out['value']}');
  }

  /// The `{value, formatted, type, array?, error_message?}` of an
  /// evaluation.
  static Map<String, Object?> valueResult(
    SheetsTarget t,
    FValue v,
    String sheetId,
    int row,
    int col,
  ) {
    Object? scalar(CellValue c) => switch (c) {
      NumberValue(:final number) =>
        number == number.truncateToDouble() ? number.toInt() : number,
      TextValue(:final text) => text,
      BoolValue(:final value) => value,
      ErrorValue(:final kind) => kind.literal,
      EmptyValue() => null,
    };
    final cv = v.toCellValue();
    final hint = v is FNumber
        ? NumberFormatter.hintFor(v.hint, t.wb.locale)
        : null;
    final fmt =
        t.model
                .explicitFormatChain(sheetId, row, col)
                .toMap()[CellCols.numberFormat]
            as String? ??
        hint;
    final type = switch (v) {
      FArray() => 'array',
      FNumber() => 'number',
      FText() => 'text',
      FBool() => 'bool',
      FError() => 'error',
      _ => switch (cv) {
        NumberValue() => 'number',
        BoolValue() => 'bool',
        ErrorValue() => 'error',
        _ => 'text',
      },
    };
    final out = <String, Object?>{
      'value': scalar(cv),
      'formatted': t.wb.display.displayText(cv, fmt),
      'type': type,
    };
    if (v is FArray) {
      out['array'] = [
        for (var r = 0; r < v.rows && r * v.cols < 1000; r++)
          [for (var c = 0; c < v.cols; c++) scalar(v.at(r, c).toCellValue())],
      ];
    }
    if (v is FError) {
      out['error_message'] = v.message;
    }
    return out;
  }

  static Future<ToolResult> validateFormulaTool(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final f = a.requireString('formula');
    final r = validateFormula(f.startsWith('=') ? f : '=$f');
    return ToolResult(
      r.toJson(),
      text: r.ok
          ? 'OK${r.unknownFunctions.isEmpty ? '' : ' (unknown functions: ${r.unknownFunctions.join(', ')})'}'
          : r.error!.message,
    );
  }

  static Future<ToolResult> explainFormula(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final r = SheetsMcp.range(t, a.requireString('cell'));
    final row = r.rect.top, col = r.rect.left;
    final formula = t.wb.formulaAt(r.sheetId, row, col);
    if (formula == null) {
      throw McpToolException(
        McpErrorCode.invalidArgs,
        '${SheetsMcp.cellA1(t.model, r.sheetId, row, col)} has no formula.',
      );
    }
    final node = explainCell(t.wb.engine, r.sheetId, row, col);
    var budget = 50;
    Map<String, Object?>? prune(Map<String, Object?> n) {
      if (budget <= 0) return null;
      budget--;
      final children = (n['children'] as List?)?.cast<Map<String, Object?>>();
      return {
        ...n,
        if (children != null)
          'children': [
            for (final c in children)
              if (prune(c) case final Map<String, Object?> p) p,
          ],
      };
    }

    final trace = node == null ? null : prune(node.toJson());
    return ToolResult({
      'cell': SheetsMcp.cellA1(t.model, r.sheetId, row, col),
      'formula': formula,
      'value': t.wb.displayAt(r.sheetId, row, col),
      'trace': trace,
      if (budget <= 0) 'truncated': true,
    }, text: '$formula = ${t.wb.displayAt(r.sheetId, row, col)}');
  }

  static Future<ToolResult> getCell(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final r = SheetsMcp.range(t, a.requireString('cell'));
    final s = t.model.sheet(r.sheetId)!;
    final row = r.rect.top, col = r.rect.left;
    final cell = s.cellAt(row, col);
    final format = t.model.explicitFormatChain(s.id, row, col).toMap();
    final dvId = s.rulesAt(RuleKind.dataValidation, row, col).firstOrNull;
    final cfIds = s.rulesAt(RuleKind.conditionalFormat, row, col);
    final dv = dvId == null ? null : s.dvRules[dvId];
    final out = {
      'cell': SheetsMcp.cellA1(t.model, s.id, row, col),
      'value': SheetsReadModel.valueJson(
        t.wb,
        s.id,
        row,
        col,
        render: ValueRender.unformatted,
      ),
      'formatted': t.wb.displayAt(s.id, row, col),
      'formula': t.wb.formulaAt(s.id, row, col),
      'format': format,
      'number_format': t.wb.numberFormatAt(s.id, row, col),
      'note': cell?.note,
      'merged': s.mergeAt(row, col)?.a1,
      'data_validation': dv == null
          ? null
          : {
              'rule_id': dv.id,
              'criteria': jsonDecode(dv.criteriaJson),
              'strict': dv.strict,
            },
      'conditional_formats': cfIds,
    };
    return ToolResult(
      out,
      text:
          '${out['cell']}: ${out['formatted']}'
          '${out['formula'] == null ? '' : ' (${out['formula']})'}',
    );
  }

  static Future<ToolResult> getCellHistory(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final r = SheetsMcp.range(t, a.requireString('cell'));
    final s = t.model.sheet(r.sheetId)!;
    final rowId = s.rows.idAt(r.rect.top);
    final colId = s.columns.idAt(r.rect.left);
    final page = await SheetsService.cellHistory(
      ctx.session,
      ctx.actor,
      t.space,
      UuidValue.withValidation(s.id),
      UuidValue.withValidation(rowId),
      UuidValue.withValidation(colId),
      cursor: a.string('cursor'),
      limit: a.integer('limit') ?? 20,
    );
    final entries = [
      for (final e in page.entries)
        {
          'at': e.at.toUtc().toIso8601String(),
          'user': e.user == null
              ? null
              : {'name': e.user!.displayName, 'email': e.user!.email},
          'actor_kind': e.actorKind.name,
          'label': e.label,
          'before': _historyValue(e.before),
          'after': _historyValue(e.after),
        },
    ];
    return ToolResult({
      'cell': SheetsMcp.cellA1(t.model, s.id, r.rect.top, r.rect.left),
      'entries': entries,
      'next_cursor': page.nextCursor,
    }, text: '${entries.length} change(s)');
  }

  static Object? _historyValue(String? content) {
    if (content == null) return null;
    final c = CellContent.decode(content);
    return switch (c) {
      null => null,
      FormulaContent(:final text) => text,
      _ => c.literalValue.toFValue().toCellValue().displayFallback,
    };
  }

  // ------------------------------------------------------------- listings

  static Future<ToolResult> listNamedRanges(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final info = SheetsReadModel.spreadsheetInfo(
      t.wb,
      include: {'named_ranges'},
    );
    final list = info['named_ranges'] as List;
    return ToolResult(
      {'named_ranges': list},
      text: list.isEmpty
          ? 'No named ranges'
          : list
                .map(
                  (n) =>
                      '${(n as Map)['name']} = ${n['range'] ?? n['formula']}',
                )
                .join('\n'),
    );
  }

  static Future<ToolResult> listConditionalFormats(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await SheetsMcp.open(ctx, a);
    final sheets = a.has('sheet')
        ? [SheetsMcp.sheet(t, a.string('sheet')!)]
        : t.model.sheets;
    final rules = [
      for (final s in sheets) ...SheetsReadModel.cfRules(t.wb, s),
    ];
    return ToolResult({'rules': rules}, text: '${rules.length} rule(s)');
  }

  static Future<ToolResult> listProtections(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final info = SheetsReadModel.spreadsheetInfo(
      t.wb,
      include: {'protections'},
    );
    var list = (info['protections'] as List).cast<Map<String, Object?>>();
    if (a.has('sheet')) {
      final name = SheetsMcp.sheet(t, a.string('sheet')!).name;
      list = list.where((p) => p['sheet'] == name).toList();
    }
    await _protectionEditors(ctx, t, list);
    return ToolResult(
      {'protections': list},
      text: '${list.length} protection(s)',
    );
  }

  static Future<ToolResult> listFilterViews(ToolContext ctx, ToolArgs a) async {
    final t = await SheetsMcp.open(ctx, a);
    final info = SheetsReadModel.spreadsheetInfo(t.wb, include: {'filters'});
    var list = (info['filter_views'] as List).cast<Map<String, Object?>>();
    if (a.has('sheet')) {
      final name = SheetsMcp.sheet(t, a.string('sheet')!).name;
      list = list.where((p) => p['sheet'] == name).toList();
    }
    final base = t.url(DriveToolHandlers.webBase);
    return ToolResult({
      'filter_views': [
        for (final f in list) {...f, 'url': '$base?fv=${f['filter_view_id']}'},
      ],
    }, text: '${list.length} filter view(s)');
  }
}

extension on CellValue {
  /// The literal of a value in history output.
  Object? get displayFallback => switch (this) {
    NumberValue(:final number) =>
      number == number.truncateToDouble() ? number.toInt() : number,
    TextValue(:final text) => text,
    BoolValue(:final value) => value,
    ErrorValue(:final kind) => kind.literal,
    EmptyValue() => null,
  };
}
