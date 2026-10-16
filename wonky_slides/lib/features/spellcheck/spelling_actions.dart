import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart'
    show Document, DocumentPosition, TextNode;
import 'package:wonky_app/spellcheck.dart'
    as shared
    show SpellingMenuLabels, spellingMenuEntries;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/find.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../config/slides_features.dart';
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../notes/notes_edit_controller.dart';
import '../text_editing/slide_text_editor.dart';
import '../text_editing/text_editing_host.dart';
import 'editor_spelling.dart';
import 'slides_spelling.dart';

/// The body addressed by `slides.spelling.*` arguments: `elementId` (+
/// `rowId` and `columnId` for a table cell) or `notesSlideId`.
TextTarget? spellingTargetOf(JsonArgs a) {
  final notes = a.string('notesSlideId');
  if (notes != null) return NotesText(notes);
  final id = a.string('elementId');
  if (id == null) return null;
  final row = a.string('rowId'), col = a.string('columnId');
  if (row != null && col != null) return CellText(id, row, col);
  return ElementText(id);
}

/// The stored Delta JSON of body [t], or null.
String? spellingBodyOf(DeckEditorController ed, TextTarget t) => switch (t) {
  ElementText(:final elementId) => ed.model.element(elementId)?.text,
  CellText(:final elementId, :final rowId, :final columnId) =>
    ed.model.indexes.table(elementId).cell(rowId, columnId)?.text,
  NotesText(:final slideId) => ed.model.slide(slideId)?.notes,
};

/// The soft-lock target of body [t].
TextLockTarget spellingLockOf(TextTarget t) => switch (t) {
  ElementText(:final elementId) => TextLockTarget.element(elementId),
  CellText(:final elementId, :final rowId, :final columnId) =>
    TextLockTarget.cell(elementId, rowId, columnId),
  NotesText(:final slideId) => TextLockTarget.notes(slideId),
};

/// The result of [replaceSpelling].
typedef SpellingReplaceResult = ({int replaced, int skipped, String? holder});

/// Replaces words of the deck's bodies — [edits] maps each body to its
/// `(start, length, replacement)` ranges (plain-text offsets) — with one
/// `SetText` per body through [apply] (a command's transaction: one undo
/// step). Pending typing of the canvas text editor is written first;
/// bodies another participant is editing are skipped (03 §13). A body
/// being edited on the canvas keeps the caret after the last replacement.
SpellingReplaceResult replaceSpelling(
  DeckEditorController ed,
  Map<TextTarget, List<(int, int, String)>> edits,
  void Function(SlidesOperation op) apply,
) {
  final host = textEditingOf(ed);
  host.commit();
  var replaced = 0, skipped = 0;
  String? holder;
  for (final MapEntry(key: t, value: ranges) in edits.entries) {
    final held = host.locks.heldByTarget(spellingLockOf(t));
    if (held != null) {
      skipped += ranges.length;
      holder ??= held;
      continue;
    }
    final json = spellingBodyOf(ed, t);
    if (json == null || ranges.isEmpty) continue;
    final length = DeckFind.plainOf(json).length;
    final valid = [
      for (final r in ranges)
        if (r.$1 >= 0 && r.$2 > 0 && r.$1 + r.$2 <= length) r,
    ];
    if (valid.isEmpty) continue;
    apply(
      SetText(t, DeckFind.replaceRanges(json, valid, notes: t is NotesText)),
    );
    replaced += valid.length;
    final c = host.active;
    if (c != null && _same(c.target, t)) {
      final last = valid.reduce((a, b) => a.$1 >= b.$1 ? a : b);
      var shift = 0;
      for (final r in valid) {
        if (r.$1 < last.$1) shift += r.$3.length - r.$2;
      }
      c.selectRange(last.$1 + shift + last.$3.length);
    }
  }
  return (replaced: replaced, skipped: skipped, holder: holder);
}

bool _same(TextTarget a, TextTarget b) =>
    DeckFind.bodyKey(a) == DeckFind.bodyKey(b);

/// Runs [body] as one undo step labelled [label] outside a command (the
/// Check spelling dialog's buttons, 03 §14: one step per change).
void runSpellingStep(
  DeckEditorController ed,
  String label,
  void Function(void Function(SlidesOperation op) apply) body,
) {
  final t = ed.services.undo.beginTransaction(
    label,
    stack: UndoStackKey(ed.session.itemUuid.uuid),
  );
  final ctx = CommandContext(
    services: ed.services,
    source: InvocationSource.ui,
    transaction: t,
  );
  try {
    body((op) => ed.apply(ctx, op));
    t.commit();
  } catch (_) {
    t.commit();
    rethrow;
  }
}

