import '../../eval/eval_context.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'text_common.dart';

/// Substrings, positions and replacement: LEFT, RIGHT, MID, FIND, SEARCH, REPLACE (and their
/// byte-based `…B` forms), SUBSTITUTE, TEXTBEFORE, TEXTAFTER (05 §15.5).
void registerSubstrings(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.text;

  b.fn(
    'LEFT',
    'Returns a substring from the beginning of a specified string.',
    [
      P.text(
        'string',
        'The string from which the left portion will be returned.',
      ),
      P.num(
        'number_of_characters',
        'The number of characters to return from the left side of string.',
        true,
        1,
      ),
    ],
    (a) {
      final s = a.text(0);
      final n = nonNegativeArg(a, 1, 1);
      return FText(n >= s.length ? s : s.substring(0, n));
    },
    priority: Priority.p0,
    examples: ['LEFT("lorem ipsum", 5)', 'LEFT(A2)'],
    seeAlso: ['RIGHT', 'MID', 'LEFTB'],
  );
  b.fn(
    'RIGHT',
    'Returns a substring from the end of a specified string.',
    [
      P.text(
        'string',
        'The string from which the right portion will be returned.',
      ),
      P.num(
        'number_of_characters',
        'The number of characters to return from the right side of string.',
        true,
        1,
      ),
    ],
    (a) {
      final s = a.text(0);
      final n = nonNegativeArg(a, 1, 1);
      return FText(n >= s.length ? s : s.substring(s.length - n));
    },
    priority: Priority.p0,
    examples: ['RIGHT("lorem ipsum", 5)', 'RIGHT(A2)'],
    seeAlso: ['LEFT', 'MID', 'RIGHTB'],
  );
  b.fn(
    'MID',
    'Returns a segment of a string.',
    [
      P.text('string', 'The string to extract a segment from.'),
      P.num(
        'starting_at',
        'The index from the left of string from which to begin extracting. The first character in string has the index 1.',
      ),
      P.num('extract_length', 'The length of the segment to extract.'),
    ],
    (a) {
      final s = a.text(0);
      final start = positiveArg(a, 1);
      final n = nonNegativeArg(a, 2);
      if (start > s.length) return FText.empty;
      final end = start - 1 + n;
      return FText(s.substring(start - 1, end > s.length ? s.length : end));
    },
    priority: Priority.p0,
    examples: ['MID("get this", 5, 4)', 'MID(A2, 3, 2)'],
    seeAlso: ['LEFT', 'RIGHT', 'MIDB'],
  );
  b.fn(
    'LEFTB',
    'Returns the left portion of a string up to a certain number of bytes.',
    [
      P.text(
        'string',
        'The string from which the left portion will be returned.',
      ),
      P.num(
        'num_of_bytes',
        'The number of bytes to return from the left side of string.',
        true,
        1,
      ),
    ],
    (a) {
      final s = a.text(0);
      final n = nonNegativeArg(a, 1, 1);
      return FText(s.substring(0, unitsInBytes(s, 0, n)));
    },
    priority: Priority.p2,
    examples: ['LEFTB("日本語", 4)'],
    seeAlso: ['LEFT', 'RIGHTB', 'MIDB'],
    notes: 'A double-byte character that would be split is left out.',
  );
  b.fn(
    'RIGHTB',
    'Returns the right portion of a string up to a certain number of bytes.',
    [
      P.text(
        'string',
        'The string from which the right portion will be returned.',
      ),
      P.num(
        'num_of_bytes',
        'The number of bytes to return from the right side of string.',
        true,
        1,
      ),
    ],
    (a) {
      final s = a.text(0);
      final n = nonNegativeArg(a, 1, 1);
      var used = 0, i = s.length;
      while (i > 0) {
        final w = byteWidth(s.codeUnitAt(i - 1));
        if (used + w > n) break;
        used += w;
        i--;
      }
      return FText(s.substring(i));
    },
    priority: Priority.p2,
    examples: ['RIGHTB("日本語", 4)'],
    seeAlso: ['RIGHT', 'LEFTB', 'MIDB'],
    notes: 'A double-byte character that would be split is left out.',
  );
  b.fn(
    'MIDB',
    'Returns a section of a string starting at a given byte and up to a specified number of bytes.',
    [
      P.text('string', 'The string to extract a segment from.'),
      P.num(
        'starting_at',
        'The byte position from which to begin extracting (1-based).',
      ),
      P.num('extract_length_bytes', 'The number of bytes to extract.'),
    ],
    (a) {
      final s = a.text(0);
      final start = positiveArg(a, 1);
      final n = nonNegativeArg(a, 2);
      final from = unitAtByte(s, start);
      return FText(s.substring(from, from + unitsInBytes(s, from, n)));
    },
    priority: Priority.p2,
    examples: ['MIDB("日本語", 3, 4)'],
    seeAlso: ['MID', 'LEFTB', 'RIGHTB'],
  );

  b.fn(
    'FIND',
    'Returns the position at which a string is first found within text, case-sensitive.',
    _findParams,
    (a) => _find(a, caseSensitive: true),
    priority: Priority.p0,
    examples: ['FIND("n", "banana")', 'FIND("an", A2, 3)'],
    seeAlso: ['SEARCH', 'FINDB', 'REGEXMATCH'],
  );
  b.fn(
    'SEARCH',
    'Returns the position at which a string is first found within text, ignoring case.',
    _findParams,
    (a) => _find(a, caseSensitive: false),
    priority: Priority.p0,
    examples: ['SEARCH("N", "banana")', 'SEARCH("an", A2, 3)'],
    seeAlso: ['FIND', 'SEARCHB', 'REGEXMATCH'],
    notes:
        'As in Google Sheets, * and ? are matched literally (no wildcards); use REGEXMATCH for patterns.',
  );
  b.fn(
    'FINDB',
    'Returns the byte position at which a string is first found within text, case-sensitive.',
    _findParams,
    (a) => _find(a, caseSensitive: true, bytes: true),
    priority: Priority.p2,
    examples: ['FINDB("本", "日本")'],
    seeAlso: ['FIND', 'SEARCHB'],
  );
  b.fn(
    'SEARCHB',
    'Returns the byte position at which a string is first found within text, ignoring case.',
    _findParams,
    (a) => _find(a, caseSensitive: false, bytes: true),
    priority: Priority.p2,
    examples: ['SEARCHB("b", "日本ABC")'],
    seeAlso: ['SEARCH', 'FINDB'],
  );

  b.fn(
    'REPLACE',
    'Replaces part of a text string with a different text string.',
    [
      P.text('text', 'The text, a part of which will be replaced.'),
      P.num(
        'position',
        'The position where the replacement will begin (starting from 1).',
      ),
      P.num('length', 'The number of characters in the text to be replaced.'),
      P.text(
        'new_text',
        'The text which will be inserted into the original text.',
      ),
    ],
    (a) {
      final s = a.text(0);
      final pos = positiveArg(a, 1);
      final n = nonNegativeArg(a, 2);
      final from = pos - 1 > s.length ? s.length : pos - 1;
      final to = from + n > s.length ? s.length : from + n;
      return FText(s.replaceRange(from, to, a.text(3)));
    },
    priority: Priority.p0,
    examples: ['REPLACE("abcdefg", 2, 3, "X")', 'REPLACE(A2, 1, 4, "2027")'],
    seeAlso: ['SUBSTITUTE', 'REGEXREPLACE', 'REPLACEB'],
  );
  b.fn(
    'REPLACEB',
    'Replaces part of a text string, based on a number of bytes, with a different text string.',
    [
      P.text('text', 'The text, a part of which will be replaced.'),
      P.num(
        'position',
        'The byte position where the replacement will begin (starting from 1).',
      ),
      P.num('num_bytes', 'The number of bytes in the text to be replaced.'),
      P.text(
        'new_text',
        'The text which will be inserted into the original text.',
      ),
    ],
    (a) {
      final s = a.text(0);
      final pos = positiveArg(a, 1);
      final n = nonNegativeArg(a, 2);
      final from = unitAtByte(s, pos);
      final to = from + unitsInBytes(s, from, n);
      return FText(s.replaceRange(from, to, a.text(3)));
    },
    priority: Priority.p2,
    examples: ['REPLACEB("日本語", 3, 2, "X")'],
    seeAlso: ['REPLACE'],
  );
  b.fn(
    'SUBSTITUTE',
    'Replaces existing text with new text in a string (case-sensitive).',
    [
      P.text('text_to_search', 'The text within which to search and replace.'),
      P.text('search_for', 'The string to search for within text_to_search.'),
      P.text('replace_with', 'The string that will replace search_for.'),
      P.num(
        'occurrence_number',
        'The instance of search_for within text_to_search to replace. By default, all occurrences are replaced.',
        true,
      ),
    ],
    (a) {
      final s = a.text(0);
      final find = a.text(1);
      final rep = a.text(2);
      final has = a.has(3);
      final occ = has ? positiveArg(a, 3) : 0;
      if (find.isEmpty) return FText(s);
      if (!has) return FText(s.replaceAll(find, rep));
      var p = -find.length;
      for (var k = 0; k < occ; k++) {
        p = s.indexOf(find, p + find.length);
        if (p < 0) return FText(s);
      }
      return FText(s.replaceRange(p, p + find.length, rep));
    },
    priority: Priority.p0,
    examples: [
      'SUBSTITUTE("search for it", "search for", "Google")',
      'SUBSTITUTE(A2, "a", "b", 2)',
    ],
    seeAlso: ['REPLACE', 'REGEXREPLACE'],
  );

  final beforeAfterParams = [
    P.text('text', 'The text to search within.'),
    P.array(
      'delimiter',
      'The text that marks the point to extract before or after. An array of delimiters matches any of them.',
    ),
    P.num(
      'instance_num',
      'Which occurrence of the delimiter to use. Negative numbers search from the end of the text.',
      true,
      1,
    ),
    P.num(
      'match_mode',
      '0 for a case-sensitive search, 1 for a case-insensitive search.',
      true,
      0,
    ),
    P.num(
      'match_end',
      '1 treats the end of the text as a delimiter; 0 does not.',
      true,
      0,
    ),
    P.scalar(
      'if_not_found',
      'The value returned when no match is found.',
      true,
      '#N/A',
    ),
  ];
  b.fn(
    'TEXTBEFORE',
    'Returns the text that occurs before a given delimiter.',
    beforeAfterParams,
    (a) => _beforeAfter(a, before: true),
    liftable: true,
    examples: ['TEXTBEFORE("Red riding hood", " ")', 'TEXTBEFORE(A2, "-", -1)'],
    seeAlso: ['TEXTAFTER', 'TEXTSPLIT', 'SPLIT'],
  );
  b.fn(
    'TEXTAFTER',
    'Returns the text that occurs after a given delimiter.',
    beforeAfterParams,
    (a) => _beforeAfter(a, before: false),
    liftable: true,
    examples: ['TEXTAFTER("Red riding hood", " ")', 'TEXTAFTER(A2, "-", -1)'],
    seeAlso: ['TEXTBEFORE', 'TEXTSPLIT', 'SPLIT'],
  );
}

