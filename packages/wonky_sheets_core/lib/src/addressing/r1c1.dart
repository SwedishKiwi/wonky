import 'a1.dart';
import 'column_letters.dart';
import 'sheet_names.dart';

/// R1C1 notation helpers (scripts, XLSX shared formulas, `INDIRECT(…, FALSE)`, `ADDRESS`).
///
/// `R2C3` is absolute (row 2, column 3); `R[1]C[-1]` is relative to the host cell; `RC` is the
/// host cell itself. Whole rows `R2:R4`, whole columns `C1:C3`.
abstract final class R1C1 {
  static String _part(String letter, int index, bool abs, int host) {
    if (abs) return '$letter${index + 1}';
    final d = index - host;
    return d == 0 ? letter : '$letter[$d]';
  }

  /// Formats [area] relative to the host cell ([hostRow], [hostCol]).
  static String format(
    A1Area area,
    int hostRow,
    int hostCol, {
    bool includeSheet = true,
  }) {
    final b = StringBuffer();
    if (includeSheet && area.sheet != null) {
      b
        ..write(SheetNames.quoteIfNeeded(area.sheet!))
        ..write('!');
    }
    String cell(int r, bool ar, int c, bool ac) =>
        '${_part('R', r, ar, hostRow)}${_part('C', c, ac, hostCol)}';
    switch (area.kind) {
      case A1Kind.cell:
        b.write(cell(area.row1!, area.absRow1, area.col1!, area.absCol1));
      case A1Kind.rect:
        b
          ..write(cell(area.row1!, area.absRow1, area.col1!, area.absCol1))
          ..write(':')
          ..write(cell(area.row2!, area.absRow2, area.col2!, area.absCol2));
      case A1Kind.columns:
        b
          ..write(_part('C', area.col1!, area.absCol1, hostCol))
          ..write(':')
          ..write(_part('C', area.col2!, area.absCol2, hostCol));
      case A1Kind.rows:
        b
          ..write(_part('R', area.row1!, area.absRow1, hostRow))
          ..write(':')
          ..write(_part('R', area.row2!, area.absRow2, hostRow));
      case A1Kind.openRows:
        b
          ..write(cell(area.row1!, area.absRow1, area.col1!, area.absCol1))
          ..write(':')
          ..write(_part('C', area.col2!, area.absCol2, hostCol));
      case A1Kind.openColumns:
        b
          ..write(cell(area.row1!, area.absRow1, area.col1!, area.absCol1))
          ..write(':')
          ..write(_part('R', area.row2!, area.absRow2, hostRow));
    }
    return b.toString();
  }

  static final RegExp _cellRe = RegExp(
    r'^(?:[Rr](?:(\d+)|\[(-?\d+)\])?)(?:[Cc](?:(\d+)|\[(-?\d+)\])?)',
  );
  static final RegExp _rowRe = RegExp(r'^[Rr](?:(\d+)|\[(-?\d+)\])?');
  static final RegExp _colRe = RegExp(r'^[Cc](?:(\d+)|\[(-?\d+)\])?');

  /// Scans an R1C1 reference at [start]; returns the area (indices resolved against the host)
  /// and the end offset, or null.
  static (A1Area, int)? scan(String s, int start, int hostRow, int hostCol) {
    String? sheet;
    var i = start;
    final p = A1Scanner.scanSheetPrefix(s, i);
    if (p != null) {
      sheet = p.$1;
      i = p.$2;
    }
    (int, bool) val(String? absText, String? relText, int host) {
      if (absText != null) return (int.parse(absText) - 1, true);
      if (relText != null) return (host + int.parse(relText), false);
      return (host, false);
    }

    final rest = s.substring(i);
    final m1 = _cellRe.firstMatch(rest);
    bool boundary(int end) {
      if (end >= rest.length) return true;
      final c = rest.codeUnitAt(end);
      return !(ColumnLetters.isLetter(c) ||
          ColumnLetters.isDigit(c) ||
          c == 0x5f ||
          c == 0x28);
    }

    if (m1 != null) {
      final (r1, ar1) = val(m1.group(1), m1.group(2), hostRow);
      final (c1, ac1) = val(m1.group(3), m1.group(4), hostCol);
      var end = m1.end;
      if (end < rest.length && rest.codeUnitAt(end) == 0x3a) {
        final tail = rest.substring(end + 1);
        final m2 = _cellRe.firstMatch(tail);
        if (m2 != null && boundary(end + 1 + m2.end)) {
          final (r2, ar2) = val(m2.group(1), m2.group(2), hostRow);
          final (c2, ac2) = val(m2.group(3), m2.group(4), hostCol);
          if (r1 < 0 || c1 < 0 || r2 < 0 || c2 < 0) return null;
          return (
            A1Area.raw(
              A1Kind.rect,
              sheet: sheet,
              row1: r1,
              col1: c1,
              row2: r2,
              col2: c2,
              absRow1: ar1,
              absCol1: ac1,
              absRow2: ar2,
              absCol2: ac2,
            ),
            i + end + 1 + m2.end,
          );
        }
      }
      if (!boundary(end)) return null;
      if (r1 < 0 || c1 < 0) return null;
      return (
        A1Area.cell(r1, c1, sheet: sheet, absRow: ar1, absCol: ac1),
        i + end,
      );
    }
    final mr = _rowRe.firstMatch(rest);
    if (mr != null && mr.end < rest.length && rest.codeUnitAt(mr.end) == 0x3a) {
      final tail = rest.substring(mr.end + 1);
      final mr2 = _rowRe.firstMatch(tail);
      if (mr2 != null && boundary(mr.end + 1 + mr2.end)) {
        final (r1, a1) = val(mr.group(1), mr.group(2), hostRow);
        final (r2, a2) = val(mr2.group(1), mr2.group(2), hostRow);
        if (r1 < 0 || r2 < 0) return null;
        return (
          A1Area.rows(r1, r2, sheet: sheet, absRow1: a1, absRow2: a2),
          i + mr.end + 1 + mr2.end,
        );
      }
    }
    final mc = _colRe.firstMatch(rest);
    if (mc != null && mc.end < rest.length && rest.codeUnitAt(mc.end) == 0x3a) {
      final tail = rest.substring(mc.end + 1);
      final mc2 = _colRe.firstMatch(tail);
      if (mc2 != null && boundary(mc.end + 1 + mc2.end)) {
        final (c1, a1) = val(mc.group(1), mc.group(2), hostCol);
        final (c2, a2) = val(mc2.group(1), mc2.group(2), hostCol);
        if (c1 < 0 || c2 < 0) return null;
        return (
          A1Area.columns(c1, c2, sheet: sheet, absCol1: a1, absCol2: a2),
          i + mc.end + 1 + mc2.end,
        );
      }
    }
    return null;
  }

  /// Parses a complete R1C1 reference relative to the host.
  static A1Area? tryParse(String text, int hostRow, int hostCol) {
    final m = scan(text, 0, hostRow, hostCol);
    if (m == null || m.$2 != text.length) return null;
    return m.$1;
  }
}