/// The body offset (paragraphs joined by `"\n"`) of [nodeId] / [offset] in
/// a super_editor [document] of a Slides body.
int bodyOffsetOf(Document document, String nodeId, int offset) {
  var at = 0;
  for (final node in document) {
    if (node is! TextNode) continue;
    if (node.id == nodeId) return at + offset.clamp(0, node.text.length);
    at += node.text.length + 1;
  }
  return at;
}

/// The spelling section of a context menu for the misspelled [word] at
/// body offset [start] of [target] (03 §14): up to five suggestions,
/// *Ignore*, *Add "word" to dictionary* and a separator; empty when the
/// feature is off or the deck can't be edited. A suggestion runs
/// `slides.spelling.replace` (one undo step "Correct spelling").
List<WonkyMenuEntry> spellingMenuEntries(
  DeckEditorController ed,
  TextTarget target,
  int start,
  SpellRange r, {
  VoidCallback? after,
}) => spellingMenuEntriesWith(
  ed,
  r.word,
  onReplace: (replacement) => ed
      .invokeCommand('slides.spelling.replace', {
        ...SlidesSpelling.argsOf(target),
        'start': start,
        'length': r.length,
        'word': r.word,
        'replacement': replacement,
      })
      .then((_) => after?.call()),
  after: after,
);

/// The spelling section of a context menu for the misspelled [word]:
/// suggestions call [onReplace], *Ignore* and *Add to dictionary* run
/// `slides.spelling.ignore` / `addToDictionary`.
List<WonkyMenuEntry> spellingMenuEntriesWith(
  DeckEditorController ed,
  String word, {
  required void Function(String replacement) onReplace,
  VoidCallback? after,
}) {
  if (!SlidesFeatures.isOn(SlidesFeature.spelling) || !ed.canEdit) {
    return const [];
  }
  final spelling = SlidesSpelling.of(ed);
  final l = slidesL10nOf(ed.services);
  void run(String id, Map<String, Object?> args) {
    ed.invokeCommand(id, args).then((_) => after?.call());
  }

  return shared.spellingMenuEntries(
    word: word,
    suggestions: spelling.suggestionsFor(word),
    onReplace: onReplace,
    onIgnore: () => run('slides.spelling.ignore', {'word': word}),
    onAddToDictionary: () =>
        run('slides.spelling.addToDictionary', {'word': word}),
    labels: shared.SpellingMenuLabels(
      noSuggestions: l.spellingNoSuggestions,
      ignore: l.cmdSpellingIgnore,
      addToDictionary: l.spellingAddWordToDictionary,
    ),
    keyPrefix: 'menu.slides.spell',
  );
}

/// The spelling section of the canvas text context menu: the misspelled
/// word at the caret of the body being edited.
List<WonkyMenuEntry> canvasSpellingMenu(DeckEditorController ed) {
  final c = textEditingOf(ed).active;
  if (c == null) return const [];
  final addon = c.addons.whereType<EditorSpelling>().firstOrNull;
  final hit = addon?.errorAtCaret();
  if (hit == null) return const [];
  final (nodeId, r) = hit;
  return spellingMenuEntries(
    ed,
    c.target,
    bodyOffsetOf(c.document, nodeId, r.start),
    r,
    after: () => textEditingOf(ed).editorFocus.requestFocus(),
  );
}

/// The spelling menu of a right-click on the notes being edited at
/// [position] (`NotesPane.contextMenuEntries`).
List<WonkyMenuEntry> notesSpellingMenu(
  DeckEditorController ed,
  NotesEditController edit,
  DocumentPosition position,
) {
  final addon = edit.addons.whereType<EditorSpelling>().firstOrNull;
  final r = addon?.errorAt(position);
  if (r == null) return const [];
  edit.commit();
  return spellingMenuEntries(
    ed,
    NotesText(edit.slideId),
    bodyOffsetOf(edit.document, position.nodeId, r.start),
    r,
  );
}

/// The [EditorSpelling] of a new canvas text editing session
/// (`SlideTextEditing.addonFactories`).
SlideTextEditAddon? canvasSpellingAddon(
  SlideTextEditing host,
  SlideTextEditController c,
) => SlidesFeatures.isOn(SlidesFeature.spelling)
    ? EditorSpelling(
        document: c.document,
        composer: c.composer,
        spelling: SlidesSpelling.of(host.editor),
      )
    : null;

/// The [EditorSpelling] of a new notes editing session
/// (`NotesPane.addonFactories`).
SlideTextEditAddon? notesSpellingAddon(
  DeckEditorController ed,
  NotesEditController edit,
) => SlidesFeatures.isOn(SlidesFeature.spelling)
    ? EditorSpelling(
        document: edit.document,
        composer: edit.composer,
        spelling: SlidesSpelling.of(ed),
      )
    : null;
