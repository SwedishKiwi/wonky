import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Offset;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';

import '../editor_screen/deck_editor_controller.dart';
import 'navigator_drop.dart';
import 'navigator_model.dart';

final Expando<NavigatorController> _controllers = Expando('slidesNavigator');

/// The navigator view state of an editor (created on first use; shared by
/// the navigator, the grid view and the commands).
NavigatorController navigatorOf(DeckEditorController editor) =>
    _controllers[editor] ??= NavigatorController(editor);

/// A drag of navigator rows or grid tiles (04 §5.10): what is dragged, the
/// pointer, the resolved drop and Alt (copy). Live preview only — nothing
/// is written until the drop.
class NavDragState {
  NavDragState({
    required this.selection,
    required this.pointer,
    this.label = '',
    this.firstSlideId,
  });

  final NavSelection selection;

  /// The pointer in the dragging surface's global coordinates.
  Offset pointer;

  /// "3 slides" / "Intro · 5 slides" (ghost badge).
  final String label;

  /// The slide shown on the ghost.
  final String? firstSlideId;

  /// The current drop position (null = outside / cancelled position).
  NavDrop? drop;

  /// Alt (Option) held: the drop copies.
  bool copy = false;
}

/// The slide navigator's view state (Slides 04 §5): collapsed groups (per
/// user and device: `LocalViewState.collapsedGroups` under
/// `slides.view.<deckId>`, never synced, not undoable), the visible rows,
/// the keyboard focus row and Shift anchor, the inline rename, the
/// insertion point, the live drag and the grid-view thumbnail size.
///
/// The selection itself lives in the editor ([DeckEditorController
/// .selectSlides], current slide included); the click and keyboard helpers
/// here translate gestures into it (04 §5.5).
class NavigatorController extends ChangeNotifier {
  NavigatorController(this.editor) {
    _lastCurrent = editor.currentSlideId;
    editor.addListener(_onEditor);
    unawaited(_load());
  }

  final DeckEditorController editor;
  bool _disposed = false;

  SlideOrder get order => editor.order;

  // ------------------------------------------------------------- collapse

  final Set<String> _collapsed = {};

  /// Collapsed group ids (existing groups only).
  Set<String> get collapsed => {
    for (final id in _collapsed)
      if (editor.model.group(id) != null) id,
  };

  bool isCollapsed(String groupId) => _collapsed.contains(groupId);

  /// Collapses or expands [groupIds]; returns whether anything changed.
  bool setCollapsed(Iterable<String> groupIds, bool collapse) {
    var changed = false;
    for (final id in groupIds) {
      changed |= collapse ? _collapsed.add(id) : _collapsed.remove(id);
    }
    if (changed) {
      _rows = null;
      _save();
      notifyListeners();
    }
    return changed;
  }

  void toggleCollapsed(String groupId) =>
      setCollapsed([groupId], !isCollapsed(groupId));

  // ------------------------------------------------------- grid view size

  double _gridThumbSize = 200;

  /// The grid view's thumbnail width (120–480 px, 04 §9; device pref).
  double get gridThumbSize => _gridThumbSize;

  void setGridThumbSize(double size, {bool commit = true}) {
    final v = size.clamp(120.0, 480.0);
    if (v == _gridThumbSize) return;
    _gridThumbSize = v;
    if (commit) _save();
    notifyListeners();
  }

  // ----------------------------------------------------------- persistence

  String get _storeKey => 'slides.view.${editor.session.deckId}';

  Future<void> _load() async {
    try {
      final raw = await editor.services.userStore.read(_storeKey);
      final m = _decode(raw);
      if (_disposed || m == null) return;
      final c = m['collapsedGroups'];
      if (c is List) {
        _collapsed.addAll(c.whereType<String>());
        // A current slide inside a restored collapsed group stays visible.
        final cur = editor.currentEntry?.groupId;
        if (cur != null) _collapsed.remove(cur);
      }
      final g = m['gridThumbSize'];
      if (g is num) _gridThumbSize = g.toDouble().clamp(120.0, 480.0);
      _rows = null;
      notifyListeners();
    } catch (_) {
      // Unreadable view state: defaults.
    }
  }

