import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_sheets_core/formula.dart' show RecalcBatch;
import 'package:wonky_sheets_core/model.dart';

import '../charts/controller/chart_controller.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// A move or resize in progress (08 §9.3): the live ghost rectangle (sheet
/// px at 100 % zoom) and the guides to draw.
@immutable
class ObjectDrag {
  const ObjectDrag(this.objectId, this.rect, {this.guides = const []});

  final String objectId;
  final ChartRect rect;
  final List<SnapGuide> guides;
}

/// A request to show a chart editor section ([section] null = Setup tab).
@immutable
class ChartEditorJump {
  const ChartEditorJump({this.section, this.seriesKey, this.serial = 0});

  /// `titles`, `series`, `legend`, `hAxis`, `vAxis`, `gridlines`, `style`.
  final String? section;
  final String? seriesKey;
  final int serial;
}

/// The embedded objects of an open spreadsheet (08 §9): the sorted objects
/// per sheet, the object selection and focus, the drag ghost, and one
/// [ChartController] per chart, re-resolved (debounced) when source cells
/// change locally or remotely (08 §4.3).
///
/// One instance per [SheetEditorController] ([of]); the editor screen's
/// objects host disposes it.
class ObjectsController extends ChangeNotifier {
  ObjectsController._(this.editor) {
    editor.model.addListener(_onBatch);
    _recalc = editor.engine.changes.listen(_onRecalc);
    editor.addListener(_onEditor);
    _sheet = editor.activeSheetId;
  }

  static final Expando<ObjectsController> _registry = Expando(
    'ObjectsController',
  );

  /// The controller of [editor] (created on first use).
  static ObjectsController of(SheetEditorController editor) =>
      _registry[editor] ??= ObjectsController._(editor);

  /// The controller of [editor] if one was created.
  static ObjectsController? maybeOf(SheetEditorController editor) =>
      _registry[editor];

  final SheetEditorController editor;

  /// Keyboard focus of the object layer (08 §9.2 `ObjectFocusNode`).
  final FocusNode focus = FocusNode(debugLabel: 'sheets.objects');

  /// Where the chart editor panel should jump (08 §6.5: a double-click on a
  /// chart element opens the matching Customize section).
  final ValueNotifier<ChartEditorJump> editorJump = ValueNotifier(
    const ChartEditorJump(),
  );

  StreamSubscription<RecalcBatch>? _recalc;
  String _sheet = '';
  String? _selected;
  ObjectDrag? _drag;
  bool _disposed = false;

  final Map<String, ChartController> _charts = {};
  final Map<String, (String, ObjectAnchor?)> _anchors = {};
  final Map<String, List<EmbeddedObjectRecord>> _sorted = {};

  Timer? _debounce;
  DateTime? _firstPending;
  final Set<String> _pendingSheets = {};

  /// Debounce of chart data updates (08 §4.3: trailing 150 ms, max 500 ms).
  static const debounce = Duration(milliseconds: 150);
  static const maxWait = Duration(milliseconds: 500);

  WorkbookModel get model => editor.model;

  // ---------------------------------------------------------------------------
  // Objects.

  /// Objects of [sheetId] in paint order (bottom first, 08 §9.4).
  List<EmbeddedObjectRecord> objectsOn(String sheetId) =>
      _sorted.putIfAbsent(sheetId, () {
        final s = model.sheet(sheetId);
        if (s == null) return const [];
        final list = s.objects.values.toList()
          ..sort((a, b) {
            final z = a.zIndex.compareTo(b.zIndex);
            return z != 0 ? z : a.id.compareTo(b.id);
          });
        return list;
      });

  /// Objects of the active sheet in paint order.
  List<EmbeddedObjectRecord> get activeObjects =>
      objectsOn(editor.activeSheetId);

  /// The object [id] (any sheet).
  EmbeddedObjectRecord? record(String? id) {
    if (id == null) return null;
    for (final s in model.sheets) {
      final o = s.objects[id];
      if (o != null) return o;
    }
    return null;
  }

  /// The parsed anchor of [o] (cached per anchor JSON).
  ObjectAnchor? anchorOf(EmbeddedObjectRecord o) {
    final hit = _anchors[o.id];
    if (hit != null && hit.$1 == o.anchorJson) return hit.$2;
    final a = ObjectAnchor.tryParse(o.anchorJson);
    _anchors[o.id] = (o.anchorJson, a);
    return a;
  }

  /// Sheet px rectangle (100 % zoom) of [o]: the drag ghost while it is
  /// dragged, null for chart-sheet or broken anchors.
  ChartRect? rectOf(EmbeddedObjectRecord o, {bool ghost = true}) {
    final d = _drag;
    if (ghost && d != null && d.objectId == o.id) return d.rect;
    final s = model.sheet(o.sheetId);
    final a = anchorOf(o);
    if (s == null || a == null) return null;
    return a.rectIn(s.rows, s.columns);
  }

