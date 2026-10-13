import '../../../addressing/a1.dart';
import '../../../addressing/sheet_names.dart';
import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../eval/range_access.dart';
import '../../values/dates.dart';
import '../../values/errors.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../registry.dart';

/// Information functions (05 §15.8).
void registerInfo(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.info;

  void isFn(
    String name,
    String summary,
    bool Function(FValue v) test, {
    Priority priority = Priority.p0,
    bool passPending = true,
    String example = '',
  }) {
    b.fn(
      name,
      summary,
      [P.scalar('value', 'The value to be verified.')],
      (a) {
        final v = a.scalarOrError(0);
        if (passPending && v is FError && v.pending) return v;
        return FBool(test(v));
      },
      handlesErrors: true,
      priority: priority,
      examples: [example.isEmpty ? '$name(A1)' : example],
    );
  }

  isFn(
    'ISBLANK',
    'Checks whether the referenced cell is empty.',
    (v) => v is FEmpty,
  );
  isFn(
    'ISERR',
    'Checks whether a value is an error other than #N/A.',
    (v) => v is FError && v.kind != ErrorKind.na,
  );
  isFn(
    'ISERROR',
    'Checks whether a value is an error.',
    (v) => v is FError,
    example: 'ISERROR(A1/B1)',
  );
  isFn(
    'ISNA',
    'Checks whether a value is the error #N/A.',
    (v) => v is FError && v.kind == ErrorKind.na,
  );
  isFn(
    'ISLOGICAL',
    'Checks whether a value is TRUE or FALSE.',
    (v) => v is FBool,
  );
  isFn('ISNUMBER', 'Checks whether a value is a number.', (v) => v is FNumber);
  isFn('ISTEXT', 'Checks whether a value is text.', (v) => v is FText);
  isFn(
    'ISNONTEXT',
    'Checks whether a value is non-textual.',
    (v) => v is! FText,
  );
  isFn(
    'ISEMAIL',
    'Checks whether a value is a valid email address.',
    (v) =>
        v is FText &&
        RegExp(
          r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$",
        ).hasMatch(v.v.trim()),
    priority: Priority.p1,
    example: 'ISEMAIL("hello@example.com")',
  );
  isFn(
    'ISURL',
    'Checks whether a value is a valid URL.',
    (v) =>
        v is FText &&
        RegExp(
          r'^(?:(?:https?|ftp)://)?(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}(?::\d+)?(?:[/?#]\S*)?$',
          caseSensitive: false,
        ).hasMatch(v.v.trim()),
    priority: Priority.p1,
    example: 'ISURL("https://example.com")',
  );

  b.fn(
    'ISEVEN',
    'Checks whether the provided value is even.',
    [P.num('value', 'The value to be verified as even.')],
    (a) => FBool(a.number(0).truncate().isEven),
    examples: ['ISEVEN(4)'],
  );
  b.fn(
    'ISODD',
    'Checks whether the provided value is odd.',
    [P.num('value', 'The value to be verified as odd.')],
    (a) => FBool(a.number(0).truncate().isOdd),
    examples: ['ISODD(3)'],
  );
  b.fn(
    'ISREF',
    'Checks whether a value is a valid cell reference.',
    [P.any('value', 'The value to be verified as a cell reference.')],
    (a) => FBool(a[0] is FRef),
    handlesErrors: true,
    liftable: false,
    examples: ['ISREF(A1)', 'ISREF("A1")'],
  );
  b.fn(
    'ISFORMULA',
    'Checks whether a value is a formula.',
    [P.ref('cell', 'The cell to be verified as containing a formula.')],
    (a) {
      final r = a.ref(0);
      final s = a.sheetOfRef(r);
      return FBool(a.ctx.host.formulaAt(s, r.area.top, r.area.left) != null);
    },
    liftable: false,
    examples: ['ISFORMULA(A2)'],
  );
  b.fn(
    'ISDATE',
    'Returns whether a value is a date.',
    [P.any('value', 'The value to be verified as a date.')],
    (a) {
      var v = a[0];
      if (v is FRef) {
        final s = a.sheetOfRef(v);
        final x = RangeAccess.cellWithHint(a.ctx, s, v.area.top, v.area.left);
        return FBool(x is FNumber && x.hint.isDateLike);
      }
      if (v is FRich) v = v.scalar;
      return switch (v) {
        FNumber(:final hint) => FBool(hint.isDateLike),
        FText(:final v) => FBool(
          DateTimeParser.parse(
                v,
                a.locale,
                currentYear: a.ctx.currentYear,
              )?.hasDate ??
              false,
        ),
        _ => FBool.f,
      };
    },
    handlesErrors: true,
    liftable: false,
    examples: ['ISDATE(DATE(2024, 1, 1))', 'ISDATE("2024-01-31")'],
  );

  b.fn(
    'ERROR.TYPE',
    'Returns a number corresponding to the error value in a different cell.',
    [
      P.scalar(
        'reference',
        'The cell to find the error number for, although you can also provide the error value directly.',
      ),
    ],
    (a) {
      final v = a.scalarOrError(0);
      if (v is FError) return FNumber(v.kind.typeCode.toDouble());
      return const FError(
        ErrorKind.na,
        'ERROR.TYPE parameter 1 is not an error.',
      );
    },
    handlesErrors: true,
    priority: Priority.p0,
    examples: ['ERROR.TYPE(A1)', 'ERROR.TYPE(1/0)'],
  );
  b.fn(
    'NA',
    'Returns the "value not available" error, #N/A.',
    const [],
    (_) => const FError(ErrorKind.na, 'Value not available.'),
    priority: Priority.p0,
    examples: ['NA()'],
  );
  b.fn(
    'N',
    'Returns the argument provided as a number. Text is converted to 0 and errors are returned as-is.',
    [P.scalar('value', 'The argument to be converted to a number.')],
    (a) => switch (a.scalarOrError(0)) {
      final FNumber n => FNumber(n.v),
      FBool(:final v) => FNumber(v ? 1 : 0),
      final FError e => e,
      _ => FNumber.zero,
    },
    handlesErrors: true,
    examples: ['N("hello")', 'N(TRUE)'],
  );
  b.fn(
    'TYPE',
    'Returns a number associated with the type of data passed into the function: 1 number, 2 text, 4 boolean, 16 error, 64 array, 128 lambda.',
    [P.any('value', 'The data whose type is to be determined.')],
    (a) {
      var v = a[0];
      if (v is FRef) {
        if (!v.area.isSingleCell) return const FNumber(64);
        v = RangeAccess.cell(a.ctx, v);
      }
      if (v is FRich) v = v.scalar;
      return FNumber(switch (v) {
        FText() => 2,
        FBool() => 4,
        FError() => 16,
        FArray() => 64,
        FLambda() => 128,
        _ => 1,
      });
    },
    handlesErrors: true,
    liftable: false,
    examples: ['TYPE(A1)', 'TYPE({1,2})'],
  );
  b.fn(
    'CELL',
    'Returns the requested information about the specified cell.',
    [
      P.text(
        'info_type',
        'The type of information requested: "address", "col", "color", "contents", "format", "parentheses", "prefix", "protect", "row", "type", "width".',
      ),
      P.ref('reference', 'The reference to the cell.'),
    ],
    _cell,
    positionSensitive: true,
    liftable: false,
    examples: ['CELL("address", B2)', 'CELL("type", A1)'],
  );
  b.fn(
    'SHEET',
    'Returns the sheet number of the specified sheet or other reference.',
    [
      P.any(
        'value',
        'A reference or the name of a sheet. Defaults to the sheet containing the formula.',
        true,
      ),
    ],
    (a) {
      final sheets = a.ctx.workbook.sheets;
      String id = a.ctx.sheet.id;
      if (a.has(0)) {
        final v = a[0];
        if (v is FRef) {
          id = v.area.sheetId;
        } else if (v is FText) {
          final s = a.ctx.workbook.sheetByName(v.v);
          if (s == null) fail(ErrorKind.na, "Sheet '${v.v}' not found.");
          id = s.id;
        } else if (v is FError) {
          return v;
        } else {
          fail(ErrorKind.value);
        }
      }
      a.ctx.deps.sheetNames = true;
      for (var i = 0; i < sheets.length; i++) {
        if (sheets[i].id == id) return FNumber(i + 1.0);
      }
      return FError.ref;
    },
    liftable: false,
    priority: Priority.p2,
    examples: ['SHEET()', 'SHEET("Sheet2")'],
  );
  b.fn(
    'SHEETS',
    'Returns the number of sheets in a reference or in the spreadsheet.',
    [
      P.any(
        'reference',
        'A reference (counts 1) — omit to count all sheets.',
        true,
      ),
    ],
    (a) {
      a.ctx.deps.sheetNames = true;
      if (a.has(0) && a[0] is FRef) return FNumber.one;
      return FNumber(a.ctx.workbook.sheets.length.toDouble());
    },
    liftable: false,
    priority: Priority.p2,
    examples: ['SHEETS()'],
  );
  b.stub(
    'INFO',
    'Returns information about the operating environment (not supported).',
    message: ErrorMessages.notAvailable('INFO'),
  );
}