  static Map<String, Object?>? _decode(Object? raw) {
    Object? v = raw;
    if (v is String) {
      try {
        v = jsonDecode(v);
      } catch (_) {
        return null;
      }
    }
    return v is Map ? v.cast<String, Object?>() : null;
  }

  /// Merges this state into the deck's `LocalViewState` (other keys of
  /// `slides.view.<deckId>` are kept).
  void _save() {
    final store = editor.services.userStore;
    final collapsed = [...this.collapsed]..sort();
    final size = _gridThumbSize;
    unawaited(() async {
      try {
        final m = _decode(await store.read(_storeKey)) ?? {};
        m['collapsedGroups'] = collapsed;
        m['gridThumbSize'] = size;
        await store.write(_storeKey, jsonEncode(m));
      } catch (_) {
        // Best effort (view state).
      }
    }());
  }

  // ------------------------------------------------------------------ rows

  List<NavRow>? _rows;
  SlideOrder? _rowsOrder;

  /// The visible rows (rebuilt when the order or the collapse state
  /// changes).
  List<NavRow> get rows {
    final o = order;
    if (_rows == null || !identical(o, _rowsOrder)) {
      _rowsOrder = o;
      _rows = buildNavRows(o, collapsed);
    }
    return _rows!;
  }

  /// The selection of the editor as units (04 §5.5).
  NavSelection get selection => NavSelection.of(
    order,
    slides: editor.selectedSlideIds,
    groups: editor.selectedGroupIds,
  );

  // ------------------------------------------------- focus, anchor, select

  String? _focusKey;
  String? _anchorKey;

  /// The keyboard focus row (a header can have focus without changing the
  /// current slide, 04 §5.9).
  String? get focusKey {
    final k = _focusKey;
    if (k != null && rows.any((r) => r.key == k)) return k;
    final cur = editor.currentSlideId;
    if (cur == null) return null;
    final slideKey = 'slide:$cur';
    if (rows.any((r) => r.key == slideKey)) return slideKey;
    final g = editor.currentEntry?.groupId;
    return g == null ? null : 'group:$g';
  }

  bool _navChange = false;

  /// Runs [f] as a navigator-initiated selection change (no auto-expand).
  void _nav(void Function() f) {
    _navChange = true;
    try {
      f();
    } finally {
      _navChange = false;
    }
  }

  void setFocus(String? key) {
    if (_focusKey == key) return;
    _focusKey = key;
    notifyListeners();
  }

  /// A click on a slide (04 §5.5): alone, Shift = range from the anchor in
  /// visible order, [toggle] (Mod) = toggle.
  void clickSlide(String slideId, {bool range = false, bool toggle = false}) {
    final key = 'slide:$slideId';
    clearInsertion();
    if (range && _anchorKey != null) {
      _selectRange(_anchorKey!, key);
    } else if (toggle) {
      final slides = {...editor.selectedSlideIds};
      final groups = {...editor.selectedGroupIds};
      if (!slides.remove(slideId)) slides.add(slideId);
      _nav(() {
        if (slides.isEmpty && groups.isEmpty) {
          editor.setCurrentSlide(slideId);
        } else {
          editor.selectSlides(slides, groups: groups);
        }
      });
      _anchorKey = key;
    } else {
      _nav(() => editor.setCurrentSlide(slideId));
      _anchorKey = key;
    }
    _focusKey = key;
    notifyListeners();
  }

