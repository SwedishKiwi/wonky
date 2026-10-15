import 'dart:math' as math;

/// A range of highlighted lines (1-based, inclusive), optionally limited to
/// columns `[startColumn, endColumn]` of a single line (P2 syntax
/// `line:col-col`, 1-based inclusive columns).
final class LineRange {
  /// Creates a range.
  const LineRange(
    this.first,
    this.last, {
    this.startColumn,
    this.endColumn,
    this.openEnded = false,
  });

  /// First line (1-based).
  final int first;

  /// Last line (1-based, ≥ [first]); for an [openEnded] range parsed
  /// without a line count, equal to [first].
  final int last;

  /// `7-` parsed without a line count: every line from [first] on.
  final bool openEnded;

  /// First highlighted column of a column range (1-based), or null.
  final int? startColumn;

  /// Last highlighted column of a column range (1-based), or null.
  final int? endColumn;

  /// Whether this is a column range within one line.
  bool get isColumnRange => startColumn != null;

  /// Whether [line] (1-based) is in the range.
  bool contains(int line) => line >= first && (openEnded || line <= last);

  /// The normalized text (`3`, `1-3`, `4:2-9`).
  String get text => isColumnRange
      ? '$first:$startColumn-$endColumn'
      : openEnded
      ? '$first-'
      : first == last
      ? '$first'
      : '$first-$last';

  @override
  bool operator ==(Object other) =>
      other is LineRange &&
      other.first == first &&
      other.last == last &&
      other.startColumn == startColumn &&
      other.endColumn == endColumn &&
      other.openEnded == openEnded;

  @override
  int get hashCode =>
      Object.hash(first, last, startColumn, endColumn, openEnded);

  @override
  String toString() => 'LineRange($text)';
}

/// One highlight step: the highlighted ranges, or none ("show all": every
/// line normal).
final class HighlightStep {
  /// Creates a step.
  const HighlightStep(this.ranges);

  /// A step that highlights nothing (all lines normal).
  static const all = HighlightStep([]);

  /// Ranges in input order.
  final List<LineRange> ranges;

  /// Whether this step shows all lines normally.
  bool get isAll => ranges.isEmpty;

  /// Whether [line] (1-based) is highlighted. In an "all" step no line is.
  bool highlights(int line) => ranges.any((r) => r.contains(line));

  /// The highlighted lines (1-based, sorted, distinct; open-ended ranges
  /// count their first line only — parse with a line count to clamp).
  List<int> get lines {
    final out = <int>{};
    for (final r in ranges) {
      for (var l = r.first; l <= r.last; l++) {
        out.add(l);
      }
    }
    return out.toList()..sort();
  }

  /// Contiguous runs of highlighted lines `(first, last)`, sorted.
  List<(int, int)> get blocks {
    final ls = lines;
    final out = <(int, int)>[];
    for (final l in ls) {
      if (out.isNotEmpty && out.last.$2 == l - 1) {
        out.last = (out.last.$1, l);
      } else {
        out.add((l, l));
      }
    }
    return out;
  }

  /// The last highlighted line (callout default anchor), or null.
  int? get lastLine =>
      ranges.isEmpty ? null : ranges.map((r) => r.last).reduce(math.max);

  /// The normalized text of the step (`1-3,5`; "" for an "all" step).
  String get text => ranges.map((r) => r.text).join(',');

  @override
  bool operator ==(Object other) =>
      other is HighlightStep &&
      other.ranges.length == ranges.length &&
      Iterable<int>.generate(
        ranges.length,
      ).every((i) => other.ranges[i] == ranges[i]);

  @override
  int get hashCode => Object.hashAll(ranges);

  @override
  String toString() => 'HighlightStep(${isAll ? '*' : text})';
}

/// A problem found while parsing highlight steps (Slides 07 §4.1).
final class HighlightIssue {
  /// Creates an issue.
  const HighlightIssue(this.code, this.message, {this.step});

  /// `lineOutOfRange`, `pastEnd`, `reversedRange`, `syntax`, `columnRange`.
  final String code;

  /// English message for the inspector ("Line 40 doesn't exist (the code
  /// has 32 lines)").
  final String message;

  /// 0-based step index, or null.
  final int? step;

  @override
  String toString() => 'HighlightIssue($code, $message)';
}

/// The result of [HighlightSteps.parse].
final class HighlightStepsResult {
  /// Creates a result.
  const HighlightStepsResult(this.steps, this.issues);

  /// No steps.
  static const empty = HighlightStepsResult([], []);

  /// Steps in order (empty steps kept: they show all lines).
  final List<HighlightStep> steps;

  /// Problems (clamped lines, swapped ranges, syntax errors).
  final List<HighlightIssue> issues;

  /// Number of steps.
  int get length => steps.length;

  /// The normalized form written on blur (`1-3|5|7-9`; "show all" steps are
  /// written `*`). Empty when there are no steps.
  String get normalized => steps.map((s) => s.isAll ? '*' : s.text).join('|');

  /// Step [index] (0-based), or null.
  HighlightStep? operator [](int index) =>
      index >= 0 && index < steps.length ? steps[index] : null;
}

