import '../../addressing/a1.dart';
import '../../addressing/grid_geometry.dart';
import '../../addressing/r1c1.dart';
import '../../addressing/sheet_names.dart';
import '../functions/registry.dart';
import '../model/workbook_view.dart';
import '../parser/formula_locale.dart';
import '../parser/lexer.dart';
import 'ref_resolver.dart';
import 'ref_token.dart';

/// Context for converting a formula at a host cell (05 §5.1).
final class CodecContext {
  final WorkbookView workbook;
  final String hostSheetId;

  /// Current indices of the formula's cell (or range top-left for rule formulas).
  final int hostRow;
  final int hostCol;
  final FormulaLocale locale;

  const CodecContext({
    required this.workbook,
    required this.hostSheetId,
    this.hostRow = 0,
    this.hostCol = 0,
    this.locale = FormulaLocale.enUS,
  });

  SheetView? get hostSheet => workbook.sheetById(hostSheetId);

  CodecContext at(int row, int col) => CodecContext(
    workbook: workbook,
    hostSheetId: hostSheetId,
    hostRow: row,
    hostCol: col,
    locale: locale,
  );
}

/// A1 ⇄ stored form conversion on the token stream (05 §5).
abstract final class FormulaCodec {
  static const FormulaLexer _storedLexer = FormulaLexer();

  /// User A1 text (with or without `=`) → stored text (canonical separators, `=` prefix).
  static String toStored(String a1, CodecContext ctx) {
    final host = ctx.hostSheet;
    final tokens = FormulaLexer(locale: ctx.locale).tokenize(_withEq(a1));
    final b = StringBuffer();
    for (final t in tokens) {
      switch (t.kind) {
        case TokenKind.cellRef:
        case TokenKind.rangeRef:
        case TokenKind.columnRange:
        case TokenKind.rowRange:
          b.write(_encodeA1(t.ref!.a1!, ctx, host));
        case TokenKind.functionName:
          b.write(_canonicalFunctionName(t.text, ctx.workbook));
        case TokenKind.name:
          b.write(_canonicalName(t.text, ctx.workbook));
        case TokenKind.boolean:
          b.write(t.text.toUpperCase());
        case TokenKind.error:
          b.write(t.text.toUpperCase());
        case TokenKind.number:
          b.write(
            ctx.locale.decimal == '.'
                ? t.text
                : t.text.replaceAll(ctx.locale.decimal, '.'),
          );
        case TokenKind.argSeparator:
        case TokenKind.arrayColSep:
          b.write(',');
        case TokenKind.arrayRowSep:
          b.write(';');
        default:
          b.write(t.text);
      }
    }
    return b.toString();
  }

  static String _withEq(String s) => s.startsWith('=') ? s : '=$s';

  static String _canonicalFunctionName(String name, WorkbookView wb) {
    final upper = name.toUpperCase();
    if (FunctionRegistry.standard.has(upper)) return upper;
    for (final n in wb.namedRanges) {
      if (n.name.toUpperCase() == upper) return n.name;
    }
    return name;
  }

  static String _canonicalName(String name, WorkbookView wb) {
    final upper = name.toUpperCase();
    for (final n in wb.namedRanges) {
      if (n.name.toUpperCase() == upper) return n.name;
    }
    return name;
  }

