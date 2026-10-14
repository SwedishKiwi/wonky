import 'dart:math' as math;

import '../addressing/grid_geometry.dart';
import '../charts/scene/geometry.dart';
import '../model/axis_index.dart';
import 'anchor.dart';

/// Where new, pasted and inserted objects go (08 §5.2, §9.5, §10.1).
abstract final class ObjectPlacement {
  /// Gap between the data region and a new chart (`dx`, 08 §5.2).
  static const double chartGap = 12;

  /// Inset from the viewport's top-left for the fallback position.
  static const double viewportInset = 24;

  /// Box a new image is scaled down to fit in (08 §10.1).
  static const double imageFitWidth = 600;

  /// Box height for new images.
  static const double imageFitHeight = 400;

  /// The anchor of a new chart for [dataRegion] (08 §5.2): top-left at the
  /// first visible column right of the region, top row of the region, with
  /// `dx = 12`, `dy = 0`.
  ///
  /// When there is no such column, or its left edge is at or past
  /// [viewport]`.right`, the chart goes to the viewport's top-left + 24 px
  /// (sheet origin + 24 px without a viewport). [viewport] is in sheet px at
  /// 100 % zoom. The result is normalized.
  static ObjectAnchor defaultChartAnchor({
    required GridRect dataRegion,
    required AxisIndex rows,
    required AxisIndex columns,
    ChartRect? viewport,
    double width = ObjectAnchor.defaultChartWidth,
    double height = ObjectAnchor.defaultChartHeight,
    int frozenRows = 0,
    int frozenColumns = 0,
  }) {
    final first = dataRegion.right + 1;
    var col = first >= 0 && first < columns.length
        ? columns.nextVisible(first, 1)
        : null;
    // Never anchor inside frozen columns: the chart starts in the scrolling
    // pane (objects anchored in frozen panes stay fixed over the scrolling
    // ones).
    if (col != null && col < frozenColumns) {
      final mainLeft = math.max(
        columns.offsetOf(math.min(frozenColumns, columns.length - 1)),
        viewport?.left ?? 0,
      );
      col = columns.length > frozenColumns
          ? columns.nextVisible(columns.indexAtOffset(mainLeft), 1)
          : null;
    }
    if (col != null) {
      final left = columns.offsetOf(col);
      if (viewport == null || left < viewport.right) {
        final row = dataRegion.top.clamp(0, rows.length - 1);
        var top = rows.offsetOf(row);
        // A data region starting in frozen rows: the chart goes to the top
        // of the scrolling pane's visible area instead.
        if (row < frozenRows && rows.length > frozenRows) {
          top = math.max(rows.offsetOf(frozenRows), viewport?.top ?? 0);
        }
        return ObjectAnchor.normalizeAt(
          left + chartGap,
          top,
          width: width,
          height: height,
          rows: rows,
          columns: columns,
        );
      }
    }
    return ObjectAnchor.normalizeAt(
      (viewport?.left ?? 0) + viewportInset,
      (viewport?.top ?? 0) + viewportInset,
      width: width,
      height: height,
      rows: rows,
      columns: columns,
    );
  }

  /// Default size of a new image: its natural size scaled down to fit in
  /// 600 × 400 px keeping the aspect ratio, never upscaled (08 §10.1), then
  /// kept within 20–4000 px.
  static ChartSize defaultImageSize(
    double naturalWidth,
    double naturalHeight,
  ) => _fit(naturalWidth, naturalHeight, imageFitWidth, imageFitHeight);

  /// Size for *Reset size*: the natural size, capped to 4000 px keeping the
  /// aspect ratio (08 §10.1).
  static ChartSize resetImageSize(double naturalWidth, double naturalHeight) =>
      _fit(
        naturalWidth,
        naturalHeight,
        ObjectAnchor.maxSize,
        ObjectAnchor.maxSize,
      );

  /// Anchor of an image inserted over cells at the active cell ([row],
  /// [col]) with `dx = dy = 0`, default size and `lockAspect: true`.
  static ObjectAnchor imageAnchor({
    required int row,
    required int col,
    required double naturalWidth,
    required double naturalHeight,
    required AxisIndex rows,
    required AxisIndex columns,
  }) {
    final size = defaultImageSize(naturalWidth, naturalHeight);
    return ObjectAnchor.atCell(
      row,
      col,
      width: size.width,
      height: size.height,
      rows: rows,
      columns: columns,
      lockAspect: true,
    );
  }

