import '../../ast/ast.dart';
import '../../eval/eval_context.dart';
import '../../eval/operators.dart';
import '../../eval/range_access.dart';
import '../../values/coercion.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../registry.dart';
import 'text_common.dart';

/// Joining and splitting: CONCAT, CONCATENATE, JOIN, TEXTJOIN, SPLIT, TEXTSPLIT (05 §15.5).
void registerJoinSplit(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.text;

  b.fn(
    'CONCAT',
    'Returns the concatenation of two values. Equivalent to the `&` operator.',
    [
      P.scalar('value1', 'The value to which value2 will be appended.'),
      P.scalar('value2', 'The value to append to value1.'),
    ],
    (a) => Operators.binary(
      BinaryOp.concat,
      a.scalarOrError(0),
      a.scalarOrError(1),
      a.locale,
    ),
    priority: Priority.p0,
    examples: ['CONCAT("de", "mystify")', 'CONCAT(17, 76)'],
    seeAlso: ['CONCATENATE', 'JOIN', 'TEXTJOIN'],
    notes:
        "Takes exactly two values (Google Sheets). Excel's variadic CONCAT is imported as CONCATENATE.",
  );
  b.fn(
    'CONCATENATE',
    'Appends strings to one another.',
    [
      P.array('string1', 'The initial string.'),
      P.rep(
        'string2',
        ArgKind.array,
        'More strings to append in sequence. Ranges are joined row by row.',
      ),
    ],
    (a) {
      final out = StringBuffer();
      for (var i = 0; i < a.length; i++) {
        for (final v in a.flat(i)) {
          out.write(elementText(v, a.locale));
        }
        _checkLength(out.length, a.fn);
      }
      return FText(out.toString());
    },
    priority: Priority.p0,
    examples: [
      'CONCATENATE("Welcome", " ", "to", " ", "Sheets!")',
      'CONCATENATE(A1:C1)',
    ],
    seeAlso: ['CONCAT', 'JOIN', 'TEXTJOIN'],
  );
  b.fn(
    'JOIN',
    'Concatenates the elements of one or more one-dimensional arrays using a specified delimiter.',
    [
      P.text(
        'delimiter',
        'The character or string to place between each concatenated value. May be empty.',
      ),
      P.array(
        'value_or_array1',
        'The value or values to be appended using delimiter.',
      ),
      P.rep(
        'value_or_array2',
        ArgKind.array,
        'Additional values or arrays to be appended using delimiter.',
      ),
    ],
    (a) {
      final delimiter = a.text(0);
      final parts = <String>[];
      for (var i = 1; i < a.length; i++) {
        final (rows, cols) = a.shape(i);
        if (rows > 1 && cols > 1) {
          fail(
            ErrorKind.value,
            'Function JOIN parameter ${i + 1} requires a single row or column.',
          );
        }
        for (final v in _cells(a, i)) {
          parts.add(elementText(v, a.locale));
        }
      }
      return FText(_joinChecked(parts, delimiter, a.fn));
    },
    priority: Priority.p0,
    examples: ['JOIN(" and-a ", {1, 2, "1 2 3 4"})', 'JOIN(", ", A1:A5)'],
    seeAlso: ['TEXTJOIN', 'CONCATENATE', 'SPLIT'],
    notes: 'Blank cells are joined as empty strings.',
  );
  b.fn(
    'TEXTJOIN',
    'Combines the text from multiple strings and/or arrays, with a specifiable delimiter separating the different texts.',
    [
      P.array(
        'delimiter',
        'A string, possibly empty, or a reference to a valid string. An array of delimiters is used in turn.',
      ),
      P.bool_(
        'ignore_empty',
        'If TRUE, empty cells selected in the text arguments are not included in the result.',
      ),
      P.array(
        'text1',
        'Any text item: a string, a number, or an array or range.',
      ),
      P.rep('text2', ArgKind.array, 'Additional text items to be joined.'),
    ],
    (a) {
      final delims = [for (final v in a.flat(0)) elementText(v, a.locale)];
      final ignoreEmpty = a.boolean(1);
      final parts = <String>[];
      for (var i = 2; i < a.length; i++) {
        for (final v in _cells(a, i)) {
          final s = elementText(v, a.locale);
          if (ignoreEmpty && s.isEmpty) continue;
          parts.add(s);
        }
      }
      final out = StringBuffer();
      for (var k = 0; k < parts.length; k++) {
        if (k > 0 && delims.isNotEmpty) {
          out.write(delims[(k - 1) % delims.length]);
        }
        out.write(parts[k]);
        _checkLength(out.length, a.fn);
      }
      return FText(out.toString());
    },
    priority: Priority.p0,
    examples: [
      'TEXTJOIN(" ", TRUE, "hello", "world")',
      'TEXTJOIN(", ", TRUE, A1:A10)',
    ],
    seeAlso: ['JOIN', 'CONCATENATE', 'SPLIT'],
  );
  b.fn(
    'SPLIT',
    'Divides text around a specified character or string, and puts each fragment into a separate cell in the row.',
    [
      P.any('text', 'The text to divide.'),
      P.text('delimiter', 'The character or characters to use to split text.'),
      P.bool_(
        'split_by_each',
        'Whether or not to divide text around each character contained in delimiter.',
        true,
        true,
      ),
      P.bool_(
        'remove_empty_text',
        'Whether or not to remove empty text messages from the split results.',
        true,
        true,
      ),
    ],
    _split,
    returns: ReturnKind.array,
    priority: Priority.p0,
    examples: ['SPLIT("1,2,3", ",")', 'SPLIT("Alas, poor Yorick", " ,", TRUE)'],
    seeAlso: ['TEXTSPLIT', 'JOIN', 'REGEXEXTRACT'],
    notes:
        'Parts that look like numbers, dates or percentages become numbers. A range or array of texts in array mode is split row by row.',
  );
  b.fn(
    'TEXTSPLIT',
    'Splits text into rows and columns using column and row delimiters.',
    [
      P.text('text', 'The text to split.'),
      P.array(
        'col_delimiter',
        'The text that marks where to spill the text across columns. An array matches any of its values. May be left empty when row_delimiter is given.',
      ),
      P.array(
        'row_delimiter',
        'The text that marks where to spill the text down rows.',
        true,
      ),
      P.bool_(
        'ignore_empty',
        'TRUE ignores consecutive delimiters; FALSE creates empty cells.',
        true,
        false,
      ),
      P.num(
        'match_mode',
        '0 for a case-sensitive match, 1 for case-insensitive.',
        true,
        0,
      ),
      P.scalar(
        'pad_with',
        'The value with which to pad missing cells.',
        true,
        '#N/A',
      ),
    ],
    _textSplit,
    returns: ReturnKind.array,
    priority: Priority.p2,
    examples: ['TEXTSPLIT("a,b;c,d", ",", ";")', 'TEXTSPLIT(A2, " ")'],
    seeAlso: ['SPLIT', 'TEXTBEFORE', 'TEXTAFTER'],
  );
}

