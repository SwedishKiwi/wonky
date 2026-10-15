import 'package:wonky_charts/wonky_charts.dart';

import '../model/api/deck_reader.dart';
import '../model/api/kinds.dart';
import '../model/api/records.dart';
import '../motion/builds/parts.dart' show ChartShape;
import '../motion/timeline/slide_frame.dart' show ChartRevealState;
import 'chart_element_data.dart';

/// The bridge between the Slides timeline (06 §9) and the chart engine (08 §9–§10):
/// chart data shapes for chart deliveries, and a frame's per-element `ChartRevealState` as
/// the engine's [ChartReveal] plus the 3D camera of the frame.
abstract final class SlideChartMotion {
  /// The `chartShapeOf` hook of `SlideMotionInput.fromDeck` over [deck]: series keys in
  /// legend order, the category count, pie and 3D flags, read from the element's snapshot
  /// (`gz:` columns included) — or null for elements without data (the compiler then reads
  /// nothing and chart deliveries fall back to the whole chart).
  static ChartShape? Function(SlideElementRec element) shapes(DeckReader deck) {
    final cache = <String, (String, ChartShape?)>{};
    return (element) {
      if (element.kind != ElementKind.chart) return null;
      final link = deck.chartLinkOf(element.id);
      final key = link == null
          ? 'd${element.dataJson.hashCode}'
          : 'l${link.sourceVersion}|${link.dataSnapshotJson.hashCode}|'
                '${link.sourceSpecJson.hashCode}';
      final hit = cache[element.id];
      if (hit != null && hit.$1 == key) return hit.$2;
      final shape = shapeOf(element, deck);
      cache[element.id] = (key, shape);
      return shape;
    };
  }

  /// The data shape of chart [element] (see [shapes]).
  static ChartShape? shapeOf(SlideElementRec element, DeckReader deck) {
    final data = ChartElementData.fromJson(element.dataJson);
    ChartSourceSnapshot? snap;
    if (data.source == SlideChartSource.linked) {
      final link = deck.chartLinkOf(element.id);
      if (link != null) {
        snap = ChartSourceSnapshot.fromColumns(
          link.sourceSpecJson,
          link.dataSnapshotJson,
        );
      }
    } else if (data.source == SlideChartSource.static) {
      snap = data.snapshot;
    }
    if (snap == null || snap.dataSnapshot.isPlaceholder) return null;
    return shapeOfSnapshot(snap);
  }

  /// The data shape of [snap].
  static ChartShape shapeOfSnapshot(ChartSourceSnapshot snap) {
    final spec = snap.spec;
    final d = snap.data;
    final keys = [for (final s in d.series) s.key];
    var points = d.domain.length;
    if (d.table != null && d.table!.rowCount > points) {
      points = d.table!.rowCount;
    }
    return ChartShape(
      seriesKeys: keys,
      categoryCount: points,
      pie: spec.type == ChartType.pie,
      is3d: spec.threeD.appliesTo(spec.type),
    );
  }

  /// The 3D camera a chart element shows without animation: its `camera`, else the view of
  /// its effective spec — the `base` of [view] and [fitViews] (SL-29's player).
  static Chart3DView baseView(ChartElementData data, ChartSpec spec) =>
      data.camera ?? Chart3DView.of(spec);

  /// [state] (a frame's chart state, null = fully shown) as a [ChartReveal]. Part roles:
  /// `series` → series key, `category` → point index, `point` → both, `all` → every part,
  /// `labels` → data labels. The highlight is `{target: {series: k} | {point: [k, i]},
  /// dimOthers}`.
  static ChartReveal reveal(ChartRevealState? state) {
    if (state == null) return ChartReveal.full;
    final parts = <ChartRevealKey, ChartPartReveal>{};
    var labels = ChartPartReveal.shown;
    for (final p in state.parts) {
      final r = ChartPartReveal(grow: p.grow, opacity: p.opacity);
      switch (p.key.role) {
        case 'series':
          parts[ChartRevealKey(seriesKey: p.key.series)] = r;
        case 'category':
          parts[ChartRevealKey(pointIndex: p.key.index)] = r;
        case 'point':
          parts[ChartRevealKey(
                seriesKey: p.key.series,
                pointIndex: p.key.index,
              )] =
              r;
        case 'labels':
          labels = r;
        default:
          parts[ChartRevealKey.all] = r;
      }
    }
    String? hs;
    (String, int)? hp;
    var dim = 0.3;
    final h = state.highlight;
    if (h != null) {
      final target = h['target'];
      if (h['dimOthers'] is num) dim = (h['dimOthers']! as num).toDouble();
      if (target is Map) {
        final s = target['series'];
        final pt = target['point'];
        if (s is String) hs = s;
        if (pt is List && pt.length == 2 && pt[0] is String && pt[1] is num) {
          hp = (pt[0]! as String, (pt[1]! as num).toInt());
        }
      }
    }
    return ChartReveal(
      backgroundOpacity: state.backgroundOpacity,
      parts: parts,
      dataLabels: labels,
      highlightSeries: hs,
      highlightPoint: hp,
      dimOthers: dim,
      highlightMix: state.highlightMix,
    );
  }

  /// The 3D camera of a frame: the element's view [base] (its `camera` or the spec's view)
  /// blended toward a `chartCamera` target by `cameraMix` (shortest arc unless the target
  /// says `direction: cw|ccw` and `turns`), then rotated by the `chartOrbit` offsets.
  /// Targets may name a `preset` (08 §10.2) and leave angles null (= keep).
  static Chart3DView view(
    ChartRevealState? state,
    Chart3DView base, {
    ChartType type = ChartType.column,
  }) {
    if (state == null) return base;
    var v = base;
    final cam = state.camera;
    if (cam != null) {
      final from = state.fromCamera == null
          ? base
          : _target(state.fromCamera!, base, type);
      final to = _target(cam, from, type);
      v = Chart3DView.lerp(
        from,
        to,
        state.cameraMix,
        turn: switch (cam['direction']) {
          'cw' => Chart3DTurn.cw,
          'ccw' => Chart3DTurn.ccw,
          _ => Chart3DTurn.shortest,
        },
        turns: cam['turns'] is num ? (cam['turns']! as num).toInt() : 0,
      );
    }
    if (state.azimuthDelta != 0 || state.elevationDelta != 0) {
      v = v.rotated(
        azimuth: state.azimuthDelta,
        elevation: state.elevationDelta,
      );
    }
    return v;
  }

  /// The views a frame's camera animation spans ([view]'s start and end), for
  /// `ChartLayoutOptions.fitViews3D`; null when the camera doesn't move.
  static List<Chart3DView>? fitViews(
    ChartRevealState? state,
    Chart3DView base, {
    ChartType type = ChartType.column,
  }) {
    final cam = state?.camera;
    if (state == null || cam == null) return null;
    final from = state.fromCamera == null
        ? base
        : _target(state.fromCamera!, base, type);
    return [from, _target(cam, from, type)];
  }

  static Chart3DView _target(
    Map<String, Object?> m,
    Chart3DView keep,
    ChartType type,
  ) {
    final preset = m['preset'] is String
        ? Chart3DView.preset(m['preset']! as String, type: type)
        : null;
    return Chart3DView.fromJson(m, fallback: preset ?? keep) ?? keep;
  }
}
