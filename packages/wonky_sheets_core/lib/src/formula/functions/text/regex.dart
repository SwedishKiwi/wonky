import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'regex_shim.dart';

/// Regular expressions: REGEXMATCH, REGEXEXTRACT, REGEXREPLACE, REGEXTEST (05 §15.5). Patterns
/// use RE2 syntax, translated by [SheetsRegex].
void registerRegex(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.text;
  const notes =
      'Patterns use RE2 syntax (as in Google Sheets); lookaround and backreferences are also accepted.';

  b.fn(
    'REGEXMATCH',
    'Whether a piece of text matches a regular expression.',
    [
      P.text('text', 'The text to be tested against the regular expression.'),
      P.text(
        'regular_expression',
        'The regular expression to test the text against.',
      ),
    ],
    (a) {
      final re = SheetsRegex.compile(a.text(1), fn: a.fn);
      return FBool(re.hasMatch(a.text(0)));
    },
    priority: Priority.p0,
    examples: [
      'REGEXMATCH("Spreadsheets", "S.r")',
      r'REGEXMATCH(A2, "^\d{5}$")',
    ],
    seeAlso: ['REGEXEXTRACT', 'REGEXREPLACE', 'SEARCH'],
    notes: notes,
  );
  b.fn(
    'REGEXEXTRACT',
    'Extracts the first matching substring according to a regular expression. With capture groups, returns the groups.',
    [
      P.text('text', 'The input text.'),
      P.text(
        'regular_expression',
        'The first part of text that matches this expression will be returned. Capture groups return their contents instead.',
      ),
    ],
    (a) {
      final text = a.text(0);
      final pattern = a.text(1);
      final re = SheetsRegex.compile(pattern, fn: a.fn);
      final m = re.firstMatch(text);
      if (m == null) {
        fail(
          ErrorKind.na,
          'Function REGEXEXTRACT parameter 2 value "$pattern" does not match text of '
          'Function REGEXEXTRACT parameter 1 value "$text".',
        );
      }
      if (m.groupCount == 0) return FText(m.group(0)!);
      if (m.groupCount == 1) return FText(m.group(1) ?? '');
      return FArray.row([
        for (var g = 1; g <= m.groupCount; g++) FText(m.group(g) ?? ''),
      ]);
    },
    returns: ReturnKind.array,
    liftable: true,
    priority: Priority.p0,
    examples: [
      r'REGEXEXTRACT("Needle 42 in a haystack", "\d+")',
      r'REGEXEXTRACT(A2, "(\w+)@(\w+)")',
    ],
    seeAlso: ['REGEXMATCH', 'REGEXREPLACE', 'SPLIT'],
    notes: '$notes Several capture groups return a row of the groups.',
  );
  b.fn(
    'REGEXREPLACE',
    'Replaces part of a text string with a different text string using regular expressions.',
    [
      P.text('text', 'The text, a part of which will be replaced.'),
      P.text(
        'regular_expression',
        'The regular expression. All matching instances in text will be replaced.',
      ),
      P.text(
        'replacement',
        r'The text which will be inserted into the original text. $1…$9 insert capture groups, $0 the whole match, \$ a dollar sign.',
      ),
    ],
    (a) {
      final re = SheetsRegex.compile(a.text(1), fn: a.fn);
      final rep = a.text(2);
      return FText(a.text(0).replaceAllMapped(re, (m) => _expand(m, rep)));
    },
    priority: Priority.p0,
    examples: [
      'REGEXREPLACE("Spreadsheets", "S.*d", "Bed")',
      r'REGEXREPLACE(A2, "(\w+) (\w+)", "$2 $1")',
    ],
    seeAlso: ['REGEXMATCH', 'REGEXEXTRACT', 'SUBSTITUTE'],
    notes: notes,
  );
  b.fn(
    'REGEXTEST',
    'Returns whether any part of a text matches a regular expression (Excel compatible).',
    [
      P.text('text', 'The text to test.'),
      P.text('pattern', 'The regular expression.'),
      P.num(
        'case_sensitivity',
        '0 for a case-sensitive match, 1 for a case-insensitive match.',
        true,
        0,
      ),
    ],
    (a) {
      final mode = a.has(2) ? a.integer(2) : 0;
      if (mode != 0 && mode != 1) {
        fail(
          ErrorKind.value,
          'Function REGEXTEST parameter 3 value $mode is out of range.',
        );
      }
      final re = SheetsRegex.compile(
        a.text(1),
        fn: a.fn,
        caseSensitive: mode == 0,
      );
      return FBool(re.hasMatch(a.text(0)));
    },
    priority: Priority.p2,
    examples: [r'REGEXTEST("ABC123", "\d")', 'REGEXTEST(A2, "^abc", 1)'],
    seeAlso: ['REGEXMATCH'],
  );
}

/// Expands `$0`…`$9` and `\$` in a REGEXREPLACE replacement.
String _expand(Match m, String rep) {
  if (!rep.contains(r'$') && !rep.contains(r'\')) return rep;
  final out = StringBuffer();
  for (var i = 0; i < rep.length; i++) {
    final c = rep[i];
    if (c == r'\' && i + 1 < rep.length && rep[i + 1] == r'$') {
      out.write(r'$');
      i++;
      continue;
    }
    if (c == r'$' && i + 1 < rep.length) {
      final d = rep.codeUnitAt(i + 1) - 0x30;
      if (d >= 0 && d <= 9) {
        if (d <= m.groupCount) out.write(m.group(d) ?? '');
        i++;
        continue;
      }
    }
    out.write(c);
  }
  return out.toString();
}
