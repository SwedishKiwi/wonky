import '../spec/chart_spec.dart';
import '../spec/chart_type.dart';
import '../spec/spec_json.dart';
import '../spec/three_d_options.dart';

/// Which way the azimuth turns while a camera animates (Slides 08 §10.3).
enum Chart3DTurn {
  /// Along the shorter arc (default).
  shortest,

  /// Increasing azimuth.
  cw,

  /// Decreasing azimuth.
  ccw,
}

/// The view of a 3D chart (Slides 08 §10.2–§10.3): the camera triple a deck stores in a chart
/// element's `dataJson.camera` and animates with `chartCamera`/`chartOrbit` builds and Magic
/// Move. [azimuth] (degrees, any value; normalized to 0 ≤ a < 360 when applied), [elevation]
/// (0..90) and [perspective] (field of view, 0..60).
final class Chart3DView {
  /// Creates a view.
  const Chart3DView({
    required this.azimuth,
    required this.elevation,
    this.perspective = ChartThreeD.defaultPerspective,
  });

  /// The effective view of [spec] (its `threeD` angles, or the type's defaults).
  factory Chart3DView.of(ChartSpec spec) => Chart3DView(
    azimuth: spec.threeD.azimuthFor(spec.type),
    elevation: spec.threeD.elevationFor(spec.type),
    perspective: spec.threeD.perspective,
  );

  /// Parses `{azimuth, elevation, perspective}`; missing keys come from [fallback] (null when
  /// [json] is not an object and there is no fallback). Values are clamped.
  static Chart3DView? fromJson(Object? json, {Chart3DView? fallback}) {
    if (json is! Map) return fallback;
    final r = JsonReader(json);
    final az = r.dbl('azimuth') ?? fallback?.azimuth;
    final el = r.dbl('elevation') ?? fallback?.elevation;
    if (az == null || el == null) return null;
    return Chart3DView(
      azimuth: az.isFinite ? az : 0,
      elevation: el.isFinite
          ? el.clamp(ChartThreeD.minElevation, ChartThreeD.maxElevation)
          : ChartThreeD.defaultElevation(ChartType.column),
      perspective:
          (r.dbl('perspective') ??
                  fallback?.perspective ??
                  ChartThreeD.defaultPerspective)
              .clamp(0.0, ChartThreeD.maxPerspective),
    );
  }

  /// Rotation about the vertical axis in degrees (not normalized: animations may pass 360).
  final double azimuth;

  /// View angle above the floor in degrees, 0..90.
  final double elevation;

  /// Field of view in degrees, 0..60.
  final double perspective;

  /// The camera presets of Slides 08 §10.2 for cartesian 3D charts (`default`, `front`,
  /// `isometric`, `topDown`, `lowAngle`, `side`, `dramatic`).
  static const Map<String, Chart3DView> presets = {
    'default': Chart3DView(azimuth: 20, elevation: 20, perspective: 15),
    'front': Chart3DView(azimuth: 0, elevation: 8, perspective: 10),
    'isometric': Chart3DView(azimuth: 45, elevation: 35.264, perspective: 0),
    'topDown': Chart3DView(azimuth: 0, elevation: 85, perspective: 0),
    'lowAngle': Chart3DView(azimuth: 25, elevation: 5, perspective: 30),
    'side': Chart3DView(azimuth: 80, elevation: 15, perspective: 15),
    'dramatic': Chart3DView(azimuth: 35, elevation: 25, perspective: 45),
  };

  /// The presets of 3D pie charts (`default`, `flat`, `tilted`, `steep`).
  static const Map<String, Chart3DView> piePresets = {
    'default': Chart3DView(azimuth: 0, elevation: 40, perspective: 15),
    'flat': Chart3DView(azimuth: 0, elevation: 85, perspective: 15),
    'tilted': Chart3DView(azimuth: 0, elevation: 40, perspective: 15),
    'steep': Chart3DView(azimuth: 0, elevation: 60, perspective: 15),
  };

  /// The preset [name] for a chart of [type] (pie presets for pies), or null.
  static Chart3DView? preset(
    String name, {
    ChartType type = ChartType.column,
  }) => type == ChartType.pie ? piePresets[name] : presets[name];

  /// [azimuth] in 0 ≤ a < 360.
  double get normalizedAzimuth => ChartThreeD.normalizeAzimuth(azimuth);

