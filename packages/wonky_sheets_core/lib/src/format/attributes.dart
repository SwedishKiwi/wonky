import 'dart:convert';

import '../model/schema.dart';

/// The value type of a [FormatAttr].
enum FormatValueType { string, double, bool, int, hAlign, vAlign, wrap }

/// A cell format attribute (06 §1.1). [column] is the `Cell` column name and the
/// key in row/column/sheet `formatJson`.
enum FormatAttr {
  numberFormat(CellCols.numberFormat, FormatValueType.string),
  fontFamily(CellCols.fontFamily, FormatValueType.string),
  fontSize(CellCols.fontSize, FormatValueType.double),
  bold(CellCols.bold, FormatValueType.bool),
  italic(CellCols.italic, FormatValueType.bool),
  underline(CellCols.underline, FormatValueType.bool),
  strikethrough(CellCols.strikethrough, FormatValueType.bool),
  textColor(CellCols.textColor, FormatValueType.string),
  fillColor(CellCols.fillColor, FormatValueType.string),
  hAlign(CellCols.hAlign, FormatValueType.hAlign),
  vAlign(CellCols.vAlign, FormatValueType.vAlign),
  wrap(CellCols.wrap, FormatValueType.wrap),
  rotation(CellCols.rotation, FormatValueType.int),
  borderTop(CellCols.borderTop, FormatValueType.string),
  borderRight(CellCols.borderRight, FormatValueType.string),
  borderBottom(CellCols.borderBottom, FormatValueType.string),
  borderLeft(CellCols.borderLeft, FormatValueType.string),
  linkUrl(CellCols.linkUrl, FormatValueType.string);

  const FormatAttr(this.column, this.type);

  /// Column / JSON key.
  final String column;

  /// Value type.
  final FormatValueType type;

  /// The four border attributes.
  static const borders = [borderTop, borderRight, borderBottom, borderLeft];

  /// Attributes cleared by *Clear formatting* (all but [linkUrl], 06 §3).
  static final clearable = [
    for (final a in values)
      if (a != linkUrl) a,
  ];

  /// Attributes a conditional format may set (06 §15.4).
  static const conditional = [bold, italic, underline, strikethrough, textColor, fillColor];

  static final Map<String, FormatAttr> _byColumn = {for (final a in values) a.column: a};

  /// Attribute for a column / JSON key, or null.
  static FormatAttr? byColumn(String column) => _byColumn[column];

  /// Normalizes a raw value (JSON or column value) to the canonical Dart type:
  /// `String`, `double`, `bool`, `int` or the align/wrap enums. Returns null for
  /// null or values of the wrong type.
  Object? normalize(Object? v) {
    if (v == null) return null;
    switch (type) {
      case FormatValueType.string:
        return v is String ? v : null;
      case FormatValueType.double:
        return v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
      case FormatValueType.bool:
        return v is bool ? v : (v == 'true' ? true : (v == 'false' ? false : null));
      case FormatValueType.int:
        return v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
      case FormatValueType.hAlign:
        return enumByName(HorizontalAlign.values, v);
      case FormatValueType.vAlign:
        return enumByName(VerticalAlign.values, v);
      case FormatValueType.wrap:
        return enumByName(WrapStrategy.values, v);
    }
  }

  /// Converts a canonical value to its column/JSON representation (enums →
  /// names).
  Object? toColumnValue(Object? v) => v is Enum ? v.name : v;
}

/// An immutable set of explicit format attribute values (null = inherit).
///
/// Instances are interned with [CellFormat.intern] so cells with identical
/// formats share one object (the "format value table" of 02 §6).
final class CellFormat {
  CellFormat._(this._values) : _hash = _computeHash(_values);

  /// Creates a format from attribute → value (null values are dropped).
  factory CellFormat(Map<FormatAttr, Object?> values) {
    final v = List<Object?>.filled(FormatAttr.values.length, null);
    values.forEach((a, x) => v[a.index] = a.normalize(x));
    return CellFormat._(v);
  }