FValue _cell(Args a) {
  final type = a.text(0).toLowerCase();
  final r = a.ref(1);
  final s = a.sheetOfRef(r);
  final row = r.area.top, col = r.area.left;
  final host = a.ctx.host;
  switch (type) {
    case 'address':
      final addr = A1Area.cell(row, col, absRow: true, absCol: true).format();
      if (s.id != a.ctx.sheet.id) {
        a.ctx.deps.sheetNames = true;
        return FText('${SheetNames.quoteIfNeeded(s.name)}!$addr');
      }
      return FText(addr);
    case 'col':
      return FNumber(col + 1.0);
    case 'row':
      return FNumber(row + 1.0);
    case 'contents':
      final v = host.cellValue(s, row, col);
      return v is FRich ? v.scalar : v;
    case 'type':
      final v = host.cellValue(s, row, col);
      if (v is FEmpty) return const FText('b');
      if (v is FText) return const FText('l');
      return const FText('v');
    case 'width':
      a.ctx.deps.axisSheets.add(s.id);
      return FNumber((s.columnWidthAt(col) / 7).roundToDouble());
    case 'prefix':
      final v = host.cellValue(s, row, col);
      return v is FText ? const FText("'") : FText.empty;
    case 'format':
      return FText(_formatCode(host.cellHint(s, row, col)));
    case 'color':
      final h = host.cellHint(s, row, col);
      return FNumber(
        h.kind == FormatHintKind.fromCell && (h.detail ?? '').contains(';[')
            ? 1
            : 0,
      );
    case 'parentheses':
      final h = host.cellHint(s, row, col);
      return FNumber(
        h.kind == FormatHintKind.fromCell && (h.detail ?? '').contains('(')
            ? 1
            : 0,
      );
    case 'protect':
      return FNumber.one;
    default:
      fail(
        ErrorKind.value,
        "Function CELL parameter 1 value '$type' is not valid.",
      );
  }
}

/// Excel CELL("format") codes.
String _formatCode(FormatHint h) {
  switch (h.kind) {
    case FormatHintKind.none:
      return 'G';
    case FormatHintKind.date || FormatHintKind.dateTime:
      return 'D1';
    case FormatHintKind.time || FormatHintKind.duration:
      return 'D9';
    case FormatHintKind.percent:
      return 'P0';
    case FormatHintKind.currency:
      return 'C2';
    case FormatHintKind.scientific:
      return 'S2';
    case FormatHintKind.fromCell:
      final p = h.detail ?? '';
      if (FormatHint.looksLikeDatePattern(p)) return 'D1';
      final dec = RegExp(r'\.(0+)').firstMatch(p)?.group(1)?.length ?? 0;
      if (p.contains('%')) return 'P$dec';
      if (p.contains(r'$') || p.contains('€') || p.contains('£')) {
        return 'C$dec';
      }
      if (p.contains('E+') || p.contains('E-')) return 'S$dec';
      if (p.contains(',')) return ',$dec';
      if (RegExp('[0#]').hasMatch(p)) return 'F$dec';
      return 'G';
  }
}
