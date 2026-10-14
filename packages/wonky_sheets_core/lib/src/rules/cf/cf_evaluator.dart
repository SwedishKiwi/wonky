import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../engine_bridge/formula_hooks.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../format/attributes.dart';
import '../../format/theme.dart';
import '../../formula/model/workbook_view.dart';
import '../../formula/values/fvalue.dart';
import '../../model/events.dart';
import '../../model/grid_range.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';
import '../conditions/condition.dart';
import '../conditions/condition_evaluator.dart';
import '../conditions/display_text.dart';
import '../conditions/relative_dates.dart';
import '../conditions/value_text.dart';
import 'cf_rule.dart';
import 'range_stats.dart';

/// A data bar to paint in a cell (06 §15.6). [start]/[end] are fractions of
/// the content box width measured from the bar origin side (left for LTR).
final class DataBarResult {
  /// Creates a result.
  const DataBarResult({
    required this.start,
    required this.end,
    required this.color,
    required this.negative,
    required this.gradient,
    required this.showValue,
    required this.rightToLeft,
    this.axis,
  });

  /// Start fraction (0..1).
  final double start;

  /// End fraction (0..1, ≥ [start]).
  final double end;

  /// Bar color (`color` or `negativeColor`).
  final String color;

  /// Whether the value is negative.
  final bool negative;

  /// Gradient to 10 % alpha.
  final bool gradient;

  /// Whether the cell text is shown.
  final bool showValue;

  /// Mirror horizontally.
  final bool rightToLeft;

  /// Axis position fraction when an axis is drawn.
  final double? axis;

  @override
  bool operator ==(Object other) =>
      other is DataBarResult &&
      other.start == start &&
      other.end == end &&
      other.color == color &&
      other.negative == negative &&
      other.gradient == gradient &&
      other.showValue == showValue &&
      other.rightToLeft == rightToLeft &&
      other.axis == axis;

  @override
  int get hashCode => Object.hash(
    start,
    end,
    color,
    negative,
    gradient,
    showValue,
    rightToLeft,
    axis,
  );

  @override
  String toString() =>
      'DataBarResult($start–$end, $color${axis == null ? '' : ', axis $axis'})';
}

/// An icon to paint left of the text (06 §15.7).
final class IconResult {
  /// Creates a result.
  const IconResult(this.set, this.index, {this.showValue = true});

  /// The icon set.
  final IconSetKind set;

  /// Icon index (0 = icon of the highest threshold, after `reverse`).
  final int index;

  /// Whether the cell text is shown.
  final bool showValue;

  @override
  bool operator ==(Object other) =>
      other is IconResult &&
      other.set == set &&
      other.index == index &&
      other.showValue == showValue;

  @override
  int get hashCode => Object.hash(set, index, showValue);

  @override
  String toString() => 'IconResult(${set.id}, $index)';
}

/// The conditional formatting of one cell (06 §15.8).
final class CfResult {
  /// Creates a result.
  const CfResult({
    required this.overlay,
    this.scaleColor,
    this.dataBar,
    this.icon,
  });

  /// No conditional formatting.
  static final CfResult none = CfResult(overlay: CellFormat.empty);

  /// The format overlay (bold, italic, underline, strikethrough, textColor,
  /// fillColor), including a color scale's fill when it won the fill attribute.
  final CellFormat overlay;

  /// The color scale color that set the fill, if any.
  final String? scaleColor;

  /// The data bar, if any.
  final DataBarResult? dataBar;

  /// The icon, if any.
  final IconResult? icon;

  /// Whether nothing applies.
  bool get isEmpty => overlay.isEmpty && dataBar == null && icon == null;

  @override
  bool operator ==(Object other) =>
      other is CfResult &&
      other.overlay == overlay &&
      other.scaleColor == scaleColor &&
      other.dataBar == dataBar &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(overlay, scaleColor, dataBar, icon);

  @override
  String toString() =>
      'CfResult(${overlay.toMap()}, scale: $scaleColor, bar: $dataBar, icon: $icon)';
}

/// A rule being edited in the CF panel, previewed without persisting
/// (06 §15.9). [ruleId] equal to an existing rule replaces it; [sortKey] places
/// it among the sheet's rules.
final class CfDraft {
  /// Creates a draft.
  const CfDraft({
    required this.sheetId,
    required this.ruleId,
    required this.sortKey,
    required this.ranges,
    required this.rule,
  });

  final String sheetId;
  final String ruleId;
  final String sortKey;

