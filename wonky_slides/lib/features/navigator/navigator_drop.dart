import 'package:wonky_slides_core/ops.dart';

import 'navigator_model.dart';

/// A laid-out navigator row (content coordinates, px).
typedef NavRowBox = ({NavRow row, double top, double height});

/// Where a drag over the navigator would drop (04 §5.10): the order
/// [target], the indicator line at [y] (indented when [inside] a group, in
/// the group's color) or the highlighted group header / empty zone
/// [highlightGroupId], and whether the drop is [refused] (groups can't be
/// nested).
final class NavDrop {
  const NavDrop({
    required this.target,
    required this.y,
    this.inside = false,
    this.groupId,
    this.highlightGroupId,
    this.refused = false,
  });

  final SlideTarget target;

  /// The indicator's y (content coordinates).
  final double y;

  /// Whether the indicator is indented (a position inside [groupId]).
  final bool inside;

  /// The group of an inside position (indicator color).
  final String? groupId;

  /// The header or empty zone highlighted instead of a line (append).
  final String? highlightGroupId;

  /// Groups dropped inside a group: shown red, not dropped.
  final bool refused;

  @override
  String toString() =>
      'NavDrop(${_describe(target)}, y: $y, inside: $inside'
      '${highlightGroupId == null ? '' : ', append: $highlightGroupId'}'
      '${refused ? ', refused' : ''})';

  static String _describe(SlideTarget t) => switch (t) {
    TopLevel(:final beforeId, :final afterId) =>
      'top(before: $beforeId, after: $afterId)',
    InGroup(:final groupId, :final beforeId, :final afterId) =>
      'in $groupId(before: $beforeId, after: $afterId)',
  };
}

/// Resolves the drop position of a pointer over the navigator rows (04
/// §5.10):
///
/// - on a slide row: the gap above (upper half) or below (lower half);
/// - on a group header: its middle 50 % appends to the group (highlighted),
///   the upper/lower quarters drop at the top level before/after the
///   group; an empty group's zone appends;
/// - the gap below the last row of an expanded group is decided by x:
///   ≥ [indentX] inside the group (end), else the top level after it;
/// - a gap above a group's slide is inside that group.
///
/// [draggingGroups]: inside positions are [NavDrop.refused].
NavDrop resolveNavDrop(
  List<NavRowBox> rows,
  double x,
  double y, {
  required bool draggingGroups,
  double indentX = 24,
}) {
  NavDrop drop(SlideTarget t, double at, {String? highlight}) {
    final inside = t is InGroup;
    return NavDrop(
      target: t,
      y: at,
      inside: inside && highlight == null,
      groupId: t is InGroup ? t.groupId : null,
      highlightGroupId: highlight,
      refused: inside && draggingGroups,
    );
  }

  if (rows.isEmpty) return drop(const TopLevel(), 0);

  NavDrop gap(NavRowBox? a, NavRowBox? b) {
    final ar = a?.row;
    final br = b?.row;
    if (a != null && ar!.lastInGroup) {
      final g = ar.groupId!;
      final at = a.top + a.height;
      if (x >= indentX) {
        return drop(ar.isSlide ? InGroup(g, afterId: ar.id) : InGroup(g), at);
      }
      return drop(TopLevel(afterId: g), at);
    }
    if (b != null && br!.inGroup) {
      return drop(InGroup(br.groupId!, beforeId: br.id), b.top);
    }
    if (b != null) return drop(TopLevel(beforeId: br!.id), b.top);
    return drop(TopLevel(afterId: ar!.id), a!.top + a.height);
  }

  /// The bottom of [g]'s last row (where "after the group" draws).
  double groupBottom(String g, int from) {
    var bottom = rows[from].top + rows[from].height;
    for (var j = from + 1; j < rows.length; j++) {
      final r = rows[j].row;
      if (r.kind == NavRowKind.group || r.groupId != g) break;
      bottom = rows[j].top + rows[j].height;
    }
    return bottom;
  }

  if (y < rows.first.top) return gap(null, rows.first);
  for (var i = 0; i < rows.length; i++) {
    final box = rows[i];
    if (y >= box.top + box.height) continue;
    final frac = box.height <= 0 ? 0.5 : (y - box.top) / box.height;
    final prev = i > 0 ? rows[i - 1] : null;
    final next = i + 1 < rows.length ? rows[i + 1] : null;
    switch (box.row.kind) {
      case NavRowKind.group:
        final g = box.row.id;
        if (frac < 0.25) return gap(prev, box);
        if (frac > 0.75) {
          return drop(TopLevel(afterId: g), groupBottom(g, i));
        }
        return drop(InGroup(g), box.top + box.height / 2, highlight: g);
      case NavRowKind.emptyGroup:
        return drop(
          InGroup(box.row.id),
          box.top + box.height / 2,
          highlight: box.row.id,
        );
      case NavRowKind.slide:
        return frac < 0.5 ? gap(prev, box) : gap(box, next);
    }
  }
  return gap(rows.last, null);
}