  /// A click on a group header (04 §5.5): the group is selected (its
  /// slides count as selected) and the current slide moves to its first
  /// slide unless it is already in the group.
  void clickGroup(String groupId, {bool range = false, bool toggle = false}) {
    final key = 'group:$groupId';
    clearInsertion();
    if (range && _anchorKey != null) {
      _selectRange(_anchorKey!, key);
    } else if (toggle) {
      final groups = {...editor.selectedGroupIds};
      final slides = {...editor.selectedSlideIds};
      final members = _members(groupId);
      if (groups.remove(groupId)) {
        slides.removeAll(members);
      } else {
        groups.add(groupId);
        slides.addAll(members);
      }
      _nav(() => editor.selectSlides(slides, groups: groups));
      _anchorKey = key;
    } else {
      selectGroups([groupId]);
      _anchorKey = key;
    }
    _focusKey = key;
    notifyListeners();
  }

  /// Selects [groupIds] (with their slides); the current slide moves to the
  /// first one's first slide when it is outside them.
  void selectGroups(List<String> groupIds) {
    final slides = [for (final g in groupIds) ..._members(g)];
    _nav(() {
      final cur = editor.currentEntry;
      editor.selectSlides(slides, groups: groupIds);
      if (slides.isEmpty) return;
      editor.setCurrentSlide(
        cur != null && groupIds.contains(cur.groupId) ? cur.id : slides.first,
        select: false,
      );
    });
  }

  /// A click below the rows: the selection clears to the current slide.
  void clickEmpty() {
    final cur = editor.currentSlideId;
    _nav(() {
      if (cur != null) editor.setCurrentSlide(cur);
    });
    _anchorKey = cur == null ? null : 'slide:$cur';
  }

  List<String> _members(String groupId) {
    final r = order.range(groupId);
    if (r == null) return const [];
    return [for (var i = r.start; i < r.end; i++) order.entries[i].id];
  }

  void _selectRange(String fromKey, String toKey) {
    final rows = this.rows;
    var a = rows.indexWhere((r) => r.key == fromKey);
    var b = rows.indexWhere((r) => r.key == toKey);
    if (a < 0) a = b;
    if (b < 0) return;
    if (a > b) (a, b) = (b, a);
    final slides = <String>[];
    final groups = <String>[];
    for (var i = a; i <= b; i++) {
      final r = rows[i];
      switch (r.kind) {
        case NavRowKind.slide:
          slides.add(r.id);
        case NavRowKind.group:
          // A collapsed group in the range is included as a whole; an
          // expanded one at an end of the range too.
          if (r.collapsed || r.key == fromKey || r.key == toKey) {
            groups.add(r.id);
            slides.addAll(_members(r.id));
          }
        case NavRowKind.emptyGroup:
          break;
      }
    }
    _nav(() {
      final keepCurrent = editor.currentSlideId;
      editor.selectSlides(slides, groups: groups);
      if (keepCurrent != null && slides.contains(keepCurrent)) {
        editor.setCurrentSlide(keepCurrent, select: false);
      } else if (toKey.startsWith('slide:')) {
        editor.setCurrentSlide(toKey.substring(6), select: false);
      }
    });
  }

  /// Selects every slide (⌘A in the navigator).
  void selectAll() {
    _nav(() {
      final cur = editor.currentSlideId;
      editor.selectSlides([for (final e in order.entries) e.id]);
      if (cur != null) editor.setCurrentSlide(cur, select: false);
    });
    notifyListeners();
  }

  /// Moves the focus row by [delta] (↑/↓); slides become current, headers
  /// only get focus. With [extend] (Shift) the selection extends from the
  /// anchor.
  void moveFocus(int delta, {bool extend = false}) {
    final rows = [
      for (final r in this.rows)
        if (r.kind != NavRowKind.emptyGroup) r,
    ];
    if (rows.isEmpty) return;
    final at = rows.indexWhere((r) => r.key == focusKey);
    final i = at < 0 ? 0 : (at + delta).clamp(0, rows.length - 1);
    focusRow(rows[i], extend: extend);
  }

  /// Focuses the first (or last) row (Home / End).
  void focusEdge({required bool last, bool extend = false}) {
    final rows = [
      for (final r in this.rows)
        if (r.kind != NavRowKind.emptyGroup) r,
    ];
    if (rows.isEmpty) return;
    focusRow(last ? rows.last : rows.first, extend: extend);
  }

