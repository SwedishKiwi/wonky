import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../content/cell_content.dart';
import '../mutations/operations.dart' show FillMode;

/// Direction of a fill along its axis.
enum FillDirection {
  /// Down / right: targets follow the source.
  forward,

  /// Up / left: targets precede the source; series extend backwards.
  backward,
}

/// One source cell along the fill axis.
final class FillSource {
  /// Creates a source cell.
  const FillSource(this.content, {this.numberFormat});

  /// The cell content (null = empty).
  final CellContent? content;

  /// The cell's effective number format (dates/times are detected from it).
  final String? numberFormat;
}

/// Content for one target cell.
final class FillItem {
  /// Creates an item.
  const FillItem(this.sourceIndex, this.content, {this.isFormula = false});

  /// Index of the source cell this target corresponds to cyclically: formats
  /// are copied from it, and formulas are translated from its position.
  final int sourceIndex;

  /// Content to write (null = empty). For formulas this is the **source**
  /// formula; the caller translates it with `FormulaHooks.translate` from the
  /// source position to the target position.
  final CellContent? content;

  /// Whether [content] is a source formula that needs translation.
  final bool isFormula;

  @override
  bool operator ==(Object other) =>
      other is FillItem &&
      other.sourceIndex == sourceIndex &&
      other.content == content &&
      other.isFormula == isFormula;

  @override
  int get hashCode => Object.hash(sourceIndex, content, isFormula);

  @override
  String toString() =>
      'FillItem($sourceIndex, $content${isFormula ? ', formula' : ''})';
}

enum _Kind { other, number, date, time, textNumber, list }

enum _Case { asList, upper, lower }

final class _Cell {
  _Cell(
    this.kind, {
    this.value = 0,
    this.prefix = '',
    this.suffix = '',
    this.width = 0,
  });

  final _Kind kind;
  final double value;
  final String prefix;
  final String suffix;

  /// Zero-padding width of text numbers (0 = none).
  final int width;

  /// Candidate lists (index into the list table) → position in that list.
  Map<int, int> lists = const {};
  _Case textCase = _Case.asList;
}

final class _Run {
  _Run(this.start, this.kind);

  final int start;
  final _Kind kind;
  final List<_Cell> cells = [];
  int listId = -1;

  int get length => cells.length;
}

/// Series detection for the fill handle (03 §10.2), per row or column of the
/// source. [FillMode.copy] is the Alt (⌥) column of 03 §10.2: single numbers
/// step +1, every other series copies.
///
/// Targets are numbered from the source outwards: with
/// [FillDirection.forward] item 0 is the cell right after the source; with
/// [FillDirection.backward] item 0 is the cell right before it.
final class SeriesDetector {
  /// Creates a detector.
  const SeriesDetector();

  /// Shared instance.
  static const SeriesDetector instance = SeriesDetector();

  static const List<String> _quarters = ['Q1', 'Q2', 'Q3', 'Q4'];

  /// Computes [count] target items for [sources].
  ///
  /// [customLists] are the user's custom lists (Settings › Sheets); they
  /// take precedence over built-in weekday/month/quarter lists of [locale]
  /// (and English).
  List<FillItem> fill(
    List<FillSource> sources,
    int count, {
    FillDirection direction = FillDirection.forward,
    FillMode mode = FillMode.auto,
    String locale = 'en_US',
    List<List<String>> customLists = const [],
  }) {
    if (sources.isEmpty || count <= 0) return const [];
    final lists = _lists(locale, customLists);
    final index = _ListIndex(lists);
    final cells = [for (final s in sources) _classify(s, locale, index)];
    final runs = _runs(cells);
    final runOf = List<_Run?>.filled(cells.length, null);
    for (final r in runs) {
      for (var k = 0; k < r.length; k++) {
        runOf[r.start + k] = r;
      }
    }
    final l = sources.length;
    final out = <FillItem>[];
    for (var i = 0; i < count; i++) {
      final q = direction == FillDirection.forward ? l + i : -1 - i;
      final j = q % l;
      final c = _floorDiv(q, l);
      final src = sources[j];
      final content = src.content;
      if (content is FormulaContent) {
        out.add(FillItem(j, content, isFormula: true));
        continue;
      }
      final run = runOf[j]!;
      final k = j - run.start;
      final p = k + c * run.length;
      final v = _valueAt(run, p, mode, lists);
      out.add(FillItem(j, v ?? content));
    }
    return out;
  }

