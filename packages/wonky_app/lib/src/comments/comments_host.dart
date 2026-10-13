import 'package:flutter/foundation.dart';

/// Where an app shows the open file's comments instead of the comments side
/// panel (suite 07 §2.3) — Write shows them in the margin next to the page.
///
/// Set on `ShellServices.commentsHost` by the app's editor screen; the
/// comment commands (`shell.comments.togglePanel`, `.create`, `.activate`)
/// show the comments through it, and fall back to the side panel when no
/// host is set.
abstract interface class CommentsHost implements Listenable {
  /// Whether the comments are visible.
  bool get isShown;

  /// Shows or hides the comments.
  set isShown(bool value);
}
