import '../addressing/a1.dart';
import '../addressing/column_letters.dart';
import '../addressing/r1c1.dart';
import '../addressing/sheet_names.dart';

/// Token-level conversion of whole formulas between A1 and R1C1 notation
/// relative to a host cell (Google Sheets `data-sheets-formula`, 03 §12.2).
///
/// String literals are copied verbatim; quoted sheet names are kept with the
/// reference they prefix; function names and defined names are never taken
/// for references.
abstract final class R1C1Relative {
  /// Converts an A1 formula (e.g. `=SUM(A1:A2)` in B3) to R1C1 relative to
  /// ([hostRow], [hostCol]) (`=SUM(R[-2]C[-1]:R[-1]C[-1])`).
  static String fromA1(String a1Formula, int hostRow, int hostCol) {
    final s = a1Formula;
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x22) {
        final e = _skipString(s, i);
        b.write(s.substring(i, e));
        i = e;
        continue;
      }
      final atBoundary = i == 0 || !_isRefPart(s.codeUnitAt(i - 1));
      if (atBoundary &&
          (c == 0x27 || c == 0x24 || _isIdentStart(c) || _isDigit(c))) {
        final m = A1Scanner.scan(s, i);
        if (m != null && _endOk(s, m.end)) {
          b.write(R1C1.format(m.area, hostRow, hostCol));
          i = m.end;
          continue;
        }
        if (c == 0x27) {
          final e = _skipQuoted(s, i);
          b.write(s.substring(i, e));
          i = e;
          continue;
        }
        if (_isIdentStart(c)) {
          var e = i + 1;
          while (e < s.length && _isIdentPart(s.codeUnitAt(e))) {
            e++;
          }
          b.write(s.substring(i, e));
          i = e;
          continue;
        }
        if (_isDigit(c)) {
          final e = _skipNumber(s, i);
          b.write(s.substring(i, e));
          i = e;
          continue;
        }
      }
      b.writeCharCode(c);
      i++;
    }
    return b.toString();
  }

  static final RegExp _cellRe = RegExp(
    r'[Rr](\[-?\d+\]|\d+)?[Cc](\[-?\d+\]|\d+)?',
  );
  static final RegExp _rowRe = RegExp(r'[Rr](\[-?\d+\]|\d+)?');
  static final RegExp _colRe = RegExp(r'[Cc](\[-?\d+\]|\d+)?');

  /// Converts an R1C1 formula relative to ([hostRow], [hostCol]) to A1.
  /// References that resolve outside the grid become `#REF!`.
  static String toA1(String r1c1Formula, int hostRow, int hostCol) {
    final s = r1c1Formula;
    final b = StringBuffer();
    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x22) {
        final e = _skipString(s, i);
        b.write(s.substring(i, e));
        i = e;
        continue;
      }
      final atBoundary = i == 0 || !_isRefPart(s.codeUnitAt(i - 1));
      if (atBoundary && (c == 0x27 || _isIdentStart(c))) {
        String? sheet;
        var j = i;
        final prefix = A1Scanner.scanSheetPrefix(s, i);
        if (prefix != null) {
          sheet = prefix.$1;
          j = prefix.$2;
        }
        final ref = _scanR1C1(s, j, hostRow, hostCol);
        if (ref != null) {
          final (text, end) = ref;
          if (text == '#REF!') {
            b.write(text);
          } else {
            if (sheet != null) {
              b
                ..write(SheetNames.quoteIfNeeded(sheet))
                ..write('!');
            }
            b.write(text);
          }
          i = end;
          continue;
        }
        if (prefix != null) {
          b.write(s.substring(i, prefix.$2));
          i = prefix.$2;
          continue;
        }
        if (c == 0x27) {
          final e = _skipQuoted(s, i);
          b.write(s.substring(i, e));
          i = e;
          continue;
        }
        var e = i + 1;
        while (e < s.length && _isIdentPart(s.codeUnitAt(e))) {
          e++;
        }
        b.write(s.substring(i, e));
        i = e;
        continue;
      }
      if (atBoundary && _isDigit(c)) {
        final e = _skipNumber(s, i);
        b.write(s.substring(i, e));
        i = e;
        continue;
      }
      b.writeCharCode(c);
      i++;
    }
    return b.toString();
  }

  /// Scans one R1C1 reference at [i]; returns its A1 text (or `#REF!`) and
  /// the end offset, or null when there is no reference.
  static (String, int)? _scanR1C1(String s, int i, int hostRow, int hostCol) {
    (int, bool) part(String? g, int host) {
      if (g == null) return (host, false);
      if (g.startsWith('[')) {
        return (host + int.parse(g.substring(1, g.length - 1)), false);
      }
      return (int.parse(g) - 1, true);
    }

    bool inRange(int r, int c) =>
        r >= 0 &&
        c >= 0 &&
        r < ColumnLetters.maxRows &&
        c < ColumnLetters.maxColumns;

    final m1 = _cellRe.matchAsPrefix(s, i);
    if (m1 != null) {
      final (r1, ar1) = part(m1.group(1), hostRow);
      final (c1, ac1) = part(m1.group(2), hostCol);
      var end = m1.end;
      if (end < s.length && s.codeUnitAt(end) == 0x3a) {
        final m2 = _cellRe.matchAsPrefix(s, end + 1);
        if (m2 != null && _endOk(s, m2.end)) {
          final (r2, ar2) = part(m2.group(1), hostRow);
          final (c2, ac2) = part(m2.group(2), hostCol);
          if (!inRange(r1, c1) || !inRange(r2, c2)) return ('#REF!', m2.end);
          final a = A1Area.rect(
            r1,
            c1,
            r2,
            c2,
            absRow1: ar1,
            absCol1: ac1,
            absRow2: ar2,
            absCol2: ac2,
          );
          return (a.formatArea(), m2.end);
        }
      }
      if (!_endOk(s, end)) return null;
      if (!inRange(r1, c1)) return ('#REF!', end);
      return (A1Area.cell(r1, c1, absRow: ar1, absCol: ac1).formatArea(), end);
    }
    final mr = _rowRe.matchAsPrefix(s, i);
    if (mr != null) {
      final (r1, a1) = part(mr.group(1), hostRow);
      var end = mr.end;
      var r2 = r1;
      var a2 = a1;
      if (end < s.length && s.codeUnitAt(end) == 0x3a) {
        final m2 = _rowRe.matchAsPrefix(s, end + 1);
        if (m2 != null && _endOk(s, m2.end)) {
          (r2, a2) = part(m2.group(1), hostRow);
          end = m2.end;
        }
      }
      if (_endOk(s, end)) {
        if (!inRange(r1, 0) || !inRange(r2, 0)) return ('#REF!', end);
        return (
          A1Area.rows(r1, r2, absRow1: a1, absRow2: a2).formatArea(),
          end,
        );
      }
    }
    final mc = _colRe.matchAsPrefix(s, i);
    if (mc != null) {
      final (c1, a1) = part(mc.group(1), hostCol);
      var end = mc.end;
      var c2 = c1;
      var a2 = a1;
      if (end < s.length && s.codeUnitAt(end) == 0x3a) {
        final m2 = _colRe.matchAsPrefix(s, end + 1);
        if (m2 != null && _endOk(s, m2.end)) {
          (c2, a2) = part(m2.group(1), hostCol);
          end = m2.end;
        }
      }
      if (_endOk(s, end)) {
        if (!inRange(0, c1) || !inRange(0, c2)) return ('#REF!', end);
        return (
          A1Area.columns(c1, c2, absCol1: a1, absCol2: a2).formatArea(),
          end,
        );
      }
    }
    return null;
  }

  static bool _endOk(String s, int end) {
    if (end >= s.length) return true;
    final c = s.codeUnitAt(end);
    return !(_isIdentPart(c) || c == 0x28 || c == 0x21 || c == 0x5b);
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
  static bool _isIdentStart(int c) =>
      ColumnLetters.isLetter(c) || c == 0x5f || c >= 0xc0;
  static bool _isIdentPart(int c) =>
      _isIdentStart(c) || _isDigit(c) || c == 0x2e;
  static bool _isRefPart(int c) =>
      _isIdentPart(c) || c == 0x24 || c == 0x27 || c == 0x5d;

  static int _skipString(String s, int i) {
    var j = i + 1;
    while (j < s.length) {
      if (s.codeUnitAt(j) == 0x22) {
        if (j + 1 < s.length && s.codeUnitAt(j + 1) == 0x22) {
          j += 2;
          continue;
        }
        return j + 1;
      }
      j++;
    }
    return s.length;
  }

  static int _skipQuoted(String s, int i) {
    var j = i + 1;
    while (j < s.length) {
      if (s.codeUnitAt(j) == 0x27) {
        if (j + 1 < s.length && s.codeUnitAt(j + 1) == 0x27) {
          j += 2;
          continue;
        }
        return j + 1;
      }
      j++;
    }
    return s.length;
  }

  static int _skipNumber(String s, int i) {
    var j = i;
    while (j < s.length &&
        (_isDigit(s.codeUnitAt(j)) || s.codeUnitAt(j) == 0x2e)) {
      j++;
    }
    if (j < s.length && (s.codeUnitAt(j) | 0x20) == 0x65) {
      var k = j + 1;
      if (k < s.length &&
          (s.codeUnitAt(k) == 0x2b || s.codeUnitAt(k) == 0x2d)) {
        k++;
      }
      if (k < s.length && _isDigit(s.codeUnitAt(k))) {
        j = k;
        while (j < s.length && _isDigit(s.codeUnitAt(j))) {
          j++;
        }
      }
    }
    return j;
  }
}
