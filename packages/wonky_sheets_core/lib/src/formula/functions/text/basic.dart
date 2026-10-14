import '../../eval/eval_context.dart';
import '../../eval/operators.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'text_common.dart';

/// Character codes, case, cleanup and comparison: CHAR, CODE, UNICHAR, UNICODE, CLEAN, TRIM,
/// LEN, LENB, LOWER, UPPER, PROPER, T, EXACT, REPT, ASC (05 §15.5).
void registerTextBasic(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.text;

  b.fn(
    'CHAR',
    'Converts a number into a character according to the current Unicode table.',
    [
      P.num(
        'table_number',
        'The number of the character to look up from the current Unicode table in decimal format.',
      ),
    ],
    (a) => FText(_fromCodePoint(a, a.integer(0))),
    priority: Priority.p0,
    examples: ['CHAR(97)', 'CHAR(8364)'],
    seeAlso: ['CODE', 'UNICHAR'],
    notes: 'Uses Unicode code points (Excel uses the ANSI code page).',
  );
  b.fn(
    'UNICHAR',
    'Returns the Unicode character for a number.',
    [P.num('number', 'The Unicode code point of the character, in decimal.')],
    (a) => FText(_fromCodePoint(a, a.integer(0))),
    examples: ['UNICHAR(66)', 'UNICHAR(128512)'],
    seeAlso: ['UNICODE', 'CHAR'],
  );
  b.fn(
    'CODE',
    'Returns the numeric Unicode map value of the first character in the string provided.',
    [
      P.text(
        'string',
        'The string from which to return the Unicode map value of the first character.',
      ),
    ],
    (a) => FNumber(_firstCodePoint(a).toDouble()),
    priority: Priority.p0,
    examples: ['CODE("a")', 'CODE(A2)'],
    seeAlso: ['CHAR', 'UNICODE'],
  );
  b.fn(
    'UNICODE',
    'Returns the decimal Unicode value of the first character of the text.',
    [P.text('text', 'The string whose first character to convert.')],
    (a) => FNumber(_firstCodePoint(a).toDouble()),
    examples: ['UNICODE("A")', 'UNICODE("😀")'],
    seeAlso: ['UNICHAR', 'CODE'],
  );
  b.fn(
    'CLEAN',
    'Returns the text with the non-printable ASCII characters removed.',
    [
      P.text(
        'text',
        'The text whose non-printable characters (codes 0–31) are to be removed.',
      ),
    ],
    (a) {
      final s = a.text(0);
      final out = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        final c = s.codeUnitAt(i);
        if (c >= 0x20) out.writeCharCode(c);
      }
      return FText(out.toString());
    },
    examples: ['CLEAN(A2)', 'CLEAN("A" & CHAR(10) & "B")'],
    seeAlso: ['TRIM'],
  );
  b.fn(
    'TRIM',
    'Removes leading and trailing spaces in a specified string and collapses runs of spaces inside it to one.',
    [
      P.text(
        'text',
        'The string or reference to a cell containing a string to be trimmed.',
      ),
    ],
    (a) => FText(_trimSpaces(a.text(0))),
    priority: Priority.p0,
    examples: ['TRIM("  lorem   ipsum  ")', 'TRIM(A2)'],
    seeAlso: ['CLEAN', 'SUBSTITUTE'],
    notes:
        'Only the space character U+0020 is removed (Sheets and Excel parity).',
  );
  b.fn(
    'LEN',
    'Returns the length of a string.',
    [P.text('text', 'The string whose length will be returned.')],
    (a) => FNumber(a.text(0).length.toDouble()),
    priority: Priority.p0,
    examples: ['LEN(A2)', 'LEN("lorem ipsum")'],
    seeAlso: ['LENB'],
    notes:
        'Counts UTF-16 code units, so characters outside the Basic Multilingual Plane (such as emoji) count as 2.',
  );
  b.fn(
    'LENB',
    'Returns the length of a string in bytes.',
    [P.text('string', 'The string whose length in bytes will be returned.')],
    (a) => FNumber(byteLength(a.text(0)).toDouble()),
    priority: Priority.p2,
    examples: ['LENB("日本")', 'LENB(A2)'],
    seeAlso: ['LEN'],
    notes:
        'Latin-1 and half-width katakana characters count as 1 byte, all other characters as 2 bytes.',
  );
  b.fn(
    'LOWER',
    'Converts a specified string to lowercase.',
    [P.text('text', 'The string to convert to lowercase.')],
    (a) => FText(a.text(0).toLowerCase()),
    priority: Priority.p0,
    examples: ['LOWER("LOREM IPSUM")', 'LOWER(A2)'],
    seeAlso: ['UPPER', 'PROPER'],
  );
  b.fn(
    'UPPER',
    'Converts a specified string to uppercase.',
    [P.text('text', 'The string to convert to uppercase.')],
    (a) => FText(a.text(0).toUpperCase()),
    priority: Priority.p0,
    examples: ['UPPER("lorem ipsum")', 'UPPER(A2)'],
    seeAlso: ['LOWER', 'PROPER'],
  );
  b.fn(
    'PROPER',
    'Capitalizes each word in a specified string.',
    [
      P.text(
        'text_to_capitalize',
        'The text which will be returned with the first letter of each word in uppercase and all other letters in lowercase.',
      ),
    ],
    (a) => FText(_proper(a.text(0))),
    priority: Priority.p0,
    examples: ['PROPER("lorem ipsum")', 'PROPER("2-way street")'],
    seeAlso: ['UPPER', 'LOWER'],
    notes: 'A word is a run of letters: any other character starts a new word.',
  );
  b.fn(
    'T',
    'Returns string arguments as text, or the empty string for any other value.',
    [P.scalar('value', 'The argument to be converted to text.')],
    (a) {
      final v = a.scalar(0);
      return v is FText ? v : FText.empty;
    },
    examples: ['T("text")', 'T(A2)'],
    seeAlso: ['N', 'TO_TEXT'],
  );
  b.fn(
    'EXACT',
    'Tests whether two strings are identical (case-sensitive).',
    [
      P.text('string1', 'The first string to compare.'),
      P.text('string2', 'The second string to compare.'),
    ],
    (a) => FBool(a.text(0) == a.text(1)),
    priority: Priority.p0,
    examples: ['EXACT("Hello", "hello")', 'EXACT(A1, B1)'],
    seeAlso: ['EQ'],
  );
  b.fn(
    'REPT',
    'Returns specified text repeated a number of times.',
    [
      P.text('text_to_repeat', 'The character or string to repeat.'),
      P.num(
        'number_of_repetitions',
        'The number of times text_to_repeat should appear in the value returned.',
      ),
    ],
    (a) {
      final s = a.text(0);
      final n = nonNegativeArg(a, 1);
      if (s.length * n > Operators.maxText) {
        fail(ErrorKind.value, ErrorMessages.textTooLong('REPT'));
      }
      return FText(s * n);
    },
    priority: Priority.p0,
    examples: ['REPT("ha", 3)', 'REPT("-", 10)'],
    seeAlso: ['CONCATENATE'],
  );
  b.fn(
    'ASC',
    'Converts full-width ASCII and katakana characters to their half-width counterparts.',
    [
      P.text(
        'text',
        'The text or a reference to a cell containing the text to convert.',
      ),
    ],
    (a) => FText(_toHalfWidth(a.text(0))),
    priority: Priority.p2,
    examples: ['ASC("ＡＢＣ１２３")', 'ASC("カタカナ")'],
    seeAlso: ['UPPER', 'LOWER'],
  );
}