  static String _encodeA1(A1Area area, CodecContext ctx, SheetView? host) {
    SheetView? sheet = host;
    String? sheetId;
    if (area.sheet != null) {
      sheet = ctx.workbook.sheetByName(area.sheet!);
      if (sheet == null) {
        return RefToken(unbound: area.format()).encode();
      }
      if (sheet.id != ctx.hostSheetId) sheetId = sheet.id;
    }
    if (sheet == null) return RefToken(unbound: area.format()).encode();
    final rows = sheet.rows;
    final cols = sheet.columns;
    bool rowOk(int? r) => r == null || r < rows.length;
    bool colOk(int? c) => c == null || c < cols.length;
    if (!rowOk(area.row1) ||
        !rowOk(area.row2) ||
        !colOk(area.col1) ||
        !colOk(area.col2)) {
      return RefToken(
        sheetId: sheetId,
        unbound: area.format(
          includeSheet: sheetId == null && area.sheet != null,
        ),
      ).encode();
    }
    if (area.kind == A1Kind.cell) {
      return RefToken(
        sheetId: sheetId,
        rowId: rows.idAt(area.row1!),
        colId: cols.idAt(area.col1!),
        absRow: area.absRow1,
        absCol: area.absCol1,
      ).encode();
    }
    RefToken endpoint(int? r, bool ar, int? c, bool ac, String? sid) =>
        RefToken(
          sheetId: sid,
          rowId: r == null ? null : rows.idAt(r),
          colId: c == null ? null : cols.idAt(c),
          absRow: r != null && ar,
          absCol: c != null && ac,
          rowKey: r == null ? null : rows.sortKeyAt(r),
          colKey: c == null ? null : cols.sortKeyAt(c),
        );
    final start = endpoint(
      area.row1,
      area.absRow1,
      area.col1,
      area.absCol1,
      sheetId,
    );
    final end = endpoint(
      area.row2,
      area.absRow2,
      area.col2,
      area.absCol2,
      null,
    );
    return '${start.encode()}:${end.encode()}';
  }

  /// Stored text → A1 text in [CodecContext.locale]. Missing ids render `#REF!`.
  static String toA1(String stored, CodecContext ctx) {
    final host = ctx.hostSheet;
    final tokens = _storedLexer.tokenize(_withEq(stored));
    final loc = ctx.locale;
    final b = StringBuffer();
    for (final t in tokens) {
      switch (t.kind) {
        case TokenKind.storedRef:
          b.write(
            renderStoredRef(
              t.ref!.stored!,
              ctx.workbook,
              host,
              ctx.hostSheetId,
            ),
          );
        case TokenKind.number:
          b.write(
            loc.decimal == '.' ? t.text : t.text.replaceAll('.', loc.decimal),
          );
        case TokenKind.argSeparator:
          b.write(loc.argSeparator);
        case TokenKind.arrayColSep:
          b.write(loc.arrayColSeparator);
        case TokenKind.arrayRowSep:
          b.write(loc.arrayRowSeparator);
        default:
          b.write(t.text);
      }
    }
    return b.toString();
  }

  /// Renders one stored reference as A1 (`#REF!` when it cannot be resolved).
  static String renderStoredRef(
    StoredRef ref,
    WorkbookView wb,
    SheetView? host,
    String hostSheetId,
  ) {
    final s = ref.start;
    if (s.isUnbound) {
      if (s.sheetId != null) {
        final sh = wb.sheetById(s.sheetId!);
        if (sh == null) return '#REF!';
        return '${SheetNames.quoteIfNeeded(sh.name)}!${s.unbound}';
      }
      return s.unbound!;
    }
    if (host == null) return '#REF!';
    final r = RefResolver.resolve(ref, wb, host);
    if (r is! ResolvedRef) return '#REF!';
    final area = A1Area.raw(
      r.kind,
      sheet: (s.sheetId != null && s.sheetId != hostSheetId)
          ? r.sheet.name
          : null,
      row1: r.row1,
      col1: r.col1,
      row2: r.row2,
      col2: r.col2,
      absRow1: s.absRow,
      absCol1: s.absCol,
      absRow2: ref.end?.absRow ?? s.absRow,
      absCol2: ref.end?.absCol ?? s.absCol,
    );
    return area.format();
  }

  /// Canonical A1 form of user text: `toA1(toStored(a1))`.
  static String normalize(String a1, CodecContext ctx) =>
      toA1(toStored(a1, ctx), ctx);

