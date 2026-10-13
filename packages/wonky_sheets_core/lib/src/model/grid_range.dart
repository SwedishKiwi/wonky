import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:wonky_sync_models/ids.dart';

import '../addressing/grid_geometry.dart';

/// An id-based range (02 §2 GridRange JSON, 05 §24 F1):
/// `{"s":"<sheetId>","r1":"<rowId>","r2":"<rowId>","c1":"<colId>","c2":"<colId>"}`
/// with any bound optional (unbounded), plus optional sortKey hints `r1k`,
/// `r2k`, `c1k`, `c2k` used to resolve deleted endpoints deterministically.
final class GridRange {
  /// Creates a range.
  const GridRange({
    required this.sheetId,
    this.r1,
    this.r2,
    this.c1,
    this.c2,
    this.r1k,
    this.r2k,
    this.c1k,
    this.c2k,
  });

  /// The whole sheet.
  const GridRange.sheet(this.sheetId)
    : r1 = null,
      r2 = null,
      c1 = null,
      c2 = null,
      r1k = null,
      r2k = null,
      c1k = null,
      c2k = null;

  final String sheetId;
  final String? r1;
  final String? r2;
  final String? c1;
  final String? c2;
  final String? r1k;
  final String? r2k;
  final String? c1k;
  final String? c2k;

  /// Whether no row bound is set (whole columns).
  bool get unboundedRows => r1 == null && r2 == null;

  /// Whether no column bound is set (whole rows).
  bool get unboundedColumns => c1 == null && c2 == null;

  /// Whether all four bounds are set.
  bool get isBounded => r1 != null && r2 != null && c1 != null && c2 != null;

  /// Parses JSON (map or string). Ids may be canonical UUIDs or 22-char base-62.
  static GridRange? tryParse(Object? json) {
    Object? m = json;
    if (m is String) {
      if (m.isEmpty) return null;
      try {
        m = jsonDecode(m);
      } on FormatException {
        return null;
      }
    }
    if (m is! Map) return null;
    final s = m['s'];
    if (s is! String) return null;
    String? id(String k) {
      final v = m as Map;
      final x = v[k];
      if (x is! String || x.isEmpty) return null;
      return _decodeId(x);
    }

    String? key(String k) {
      final x = (m as Map)[k];
      return x is String && x.isNotEmpty ? x : null;
    }

    return GridRange(
      sheetId: _decodeId(s),
      r1: id('r1'),
      r2: id('r2'),
      c1: id('c1'),
      c2: id('c2'),
      r1k: key('r1k'),
      r2k: key('r2k'),
      c1k: key('c1k'),
      c2k: key('c2k'),
    );
  }

  /// Parses a JSON list of ranges (`rangesJson`); invalid entries are skipped.
  static List<GridRange> parseList(String? json) {
    if (json == null || json.isEmpty) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (tryParse(e) case final GridRange r) r,
    ];
  }

  /// Encodes a list (`rangesJson`).
  static String encodeList(Iterable<GridRange> ranges) =>
      jsonEncode([for (final r in ranges) r.toJson()]);

  static String _decodeId(String x) {
    if (x.length == Base62Uuid.length &&
        !x.contains('-') &&
        Base62Uuid.isValid(x)) {
      return Base62Uuid.decode(x);
    }
    return x;
  }

  /// JSON map (canonical UUID ids, null bounds omitted).
  Map<String, Object?> toJson() => {
    's': sheetId,
    if (r1 != null) 'r1': r1,
    if (r2 != null) 'r2': r2,
    if (c1 != null) 'c1': c1,
    if (c2 != null) 'c2': c2,
    if (r1k != null) 'r1k': r1k,
    if (r2k != null) 'r2k': r2k,
    if (c1k != null) 'c1k': c1k,
    if (c2k != null) 'c2k': c2k,
  };

  /// JSON string.
  String encode() => jsonEncode(toJson());

  /// A copy with replaced bounds. Pass [clear] keys (`'r1'`, …) to unset.
  GridRange copyWith({
    String? sheetId,
    String? r1,
    String? r2,
    String? c1,
    String? c2,
    String? r1k,
    String? r2k,
    String? c1k,
    String? c2k,
  }) => GridRange(
    sheetId: sheetId ?? this.sheetId,
    r1: r1 ?? this.r1,
    r2: r2 ?? this.r2,
    c1: c1 ?? this.c1,
    c2: c2 ?? this.c2,
    r1k: r1k ?? this.r1k,
    r2k: r2k ?? this.r2k,
    c1k: c1k ?? this.c1k,
    c2k: c2k ?? this.c2k,
  );

  /// All ids referenced (sheet, rows, columns).
  Iterable<String> get ids => [sheetId, ?r1, ?r2, ?c1, ?c2];

  @override
  bool operator ==(Object other) =>
      other is GridRange &&
      other.sheetId == sheetId &&
      other.r1 == r1 &&
      other.r2 == r2 &&
      other.c1 == c1 &&
      other.c2 == c2;

  @override
  int get hashCode => Object.hash(sheetId, r1, r2, c1, c2);

  @override
  String toString() => 'GridRange(${encode()})';
}

