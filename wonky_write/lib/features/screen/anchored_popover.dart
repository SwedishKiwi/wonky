import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/write_l10n.dart';

/// Shows [builder] in a modal popover below (or above, when there is no
/// room) [anchor] (global coordinates), like a `ShadPopover` but opened
/// programmatically from commands (link editor, table size …). Esc or a
/// click outside closes it; the future completes with the popped value.
Future<T?> showAnchoredPopover<T>(
  BuildContext context, {
  required Rect anchor,
  required WidgetBuilder builder,
  double width = 360,
  String? barrierLabel,
}) => Navigator.of(context).push<T>(
  _AnchoredPopoverRoute<T>(
    anchor: anchor,
    builder: builder,
    width: width,
    label: barrierLabel ?? writeL10n(context).popoverDismiss,
  ),
);

class _AnchoredPopoverRoute<T> extends PopupRoute<T> {
  _AnchoredPopoverRoute({
    required this.anchor,
    required this.builder,
    required this.width,
    required this.label,
  });

  final Rect anchor;
  final WidgetBuilder builder;
  final double width;
  final String label;

  @override
  Color? get barrierColor => const Color(0x00000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final theme = ShadTheme.of(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final content = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: theme.colorScheme.popover,
            borderRadius: theme.radius,
            border: Border.all(color: theme.colorScheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1f000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.popoverForeground,
              fontWeight: FontWeight.w400,
            ),
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(anchor),
      child: reduce
          ? content
          : FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: content,
              ),
            ),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout(this.anchor);

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        constraints.biggest,
      ).deflate(const EdgeInsets.all(8));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = anchor.left;
    if (x + childSize.width > size.width - 8) {
      x = size.width - 8 - childSize.width;
    }
    if (x < 8) x = 8;
    var y = anchor.bottom + 6;
    if (y + childSize.height > size.height - 8) {
      final above = anchor.top - 6 - childSize.height;
      y = above >= 8
          ? above
          : (size.height - 8 - childSize.height).clamp(8, size.height);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}
