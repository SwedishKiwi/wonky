import 'package:flutter/foundation.dart';

/// Keeps at most one menu open at a time (suite 02 §4.2).
///
/// shad puts every context menu, its trigger and its popover in one tap
/// region group, so a tap on another menu's trigger is "inside" the open
/// menu and never closes it. Each top-level menu (menubar, dropdown, context
/// menu) claims this slot when it opens, which closes the previous one.
abstract final class OpenMenu {
  static Object? _owner;
  static VoidCallback? _close;

  /// [owner] opened; closes the menu that was open before (unless it is
  /// [owner] itself). [close] closes [owner]'s menu.
  static void claim(Object owner, VoidCallback close) {
    final previous = _close;
    final previousOwner = _owner;
    _owner = owner;
    _close = close;
    if (previous != null && !identical(previousOwner, owner)) previous();
  }

  /// [owner]'s menu closed.
  static void release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _close = null;
  }

  /// Closes the open menu, if any.
  static void closeAll() {
    final close = _close;
    _owner = null;
    _close = null;
    close?.call();
  }
}