  /// Applied rectangles (the first one's top-left is the formula anchor).
  final List<GridRect> ranges;
  final CfRule rule;
}

final Object _noResult = Object();

final class _RuleState {
  _RuleState(
    this.id,
    this.sortKey,
    this.ruleJson,
    this.rangesJson,
    this.rule,
    this.rects,
    this.generation,
  );

  final String id;
  final String sortKey;
  final String ruleJson;
  final String rangesJson;
  final CfRule rule;
  final List<GridRect> rects;
  final (int, int) generation;
  CompiledCondition? compiled;
  RangeStats? stats;
  List<double?>? thresholds;

  /// rowId → colId → result (bool, color, DataBarResult, IconResult or [_noResult]).
  final Map<String, Map<String, Object>> results = {};

  CellPos get anchor =>
      rects.isEmpty ? const CellPos(0, 0) : rects.first.topLeft;

  void clear() {
    results.clear();
    stats = null;
    thresholds = null;
  }
}

/// Evaluates the conditional formatting of cells (06 §15.8, §15.10).
///
/// Rules are taken from `SheetModel.cfRules` in `(sortKey, id)` order and
/// matched through the sheet's `RuleIndex`. Per-rule results are cached keyed
/// `(ruleId, rowId, colId)`; callers invalidate with [invalidateRule],
/// [invalidateCells] and [invalidateAll] (e.g. after recalc batches, rule
/// changes or the volatile midnight tick).
final class CfEvaluator {
  /// Creates the evaluator.
  CfEvaluator(
    this.model,
    this.values,
    this.displayText,
    this.hooks, {
    SpreadsheetDates? dates,
    String? locale,
  }) : conditions = ConditionEvaluator(
         locale: locale ?? model.spreadsheet.locale,
         dates: dates ?? SpreadsheetDates(timeZone: model.spreadsheet.timeZone),
         hooks: hooks,
       );

  /// The workbook.
  final WorkbookModel model;

  /// Computed values.
  final CellSource values;

  /// Display formatting (kept for consumers that render CF previews).
  final DisplayTextProvider displayText;

  /// Formula services (custom formulas, `=` values, formula thresholds).
  final FormulaHooks? hooks;

  /// The shared condition evaluator.
  final ConditionEvaluator conditions;

  final Map<String, _RuleState> _states = {};
  CfDraft? _draft;

  /// Statistics of large ranges (06 §15.10: computed in the background when
  /// a rule's ranges cover more than [asyncStatsCells] cells). Returns the
  /// stats, or null while they are not ready: such rules then render
  /// nothing and nothing is cached for them. Null = always synchronous.
  RangeStats? Function(String sheetId, String ruleId, List<GridRect> rects)?
  asyncStats;

  /// Cells from which [asyncStats] is used.
  int asyncStatsCells = 100000;
  _RuleState? _draftState;

  /// Sets (or clears) the draft rule previewed by the editor.
  void setDraft(CfDraft? draft) {
    _draft = draft;
    _draftState = null;
  }

  /// The current draft.
  CfDraft? get draft => _draft;

  /// Drops the cached results and stats of [ruleId].
  void invalidateRule(String ruleId) {
    _states.remove(ruleId);
    if (_draft?.ruleId == ruleId) _draftState?.clear();
  }

  /// Drops cached results of the given cells of [sheetId]; rules depending on
  /// range statistics whose ranges contain a changed cell are dropped entirely.
  void invalidateCells(String sheetId, Iterable<CellKey> keys) {
    final sheet = model.sheet(sheetId);
    final list = keys.toList();
    if (list.isEmpty) return;
    for (final st in [..._states.values, ?_draftState]) {
      final rec = sheet?.cfRules[st.id];
      if (rec == null && st != _draftState) continue;
      if (st.rule.usesRangeStats && sheet != null) {
        final hit = list.any((k) {
          final r = sheet.rows.indexOf(k.rowId);
          final c = sheet.columns.indexOf(k.colId);
          return r >= 0 &&
              c >= 0 &&
              st.rects.any((rect) => rect.contains(r, c));
        });
        if (hit) {
          st.clear();
          continue;
        }
      }
      for (final k in list) {
        st.results[k.rowId]?.remove(k.colId);
      }
    }
  }

  /// Drops all caches (e.g. midnight / volatile tick, locale change).
  void invalidateAll() {
    _states.clear();
    _draftState = null;
  }