final List<ArgSpec> _findParams = [
  P.text('search_for', 'The string to look for within text_to_search.'),
  P.text(
    'text_to_search',
    'The text to search for the first occurrence of search_for.',
  ),
  P.num(
    'starting_at',
    'The character within text_to_search at which to start the search.',
    true,
    1,
  ),
];

FValue _find(
  FunctionArgs a, {
  required bool caseSensitive,
  bool bytes = false,
}) {
  var needle = a.text(0);
  var hay = a.text(1);
  final start = positiveArg(a, 2);
  final limit = bytes ? byteLength(hay) + 1 : hay.length + 1;
  if (start > limit) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter 3 value is $start. It should be less than or equal to $limit.',
    );
  }
  final from = bytes ? unitAtByte(hay, start) : start - 1;
  if (!caseSensitive) {
    needle = needle.toLowerCase();
    hay = hay.toLowerCase();
  }
  final p = hay.indexOf(needle, from);
  if (p < 0) {
    fail(ErrorKind.value, ErrorMessages.didNotFind(a.text(0), a.fn));
  }
  final pos = bytes ? byteLength(hay.substring(0, p)) + 1 : p + 1;
  return FNumber(pos.toDouble());
}

FValue _beforeAfter(FunctionArgs a, {required bool before}) {
  final text = a.text(0);
  final delims = delimiterList(a, 1);
  final instance = a.has(2) ? a.integer(2) : 1;
  final mode = a.has(3) ? a.integer(3) : 0;
  final matchEnd = a.has(4) && a.number(4) != 0;
  if (instance == 0 || (text.isNotEmpty && instance.abs() > text.length)) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter 3 value $instance is out of range.',
    );
  }
  if (mode != 0 && mode != 1) {
    fail(
      ErrorKind.value,
      'Function ${a.fn} parameter 4 value $mode is out of range.',
    );
  }
  if (delims.isEmpty) fail(ErrorKind.value);
  final hay = mode == 1 ? text.toLowerCase() : text;
  final ds = mode == 1 ? [for (final d in delims) d.toLowerCase()] : delims;
  final found = <(int, int)>[];
  var p = 0;
  while (p <= hay.length) {
    final m = findAny(hay, ds, p);
    if (m == null) break;
    found.add(m);
    p = m.$2 > m.$1 ? m.$2 : m.$2 + 1;
  }
  (int, int)? hit;
  if (instance > 0) {
    if (matchEnd) found.add((text.length, text.length));
    if (instance <= found.length) hit = found[instance - 1];
  } else {
    if (matchEnd) found.insert(0, (0, 0));
    final k = found.length + instance;
    if (k >= 0) hit = found[k];
  }
  if (hit == null) {
    if (a.has(5)) return a.scalarOrError(5);
    return FError(ErrorKind.na, ErrorMessages.didNotFind(delims.first, a.fn));
  }
  return FText(before ? text.substring(0, hit.$1) : text.substring(hit.$2));
}
