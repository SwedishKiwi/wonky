import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// Shows toasts through `ShadSonner` (stacked, bottom-right).
class Toasts {
  Toasts(this._context);

  final BuildContext? Function() _context;
  int _next = 1;

  int show(
    String title, {
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
    bool destructive = false,
    Duration? duration,
  }) {
    final ctx = _context();
    final id = _next++;
    if (ctx == null || !ctx.mounted) return id;
    final sonner = ShadSonner.maybeOf(ctx);
    if (sonner == null) return id;
    final action = actionLabel == null
        ? null
        : ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () {
              sonner.hide(id);
              onAction?.call();
            },
            child: Text(actionLabel),
          );
    sonner.show(
      destructive
          ? ShadToast.destructive(
              id: id,
              title: Text(title),
              description: description == null ? null : Text(description),
              action: action,
              duration: duration,
            )
          : ShadToast(
              id: id,
              title: Text(title),
              description: description == null ? null : Text(description),
              action: action,
              duration: duration,
            ),
    );
    return id;
  }

  void error(String title, {String? description}) =>
      show(title, description: description, destructive: true);

  void hide(int id) {
    final ctx = _context();
    if (ctx == null || !ctx.mounted) return;
    ShadSonner.maybeOf(ctx)?.hide(id);
  }
}
