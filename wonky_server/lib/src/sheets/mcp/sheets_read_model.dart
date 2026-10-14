import 'dart:convert';
import 'dart:math' as math;

import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput;
import 'package:wonky_sync_models/ids.dart' show FractionalIndex;

import '../headless/headless_workbook.dart';
import 'sheets_mcp_support.dart';

/// How cell values are rendered in tool output (Sheets 12 §3.2).
enum ValueRender { formatted, unformatted, formula }

/// How dates are rendered with [ValueRender.unformatted].
enum DateRender { serial, formatted, iso }

/// Read-side views of a headless workbook shared by the read tools, the
/// MCP resources and the AI context builder.
abstract final class SheetsReadModel {
  // ------------------------------------------------------------- values

  /// Whether [format] (explicit or hint) displays dates/times.
  static bool isDateFormat(String? format, String locale) {
    if (format == null) return false;
    final resolved = NumberFormatPresets.resolve(format, locale) ?? format;
    return FormatHint.looksLikeDatePattern(resolved) ||
        FormatHint.looksLikeDatePattern(format);
  }

  /// ISO-8601 text of a serial date/time.
  static String isoOf(double serial) {
    final ms = DateSerial.toUnixMillis(serial);
    final d = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final iso = d.toIso8601String();
    if (serial == serial.floorToDouble()) return iso.substring(0, 10);
    return iso.replaceAll('.000Z', '').replaceAll('Z', '');
  }

  /// The JSON value of a cell for [render].
  static Object? valueJson(
    HeadlessWorkbook wb,
    String sheetId,
    int row,
    int col, {
    ValueRender render = ValueRender.formatted,
    DateRender dates = DateRender.iso,
  }) {
    if (render == ValueRender.formula) {
      final f = wb.formulaAt(sheetId, row, col);
      if (f != null) return f;
    }
    final v = wb.valueAt(sheetId, row, col);
    if (v is EmptyValue) return null;
    if (render == ValueRender.formatted) {
      return wb.display.displayText(v, wb.numberFormatAt(sheetId, row, col));
    }
    return switch (v) {
      NumberValue(:final number) => () {
        if (dates == DateRender.serial) return _num(number);
        final fmt = wb.numberFormatAt(sheetId, row, col);
        if (!isDateFormat(fmt, wb.locale)) return _num(number);
        return dates == DateRender.iso
            ? isoOf(number)
            : wb.display.displayText(v, fmt);
      }(),
      TextValue(:final text) => text,
      BoolValue(:final value) => value,
      ErrorValue(:final kind) => kind.literal,
      EmptyValue() => null,
    };
  }

  static num _num(double n) =>
      n == n.truncateToDouble() && n.abs() < 9007199254740992 ? n.toInt() : n;

  /// Reads [rect] of [sheetId] row-major with [render]; trailing empty rows
  /// and columns trimmed.
  static List<List<Object?>> readRect(
    HeadlessWorkbook wb,
    String sheetId,
    GridRect rect, {
    ValueRender render = ValueRender.formatted,
    DateRender dates = DateRender.iso,
  }) {
    final out = <List<Object?>>[];
    for (var r = rect.top; r <= rect.bottom; r++) {
      final row = <Object?>[];
      for (var c = rect.left; c <= rect.right; c++) {
        row.add(valueJson(wb, sheetId, r, c, render: render, dates: dates));
      }
      out.add(row);
    }
    return trim(out);
  }

  /// Removes trailing empty rows and trailing empty columns.
  static List<List<Object?>> trim(List<List<Object?>> rows) {
    bool empty(Object? v) => v == null || v == '';
    var lastRow = rows.length - 1;
    while (lastRow >= 0 && rows[lastRow].every(empty)) {
      lastRow--;
    }
    final kept = rows.sublist(0, lastRow + 1);
    var width = 0;
    for (final r in kept) {
      for (var c = r.length - 1; c >= 0; c--) {
        if (!empty(r[c])) {
          if (c + 1 > width) width = c + 1;
          break;
        }
      }
    }
    return [for (final r in kept) r.sublist(0, math.min(width, r.length))];
  }

