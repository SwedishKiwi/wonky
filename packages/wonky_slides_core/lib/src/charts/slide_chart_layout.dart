import 'dart:collection';

import 'package:wonky_charts/wonky_charts.dart';

import '../model/api/deck_reader.dart';
import '../model/api/records.dart';
import '../model/api/resolved.dart';
import '../scene/nodes/scene_nodes.dart';
import '../theme/resolve/resolved_theme.dart';
import 'chart_element_data.dart';
import 'slide_chart_spec.dart';

/// A chart element laid out (Slides 08 §3.5, §9): the scene in chart px (draw it into the
/// element frame; `ChartNode` scales it), the look it was laid out with, the snapshot and the
/// element data.
final class SlideChartBuild {
  /// Creates a build.
  const SlideChartBuild({
    required this.scene,
    required this.look,
    required this.snapshot,
    required this.data,
    this.warnings = const [],
  });

  final ChartScene scene;
  final SlideChartLook look;
  final ChartSourceSnapshot snapshot;
  final ChartElementData data;

  /// Data and layout warnings.
  final List<ChartWarning> warnings;
}

/// The chart layer of the slide scene (Slides 08; `ChartSceneSource` for
/// `SceneBuildContext.charts` and the PDF exporter): reads a chart element's snapshot (the
/// `ChartLink` columns of a linked chart, `gz:` included, or `dataJson.snapshot` of a static
/// one), computes the effective spec and theme ([SlideChartSpec.effective]) and lays the
/// chart out with [measurer] at the element size divided by [suPerPx] (charts keep the text
/// proportions they have in Sheets: a 1,200 su wide chart is laid out 600 px wide).
///
/// Charts without data yet (a link pasted before its first resolve) and native charts (P1)
/// return null, so the scene builder draws its placeholder. Results are cached (LRU of
/// [cacheSize]) by element, data, snapshot version, theme, size and background.
///
/// For builds and camera animation use [build] with a `ChartReveal` and a `Chart3DView` (2D
/// reveals are applied to the cached layout, 3D charts are laid out again per frame).
final class SlideChartLayout implements ChartSceneSource {
  /// Creates the layout.
  SlideChartLayout({
    this.measurer = const ApproxTextMeasurer(),
    this.suPerPx = 2,
    this.cacheSize = 64,
  });

  /// Text metrics (Flutter `TextPainter` in the app, `TtfChartTextMeasurer` in PDFs).
  final TextMeasurer measurer;

  /// Slide units per chart px.
  final double suPerPx;
  final int cacheSize;

  final LinkedHashMap<String, SlideChartBuild?> _cache = LinkedHashMap();
  final Map<String, ChartSourceSnapshot> _snapshots = {};

  /// The snapshot [element] shows, or null (no data yet, native, not a chart).
  ChartSourceSnapshot? snapshotOf(
    SlideElementRec element,
    DeckReader? deck, {
    ChartElementData? data,
  }) {
    final d = data ?? ChartElementData.fromJson(element.dataJson);
    switch (d.source) {
      case SlideChartSource.linked:
        final link = deck?.chartLinkOf(element.id);
        if (link == null) return null;
        final key =
            '${link.sourceVersion}|${link.sourceSpecJson.hashCode}|'
            '${link.dataSnapshotJson.hashCode}';
        final cached = _snapshots[element.id];
        if (cached != null && _snapshotKeys[element.id] == key) {
          return cached.dataSnapshot.isPlaceholder ? null : cached;
        }
        final s = ChartSourceSnapshot.fromColumns(
          link.sourceSpecJson,
          link.dataSnapshotJson,
        );
        if (_snapshots.length > cacheSize * 2) {
          _snapshots.clear();
          _snapshotKeys.clear();
        }
        _snapshots[element.id] = s;
        _snapshotKeys[element.id] = key;
        return s.dataSnapshot.isPlaceholder ? null : s;
      case SlideChartSource.static:
        final s = d.snapshot;
        return s == null || s.dataSnapshot.isPlaceholder ? null : s;
      case SlideChartSource.native:
        return null;
    }
  }

  final Map<String, String> _snapshotKeys = {};

