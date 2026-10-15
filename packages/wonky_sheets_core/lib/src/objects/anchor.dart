import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:wonky_sync_models/ids.dart';
import 'package:wonky_charts/wonky_charts.dart';

import '../model/axis_index.dart';
import 'object_geometry.dart';

/// Position and size of an embedded object (`EmbeddedObject.anchorJson`,
/// Sheets 08 §1.2).
///
/// Over-grid objects are anchored to a cell by row/column **id** plus a px
/// offset inside that cell, so they move with the cell when rows or columns are
/// inserted, deleted, resized or reordered. Objects on a chart sheet use an
/// [ownSheet] anchor without a cell.
///
/// Ids are canonical UUID strings in memory and 22-char base-62 strings in
/// JSON. All px values are at 100 % zoom. Unknown JSON keys are kept in
/// [extras] and written back unchanged.
final class ObjectAnchor {
  /// Creates an over-grid anchor (no validation; use [normalizeAt] or
  /// [normalized] before writing).
  const ObjectAnchor({
    this.v = currentVersion,
    this.rowId,
    this.colId,
    this.rowKey,
    this.colKey,
    this.dx = 0,
    this.dy = 0,
    this.width = defaultChartWidth,
    this.height = defaultChartHeight,
    this.lockAspect = false,
    this.ownSheet = false,
    this.extras = const {},
  });

  /// The anchor of an object on a chart sheet: `{"v":1,"ownSheet":true}`.
  ///
  /// [width]/[height] (0 = unknown) and [lockAspect] are only written when
  /// set; a chart sheet keeps the stored aspect ratio only if [lockAspect].
  const ObjectAnchor.ownSheetAnchor({
    this.width = 0,
    this.height = 0,
    this.lockAspect = false,
    this.extras = const {},
  }) : v = currentVersion,
       rowId = null,
       colId = null,
       rowKey = null,
       colKey = null,
       dx = 0,
       dy = 0,
       ownSheet = true;

  /// Anchor schema version written by this code.
  static const int currentVersion = 1;

  /// Minimum object width/height in px (08 §9.3).
  static const double minSize = 20;

  /// Maximum object width/height in px (08 §9.3).
  static const double maxSize = 4000;

  /// Default chart width (08 §5.2, golden ratio).
  static const double defaultChartWidth = 600;

  /// Default chart height.
  static const double defaultChartHeight = 371;

  /// Offset of a duplicate (`Mod+D`) in px on both axes (08 §9.5).
  static const double duplicateOffset = 16;

  /// Arrow-key nudge in px (08 §9.3).
  static const double nudgeStep = 1;

  /// Shift+arrow nudge in px.
  static const double nudgeLargeStep = 10;

  /// JSON keys this class understands; everything else goes to [extras].
  static const Set<String> knownKeys = {
    'v',
    'rowId',
    'colId',
    'rk',
    'ck',
    'dx',
    'dy',
    'width',
    'height',
    'lockAspect',
    'ownSheet',
  };

  /// Schema version (`v`).
  final int v;

  /// Anchor row id (canonical UUID); null for [ownSheet] anchors.
  final String? rowId;

  /// Anchor column id (canonical UUID); null for [ownSheet] anchors.
  final String? colId;

  /// SortKey of the anchor row when last normalized (`rk`); used to re-anchor
  /// deterministically after the row was deleted.
  final String? rowKey;

  /// SortKey of the anchor column when last normalized (`ck`).
  final String? colKey;

  /// Offset from the anchor cell's left edge (px, ≥ 0).
  final double dx;

  /// Offset from the anchor cell's top edge (px, ≥ 0).
  final double dy;

  /// Width in px (20–4000 for over-grid objects).
  final double width;

  /// Height in px (20–4000 for over-grid objects).
  final double height;

  /// Whether resizing keeps the aspect ratio by default (images: true).
  final bool lockAspect;

  /// Whether the object fills a chart sheet (no cell anchor).
  final bool ownSheet;

  /// Unknown JSON keys, preserved on round-trip.
  final Map<String, Object?> extras;

  // ---------------------------------------------------------------------------
  // JSON.

