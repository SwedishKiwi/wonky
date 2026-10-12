import 'column_letters.dart';
import 'grid_geometry.dart';
import 'sheet_names.dart';

/// The shape of a parsed A1 reference.
enum A1Kind {
  /// `A1`
  cell,

  /// `A1:B5`
  rect,

  /// `A:C`
  columns,

  /// `1:3`
  rows,

  /// `A2:B` — columns A–B from row 2 to the last row.
  openRows,

  /// `B3:5` — rows 3–5 from column B to the last column.
  openColumns,
}

/// A positional (index-based) A1 reference such as `'Q3 plan'!$A$1:B5`.
///
/// Indices are zero-based. Missing bounds are `null` (open). The `abs*` flags record `$`.
final class A1Area {
  final String? sheet;
  final A1Kind kind;
  final int? row1;
  final int? col1;
  final int? row2;
  final int? col2;
  final bool absRow1;
  final bool absCol1;
  final bool absRow2;
  final bool absCol2;

  const A1Area._(
    this.kind, {
    this.sheet,
    this.row1,
    this.col1,
    this.row2,
    this.col2,
    this.absRow1 = false,
    this.absCol1 = false,
    this.absRow2 = false,
    this.absCol2 = false,
  });

  /// A single cell.
  const A1Area.cell(
    int row,
    int col, {
    this.sheet,
    bool absRow = false,
    bool absCol = false,
  }) : kind = A1Kind.cell,
       row1 = row,
       col1 = col,
       row2 = row,
       col2 = col,
       absRow1 = absRow,
       absCol1 = absCol,
       absRow2 = absRow,
       absCol2 = absCol;

  /// A rectangle `A1:B5` (bounds as given).
  factory A1Area.rect(
    int r1,
    int c1,
    int r2,
    int c2, {
    String? sheet,
    bool absRow1 = false,
    bool absCol1 = false,
    bool absRow2 = false,
    bool absCol2 = false,
  }) {
    return A1Area._(
      A1Kind.rect,
      sheet: sheet,
      row1: r1,
      col1: c1,
      row2: r2,
      col2: c2,
      absRow1: absRow1,
      absCol1: absCol1,
      absRow2: absRow2,
      absCol2: absCol2,
    );
  }

  /// Whole columns `A:C`.
  const A1Area.columns(int c1, int c2, {this.sheet, this.absCol1 = false, this.absCol2 = false})
    : kind = A1Kind.columns,
      row1 = null,
      row2 = null,
      col1 = c1,
      col2 = c2,
      absRow1 = false,
      absRow2 = false;

  /// Whole rows `1:3`.
  const A1Area.rows(int r1, int r2, {this.sheet, this.absRow1 = false, this.absRow2 = false})
    : kind = A1Kind.rows,
      col1 = null,
      col2 = null,
      row1 = r1,
      row2 = r2,
      absCol1 = false,
      absCol2 = false;

  /// Generic constructor used by parsers.
  const A1Area.raw(
    this.kind, {
    this.sheet,
    this.row1,
    this.col1,
    this.row2,
    this.col2,
    this.absRow1 = false,
    this.absCol1 = false,
    this.absRow2 = false,
    this.absCol2 = false,
  });

  bool get isCell => kind == A1Kind.cell;

  A1Area withSheet(String? sheet) => A1Area.raw(
    kind,
    sheet: sheet,
    row1: row1,
    col1: col1,
    row2: row2,
    col2: col2,
    absRow1: absRow1,
    absCol1: absCol1,
    absRow2: absRow2,
    absCol2: absCol2,
  );

  /// Resolves open bounds against a sheet of [rowCount] × [colCount] and normalizes.
  GridRect toRect(int rowCount, int colCount) {
    final r1 = row1 ?? 0;
    final c1 = col1 ?? 0;
    final r2 = row2 ?? (rowCount - 1);
    final c2 = col2 ?? (colCount - 1);
    return GridRect.normalized(r1, c1, r2, c2);
  }

  /// Renders the reference (`'My sheet'!$A$1:B2`). [includeSheet] adds the sheet prefix when
  /// [sheet] is set.
  String format({bool includeSheet = true}) {
    final b = StringBuffer();
    if (includeSheet && sheet != null) {
      b
        ..write(SheetNames.quoteIfNeeded(sheet!))
        ..write('!');
    }
    b.write(formatArea());
    return b.toString();
  }

