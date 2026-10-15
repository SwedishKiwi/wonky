import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:wonky_app/spellcheck.dart';
import 'package:wonky_slides_core/find.dart';
import 'package:wonky_slides_core/ops.dart';

import '../../l10n/slides_l10n.dart';
import '../canvas/slide_canvas_controller.dart' show selectionOf;
import '../editor_screen/deck_editor_controller.dart';
import '../text_editing/text_editing_host.dart';
import 'slides_spelling.dart';
import 'spelling_actions.dart';

/// The Check spelling dialog's view of a deck (Slides 03 §14): every body
/// of the deck in presentation order (`DeckFind.bodies`) laid end to end,
/// so the shell's dialog (`package:wonky_app/spellcheck.dart`) walks the
/// misspellings deck-wide from the caret (or the current slide). Each
/// *Change* and *Change all* is one undo step ("Correct spelling");
/// *Ignore all* ignores the word for the session; *Add* adds it to the
/// synced personal dictionary.
///
/// Showing a word makes its slide current and selects the object (or
/// opens the notes) — the text editor isn't started under the modal dialog.
class SlidesSpellingSession implements SpellingSession {
  SlidesSpellingSession(this.editor);

  final DeckEditorController editor;

  SlidesSpelling get _spelling => SlidesSpelling.of(editor);

  /// Global offset → deck issue of the last [issues] call.
  final Map<int, SlidesSpellingIssue> _byStart = {};

  /// Body key → base offset of the last [issues] call.
  final Map<String, int> _bases = {};

  @override
  List<SpellingIssue> get issues {
    _byStart.clear();
    _bases.clear();
    final out = <SpellingIssue>[];
    var base = 0;
    final byBody = <String, List<SlidesSpellingIssue>>{};
    for (final i in _spelling.deckIssues()) {
      byBody.putIfAbsent(i.bodyKey, () => []).add(i);
    }
    for (final (_, target, json) in DeckFind.bodies(
      editor.model,
      const DeckFindOptions(),
    )) {
      final key = DeckFind.bodyKey(target);
      _bases[key] = base;
      for (final i in byBody[key] ?? const <SlidesSpellingIssue>[]) {
        _byStart[base + i.start] = i;
        out.add(SpellingIssue(i.word, base + i.start, base + i.end));
      }
      base += DeckFind.plainOf(json).length + 1;
    }
    return out;
  }

  @override
  bool get isAvailable => _spelling.isReady;

  @override
  int get startOffset {
    if (_bases.isEmpty) issues;
    final c = textEditingOf(editor).active;
    if (c != null) {
      final base = _bases[DeckFind.bodyKey(c.target)];
      final range = c.selectionRange;
      if (base != null && range != null) return base + range.$1;
    }
    final slide = editor.currentSlideId;
    if (slide == null) return 0;
    for (final (slideId, target, _) in DeckFind.bodies(
      editor.model,
      const DeckFindOptions(),
    )) {
      if (slideId == slide) return _bases[DeckFind.bodyKey(target)] ?? 0;
    }
    return 0;
  }

  @override
  List<String> suggestionsFor(String word) => _spelling.suggestionsFor(word);

  SlidesSpellingIssue? _issue(SpellingIssue i) => _byStart[i.start];

  @override
  void select(SpellingIssue issue) {
    final i = _issue(issue);
    if (i == null) return;
    // The dialog shows its first word while it builds: navigate after
    // that frame (the editor notifies its listeners).
    final b = WidgetsBinding.instance;
    if (b.schedulerPhase == SchedulerPhase.idle ||
        b.schedulerPhase == SchedulerPhase.postFrameCallbacks) {
      _show(i);
      return;
    }
    b
      ..addPostFrameCallback((_) => _show(i))
      ..scheduleFrame();
  }

  void _show(SlidesSpellingIssue i) {
    if (editor.currentSlideId != i.slideId) editor.setCurrentSlide(i.slideId);
    switch (i.target) {
      case NotesText():
        textEditingOf(editor).end(select: false);
        if (!editor.notesVisible) editor.setNotesVisible(true);
      case ElementText(:final elementId) || CellText(:final elementId):
        textEditingOf(editor).end(select: false);
        final parent = editor.model.element(elementId)?.parentId;
        selectionOf(editor).select([elementId], enteredGroup: parent);
    }
  }

  @override
  void change(SpellingIssue issue, String replacement) {
    final i = _issue(issue);
    if (i == null) return;
    runSpellingStep(
      editor,
      slidesL10nOf(editor.services).undoCorrectSpelling,
      (apply) => replaceSpelling(editor, {
        i.target: [(i.start, i.length, replacement)],
      }, apply),
    );
  }

  @override
  void changeAll(String word, String replacement) {
    runSpellingStep(
      editor,
      slidesL10nOf(editor.services).undoCorrectSpelling,
      (apply) => replaceSpelling(
        editor,
        spellingEditsFor(editor, word, replacement),
        apply,
      ),
    );
  }

  @override
  void ignoreAll(String word) => _spelling.ignore(word);

  @override
  Future<void> addToDictionary(String word) async {
    final ok = await _spelling.addToDictionary(word);
    if (!ok) {
      editor.services.toasts.error(
        slidesL10nOf(editor.services).toastPersonalDictionaryFull(10000),
      );
    }
  }

  @override
  void recheck() {}
}

/// The `replaceSpelling` edits replacing every flagged [word] of the deck
/// with [replacement] (*Change all*).
Map<TextTarget, List<(int, int, String)>> spellingEditsFor(
  DeckEditorController editor,
  String word,
  String replacement,
) {
  final edits = <String, (TextTarget, List<(int, int, String)>)>{};
  for (final i in SlidesSpelling.of(editor).deckIssues()) {
    if (i.word != word) continue;
    edits.putIfAbsent(i.bodyKey, () => (i.target, [])).$2.add((
      i.start,
      i.length,
      replacement,
    ));
  }
  return {for (final (t, ranges) in edits.values) t: ranges};
}
