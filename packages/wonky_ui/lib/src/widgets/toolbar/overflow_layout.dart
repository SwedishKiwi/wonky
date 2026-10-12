import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Role of a child of [ToolbarOverflowLayout].
enum ToolbarSlot { item, separator, overflowButton }

/// Parent data for [ToolbarOverflowLayout] children.
class ToolbarOverflowParentData extends ContainerBoxParentData<RenderBox> {
  ToolbarSlot slot = ToolbarSlot.item;
  int priority = 0;
  int group = 0;
  int index = 0;
  bool pinned = false;
  bool visible = true;
}

/// Positions a toolbar child and describes how it overflows.
class ToolbarOverflowChild extends ParentDataWidget<ToolbarOverflowParentData> {
  const ToolbarOverflowChild({
    super.key,
    required this.slot,
    this.priority = 0,
    this.group = 0,
    this.index = 0,
    this.pinned = false,
    required super.child,
  });

  final ToolbarSlot slot;
  final int priority;
  final int group;
  final int index;
  final bool pinned;

  @override
  void applyParentData(RenderObject renderObject) {
    final pd = renderObject.parentData! as ToolbarOverflowParentData;
    var changed = false;
    if (pd.slot != slot) {
      pd.slot = slot;
      changed = true;
    }
    if (pd.priority != priority) {
      pd.priority = priority;
      changed = true;
    }
    if (pd.group != group) {
      pd.group = group;
      changed = true;
    }
    if (pd.index != index) {
      pd.index = index;
      changed = true;
    }
    if (pd.pinned != pinned) {
      pd.pinned = pinned;
      changed = true;
    }
    if (changed) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => ToolbarOverflowLayout;
}

/// Lays children out in a row; when they don't fit, hides the
/// least-important items (highest `priority` number first, rightmost first
/// on ties), shows the overflow button and reports the hidden item indices.
class ToolbarOverflowLayout extends MultiChildRenderObjectWidget {
  const ToolbarOverflowLayout({
    super.key,
    required this.onHiddenChanged,
    this.spacing = 2,
    required super.children,
  });

  final ValueChanged<Set<int>> onHiddenChanged;
  final double spacing;

  @override
  RenderToolbarOverflow createRenderObject(BuildContext context) =>
      RenderToolbarOverflow(onHiddenChanged: onHiddenChanged, spacing: spacing);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderToolbarOverflow renderObject,
  ) {
    renderObject
      ..onHiddenChanged = onHiddenChanged
      ..spacing = spacing;
  }
}

/// Render object of [ToolbarOverflowLayout].
class RenderToolbarOverflow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ToolbarOverflowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ToolbarOverflowParentData> {
  RenderToolbarOverflow({
    required this._onHiddenChanged,
    this._spacing = 2,
  });

  ValueChanged<Set<int>> _onHiddenChanged;
  set onHiddenChanged(ValueChanged<Set<int>> v) => _onHiddenChanged = v;

  double _spacing;
  set spacing(double v) {
    if (v == _spacing) return;
    _spacing = v;
    markNeedsLayout();
  }