  static int _floorDiv(int a, int b) {
    final q = a ~/ b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
  }

  static List<List<String>> _lists(String locale, List<List<String>> custom) {
    final l = LocaleFormatData.forId(locale);
    final en = LocaleFormatData.forId('en_US');
    final lists = <List<String>>[
      for (final c in custom)
        if (c.length >= 2) c,
    ];
    final seen = <String>{};
    void add(List<String> list) {
      if (list.length < 2) return;
      final key = list.map((e) => e.toLowerCase()).join('\u0000');
      if (seen.add(key)) lists.add(list);
    }

    add(l.shortWeekdays);
    add(l.weekdays);
    add(l.standaloneShortMonths);
    add(l.shortMonths);
    add(l.months);
    add(l.standaloneMonths);
    add(en.shortWeekdays);
    add(en.weekdays);
    add(en.shortMonths);
    add(en.months);
    add(_quarters);
    return lists;
  }

  static final RegExp _lastNumber = RegExp(r'(\d+)(?!.*\d)');

  static _Cell _classify(FillSource s, String locale, _ListIndex index) {
    final content = s.content;
    switch (content) {
      case NumberContent(:final number):
        final info = NumberFormatInfo.of(s.numberFormat, locale: locale);
        if (info.isDateLike) return _Cell(_Kind.date, value: number);
        if (info.isTimeLike) return _Cell(_Kind.time, value: number);
        return _Cell(_Kind.number, value: number);
      case TextContent() || RichTextContent():
        final text = content!.plainText!;
        final lists = index.lookup(text);
        if (lists.isNotEmpty) {
          return _Cell(_Kind.list)
            ..lists = lists
            ..textCase = _caseOf(text);
        }
        final m = _lastNumber.firstMatch(text);
        if (m != null && m.group(1)!.length <= 15) {
          final digits = m.group(1)!;
          return _Cell(
            _Kind.textNumber,
            value: double.parse(digits),
            prefix: text.substring(0, m.start),
            suffix: text.substring(m.end),
            width: digits.length > 1 && digits.startsWith('0')
                ? digits.length
                : 0,
          );
        }
        return _Cell(_Kind.other);
      default:
        return _Cell(_Kind.other);
    }
  }

  static _Case _caseOf(String t) {
    final up = t.toUpperCase();
    final low = t.toLowerCase();
    if (up == low) return _Case.asList;
    if (t == up && t.length > 1) return _Case.upper;
    if (t == low) return _Case.lower;
    return _Case.asList;
  }

