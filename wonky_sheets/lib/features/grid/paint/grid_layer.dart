import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show WidgetBuilder;
import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:wonky_sheets_core/model.dart';

import '../../../theme/sheets_tokens.dart';
import '../../sheet_editor/sheet_editor_controller.dart';
import '../selection/grid_selection.dart';
import '../viewport/grid_geometry.dart';
import 'cell_render_cache.dart';
import 'text_layout_cache.dart';

/// Well-known z orders of grid layers (13 §4.4). Layers below
/// [GridLayer.overlayThreshold] are painted by the content pass (repainted
/// when cells change or the grid scrolls); the others by the overlay pass
/// (repainted on selection/editing changes too).
abstract final class GridZ {
  static const background = 0;
  static const gridlines = 50;
  static const cells = 100;
  static const conditionalFormat = 150;
  static const borders = 200;
  static const decorations = 250;
  static const objects = 400;
  static const find = 450;
  static const presence = 500;
  static const referenceBoxes = 550;
  static const selection = 600;
  static const dragFeedback = 700;
  static const frozenDividers = 800;
  static const headers = 900;
}

/// Everything a layer needs to paint one frame.
class GridPaintContext {
  GridPaintContext({
    required this.controller,
    required this.geometry,
    required this.tokens,
  });

  final SheetEditorController controller;
  final GridGeometry geometry;
  final GridPaintTokens tokens;

  WorkbookModel get model => controller.model;
  SheetModel get sheet => geometry.sheet;
  String get sheetId => sheet.id;
  double get zoom => geometry.zoom;
  CellRenderCache get cells => controller.cells;
  TextLayoutCache get text => controller.textCache;
  ResolvedSelection get selection => controller.selection.resolved;

  /// Paints [body] once per pane, clipped to the pane.
  void forEachPane(Canvas canvas, void Function(GridPane pane) body) {
    for (final pane in geometry.panes) {
      if (pane.rect.isEmpty) continue;
      canvas.save();
      canvas.clipRect(pane.rect);
      body(pane);
      canvas.restore();
    }
  }
}

/// A plug-in layer of the grid (13 §4.4, 03 §2.4). Features (conditional
/// formatting, presence, objects, filters, find) add layers with
/// `SheetEditorController.layers.add(layer)` instead of editing the core
/// painters.
abstract class GridLayer {
  const GridLayer();

  /// Paint order; see [GridZ].
  int get zOrder;

  /// Repaints of this layer (null = only when the grid repaints).
  Listenable? get repaint => null;

  /// Whether the layer is painted by the overlay pass.
  bool get isOverlay => zOrder >= overlayThreshold;

  static const overlayThreshold = GridZ.presence;

  void paint(GridPaintContext ctx, Canvas canvas);
}

/// The ordered set of grid layers of an editor.
class GridLayerRegistry extends ChangeNotifier {
  final List<GridLayer> _layers = [];

  List<GridLayer> get content => [
    for (final l in _sorted)
      if (!l.isOverlay) l,
  ];

  List<GridLayer> get overlay => [
    for (final l in _sorted)
      if (l.isOverlay) l,
  ];

  List<GridLayer> get _sorted =>
      List.of(_layers)..sort((a, b) => a.zOrder.compareTo(b.zOrder));

  /// Repaint signals of all layers of a pass.
  List<Listenable> repaintsOf({required bool overlay}) => [
    for (final l in _layers)
      if (l.isOverlay == overlay && l.repaint != null) l.repaint!,
  ];

  void add(GridLayer layer) {
    _layers.add(layer);
    notifyListeners();
  }

  void remove(GridLayer layer) {
    if (_layers.remove(layer)) notifyListeners();
  }

  final List<WidgetBuilder> _widgets = [];

  /// Widgets stacked over the grid cells (floating buttons such as the
  /// pivot table *Edit* button), built inside the grid area's `Stack`.
  List<WidgetBuilder> get widgets => List.unmodifiable(_widgets);

  void addWidget(WidgetBuilder builder) {
    _widgets.add(builder);
    notifyListeners();
  }

  void removeWidget(WidgetBuilder builder) {
    if (_widgets.remove(builder)) notifyListeners();
  }
}

/// A plug-in pointer handler of the grid (filter buttons, the group gutter,
/// dropdown chips …): consulted, in order, before the grid's own handling of
/// a primary pointer down. Added with `controller.gridHooks.hitHandlers`.
abstract class GridHitHandler {
  const GridHitHandler();

  /// Handles a primary pointer down at [local] (grid coordinates); true
  /// consumes it.
  bool onPointerDown(GridGeometry g, Offset local, PointerDownEvent event);

  /// The cursor over [local], or null to keep the grid's cursor.
  MouseCursor? cursorAt(GridGeometry g, Offset local) => null;
}

/// The hovered cell of [GridHooks.hover].
typedef GridHoverCell = ({String sheetId, int row, int col});

/// Colors of the row/column headers (filter views darken them, 07 §4.2).
typedef GridHeaderColors = ({
  Color bg,
  Color fg,
  Color selectedBg,
  Color fullBg,
  Color border,
});

/// Feature hooks into the core grid painting and hit testing (07: filters,
/// filter views, outline groups). Every hook is optional.
class GridHooks {
  /// Pointer handlers consulted before the grid's own handling.
  final List<GridHitHandler> hitHandlers = [];

  /// The cell under the mouse pointer (hover cards, 03 §14); null outside
  /// the cells.
  final ValueNotifier<GridHoverCell?> hover = ValueNotifier(null);

  /// Widgets layered over the grid (cell popovers, hover cards), built
  /// inside the grid's stack (use `Positioned`).
  final ValueNotifier<List<Widget Function(BuildContext)>> overlays =
      ValueNotifier(const []);

  /// Outline gutter sizes (px, unscaled) left of the row headers / above the
  /// column headers of [sheet] (07 §16.3).
  ({double rows, double cols}) Function(SheetModel sheet)? gutters;

  /// Text color of a row number (filtered rows, 07 §3.5), or null.
  Color? Function(String sheetId, int row, GridPaintTokens tokens)?
  rowNumberColor;

  /// Header colors replacing the tokens (active filter view), or null.
  GridHeaderColors? Function(String sheetId, GridPaintTokens tokens)?
  headerColors;
}