void _checkLength(int n, String fn) {
  if (n > Operators.maxText) {
    fail(ErrorKind.value, ErrorMessages.textTooLong(fn));
  }
}

String _joinChecked(List<String> parts, String delimiter, String fn) {
  final out = StringBuffer();
  for (var k = 0; k < parts.length; k++) {
    if (k > 0) out.write(delimiter);
    out.write(parts[k]);
    _checkLength(out.length, fn);
  }
  return out.toString();
}

/// Values of argument [i] (blank cells included, row-major).
List<FValue> _cells(FunctionArgs a, int i) => a.flat(i);

FValue _split(FunctionArgs a) {
  final delimiter = a.text(1);
  final byEach = a.boolOr(2, true);
  final removeEmpty = a.boolOr(3, true);
  if (delimiter.isEmpty) {
    fail(
      ErrorKind.value,
      'Function SPLIT parameter 2 value should be non-empty.',
    );
  }
  final delims = byEach
      ? [for (final r in delimiter.runes) String.fromCharCode(r)]
      : [delimiter];
  var v = a[0];
  if (v is FRef) {
    v = a.ctx.arrayMode && !v.area.isSingleCell
        ? RangeAccess.materialize(a.ctx, v)
        : RangeAccess.intersect(a.ctx, v);
  }
  if (v is FRich) v = v.scalar;
  if (v is FArray && v.length > 1) {
    final rows = <List<FValue>>[];
    for (var r = 0; r < v.rows; r++) {
      final row = <FValue>[];
      for (var c = 0; c < v.cols; c++) {
        var x = v.at(r, c);
        if (x is FRich) x = x.scalar;
        if (x is FError) {
          row.add(x);
        } else if (x is FEmpty) {
          continue;
        } else {
          row.addAll(_splitOne(a, _text(a, x), delims, removeEmpty));
        }
      }
      rows.add(row);
    }
    var width = 1;
    for (final r in rows) {
      if (r.length > width) width = r.length;
    }
    return FArray.generate(
      rows.length,
      width,
      (r, c) => c < rows[r].length ? rows[r][c] : FEmpty.instance,
    );
  }
  if (v is FArray) v = v.topLeft;
  if (v is FError) return v;
  final text = _text(a, v);
  if (text.isEmpty) {
    fail(
      ErrorKind.value,
      'Function SPLIT parameter 1 value should be non-empty.',
    );
  }
  final parts = _splitOne(a, text, delims, removeEmpty);
  if (parts.isEmpty) return FText.empty;
  return FArray.row(parts);
}

