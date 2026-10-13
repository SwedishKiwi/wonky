import '../../addressing/grid_geometry.dart';

/// Where to search (07 §11.2 `searchIn`).
enum FindScope { allSheets, sheet, range }

/// Thrown by [FindQuery.compile] for invalid regular expressions.
final class FindPatternException implements Exception {
  /// Creates the exception.
  const FindPatternException(this.message);

  /// Inline error under the input.
  final String message;

  @override
  String toString() => 'FindPatternException: $message';
}

/// A find / replace query (07 §11).
final class FindQuery {
  /// Creates a query. The find bar uses the defaults (active sheet,
  /// case-insensitive, partial match, display values).
  const FindQuery(
    this.query, {
    this.matchCase = false,
    this.entireCell = false,
    this.regex = false,
    this.searchFormulas = false,
    this.searchLinks = false,
    this.scope = FindScope.sheet,
    this.sheetId,
    this.range,
  });

  final String query;
  final bool matchCase;

  /// Match entire cell contents.
  final bool entireCell;

  /// Search using regular expressions.
  final bool regex;

  /// Also search within formulas (A1 text).
  final bool searchFormulas;

  /// Also search within links (P1).
  final bool searchLinks;
  final FindScope scope;

  /// Sheet of [FindScope.sheet] / [FindScope.range].
  final String? sheetId;

  /// Rectangle of [FindScope.range].
  final GridRect? range;

  /// Compiles the matcher. Throws [FindPatternException] for invalid patterns.
  FindMatcher compile() {
    if (query.isEmpty) {
      throw const FindPatternException('Enter something to search for');
    }
    final body = regex ? query : RegExp.escape(query);
    final pattern = entireCell ? '^(?:$body)\$' : body;
    try {
      return FindMatcher._(
        RegExp(pattern, caseSensitive: matchCase, unicode: regex),
        regex: regex,
      );
    } on FormatException catch (e) {
      throw FindPatternException('Invalid regular expression: ${e.message}');
    }
  }
}

/// A compiled query: matching and replacement on texts.
final class FindMatcher {
  FindMatcher._(this.pattern, {required this.regex});

  /// The compiled pattern.
  final RegExp pattern;

  /// Whether `$` expansion applies to replacements.
  final bool regex;

  /// Whether [text] contains a match.
  bool matches(String text) => pattern.hasMatch(text);

  /// Number of matches in [text] (non-empty matches; an empty match counts once).
  int countIn(String text) {
    var n = 0;
    for (final _ in pattern.allMatches(text)) {
      n++;
    }
    return n;
  }

  /// [text] with every match replaced. In regex mode `$1`…`$99`, `$&` and `$$`
  /// are expanded; otherwise [replacement] is literal. Returns the new text and
  /// the replaced spans `(oldStart, oldEnd, newStart, newEnd)`.
  (String, List<(int, int, int, int)>) replaceAll(
    String text,
    String replacement,
  ) {
    final out = StringBuffer();
    final spans = <(int, int, int, int)>[];
    var last = 0;
    for (final m in pattern.allMatches(text)) {
      out.write(text.substring(last, m.start));
      final r = regex ? expand(m, replacement) : replacement;
      final ns = out.length;
      out.write(r);
      spans.add((m.start, m.end, ns, out.length));
      last = m.end;
    }
    out.write(text.substring(last));
    return (out.toString(), spans);
  }

  /// Expands `$1`…`$99`, `$&` and `$$` of [replacement] for match [m]. Two-digit
  /// groups are used when that group exists, else one digit; unknown groups are
  /// kept literally.
  static String expand(Match m, String replacement) {
    final b = StringBuffer();
    var i = 0;
    final n = replacement.length;
    while (i < n) {
      final ch = replacement.codeUnitAt(i);
      if (ch != 0x24 || i + 1 >= n) {
        b.writeCharCode(ch);
        i++;
        continue;
      }
      final next = replacement.codeUnitAt(i + 1);
      if (next == 0x24) {
        b.write(r'$');
        i += 2;
      } else if (next == 0x26) {
        b.write(m.group(0));
        i += 2;
      } else if (next >= 0x30 && next <= 0x39) {
        final d1 = next - 0x30;
        var used = 0;
        var group = -1;
        if (i + 2 < n) {
          final c2 = replacement.codeUnitAt(i + 2);
          if (c2 >= 0x30 && c2 <= 0x39) {
            final g2 = d1 * 10 + (c2 - 0x30);
            if (g2 >= 1 && g2 <= m.groupCount) {
              group = g2;
              used = 3;
            }
          }
        }
        if (group < 0 && d1 >= 1 && d1 <= m.groupCount) {
          group = d1;
          used = 2;
        }
        if (group < 0) {
          b.write(r'$');
          i++;
        } else {
          b.write(m.group(group) ?? '');
          i += used;
        }
      } else {
        b.write(r'$');
        i++;
      }
    }
    return b.toString();
  }
}
