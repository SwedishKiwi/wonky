import 'dart:typed_data';

import '../../content/cell_content.dart';

/// Sort ordering of Google Sheets (07 §2.3), stable when combined with the
/// original index:
///
/// 1. numbers (dates/times included) ascending;
/// 2. text by a collation key (NFKD-like decomposition, combining marks
///    stripped, simple case folding), then the original string ordinal;
/// 3. booleans FALSE < TRUE;
/// 4. errors by `ERROR.TYPE` code;
/// 5. blanks (and `""`) always last, in both directions.
///
/// Descending reverses groups 1–4.
abstract final class SortKeys {
  /// Type groups.
  static const int number = 0;
  static const int text = 1;
  static const int boolean = 2;
  static const int error = 3;
  static const int blank = 4;

  /// The type group of [v].
  static int groupOf(CellValue v) => switch (v) {
    NumberValue() => number,
    TextValue(:final text) => text.isEmpty ? blank : SortKeys.text,
    BoolValue() => boolean,
    ErrorValue() => error,
    EmptyValue() => blank,
  };

  /// Compares two values; blanks sort last regardless of [ascending].
  static int compare(CellValue a, CellValue b, {bool ascending = true}) {
    final ga = groupOf(a);
    final gb = groupOf(b);
    if (ga == blank || gb == blank) {
      if (ga == gb) return 0;
      return ga == blank ? 1 : -1;
    }
    int c;
    if (ga != gb) {
      c = ga < gb ? -1 : 1;
    } else {
      switch (a) {
        case NumberValue(:final number):
          c = number.compareTo((b as NumberValue).number);
        case TextValue(text: final x):
          c = compareText(x, (b as TextValue).text);
        case BoolValue(:final value):
          final w = (b as BoolValue).value;
          c = value == w ? 0 : (value ? 1 : -1);
        case ErrorValue(:final kind):
          c = kind.code.compareTo((b as ErrorValue).kind.code);
        case EmptyValue():
          c = 0;
      }
    }
    return ascending ? c : -c;
  }

  /// Text comparison: collation key, then ordinal.
  static int compareText(String a, String b) {
    if (identical(a, b) || a == b) return 0;
    final c = collationKey(a).compareTo(collationKey(b));
    return c != 0 ? c : a.compareTo(b);
  }

  static final Map<String, String> _keyCache = {};

  /// The deterministic collation key of [s] (cached for repeated values).
  static String collationKey(String s) {
    final cached = _keyCache[s];
    if (cached != null) return cached;
    final k = _computeKey(s);
    if (_keyCache.length > 50000) _keyCache.clear();
    _keyCache[s] = k;
    return k;
  }

