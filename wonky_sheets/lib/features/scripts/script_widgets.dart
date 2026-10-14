import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// A small ghost icon button with a tooltip (script editor, dialogs).
Widget scriptIconButton({
  Key? key,
  required IconData icon,
  required String tooltip,
  VoidCallback? onPressed,
  double size = 28,
}) => ShadTooltip(
  builder: (_) => Text(tooltip),
  child: ShadIconButton.ghost(
    key: key,
    width: size,
    height: size,
    iconSize: 15,
    icon: Icon(icon),
    semanticLabel: tooltip,
    onPressed: onPressed,
  ),
);
