import 'dart:collection';

import '../../eval/eval_context.dart';
import '../../values/errors.dart';

/// Compiles Google Sheets (RE2) regular expressions to Dart [RegExp]s (05 §15.5).
///
/// Patterns run as ECMAScript regular expressions with `unicode: true`. RE2-only syntax is
/// rewritten first: `(?P<name>…)` → `(?<name>…)`, `(?P=name)` → `\k<name>`, leading inline
/// flags `(?i)`, `(?s)`, `(?m)` → [RegExp] options, `\A`/`\z` → anchors, `\Q…\E` → escaped
/// literals, `\pL` → `\p{L}`, POSIX classes (`[[:alpha:]]`) → Unicode property escapes, and
/// RE2's lenient escapes of punctuation and stray braces → valid unicode-mode escapes. Inline
/// flags elsewhere are rejected ("Unsupported regular expression syntax").
abstract final class SheetsRegex {
  /// Longest accepted pattern (catastrophic backtracking cannot be interrupted in Dart).
  static const int maxPatternLength = 1000;

  static final LinkedHashMap<String, RegExp> _cache = LinkedHashMap();

  /// Compiles [pattern] for function [fn] (its parameter [param] holds the pattern). Throws a
  /// [FormulaError] (`#VALUE!`) for invalid or unsupported patterns.
  static RegExp compile(
    String pattern, {
    required String fn,
    int param = 2,
    bool caseSensitive = true,
  }) {
    final key = '${caseSensitive ? 1 : 0}\u0001$pattern';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    if (pattern.length > maxPatternLength) {
      fail(
        ErrorKind.value,
        'Function $fn parameter $param value is longer than the limit of '
        '$maxPatternLength characters.',
      );
    }
    final RegExp re;
    try {
      final t = translate(pattern);
      re = RegExp(
        t.source,
        unicode: true,
        caseSensitive: caseSensitive && !t.ignoreCase,
        dotAll: t.dotAll,
        multiLine: t.multiLine,
      );
    } on UnsupportedRegexSyntax {
      fail(ErrorKind.value, 'Unsupported regular expression syntax');
    } on FormatException {
      fail(
        ErrorKind.value,
        "Function $fn parameter $param value '$pattern' is not a valid regular "
        'expression.',
      );
    }
    if (_cache.length > 512) _cache.remove(_cache.keys.first);
    _cache[key] = re;
    return re;
  }

  static const String _syntaxChars = r'^$\.*+?()[]{}|/';

  static String _hex(int c) =>
      '\\x${c.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  /// Escapes one literal character for unicode-mode source (inside or outside a class).
  static String _literal(String ch) {
    final c = ch.codeUnitAt(0);
    if (ch.length == 1 && c < 0x80) {
      final isWord =
          (c >= 0x30 && c <= 0x39) ||
          (c >= 0x41 && c <= 0x5a) ||
          (c >= 0x61 && c <= 0x7a) ||
          c == 0x5f;
      if (isWord || c == 0x20) return ch;
      return _hex(c);
    }
    return ch;
  }

  static const Map<String, (String, String?)> _posix = {
    'alpha': (r'\p{L}', r'\P{L}'),
    'digit': (r'\d', r'\D'),
    'alnum': (r'\p{L}\p{Nd}', null),
    'upper': (r'\p{Lu}', r'\P{Lu}'),
    'lower': (r'\p{Ll}', r'\P{Ll}'),
    'space': (r'\s', r'\S'),
    'word': (r'\w', r'\W'),
    'punct': (r'\p{P}', r'\P{P}'),
    'xdigit': ('0-9A-Fa-f', null),
    'blank': (r' \t', null),
    'cntrl': (r'\p{Cc}', r'\P{Cc}'),
    'print': (r'\x20-\x7E', null),
    'graph': (r'\x21-\x7E', null),
    'ascii': (r'\x00-\x7F', null),
  };

  static final RegExp _quantifier = RegExp(r'\{\d+(,\d*)?\}');
  static final RegExp _flagGroup = RegExp(r'\(\?([a-zA-Z-]+)\)');

