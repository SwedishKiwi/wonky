import '../../eval/args.dart';
import '../../eval/range_access.dart';
import '../../parser/formula_locale.dart';
import '../../values/format_hint.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../registry.dart';

/// Number pattern displaying [hint] in [locale] (mirrors the 06 presets), or null for
/// General display.
String? patternForHint(FormatHint hint, FormulaLocale locale) {
  final english = locale.id.startsWith('en');
  final date = switch (locale.dateOrder) {
    DateOrder.mdy => 'm/d/yyyy',
    DateOrder.dmy => english ? 'dd/mm/yyyy' : 'dd.mm.yyyy',
    DateOrder.ymd => 'yyyy-mm-dd',
  };
  final time = english ? 'h:mm:ss AM/PM' : 'hh:mm:ss';
  final dateTime =
      '$date ${locale.dateOrder == DateOrder.mdy ? 'h' : 'hh'}:mm:ss';
  String currency([String? symbol]) {
    final s = (symbol ?? locale.currencySymbol).replaceAll('"', '');
    return locale.dateOrder == DateOrder.mdy || english
        ? '"$s"#,##0.00'
        : '#,##0.00 "$s"';
  }

  switch (hint.kind) {
    case FormatHintKind.none:
      return null;
    case FormatHintKind.date:
      return date;
    case FormatHintKind.time:
      return time;
    case FormatHintKind.dateTime:
      return dateTime;
    case FormatHintKind.duration:
      return '[h]:mm:ss';
    case FormatHintKind.percent:
      return '0.00%';
    case FormatHintKind.scientific:
      return '0.00E+00';
    case FormatHintKind.currency:
      final code = hint.detail;
      return currency(
        code == null || code == locale.currencyCode ? null : code,
      );
    case FormatHintKind.fromCell:
      final p = hint.detail ?? '';
      if (p.isEmpty ||
          p == 'preset:automatic' ||
          p.toLowerCase() == 'general') {
        return null;
      }
      return switch (p) {
        'preset:date' => date,
        'preset:time' => time,
        'preset:dateTime' => dateTime,
        'preset:currency' || 'preset:accounting' => currency(),
        'preset:currencyRounded' => currency().replaceAll('.00', ''),
        _ when p.startsWith('preset:') => null,
        _ => p,
      };
  }
}

/// Display text of [v] formatted with [hint] (General when there is no hint).
FValue _displayText(Args a, FValue v, FormatHint hint) {
  if (v is FRich) v = v.scalar;
  switch (v) {
    case FError():
      return v;
    case FNumber(v: final x):
      final h = hint.isNone ? v.hint : hint;
      final pattern = patternForHint(h, a.locale);
      if (pattern != null) {
        final s = a.ctx.host.textFormatter.format(v, pattern, a.locale);
        if (s != null) return FText(s);
      }
      return FText(Numeric.toText(x, decimal: a.locale.decimal));
    case FText():
      return v;
    case FBool(v: final b):
      return FText(b ? 'TRUE' : 'FALSE');
    default:
      return FText.empty;
  }
}

FValue _cellText(Args a, FRef ref, int row, int col) {
  final s = a.sheetOfRef(ref);
  final cell = FRef(
    ResolvedArea.cell(ref.area.sheetId, row, col),
    dynamic: ref.dynamic,
  );
  final v = RangeAccess.cell(a.ctx, cell);
  return _displayText(a, v, a.ctx.host.cellHint(s, row, col));
}

FValue _toText(Args a) {
  final v = a[0];
  final ctx = a.ctx;
  if (v is FRef) {
    final area = v.area;
    if (area.isSingleCell) return _cellText(a, v, area.top, area.left);
    if (ctx.arrayMode) {
      final c = RangeAccess.clamp(ctx, v);
      return FArray.generate(
        c.rows,
        c.cols,
        (r, col) => _cellText(a, v, c.top + r, c.left + col),
      );
    }
    // Implicit intersection (05 §7.4).
    if (area.left == area.right &&
        ctx.row >= area.top &&
        ctx.row <= area.bottom) {
      return _cellText(a, v, ctx.row, area.left);
    }
    if (area.top == area.bottom &&
        ctx.col >= area.left &&
        ctx.col <= area.right) {
      return _cellText(a, v, area.top, ctx.col);
    }
    return RangeAccess.intersect(ctx, v);
  }
  if (v is FArray) {
    if (ctx.arrayMode && v.length > 1) {
      return FArray.generate(
        v.rows,
        v.cols,
        (r, c) => _displayText(a, v.at(r, c), FormatHint.none),
      );
    }
    return _displayText(a, v.topLeft, FormatHint.none);
  }
  return _displayText(a, v, FormatHint.none);
}

/// Number arguments get [hint]; other values pass through unchanged (Sheets behavior).
FValue _withHint(FValue v, FormatHint hint) =>
    v is FNumber ? FNumber(v.v, hint) : v;

/// TO_DATE, TO_DOLLARS, TO_PERCENT, TO_PURE_NUMBER, TO_TEXT (05 §15.15).
void registerToFunctions(FunctionRegistryBuilder b) {
  b.fn(
    'TO_DATE',
    'Converts a provided number to a date.',
    [
      P.scalar(
        'value',
        'The argument or reference to a cell to be converted to a date. Values that are not numbers are returned unchanged.',
      ),
    ],
    (a) => _withHint(a.scalar(0), FormatHint.date),
    examples: ['TO_DATE(25405)', 'TO_DATE(A2)'],
    seeAlso: ['TO_PURE_NUMBER', 'DATE'],
  );
  b.fn(
    'TO_DOLLARS',
    'Converts a provided number to a dollar value.',
    [
      P.scalar(
        'value',
        'The argument or reference to a cell to be converted to a dollar value. Values that are not numbers are returned unchanged.',
      ),
    ],
    (a) => _withHint(a.scalar(0), FormatHint.currencyDefault),
    examples: ['TO_DOLLARS(1.5)', 'TO_DOLLARS(A2)'],
    seeAlso: ['DOLLAR', 'TO_PURE_NUMBER'],
  );
  b.fn(
    'TO_PERCENT',
    'Converts a provided number to a percentage.',
    [
      P.scalar(
        'value',
        'The argument or reference to a cell to be converted to a percentage. Values that are not numbers are returned unchanged.',
      ),
    ],
    (a) => _withHint(a.scalar(0), FormatHint.percent),
    examples: ['TO_PERCENT(0.25)', 'TO_PERCENT(A2)'],
    seeAlso: ['TO_PURE_NUMBER'],
  );
  b.fn(
    'TO_PURE_NUMBER',
    'Converts a provided date/time, percentage, currency or other formatted numeric value to a pure number without formatting.',
    [
      P.scalar(
        'value',
        'The argument or reference to a cell to be converted to a pure number. Values that are not numbers are returned unchanged.',
      ),
    ],
    (a) => _withHint(a.scalar(0), FormatHint.none),
    examples: ['TO_PURE_NUMBER(50%)', 'TO_PURE_NUMBER(A2)'],
    seeAlso: ['TO_DATE', 'TO_PERCENT', 'TO_DOLLARS', 'TO_TEXT'],
  );
  b.fn(
    'TO_TEXT',
    'Converts a provided numeric value to a text value, as displayed with the source cell\'s number format.',
    [
      P.any(
        'value',
        'The argument or reference to a cell to be converted to text.',
      ),
    ],
    _toText,
    examples: ['TO_TEXT(24)', 'TO_TEXT(A2)'],
    seeAlso: ['TEXT', 'TO_PURE_NUMBER'],
  );
}