  /// Statistics of the numeric values of a rule's ranges.
  RangeStats rangeStats(String sheetId, String ruleId) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return RangeStats.empty;
    final st = _ruleState(sheet, ruleId);
    if (st == null) return RangeStats.empty;
    return _statsOrPending(sheet, st) ?? RangeStats.empty;
  }

  // ---------------------------------------------------------------------------

  _RuleState? _ruleState(SheetModel sheet, String ruleId) {
    final d = _draft;
    if (d != null && d.ruleId == ruleId && d.sheetId == sheet.id) {
      return _draftState ??= _RuleState(
        d.ruleId,
        d.sortKey,
        '',
        '',
        d.rule,
        d.ranges,
        (sheet.rows.generation, sheet.columns.generation),
      );
    }
    final rec = sheet.cfRules[ruleId];
    if (rec == null) {
      _states.remove(ruleId);
      return null;
    }
    final gen = (sheet.rows.generation, sheet.columns.generation);
    final cached = _states[ruleId];
    if (cached != null &&
        cached.ruleJson == rec.ruleJson &&
        cached.rangesJson == rec.rangesJson &&
        cached.sortKey == rec.sortKey &&
        cached.generation == gen) {
      return cached;
    }
    final rects = [
      for (final r in GridRange.parseList(rec.rangesJson))
        if (sheet.resolve(r) case final ResolvedRange rr) rr.rect,
    ];
    final st = _RuleState(
      ruleId,
      rec.sortKey,
      rec.ruleJson,
      rec.rangesJson,
      CfRule.parse(rec.ruleJson),
      rects,
      gen,
    );
    _states[ruleId] = st;
    return st;
  }

  RangeStats _stats(SheetModel sheet, _RuleState st) =>
      _statsOrPending(sheet, st) ?? RangeStats.empty;

  /// The stats of [st], or null while [asyncStats] computes them.
  RangeStats? _statsOrPending(SheetModel sheet, _RuleState st) {
    final cached = st.stats;
    if (cached != null) return cached;
    final f = asyncStats;
    if (f != null && st.rule.usesRangeStats) {
      var cells = 0;
      for (final r in st.rects) {
        cells += r.cellCount;
      }
      if (cells > asyncStatsCells) {
        return st.stats = f(sheet.id, st.id, st.rects);
      }
    }
    return st.stats = RangeStats.collect(sheet, values, st.rects);
  }

  /// The rules applying at a cell, in priority order.
  List<_RuleState> _candidates(SheetModel sheet, int row, int col) {
    final ids = sheet.rulesAt(RuleKind.conditionalFormat, row, col);
    final d = _draft;
    final out = <_RuleState>[];
    for (final id in ids) {
      if (d != null && d.sheetId == sheet.id && d.ruleId == id) continue;
      final rec = sheet.cfRules[id];
      if (rec == null || !rec.enabled) continue;
      final st = _ruleState(sheet, id);
      if (st != null) out.add(st);
    }
    if (d != null &&
        d.sheetId == sheet.id &&
        d.ranges.any((r) => r.contains(row, col))) {
      final st = _ruleState(sheet, d.ruleId);
      if (st != null) out.add(st);
    }
    if (out.length > 1) {
      out.sort((a, b) {
        final c = a.sortKey.compareTo(b.sortKey);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    }
    return out;
  }

  /// The conditional formatting of the cell at ([row], [col]) of [sheetId].
  CfResult evaluate(String sheetId, int row, int col) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return CfResult.none;
    final rules = _candidates(sheet, row, col);
    if (rules.isEmpty) return CfResult.none;
    final rowId = sheet.rows.tryIdAt(row);
    final colId = sheet.columns.tryIdAt(col);
    if (rowId == null || colId == null) return CfResult.none;
    Map<FormatAttr, Object?>? fmt;
    String? scaleColor;
    DataBarResult? bar;
    IconResult? icon;
    CellValue? value;
    CellValue cellValue() =>
        value ??= values.valueAt(sheetId, row, col).toCellValue();

    for (final st in rules) {
      final rule = st.rule;
      if (rule is CfDataBarRule && bar != null) continue;
      if (rule is CfIconSetRule && icon != null) continue;
      if (rule is CfColorScaleRule &&
          (fmt?.containsKey(FormatAttr.fillColor) ?? false)) {
        continue;
      }
      final cached = st.results[rowId]?[colId];
      final Object result;
      if (cached != null) {
        result = cached;
      } else if (rule.usesRangeStats && _statsOrPending(sheet, st) == null) {
        // Large-range stats still computing: no scale yet, nothing cached.
        continue;
      } else {
        result = _evaluateRule(sheet, st, row, col, cellValue()) ?? _noResult;
        (st.results[rowId] ??= {})[colId] = result;
      }
      switch (rule) {
        case CfBooleanRule():
          if (result != true) continue;
          final f = fmt ??= {};
          for (final a in rule.format.attrs) {
            f.putIfAbsent(a, () => rule.format[a]);
          }
        case CfColorScaleRule():
          if (result is String) {
            (fmt ??= {})[FormatAttr.fillColor] = result;
            scaleColor = result;
          }
        case CfDataBarRule():
          if (result is DataBarResult) bar = result;
        case CfIconSetRule():
          if (result is IconResult) icon = result;
        case CfUnknownRule():
          break;
      }
      if (rule is CfBooleanRule && result == true && rule.stopIfTrue) break;
    }
    if (fmt == null && bar == null && icon == null) return CfResult.none;
    return CfResult(
      overlay: fmt == null
          ? CellFormat.empty
          : CellFormat.intern(CellFormat(fmt)),
      scaleColor: scaleColor,
      dataBar: bar,
      icon: icon,
    );
  }

  /// The conditional formatting of every cell of [rect] on [sheetId] that has
  /// any (06 §15.10 visible-first evaluation: pass the visible window plus
  /// overscan). Cells without conditional formatting are omitted. Only cells
  /// covered by a rule (or the draft) are visited.
  Map<CellPos, CfResult> evaluateRect(String sheetId, GridRect rect) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return const {};
    final parts = <GridRect>[];
    for (final id in sheet.rulesIntersecting(
      RuleKind.conditionalFormat,
      rect,
    )) {
      for (final r in sheet.ruleRects(RuleKind.conditionalFormat, id)) {
        if (r.intersection(rect) case final GridRect i) parts.add(i);
      }
    }
    final d = _draft;
    if (d != null && d.sheetId == sheetId) {
      for (final r in d.ranges) {
        if (r.intersection(rect) case final GridRect i) parts.add(i);
      }
    }
    if (parts.isEmpty) return const {};
    final out = <CellPos, CfResult>{};
    final visited = parts.length > 1 ? <CellPos>{} : null;
    for (final p in parts) {
      for (var r = p.top; r <= p.bottom; r++) {
        for (var c = p.left; c <= p.right; c++) {
          final pos = CellPos(r, c);
          if (visited != null && !visited.add(pos)) continue;
          final res = evaluate(sheetId, r, c);
          if (!res.isEmpty) out[pos] = res;
        }
      }
    }
    return out;
  }

  /// Evaluates one rule for a cell: bool (boolean rules), color string,
  /// [DataBarResult] or [IconResult]; null when nothing applies.
  Object? _evaluateRule(
    SheetModel sheet,
    _RuleState st,
    int row,
    int col,
    CellValue value,
  ) {
    final rule = st.rule;
    switch (rule) {
      case CfBooleanRule():
        final a = st.anchor;
        final c = st.compiled ??= conditions.compile(
          rule.condition,
          sheetId: sheet.id,
          anchorRow: a.row,
          anchorCol: a.col,
        );
        return c.test(
          value,
          row: row,
          col: col,
          // Only `dateIsValid` reads the format; skip the lookup otherwise.
          numberFormat:
              rule.condition.type.family == ConditionFamily.dateValidity
              ? values.numberFormatAt(sheet.id, row, col)
              : null,
        );
      case CfColorScaleRule():
        if (value is! NumberValue) return null;
        return _scaleColor(sheet, st, rule, value.number);
      case CfDataBarRule():
        if (value is! NumberValue) return null;
        return _dataBar(sheet, st, rule, value.number);
      case CfIconSetRule():
        if (value is! NumberValue) return null;
        return _icon(sheet, st, rule, value.number);
      case CfUnknownRule():
        return null;
    }
  }

  double? _threshold(SheetModel sheet, _RuleState st, CfThreshold t) {
    final stats = _stats(sheet, st);
    double? literal(String? text) {
      if (text == null) return null;
      if (text.startsWith('=') && text.length > 1) {
        final h = hooks;
        if (h == null) return null;
        final a = st.anchor;
        final r = h.evaluateRelative(
          text,
          sheetId: sheet.id,
          anchorRow: a.row,
          anchorCol: a.col,
          row: a.row,
          col: a.col,
        );
        return r is FError
            ? null
            : ValueText.numberOf(r, locale: conditions.locale);
      }
      return ValueText.parseNumber(text, locale: conditions.locale);
    }

    switch (t.kind) {
      case CfValueKind.min:
        return stats.isEmpty ? null : stats.min;
      case CfValueKind.max:
        return stats.isEmpty ? null : stats.max;
      case CfValueKind.number:
      case CfValueKind.formula:
        return literal(t.value);
      case CfValueKind.percent:
        final p = literal(t.value);
        if (p == null || stats.isEmpty) return null;
        return stats.min + p / 100 * (stats.max - stats.min);
      case CfValueKind.percentile:
        final p = literal(t.value);
        if (p == null || stats.isEmpty) return null;
        return stats.percentile(p / 100);
    }
  }

  List<double?> _thresholds(
    SheetModel sheet,
    _RuleState st,
    List<CfThreshold> ts,
  ) => st.thresholds ??= [for (final t in ts) _threshold(sheet, st, t)];

  String _color(String c) => model.theme.resolveColor(c) ?? c;

  String? _scaleColor(
    SheetModel sheet,
    _RuleState st,
    CfColorScaleRule rule,
    double v,
  ) {
    final pts = rule.points;
    final ts = _thresholds(sheet, st, [for (final p in pts) p.threshold]);
    final xs = <double>[];
    final cs = <String>[];
    for (var i = 0; i < pts.length; i++) {
      final x = ts[i];
      if (x == null) continue;
      xs.add(x);
      cs.add(_color(pts[i].color));
    }
    if (xs.isEmpty) return null;
    if (v <= xs.first) return cs.first;
    if (v >= xs.last) return cs.last;
    for (var i = 0; i + 1 < xs.length; i++) {
      if (v <= xs[i + 1]) {
        final span = xs[i + 1] - xs[i];
        final t = span <= 0 ? 1.0 : (v - xs[i]) / span;
        return ColorUtil.lerp(cs[i], cs[i + 1], t);
      }
    }
    return cs.last;
  }

  DataBarResult? _dataBar(
    SheetModel sheet,
    _RuleState st,
    CfDataBarRule rule,
    double v,
  ) {
    final ts = _thresholds(sheet, st, [rule.min, rule.max]);
    var min = ts[0];
    var max = ts[1];
    if (min == null || max == null) return null;
    if (min > max) (min, max) = (max, min);
    final rtl = switch (rule.direction) {
      DataBarDirection.ltr => false,
      DataBarDirection.rtl => true,
      DataBarDirection.context => sheet.record?.rightToLeft ?? false,
    };
    final x = v.clamp(min, max);
    final negative = v < 0;
    final color = _color(negative ? rule.negativeColor : rule.color);
    DataBarResult make(double s, double e, double? axis) => DataBarResult(
      start: s.clamp(0.0, 1.0),
      end: e.clamp(0.0, 1.0),
      color: color,
      negative: negative,
      gradient: rule.gradient,
      showValue: rule.showValue,
      rightToLeft: rtl,
      axis: axis,
    );
    final span = max - min;
    switch (rule.axis) {
      case DataBarAxis.middle:
        final m = min.abs() > max.abs() ? min.abs() : max.abs();
        if (m == 0) return make(0.5, 0.5, 0.5);
        final f = 0.5 * x / m;
        return negative ? make(0.5 + f, 0.5, 0.5) : make(0.5, 0.5 + f, 0.5);
      case DataBarAxis.auto when min < 0 && max > 0:
        final axis = -min / span;
        final pos = (x - min) / span;
        return negative ? make(pos, axis, axis) : make(axis, pos, axis);
      case DataBarAxis.auto when max <= 0 && min < 0:
        // All values negative: the axis sits at the far edge and bars grow
        // away from it, the most negative value being the longest.
        if (span <= 0) return make(0, 1, 1);
        return make((x - min) / span, 1, 1);
      case DataBarAxis.auto:
      case DataBarAxis.none:
        if (span <= 0) return make(0, 1, null);
        return make(0, (x - min) / span, null);
    }
  }

  IconResult? _icon(
    SheetModel sheet,
    _RuleState st,
    CfIconSetRule rule,
    double v,
  ) {
    final n = rule.set.iconCount;
    final ts = _thresholds(sheet, st, [
      for (final t in rule.thresholds) t.threshold,
    ]);
    var index = n - 1;
    for (var i = 0; i < rule.thresholds.length && i < n - 1; i++) {
      final x = ts[i];
      if (x == null) continue;
      final pass = rule.thresholds[i].inclusive ? v >= x : v > x;
      if (pass) {
        index = i;
        break;
      }
    }
    if (rule.reverse) index = n - 1 - index;
    return IconResult(rule.set, index, showValue: rule.showValue);
  }
}