  /// Copy/fill/paste (03 §10, §12.3): shifts relative parts by the index delta between the
  /// hosts. [fromSheetId]/[toSheetId] default to the same sheet. Refs shifted out of the grid
  /// become `#REF!`.
  static String translate(
    String stored,
    CellPos from,
    CellPos to,
    WorkbookView wb, {
    required String fromSheetId,
    String? toSheetId,
  }) {
    final src = wb.sheetById(fromSheetId);
    final dst = wb.sheetById(toSheetId ?? fromSheetId);
    if (src == null || dst == null) return _withEq(stored);
    final dRow = to.row - from.row;
    final dCol = to.col - from.col;
    final tokens = _storedLexer.tokenize(_withEq(stored));
    final b = StringBuffer();
    for (final t in tokens) {
      if (t.kind != TokenKind.storedRef) {
        b.write(t.text);
        continue;
      }
      b.write(_translateRef(t.ref!.stored!, wb, src, dst, dRow, dCol));
    }
    return b.toString();
  }

  static String _translateRef(
    StoredRef ref,
    WorkbookView wb,
    SheetView src,
    SheetView dst,
    int dRow,
    int dCol,
  ) {
    final s = ref.start;
    if (s.isUnbound) {
      final area = A1Area.tryParse(s.unbound!);
      if (area == null) return ref.encode();
      final shifted = _shiftArea(area, dRow, dCol);
      if (shifted == null) return '#REF!';
      return s.copyWith(unbound: shifted.format()).encode();
    }
    // The referenced sheet: explicit S: stays; implicit = host sheet (source → destination).
    final refSheet = s.sheetId != null ? wb.sheetById(s.sheetId!) : src;
    if (refSheet == null) return ref.encode();
    final targetSheet = s.sheetId != null ? refSheet : dst;
    RefToken? shift(RefToken tok, {required bool isStart}) {
      String? rowId = tok.rowId, colId = tok.colId;
      String? rowKey = tok.rowKey, colKey = tok.colKey;
      if (tok.rowId != null) {
        final idx = RefResolver.endpointIndex(
          refSheet.rows,
          tok.rowId!,
          tok.rowKey,
          isStart: isStart,
        );
        if (idx < 0) return null;
        final ni = tok.absRow ? idx : idx + dRow;
        if (ni < 0 || ni >= targetSheet.rows.length) return null;
        rowId = targetSheet.rows.idAt(ni);
        if (tok.rowKey != null) rowKey = targetSheet.rows.sortKeyAt(ni);
      }
      if (tok.colId != null) {
        final idx = RefResolver.endpointIndex(
          refSheet.columns,
          tok.colId!,
          tok.colKey,
          isStart: isStart,
        );
        if (idx < 0) return null;
        final ni = tok.absCol ? idx : idx + dCol;
        if (ni < 0 || ni >= targetSheet.columns.length) return null;
        colId = targetSheet.columns.idAt(ni);
        if (tok.colKey != null) colKey = targetSheet.columns.sortKeyAt(ni);
      }
      return tok.copyWith(
        rowId: rowId,
        colId: colId,
        rowKey: rowKey,
        colKey: colKey,
      );
    }

    // Missing ids (deleted rows) stay as they are (they render #REF!).
    if (ref.end == null) {
      final a = shift(s, isStart: true);
      if (a == null) {
        final missing =
            (s.rowId != null && refSheet.rows.indexOf(s.rowId!) < 0) ||
            (s.colId != null && refSheet.columns.indexOf(s.colId!) < 0);
        return missing ? ref.encode() : '#REF!';
      }
      return a.encode();
    }
    final a = shift(s, isStart: true);
    final e = shift(ref.end!, isStart: false);
    if (a == null || e == null) return '#REF!';
    return '${a.encode()}:${e.encode()}';
  }