  /// Parses a JSON string or map; null when it is not a valid anchor.
  static ObjectAnchor? tryParse(Object? jsonOrString) {
    Object? value = jsonOrString;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is! Map) return null;
    try {
      return ObjectAnchor.fromJson(value);
    } on FormatException {
      return null;
    }
  }

  /// Parses a JSON map. Ids may be base-62 or canonical UUIDs. Offsets are
  /// clamped to ≥ 0 and over-grid sizes to [minSize]..[maxSize].
  ///
  /// Throws a [FormatException] when an over-grid anchor has no row or column
  /// id.
  factory ObjectAnchor.fromJson(Map<dynamic, dynamic> json) {
    final extras = <String, Object?>{
      for (final e in json.entries)
        if (!knownKeys.contains(e.key)) '${e.key}': _copyJson(e.value),
    };
    final version = switch (json['v']) {
      final num n when n.isFinite => n.toInt(),
      _ => currentVersion,
    };
    final lock = json['lockAspect'] == true;
    if (json['ownSheet'] == true) {
      return ObjectAnchor(
        v: version,
        width: math.max(0, _num(json['width']) ?? 0),
        height: math.max(0, _num(json['height']) ?? 0),
        lockAspect: lock,
        ownSheet: true,
        extras: extras,
      );
    }
    final rowId = _decodeId(json['rowId']);
    final colId = _decodeId(json['colId']);
    if (rowId == null || colId == null) {
      throw FormatException('Object anchor without rowId/colId', json);
    }
    return ObjectAnchor(
      v: version,
      rowId: rowId,
      colId: colId,
      rowKey: _str(json['rk']),
      colKey: _str(json['ck']),
      dx: math.max(0, _num(json['dx']) ?? 0),
      dy: math.max(0, _num(json['dy']) ?? 0),
      width: clampSize(_num(json['width']) ?? defaultChartWidth),
      height: clampSize(_num(json['height']) ?? defaultChartHeight),
      lockAspect: lock,
      extras: extras,
    );
  }

  /// JSON map (ids as 22-char base-62, known keys first, then [extras]).
  Map<String, Object?> toJson() {
    final m = <String, Object?>{'v': v};
    if (ownSheet) {
      m['ownSheet'] = true;
      if (width > 0) m['width'] = width;
      if (height > 0) m['height'] = height;
      if (lockAspect) m['lockAspect'] = true;
    } else {
      if (rowId != null) m['rowId'] = _encodeId(rowId!);
      if (colId != null) m['colId'] = _encodeId(colId!);
      if (rowKey != null) m['rk'] = rowKey;
      if (colKey != null) m['ck'] = colKey;
      m['dx'] = dx;
      m['dy'] = dy;
      m['width'] = width;
      m['height'] = height;
      m['lockAspect'] = lockAspect;
    }
    for (final e in extras.entries) {
      if (!knownKeys.contains(e.key)) m[e.key] = _copyJson(e.value);
    }
    return m;
  }

  /// JSON string for the `anchorJson` column.
  String encode() => jsonEncode(toJson());

  /// Copy with the given fields replaced.
  ObjectAnchor copyWith({
    int? v,
    String? rowId,
    String? colId,
    String? rowKey,
    String? colKey,
    double? dx,
    double? dy,
    double? width,
    double? height,
    bool? lockAspect,
    bool? ownSheet,
    Map<String, Object?>? extras,
  }) => ObjectAnchor(
    v: v ?? this.v,
    rowId: rowId ?? this.rowId,
    colId: colId ?? this.colId,
    rowKey: rowKey ?? this.rowKey,
    colKey: colKey ?? this.colKey,
    dx: dx ?? this.dx,
    dy: dy ?? this.dy,
    width: width ?? this.width,
    height: height ?? this.height,
    lockAspect: lockAspect ?? this.lockAspect,
    ownSheet: ownSheet ?? this.ownSheet,
    extras: extras ?? this.extras,
  );

  /// The chart-sheet anchor for this object (08 §11), keeping size, aspect
  /// lock and extras.
  ObjectAnchor toOwnSheet() => ObjectAnchor.ownSheetAnchor(
    width: width,
    height: height,
    lockAspect: lockAspect,
    extras: extras,
  );

  /// Size clamped to [minSize]..[maxSize] (NaN → [minSize]).
  static double clampSize(double px) {
    if (px.isNaN) return minSize;
    return px < minSize ? minSize : (px > maxSize ? maxSize : px);
  }

  // ---------------------------------------------------------------------------
  // Geometry.

  /// The object's rectangle in sheet px at 100 % zoom; null for [ownSheet]
  /// anchors or when the anchor row/column does not exist.
  ///
  /// The top-left is the anchor cell's top-left plus the offsets, capped to
  /// the cell's size, so an object anchored in a hidden row/column sits at the
  /// collapsed edge.
  ChartRect? rectIn(AxisIndex rows, AxisIndex columns) {
    if (ownSheet) return null;
    final r = rowId == null ? -1 : rows.indexOf(rowId!);
    final c = colId == null ? -1 : columns.indexOf(colId!);
    if (r < 0 || c < 0) return null;
    final left = columns.offsetOf(c) + math.min(dx, columns.sizeAt(c));
    final top = rows.offsetOf(r) + math.min(dy, rows.sizeAt(r));
    return ChartRect(left, top, width, height);
  }

  /// A normalized anchor for an object whose top-left is at ([x], [y]) sheet
  /// px (08 §1.2): the visible cell containing the point, and the offset
  /// inside it. Negative coordinates clamp to 0, points past the last
  /// row/column anchor to it; sizes are clamped to [minSize]..[maxSize].
  ///
  /// Throws an [ArgumentError] when [rows] or [columns] is empty.
  static ObjectAnchor normalizeAt(
    double x,
    double y, {
    required double width,
    required double height,
    required AxisIndex rows,
    required AxisIndex columns,
    bool lockAspect = false,
    int v = currentVersion,
    Map<String, Object?> extras = const {},
  }) {
    if (rows.length == 0 || columns.length == 0) {
      throw ArgumentError(
        'Cannot anchor an object on a sheet without rows or columns',
      );
    }
    final (c, ox) = _locate(columns, x);
    final (r, oy) = _locate(rows, y);
    return ObjectAnchor(
      v: v,
      rowId: rows.idAt(r),
      colId: columns.idAt(c),
      rowKey: rows.sortKeyAt(r),
      colKey: columns.sortKeyAt(c),
      dx: ox,
      dy: oy,
      width: clampSize(width),
      height: clampSize(height),
      lockAspect: lockAspect,
      extras: extras,
    );
  }

  /// An anchor at cell ([row], [col]) with offsets [dx]/[dy] (paste at the
  /// active cell uses 0/0, 08 §9.5). Indices are clamped to the axes. Offsets
  /// that don't fit the cell are normalized to the cell containing the point.
  static ObjectAnchor atCell(
    int row,
    int col, {
    required double width,
    required double height,
    required AxisIndex rows,
    required AxisIndex columns,
    double dx = 0,
    double dy = 0,
    bool lockAspect = false,
    int v = currentVersion,
    Map<String, Object?> extras = const {},
  }) {
    if (rows.length == 0 || columns.length == 0) {
      throw ArgumentError(
        'Cannot anchor an object on a sheet without rows or columns',
      );
    }
    final r = row.clamp(0, rows.length - 1);
    final c = col.clamp(0, columns.length - 1);
    final ox = dx.isNaN || dx < 0 ? 0.0 : dx;
    final oy = dy.isNaN || dy < 0 ? 0.0 : dy;
    final fits =
        (ox == 0 || ox < columns.sizeAt(c)) && (oy == 0 || oy < rows.sizeAt(r));
    if (!fits) {
      return normalizeAt(
        columns.offsetOf(c) + ox,
        rows.offsetOf(r) + oy,
        width: width,
        height: height,
        rows: rows,
        columns: columns,
        lockAspect: lockAspect,
        v: v,
        extras: extras,
      );
    }
    return ObjectAnchor(
      v: v,
      rowId: rows.idAt(r),
      colId: columns.idAt(c),
      rowKey: rows.sortKeyAt(r),
      colKey: columns.sortKeyAt(c),
      dx: ox,
      dy: oy,
      width: clampSize(width),
      height: clampSize(height),
      lockAspect: lockAspect,
      extras: extras,
    );
  }

  /// This anchor re-normalized against the current axes: re-anchored when
  /// its row/column was deleted, moved to the cell that contains the
  /// top-left point when the offsets no longer fit (e.g. after a column was
  /// narrowed or the anchor was hidden), with fresh sortKey hints and clamped
  /// sizes. An anchor that already fits keeps its ids and offsets exactly.
  ObjectAnchor normalized(AxisIndex rows, AxisIndex columns) {
    if (ownSheet) return this;
    final base = reanchor(rows, columns) ?? this;
    final r = base.rowId == null ? -1 : rows.indexOf(base.rowId!);
    final c = base.colId == null ? -1 : columns.indexOf(base.colId!);
    if (r < 0 || c < 0) return base;
    if (base.dx >= 0 &&
        base.dx < columns.sizeAt(c) &&
        base.dy >= 0 &&
        base.dy < rows.sizeAt(r)) {
      return ObjectAnchor(
        v: v,
        rowId: base.rowId,
        colId: base.colId,
        rowKey: rows.sortKeyAt(r),
        colKey: columns.sortKeyAt(c),
        dx: base.dx,
        dy: base.dy,
        width: clampSize(width),
        height: clampSize(height),
        lockAspect: lockAspect,
        extras: extras,
      );
    }
    final rect = base.rectIn(rows, columns)!;
    return _at(rect.left, rect.top, width, height, rows, columns);
  }

  /// The re-anchored anchor after its row or column was deleted (08 §1.2,
  /// A-08-4), or null when no maintenance is needed (both exist, an
  /// [ownSheet] anchor, or an empty sheet).
  ///
  /// A missing row moves to the next surviving row by `(sortKey, id)` (found
  /// through the [rowKey] hint), else the previous one (it was the last); the
  /// same for columns. Without a hint it falls back to index 0. Offsets reset
  /// to 0. Hidden state is ignored, so concurrent fixers write identical
  /// anchors.
  ObjectAnchor? reanchor(AxisIndex rows, AxisIndex columns) {
    if (ownSheet || rows.length == 0 || columns.length == 0) return null;
    final r0 = rowId == null ? -1 : rows.indexOf(rowId!);
    final c0 = colId == null ? -1 : columns.indexOf(colId!);
    if (r0 >= 0 && c0 >= 0) return null;
    final r = r0 >= 0 ? r0 : _survivor(rows, rowId, rowKey);
    final c = c0 >= 0 ? c0 : _survivor(columns, colId, colKey);
    return ObjectAnchor(
      v: v,
      rowId: rows.idAt(r),
      colId: columns.idAt(c),
      rowKey: rows.sortKeyAt(r),
      colKey: columns.sortKeyAt(c),
      width: clampSize(width),
      height: clampSize(height),
      lockAspect: lockAspect,
      extras: extras,
    );
  }

  // ---------------------------------------------------------------------------
  // Move, resize, nudge (08 §9.3).

  /// Moved by ([ddx], [ddy]) px and normalized.
  ObjectAnchor moveBy(
    double ddx,
    double ddy,
    AxisIndex rows,
    AxisIndex columns,
  ) {
    if (ownSheet) return this;
    final rect = _currentRect(rows, columns);
    return _at(rect.left + ddx, rect.top + ddy, width, height, rows, columns);
  }

  /// Moved to cell ([row], [col]) with offsets [dx]/[dy] (see [atCell]).
  ObjectAnchor moveToCell(
    int row,
    int col,
    AxisIndex rows,
    AxisIndex columns, {
    double dx = 0,
    double dy = 0,
  }) {
    if (ownSheet) return this;
    return atCell(
      row,
      col,
      width: width,
      height: height,
      rows: rows,
      columns: columns,
      dx: dx,
      dy: dy,
      lockAspect: lockAspect,
      v: v,
      extras: extras,
    );
  }

  /// Arrow-key nudge: [stepsX]/[stepsY] steps of [nudgeStep] px, or of
  /// [nudgeLargeStep] px when [large] (Shift).
  ObjectAnchor nudge(
    int stepsX,
    int stepsY,
    AxisIndex rows,
    AxisIndex columns, {
    bool large = false,
  }) {
    final step = large ? nudgeLargeStep : nudgeStep;
    return moveBy(stepsX * step, stepsY * step, rows, columns);
  }

  /// Alt+arrow nudge: moves the anchor by [dRow] rows and [dCol] columns,
  /// skipping hidden ones and stopping at the sheet edges. The offsets are
  /// kept when they fit the new cell, else reset to 0.
  ObjectAnchor nudgeByCells(
    int dRow,
    int dCol,
    AxisIndex rows,
    AxisIndex columns,
  ) {
    if (ownSheet || rows.length == 0 || columns.length == 0) return this;
    final base = normalized(rows, columns);
    final r = _stepVisible(rows, rows.indexOf(base.rowId!), dRow);
    final c = _stepVisible(columns, columns.indexOf(base.colId!), dCol);
    final ox = base.dx < columns.sizeAt(c) ? base.dx : 0.0;
    final oy = base.dy < rows.sizeAt(r) ? base.dy : 0.0;
    return ObjectAnchor(
      v: v,
      rowId: rows.idAt(r),
      colId: columns.idAt(c),
      rowKey: rows.sortKeyAt(r),
      colKey: columns.sortKeyAt(c),
      dx: ox,
      dy: oy,
      width: base.width,
      height: base.height,
      lockAspect: lockAspect,
      extras: extras,
    );
  }

  /// Resized to [width] × [height] (top-left unchanged), clamped to
  /// [minSize]..[maxSize]. With [keepAspect] (default: [lockAspect]) the
  /// current aspect ratio is kept, following the dimension that grows the box
  /// most.
  ObjectAnchor resized(double width, double height, {bool? keepAspect}) {
    final keep = keepAspect ?? lockAspect;
    final size = ObjectGeometry.constrainSize(
      width,
      height,
      aspect: keep && this.width > 0 && this.height > 0
          ? this.width / this.height
          : null,
    );
    return copyWith(width: size.width, height: size.height);
  }

  /// Resized by dragging [handle] by ([ddx], [ddy]) px (the opposite edge or
  /// corner stays fixed), normalized. [keepAspect] (default: [lockAspect])
  /// applies to corner handles only.
  ObjectAnchor resizeByHandle(
    ResizeHandle handle,
    double ddx,
    double ddy,
    AxisIndex rows,
    AxisIndex columns, {
    bool? keepAspect,
  }) {
    if (ownSheet) {
      return resized(width + ddx, height + ddy, keepAspect: keepAspect);
    }
    final rect = ObjectGeometry.resizeRect(
      _currentRect(rows, columns),
      handle,
      ddx,
      ddy,
      keepAspect: keepAspect ?? lockAspect,
    );
    return withRect(rect, rows, columns);
  }

  /// The normalized anchor for an object occupying [rect] (e.g. the dropped
  /// ghost of a drag), keeping [lockAspect], [v] and [extras].
  ObjectAnchor withRect(ChartRect rect, AxisIndex rows, AxisIndex columns) =>
      _at(rect.left, rect.top, rect.width, rect.height, rows, columns);

  /// The anchor of a duplicate (`Mod+D`): offset by (+16, +16) px (08 §9.5).
  ObjectAnchor duplicated(AxisIndex rows, AxisIndex columns) =>
      moveBy(duplicateOffset, duplicateOffset, rows, columns);

  // ---------------------------------------------------------------------------
  // Internals.

  ObjectAnchor _at(
    double x,
    double y,
    double w,
    double h,
    AxisIndex rows,
    AxisIndex columns,
  ) => normalizeAt(
    x,
    y,
    width: w,
    height: h,
    rows: rows,
    columns: columns,
    lockAspect: lockAspect,
    v: v,
    extras: extras,
  );

  ChartRect _currentRect(AxisIndex rows, AxisIndex columns) =>
      (reanchor(rows, columns) ?? this).rectIn(rows, columns) ??
      ChartRect(0, 0, width, height);

  static (int, double) _locate(AxisIndex axis, double px) {
    final p = px.isNaN || px <= 0 ? 0.0 : (px.isFinite ? px : axis.totalSize);
    final i = axis.indexAtOffset(p);
    final size = axis.sizeAt(i);
    final off = p - axis.offsetOf(i);
    return (i, off < 0 ? 0.0 : (off > size ? size : off));
  }

  static int _survivor(AxisIndex axis, String? id, String? key) {
    if (key == null) return 0;
    final i = axis.insertionIndex(key, id ?? '');
    return i < axis.length ? i : axis.length - 1;
  }

  static int _stepVisible(AxisIndex axis, int from, int steps) {
    var i = from;
    final dir = steps.sign;
    for (var k = 0; k < steps.abs(); k++) {
      final next = axis.nextVisible(i + dir, dir);
      if (next == null) break;
      i = next;
    }
    return i;
  }

  static double? _num(Object? v) =>
      v is num && v.isFinite ? v.toDouble() : null;

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  static String? _decodeId(Object? v) {
    if (v is! String || v.isEmpty) return null;
    if (v.length == Base62Uuid.length && Base62Uuid.isValid(v)) {
      return Base62Uuid.decode(v);
    }
    return v.length == 36 ? v.toLowerCase() : v;
  }

  static String _encodeId(String id) {
    if (id.length != 36) return id;
    try {
      return Base62Uuid.encode(id);
    } on FormatException {
      return id;
    }
  }

  static Object? _copyJson(Object? v) {
    if (v is Map) {
      return {for (final e in v.entries) '${e.key}': _copyJson(e.value)};
    }
    if (v is List) return [for (final x in v) _copyJson(x)];
    return v;
  }

  static const _deep = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      other is ObjectAnchor &&
      other.v == v &&
      other.rowId == rowId &&
      other.colId == colId &&
      other.rowKey == rowKey &&
      other.colKey == colKey &&
      other.dx == dx &&
      other.dy == dy &&
      other.width == width &&
      other.height == height &&
      other.lockAspect == lockAspect &&
      other.ownSheet == ownSheet &&
      _deep.equals(other.extras, extras);

  @override
  int get hashCode => Object.hash(
    v,
    rowId,
    colId,
    rowKey,
    colKey,
    dx,
    dy,
    width,
    height,
    lockAspect,
    ownSheet,
    _deep.hash(extras),
  );

  @override
  String toString() => 'ObjectAnchor(${encode()})';
}