/// A range resolved to current indices.
final class ResolvedRange {
  /// Creates a resolved range.
  const ResolvedRange(
    this.sheetId,
    this.rect, {
    this.wholeRows = false,
    this.wholeColumns = false,
  });

  /// The sheet.
  final String sheetId;

  /// Inclusive index rectangle.
  final GridRect rect;

  /// Whether the range spans all columns (whole rows, `1:3`).
  final bool wholeRows;

  /// Whether the range spans all rows (whole columns, `A:C`).
  final bool wholeColumns;

  /// Whether the range is the whole sheet.
  bool get wholeSheet => wholeRows && wholeColumns;

  @override
  bool operator ==(Object other) =>
      other is ResolvedRange &&
      other.sheetId == sheetId &&
      other.rect == rect &&
      other.wholeRows == wholeRows &&
      other.wholeColumns == wholeColumns;

  @override
  int get hashCode => Object.hash(sheetId, rect, wholeRows, wholeColumns);

  @override
  String toString() => 'ResolvedRange($sheetId, ${rect.a1})';
}

/// Set operations on index rectangles (DV overlap subtraction 07 §6.4).
abstract final class RectSet {
  /// `a − b`, split into at most 4 rectangles.
  static List<GridRect> subtract(GridRect a, GridRect b) {
    final i = a.intersection(b);
    if (i == null) return [a];
    final out = <GridRect>[];
    if (i.top > a.top) out.add(GridRect(a.top, a.left, i.top - 1, a.right));
    if (i.bottom < a.bottom) {
      out.add(GridRect(i.bottom + 1, a.left, a.bottom, a.right));
    }
    if (i.left > a.left) out.add(GridRect(i.top, a.left, i.bottom, i.left - 1));
    if (i.right < a.right) {
      out.add(GridRect(i.top, i.right + 1, i.bottom, a.right));
    }
    return out;
  }

  /// `rects − b` for every rectangle.
  static List<GridRect> subtractAll(Iterable<GridRect> rects, GridRect b) => [
    for (final r in rects) ...subtract(r, b),
  ];

  /// Whether the rectangles cover the same cells (order-insensitive equality
  /// after normalization).
  static bool sameCells(List<GridRect> a, List<GridRect> b) {
    int area(List<GridRect> l) => l.fold(0, (s, r) => s + r.cellCount);
    if (area(a) != area(b)) return false;
    for (final r in a) {
      var covered = 0;
      for (final q in b) {
        covered += r.intersection(q)?.cellCount ?? 0;
      }
      if (covered != r.cellCount) return false;
    }
    return true;
  }

  /// Bounding box of [rects] or null.
  static GridRect? bounds(Iterable<GridRect> rects) {
    GridRect? b;
    for (final r in rects) {
      b = b == null
          ? r
          : GridRect(
              r.top < b.top ? r.top : b.top,
              r.left < b.left ? r.left : b.left,
              r.bottom > b.bottom ? r.bottom : b.bottom,
              r.right > b.right ? r.right : b.right,
            );
    }
    return b;
  }

  static const _eq = ListEquality<GridRect>();

  /// List equality.
  static bool equals(List<GridRect> a, List<GridRect> b) => _eq.equals(a, b);
}
