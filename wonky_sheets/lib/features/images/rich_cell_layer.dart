import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_sheets_core/formula.dart'
    show FRich, ImageValue, SparklineValue;
import 'package:wonky_sheets_core/model.dart';

import '../charts/render/chart_painter.dart';
import '../grid/paint/grid_layer.dart';
import '../grid/viewport/grid_geometry.dart';
import 'image_service.dart';

/// In-cell renderers (08 §2 sparklines, §10.2 images; 03 §14.10): paints
/// `SPARKLINE()` and `IMAGE()` results inside their cells, above the cell
/// content and below conditional formats and borders.
class RichCellLayer extends GridLayer {
  RichCellLayer(this.images);

  final SheetsImageService images;

  @override
  int get zOrder => GridZ.cells + 10;

  @override
  Listenable? get repaint => images.loaded;

  /// Inner padding of in-cell renderers at 100 % zoom.
  static const double pad = 2;

  final LinkedHashMap<(SparklineValue, double, double, bool), ChartScene>
  _scenes = LinkedHashMap();

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    final sheet = ctx.sheet;
    if (sheet.cells.contentCount == 0) return;
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      _paintPane(ctx, canvas, pane);
    });
  }

  void _paintPane(GridPaintContext ctx, Canvas canvas, GridPane pane) {
    final sheet = ctx.sheet;
    final rows = sheet.rows;
    final cols = sheet.columns;
    final engine = ctx.controller.engine;
    for (var r = pane.rowStart; r <= pane.rowEnd; r++) {
      if (rows.sizeAt(r) <= 0) continue;
      final rowId = rows.idAt(r);
      if (sheet.cells.rowCount(rowId) == 0) continue;
      for (final cell in sheet.cells.inRow(rowId)) {
        final content = cell.content;
        if (content == null || !content.startsWith('=')) continue;
        final c = cols.indexOf(cell.columnId);
        if (c < pane.colStart || c > pane.colEnd || cols.sizeAt(c) <= 0) {
          continue;
        }
        final v = engine.valueAt(sheet.id, r, c);
        if (v is! FRich) continue;
        final merge = sheet.mergeAt(r, c);
        final rect = merge == null
            ? pane.cellRect(r, c)
            : pane.rangeRect(merge);
        if (rect.width <= 0 || rect.height <= 0) continue;
        switch (v.payload) {
          case SparklineValue sp:
            _sparkline(ctx, canvas, rect, sp);
          case ImageValue img:
            _image(ctx, canvas, rect, img);
        }
      }
    }
  }

  void _sparkline(
    GridPaintContext ctx,
    Canvas canvas,
    Rect rect,
    SparklineValue v,
  ) {
    final z = ctx.zoom;
    final w = rect.width / z;
    final h = rect.height / z;
    final dark = ctx.tokens.isDark;
    final key = (v, w, h, dark);
    var scene = _scenes.remove(key);
    scene ??= SparklineRenderer.layoutValue(
      v,
      w,
      h,
      defaultColor: dark ? 0xFF8AB4F8 : 0xFF4285F4,
      padding: pad + 1,
    );
    _scenes[key] = scene;
    if (_scenes.length > 400) _scenes.remove(_scenes.keys.first);
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(rect.left, rect.top);
    canvas.scale(z);
    paintChartScene(canvas, scene);
    canvas.restore();
  }

  void _image(GridPaintContext ctx, Canvas canvas, Rect rect, ImageValue v) {
    final z = ctx.zoom;
    final inner = rect.deflate(pad * z);
    if (inner.isEmpty) return;
    final img = images.decoded(v.url);
    if (img == null) {
      canvas.drawRect(
        inner,
        Paint()..color = ctx.tokens.gridLine.withValues(alpha: 0.5),
      );
      return;
    }
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final dst = imageCellRect(
      inner,
      Size(src.width, src.height),
      mode: v.mode,
      width: v.width,
      height: v.height,
      zoom: z,
    );
    canvas.save();
    canvas.clipRect(inner);
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
    canvas.restore();
  }
}

/// Where an `IMAGE()` result of [natural] size goes inside [cell] (08
/// §10.2): mode 1 fits (keeps the aspect ratio, centered), 2 stretches, 3
/// original size, 4 custom [width] × [height] px (top-left aligned).
Rect imageCellRect(
  Rect cell,
  Size natural, {
  int mode = 1,
  double? width,
  double? height,
  double zoom = 1,
}) {
  switch (mode) {
    case 2:
      return cell;
    case 3:
      return Rect.fromLTWH(
        cell.left,
        cell.top,
        natural.width * zoom,
        natural.height * zoom,
      );
    case 4:
      return Rect.fromLTWH(
        cell.left,
        cell.top,
        (width ?? natural.width) * zoom,
        (height ?? natural.height) * zoom,
      );
    default:
      if (natural.width <= 0 || natural.height <= 0) return cell;
      final s = math.min(
        cell.width / natural.width,
        cell.height / natural.height,
      );
      final w = natural.width * s;
      final h = natural.height * s;
      return Rect.fromLTWH(
        cell.left + (cell.width - w) / 2,
        cell.top + (cell.height - h) / 2,
        w,
        h,
      );
  }
}