String _text(FunctionArgs a, FValue v) {
  final r = Coerce.toText(v, a.locale);
  if (r is FError) throw FormulaError(r);
  return r as String;
}

List<FValue> _splitOne(
  FunctionArgs a,
  String text,
  List<String> delims,
  bool removeEmpty,
) {
  final out = <FValue>[];
  var start = 0;
  while (true) {
    final m = findAny(text, delims, start);
    final end = m?.$1 ?? text.length;
    final part = text.substring(start, end);
    if (!(removeEmpty && part.isEmpty)) out.add(_typed(a, part));
    if (m == null) break;
    start = m.$2;
  }
  return out;
}

/// A split part as typed input: numbers (with dates, times, percentages) or text.
FValue _typed(FunctionArgs a, String part) {
  final p = TextNumberParser.parse(
    part,
    a.locale,
    currentYear: a.ctx.currentYear,
  );
  return p == null ? FText(part) : FNumber(p.$1, p.$2);
}

FValue _textSplit(FunctionArgs a) {
  final text = a.text(0);
  List<String> delims(int i) => a.has(i)
      ? [
          for (final d in delimiterList(a, i))
            if (d.isNotEmpty) d,
        ]
      : const [];
  final colDelims = delims(1);
  final rowDelims = delims(2);
  final ignoreEmpty = a.boolOr(3, false);
  final mode = a.has(4) ? a.integer(4) : 0;
  final pad = a.has(5) ? a.scalarOrError(5) : FError.na;
  if (mode != 0 && mode != 1) {
    fail(
      ErrorKind.value,
      'Function TEXTSPLIT parameter 5 value $mode is out of range.',
    );
  }
  if (colDelims.isEmpty && rowDelims.isEmpty) {
    fail(
      ErrorKind.value,
      'Function TEXTSPLIT needs a column or row delimiter.',
    );
  }
  final folded = mode == 1;
  List<String> splitBy(String s, List<String> ds) {
    if (ds.isEmpty) return [s];
    final hay = folded ? s.toLowerCase() : s;
    final keys = folded ? [for (final d in ds) d.toLowerCase()] : ds;
    final parts = <String>[];
    var start = 0;
    while (true) {
      final m = findAny(hay, keys, start);
      final end = m?.$1 ?? s.length;
      final part = s.substring(start, end);
      if (!(ignoreEmpty && part.isEmpty)) parts.add(part);
      if (m == null) break;
      start = m.$2;
    }
    return parts;
  }

  final rows = [for (final r in splitBy(text, rowDelims)) splitBy(r, colDelims)]
    ..removeWhere((r) => r.isEmpty);
  if (rows.isEmpty) return FText.empty;
  var width = 1;
  for (final r in rows) {
    if (r.length > width) width = r.length;
  }
  return FArray.generate(
    rows.length,
    width,
    (r, c) => c < rows[r].length ? FText(rows[r][c]) : pad,
  );
}
