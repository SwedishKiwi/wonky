import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart'
    show SlidePlaceholderType, SuRect;

import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import 'chart_text.dart';

/// Chart element helpers of the editor (Slides 08): element data, the
/// laid-out chart of an element (the canvas' chart source, else one per
/// editor), placeholder checks and insert placement.
abstract final class ChartElements {
  static final Expando<SlideChartLayout> _layouts = Expando(
    'slidesChartLayout',
  );

  /// The element data of [e].
  static ChartElementData dataOf(SlideElementRec e) =>
      ChartElementData.fromJson(e.dataJson);

  /// Whether [e] is a chart element.
  static bool isChart(SlideElementRec? e) =>
      e != null && e.kind == ElementKind.chart;

  /// Whether chart [e] is linked to a spreadsheet (a `ChartLink` row).
  static bool isLinked(DeckEditorController ed, SlideElementRec e) =>
      isChart(e) &&
      dataOf(e).source == SlideChartSource.linked &&
      ed.model.chartLinkOf(e.id) != null;

  /// Whether chart [e] shows nothing yet: an empty chart placeholder (or a
  /// chart without a link or snapshot).
  static bool isEmpty(DeckEditorController ed, SlideElementRec e) {
    if (!isChart(e)) return false;
    final d = dataOf(e);
    return switch (d.source) {
      SlideChartSource.linked => ed.model.chartLinkOf(e.id) == null,
      SlideChartSource.static => d.snapshot == null,
      SlideChartSource.native => d.spec == null,
    };
  }

  /// Whether resolved [e] is an empty chart placeholder of its layout.
  static bool isEmptyPlaceholder(DeckEditorController ed, ResolvedElement e) =>
      e.placeholderType == SlidePlaceholderType.chart && isEmpty(ed, e.record);

  /// The chart layout of [ed]: the canvas renderer's, else the editor's own.
  static SlideChartLayout layoutOf(DeckEditorController ed) {
    final c = SlideCanvasController.of(ed)?.renderer.charts;
    if (c is SlideChartLayout) return c;
    return _layouts[ed] ??= SlidesChartText.layout();
  }

  /// The slide (or master-mode surface) chart [id] is on.
  static String? surfaceOf(DeckEditorController ed, String id) =>
      ed.model.element(id)?.ownerId;

  /// Chart [id] laid out at its frame size on its slide (null: not a chart,
  /// no data yet).
  static SlideChartBuild? buildOf(
    DeckEditorController ed,
    String id, {
    Chart3DView? view,
  }) {
    final e = ed.model.element(id);
    if (!isChart(e)) return null;
    final owner = e!.ownerId;
    final slide = owner == null ? null : ed.resolver.resolve(owner);
    if (slide == null) return null;
    ResolvedElement? find(List<ResolvedElement> list) {
      for (final x in list) {
        if (x.id == id) return x;
        final c = find(x.children);
        if (c != null) return c;
      }
      return null;
    }

    final r = find(slide.elements);
    final w = r?.frame.width ?? e.width ?? 0;
    final h = r?.frame.height ?? e.height ?? 0;
    return layoutOf(ed).build(
      e,
      ed.model,
      slide.theme,
      width: w,
      height: h,
      background: slide.background.effectiveColor(0xffffffff),
      view: view,
    );
  }

  /// The snapshot chart [id] shows (null: none yet).
  static ChartSourceSnapshot? snapshotOf(DeckEditorController ed, String id) {
    final e = ed.model.element(id);
    if (!isChart(e)) return null;
    return layoutOf(ed).snapshotOf(e!, ed.model);
  }

  /// Whether chart [id] is a 3D chart.
  static bool is3D(DeckEditorController ed, String id) {
    final s = snapshotOf(ed, id);
    return s != null && s.spec.is3D;
  }

  /// The effective camera of 3D chart [id] (the element's override, else
  /// the source spec's view).
  static Chart3DView? cameraOf(DeckEditorController ed, String id) {
    final e = ed.model.element(id);
    final s = snapshotOf(ed, id);
    if (e == null || s == null || !s.spec.is3D) return null;
    return dataOf(e).camera ?? Chart3DView.of(s.spec);
  }

  /// The aspect ratio of new charts (Sheets' default chart, 600 × 371).
  static const aspect = 600 / 371;

  /// Frames of [n] new charts: inside [area] (a placeholder; centered at
  /// 70 % of the slide width otherwise), in a grid when several.
  static List<SuRect> placements(
    int n, {
    required double slideWidth,
    required double slideHeight,
    SuRect? area,
  }) {
    if (n <= 0) return const [];
    final box =
        area ??
        () {
          final w = slideWidth * 0.7;
          final h = (w / aspect).clamp(0.0, slideHeight * 0.8);
          return SuRect((slideWidth - w) / 2, (slideHeight - h) / 2, w, h);
        }();
    var cols = 1;
    while (cols * cols < n) {
      cols++;
    }
    final rows = (n / cols).ceil();
    const gap = 24.0;
    final cw = (box.width - gap * (cols - 1)) / cols;
    final ch = (box.height - gap * (rows - 1)) / rows;
    final out = <SuRect>[];
    for (var i = 0; i < n; i++) {
      final cx = box.x + (i % cols) * (cw + gap);
      final cy = box.y + (i ~/ cols) * (ch + gap);
      // Fit the chart's aspect ratio into the cell, centered.
      var w = cw, h = cw / aspect;
      if (h > ch) {
        h = ch;
        w = ch * aspect;
      }
      out.add(
        SuRect(
          (cx + (cw - w) / 2).roundToDouble(),
          (cy + (ch - h) / 2).roundToDouble(),
          w.roundToDouble(),
          h.roundToDouble(),
        ),
      );
    }
    return out;
  }
}
