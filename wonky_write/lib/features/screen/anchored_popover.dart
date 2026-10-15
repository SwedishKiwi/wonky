import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/write_l10n.dart';

/// Shows [builder] in a modal popover below (or above, when there is no
/// room) [anchor] (global coordinates), like a `ShadPopover` but opened
/// programmatically from commands (link editor, table size …). Esc or a
/// click outside closes it; the future completes with the popped value.
///
/// The shell's [showAnchoredPopoverAt] with Write's default barrier label.
Future<T?> showAnchoredPopover<T>(
  BuildContext context, {
  required Rect anchor,
  required WidgetBuilder builder,
  double width = 360,
  String? barrierLabel,
}) => showAnchoredPopoverAt<T>(
  context,
  anchor: anchor,
  builder: builder,
  width: width,
  barrierLabel: barrierLabel ?? writeL10n(context).popoverDismiss,
);