  // ----------------------------------------------------------- metadata

  /// The metadata sections of `sheets.get_spreadsheet` (Sheets 12 §3.1).
  static const defaultInclude = {
    'sheets',
    'named_ranges',
    'charts',
    'pivots',
    'filters',
    'protections',
  };

  /// `sheets.get_spreadsheet` output (without async parts: role, url,
  /// protection editors).
  static Map<String, Object?> spreadsheetInfo(
    HeadlessWorkbook wb, {
    Set<String> include = defaultInclude,
  }) {
    final m = wb.model;
    final ss = m.spreadsheet;
    String? rangeA1(String? json) {
      final g = GridRange.tryParse(json);
      final rr = g == null ? null : m.resolve(g);
      return rr == null ? null : m.a1Of(rr);
    }

    List<String> rangesA1(String json) => [
      for (final g in GridRange.parseList(json))
        if (m.resolve(g) case final ResolvedRange rr) m.a1Of(rr),
    ];

    final cellCount = m.sheets.fold(0, (n, s) => n + s.cells.count);
    return {
      'title': ss.title,
      'locale': ss.locale,
      'time_zone': ss.timeZone,
      if (include.contains('sheets'))
        'sheets': [
          for (final (i, s) in m.sheets.indexed) sheetJson(m, s, i),
        ],
      if (include.contains('named_ranges'))
        'named_ranges': [
          for (final n in m.namedRanges)
            {
              'name': n.name,
              if (n.rangeJson != null) 'range': rangeA1(n.rangeJson),
              if (n.formula != null) 'formula': _namedFormula(wb, n),
            },
        ],
      if (include.contains('charts'))
        'charts': [
          for (final s in m.sheets)
            for (final o in s.objects.values)
              if (o.kind == EmbeddedObjectKind.chart) chartSummary(wb, s, o),
        ],
      if (include.contains('pivots'))
        'pivots': [
          for (final s in m.sheets)
            for (final p in s.pivots.values) pivotSummary(wb, s, p),
        ],
      if (include.contains('filters'))
        'filter_views': [
          for (final s in m.sheets)
            for (final f in s.filterViews.values)
              {
                'filter_view_id': f.id,
                'sheet': s.name,
                'name': f.name,
                'range': rangeA1(f.rangeJson),
              },
        ],
      if (include.contains('protections'))
        'protections': [
          for (final s in m.sheets)
            for (final p in s.protections.values)
              {
                'protection_id': p.id,
                'sheet': s.name,
                'range': p.rangeJson == null ? null : rangeA1(p.rangeJson),
                'whole_sheet': p.rangeJson == null,
                'description': p.description,
                'warning_only': p.warningOnly,
              },
        ],
      if (include.contains('cf'))
        'conditional_formats': [
          for (final s in m.sheets) ...cfRules(wb, s),
        ],
      if (include.contains('dv'))
        'data_validation': [
          for (final s in m.sheets)
            for (final d in s.dvRules.values)
              {
                'rule_id': d.id,
                'sheet': s.name,
                'ranges': rangesA1(d.rangesJson),
                'criteria': _decode(d.criteriaJson),
                'strict': d.strict,
              },
        ],
      'cell_count': cellCount,
      'cell_limit': SheetsMcp.maxCells,
      'grid_cells': SheetsMcp.gridCells(m),
    };
  }

  static String? _namedFormula(HeadlessWorkbook wb, NamedRangeRecord n) {
    final f = n.formula;
    if (f == null) return null;
    final first = wb.model.sheets.firstOrNull;
    if (first == null || !StoredFormula.hasTokens(f)) return f;
    return wb.hooks.toA1(f, sheetId: first.id, row: 0, col: 0);
  }