/// Line-highlight steps (Slides 07 §4.1): reveal.js syntax, extended.
///
/// ```
/// steps   := step ( "|" step )*
/// step    := "" | "*" | items          // "" or "*" = no highlight
/// items   := item ( "," item )*
/// item    := line | line "-" line | line "-" | line ":" col "-" col
/// ```
///
/// Line numbers are physical lines of the state (1-based), independent of
/// `startLine`; with a leading `@` they are displayed numbers (offset by
/// `startLine − 1`). Whitespace is ignored. Out-of-range lines are clamped
/// with an issue, reversed ranges swapped, empty steps kept, invalid items
/// dropped with a syntax issue.
abstract final class HighlightSteps {
  /// Parses [input] for code with [lineCount] lines (null = don't clamp).
  /// An empty or null input has no steps.
  static HighlightStepsResult parse(
    String? input, {
    int? lineCount,
    int startLine = 1,
  }) {
    if (input == null) return HighlightStepsResult.empty;
    var text = input.replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) return HighlightStepsResult.empty;
    var offset = 0;
    if (text.startsWith('@')) {
      text = text.substring(1);
      offset = startLine - 1;
    }
    final steps = <HighlightStep>[];
    final issues = <HighlightIssue>[];
    final parts = text.split('|');
    for (var si = 0; si < parts.length; si++) {
      final part = parts[si];
      if (part.isEmpty || part == '*') {
        steps.add(HighlightStep.all);
        continue;
      }
      final ranges = <LineRange>[];
      for (final item in part.split(',')) {
        if (item.isEmpty) continue;
        final r = _item(item, si, offset, lineCount, issues);
        if (r != null) ranges.add(r);
      }
      steps.add(ranges.isEmpty ? HighlightStep.all : HighlightStep(ranges));
    }
    return HighlightStepsResult(steps, issues);
  }

  /// Number of steps of [input] (cheap; for timelines).
  static int count(String? input) => parse(input).length;

  /// Checks parsed [steps] against code with [lineCount] lines: one
  /// `pastEnd` issue per step pointing past the end ("Step 3 points past the
  /// end", shown when a state's code changed).
  static List<HighlightIssue> validate(
    List<HighlightStep> steps,
    int lineCount,
  ) => [
    for (var i = 0; i < steps.length; i++)
      if (steps[i].ranges.any((r) => r.last > lineCount))
        HighlightIssue('pastEnd', 'Step ${i + 1} points past the end', step: i),
  ];

  static final _line = RegExp(r'^(\d+)$');
  static final _range = RegExp(r'^(\d+)-(\d*)$');
  static final _cols = RegExp(r'^(\d+):(\d+)-(\d+)$');

  static LineRange? _item(
    String item,
    int step,
    int offset,
    int? lineCount,
    List<HighlightIssue> issues,
  ) {
    int? first, last, c0, c1;
    var open = false;
    if (_line.firstMatch(item) case final m?) {
      first = last = int.parse(m[1]!);
    } else if (_range.firstMatch(item) case final m?) {
      first = int.parse(m[1]!);
      last = m[2]!.isEmpty ? null : int.parse(m[2]!);
      if (last == null) {
        if (lineCount == null) {
          open = true;
          last = first;
        } else {
          last = math.max(first, lineCount + offset);
        }
      }
    } else if (_cols.firstMatch(item) case final m?) {
      first = last = int.parse(m[1]!);
      c0 = int.parse(m[2]!);
      c1 = int.parse(m[3]!);
      if (c0 < 1 || c1 < 1) {
        issues.add(
          HighlightIssue(
            'columnRange',
            'Columns start at 1 ("$item")',
            step: step,
          ),
        );
        c0 = math.max(1, c0);
        c1 = math.max(1, c1);
      }
      if (c1 < c0) (c0, c1) = (c1, c0);
    } else {
      issues.add(
        HighlightIssue(
          'syntax',
          '"$item" isn\'t a line, a range like 3-5 or 7-, or 4:2-9',
          step: step,
        ),
      );
      return null;
    }
    first -= offset;
    last -= offset;
    if (last < first) {
      issues.add(
        HighlightIssue('reversedRange', 'Range $item was reversed', step: step),
      );
      (first, last) = (last, first);
    }
    if (first < 1) {
      issues.add(
        HighlightIssue(
          'lineOutOfRange',
          'Line ${first + offset} doesn\'t exist (lines start at ${1 + offset})',
          step: step,
        ),
      );
      first = 1;
      if (last < 1) last = 1;
    }
    if (lineCount != null && lineCount > 0) {
      if (last > lineCount) {
        final shown = last + offset;
        issues.add(
          HighlightIssue(
            'lineOutOfRange',
            'Line $shown doesn\'t exist (the code has $lineCount '
                '${lineCount == 1 ? 'line' : 'lines'})',
            step: step,
          ),
        );
      }
      last = math.min(last, lineCount);
      first = math.min(first, lineCount);
    }
    return LineRange(
      first,
      last,
      startColumn: c0,
      endColumn: c1,
      openEnded: open,
    );
  }
}