  /// The empty format.
  static final CellFormat empty = CellFormat._(
    List<Object?>.filled(FormatAttr.values.length, null),
  );

  final List<Object?> _values;
  final int _hash;

  static final Map<CellFormat, CellFormat> _pool = {};

  /// Returns the canonical shared instance equal to [f].
  static CellFormat intern(CellFormat f) {
    if (f.isEmpty) return empty;
    final existing = _pool[f];
    if (existing != null) return existing;
    if (_pool.length > 100000) _pool.clear();
    _pool[f] = f;
    return f;
  }

  /// Parses `formatJson` (`{"bold":true,…}`); null/invalid → [empty].
  static CellFormat fromJson(String? json) {
    if (json == null || json.isEmpty) return empty;
    final cached = _jsonCache[json];
    if (cached != null) return cached;
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return empty;
    }
    if (decoded is! Map) return empty;
    final f = fromMap(decoded.cast<String, Object?>());
    if (_jsonCache.length > 10000) _jsonCache.clear();
    _jsonCache[json] = f;
    return f;
  }

  static final Map<String, CellFormat> _jsonCache = {};

  /// From a column-name map (unknown keys ignored).
  static CellFormat fromMap(Map<String, Object?> m) {
    final v = List<Object?>.filled(FormatAttr.values.length, null);
    var any = false;
    m.forEach((k, x) {
      final a = FormatAttr.byColumn(k);
      if (a == null) return;
      final n = a.normalize(x);
      if (n != null) {
        v[a.index] = n;
        any = true;
      }
    });
    return any ? intern(CellFormat._(v)) : empty;
  }

  /// The value of [a] or null (inherit).
  Object? operator [](FormatAttr a) => _values[a.index];

  /// Whether no attribute is set.
  bool get isEmpty => _values.every((x) => x == null);

  /// Whether [a] is set.
  bool has(FormatAttr a) => _values[a.index] != null;

  /// Set attributes.
  Iterable<FormatAttr> get attrs sync* {
    for (final a in FormatAttr.values) {
      if (_values[a.index] != null) yield a;
    }
  }

  /// A copy with [a] set to [value] (null clears).
  CellFormat withValue(FormatAttr a, Object? value) {
    final v = List<Object?>.of(_values);
    v[a.index] = a.normalize(value);
    return intern(CellFormat._(v));
  }

  /// A copy with several values set (null clears).
  CellFormat withValues(Map<FormatAttr, Object?> values) {
    if (values.isEmpty) return this;
    final v = List<Object?>.of(_values);
    values.forEach((a, x) => v[a.index] = a.normalize(x));
    return intern(CellFormat._(v));
  }

  /// A copy without the given attributes.
  CellFormat without(Iterable<FormatAttr> attrs) {
    final v = List<Object?>.of(_values);
    for (final a in attrs) {
      v[a.index] = null;
    }
    return intern(CellFormat._(v));
  }

  /// Values of this format overlaid by the set values of [other].
  CellFormat overlay(CellFormat other) {
    if (other.isEmpty) return this;
    final v = List<Object?>.of(_values);
    for (var i = 0; i < v.length; i++) {
      if (other._values[i] != null) v[i] = other._values[i];
    }
    return intern(CellFormat._(v));
  }

  /// Column-name map of set attributes (enum values as names).
  Map<String, Object?> toMap() => {
    for (final a in attrs) a.column: a.toColumnValue(_values[a.index]),
  };

  /// `formatJson` encoding; null when empty.
  String? toJson() => isEmpty ? null : jsonEncode(toMap());

  static int _computeHash(List<Object?> v) => Object.hashAll(v);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CellFormat || other._hash != _hash) return false;
    for (var i = 0; i < _values.length; i++) {
      if (_values[i] != other._values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _hash;

  @override
  String toString() => 'CellFormat(${toMap()})';
}
