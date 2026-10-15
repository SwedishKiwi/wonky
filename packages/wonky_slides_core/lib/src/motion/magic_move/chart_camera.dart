/// The 3D chart camera of Magic Move (06 §8.4 "Charts (3D)", 08 §10.3):
/// azimuth, elevation and perspective of a chart element
/// (`dataJson.camera`, or a persistent `chartCamera` emphasis of the
/// outgoing slide's final frame), and their interpolation.
///
/// The seam: Magic Move interpolates cameras through a [ChartCameraLerp]
/// (`TransitionOptions.cameraLerp`). The default, [ChartCameraView.lerp],
/// delegates to `wonky_charts`' `Chart3DView.lerp` (SL-27: azimuth along
/// the shortest arc across 0/360, elevation and perspective linearly), so
/// chart builds, the chart renderer and Magic Move share one camera
/// interpolation.
library;

import 'package:wonky_charts/wonky_charts.dart' show Chart3DView;

double _r(double v) => (v * 1e6).roundToDouble() / 1e6;

/// Interpolates a chart camera from [a] to [b] at [t] (0..1).
typedef ChartCameraLerp =
    ChartCameraView Function(ChartCameraView a, ChartCameraView b, double t);

/// A 3D chart camera: [azimuth] and [elevation] in degrees, [perspective]
/// as the field of view in degrees (08 §10.2; 0 = orthographic).
final class ChartCameraView {
  /// Creates a camera.
  const ChartCameraView({
    required this.azimuth,
    required this.elevation,
    required this.perspective,
  });

  /// The *Default* preset (08 §10.2).
  static const defaults = ChartCameraView(
    azimuth: 20,
    elevation: 20,
    perspective: 15,
  );

  final double azimuth;
  final double elevation;
  final double perspective;

  /// Parses `{azimuth, elevation, perspective}` (missing keys from
  /// [fallback]); null when [json] is not a map.
  static ChartCameraView? fromJson(
    Object? json, {
    ChartCameraView fallback = defaults,
  }) {
    if (json is! Map) return null;
    double v(String k, double d) {
      final x = json[k];
      return x is num && x.isFinite ? x.toDouble() : d;
    }

    return ChartCameraView(
      azimuth: v('azimuth', fallback.azimuth),
      elevation: v('elevation', fallback.elevation),
      perspective: v('perspective', fallback.perspective),
    );
  }

  /// 08 §10.3 through `Chart3DView.lerp`: azimuth along the shortest arc
  /// (across 0/360, normalized), elevation and perspective linearly.
  static ChartCameraView lerp(ChartCameraView a, ChartCameraView b, double t) {
    final v = Chart3DView.lerp(a.view, b.view, t);
    return ChartCameraView(
      azimuth: v.azimuth,
      elevation: v.elevation,
      perspective: v.perspective,
    );
  }

  /// The `wonky_charts` view.
  Chart3DView get view => Chart3DView(
    azimuth: azimuth,
    elevation: elevation,
    perspective: perspective,
  );

  @override
  bool operator ==(Object other) =>
      other is ChartCameraView &&
      other.azimuth == azimuth &&
      other.elevation == elevation &&
      other.perspective == perspective;

  @override
  int get hashCode => Object.hash(azimuth, elevation, perspective);

  /// Canonical JSON (the `ChartRevealState.camera` shape).
  Map<String, Object?> toJson() => {
    'azimuth': _r(azimuth),
    'elevation': _r(elevation),
    'perspective': _r(perspective),
  };

  @override
  String toString() => 'ChartCameraView($azimuth, $elevation, $perspective)';
}
