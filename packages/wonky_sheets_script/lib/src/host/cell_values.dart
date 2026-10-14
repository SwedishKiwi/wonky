import 'package:wonky_sheets_core/wonky_sheets_core.dart';

import '../protocol/values.dart';

/// Converts values between the workbook and scripts (09 §6 "Cell values
/// crossing the API").
///
/// Dates are instants: a script `DateTime` is written as the serial of its
/// wall time in the spreadsheet time zone, and date-formatted cells are read
/// back as `DateTime` instants (Apps Script parity).
final class CellValueConverter {
  /// Creates a converter for the spreadsheet time zone [timeZone].
  CellValueConverter({
    required this.timeZone,
    this.timeZones = const TzDatabaseResolver(),
  });

  /// IANA time zone of the spreadsheet.
  final String timeZone;

  /// Offset lookup.
  final TimeZoneResolver timeZones;

  /// Serial (days since 1899-12-30, wall time in [timeZone]) of [instant].
  double serialOf(DateTime instant) {
    final utc = instant.toUtc();
    final wall = utc.add(timeZones.offsetAt(timeZone, utc));
    return DateSerial.fromUnixMillis(wall.millisecondsSinceEpoch);
  }

  /// Instant of the wall-time [serial] in [timeZone].
  DateTime instantOf(double serial) {
    final wallMs = DateSerial.toUnixMillis(serial);
    final guess = DateTime.fromMillisecondsSinceEpoch(wallMs, isUtc: true);
    var offset = timeZones.offsetAt(timeZone, guess);
    // One correction step for offsets that differ across the guess.
    final corrected = guess.subtract(offset);
    offset = timeZones.offsetAt(timeZone, corrected);
    return DateTime.fromMillisecondsSinceEpoch(wallMs - offset.inMilliseconds);
  }

  /// Script value of a computed formula value. [isDate] marks cells with a
  /// date/time number format.
  Object? toScript(FValue value, {bool isDate = false}) {
    switch (value) {
      case FNumber(:final v):
        if (isDate && v.isFinite) return instantOf(v);
        if (v.isFinite && v == v.truncateToDouble() && v.abs() < 9e15) {
          return v.toInt();
        }
        return v;
      case FText(:final v):
        return v;
      case FBool(:final v):
        return v;
      case FError(:final kind, :final message, :final pending):
        if (pending) return const CellError('#LOADING', 'Loading…');
        return CellError(kind.literal, message);
      case FArray():
        return toScript(value.topLeft, isDate: isDate);
      case FRich(:final scalar):
        return toScript(scalar, isDate: isDate);
      case FEmpty() || FOmitted():
        return null;
      default:
        return CellError(ErrorKind.value.literal);
    }
  }

  /// Formula value of a script value (custom function arguments/results).
  FValue toFormula(Object? value) {
    switch (value) {
      case null:
        return FEmpty.instance;
      case bool b:
        return FBool(b);
      case num n:
        return FNumber(n.toDouble());
      case String s:
        return FText(s);
      case DateTime d:
        return FNumber(serialOf(d), FormatHint.dateTime);
      case CellError e:
        if (e.code == '#LOADING') return const FError.pending();
        return FError(
          ErrorKind.fromLiteral(e.code) ?? ErrorKind.value,
          e.message,
        );
      case List<Object?> rows:
        if (rows.isEmpty) return FEmpty.instance;
        if (rows.first is! List) {
          // A 1-D list is one row (09 §8.6).
          return FArray(1, rows.length, [for (final v in rows) toFormula(v)]);
        }
        final width = rows.fold<int>(
          0,
          (w, r) => r is List && r.length > w ? r.length : w,
        );
        if (width == 0) return FEmpty.instance;
        final cells = <FValue>[];
        for (final r in rows) {
          final row = r is List ? r : [r];
          for (var c = 0; c < width; c++) {
            cells.add(c < row.length ? toFormula(row[c]) : FEmpty.instance);
          }
        }
        return FArray(rows.length, width, cells);
      default:
        return FError(ErrorKind.value, 'Unsupported return value');
    }
  }