  /// Rewrites RE2 [pattern] into unicode-mode ECMAScript source plus options.
  static ({String source, bool ignoreCase, bool dotAll, bool multiLine})
  translate(String pattern) {
    var i = 0;
    var ignoreCase = false, dotAll = false, multiLine = false;
    // Leading inline flags.
    while (true) {
      final m = _flagGroup.matchAsPrefix(pattern, i);
      if (m == null) break;
      for (final f in m.group(1)!.split('')) {
        switch (f) {
          case 'i':
            ignoreCase = true;
          case 's':
            dotAll = true;
          case 'm':
            multiLine = true;
          default:
            throw const UnsupportedRegexSyntax();
        }
      }
      i = m.end;
    }
    final out = StringBuffer();
    var inClass = false;
    var classStart = -1;
    while (i < pattern.length) {
      final ch = pattern[i];
      if (ch == r'\') {
        if (i + 1 >= pattern.length) {
          throw const FormatException('trailing backslash');
        }
        final n = pattern[i + 1];
        if (n == 'Q') {
          var end = pattern.indexOf(r'\E', i + 2);
          if (end < 0) end = pattern.length;
          for (final r in pattern.substring(i + 2, end).runes) {
            out.write(_literal(String.fromCharCode(r)));
          }
          i = end + 2;
          continue;
        }
        if (!inClass && n == 'A') {
          out.write(r'(?<![\s\S])');
        } else if (!inClass && n == 'z') {
          out.write(r'(?![\s\S])');
        } else if ((n == 'p' || n == 'P') &&
            i + 2 < pattern.length &&
            pattern[i + 2] != '{') {
          out.write('\\$n{${pattern[i + 2]}}');
          i += 3;
          continue;
        } else if (n == 'a') {
          out.write(r'\x07');
        } else if (n == 'C') {
          out.write(inClass ? r'\s\S' : r'[\s\S]');
        } else {
          final c = n.codeUnitAt(0);
          final alnum =
              (c >= 0x30 && c <= 0x39) ||
              (c >= 0x41 && c <= 0x5a) ||
              (c >= 0x61 && c <= 0x7a);
          if (alnum || c >= 0x80) {
            out.write('\\$n');
          } else if (_syntaxChars.contains(n) || (inClass && n == '-')) {
            out.write('\\$n');
          } else {
            out.write(_hex(c));
          }
        }
        i += 2;
        continue;
      }
      if (inClass) {
        if (ch == '[' && pattern.startsWith('[:', i)) {
          final end = pattern.indexOf(':]', i + 2);
          if (end > 0) {
            var name = pattern.substring(i + 2, end);
            final negated = name.startsWith('^');
            if (negated) name = name.substring(1);
            final m = _posix[name];
            if (m == null) throw const FormatException('unknown class');
            final rep = negated ? m.$2 : m.$1;
            if (rep == null) throw const UnsupportedRegexSyntax();
            out.write(rep);
            i = end + 2;
            continue;
          }
        }
        if (ch == ']' && i == classStart) {
          out.write(r'\]');
        } else if (ch == ']') {
          inClass = false;
          out.write(ch);
        } else if (ch == '[') {
          out.write(r'\[');
        } else {
          out.write(ch);
        }
        i++;
        continue;
      }
      switch (ch) {
        case '[':
          inClass = true;
          out.write(ch);
          i++;
          if (i < pattern.length && pattern[i] == '^') {
            out.write('^');
            i++;
          }
          classStart = i;
          continue;
        case '(':
          if (pattern.startsWith('(?P<', i)) {
            out.write('(?<');
            i += 4;
            continue;
          }
          if (pattern.startsWith('(?P=', i)) {
            final end = pattern.indexOf(')', i);
            if (end < 0) throw const FormatException('unterminated group');
            out.write('\\k<${pattern.substring(i + 4, end)}>');
            i = end + 1;
            continue;
          }
          if (pattern.startsWith('(?', i) && i + 2 < pattern.length) {
            final n = pattern[i + 2];
            final ok = n == ':' || n == '=' || n == '!' || n == '<';
            if (!ok) throw const UnsupportedRegexSyntax();
          }
          out.write(ch);
        case '{':
          final m = _quantifier.matchAsPrefix(pattern, i);
          if (m != null && i > 0) {
            out.write(m.group(0));
            i = m.end;
            continue;
          }
          out.write(r'\{');
        case '}':
          out.write(r'\}');
        case ']':
          out.write(r'\]');
        default:
          out.write(ch);
      }
      i++;
    }
    if (inClass) throw const FormatException('unterminated class');
    return (
      source: out.toString(),
      ignoreCase: ignoreCase,
      dotAll: dotAll,
      multiLine: multiLine,
    );
  }
}

/// RE2 syntax that has no Dart equivalent (inline flags inside the pattern, `(?U)`, …).
final class UnsupportedRegexSyntax implements Exception {
  const UnsupportedRegexSyntax();
}