  /// The area part without sheet prefix.
  String formatArea() {
    String col(int c, bool abs) => '${abs ? r'$' : ''}${ColumnLetters.fromIndex(c)}';
    String row(int r, bool abs) => '${abs ? r'$' : ''}${r + 1}';
    switch (kind) {
      case A1Kind.cell:
        return '${col(col1!, absCol1)}${row(row1!, absRow1)}';
      case A1Kind.rect:
        return '${col(col1!, absCol1)}${row(row1!, absRow1)}:'
            '${col(col2!, absCol2)}${row(row2!, absRow2)}';
      case A1Kind.columns:
        return '${col(col1!, absCol1)}:${col(col2!, absCol2)}';
      case A1Kind.rows:
        return '${row(row1!, absRow1)}:${row(row2!, absRow2)}';
      case A1Kind.openRows:
        return '${col(col1!, absCol1)}${row(row1!, absRow1)}:${col(col2!, absCol2)}';
      case A1Kind.openColumns:
        return '${col(col1!, absCol1)}${row(row1!, absRow1)}:${row(row2!, absRow2)}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is A1Area &&
      other.sheet == sheet &&
      other.kind == kind &&
      other.row1 == row1 &&
      other.col1 == col1 &&
      other.row2 == row2 &&
      other.col2 == col2 &&
      other.absRow1 == absRow1 &&
      other.absCol1 == absCol1 &&
      other.absRow2 == absRow2 &&
      other.absCol2 == absCol2;

  @override
  int get hashCode => Object.hash(
    sheet,
    kind,
    row1,
    col1,
    row2,
    col2,
    absRow1,
    absCol1,
    absRow2,
    absCol2,
  );

  @override
  String toString() => format();

  /// Parses a complete A1 reference (with optional sheet prefix). Returns null when [text] is
  /// not exactly one reference.
  static A1Area? tryParse(String text) {
    final m = A1Scanner.scan(text, 0);
    if (m == null || m.end != text.length) return null;
    return m.area;
  }
}

/// Result of [A1Scanner.scan].
final class A1Match {
  final A1Area area;
  final int start;
  final int end;

  /// Offset where the area starts (after the `!` of a sheet prefix).
  final int areaStart;
  const A1Match(this.area, this.start, this.end, this.areaStart);
}

/// Hand-written scanner for A1 references, shared by the formula lexer, the petitparser grammar
/// and address parsing.
abstract final class A1Scanner {
  static bool _isIdentStart(int c) =>
      ColumnLetters.isLetter(c) || c == 0x5f || c >= 0xc0 && c != 0x27e6 && c != 0x27e7;
  static bool _isIdentPart(int c) =>
      _isIdentStart(c) || ColumnLetters.isDigit(c) || c == 0x2e;

  /// Scans a sheet prefix (`Sheet1!` or `'My sheet'!`) at [i]. Returns `(name, endAfterBang)`.
  static (String, int)? scanSheetPrefix(String s, int i) {
    if (i >= s.length) return null;
    final c = s.codeUnitAt(i);
    if (c == 0x27) {
      // quoted
      var j = i + 1;
      final b = StringBuffer();
      while (j < s.length) {
        final d = s.codeUnitAt(j);
        if (d == 0x27) {
          if (j + 1 < s.length && s.codeUnitAt(j + 1) == 0x27) {
            b.write("'");
            j += 2;
            continue;
          }
          break;
        }
        b.writeCharCode(d);
        j++;
      }
      if (j >= s.length) return null; // unterminated
      if (j + 1 < s.length && s.codeUnitAt(j + 1) == 0x21) {
        return (b.toString(), j + 2);
      }
      return null;
    }
    if (!(ColumnLetters.isLetter(c) || c == 0x5f || c >= 0xc0)) return null;
    var j = i + 1;
    while (j < s.length) {
      final d = s.codeUnitAt(j);
      if (ColumnLetters.isLetter(d) || ColumnLetters.isDigit(d) || d == 0x5f || d >= 0xc0) {
        j++;
      } else {
        break;
      }
    }
    if (j < s.length && s.codeUnitAt(j) == 0x21) {
      return (s.substring(i, j), j + 1);
    }
    return null;
  }

  /// Scans `[$]letters` at [i]: returns (colIndex, abs, end) or null.
  static (int, bool, int)? _col(String s, int i) {
    var j = i;
    var abs = false;
    if (j < s.length && s.codeUnitAt(j) == 0x24) {
      abs = true;
      j++;
    }
    final start = j;
    while (j < s.length && ColumnLetters.isLetter(s.codeUnitAt(j)) && j - start < 4) {
      j++;
    }
    final len = j - start;
    if (len == 0 || len > 3) return null;
    return (ColumnLetters.toIndex(s.substring(start, j)), abs, j);
  }

  /// Scans `[$]digits` at [i]: returns (rowIndex, abs, end) or null.
  static (int, bool, int)? _row(String s, int i) {
    var j = i;
    var abs = false;
    if (j < s.length && s.codeUnitAt(j) == 0x24) {
      abs = true;
      j++;
    }
    final start = j;
    while (j < s.length && ColumnLetters.isDigit(s.codeUnitAt(j)) && j - start < 9) {
      j++;
    }
    if (j == start) return null;
    if (j < s.length && ColumnLetters.isDigit(s.codeUnitAt(j))) return null; // too long
    if (s.codeUnitAt(start) == 0x30) return null; // leading zero
    final n = int.parse(s.substring(start, j));
    if (n < 1 || n > ColumnLetters.maxRows) return null;
    return (n - 1, abs, j);
  }

  static bool _boundaryOk(String s, int j) {
    if (j >= s.length) return true;
    final c = s.codeUnitAt(j);
    if (_isIdentPart(c)) return false;
    if (c == 0x28) return false; // '(' → function call
    if (c == 0x21) return false; // '!' → it was a sheet name
    return true;
  }

  /// Scans an A1 reference starting exactly at [start]. Returns null when there is none.
  /// When [allowSheet] is false, sheet prefixes are not considered.
  static A1Match? scan(String s, int start, {bool allowSheet = true}) {
    String? sheet;
    var i = start;
    if (allowSheet) {
      final p = scanSheetPrefix(s, i);
      if (p != null) {
        sheet = p.$1;
        i = p.$2;
      }
    }
    final areaStart = i;
    final area = _scanArea(s, i);
    if (area == null) return null;
    return A1Match(area.$1.withSheet(sheet), start, area.$2, areaStart);
  }

  static (A1Area, int)? _scanArea(String s, int i) {
    if (i >= s.length) return null;
    // Try cell or column first.
    final c1 = _col(s, i);
    if (c1 != null) {
      final r1 = _row(s, c1.$3);
      if (r1 != null) {
        // cell, maybe range
        final afterCell = r1.$3;
        if (afterCell < s.length && s.codeUnitAt(afterCell) == 0x3a) {
          final k = afterCell + 1;
          final c2 = _col(s, k);
          if (c2 != null) {
            final r2 = _row(s, c2.$3);
            if (r2 != null && _boundaryOk(s, r2.$3)) {
              return (
                A1Area.raw(
                  A1Kind.rect,
                  row1: r1.$1,
                  col1: c1.$1,
                  row2: r2.$1,
                  col2: c2.$1,
                  absRow1: r1.$2,
                  absCol1: c1.$2,
                  absRow2: r2.$2,
                  absCol2: c2.$2,
                ),
                r2.$3,
              );
            }
            if (r2 == null && _boundaryOk(s, c2.$3)) {
              return (
                A1Area.raw(
                  A1Kind.openRows,
                  row1: r1.$1,
                  col1: c1.$1,
                  col2: c2.$1,
                  absRow1: r1.$2,
                  absCol1: c1.$2,
                  absCol2: c2.$2,
                ),
                c2.$3,
              );
            }
          }
          final r2 = _row(s, k);
          if (r2 != null && _boundaryOk(s, r2.$3)) {
            return (
              A1Area.raw(
                A1Kind.openColumns,
                row1: r1.$1,
                col1: c1.$1,
                row2: r2.$1,
                absRow1: r1.$2,
                absCol1: c1.$2,
                absRow2: r2.$2,
              ),
              r2.$3,
            );
          }
        }
        if (_boundaryOk(s, afterCell)) {
          return (
            A1Area.cell(r1.$1, c1.$1, absRow: r1.$2, absCol: c1.$2),
            afterCell,
          );
        }
        return null;
      }
      // column range A:C
      final afterCol = c1.$3;
      if (afterCol < s.length && s.codeUnitAt(afterCol) == 0x3a) {
        final c2 = _col(s, afterCol + 1);
        if (c2 != null && _row(s, c2.$3) == null && _boundaryOk(s, c2.$3)) {
          return (
            A1Area.columns(c1.$1, c2.$1, absCol1: c1.$2, absCol2: c2.$2),
            c2.$3,
          );
        }
      }
      return null;
    }
    // row range 1:3
    final r1 = _row(s, i);
    if (r1 != null && r1.$3 < s.length && s.codeUnitAt(r1.$3) == 0x3a) {
      final r2 = _row(s, r1.$3 + 1);
      if (r2 != null && _boundaryOk(s, r2.$3)) {
        final next = r2.$3;
        // "1:3.5" or "1:3e" are not row ranges
        if (next < s.length && (s.codeUnitAt(next) == 0x2e)) return null;
        return (
          A1Area.rows(r1.$1, r2.$1, absRow1: r1.$2, absRow2: r2.$2),
          r2.$3,
        );
      }
    }
    return null;
  }
}
