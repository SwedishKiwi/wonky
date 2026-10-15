import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../editor_screen/deck_editor_controller.dart';
import 'reading_order.dart';
import 'slide_elements.dart';

/// What has keyboard focus inside the canvas (03 §1.1, §3.1).
enum CanvasFocus {
  /// Elements (or nothing) selected on the canvas.
  canvas,

  /// A text body is being edited (SL-13).
  text,

  /// A table cell range (SL-15).
  table,

  /// Image crop mode (SL-15).
  crop,
}

/// The selection model of the canvas (03 §1.1 `SelectionController`, §3):
/// the selected element ids of the current slide (stored in the editor,
/// [DeckEditorController.selectedElementIds], so the chrome, undo
/// snapshots and MCP see them), the **entered group** (selecting inside an
/// element group), the marquee rectangle, and per-slide memory (changing
/// the slide clears the selection; returning restores it in the session).
///
/// API for the element work packages (SL-13…SL-15): [select], [toggle],
/// [clear], [enterGroup], [escape], [selectAll], [cycle], [focus] and the
/// resolved [elements] of the current slide. Selection is view state:
/// never undoable, but undo/redo restore it through the editor's snapshots.
class SelectionController extends ChangeNotifier {
  SelectionController(this.editor) {
    _slideId = editor.surfaceId;
    _lastIds = editor.selectedElementIds;
    editor.addListener(_onEditor);
  }

  final DeckEditorController editor;

  String? _slideId;
  String? _entered;
  List<String> _lastIds = const [];
  final Map<String, (List<String>, String?)> _memory = {};
  SuRect? _marquee;
  bool _disposed = false;

  // ------------------------------------------------------------- reading

  /// The selected element ids (current slide).
  List<String> get ids => editor.selectedElementIds;

  /// Whether nothing is selected.
  bool get isEmpty => ids.isEmpty;

  /// The resolved current slide (or the layout/master edited in masters
  /// mode, SL-28), or null in an empty deck.
  ResolvedSlide? get slide {
    final id = editor.surfaceId;
    return id == null ? null : editor.resolver.resolve(id);
  }

  /// The element index of the current slide.
  SlideElements? get elements {
    final s = slide;
    return s == null ? null : SlideElements.of(s);
  }

  /// The selected elements (resolved, slide space).
  List<ResolvedElement> get selected {
    final els = elements;
    if (els == null) return const [];
    return [for (final id in ids) ?els[id]];
  }

  /// The innermost entered element group (03 §3.1 *Inside group*), or null.
  String? get enteredGroupId {
    final g = _entered;
    if (g == null) return null;
    final e = elements?[g];
    return e != null && e.record.kind == ElementKind.group ? g : null;
  }

  /// What has focus inside the canvas.
  CanvasFocus get focus =>
      editor.textEditing ? CanvasFocus.text : CanvasFocus.canvas;

  /// The live marquee (slide space) while dragging one, else null.
  SuRect? get marquee => _marquee;

  set marquee(SuRect? r) {
    if (r == _marquee) return;
    _marquee = r;
    notifyListeners();
  }

  /// The elements selection acts on: the entered group's children, else
  /// the slide's top-level elements.
  List<ResolvedElement> get scope =>
      elements?.siblings(enteredGroupId) ?? const [];

  // ------------------------------------------------------------- writing

  /// Selects [ids] (elements of the current slide). [enteredGroup] sets the
  /// entered group; by default it is the common parent of [ids].
  void select(Iterable<String> ids, {String? enteredGroup}) {
    final els = elements;
    final list = [
      for (final id in ids)
        if (els != null && els.contains(id)) id,
    ];
    _entered = enteredGroup ?? _commonParent(list);
    editor.textEditing = false;
    editor.selectElements(list);
  }

  String? _commonParent(List<String> ids) {
    final els = elements;
    if (els == null || ids.isEmpty) return null;
    final parents = {for (final id in ids) els.parentOf(id)?.id};
    return parents.length == 1 ? parents.single : null;
  }

  /// Adds [id] to the selection, or removes it (Shift/Mod+click). An
  /// element of another group replaces the selection.
  void toggle(String id) {
    final els = elements;
    if (els == null || !els.contains(id)) return;
    final cur = ids;
    if (cur.contains(id)) {
      select([
        for (final x in cur)
          if (x != id) x,
      ], enteredGroup: _entered);
      return;
    }
    final parent = els.parentOf(id)?.id;
    final sameScope = cur.every((x) => els.parentOf(x)?.id == parent);
    select(sameScope ? [...cur, id] : [id]);
  }

  /// Clears the selection and leaves entered groups.
  void clear() {
    _entered = null;
    editor.clearElementSelection();
    notifyListeners();
  }

  /// Enters element group [groupId] and selects [childId] (or nothing).
  void enterGroup(String groupId, {String? childId}) {
    final g = elements?[groupId];
    if (g == null || g.record.kind != ElementKind.group) return;
    _entered = groupId;
    editor.textEditing = false;
    editor.selectElements([?childId]);
    notifyListeners();
  }

  /// Esc (03 §3.3): text editing → the element; inside a group → the
  /// group; elements → none. Returns whether anything changed.
  bool escape() {
    if (editor.textEditing) {
      editor.textEditing = false;
      editor.selectElements(ids);
      return true;
    }
    final g = enteredGroupId;
    if (g != null) {
      select([g], enteredGroup: elements?.parentOf(g)?.id);
      return true;
    }
    if (ids.isNotEmpty) {
      clear();
      return true;
    }
    return false;
  }

  /// Every selectable element of the scope (Mod+A on the canvas).
  void selectAll() => select([
    for (final e in scope)
      if (SlideElements.selectable(e)) e.id,
  ], enteredGroup: enteredGroupId);

  /// Tab / Shift+Tab (03 §3.3): the next/previous element of the scope in
  /// reading order (wrapping). Returns the new id, or null.
  String? cycle(int direction) {
    final s = slide;
    if (s == null) return null;
    final order = [
      for (final e in ReadingOrder.of(scope, slideHeight: s.bounds.height))
        if (SlideElements.selectable(e)) e.id,
    ];
    if (order.isEmpty) return null;
    final cur = ids.isEmpty ? -1 : order.indexOf(ids.last);
    final int next;
    if (cur < 0) {
      next = direction > 0 ? 0 : order.length - 1;
    } else {
      next = (cur + direction) % order.length;
    }
    select([order[next]], enteredGroup: enteredGroupId);
    return order[next];
  }

  // ---------------------------------------------------------- slide memo

  void _onEditor() {
    if (_disposed) return;
    final cur = editor.surfaceId;
    if (cur != _slideId) {
      final old = _slideId;
      if (old != null) _memory[old] = (_lastIds, _entered);
      _slideId = cur;
      _entered = null;
      _marquee = null;
      final m = cur == null ? null : _memory[cur];
      if (m != null && editor.selectedElementIds.isEmpty) {
        final els = elements;
        final alive = [
          for (final id in m.$1)
            if (els != null && els.contains(id)) id,
        ];
        _entered = m.$2;
        if (alive.isNotEmpty) {
          _lastIds = alive;
          editor.selectElements(alive);
          return;
        }
      }
    }
    _lastIds = editor.selectedElementIds;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    editor.removeListener(_onEditor);
    super.dispose();
  }
}
