import 'package:wonky_client/wonky_client.dart'
    show CommentAnchorKind, CommentThreadView;

/// A new comment's anchor, produced by the app from the current selection.
class NewCommentAnchor {
  const NewCommentAnchor({
    required this.kind,
    required this.anchorJson,
    this.quotedText,
    this.label,
  });

  final CommentAnchorKind kind;

  /// App-specific JSON (Write: Delta range; Sheets: `{sheetId,rowId,colId}`).
  final String anchorJson;

  /// Snapshot of the anchored text / cell value.
  final String? quotedText;

  /// Human label of the anchor in the panel ("B4", "Paragraph 3").
  final String? label;
}

/// Connects comments to an app's content (suite 07 §2.3): Write anchors to
/// text ranges, Sheets to cells/ranges.
abstract class CommentAnchorProvider {
  /// The anchor for a new comment at the current selection, or null when no
  /// anchor is possible (then `shell.comments.create` is disabled).
  NewCommentAnchor? anchorForSelection();

  /// Display label of an existing thread's anchor ("B4", quoted text).
  String? labelFor(CommentThreadView thread) => thread.quotedText;

  /// Sort key for "sort by position" in the panel.
  num positionOf(CommentThreadView thread) => 0;

  /// Scrolls to / selects the anchor of [thread] (`shell.comments.activate`).
  void reveal(CommentThreadView thread);

  /// Called when a thread is created locally (Write marks the range).
  void onThreadCreated(CommentThreadView thread) {}

  /// Called when a thread is deleted (Write removes the attribution).
  void onThreadDeleted(CommentThreadView thread) {}

  /// The thread that should be highlighted as active (caret inside anchor).
  String? get activeThreadUuid => null;
}
