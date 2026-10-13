// WONKY PATCH SE-6: content drag delegate (drag and drop of the selection).
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';

/// Lets an app take over a mouse drag that starts on document content.
///
/// By default, dragging on the document selects content. A
/// [ContentDragDelegate] is asked first, when the pan starts, whether it wants
/// to handle the drag instead, e.g., because the drag started inside the
/// current expanded selection and should move that text elsewhere. When
/// [onDragStart] returns `true`, the document doesn't change the selection
/// during that gesture, and the delegate receives every update (also while
/// the document auto-scrolls near the viewport edges) plus the end or cancel.
abstract class ContentDragDelegate {
  /// Called when a pan starts. [details] describe the pointer-down position.
  ///
  /// Return `true` to own this drag.
  bool onDragStart(ContentDragDetails details);

  /// The pointer moved (or the document scrolled under it) during an owned drag.
  void onDragUpdate(ContentDragDetails details);

  /// The owned drag ended at [details].
  void onDragEnd(ContentDragDetails details);

  /// The owned drag was cancelled by the gesture system.
  void onDragCancel();
}

/// Where a [ContentDragDelegate] drag is.
class ContentDragDetails {
  const ContentDragDetails({
    required this.documentLayout,
    required this.globalOffset,
    required this.layoutOffset,
    required this.position,
  });

  /// The document layout, for geometry queries.
  final DocumentLayout documentLayout;

  /// The pointer in global coordinates.
  final Offset globalOffset;

  /// The pointer in document layout coordinates.
  final Offset layoutOffset;

  /// The document position nearest to the pointer, if any.
  final DocumentPosition? position;
}
