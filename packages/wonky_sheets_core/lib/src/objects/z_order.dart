import '../charts/scene/geometry.dart';
import '../model/sheet_model.dart';
import 'anchor.dart';

/// One object as seen by z-order operations.
final class ZOrderItem {
  /// Creates an item.
  const ZOrderItem(this.id, this.zIndex, this.rect);

  /// Object id.
  final String id;

  /// Stored `zIndex`.
  final int zIndex;

  /// Object rectangle (sheet px), used for the overlap test.
  final ChartRect rect;

  @override
  bool operator ==(Object other) =>
      other is ZOrderItem &&
      other.id == id &&
      other.zIndex == zIndex &&
      other.rect == rect;

  @override
  int get hashCode => Object.hash(id, zIndex, rect);

  @override
  String toString() => 'ZOrderItem($id, $zIndex, $rect)';
}

/// Z-order of the objects on one sheet (08 §9.4). Higher `zIndex` draws on
/// top; ties sort by object id.
///
/// The operations return the new `zIndex` of the objects that change only
/// (empty when nothing changes).
abstract final class ZOrder {
  /// Items of [sheet]; objects without a resolvable rectangle (chart-sheet
  /// or broken anchors) get an empty rectangle and overlap nothing.
  static List<ZOrderItem> itemsOf(SheetModel sheet) => [
    for (final o in sheet.objects.values)
      ZOrderItem(
        o.id,
        o.zIndex,
        ObjectAnchor.tryParse(
              o.anchorJson,
            )?.rectIn(sheet.rows, sheet.columns) ??
            ChartRect.zero,
      ),
  ];

  /// Paint order comparison (bottom first).
  static int compare(ZOrderItem a, ZOrderItem b) {
    final c = a.zIndex.compareTo(b.zIndex);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  /// Items in paint order, bottom first.
  static List<ZOrderItem> sorted(Iterable<ZOrderItem> items) =>
      [...items]..sort(compare);

  /// *Bring to front*: `max + 1` (nothing when already on top).
  static Map<String, int> bringToFront(Iterable<ZOrderItem> items, String id) {
    final s = sorted(items);
    final i = s.indexWhere((e) => e.id == id);
    if (i < 0 || i == s.length - 1) return const {};
    return {id: s.last.zIndex + 1};
  }

  /// *Send to back*: `min − 1` (nothing when already at the bottom).
  static Map<String, int> sendToBack(Iterable<ZOrderItem> items, String id) {
    final s = sorted(items);
    final i = s.indexWhere((e) => e.id == id);
    if (i <= 0) return const {};
    return {id: s.first.zIndex - 1};
  }

  /// *Bring forward*: swaps with the next object above that overlaps it.
  static Map<String, int> bringForward(Iterable<ZOrderItem> items, String id) {
    final s = sorted(items);
    final i = s.indexWhere((e) => e.id == id);
    if (i < 0) return const {};
    for (var j = i + 1; j < s.length; j++) {
      if (s[j].rect.overlaps(s[i].rect)) {
        return _swap(s, i, j, raiseLower: true);
      }
    }
    return const {};
  }

  /// *Send backward*: swaps with the next object below that overlaps it.
  static Map<String, int> sendBackward(Iterable<ZOrderItem> items, String id) {
    final s = sorted(items);
    final i = s.indexWhere((e) => e.id == id);
    if (i < 0) return const {};
    for (var j = i - 1; j >= 0; j--) {
      if (s[j].rect.overlaps(s[i].rect)) {
        return _swap(s, j, i, raiseLower: false);
      }
    }
    return const {};
  }

  /// The object selected by *Select next object* after [currentId]: z-order
  /// top first, wrapping; the top object when nothing (or an unknown id) is
  /// selected. Null without objects.
  static String? selectNext(Iterable<ZOrderItem> items, String? currentId) =>
      _cycle(items, currentId, 1);

  /// *Select previous object*: backwards through [selectNext]'s order; the
  /// bottom object when nothing is selected.
  static String? selectPrevious(
    Iterable<ZOrderItem> items,
    String? currentId,
  ) => _cycle(items, currentId, -1);

  static String? _cycle(
    Iterable<ZOrderItem> items,
    String? currentId,
    int dir,
  ) {
    final topFirst = sorted(items).reversed.toList();
    if (topFirst.isEmpty) return null;
    final i = currentId == null
        ? -1
        : topFirst.indexWhere((e) => e.id == currentId);
    if (i < 0) return dir > 0 ? topFirst.first.id : topFirst.last.id;
    return topFirst[(i + dir) % topFirst.length].id;
  }

  /// Swaps the paint positions of `s[lo]` and `s[hi]` (lo < hi). Tries the
  /// plain value swap first, then (for equal values) a ±1 step of the moving
  /// object, and falls back to renumbering densely when ties with other
  /// objects make the cheap writes ambiguous.
  static Map<String, int> _swap(
    List<ZOrderItem> s,
    int lo,
    int hi, {
    required bool raiseLower,
  }) {
    final a = s[lo];
    final b = s[hi];
    final desired = [for (final e in s) e.id];
    desired[lo] = b.id;
    desired[hi] = a.id;
    final candidates = <Map<String, int>>[
      if (a.zIndex != b.zIndex)
        {a.id: b.zIndex, b.id: a.zIndex}
      else if (raiseLower)
        {a.id: a.zIndex + 1}
      else
        {b.id: b.zIndex - 1},
    ];
    for (final c in candidates) {
      if (_orderMatches(s, c, desired)) return c;
    }
    final out = <String, int>{};
    final base = s.first.zIndex;
    final byId = {for (final e in s) e.id: e};
    for (var k = 0; k < desired.length; k++) {
      if (byId[desired[k]]!.zIndex != base + k) out[desired[k]] = base + k;
    }
    return out;
  }

  static bool _orderMatches(
    List<ZOrderItem> s,
    Map<String, int> changes,
    List<String> desired,
  ) {
    final next = sorted([
      for (final e in s) ZOrderItem(e.id, changes[e.id] ?? e.zIndex, e.rect),
    ]);
    for (var k = 0; k < desired.length; k++) {
      if (next[k].id != desired[k]) return false;
    }
    return true;
  }
}
