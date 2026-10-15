import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_app/wonky_app.dart' show UndoService;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/scene.dart' show TextBody;

import '../model/deck_session.dart';
import '../text_editing/slide_text_editor.dart'
    show SlideTextEditAddon, recordTypingStep;
import '../text_editing/slides_delta_mapper.dart';
import '../text_editing/slides_text_reactions.dart';

/// One editing session of a slide's speaker notes (Slides 04 §8): the
/// super_editor document of `Slide.notes` (the notes subset of the text
/// schema, 02 §4.3 — the planner normalizes every write to it), the write
/// path and the external-change patching.
///
/// Edits are written with `SetText(NotesText)` after [commitDelay] of idle
/// typing and on [close]; each write is recorded as a `slides.rows` undo
/// step that coalesces per slide (`slides.notes:<slideId>`, one step per
/// typing burst). Undo, redo and collaborators' changes of the notes are
/// patched into the document when no local edit is pending.
class NotesEditController extends ChangeNotifier {
  NotesEditController({
    required this.session,
    required this.slideId,
    required this.undo,
    required this.undoLabel,
    this.commitDelay = const Duration(milliseconds: 300),
    this.mapper = const SlidesDeltaMapper(),
  }) {
    _stored = session.model.slide(slideId)?.notes;
    document = mapper.documentFromBody(TextBody.fromJson(_stored));
    final last = document.toList().whereType<TextNode>().last;
    composer = MutableDocumentComposer(
      initialSelection: DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: last.id,
          nodePosition: TextNodePosition(offset: last.text.length),
        ),
      ),
    );
    editor = createSlidesTextEditor(document: document, composer: composer);
    editor.addListener(FunctionalEditListener(_onEdits));
    session.model.addListener(_onBatch);
  }

  final DeckSession session;
  final String slideId;

  /// The shell's undo service (typing steps).
  final UndoService? undo;

  /// The undo label of typing ("Edit speaker notes").
  final String undoLabel;
  final Duration commitDelay;
  final SlidesDeltaMapper mapper;

  late final MutableDocument document;
  late final MutableDocumentComposer composer;
  late final Editor editor;

  /// Additions of other features (SL-44: spelling squiggles), added by the
  /// notes pane when editing starts (`NotesPane.addonFactories`) and
  /// disposed with the controller.
  final List<SlideTextEditAddon> addons = [];

  /// The undo coalescing key of this slide's notes typing.
  String get coalesceKey => 'slides.notes:$slideId';

  String? _stored;
  String? _pending;
  Timer? _timer;
  bool _patching = false;
  bool _closed = false;

  /// Whether edits wait to be written.
  bool get hasPendingEdits => _pending != null;

  /// The notes being edited (Delta JSON).
  String get json => _pending ?? mapper.jsonOf(document);

  void _onEdits(List<EditEvent> changes) {
    if (_patching || _closed) return;
    if (!changes.any((e) => e is DocumentEdit)) {
      notifyListeners();
      return;
    }
    final next = mapper.jsonOf(document);
    if (next == (_pending ?? _stored)) return;
    _pending = next;
    _timer?.cancel();
    _timer = Timer(commitDelay, commit);
    notifyListeners();
  }

  /// Writes pending edits now (idle timer, blur, slide change, undo).
  SlidesPlan? commit() {
    _timer?.cancel();
    _timer = null;
    final pending = _pending;
    if (pending == null) return null;
    _pending = null;
    if (session.model.slide(slideId) == null) return null;
    final current = session.model.slide(slideId)?.notes;
    if (_same(pending, current)) return null;
    final empty =
        SlidesText.isBlank(pending) &&
        !pending.contains('"list"') &&
        current == null;
    if (empty) return null;
    final SlidesPlan plan;
    try {
      _patching = true;
      plan = session.execute(SetText(NotesText(slideId), pending));
    } on PlanException {
      return null;
    } finally {
      _patching = false;
    }
    _stored = session.model.slide(slideId)?.notes;
    final u = undo;
    if (!plan.isEmpty && u != null) {
      recordTypingStep(u, plan, coalesceKey: coalesceKey, label: undoLabel);
    }
    return plan;
  }

  void _onBatch(DeckChangeBatch batch) {
    if (_patching || _closed) return;
    final slide = session.model.slide(slideId);
    if (slide == null) return;
    final notes = slide.notes;
    if (_same(notes, _stored)) return;
    _stored = notes;
    // Local edits that weren't written yet win (02 §4.4).
    if (_pending != null) return;
    _replaceBody(TextBody.fromJson(notes));
    notifyListeners();
  }

  /// Replaces the document's content with [body] (undo, redo, remote).
  void _replaceBody(TextBody body) {
    final old = document.toList();
    final fresh = mapper.nodesFromBody(body);
    final ops = <DocumentPatchOperation>[];
    for (var i = 0; i < fresh.length; i++) {
      if (i < old.length) {
        ops.add(ReplaceNodePatch(old[i].id, _withId(fresh[i], old[i].id)));
      } else {
        ops.add(InsertNodePatch(i, fresh[i]));
      }
    }
    for (var i = fresh.length; i < old.length; i++) {
      ops.add(DeleteNodePatch(old[i].id));
    }
    final ids = [
      for (var i = 0; i < fresh.length; i++)
        i < old.length ? old[i].id : fresh[i].id,
    ];
    final selection = composer.selection;
    DocumentSelection? after;
    if (selection != null) {
      DocumentPosition clamp(DocumentPosition p) {
        var index = ids.indexOf(p.nodeId);
        if (index < 0) index = ids.length - 1;
        final node = fresh[index] as TextNode;
        final o = p.nodePosition is TextNodePosition
            ? (p.nodePosition as TextNodePosition).offset
            : node.text.length;
        return DocumentPosition(
          nodeId: ids[index],
          nodePosition: TextNodePosition(offset: o.clamp(0, node.text.length)),
        );
      }

      after = DocumentSelection(
        base: clamp(selection.base),
        extent: clamp(selection.extent),
      );
    }
    _patching = true;
    try {
      editor.execute([
        ApplyDocumentPatchRequest(
          operations: ops,
          updateSelection: after != null,
          selectionAfter: after,
          resyncIme: true,
          tag: 'slides.notes.external',
        ),
      ]);
    } finally {
      _patching = false;
    }
  }

  static DocumentNode _withId(DocumentNode n, String id) => switch (n) {
    ParagraphNode() => n.copyParagraphWith(id: id),
    ListItemNode() => n.copyListItemWith(id: id),
    TaskNode() => n.copyTaskWith(id: id),
    _ => n,
  };

  static bool _same(String? a, String? b) {
    if (a == b) return true;
    try {
      return sameDelta(
        SlidesText.normalize(SlidesText.parse(a), notes: true),
        SlidesText.normalize(SlidesText.parse(b), notes: true),
      );
    } on FormatException {
      return false;
    }
  }

  // ------------------------------------------------------ mini toolbar

  /// The selection as a range, or null when collapsed / missing.
  DocumentRange? get _range {
    final s = composer.selection;
    if (s == null || s.isCollapsed) return null;
    return s.normalize(document);
  }

  /// Whether the selection (or the typing style) has [a].
  bool hasAttribution(Attribution a) {
    final r = _range;
    if (r == null) return composer.preferences.currentAttributions.contains(a);
    final node = document.getNodeById(r.start.nodeId);
    if (node is! TextNode) return false;
    final start = (r.start.nodePosition as TextNodePosition).offset;
    return node.text.hasAttributionAt(start, attribution: a);
  }

  /// Toggles bold / italic / underline on the selection, or for typing.
  void toggleAttribution(Attribution a) {
    final r = _range;
    if (r == null) {
      final prefs = composer.preferences;
      if (prefs.currentAttributions.contains(a)) {
        prefs.removeStyle(a);
      } else {
        prefs.addStyle(a);
      }
      notifyListeners();
      return;
    }
    editor.execute([
      ToggleTextAttributionsRequest(documentRange: r, attributions: {a}),
    ]);
  }

  /// The list type of the caret's paragraph (null = a plain paragraph).
  ListItemType? get listType {
    final s = composer.selection;
    if (s == null) return null;
    final node = document.getNodeById(s.extent.nodeId);
    return node is ListItemNode ? node.type : null;
  }

  /// Turns the selected paragraphs into a [type] list, or back into
  /// paragraphs when they already are one.
  void toggleList(ListItemType type) {
    final s = composer.selection;
    if (s == null) return;
    final r = s.normalize(document);
    final nodes = document.getNodesInside(r.start, r.end);
    final off = nodes.every((n) => n is ListItemNode && n.type == type);
    editor.execute([
      for (final n in nodes)
        if (off && n is ListItemNode)
          ConvertListItemToParagraphRequest(nodeId: n.id)
        else if (n is ListItemNode)
          ChangeListItemTypeRequest(nodeId: n.id, newType: type)
        else if (n is ParagraphNode)
          ConvertParagraphToListItemRequest(nodeId: n.id, type: type),
    ]);
  }

  /// The link of the selection's start, or null.
  String? get link {
    final r = _range;
    final s = composer.selection;
    final p = r?.start ?? s?.extent;
    if (p == null) return null;
    final node = document.getNodeById(p.nodeId);
    if (node is! TextNode) return null;
    final o = (p.nodePosition as TextNodePosition).offset;
    for (final a in node.text.getAllAttributionsAt(
      o.clamp(0, node.text.length),
    )) {
      if (a is LinkAttribution) return a.plainTextUri;
    }
    return null;
  }

  /// Whether a range is selected (links need one).
  bool get hasRange => _range != null;

  /// Sets (or with null removes) the link of the selected range.
  void setLink(String? url) {
    final r = _range;
    if (r == null) return;
    final node = document.getNodeById(r.start.nodeId);
    if (node is! TextNode) return;
    final existing = <Attribution>{
      for (final a in node.text.getAllAttributionsAt(
        (r.start.nodePosition as TextNodePosition).offset,
      ))
        if (a is LinkAttribution) a,
    };
    editor.execute([
      if (existing.isNotEmpty)
        RemoveTextAttributionsRequest(documentRange: r, attributions: existing),
      if (url != null)
        AddTextAttributionsRequest(
          documentRange: r,
          attributions: {LinkAttribution(url)},
        ),
    ]);
  }

  // ------------------------------------------------------------- end

  /// Ends the session: writes pending edits and detaches.
  SlidesPlan? close() {
    if (_closed) return null;
    final plan = commit();
    _closed = true;
    session.model.removeListener(_onBatch);
    return plan;
  }

  @override
  void dispose() {
    close();
    _timer?.cancel();
    for (final a in addons) {
      a.dispose();
    }
    addons.clear();
    editor.dispose();
    super.dispose();
  }
}