  /// Script value of a custom function argument: scalars, or row-major 2-D
  /// lists for ranges (09 §8.6 step 4).
  Object? argToScript(FValue value) {
    if (value is FArray) {
      return [
        for (var r = 0; r < value.rows; r++)
          [for (var c = 0; c < value.cols; c++) toScript(value.at(r, c))],
      ];
    }
    if (value is FOmitted) return null;
    return toScript(value, isDate: value is FNumber && _isDateHint(value.hint));
  }

  static bool _isDateHint(FormatHint hint) =>
      hint == FormatHint.date ||
      hint == FormatHint.dateTime ||
      hint == FormatHint.time;

  /// Cell input for a script value written with `values` (09 §6: strings
  /// starting with `=` are formulas unless [raw]).
  CellInput toInput(Object? value, {required bool raw}) {
    switch (value) {
      case null:
        return const CellInput.raw(null);
      case String s:
        if (raw) return CellInput.content(s.isEmpty ? null : TextContent(s));
        return CellInput.user(s);
      case bool b:
        return CellInput.raw(b);
      case num n:
        if (n is double && !n.isFinite) {
          return const CellInput.content(ErrorContent(CellErrorKind.num));
        }
        return CellInput.raw(n);
      case DateTime d:
        return CellInput.content(NumberContent(serialOf(d)));
      case CellError e:
        final kind = CellErrorKind.tryParse(e.code) ?? CellErrorKind.value;
        return CellInput.content(ErrorContent(kind));
      default:
        throw ArgumentError('Unsupported cell value: ${value.runtimeType}');
    }
  }
}

/// Whether a number format pattern shows a date or time (`yyyy-mm-dd`,
/// `h:mm`, `preset:date`, …). Durations (`[h]:mm:ss`) are numbers.
bool isDateTimeFormat(String? pattern) {
  if (pattern == null || pattern.isEmpty) return false;
  if (pattern.startsWith('preset:')) {
    final p = pattern.substring(7);
    return p == 'date' || p == 'time' || p == 'dateTime';
  }
  var inQuote = false;
  var inBracket = false;
  var hasDate = false;
  for (var i = 0; i < pattern.length; i++) {
    final ch = pattern[i];
    if (ch == '"') {
      inQuote = !inQuote;
      continue;
    }
    if (inQuote) continue;
    if (ch == '\\') {
      i++;
      continue;
    }
    if (ch == '[') {
      // `[h]`, `[mm]` elapsed time → duration; `[$€]`, `[Red]` → ignored.
      final end = pattern.indexOf(']', i);
      final inner = end < 0 ? '' : pattern.substring(i + 1, end).toLowerCase();
      if (inner == 'h' ||
          inner == 'hh' ||
          inner == 'm' ||
          inner == 'mm' ||
          inner == 's' ||
          inner == 'ss') {
        return false;
      }
      inBracket = true;
      continue;
    }
    if (ch == ']') {
      inBracket = false;
      continue;
    }
    if (inBracket) continue;
    final lower = ch.toLowerCase();
    if (lower == 'y' || lower == 'd' || lower == 'h' || lower == 's') {
      hasDate = true;
    }
    if (lower == 'm' &&
        (_near(pattern, i, 'h') ||
            _near(pattern, i, 'y') ||
            _near(pattern, i, 'd') ||
            _near(pattern, i, 's'))) {
      hasDate = true;
    }
  }
  return hasDate;
}

bool _near(String p, int i, String ch) {
  final lower = p.toLowerCase();
  final from = i - 4 < 0 ? 0 : i - 4;
  final to = i + 5 > p.length ? p.length : i + 5;
  return lower.substring(from, to).contains(ch);
}
