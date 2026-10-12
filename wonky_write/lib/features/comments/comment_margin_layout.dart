import 'package:flutter/foundation.dart';

/// One card of the comment margin (a comment thread or a suggestion).
@immutable
class MarginItem {
  const MarginItem({
    required this.id,
    required this.anchorTop,
    required this.anchorOffset,
    required this.height,
    this.createdAt = 0,
  });

  final String id;

  /// Top of the anchor's first line box, in margin coordinates.
  final double anchorTop;

  /// Delta offset of the anchor (tie-breaker).
  final int anchorOffset;

  /// Measured (or estimated) card height.
  final double height;

  /// Creation time (second tie-breaker).
  final int createdAt;
}

/// The comment margin layout (Write 08 §3.2): cards keep document order, never
/// overlap, and the active card aligns with its anchor, pushing earlier cards
/// up and later cards down.
abstract final class CommentMarginLayout {
  /// Estimated height of a card before it is measured.
  static const estimatedHeight = 76.0;

  /// The top of every card, by id.
  static Map<String, double> layout(
    List<MarginItem> items, {
    String? activeId,
    double gap = 8,
    double minY = 0,
  }) {
    if (items.isEmpty) return const {};
    final sorted = [...items]
      ..sort((a, b) {
        final c = a.anchorTop.compareTo(b.anchorTop);
        if (c != 0) return c;
        final o = a.anchorOffset.compareTo(b.anchorOffset);
        if (o != 0) return o;
        return a.createdAt.compareTo(b.createdAt);
      });
    final n = sorted.length;
    final y = List<double>.filled(n, 0);
    void forward(int from) {
      for (var i = from; i < n; i++) {
        final prev = y[i - 1] + sorted[i - 1].height + gap;
        y[i] = sorted[i].anchorTop > prev ? sorted[i].anchorTop : prev;
      }
    }

    final a = activeId == null
        ? -1
        : sorted.indexWhere((item) => item.id == activeId);
    if (a < 0) {
      y[0] = sorted[0].anchorTop > minY ? sorted[0].anchorTop : minY;
      forward(1);
    } else {
      y[a] = sorted[a].anchorTop;
      forward(a + 1);
      for (var i = a - 1; i >= 0; i--) {
        final limit = y[i + 1] - gap - sorted[i].height;
        y[i] = sorted[i].anchorTop < limit ? sorted[i].anchorTop : limit;
      }
      if (y[0] < minY) {
        y[0] = minY;
        forward(1);
      }
    }
    return {for (var i = 0; i < n; i++) sorted[i].id: y[i]};
  }
}
