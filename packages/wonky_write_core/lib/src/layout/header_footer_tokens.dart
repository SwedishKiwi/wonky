/// Header/footer slot tokens (07 §6.3).
library;

import 'page_setup.dart';

/// Values for token expansion.
final class TokenContext {
  /// Creates a context.
  const TokenContext({
    this.title = '',
    this.author = '',
    required this.now,
    this.modified,
    this.locale = 'en-US',
    this.pageIndex = 0,
    this.pageCount = 1,
    this.pageNumberStart = 1,
    this.pageNumberFormat = PageNumberFormat.decimal,
  });

  /// `{title}`: Drive item name.
  final String title;

  /// `{author}`: owner display name or front matter `author`.
  final String author;

  /// `{date}`: export/print time (injected; never `DateTime.now()`).
  final DateTime now;

  /// `{modified}`: last modification time.
  final DateTime? modified;

  /// Locale for date formats.
  final String locale;

  /// 0-based physical page index.
  final int pageIndex;

  /// Physical page count.
  final int pageCount;

  /// Logical number of the first page.
  final int pageNumberStart;

  /// Number format.
  final PageNumberFormat pageNumberFormat;

  /// Copy for another page.
  TokenContext forPage(int index, int count) => TokenContext(
    title: title,
    author: author,
    now: now,
    modified: modified,
    locale: locale,
    pageIndex: index,
    pageCount: count,
    pageNumberStart: pageNumberStart,
    pageNumberFormat: pageNumberFormat,
  );
}

/// Expands `{title}`, `{page}`, `{pages}`, `{date}`, `{date:<pattern>}`,
/// `{author}`, `{modified}`; `{{`/`}}` are literal braces; unknown tokens
/// render literally.
abstract final class HeaderFooterTokens {
  static final _token = RegExp(r'\{\{|\}\}|\{([a-z]+)(?::([^{}]*))?\}');

  /// Known token names.
  static const names = {'title', 'page', 'pages', 'date', 'author', 'modified'};

  /// Expands [template] for [ctx].
  static String expand(String template, TokenContext ctx) => template.replaceAllMapped(_token, (m) {
    final all = m.group(0)!;
    if (all == '{{') return '{';
    if (all == '}}') return '}';
    final name = m.group(1)!;
    final pattern = m.group(2);
    switch (name) {
      case 'title':
        return ctx.title;
      case 'author':
        return ctx.author;
      case 'page':
        return ctx.pageNumberFormat.format(ctx.pageNumberStart + ctx.pageIndex);
      case 'pages':
        return ctx.pageNumberFormat.format(ctx.pageNumberStart + ctx.pageCount - 1);
      case 'date':
        return pattern == null ? mediumDate(ctx.now, ctx.locale) : formatDate(ctx.now, pattern, ctx.locale);
      case 'modified':
        final t = ctx.modified;
        if (t == null) return '';
        return pattern == null ? mediumDate(t, ctx.locale) : formatDate(t, pattern, ctx.locale);
    }
    return all;
  });

  /// Whether [template] uses `{pages}` (needs a second layout pass).
  static bool usesPageCount(String template) => template.contains('{pages}');

  static const _monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _daysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Locale medium date: `MMM d, y` for English (US/CA/PH), `d MMM y`
  /// elsewhere.
  static String mediumDate(DateTime t, String locale) {
    final l = locale.replaceAll('_', '-');
    final us = l == 'en' || l == 'en-US' || l == 'en-CA' || l == 'en-PH' || l == 'fil-PH';
    return formatDate(t, us ? 'MMM d, y' : 'd MMM y', locale);
  }

  /// Formats [t] with an intl-style [pattern] subset: `y yy yyyy M MM MMM
  /// MMMM d dd E EEE EEEE H HH h hh m mm s ss a`; text in `'…'` is literal.
  /// Month/day names are English.
  static String formatDate(DateTime t, String pattern, String locale) {
    final b = StringBuffer();
    var i = 0;
    while (i < pattern.length) {
      final c = pattern[i];
      if (c == "'") {
        final end = pattern.indexOf("'", i + 1);
        if (end < 0) {
          b.write(pattern.substring(i + 1));
          break;
        }
        b.write(end == i + 1 ? "'" : pattern.substring(i + 1, end));
        i = end + 1;
        continue;
      }
      var j = i;
      while (j < pattern.length && pattern[j] == c) {
        j++;
      }
      final n = j - i;
      String two(int v) => v.toString().padLeft(2, '0');
      final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
      b.write(switch (c) {
        'y' => n == 2 ? two(t.year % 100) : t.year.toString().padLeft(n, '0'),
        'M' => switch (n) {
          1 => '${t.month}',
          2 => two(t.month),
          3 => _monthsLong[t.month - 1].substring(0, 3),
          _ => _monthsLong[t.month - 1],
        },
        'd' => n >= 2 ? two(t.day) : '${t.day}',
        'E' => n >= 4 ? _daysLong[t.weekday - 1] : _daysLong[t.weekday - 1].substring(0, 3),
        'H' => n >= 2 ? two(t.hour) : '${t.hour}',
        'h' => n >= 2 ? two(hour12) : '$hour12',
        'm' => n >= 2 ? two(t.minute) : '${t.minute}',
        's' => n >= 2 ? two(t.second) : '${t.second}',
        'a' => t.hour < 12 ? 'AM' : 'PM',
        _ => pattern.substring(i, j),
      });
      i = j;
    }
    return b.toString();
  }
}
