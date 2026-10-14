import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../charts3d/orbit/chart_orbit.dart';
import '../collab/sheets_collab.dart';
import '../charts/controller/chart_controller.dart';
import '../charts/view/chart_sheet_view.dart';
import '../charts/view/chart_view.dart';
import '../grid/viewport/grid_geometry.dart';
import '../images/image_object_view.dart';
import '../images/image_service.dart';
import '../images/rich_cell_layer.dart';
import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../toolbar/command_ui.dart';
import 'object_menu.dart';
import 'objects_controller.dart';

/// Key scope of a selected object (08 §9.2): arrows nudge, Del deletes,
/// Enter edits, Esc returns to the grid, Mod+C/X/V/D.
const objectKeyScope = KeyScope('sheetsObject');

/// Screen rectangle of the sheet-px rectangle [r] in [pane].
Rect objectScreenRect(GridGeometry g, GridPane pane, ChartRect r) {
  final cols = g.sheet.columns;
  final rows = g.sheet.rows;
  final x =
      pane.rect.left +
      (r.left - cols.offsetOf(pane.firstCol)) * g.zoom -
      pane.scrollX;
  final y =
      pane.rect.top +
      (r.top - rows.offsetOf(pane.firstRow)) * g.zoom -
      pane.scrollY;
  return Rect.fromLTWH(x, y, r.width * g.zoom, r.height * g.zoom);
}

/// Hosts the objects layer over the grid (08 §9.1): charts and images as
/// positioned widgets (each in a `RepaintBoundary`, so scrolling only moves
/// them) clipped to the pane of their anchor cell, the selection frame with
/// resize handles, smart guides, and the chart-sheet view replacing the grid
/// on chart sheets (08 §11).
class SheetObjectsHost extends StatefulWidget {
  const SheetObjectsHost({
    super.key,
    required this.editor,
    required this.services,
    required this.child,
  });

  final SheetEditorController editor;
  final ShellServices services;

  /// The grid.
  final Widget child;

  @override
  State<SheetObjectsHost> createState() => _SheetObjectsHostState();
}

class _SheetObjectsHostState extends State<SheetObjectsHost> {
  late final ObjectsController objects = ObjectsController.of(widget.editor);
  late final RichCellLayer _richCells = RichCellLayer(
    SheetsImageService.of(widget.editor),
  );

  @override
  void initState() {
    super.initState();
    widget.editor.layers.add(_richCells);
  }

  @override
  void dispose() {
    widget.editor.layers.remove(_richCells);
    objects.dispose();
    super.dispose();
  }

  /// A press outside every object deselects (the grid takes focus itself).
  void _onAnyDown(PointerDownEvent e) {
    if (_ObjectsOverlayState.consumedPointer == e.pointer) return;
    if (objects.selectedId != null) objects.select(null, focus: false);
  }