  static List<_Run> _runs(List<_Cell> cells) {
    final runs = <_Run>[];
    _Run? cur;
    Map<int, int>? common;
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      var join = false;
      if (cur != null && cur.kind == c.kind) {
        switch (c.kind) {
          case _Kind.number || _Kind.date || _Kind.time:
            join = true;
          case _Kind.textNumber:
            final f = cur.cells.first;
            join = f.prefix == c.prefix && f.suffix == c.suffix;
          case _Kind.list:
            final inter = {
              for (final e in common!.entries)
                if (c.lists.containsKey(e.key)) e.key: e.value,
            };
            if (inter.isNotEmpty) {
              join = true;
              common = inter;
            }
          case _Kind.other:
            join = false;
        }
      }
      if (join) {
        cur!.cells.add(c);
      } else {
        if (cur != null) _finishRun(cur, common);
        cur = _Run(i, c.kind)..cells.add(c);
        common = c.lists;
        runs.add(cur);
      }
    }
    if (cur != null) _finishRun(cur, common);
    return runs;
  }

  static void _finishRun(_Run run, Map<int, int>? common) {
    if (run.kind != _Kind.list || common == null || common.isEmpty) return;
    run.listId = common.keys.reduce((a, b) => a < b ? a : b);
  }

  CellContent? _valueAt(
    _Run run,
    int p,
    FillMode mode,
    List<List<String>> lists,
  ) {
    final r = run.length;
    final cells = run.cells;
    final auto = mode == FillMode.auto;
    switch (run.kind) {
      case _Kind.other:
        return null;
      case _Kind.number:
        if (r == 1) {
          return auto ? null : NumberContent(_clean(cells[0].value + p));
        }
        if (!auto) return null;
        return NumberContent(_clean(_trend(cells, p)));
      case _Kind.time:
        if (!auto) return null;
        final v0 = cells[0].value;
        final step = r == 1 ? 1 / 24 : cells[1].value - v0;
        return NumberContent(_clean(v0 + p * step));
      case _Kind.date:
        if (!auto) return null;
        if (r == 1) return NumberContent(_clean(cells[0].value + p));
        return NumberContent(_clean(_dateSeries(cells, p)));
      case _Kind.textNumber:
        if (!auto) return null;
        final first = cells[0];
        double n;
        if (r == 1) {
          n = first.value + p;
        } else {
          n = _trend(cells, p).roundToDouble();
        }
        var digits = n.abs().toStringAsFixed(0);
        if (first.width > 0) digits = digits.padLeft(first.width, '0');
        return TextContent('${first.prefix}$digits${first.suffix}');
      case _Kind.list:
        if (!auto) return null;
        final list = lists[run.listId];
        final n = list.length;
        final i0 = cells[0].lists[run.listId]!;
        var step = 1;
        if (r >= 2) {
          step = (cells[1].lists[run.listId]! - i0) % n;
          if (step == 0) {
            return TextContent(_applyCase(list[i0], cells[0].textCase));
          }
        }
        final idx = (i0 + p * step) % n;
        return TextContent(_applyCase(list[idx], cells[0].textCase));
    }
  }

  static String _applyCase(String s, _Case c) => switch (c) {
    _Case.upper => s.toUpperCase(),
    _Case.lower => s.toLowerCase(),
    _Case.asList => s,
  };

  static double _clean(double v) => roundToSignificantDigits(v);

  /// Linear trend: arithmetic progression step, else least-squares fit.
  static double _trend(List<_Cell> cells, int p) {
    final r = cells.length;
    final v0 = cells[0].value;
    final step = cells[1].value - v0;
    var arithmetic = true;
    for (var k = 2; k < r; k++) {
      final d = cells[k].value - cells[k - 1].value;
      final tol = 1e-9 * (d.abs() > step.abs() ? d.abs() : step.abs());
      if ((d - step).abs() > tol) {
        arithmetic = false;
        break;
      }
    }
    if (arithmetic) return v0 + p * step;
    final meanX = (r - 1) / 2;
    var meanY = 0.0;
    for (final c in cells) {
      meanY += c.value;
    }
    meanY /= r;
    var sxy = 0.0;
    var sxx = 0.0;
    for (var k = 0; k < r; k++) {
      final dx = k - meanX;
      sxy += dx * (cells[k].value - meanY);
      sxx += dx * dx;
    }
    final b = sxy / sxx;
    final a = meanY - b * meanX;
    return a + b * p;
  }

  static double _dateSeries(List<_Cell> cells, int p) {
    final days = [for (final c in cells) c.value.floor()];
    final ymd = [for (final d in days) SerialCalendar.dateOf(d)];
    bool isEom(({int year, int month, int day}) d) =>
        d.day == SerialCalendar.daysInMonth(d.year, d.month);
    final sameDay = ymd.every((d) => d.day == ymd.first.day);
    final allEom = ymd.every(isEom);
    if (sameDay || allEom) {
      int monthIndex(({int year, int month, int day}) d) =>
          d.year * 12 + d.month - 1;
      final step = monthIndex(ymd[1]) - monthIndex(ymd[0]);
      var equal = step != 0;
      for (var k = 2; k < ymd.length && equal; k++) {
        if (monthIndex(ymd[k]) - monthIndex(ymd[k - 1]) != step) equal = false;
      }
      if (equal) {
        final frac = cells[0].value - days[0];
        final preferred = allEom && !sameDay ? 31 : ymd.first.day;
        return SerialCalendar.addMonths(
              days[0],
              p * step,
              preferredDay: preferred,
            ) +
            frac;
      }
    }
    return _trend(cells, p);
  }
}

/// Case-insensitive lookup of list items.
final class _ListIndex {
  _ListIndex(List<List<String>> lists) {
    for (var id = 0; id < lists.length; id++) {
      final list = lists[id];
      for (var i = 0; i < list.length; i++) {
        (_map[list[i].toLowerCase()] ??= {}).putIfAbsent(id, () => i);
      }
    }
  }

  final Map<String, Map<int, int>> _map = {};

  Map<int, int> lookup(String text) =>
      _map[text.trim().toLowerCase()] ?? const {};
}