  static A1Area? _shiftArea(A1Area a, int dRow, int dCol) {
    int? sr(int? r, bool abs) => r == null ? null : (abs ? r : r + dRow);
    int? sc(int? c, bool abs) => c == null ? null : (abs ? c : c + dCol);
    final r1 = sr(a.row1, a.absRow1), r2 = sr(a.row2, a.absRow2);
    final c1 = sc(a.col1, a.absCol1), c2 = sc(a.col2, a.absCol2);
    for (final v in [r1, r2, c1, c2]) {
      if (v != null && v < 0) return null;
    }
    return A1Area.raw(
      a.kind,
      sheet: a.sheet,
      row1: r1,
      col1: c1,
      row2: r2,
      col2: c2,
      absRow1: a.absRow1,
      absCol1: a.absCol1,
      absRow2: a.absRow2,
      absCol2: a.absCol2,
    );
  }

  /// Stored → R1C1 text relative to the host cell (scripts, XLSX shared formulas).
  static String toR1C1(String stored, CodecContext ctx) {
    final host = ctx.hostSheet;
    final tokens = _storedLexer.tokenize(_withEq(stored));
    final b = StringBuffer();
    for (final t in tokens) {
      if (t.kind != TokenKind.storedRef) {
        b.write(t.text);
        continue;
      }
      final ref = t.ref!.stored!;
      if (host == null || ref.start.isUnbound) {
        b.write(ref.start.isUnbound ? ref.start.unbound : '#REF!');
        continue;
      }
      final r = RefResolver.resolve(ref, ctx.workbook, host);
      if (r is! ResolvedRef) {
        b.write('#REF!');
        continue;
      }
      final s = ref.start;
      final area = A1Area.raw(
        r.kind,
        sheet: (s.sheetId != null && s.sheetId != ctx.hostSheetId)
            ? r.sheet.name
            : null,
        row1: r.row1,
        col1: r.col1,
        row2: r.row2,
        col2: r.col2,
        absRow1: s.absRow,
        absCol1: s.absCol,
        absRow2: ref.end?.absRow ?? s.absRow,
        absCol2: ref.end?.absCol ?? s.absCol,
      );
      b.write(R1C1.format(area, ctx.hostRow, ctx.hostCol));
    }
    return b.toString();
  }

  /// R1C1 text → stored text at the host cell.
  static String fromR1C1(String r1c1, CodecContext ctx) =>
      toStored(r1c1ToA1(r1c1, ctx.hostRow, ctx.hostCol), ctx);

  /// Rewrites R1C1 references to A1 text (strings untouched).
  static String r1c1ToA1(String text, int hostRow, int hostCol) {
    final b = StringBuffer();
    var i = 0;
    final n = text.length;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (c == 0x22) {
        var j = i + 1;
        while (j < n) {
          if (text.codeUnitAt(j) == 0x22) {
            if (j + 1 < n && text.codeUnitAt(j + 1) == 0x22) {
              j += 2;
              continue;
            }
            break;
          }
          j++;
        }
        final e = j < n ? j + 1 : n;
        b.write(text.substring(i, e));
        i = e;
        continue;
      }
      final prevIdent =
          i > 0 && FormulaLexer.isIdentPart(text.codeUnitAt(i - 1));
      if (!prevIdent &&
          (c == 0x52 ||
              c == 0x72 ||
              c == 0x43 ||
              c == 0x63 ||
              c == 0x27 ||
              FormulaLexer.isIdentStart(c))) {
        final m = R1C1.scan(text, i, hostRow, hostCol);
        if (m != null) {
          b.write(m.$1.format());
          i = m.$2;
          continue;
        }
      }
      // copy one identifier at a time so R1C1 matching only starts at identifier boundaries
      if (FormulaLexer.isIdentStart(c)) {
        var j = i + 1;
        while (j < n && FormulaLexer.isIdentPart(text.codeUnitAt(j))) {
          j++;
        }
        b.write(text.substring(i, j));
        i = j;
        continue;
      }
      b.writeCharCode(c);
      i++;
    }
    return b.toString();
  }

  /// All stored references in [stored], in order.
  static List<StoredRef> references(String stored) => [
    for (final t in _storedLexer.tokenize(stored))
      if (t.kind == TokenKind.storedRef) t.ref!.stored!,
  ];
}