  @override
  Widget build(BuildContext context) {
    final ed = widget.editor;
    return ListenableBuilder(
      listenable: ed,
      builder: (context, _) {
        final chartSheet = ed.activeSheet?.record?.kind == SheetKind.chart;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onAnyDown,
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              Positioned.fill(
                child: _ObjectsOverlay(
                  editor: ed,
                  services: widget.services,
                  objects: objects,
                ),
              ),
              if (chartSheet)
                Positioned.fill(
                  child: ChartSheetView(
                    key: ValueKey<String>(
                      'sheets.chartSheet.${ed.activeSheetId}',
                    ),
                    editor: ed,
                    services: widget.services,
                    objects: objects,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _Mode { none, pending, move, resize }

class _ObjectsOverlay extends StatefulWidget {
  const _ObjectsOverlay({
    required this.editor,
    required this.services,
    required this.objects,
  });

  final SheetEditorController editor;
  final ShellServices services;
  final ObjectsController objects;

  @override
  State<_ObjectsOverlay> createState() => _ObjectsOverlayState();
}

class _ObjectsOverlayState extends State<_ObjectsOverlay> {
  /// Pointer id of the last press handled by an object (the host's
  /// deselect listener runs after the object's).
  static int? consumedPointer;

  SheetEditorController get ed => widget.editor;
  ObjectsController get objects => widget.objects;

  _Mode _mode = _Mode.none;
  String? _dragId;
  ResizeHandle? _handle;
  Offset _start = Offset.zero;
  Offset _last = Offset.zero;
  ChartRect? _startRect;
  double _scrollX0 = 0;
  double _scrollY0 = 0;
  PaneKind _pane = PaneKind.main;
  Timer? _autoScroll;
  DateTime? _lastDown;
  String? _lastDownId;
  Size _size = Size.zero;

  /// Start rectangles of the other selected objects of a group move.
  Map<String, ChartRect> _groupStart = const {};

  /// A press on a member of a multi-selection selects only it when the
  /// pointer goes up without dragging.
  String? _collapseOnUp;

  static const double _frame = 8;

  bool get _alt => HardwareKeyboard.instance.isAltPressed;
  bool get _shift => HardwareKeyboard.instance.isShiftPressed;

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final r = widget.services.keymap.handle(
      e,
      objectKeyScope,
      context: context,
    );
    if (r == KeyEventResult.handled) return r;
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      objects.select(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Pointer.

  GridGeometry? _geometry() =>
      ed.geometryFor(_size, MediaQuery.devicePixelRatioOf(context));

  void _downOnObject(EmbeddedObjectRecord o, PointerDownEvent e) {
    consumedPointer = e.pointer;
    _collapseOnUp = null;
    if (e.buttons == kSecondaryMouseButton) {
      if (objects.isSelected(o.id)) {
        objects.focus.requestFocus();
      } else {
        objects.select(o.id);
      }
      _openMenu(o, e.position);
      return;
    }
    final kb = HardwareKeyboard.instance;
    if (kb.isShiftPressed || kb.isMetaPressed || kb.isControlPressed) {
      // Shift/Mod-click adds to or removes from the selection (08 §9.2).
      objects.toggleSelect(o.id);
      _mode = _Mode.none;
      _lastDownId = null;
      return;
    }
    final now = DateTime.now();
    final dbl =
        _lastDownId == o.id &&
        _lastDown != null &&
        now.difference(_lastDown!) < const Duration(milliseconds: 400);
    _lastDown = now;
    _lastDownId = o.id;
    final inGroup = objects.isMultiSelection && objects.isSelected(o.id);
    if (inGroup && !dbl) {
      _collapseOnUp = o.id;
      objects.focus.requestFocus();
    } else {
      objects.select(o.id);
    }
    if (dbl) {
      _mode = _Mode.none;
      _openEditor(o, e.localPosition);
      return;
    }
    // A selected 3D chart orbits instead of moving (08 §23.6).
    if (ChartPointerClaims.isClaimed(e.pointer)) {
      _mode = _Mode.none;
      return;
    }
    if (!ed.canEdit) return;
    _begin(o, e.position, _Mode.pending);
  }

  void _downOnHandle(
    EmbeddedObjectRecord o,
    ResizeHandle h,
    PointerDownEvent e,
  ) {
    consumedPointer = e.pointer;
    if (!ed.canEdit) return;
    _handle = h;
    _begin(o, e.position, _Mode.resize);
  }

  void _begin(EmbeddedObjectRecord o, Offset global, _Mode mode) {
    final rect = objects.rectOf(o, ghost: false);
    final cell = objects.anchorCell(o);
    final g = _geometry();
    if (rect == null || cell == null || g == null) return;
    _mode = mode;
    _dragId = o.id;
    _start = global;
    _last = global;
    _startRect = rect;
    _scrollX0 = ed.scroll.x;
    _scrollY0 = ed.scroll.y;
    _pane = g.paneFor(cell.$1, cell.$2).kind;
    _groupStart = mode == _Mode.pending && objects.isMultiSelection
        ? {
            for (final r in objects.selectedRecords)
              if (r.id != o.id) r.id: ?objects.rectOf(r, ghost: false),
          }
        : const {};
  }

  void _onMove(PointerMoveEvent e) {
    if (_mode == _Mode.none) return;
    _last = e.position;
    if (_mode == _Mode.pending) {
      if ((e.position - _start).distance < 3) return;
      _mode = _Mode.move;
    }
    _apply();
    _ensureAutoScroll(e.localPosition);
  }

  /// Pointer travel in sheet px, including auto-scroll of the pane.
  Offset _delta() {
    final z = ed.scroll.zoom;
    final scrollsX = _pane == PaneKind.main || _pane == PaneKind.top;
    final scrollsY = _pane == PaneKind.main || _pane == PaneKind.left;
    final d = (_last - _start) / z;
    return Offset(
      d.dx + (scrollsX ? (ed.scroll.x - _scrollX0) / z : 0),
      d.dy + (scrollsY ? (ed.scroll.y - _scrollY0) / z : 0),
    );
  }

  List<ChartRect> _others(String id) => [
    for (final o in objects.activeObjects)
      if (o.id != id && !_groupStart.containsKey(o.id))
        ?objects.rectOf(o, ghost: false),
  ];

  void _apply() {
    final id = _dragId;
    final start = _startRect;
    final sheet = ed.activeSheet;
    if (id == null || start == null || sheet == null) return;
    final d = _delta();
    var guides = const <SnapGuide>[];
    ChartRect rect;
    if (_mode == _Mode.move) {
      rect = start.translate(d.dx, d.dy);
      rect = ChartRect(
        math.max(0, rect.left),
        math.max(0, rect.top),
        rect.width,
        rect.height,
      );
      if (_alt) {
        rect = GridSnap.snapMove(rect, sheet.rows, sheet.columns);
      } else {
        final snap = SmartGuides.snapMove(rect, _others(id));
        rect = snap.rect;
        guides = snap.guides;
      }
    } else {
      final h = _handle!;
      final o = objects.record(id);
      final lock = o == null
          ? false
          : (objects.anchorOf(o)?.lockAspect ?? false);
      rect = ObjectGeometry.resizeRect(
        start,
        h,
        d.dx,
        d.dy,
        keepAspect: lock != _shift,
      );
      if (_alt) {
        rect = GridSnap.snapResize(rect, h, sheet.rows, sheet.columns);
      } else if (!(lock != _shift && h.isCorner)) {
        final snap = SmartGuides.snapResize(rect, h, _others(id));
        rect = snap.rect;
        guides = snap.guides;
      }
    }
    var group = const <String, ChartRect>{};
    if (_mode == _Mode.move && _groupStart.isNotEmpty) {
      // The whole selection moves by the primary object's offset, never
      // past the sheet's top-left.
      var dx = rect.left - start.left;
      var dy = rect.top - start.top;
      for (final r in _groupStart.values) {
        dx = math.max(dx, -r.left);
        dy = math.max(dy, -r.top);
      }
      rect = start.translate(dx, dy);
      group = {
        for (final e in _groupStart.entries) e.key: e.value.translate(dx, dy),
      };
    }
    objects.drag = ObjectDrag(id, rect, guides: guides, group: group);
  }

  Future<void> _onUp(PointerEvent e) async {
    _autoScroll?.cancel();
    _autoScroll = null;
    final mode = _mode;
    _mode = _Mode.none;
    final d = objects.drag;
    final id = _dragId;
    _dragId = null;
    final collapse = _collapseOnUp;
    _collapseOnUp = null;
    final group = _groupStart;
    _groupStart = const {};
    if (d == null || id == null || d.objectId != id) {
      if (objects.drag != null) objects.drag = null;
      // A click (no drag) on a member of a multi-selection selects it alone.
      if (collapse != null && mode != _Mode.move) objects.select(collapse);
      return;
    }
    final start = _startRect!;
    final r = d.rect;
    if (mode == _Mode.move &&
        group.isNotEmpty &&
        (r.left != start.left || r.top != start.top)) {
      await ed.invokeCommand('sheets.object.move', {
        'objectIds': [id, ...group.keys],
        'by': {'x': r.left - start.left, 'y': r.top - start.top},
      });
    } else if (mode == _Mode.move &&
        (r.left != start.left || r.top != start.top)) {
      await ed.invokeCommand('sheets.object.move', {
        'objectId': id,
        'to': {'x': r.left, 'y': r.top},
      });
    } else if (mode == _Mode.resize && r != start) {
      await ed.invokeCommand('sheets.object.resize', {
        'objectId': id,
        'width': r.width,
        'height': r.height,
        'x': r.left,
        'y': r.top,
      });
    }
    if (objects.drag?.objectId == id) objects.drag = null;
    objects.focus.requestFocus();
  }

  void _ensureAutoScroll(Offset local) {
    if (_autoScroll != null) return;
    _autoScroll = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (_mode != _Mode.move && _mode != _Mode.resize) {
        _autoScroll?.cancel();
        _autoScroll = null;
        return;
      }
      final g = _geometry();
      final box = context.findRenderObject() as RenderBox?;
      if (g == null || box == null) return;
      final p = box.globalToLocal(_last);
      final r = g.main.rect;
      const edge = 24.0;
      double dx = 0;
      double dy = 0;
      if (p.dx > r.right - edge) {
        dx = (p.dx - (r.right - edge)).clamp(0, 60).toDouble();
      }
      if (p.dx < r.left + edge && p.dx > g.rowHeaderWidth) {
        dx = -((r.left + edge) - p.dx).clamp(0, 60).toDouble();
      }
      if (p.dy > r.bottom - edge) {
        dy = (p.dy - (r.bottom - edge)).clamp(0, 60).toDouble();
      }
      if (p.dy < r.top + edge && p.dy > g.colHeaderHeight) {
        dy = -((r.top + edge) - p.dy).clamp(0, 60).toDouble();
      }
      if (dx == 0 && dy == 0) return;
      ed.scroll.scrollBy(dx, dy);
      _apply();
    });
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(e, (event) {
        final s = event as PointerScrollEvent;
        var dx = s.scrollDelta.dx;
        var dy = s.scrollDelta.dy;
        if (_shift && dx == 0) {
          dx = dy;
          dy = 0;
        }
        ed.scroll.scrollBy(dx, dy);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Menus and editors.

  void _openMenu(EmbeddedObjectRecord o, Offset global) {
    final multi = objects.isMultiSelection && objects.isSelected(o.id);
    WonkyPopupMenuHost.maybeOf(context)?.show(
      global,
      () => multi
          ? multiObjectMenu(
              CommandUi(context, widget.services),
              ed,
              objects.selectedIds,
            )
          : objectMenu(CommandUi(context, widget.services), ed, o),
      onClosed: () {
        if (objects.selectedId == o.id) objects.focus.requestFocus();
      },
    );
  }

  void _openEditor(EmbeddedObjectRecord o, Offset local) {
    if (o.kind == EmbeddedObjectKind.chart) {
      final c = objects.chartOf(o);
      final rect = objects.rectOf(o);
      String? section;
      String? series;
      if (rect != null) {
        final z = ed.scroll.zoom;
        final scene = c.sceneFor(
          rect.width,
          rect.height,
          dark: chartDarkOf(context),
          tokens: chartUiTokensOf(context),
        );
        final hit = scene.hitTest(local.dx / z, local.dy / z, tolerance: 4);
        (section, series) = switch (hit?.tag.role) {
          SceneRole.title ||
          SceneRole.subtitle ||
          SceneRole.axisTitle => ('titles', null),
          SceneRole.series ||
          SceneRole.point ||
          SceneRole.dataLabel ||
          SceneRole.trendline => ('series', hit?.tag.seriesKey),
          SceneRole.legend || SceneRole.legendEntry => ('legend', null),
          SceneRole.axisLabel || SceneRole.axisLine => (
            hit?.tag.detail == 'h' ? 'hAxis' : 'vAxis',
            null,
          ),
          SceneRole.gridline || SceneRole.tick => ('gridlines', null),
          _ => (null, null),
        };
      }
      unawaited(
        ed.invokeCommand('sheets.chart.edit', {
          'objectId': o.id,
          'section': ?section,
          'seriesKey': ?series,
        }),
      );
    } else {
      unawaited(
        ed.invokeCommand('sheets.object.editAltText', {'objectId': o.id}),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build.

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: objects.focus,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _size = constraints.biggest;
          return ListenableBuilder(
            listenable: Listenable.merge([
              objects,
              ed.scroll,
              ed.contentSignal,
              ?SheetsCollab.of(ed)?.presence.cursors,
            ]),
            builder: (context, _) => _layers(context),
          );
        },
      ),
    );
  }

  Widget _layers(BuildContext context) {
    final sheet = ed.activeSheet;
    if (sheet == null || sheet.record?.kind == SheetKind.chart) {
      return const SizedBox.shrink();
    }
    final list = objects.objectsOn(sheet.id);
    if (list.isEmpty) return const SizedBox.shrink();
    final g = _geometry();
    if (g == null) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final byPane = <PaneKind, List<Widget>>{};
    final paneOf = <PaneKind, GridPane>{for (final p in g.panes) p.kind: p};
    final images = SheetsImageService.of(ed);
    final drag = objects.drag;
    for (final o in list) {
      final cell = objects.anchorCell(o);
      final rect = objects.rectOf(o);
      if (cell == null || rect == null) continue;
      final pane = g.paneFor(cell.$1, cell.$2);
      if (pane.rect.isEmpty) continue;
      final screen = objectScreenRect(g, pane, rect);
      final selected = objects.isSelected(o.id);
      final cull = pane.rect.inflate(
        math.max(pane.rect.width, pane.rect.height),
      );
      if (!selected && !screen.overlaps(cull)) continue;
      final local = screen.shift(-pane.rect.topLeft);
      final children = byPane.putIfAbsent(pane.kind, () => []);
      children.add(
        Positioned.fromRect(
          key: ValueKey<String>('sheets.object.${o.id}'),
          rect: local,
          child: _ObjectBox(
            record: o,
            state: this,
            width: rect.width,
            height: rect.height,
            zoom: g.zoom,
            images: images,
            selected: selected,
          ),
        ),
      );
    }
    // Outlines: every object of a multi-selection (no handles), and the
    // objects collaborators have selected, in their presence color with a
    // name flag (08 §9.2).
    final outlines = <String, List<(Color, String?)>>{};
    if (objects.isMultiSelection) {
      for (final id in objects.selectedIds) {
        outlines.putIfAbsent(id, () => []).add((
          theme.colorScheme.selectionBorder,
          null,
        ));
      }
    }
    final presence = SheetsCollab.of(ed)?.presence;
    if (presence != null) {
      for (final c in presence.cursorsOn(sheet.id)) {
        final oid = c.cursor.objectId;
        if (oid == null) continue;
        outlines.putIfAbsent(oid, () => []).add((
          theme.colorScheme.presence(c.colorIndex),
          c.displayName,
        ));
      }
    }
    for (final e in outlines.entries) {
      final o = objects.record(e.key);
      if (o == null || o.sheetId != sheet.id) continue;
      final cell = objects.anchorCell(o);
      final rect = objects.rectOf(o);
      if (cell == null || rect == null) continue;
      final pane = g.paneFor(cell.$1, cell.$2);
      final screen = objectScreenRect(g, pane, rect);
      for (var i = 0; i < e.value.length; i++) {
        final (color, name) = e.value[i];
        final inset = name == null ? 0.0 : 2.0 + 2 * i;
        byPane
            .putIfAbsent(pane.kind, () => [])
            .add(
              Positioned.fromRect(
                key: ValueKey<String>(
                  name == null
                      ? 'sheets.object.outline.${o.id}'
                      : 'sheets.object.remote.${o.id}.$i',
                ),
                rect: screen.inflate(inset).shift(-pane.rect.topLeft),
                child: IgnorePointer(
                  child: _ObjectOutline(color: color, name: name),
                ),
              ),
            );
      }
    }
    final sel = objects.isMultiSelection ? null : objects.selected;
    if (sel != null && sel.sheetId == sheet.id) {
      final cell = objects.anchorCell(sel);
      final rect = objects.rectOf(sel);
      if (cell != null && rect != null) {
        final pane = g.paneFor(cell.$1, cell.$2);
        final screen = objectScreenRect(g, pane, rect);
        byPane
            .putIfAbsent(pane.kind, () => [])
            .add(
              Positioned.fromRect(
                key: const ValueKey<String>('sheets.object.frame'),
                rect: screen.inflate(_frame).shift(-pane.rect.topLeft),
                child: _SelectionFrame(
                  record: sel,
                  state: this,
                  color: theme.colorScheme.selectionBorder,
                  fill: theme.colorScheme.background,
                  handles: ed.canEdit,
                  guides: drag?.objectId == sel.id ? drag!.guides : const [],
                  toLocal: (x, y) {
                    final p = objectScreenRect(
                      g,
                      pane,
                      ChartRect(x, y, 0, 0),
                    ).topLeft;
                    return p - screen.inflate(_frame).topLeft;
                  },
                ),
              ),
            );
      }
    }
    // Objects anchored in frozen rows/columns are not confined to the frozen
    // strip: like Google Sheets they extend over the scrolling panes (and
    // stay fixed on the frozen axis). Each pane clips from its own top-left
    // to the grid's bottom-right; frozen panes paint last, on top.
    final grid = g.panes
        .where((p) => !p.rect.isEmpty)
        .fold<Rect?>(
          null,
          (u, p) => u == null ? p.rect : u.expandToInclude(p.rect),
        );
    const order = [PaneKind.main, PaneKind.left, PaneKind.top, PaneKind.corner];
    return Stack(
      children: [
        for (final kind in order)
          if (byPane[kind] case final children?)
            Positioned.fromRect(
              rect: Rect.fromLTRB(
                paneOf[kind]!.rect.left,
                paneOf[kind]!.rect.top,
                grid?.right ?? paneOf[kind]!.rect.right,
                grid?.bottom ?? paneOf[kind]!.rect.bottom,
              ),
              child: ClipRect(
                child: Stack(clipBehavior: Clip.none, children: children),
              ),
            ),
      ],
    );
  }
}

/// One object over the grid: the content in a `RepaintBoundary` plus the
/// Builds the view of an object kind another feature implements.
typedef ObjectViewBuilder =
    Widget Function(
      BuildContext context,
      SheetEditorController editor,
      EmbeddedObjectRecord record,
      double zoom,
    );

/// Views of object kinds registered by other features (slicers register
/// theirs, 07 §5); the others show a generic card.
final Map<EmbeddedObjectKind, ObjectViewBuilder> objectViewBuilders = {};

/// pointer handling, cursor and semantics (08 §9.2, §14).
class _ObjectBox extends StatelessWidget {
  const _ObjectBox({
    required this.record,
    required this.state,
    required this.width,
    required this.height,
    required this.zoom,
    required this.images,
    required this.selected,
  });

  final EmbeddedObjectRecord record;
  final _ObjectsOverlayState state;
  final double width;
  final double height;
  final double zoom;
  final SheetsImageService images;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final objects = state.objects;
    final ed = state.ed;
    final o = record;
    Widget content;
    String label;
    switch (o.kind) {
      case EmbeddedObjectKind.chart:
        final c = objects.chartOf(o);
        if (c.spec.isFromNewerVersion) {
          content = const NewerVersionChartCard();
          label = o.altText ?? o.title ?? '';
        } else {
          content = ChartObjectView(
            controller: c,
            width: width,
            height: height,
            zoom: zoom,
          );
          final alt = o.altText?.trim() ?? '';
          label = alt.isNotEmpty ? alt : c.autoDescription;
        }
      case EmbeddedObjectKind.image:
        content = ImageObjectView(
          service: images,
          spec: ImageSpec.fromJson(o.specJson),
        );
        final alt = o.altText?.trim() ?? '';
        label = alt.isNotEmpty ? alt : (o.title ?? '');
      case EmbeddedObjectKind.slicer || EmbeddedObjectKind.drawing:
        // Kinds built by other features (slicers, 07 §5).
        final custom = objectViewBuilders[o.kind];
        content = custom != null
            ? custom(context, ed, o, zoom)
            : _GenericObjectCard(title: o.title ?? o.kind.name);
        label = o.altText ?? o.title ?? o.kind.name;
    }
    // Screen readers reach a chart's data as a table (08 §14).
    final chart = o.kind == EmbeddedObjectKind.chart;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      customSemanticsActions: chart
          ? {
              CustomSemanticsAction(
                label: sheetsL10n(context).chartViewDataTableAction,
              ): () => unawaited(
                ed.invokeCommand('sheets.chart.viewDataTable', {
                  'objectId': o.id,
                }),
              ),
            }
          : null,
      onTap: () => objects.select(o.id),
      child: MouseRegion(
        cursor: ed.canEdit ? SystemMouseCursors.move : SystemMouseCursors.basic,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => state._downOnObject(o, e),
          onPointerMove: state._onMove,
          onPointerUp: state._onUp,
          onPointerCancel: state._onUp,
          onPointerSignal: state._onSignal,
          child: RepaintBoundary(
            child: SizedBox(
              width: width * zoom,
              height: height * zoom,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// A selection outline of an object: a member of a multi-selection, or a
/// collaborator's selection with their name flag above it.
class _ObjectOutline extends StatelessWidget {
  const _ObjectOutline({required this.color, this.name});

  final Color color;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final n = name;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: n == null ? 1 : 2),
            ),
          ),
        ),
        if (n != null)
          Positioned(
            left: -1,
            top: -18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
              child: Text(
                n,
                maxLines: 1,
                style: theme.textTheme.small.copyWith(
                  fontSize: 11,
                  height: 1.3,
                  color: color.computeLuminance() > 0.5
                      ? const Color(0xFF000000)
                      : const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GenericObjectCard extends StatelessWidget {
  const _GenericObjectCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.small,
      ),
    );
  }
}

/// Selection outline, 8 resize handles (squares 8 px, hit areas 16 px), the
/// ⋮ button and the smart guides (08 §9.2–9.3).
class _SelectionFrame extends StatelessWidget {
  const _SelectionFrame({
    required this.record,
    required this.state,
    required this.color,
    required this.fill,
    required this.handles,
    required this.guides,
    required this.toLocal,
  });

  final EmbeddedObjectRecord record;
  final _ObjectsOverlayState state;
  final Color color;
  final Color fill;
  final bool handles;
  final List<SnapGuide> guides;

  /// Sheet px → frame-local px.
  final Offset Function(double x, double y) toLocal;

  static const double m = _ObjectsOverlayState._frame;

  static Offset _pos(ResizeHandle h, Size s) {
    final w = s.width - 2 * m;
    final hh = s.height - 2 * m;
    final x = switch (h) {
      ResizeHandle.topLeft ||
      ResizeHandle.left ||
      ResizeHandle.bottomLeft => 0.0,
      ResizeHandle.top || ResizeHandle.bottom => w / 2,
      _ => w,
    };
    final y = switch (h) {
      ResizeHandle.topLeft || ResizeHandle.top || ResizeHandle.topRight => 0.0,
      ResizeHandle.left || ResizeHandle.right => hh / 2,
      _ => hh,
    };
    return Offset(m + x, m + y);
  }

  static MouseCursor _cursor(ResizeHandle h) => switch (h) {
    ResizeHandle.topLeft ||
    ResizeHandle.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
    ResizeHandle.topRight ||
    ResizeHandle.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
    ResizeHandle.top || ResizeHandle.bottom => SystemMouseCursors.resizeUpDown,
    ResizeHandle.left ||
    ResizeHandle.right => SystemMouseCursors.resizeLeftRight,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FramePainter(
                    color: color,
                    fill: fill,
                    handles: handles,
                    guides: [
                      for (final g in guides)
                        g.vertical
                            ? (
                                toLocal(g.position, g.start),
                                toLocal(g.position, g.end),
                              )
                            : (
                                toLocal(g.start, g.position),
                                toLocal(g.end, g.position),
                              ),
                    ],
                  ),
                ),
              ),
            ),
            if (handles)
              for (final h in ResizeHandle.values)
                Positioned(
                  left: _pos(h, size).dx - 8,
                  top: _pos(h, size).dy - 8,
                  width: 16,
                  height: 16,
                  child: MouseRegion(
                    cursor: _cursor(h),
                    child: Listener(
                      key: ValueKey<String>('sheets.object.handle.${h.name}'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => state._downOnHandle(record, h, e),
                      onPointerMove: state._onMove,
                      onPointerUp: state._onUp,
                      onPointerCancel: state._onUp,
                    ),
                  ),
                ),
            Positioned(
              right: m + 4,
              top: m + 4,
              child: _MoreButton(
                onPressed: (global) => state._openMenu(record, global),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});

  final void Function(Offset global) onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    return Builder(
      builder: (context) => Listener(
        onPointerDown: (e) => _ObjectsOverlayState.consumedPointer = e.pointer,
        child: ShadTooltip(
          builder: (_) => Text(l.objectMoreOptions),
          child: ShadIconButton.outline(
            key: const ValueKey<String>('sheets.object.more'),
            width: 24,
            height: 24,
            padding: EdgeInsets.zero,
            backgroundColor: theme.colorScheme.background,
            icon: const Icon(LucideIcons.ellipsisVertical, size: 14),
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              final at = box == null
                  ? Offset.zero
                  : box.localToGlobal(Offset(0, box.size.height + 4));
              onPressed(at);
            },
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({
    required this.color,
    required this.fill,
    required this.handles,
    required this.guides,
  });

  final Color color;
  final Color fill;
  final bool handles;
  final List<(Offset, Offset)> guides;

  static const double m = _ObjectsOverlayState._frame;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(m, m, size.width - 2 * m, size.height - 2 * m);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(r.deflate(0.5), stroke);
    if (handles) {
      final f = Paint()..color = fill;
      for (final h in ResizeHandle.values) {
        final p = _SelectionFrame._pos(h, size);
        final sq = Rect.fromCenter(center: p, width: 8, height: 8);
        canvas.drawRect(sq, f);
        canvas.drawRect(sq.deflate(0.5), stroke);
      }
    }
    if (guides.isNotEmpty) {
      final g = Paint()
        ..color = color
        ..strokeWidth = 1;
      for (final (a, b) in guides) {
        _dashedLine(canvas, a, b, g);
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    final d = b - a;
    final len = d.distance;
    if (len <= 0) return;
    final u = d / len;
    for (var t = 0.0; t < len; t += 8) {
      canvas.drawLine(a + u * t, a + u * math.min(len, t + 4), p);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.color != color ||
      old.handles != handles ||
      old.fill != fill ||
      old.guides.length != guides.length ||
      guides.isNotEmpty;
}