  static String _computeKey(String s) {
    var ascii = true;
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) >= 0x80) {
        ascii = false;
        break;
      }
    }
    if (ascii) return s.toLowerCase();
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      if (r >= 0x300 && r <= 0x36f) continue; // combining diacritical marks
      if (r >= 0x1ab0 && r <= 0x1aff) continue;
      if (r >= 0x1dc0 && r <= 0x1dff) continue;
      if (r >= 0x20d0 && r <= 0x20ff) continue;
      if (r >= 0xfe20 && r <= 0xfe2f) continue;
      final m = _fold[r];
      if (m != null) {
        b.write(m);
      } else if (r >= 0xff01 && r <= 0xff5e) {
        b.writeCharCode(r - 0xfee0); // fullwidth ASCII (compatibility decomposition)
      } else if (r == 0x3000) {
        b.write(' ');
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static final Map<int, String> _fold = () {
    final m = <int, String>{};
    void add(String from, String to) {
      final f = from.runes.toList();
      for (var i = 0; i < f.length; i++) {
        m[f[i]] = to;
      }
    }

    add('àáâãäåāăąǎǟǡǻȁȃȧạảấầẩẫậắằẳẵặ', 'a');
    add('æǣǽ', 'ae');
    add('çćĉċč', 'c');
    add('ďđ', 'd');
    add('èéêëēĕėęěȅȇȩẹẻẽếềểễệ', 'e');
    add('ĝğġģǧǵ', 'g');
    add('ĥħ', 'h');
    add('ìíîïĩīĭįıǐȉȋịỉ', 'i');
    add('ĳ', 'ij');
    add('ĵǰ', 'j');
    add('ķǩ', 'k');
    add('ĺļľŀł', 'l');
    add('ñńņňŉǹ', 'n');
    add('òóôõöøōŏőơǒǫǭǿȍȏȫȭȯȱọỏốồổỗộớờởỡợ', 'o');
    add('œ', 'oe');
    add('ŕŗřȑȓ', 'r');
    add('śŝşšșſ', 's');
    add('ß', 'ss');
    add('ţťŧț', 't');
    add('þ', 'th');
    add('ùúûüũūŭůűųưǔǖǘǚǜȕȗụủứừửữự', 'u');
    add('ŵẁẃẅ', 'w');
    add('ýÿŷỳỵỷỹ', 'y');
    add('źżžƶ', 'z');
    add('ﬀ', 'ff');
    add('ﬁ', 'fi');
    add('ﬂ', 'fl');
    add('ﬃ', 'ffi');
    add('ﬄ', 'ffl');
    add('ά', 'α');
    add('έ', 'ε');
    add('ή', 'η');
    add('ίϊΐ', 'ι');
    add('ό', 'ο');
    add('ύϋΰ', 'υ');
    add('ώ', 'ω');
    add('ς', 'σ');
    add('ё', 'е');
    add('й', 'и');
    return m;
  }();
}

/// A typed snapshot of one sort key column (07 §2.7 step 1): per row the
/// group, a number (numbers, booleans 0/1, error codes) and the text.
final class SortKeyColumn {
  /// Builds the snapshot from values (one per row).
  factory SortKeyColumn.fromValues(List<CellValue> values) {
    final n = values.length;
    final groups = Uint8List(n);
    final numbers = Float64List(n);
    final texts = List<String?>.filled(n, null);
    final keys = List<String?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final g = SortKeys.groupOf(v);
      groups[i] = g;
      switch (v) {
        case NumberValue(:final number):
          numbers[i] = number;
        case BoolValue(:final value):
          numbers[i] = value ? 1 : 0;
        case ErrorValue(:final kind):
          numbers[i] = kind.code.toDouble();
        case TextValue(:final text):
          if (g == SortKeys.text) {
            texts[i] = text;
            keys[i] = SortKeys.collationKey(text);
          }
        case EmptyValue():
          break;
      }
    }
    return SortKeyColumn._(groups, numbers, texts, keys);
  }

  SortKeyColumn._(this.groups, this.numbers, this.texts, this._keys);

  /// Type group per row ([SortKeys.number] …).
  final Uint8List groups;

  /// Numeric key per row.
  final Float64List numbers;

  /// Text per row (text group only).
  final List<String?> texts;
  final List<String?> _keys;

  /// Number of rows.
  int get length => groups.length;

  /// Compares rows [i] and [j] (blanks last in both directions).
  int compare(int i, int j, {bool ascending = true}) {
    final ga = groups[i];
    final gb = groups[j];
    if (ga == SortKeys.blank || gb == SortKeys.blank) {
      if (ga == gb) return 0;
      return ga == SortKeys.blank ? 1 : -1;
    }
    int c;
    if (ga != gb) {
      c = ga < gb ? -1 : 1;
    } else if (ga == SortKeys.text) {
      c = _keys[i]!.compareTo(_keys[j]!);
      if (c == 0) c = texts[i]!.compareTo(texts[j]!);
    } else {
      c = numbers[i].compareTo(numbers[j]);
    }
    return ascending ? c : -c;
  }
}