String _fromCodePoint(FunctionArgs a, int n) {
  if (n < 1 || n > 0x10ffff || (n >= 0xd800 && n <= 0xdfff)) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter 1 value $n is out of range.',
    );
  }
  return String.fromCharCode(n);
}

int _firstCodePoint(FunctionArgs a) {
  final s = a.text(0);
  if (s.isEmpty) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter 1 value should be non-empty.',
    );
  }
  return s.runes.first;
}

/// Removes leading/trailing U+0020 and collapses inner runs.
String _trimSpaces(String s) {
  final out = StringBuffer();
  var pendingSpace = false;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x20) {
      if (out.isNotEmpty) pendingSpace = true;
      continue;
    }
    if (pendingSpace) {
      out.writeCharCode(0x20);
      pendingSpace = false;
    }
    out.writeCharCode(c);
  }
  return out.toString();
}

String _proper(String s) {
  final out = StringBuffer();
  var inWord = false;
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final upper = ch.toUpperCase();
    final lower = ch.toLowerCase();
    final isLetter = upper != lower;
    if (isLetter) {
      out.write(inWord ? lower : upper);
      inWord = true;
    } else {
      out.write(ch);
      inWord = false;
    }
  }
  return out.toString();
}

/// Full-width katakana, in half-width katakana order (U+FF61…U+FF9F).
const String _fullKatakana =
    '。「」、・ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン゛゜';
const String _voiced = 'ガギグゲゴザジズゼゾダヂヅデドバビブベボヴ';
const String _voicedBase = 'カキクケコサシスセソタチツテトハヒフヘホウ';
const String _semiVoiced = 'パピプペポ';
const String _semiVoicedBase = 'ハヒフヘホ';

String _toHalfWidth(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0xff01 && c <= 0xff5e) {
      out.writeCharCode(c - 0xfee0);
      continue;
    }
    if (c == 0x3000) {
      out.writeCharCode(0x20);
      continue;
    }
    final ch = s[i];
    var k = _fullKatakana.indexOf(ch);
    if (k >= 0) {
      out.writeCharCode(0xff61 + k);
      continue;
    }
    k = _voiced.indexOf(ch);
    if (k >= 0) {
      out
        ..writeCharCode(0xff61 + _fullKatakana.indexOf(_voicedBase[k]))
        ..writeCharCode(0xff9e);
      continue;
    }
    k = _semiVoiced.indexOf(ch);
    if (k >= 0) {
      out
        ..writeCharCode(0xff61 + _fullKatakana.indexOf(_semiVoicedBase[k]))
        ..writeCharCode(0xff9f);
      continue;
    }
    out.writeCharCode(c);
  }
  return out.toString();
}