  /// The anchor cell (row, col) of [o], or null.
  (int, int)? anchorCell(EmbeddedObjectRecord o) {
    final s = model.sheet(o.sheetId);
    final a = anchorOf(o);
    if (s == null || a == null || a.ownSheet) return null;
    final r = s.rows.indexOf(a.rowId!);
    final c = s.columns.indexOf(a.colId!);
    if (r < 0 || c < 0) return null;
    return (r, c);
  }

  /// Z-order items of [sheetId] (08 §9.4).
  List<ZOrderItem> zItems(String sheetId) {
    final s = model.sheet(sheetId);
    if (s == null) return const [];
    return ZOrder.itemsOf(s);
  }

  // ---------------------------------------------------------------------------
  // Selection (08 §9.2).

  String? get selectedId => _selected;

  EmbeddedObjectRecord? get selected => record(_selected);

  bool isSelected(String id) => _selected == id;

  /// Selects [id] (null deselects). Selecting moves keyboard focus to the
  /// object layer; deselecting returns it to the grid.
  void select(String? id, {bool focus = true}) {
    if (id == _selected) {
      if (id != null && focus) this.focus.requestFocus();
      return;
    }
    _selected = id;
    if (id != null && focus) {
      if (editor.editor.isEditing) editor.editor.commitSync();
      this.focus.requestFocus();
    } else if (id == null && this.focus.hasFocus) {
      editor.gridFocus.requestFocus();
    }
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Drag ghost.

  ObjectDrag? get drag => _drag;

  set drag(ObjectDrag? d) {
    _drag = d;
    _changed();
  }

  // ---------------------------------------------------------------------------
  // Charts.

  /// The chart controller of [o] (kept in sync with its spec).
  ChartController chartOf(EmbeddedObjectRecord o) {
    final c = _charts[o.id];
    if (c != null) {
      c.updateSpec(o.specJson);
      return c;
    }
    return _charts[o.id] = ChartController(editor, o.id, o.specJson);
  }

  /// The chart controller of object [id] if it is a chart.
  ChartController? chartById(String id) {
    final o = record(id);
    if (o == null || o.kind != EmbeddedObjectKind.chart) return null;
    return chartOf(o);
  }

  // ---------------------------------------------------------------------------
  // Change tracking.

  void _onEditor() {
    if (editor.activeSheetId != _sheet) {
      _sheet = editor.activeSheetId;
      final sel = selected;
      if (sel != null && sel.sheetId != _sheet) select(null, focus: false);
      _changed();
    }
  }

  void _onBatch(WorkbookChangeBatch batch) {
    var objects = false;
    for (final e in batch.events) {
      switch (e) {
        case RulesChanged(:final kind) when kind == RuleKind.object:
          objects = true;
        case StructureChanged(:final sheetId):
          objects = true;
          _scheduleData(sheetId);
        case SheetsChanged():
          objects = true;
        case CellsChanged(:final sheetId):
          _scheduleData(sheetId);
        case SpreadsheetChanged():
          // Theme or locale: re-lay out every chart.
          for (final c in _charts.values) {
            c.invalidateData();
          }
        default:
          break;
      }
    }
    if (!objects) return;
    _sorted.clear();
    // Forget removed objects.
    final alive = <String>{for (final s in model.sheets) ...s.objects.keys};
    _charts.removeWhere((id, c) {
      final gone = !alive.contains(id);
      if (gone) c.dispose();
      return gone;
    });
    _anchors.removeWhere((id, _) => !alive.contains(id));
    if (_selected != null && !alive.contains(_selected)) {
      _selected = null;
      if (focus.hasFocus) editor.gridFocus.requestFocus();
    }
    for (final s in model.sheets) {
      for (final o in s.objects.values) {
        _charts[o.id]?.updateSpec(o.specJson);
      }
    }
    _changed();
  }

  void _onRecalc(RecalcBatch batch) {
    for (final c in batch.cells) {
      _pendingSheets.add(c.sheetId);
    }
    for (final s in batch.spillRects.keys) {
      _pendingSheets.add(s);
    }
    _schedule();
  }

  void _scheduleData(String sheetId) {
    _pendingSheets.add(sheetId);
    _schedule();
  }

  void _schedule() {
    if (_charts.isEmpty) {
      _pendingSheets.clear();
      return;
    }
    final now = DateTime.now();
    _firstPending ??= now;
    _debounce?.cancel();
    final waited = now.difference(_firstPending!);
    final wait = waited >= maxWait - debounce ? Duration.zero : debounce;
    _debounce = Timer(wait, flushData);
  }

  /// Re-resolves the charts whose sources changed (tests call it directly).
  void flushData() {
    _debounce?.cancel();
    _debounce = null;
    _firstPending = null;
    if (_disposed) return;
    final sheets = Set.of(_pendingSheets);
    _pendingSheets.clear();
    for (final c in _charts.values) {
      if (c.sourceSheets.any(sheets.contains)) c.invalidateData();
    }
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    editor.model.removeListener(_onBatch);
    editor.removeListener(_onEditor);
    unawaited(_recalc?.cancel());
    for (final c in _charts.values) {
      c.dispose();
    }
    _charts.clear();
    focus.dispose();
    editorJump.dispose();
    _registry[editor] = null;
    super.dispose();
  }
}
