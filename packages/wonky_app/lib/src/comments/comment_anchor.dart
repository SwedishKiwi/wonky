import 'package:flutter/widgets.dart' show BuildContext, Widget;
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

/// Optional extras of a [CommentAnchorProvider] (checked with `is`, so
/// existing providers stay valid): inline composing, a panel scope filter
/// and group headers (Sheets 10 §3.4–3.5).
abstract class CommentPanelOptions {
  /// Whether `shell.comments.create` without a body shows the composer in
  /// the app next to the anchor (Sheets: next to the cell) instead of
  /// opening the comments panel.
  bool get composesInline => false;

  /// An extra scope filter of the comments panel: labels by scope id
  /// (Sheets: `sheet` → "This sheet", `all` → "All sheets"); empty = none.
  Map<String, String> get scopes => const {};

  /// The initial scope (default: the first of [scopes]).
  String? get defaultScope => null;

  /// Whether [thread] is in [scope].
  bool inScope(CommentThreadView thread, String scope) => true;

  /// The group header of [thread] in the panel's position sort (Sheets:
  /// the sheet name); null = no headers.
  String? groupOf(CommentThreadView thread) => null;
}

/// (v2) Optional section headers of the comments panel (checked with `is`
/// on the anchor provider, so existing [CommentPanelOptions] stay valid).
abstract class CommentPanelSections {
  /// A section header above the group headers in the position sort
  /// (Slides: the slide group with its color dot, Slides 09 §3.5); null =
  /// none.
  CommentPanelSection? sectionOf(CommentThreadView thread);
}

/// A section header of the comments panel ([CommentPanelOptions.sectionOf]).
class CommentPanelSection {
  const CommentPanelSection({
    required this.id,
    required this.title,
    this.leading,
  });

  /// Identifies the section (consecutive threads with the same id share
  /// one header).
  final String id;
  final String title;

  /// A small widget before the title (Slides: the group's color dot).
  final Widget Function(BuildContext context)? leading;
}

/// The [CommentPanelOptions] of [anchors], if it has any.
CommentPanelOptions? commentPanelOptionsOf(CommentAnchorProvider? anchors) =>
    anchors is CommentPanelOptions ? anchors as CommentPanelOptions : null;