  Set<int> _lastHidden = const {};

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ToolbarOverflowParentData) {
      child.parentData = ToolbarOverflowParentData();
    }
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = (c.parentData! as ToolbarOverflowParentData).nextSibling;
    }
    return out;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    // The overflow button alone.
    for (final c in _children) {
      final pd = c.parentData! as ToolbarOverflowParentData;
      if (pd.slot == ToolbarSlot.overflowButton) {
        return c.getMinIntrinsicWidth(height);
      }
    }
    return 0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var w = 0.0;
    var n = 0;
    for (final c in _children) {
      final pd = c.parentData! as ToolbarOverflowParentData;
      if (pd.slot == ToolbarSlot.overflowButton) continue;
      w += c.getMaxIntrinsicWidth(height);
      n++;
    }
    return w + math.max(0, n - 1) * _spacing;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    var h = 0.0;
    for (final c in _children) {
      h = math.max(h, c.getMinIntrinsicHeight(double.infinity));
    }
    return h;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    var h = 0.0;
    for (final c in _children) {
      h = math.max(
        h,
        c.getDryLayout(BoxConstraints(maxHeight: constraints.maxHeight)).height,
      );
    }
    return constraints.constrain(Size(constraints.maxWidth, h));
  }

  @override
  void performLayout() {
    final children = _children;
    final childConstraints = BoxConstraints(maxHeight: constraints.maxHeight);
    var height = 0.0;
    RenderBox? overflow;
    for (final c in children) {
      c.layout(childConstraints, parentUsesSize: true);
      height = math.max(height, c.size.height);
      final pd = c.parentData! as ToolbarOverflowParentData;
      pd.visible = true;
      if (pd.slot == ToolbarSlot.overflowButton) overflow = c;
    }
    final maxWidth = constraints.maxWidth;
    final items = [
      for (final c in children)
        if ((c.parentData! as ToolbarOverflowParentData).slot ==
            ToolbarSlot.item)
          c,
    ];

    bool groupVisible(int group) => items.any((c) {
      final pd = c.parentData! as ToolbarOverflowParentData;
      return pd.group == group && pd.visible;
    });

    void updateSeparators() {
      for (final c in children) {
        final pd = c.parentData! as ToolbarOverflowParentData;
        if (pd.slot != ToolbarSlot.separator) continue;
        // A separator sits after group `pd.group`; show it when that group
        // and a later group have visible items.
        final later = items.any((i) {
          final ip = i.parentData! as ToolbarOverflowParentData;
          return ip.group > pd.group && ip.visible;
        });
        pd.visible = groupVisible(pd.group) && later;
      }
    }

    double usedWidth({required bool withOverflow}) {
      var w = 0.0;
      var n = 0;
      for (final c in children) {
        final pd = c.parentData! as ToolbarOverflowParentData;
        if (pd.slot == ToolbarSlot.overflowButton) {
          if (!withOverflow) continue;
        } else if (!pd.visible) {
          continue;
        }
        w += c.size.width;
        n++;
      }
      return w + math.max(0, n - 1) * _spacing;
    }

    var overflowing = false;
    if (overflow != null) {
      (overflow.parentData! as ToolbarOverflowParentData).visible = false;
    }
    updateSeparators();
    if (usedWidth(withOverflow: false) > maxWidth) {
      overflowing = true;
      // Hide candidates: least important first, rightmost first on ties.
      final candidates = [
        for (final c in items)
          if (!(c.parentData! as ToolbarOverflowParentData).pinned) c,
      ]..sort((a, b) {
          final pa = a.parentData! as ToolbarOverflowParentData;
          final pb = b.parentData! as ToolbarOverflowParentData;
          final p = pb.priority.compareTo(pa.priority);
          return p != 0 ? p : pb.index.compareTo(pa.index);
        });
      for (final c in candidates) {
        if (usedWidth(withOverflow: true) <= maxWidth) break;
        (c.parentData! as ToolbarOverflowParentData).visible = false;
        updateSeparators();
      }
    }
    if (overflow != null) {
      (overflow.parentData! as ToolbarOverflowParentData).visible = overflowing;
    }

    // Position visible children in order; the overflow button goes last.
    var x = 0.0;
    var first = true;
    for (final c in children) {
      final pd = c.parentData! as ToolbarOverflowParentData;
      if (pd.slot == ToolbarSlot.overflowButton || !pd.visible) {
        pd.offset = const Offset(-100000, 0);
        continue;
      }
      if (!first) x += _spacing;
      first = false;
      pd.offset = Offset(x, (height - c.size.height) / 2);
      x += c.size.width;
    }
    if (overflow != null && overflowing) {
      if (!first) x += _spacing;
      final pd = overflow.parentData! as ToolbarOverflowParentData;
      pd.offset = Offset(x, (height - overflow.size.height) / 2);
      x += overflow.size.width;
    }
    size = constraints.constrain(Size(x, height));

    final hidden = <int>{
      for (final c in items)
        if (!(c.parentData! as ToolbarOverflowParentData).visible)
          (c.parentData! as ToolbarOverflowParentData).index,
    };
    if (!_setEquals(hidden, _lastHidden)) {
      _lastHidden = hidden;
      final cb = _onHiddenChanged;
      WidgetsBinding.instance.addPostFrameCallback((_) => cb(hidden));
    }
  }

  static bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final c in _children) {
      final pd = c.parentData! as ToolbarOverflowParentData;
      if (!pd.visible) continue;
      context.paintChild(c, pd.offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final c in _children.reversed) {
      final pd = c.parentData! as ToolbarOverflowParentData;
      if (!pd.visible) continue;
      final hit = result.addWithPaintOffset(
        offset: pd.offset,
        position: position,
        hitTest: (r, p) => c.hitTest(r, position: p),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final c in _children) {
      if ((c.parentData! as ToolbarOverflowParentData).visible) visitor(c);
    }
  }
}
