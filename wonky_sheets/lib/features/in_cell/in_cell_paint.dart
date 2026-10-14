import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../theme/sheets_tokens.dart';
import '../grid/paint/grid_layer.dart';
import '../formatting/cell_fonts.dart';
import '../grid/paint/text_layout_cache.dart';

/// Geometry of in-cell widgets (03 §14.1–14.2), shared by painting and
/// hit testing.
abstract final class InCellGeometry {
  /// The checkbox square of a cell (centered, 14 px × zoom).
  static Rect? checkboxBox(Rect cell, double zoom) {
    final s = math.min(14 * zoom, cell.height - 4);
    if (s <= 2) return null;
    return Rect.fromCenter(center: cell.center, width: s, height: s);
  }

  /// Horizontal padding of a chip inside the cell.
  static double inset(double zoom) => 3 * zoom;

  /// Width of the chevron area at the right of a chip / arrow cell.
  static double chevronWidth(double zoom) => 16 * zoom;

  /// The pill of a dropdown chip whose text is [textWidth] wide.
  static Rect chip(Rect cell, double textWidth, double zoom) {
    final h = math.max(4.0, math.min(cell.height - 4 * zoom, 20 * zoom));
    final left = cell.left + inset(zoom);
    final natural = textWidth + 8 * zoom + chevronWidth(zoom);
    final right = math.min(cell.right - inset(zoom), left + natural);
    return Rect.fromLTRB(
      left,
      cell.center.dy - h / 2,
      math.max(left + 8 * zoom, right),
      cell.center.dy + h / 2,
    );
  }

  /// The clickable arrow area of an `arrow`-style dropdown cell.
  static Rect arrow(Rect cell, double zoom) => Rect.fromLTRB(
    cell.right - chevronWidth(zoom) - 2 * zoom,
    cell.top,
    cell.right,
    cell.bottom,
  );
}

/// Text style of a chip's value for a cell font of [fontSize] px (zoomed).
GridTextStyle chipTextStyle(GridTextStyle cell, double zoom, Color color) =>
    GridTextStyle(
      fontFamily: cell.fontFamily,
      fontSize: math.min(cell.fontSize, 13 * zoom),
      color: color,
      bold: cell.bold,
      italic: cell.italic,
      strikethrough: cell.strikethrough,
    );

/// Width of the chip text of [d] (hit testing; same layout as painting).
double chipTextWidth(TextLayoutCache cache, CellDisplay d, double zoom) {
  final f = d.format;
  final style = chipTextStyle(
    GridTextStyle(
      fontFamily: CellFonts.screenFamily(f.fontFamily),
      fontSize: f.fontSize * 4 / 3 * zoom,
      color: const Color(0xFF000000),
      bold: f.bold,
      italic: f.italic,
      strikethrough: f.strikethrough,
    ),
    zoom,
    const Color(0xFF000000),
  );
  return cache.layout(d.text, style).maxIntrinsicWidth;
}

/// Neutral chip colors for items without a color (theme aware).
({Color bg, Color fg}) neutralChipColors(GridPaintTokens tokens) =>
    tokens.isDark
    ? (bg: const Color(0xFF3C4043), fg: const Color(0xFFE8EAED))
    : (bg: const Color(0xFFE8EAED), fg: const Color(0xFF3C4043));

/// Paints a dropdown chip (03 §14.2): a rounded pill in the option's colors
/// with the value and a chevron inside, ellipsized to the cell.
void paintDropdownChip(
  GridPaintContext ctx,
  Canvas canvas,
  Rect cell,
  CellDisplay d,
  String text,
  GridTextStyle style,
) {
  final z = ctx.zoom;
  final tokens = ctx.tokens;
  final neutral = neutralChipColors(tokens);
  final bg = hexToColor(d.widget.chipFill) ?? neutral.bg;
  final fg =
      hexToColor(d.widget.chipText) ??
      (d.widget.chipFill == null ? neutral.fg : style.color);
  final chipStyle = chipTextStyle(style, z, fg);
  final p = ctx.text.layout(text, chipStyle);
  final pill = InCellGeometry.chip(cell, p.maxIntrinsicWidth, z);
  canvas.save();
  canvas.clipRect(cell);
  canvas.drawRRect(
    RRect.fromRectAndRadius(pill, Radius.circular(pill.height / 2)),
    Paint()..color = bg,
  );
  final textLeft = pill.left + 8 * z;
  final textRight = pill.right - InCellGeometry.chevronWidth(z);
  canvas.save();
  canvas.clipRect(Rect.fromLTRB(textLeft, pill.top, textRight, pill.bottom));
  canvas.drawParagraph(p, Offset(textLeft, pill.center.dy - p.height / 2));
  canvas.restore();
  _chevron(canvas, Offset(pill.right - 8 * z, pill.center.dy), z, fg);
  canvas.restore();
}

void _chevron(Canvas canvas, Offset c, double z, Color color) {
  final path = Path()
    ..moveTo(c.dx - 3.5 * z, c.dy - 1.5 * z)
    ..lineTo(c.dx + 3.5 * z, c.dy - 1.5 * z)
    ..lineTo(c.dx, c.dy + 2.5 * z)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}