  static Object? _decode(String? json) {
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } on FormatException {
      return json;
    }
  }

  /// One sheet of `get_spreadsheet`.
  static Map<String, Object?> sheetJson(
    WorkbookModel m,
    SheetModel s,
    int index,
  ) {
    final rec = s.record!;
    final used = s.usedRect();
    return {
      'name': s.name,
      'id': s.id,
      'index': index + 1,
      'kind': rec.kind.name,
      'hidden': rec.hidden,
      'grid': {'rows': s.rows.length, 'columns': s.columns.length},
      'used_range': used?.a1,
      'frozen': {'rows': rec.frozenRows, 'columns': rec.frozenColumns},
      'tab_color': rec.tabColor,
      'has_basic_filter': s.basicFilter != null,
      'filter_views': [
        for (final f in s.filterViews.values)
          if (f.name != null) f.name,
      ],
      'merges_count': s.merges.length,
    };
  }

  /// The anchor cell of an embedded object (`B2`), or null.
  static String? anchorA1(SheetModel s, String anchorJson) {
    final a = ObjectAnchor.tryParse(anchorJson);
    if (a == null || a.ownSheet) return null;
    final r = a.rowId == null ? -1 : s.rows.indexOf(a.rowId!);
    final c = a.colId == null ? -1 : s.columns.indexOf(a.colId!);
    if (r < 0 || c < 0) return null;
    return CellPos(r, c).a1;
  }

  /// A chart in `get_spreadsheet`.
  static Map<String, Object?> chartSummary(
    HeadlessWorkbook wb,
    SheetModel s,
    EmbeddedObjectRecord o,
  ) {
    final spec = ChartSpec.fromJson(o.specJson);
    final title = spec.title.text;
    return {
      'chart_id': o.id,
      'sheet': s.name,
      'title': title.isEmpty ? o.title : title,
      'type': spec.typeId,
      'data_ranges': [
        for (final g in spec.data.ranges)
          if (wb.model.resolve(g) case final ResolvedRange rr)
            wb.model.a1Of(rr),
      ],
      'anchor': anchorA1(s, o.anchorJson),
      'own_sheet': ObjectAnchor.tryParse(o.anchorJson)?.ownSheet ?? false,
    };
  }

  /// A pivot table in `get_spreadsheet`.
  static Map<String, Object?> pivotSummary(
    HeadlessWorkbook wb,
    SheetModel s,
    PivotTableRecord p,
  ) {
    final r = s.rows.indexOf(p.anchorRowId);
    final c = s.columns.indexOf(p.anchorColId);
    final g = GridRange.tryParse(p.sourceRangeJson);
    final src = g == null ? null : wb.model.resolve(g);
    return {
      'pivot_id': p.id,
      'sheet': s.name,
      'anchor': r < 0 || c < 0 ? null : CellPos(r, c).a1,
      'source': src == null ? null : wb.model.a1Of(src),
    };
  }

  /// The conditional format rules of [s] in priority order.
  static List<Map<String, Object?>> cfRules(HeadlessWorkbook wb, SheetModel s) {
    final rules = s.cfRules.values.toList()
      ..sort(
        (a, b) => FractionalIndex.compare(a.sortKey, a.id, b.sortKey, b.id),
      );
    return [
      for (final (i, r) in rules.indexed)
        {
          'rule_id': r.id,
          'sheet': s.name,
          'ranges': [
            for (final g in GridRange.parseList(r.rangesJson))
              if (wb.model.resolve(g) case final ResolvedRange rr)
                wb.model.a1Of(rr),
          ],
          'rule': _decode(r.ruleJson),
          'index': i,
          'enabled': r.enabled,
        },
    ];
  }

  // ------------------------------------------------------------ profiles

  /// Detected tables of [s]: blocks of consecutive non-empty rows with
  /// their column span (Sheets 12 §3.13).
  static List<GridRect> detectTables(
    HeadlessWorkbook wb,
    SheetModel s, {
    GridRect? within,
    int max = 20,
  }) {
    final used = within ?? s.usedRect();
    if (used == null) return const [];
    final rowsWithData = <int, (int, int)>{};
    for (final (r, c, _) in s.cellsIn(used, contentOnly: true)) {
      final e = rowsWithData[r];
      rowsWithData[r] = e == null
          ? (c, c)
          : (math.min(e.$1, c), math.max(e.$2, c));
    }
    final rows = rowsWithData.keys.toList()..sort();
    final out = <GridRect>[];
    var i = 0;
    while (i < rows.length && out.length < max) {
      final start = rows[i];
      var end = start;
      var (left, right) = rowsWithData[start]!;
      while (i + 1 < rows.length && rows[i + 1] == end + 1) {
        i++;
        end = rows[i];
        final (l, r) = rowsWithData[end]!;
        left = math.min(left, l);
        right = math.max(right, r);
      }
      out.add(GridRect(start, left, end, right));
      i++;
    }
    return out;
  }

  /// Whether the first row of [rect] looks like a header: all its non-empty
  /// cells are text, and at least one column below holds non-text values
  /// (or the row is bold).
  static bool looksLikeHeader(
    HeadlessWorkbook wb,
    String sheetId,
    GridRect rect,
  ) {
    if (rect.rowCount < 2) return false;
    var texts = 0;
    for (var c = rect.left; c <= rect.right; c++) {
      final v = wb.valueAt(sheetId, rect.top, c);
      if (v is EmptyValue) continue;
      if (v is! TextValue) return false;
      texts++;
    }
    if (texts == 0) return false;
    final bold = wb.model
        .explicitFormatChain(sheetId, rect.top, rect.left)
        .toMap()[CellCols.bold];
    if (bold == true) return true;
    final sample = math.min(rect.bottom, rect.top + 20);
    for (var c = rect.left; c <= rect.right; c++) {
      for (var r = rect.top + 1; r <= sample; r++) {
        final v = wb.valueAt(sheetId, r, c);
        if (v is NumberValue || v is BoolValue) return true;
      }
    }
    // All text: a header when the first row's values are unique and the
    // column values below repeat.
    return rect.rowCount > 2;
  }

  /// `sheets.describe_data` for [rect] of [s].
  static Map<String, Object?> describe(
    HeadlessWorkbook wb,
    SheetModel s,
    GridRect rect, {
    int sampleRows = 5,
    int maxColumns = 50,
    bool includeTables = true,
  }) {
    final m = wb.model;
    final header = looksLikeHeader(wb, s.id, rect);
    final dataTop = header ? rect.top + 1 : rect.top;
    final columns = <Map<String, Object?>>[];
    final lastCol = math.min(rect.right, rect.left + maxColumns - 1);
    for (var c = rect.left; c <= lastCol; c++) {
      columns.add(
        _profileColumn(
          wb,
          s,
          c,
          dataTop,
          rect.bottom,
          header ? rect.top : null,
          sampleRows,
        ),
      );
    }
    return {
      'range': m.a1Of(ResolvedRange(s.id, rect)),
      'sheet': s.name,
      'header_row': header ? rect.top + 1 : null,
      'rows': rect.bottom - dataTop + 1,
      'columns': columns,
      if (rect.right > lastCol) 'columns_omitted': rect.right - lastCol,
      if (includeTables)
        'tables': [
          for (final t in detectTables(wb, s))
            {
              'range': m.a1Of(ResolvedRange(s.id, t)),
              'header_row': looksLikeHeader(wb, s.id, t) ? t.top + 1 : null,
            },
        ],
    };
  }

  static Map<String, Object?> _profileColumn(
    HeadlessWorkbook wb,
    SheetModel s,
    int c,
    int top,
    int bottom,
    int? headerRow,
    int sampleRows,
  ) {
    final numbers = <double>[];
    final dates = <double>[];
    final texts = <String, int>{};
    final distinct = <String>{};
    final formats = <String, int>{};
    var bools = 0, errors = 0, empty = 0, nonEmpty = 0;
    int? minLen, maxLen;
    final sample = <Object?>[];
    final limit = math.min(bottom, top + 200000);
    for (var r = top; r <= limit; r++) {
      final v = wb.valueAt(s.id, r, c);
      if (v is EmptyValue) {
        empty++;
        continue;
      }
      nonEmpty++;
      final fmt = wb.numberFormatAt(s.id, r, c);
      if (fmt != null) formats[fmt] = (formats[fmt] ?? 0) + 1;
      final display = wb.display.displayText(v, fmt);
      if (distinct.length < 100000) distinct.add(display);
      if (sample.length < sampleRows) sample.add(_short(display));
      switch (v) {
        case NumberValue(:final number):
          if (SheetsReadModel.isDateFormat(fmt, wb.locale)) {
            dates.add(number);
          } else {
            numbers.add(number);
          }
        case TextValue(:final text):
          texts[text] = (texts[text] ?? 0) + 1;
          final l = text.length;
          if (minLen == null || l < minLen) minLen = l;
          if (maxLen == null || l > maxLen) maxLen = l;
        case BoolValue():
          bools++;
        case ErrorValue():
          errors++;
        case EmptyValue():
          break;
      }
    }
    final textCount = texts.values.fold(0, (a, b) => a + b);
    final kinds = {
      if (numbers.isNotEmpty) 'number',
      if (dates.isNotEmpty) 'date',
      if (textCount > 0) 'text',
      if (bools > 0) 'bool',
    };
    final type = nonEmpty == 0
        ? 'empty'
        : kinds.length == 1
        ? kinds.first
        : kinds.isEmpty
        ? 'mixed'
        : 'mixed';
    final headerText = headerRow == null
        ? null
        : wb.displayAt(s.id, headerRow, c);
    final out = <String, Object?>{
      'column': SheetsMcp.letter(c),
      'header': headerText,
      'type': type,
      'non_empty': nonEmpty,
      'empty': empty,
      'distinct': distinct.length,
      if (errors > 0) 'errors': errors,
    };
    if (numbers.isNotEmpty) {
      numbers.sort();
      final sum = numbers.fold<double>(0, (a, b) => a + b);
      final mean = sum / numbers.length;
      final median = numbers.length.isOdd
          ? numbers[numbers.length ~/ 2]
          : (numbers[numbers.length ~/ 2 - 1] + numbers[numbers.length ~/ 2]) /
                2;
      var sq = 0.0;
      for (final n in numbers) {
        sq += (n - mean) * (n - mean);
      }
      out['numeric'] = {
        'min': _num(numbers.first),
        'max': _num(numbers.last),
        'mean': _round(mean),
        'median': _num(median),
        'stdev': numbers.length > 1
            ? _round(math.sqrt(sq / (numbers.length - 1)))
            : 0,
        'sum': _num(_round(sum).toDouble()),
      };
    }
    if (dates.isNotEmpty) {
      dates.sort();
      out['date'] = {'min': isoOf(dates.first), 'max': isoOf(dates.last)};
    }
    if (textCount > 0) {
      final top = texts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      out['text'] = {
        'min_len': minLen,
        'max_len': maxLen,
        'top_values': [
          for (final e in top.take(10))
            {'value': _short(e.key), 'count': e.value},
        ],
      };
    }
    if (formats.isNotEmpty) {
      final f = formats.entries.reduce((a, b) => a.value >= b.value ? a : b);
      out['number_format'] = f.key;
    }
    out['sample'] = sample;
    return out;
  }

  static num _round(double v) {
    final r = (v * 1e6).round() / 1e6;
    return _num(r);
  }

  /// Long texts are cut to 100 characters in profiles and AI context.
  static String _short(String s) =>
      s.length <= 100 ? s : '${s.substring(0, 100)}…';
}