  /// Anchor of a pasted object: at the active cell ([row], [col]) with
  /// `dx = dy = 0`, keeping the copied size and aspect lock (08 §9.5).
  static ObjectAnchor pasteAnchor({
    required int row,
    required int col,
    required ObjectAnchor copied,
    required AxisIndex rows,
    required AxisIndex columns,
  }) => ObjectAnchor.atCell(
    row,
    col,
    width: copied.width > 0 ? copied.width : ObjectAnchor.defaultChartWidth,
    height: copied.height > 0 ? copied.height : ObjectAnchor.defaultChartHeight,
    rows: rows,
    columns: columns,
    lockAspect: copied.lockAspect,
    extras: copied.extras,
  );

  static ChartSize _fit(double w, double h, double boxW, double boxH) {
    if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
      return const ChartSize(imageFitWidth, imageFitHeight);
    }
    final scale = math.min(1.0, math.min(boxW / w, boxH / h));
    var sw = w * scale;
    var sh = h * scale;
    final smaller = math.min(sw, sh);
    if (smaller < ObjectAnchor.minSize) {
      // Tiny images grow to the minimum size, keeping the ratio when the
      // other side still fits.
      final up = ObjectAnchor.minSize / smaller;
      sw *= up;
      sh *= up;
    }
    return ChartSize(ObjectAnchor.clampSize(sw), ObjectAnchor.clampSize(sh));
  }
}

/// Chart-sheet helpers (08 §11): *Move to own sheet* stores the old anchor in
/// the chart spec so *Move to sheet…* can restore it.
///
/// The anchor is stored under the top-level spec key `previousAnchor`, which
/// `ChartSpec` keeps in its `extras` (unknown keys survive round-trips).
abstract final class ChartSheetAnchors {
  /// Spec key of the stored anchor.
  static const String previousAnchorKey = 'previousAnchor';

  /// A copy of [spec] with [anchor] stored as `previousAnchor`. An
  /// [ObjectAnchor.ownSheet] anchor is not stored (the copy keeps any older
  /// value).
  static Map<String, Object?> withPreviousAnchor(
    Map<dynamic, dynamic> spec,
    ObjectAnchor anchor,
  ) {
    final out = {for (final e in spec.entries) '${e.key}': e.value};
    if (!anchor.ownSheet) out[previousAnchorKey] = anchor.toJson();
    return out;
  }

  /// The stored previous anchor of [spec], or null. Also reads a nested
  /// `extras.previousAnchor`.
  static ObjectAnchor? previousAnchorOf(Map<dynamic, dynamic> spec) {
    var a = ObjectAnchor.tryParse(spec[previousAnchorKey]);
    if (a == null) {
      if (spec['extras'] case final Map<dynamic, dynamic> extras) {
        a = ObjectAnchor.tryParse(extras[previousAnchorKey]);
      }
    }
    return a == null || a.ownSheet ? null : a;
  }

  /// A copy of [spec] without a stored previous anchor.
  static Map<String, Object?> withoutPreviousAnchor(
    Map<dynamic, dynamic> spec,
  ) {
    final out = {for (final e in spec.entries) '${e.key}': e.value}
      ..remove(previousAnchorKey);
    if (out['extras'] case final Map<dynamic, dynamic> extras
        when extras.containsKey(previousAnchorKey)) {
      out['extras'] = {
        for (final e in extras.entries)
          if (e.key != previousAnchorKey) '${e.key}': e.value,
      };
    }
    return out;
  }

  /// The over-grid anchor for *Move to sheet…* onto the sheet with [rows] /
  /// [columns]: the stored previous anchor when it belongs to that sheet
  /// (its row or column exists there; re-normalized and re-anchored if
  /// needed), else A1 with `dx = dy = 0` and the previous (or [current], or
  /// default) size.
  static ObjectAnchor anchorForMoveToSheet({
    required Map<dynamic, dynamic> spec,
    required ObjectAnchor current,
    required AxisIndex rows,
    required AxisIndex columns,
  }) {
    final prev = previousAnchorOf(spec);
    if (prev != null &&
        ((prev.rowId != null && rows.contains(prev.rowId!)) ||
            (prev.colId != null && columns.contains(prev.colId!)))) {
      return prev.normalized(rows, columns);
    }
    final w =
        prev?.width ??
        (current.width > 0 ? current.width : ObjectAnchor.defaultChartWidth);
    final h =
        prev?.height ??
        (current.height > 0 ? current.height : ObjectAnchor.defaultChartHeight);
    return ObjectAnchor.atCell(
      0,
      0,
      width: w,
      height: h,
      rows: rows,
      columns: columns,
      lockAspect: prev?.lockAspect ?? current.lockAspect,
    );
  }
}
