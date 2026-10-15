import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:wonky_slides_core/ops.dart';

import '../navigator/navigator_model.dart';

/// One laid-out item of the grid view (content coordinates): a group's
/// section header, a slide tile or an empty group's drop zone.
final class GridItem {
  const GridItem(this.row, this.rect, {this.line = 0});

  final NavRow row;
  final Rect rect;

  /// The visual line (tiles of one line share it; headers have their own).
  final int line;
}

/// The light table's geometry (Slides 04 §9): sections in presentation
/// order — a group's header spanning the row, then its slides (or its drop
/// zone) flowing in lines of [columns]; runs of top-level slides form
/// untitled sections. Pure, so hit tests and drop indicators are testable.
final class GridLayout {
  GridLayout._(this.items, this.height, this.columns, this.tileWidth);

  /// Lays out [rows] (`buildNavRows`) in [width] with tiles [tileWidth]
  /// wide and slides of [aspect] (height / width).
  factory GridLayout.of(
    List<NavRow> rows, {
    required double width,
    required double tileWidth,
    required double aspect,
    double padding = 24,
    double gap = 16,
    double headerHeight = 40,
    double labelHeight = 22,
    double emptyHeight = 56,
  }) {
    final usable = math.max(tileWidth, width - 2 * padding);
    final columns = math.max(1, ((usable + gap) / (tileWidth + gap)).floor());
    final tileHeight = tileWidth * aspect + labelHeight;
    final items = <GridItem>[];
    var y = padding;
    var col = 0;
    var line = 0;
    var inTiles = false;
    String? section;

    void endTiles() {
      if (!inTiles) return;
      y += tileHeight + gap;
      col = 0;
      line++;
      inTiles = false;
    }

    for (final r in rows) {
      switch (r.kind) {
        case NavRowKind.group:
          endTiles();
          if (items.isNotEmpty) y += 4;
          items.add(
            GridItem(
              r,
              Rect.fromLTWH(padding, y, usable, headerHeight),
              line: line++,
            ),
          );
          y += headerHeight + 6;
          section = r.id;
        case NavRowKind.emptyGroup:
          endTiles();
          items.add(
            GridItem(
              r,
              Rect.fromLTWH(padding, y, usable, emptyHeight),
              line: line++,
            ),
          );
          y += emptyHeight + gap;
        case NavRowKind.slide:
          final s = r.groupId;
          if (s != section) {
            // A run of top-level slides after a group starts a new section.
            endTiles();
            section = s;
          }
          if (inTiles && col == columns) {
            y += tileHeight + gap;
            col = 0;
            line++;
          }
          inTiles = true;
          items.add(
            GridItem(
              r,
              Rect.fromLTWH(
                padding + col * (tileWidth + gap),
                y,
                tileWidth,
                tileHeight,
              ),
              line: line,
            ),
          );
          col++;
      }
    }
    endTiles();
    return GridLayout._(items, y + padding - gap, columns, tileWidth);
  }

  final List<GridItem> items;

  /// Total content height.
  final double height;
  final int columns;
  final double tileWidth;

  /// The item at [x], [y] (content coordinates), or null.
  GridItem? itemAt(double x, double y) {
    for (final i in items) {
      if (i.rect.contains(Offset(x, y))) return i;
    }
    return null;
  }

  /// The item in the line above/below [from] closest in x (2D arrows).
  GridItem? vertical(GridItem from, {required bool down}) {
    final lines = <int>{for (final i in items) i.line}.toList()..sort();
    final at = lines.indexOf(from.line);
    final next = at + (down ? 1 : -1);
    if (at < 0 || next < 0 || next >= lines.length) return null;
    final candidates = [
      for (final i in items)
        if (i.line == lines[next] && i.row.kind != NavRowKind.emptyGroup) i,
    ];
    if (candidates.isEmpty) {
      final skip = GridItem(from.row, from.rect, line: lines[next]);
      return vertical(skip, down: down);
    }
    final cx = from.rect.center.dx;
    candidates.sort(
      (a, b) => (a.rect.center.dx - cx).abs().compareTo(
        (b.rect.center.dx - cx).abs(),
      ),
    );
    return candidates.first;
  }
}

/// A grid drop (04 §9): the [target], a vertical bar between tiles
/// ([barX], [barTop]…[barBottom]) or a highlighted header / zone, and
/// whether it is [refused] (groups can't be nested).
final class GridDrop {
  const GridDrop({
    required this.target,
    this.barX,
    this.barTop = 0,
    this.barBottom = 0,
    this.highlightGroupId,
    this.refused = false,
  });

  final SlideTarget target;
  final double? barX;
  final double barTop;
  final double barBottom;
  final String? highlightGroupId;
  final bool refused;
}

/// Resolves a drop over the grid: on a slide tile the gap left or right of
/// it in its key space; on a section header (slides) or an empty zone an
/// append to that group; a dragged group drops before/after a group's
/// header (top/bottom half) or a top-level tile, never inside a group.
/// Below everything: the end of the deck.
GridDrop resolveGridDrop(
  GridLayout layout,
  double x,
  double y, {
  required bool draggingGroups,
}) {
  GridDrop gap(GridItem tile, {required bool after}) {
    final r = tile.row;
    final g = r.groupId;
    final SlideTarget t = g == null
        ? (after ? TopLevel(afterId: r.id) : TopLevel(beforeId: r.id))
        : (after ? InGroup(g, afterId: r.id) : InGroup(g, beforeId: r.id));
    return GridDrop(
      target: t,
      barX: after ? tile.rect.right + 8 : tile.rect.left - 8,
      barTop: tile.rect.top,
      barBottom: tile.rect.bottom,
      refused: t is InGroup && draggingGroups,
    );
  }

  final hit = layout.itemAt(x, y);
  if (hit != null) {
    switch (hit.row.kind) {
      case NavRowKind.group:
        if (draggingGroups) {
          final after = y > hit.rect.center.dy;
          return GridDrop(
            target: after
                ? TopLevel(afterId: hit.row.id)
                : TopLevel(beforeId: hit.row.id),
            barX: hit.rect.left - 8,
            barTop: hit.rect.top,
            barBottom: hit.rect.bottom,
          );
        }
        return GridDrop(
          target: InGroup(hit.row.id),
          highlightGroupId: hit.row.id,
        );
      case NavRowKind.emptyGroup:
        return GridDrop(
          target: InGroup(hit.row.id),
          highlightGroupId: hit.row.id,
          refused: draggingGroups,
        );
      case NavRowKind.slide:
        return gap(hit, after: x > hit.rect.center.dx);
    }
  }
  // Between items: the nearest tile of the line at y, else the end.
  GridItem? best;
  var bestD = double.infinity;
  for (final i in layout.items) {
    if (i.row.kind != NavRowKind.slide) continue;
    if (y < i.rect.top - 16 || y > i.rect.bottom + 16) continue;
    final d = (i.rect.center.dx - x).abs();
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  if (best != null) return gap(best, after: x > best.rect.center.dx);
  return const GridDrop(target: TopLevel());
}
