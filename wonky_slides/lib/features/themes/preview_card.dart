import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// A focusable, clickable card around a preview thumbnail (layout
/// galleries, theme cards): border in `primary` when [selected], the focus
/// ring when focused, `accent` on hover; Enter / Space activate. Tooltip
/// and semantics label = [label].
class PreviewCard extends StatefulWidget {
  const PreviewCard({
    super.key,
    required this.label,
    required this.child,
    this.onPressed,
    this.onSecondaryTapDown,
    this.selected = false,
    this.padding = const EdgeInsets.all(4),
    this.semanticsHint,
  });

  final String label;
  final Widget child;
  final VoidCallback? onPressed;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool selected;
  final EdgeInsets padding;
  final String? semanticsHint;

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      hint: widget.semanticsHint,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: ShadTooltip(
            builder: (_) => Text(widget.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: widget.padding,
              decoration: BoxDecoration(
                color: _hover && enabled ? theme.colorScheme.accent : null,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  width: 2,
                  color: widget.selected
                      ? theme.colorScheme.primary
                      : _focus
                      ? theme.colorScheme.ring
                      : const Color(0x00000000),
                ),
              ),
              child: Opacity(opacity: enabled ? 1 : 0.6, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