  @override
  ChartScene? chartScene(
    ResolvedElement element,
    DeckReader? deck,
    ResolvedTheme theme, {
    required double width,
    required double height,
    int? background,
  }) => build(
    element.record,
    deck,
    theme,
    width: width,
    height: height,
    background: background,
  )?.scene;

  /// Lays [element] out at [width] × [height] su on a slide with [background] (ARGB behind
  /// the chart). [reveal] = a chart build state (`SlideChartMotion.reveal`); [view] = the 3D
  /// camera of the frame and [fitViews] the views a camera animation spans (one fit, no
  /// zoom pumping); [transitionFrom3D]/[transition3D] morph a 3D model (Magic Move, updates).
  SlideChartBuild? build(
    SlideElementRec element,
    DeckReader? deck,
    ResolvedTheme theme, {
    required double width,
    required double height,
    int? background,
    ChartReveal? reveal,
    Chart3DView? view,
    List<Chart3DView>? fitViews,
    Chart3DModel? transitionFrom3D,
    double transition3D = 1,
  }) {
    if (width <= 0 || height <= 0) return null;
    final animated3D =
        view != null || fitViews != null || transitionFrom3D != null;
    final key = [
      element.id,
      element.dataJson.hashCode,
      deck?.chartLinkOf(element.id)?.sourceVersion ?? '',
      deck?.chartLinkOf(element.id)?.dataSnapshotJson.hashCode ?? 0,
      theme.contentHash,
      theme.appearance.name,
      width.toStringAsFixed(2),
      height.toStringAsFixed(2),
      background ?? '',
    ].join('|');
    SlideChartBuild? base;
    if (!animated3D) {
      if (_cache.containsKey(key)) {
        base = _cache.remove(key);
        _cache[key] = base;
      } else {
        base = _layout(
          element,
          deck,
          theme,
          width: width,
          height: height,
          background: background,
        );
        _cache[key] = base;
        while (_cache.length > cacheSize) {
          _cache.remove(_cache.keys.first);
        }
      }
      if (base == null) return null;
      if (reveal == null || reveal.isFull) return base;
      final is3D = base.look.spec.threeD.appliesTo(base.look.spec.type);
      if (!is3D) {
        return SlideChartBuild(
          scene: reveal.applyTo(base.scene, base.look.spec),
          look: base.look,
          snapshot: base.snapshot,
          data: base.data,
          warnings: base.warnings,
        );
      }
    }
    return _layout(
      element,
      deck,
      theme,
      width: width,
      height: height,
      background: background,
      reveal: reveal,
      view: view,
      fitViews: fitViews,
      transitionFrom3D: transitionFrom3D,
      transition3D: transition3D,
    );
  }

  SlideChartBuild? _layout(
    SlideElementRec element,
    DeckReader? deck,
    ResolvedTheme theme, {
    required double width,
    required double height,
    int? background,
    ChartReveal? reveal,
    Chart3DView? view,
    List<Chart3DView>? fitViews,
    Chart3DModel? transitionFrom3D,
    double transition3D = 1,
  }) {
    final data = ChartElementData.fromJson(element.dataJson);
    final snapshot = snapshotOf(element, deck, data: data);
    if (snapshot == null) return null;
    final look = SlideChartSpec.effective(
      snapshot: snapshot,
      element: data,
      deckTheme: theme,
      slideBackground: background,
    );
    final v = view?.normalized;
    final layout = ChartPipeline.layout(
      look.spec,
      snapshot.data,
      size: ChartSize(width / suPerPx, height / suPerPx),
      theme: look.theme,
      measurer: measurer,
      locale: look.locale,
      options: ChartLayoutOptions(
        azimuth3D: v?.azimuth,
        elevation3D: v?.elevation,
        perspective3D: v?.perspective,
        fitViews3D: fitViews,
        transitionFrom3D: transitionFrom3D,
        transition3D: transition3D,
      ),
      reveal: reveal,
    );
    return SlideChartBuild(
      scene: layout.scene,
      look: look,
      snapshot: snapshot,
      data: data,
      warnings: [...snapshot.data.warnings, ...layout.warnings],
    );
  }

  /// Drops every cached layout (fonts loaded, measurer changed).
  void clear() {
    _cache.clear();
    _snapshots.clear();
    _snapshotKeys.clear();
  }
}