  void focusRow(NavRow row, {bool extend = false}) {
    clearInsertion();
    if (extend) {
      _anchorKey ??= focusKey;
      _focusKey = row.key;
      _selectRange(_anchorKey ?? row.key, row.key);
    } else {
      _focusKey = row.key;
      _anchorKey = row.key;
      if (row.isSlide) _nav(() => editor.setCurrentSlide(row.id));
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- type-ahead

  String _typed = '';
  DateTime _typedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Type-ahead (04 §5.9): letters jump to the next group whose title
  /// starts with them. Returns whether a group matched.
  bool typeAhead(String char, {DateTime? now}) {
    final t = now ?? DateTime.now();
    _typed = t.difference(_typedAt).inMilliseconds > 900 ? char : _typed + char;
    _typedAt = t;
    final prefix = _typed.toLowerCase();
    final headers = [
      for (final r in rows)
        if (r.isGroup) r,
    ];
    if (headers.isEmpty) return false;
    final at = headers.indexWhere((r) => r.key == focusKey);
    for (var k = 1; k <= headers.length; k++) {
      // A longer prefix may still match the focused group.
      final start = _typed.length > 1 ? 0 : 1;
      final h = headers[(at + k - 1 + start) % headers.length];
      final title = editor.model.group(h.id)?.title.toLowerCase() ?? '';
      if (title.startsWith(prefix)) {
        _focusKey = h.key;
        _anchorKey = h.key;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------------ rename

  String? _renaming;

  /// The group whose title is being edited inline (04 §5.4).
  String? get renamingGroupId => _renaming;

  void startRename(String groupId) {
    if (editor.model.group(groupId) == null) return;
    _renaming = groupId;
    _focusKey = 'group:$groupId';
    if (isCollapsed(groupId)) _rows = null;
    notifyListeners();
  }

  void endRename() {
    if (_renaming == null) return;
    _renaming = null;
    notifyListeners();
  }

  // --------------------------------------------------------- insertion point

  SlideTarget? _insertion;
  double? _insertionY;
  bool _insertionInside = false;

  /// The insertion caret between rows (04 §5.8): paste and *New slide*
  /// insert there. Cleared by any selection change.
  SlideTarget? get insertion => _insertion;
  double? get insertionY => _insertionY;
  bool get insertionInside => _insertionInside;

  void setInsertion(NavDrop? at) {
    _insertion = at?.target;
    _insertionY = at?.y;
    _insertionInside = at?.inside ?? false;
    notifyListeners();
  }

  void clearInsertion() {
    if (_insertion == null) return;
    _insertion = null;
    _insertionY = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------ drag

  NavDragState? _drag;

  /// The live drag (null when not dragging).
  NavDragState? get drag => _drag;

  void startDrag(NavDragState d) {
    _drag = d;
    clearInsertion();
    notifyListeners();
  }

  void updateDrag({Offset? pointer, NavDrop? drop, bool? copy}) {
    final d = _drag;
    if (d == null) return;
    if (pointer != null) d.pointer = pointer;
    d.drop = drop;
    if (copy != null) d.copy = copy;
    notifyListeners();
  }

  /// Ends the drag; returns its final state (null when there was none).
  NavDragState? endDrag() {
    final d = _drag;
    _drag = null;
    if (d != null) notifyListeners();
    return d;
  }

  // ----------------------------------------------------------- editor sync

  String? _lastCurrent;

  void _onEditor() {
    if (_disposed) return;
    final cur = editor.currentSlideId;
    if (cur != _lastCurrent) {
      _lastCurrent = cur;
      // A current slide set from elsewhere (search, comments, `?slide=`,
      // PageDown) expands its collapsed group (04 §5.3).
      final g = editor.currentEntry?.groupId;
      if (!_navChange && g != null && isCollapsed(g)) {
        setCollapsed([g], false);
        return;
      }
      if (!_navChange) _focusKey = null;
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    editor.removeListener(_onEditor);
    super.dispose();
  }
}
