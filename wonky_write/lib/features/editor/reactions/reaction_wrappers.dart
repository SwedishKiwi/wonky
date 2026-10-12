import 'package:super_editor/super_editor.dart';

import '../extractor/change_delta_extractor.dart';

/// Runs [inner] only while [isEnabled] returns `true` (user settings such as
/// *Markdown shortcuts* or *Smart quotes*, Write 04 §41.2).
class ToggleableReaction extends EditReaction {
  ToggleableReaction(this.inner, this.isEnabled);

  final EditReaction inner;
  final bool Function() isEnabled;

  @override
  void modifyContent(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    if (isEnabled()) {
      inner.modifyContent(editorContext, requestDispatcher, changeList);
    }
  }

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    if (isEnabled()) {
      inner.react(editorContext, requestDispatcher, changeList);
    }
  }
}

/// Makes the content changes of [inner] a separate change (and therefore a
/// separate undo step) from the edit that triggered it (Write 04 §2.6).
///
/// Before [inner] runs, the transaction's changes so far are closed as one
/// segment; whatever [inner] changes becomes the next segment, labelled
/// [label] ("Autoformat", "Smart quote"…).
class MarkedReaction extends EditReaction {
  MarkedReaction(this.inner, {required this.label, required this.extractor});

  final EditReaction inner;
  final String label;
  final ChangeDeltaExtractor extractor;

  @override
  void modifyContent(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    _run(
      changeList,
      () => inner.modifyContent(editorContext, requestDispatcher, changeList),
    );
  }

  @override
  void react(
    EditContext editorContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
  ) {
    _run(
      changeList,
      () => inner.react(editorContext, requestDispatcher, changeList),
    );
  }

  void _run(List<EditEvent> changeList, void Function() body) {
    // Close everything before this reaction as its own segment (cheap when
    // nothing changed since the last checkpoint), then label whatever the
    // inner reaction changes.
    extractor.checkpoint(changeList, labelForNextSegment: label);
    body();
    extractor.checkpoint(changeList);
  }
}

/// Helpers to inspect what the user just typed.
abstract final class TypedText {
  /// The last [TextInsertionEvent] of [changeList] if it is the last document
  /// change of the list (i.e. the user just typed it).
  static TextInsertionEvent? lastInsertion(List<EditEvent> changeList) {
    for (var i = changeList.length - 1; i >= 0; i -= 1) {
      final event = changeList[i];
      if (event is DocumentEdit) {
        final change = event.change;
        return change is TextInsertionEvent ? change : null;
      }
    }
    return null;
  }
}