  /// This view with its azimuth normalized and the other values clamped.
  Chart3DView get normalized => Chart3DView(
    azimuth: normalizedAzimuth,
    elevation: elevation.clamp(
      ChartThreeD.minElevation,
      ChartThreeD.maxElevation,
    ),
    perspective: perspective.clamp(0.0, ChartThreeD.maxPerspective),
  );

  /// Copy with changes.
  Chart3DView copyWith({
    double? azimuth,
    double? elevation,
    double? perspective,
  }) => Chart3DView(
    azimuth: azimuth ?? this.azimuth,
    elevation: elevation ?? this.elevation,
    perspective: perspective ?? this.perspective,
  );

  /// This view rotated by [azimuth] and tilted by [elevation] degrees (`chartOrbit` offsets);
  /// the elevation stays within 0..90.
  Chart3DView rotated({double azimuth = 0, double elevation = 0}) =>
      Chart3DView(
        azimuth: this.azimuth + azimuth,
        elevation: (this.elevation + elevation).clamp(
          ChartThreeD.minElevation,
          ChartThreeD.maxElevation,
        ),
        perspective: perspective,
      );

  /// The view between [a] and [b] at [t] (0..1, already eased; values outside are clamped):
  /// elevation and perspective linearly, the azimuth along the shortest arc between the two
  /// angles ([turn] = `shortest`), or always increasing ([Chart3DTurn.cw]) / decreasing
  /// ([Chart3DTurn.ccw]), plus [turns] extra full turns in that direction (for `shortest`
  /// the direction of the shorter arc; ties turn clockwise). The result's azimuth is
  /// normalized; `lerp(a, b, 0)` and `lerp(a, b, 1)` equal `a`/`b` normalized.
  static Chart3DView lerp(
    Chart3DView a,
    Chart3DView b,
    double t, {
    Chart3DTurn turn = Chart3DTurn.shortest,
    int turns = 0,
  }) {
    final tt = t.isNaN ? 0.0 : t.clamp(0.0, 1.0);
    final delta = azimuthDelta(a.azimuth, b.azimuth, turn: turn, turns: turns);
    return Chart3DView(
      azimuth: ChartThreeD.normalizeAzimuth(a.azimuth + delta * tt),
      elevation: a.elevation + (b.elevation - a.elevation) * tt,
      perspective: a.perspective + (b.perspective - a.perspective) * tt,
    );
  }

  /// The signed azimuth change (degrees) from [from] to [to] for [turn] and [turns] (see
  /// [lerp]).
  static double azimuthDelta(
    double from,
    double to, {
    Chart3DTurn turn = Chart3DTurn.shortest,
    int turns = 0,
  }) {
    final cw = ChartThreeD.normalizeAzimuth(to - from); // 0 ≤ cw < 360
    final extra = 360.0 * (turns < 0 ? 0 : turns);
    switch (turn) {
      case Chart3DTurn.cw:
        return cw + extra;
      case Chart3DTurn.ccw:
        return cw == 0 ? -extra : -(360 - cw) - extra;
      case Chart3DTurn.shortest:
        if (cw <= 180) return cw + extra;
        return -(360 - cw) - extra;
    }
  }

  /// [threeD] with this view's angles (normalized) and perspective.
  ChartThreeD applyTo(ChartThreeD threeD) => threeD.copyWith(
    azimuth: normalizedAzimuth,
    elevation: elevation.clamp(
      ChartThreeD.minElevation,
      ChartThreeD.maxElevation,
    ),
    perspective: perspective.clamp(0.0, ChartThreeD.maxPerspective),
  );

  /// `{azimuth, elevation, perspective}` (numbers as in spec JSON).
  Map<String, Object?> toJson() => {
    'azimuth': jsonNum(azimuth),
    'elevation': jsonNum(elevation),
    'perspective': jsonNum(perspective),
  };

  @override
  bool operator ==(Object other) =>
      other is Chart3DView &&
      other.azimuth == azimuth &&
      other.elevation == elevation &&
      other.perspective == perspective;

  @override
  int get hashCode => Object.hash(azimuth, elevation, perspective);

  @override
  String toString() =>
      'Chart3DView(azimuth: $azimuth, elevation: $elevation, '
      'perspective: $perspective)';
}
