import 'chart_type.dart';
import 'spec_json.dart';

/// Lighting preset of a 3D chart (08 §23.2).
enum Chart3DLighting {
  /// Soft key light, gentle shading and specular (default).
  soft,

  /// Strong key light with a brighter highlight.
  bright,

  /// Classic flat tones per face (top lighter, sides darker), no highlight.
  flat,
}

/// Shape of 3D columns and bars (Excel `c:shape`).
enum Chart3DShape { box, cylinder, cone, pyramid }

/// The `threeD` section of a chart spec (08 §23): whether a column, bar, line, area or pie chart
/// is drawn in 3D and how it is viewed and lit. Stored in `specJson`; values equal to their
/// defaults are omitted.
final class ChartThreeD extends SpecNode {
  /// Creates 3D options.
  const ChartThreeD({
    this.enabled = false,
    this.azimuth,
    this.elevation,
    this.perspective = defaultPerspective,
    this.depth = 100,
    this.gapDepth = 150,
    this.lighting = Chart3DLighting.soft,
    this.wallsVisible = true,
    this.floorColor,
    this.shape = Chart3DShape.box,
    this.explode = 0,
    this.extras = const {},
  });

  /// Parses JSON leniently (out-of-range values are clamped).
  factory ChartThreeD.fromJson(Object? json) {
    final r = JsonReader(json);
    final az = r.dbl('azimuth');
    final el = r.dbl('elevation');
    return ChartThreeD(
      enabled: r.boolOr('enabled', false),
      azimuth: az == null ? null : normalizeAzimuth(az),
      elevation: el?.clamp(minElevation, maxElevation),
      perspective: r
          .dblOr('perspective', defaultPerspective)
          .clamp(0.0, maxPerspective),
      depth: r.dblOr('depth', 100).clamp(20.0, 2000.0),
      gapDepth: r.dblOr('gapDepth', 150).clamp(0.0, 500.0),
      lighting: r.enumOr(
        'lighting',
        Chart3DLighting.values,
        Chart3DLighting.soft,
      ),
      wallsVisible: r.boolOr('wallsVisible', true),
      floorColor: r.str('floorColor'),
      shape: r.enumOr('shape', Chart3DShape.values, Chart3DShape.box),
      explode: r.dblOr('explode', 0).clamp(0.0, 1.0),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {
    'enabled',
    'azimuth',
    'elevation',
    'perspective',
    'depth',
    'gapDepth',
    'lighting',
    'wallsVisible',
    'floorColor',
    'shape',
    'explode',
  };

  /// Off (a flat chart).
  static const ChartThreeD none = ChartThreeD();

  /// Default field of view in degrees (Excel's default `perspective` 30 = 15°).
  static const double defaultPerspective = 15;

  /// Largest field of view in degrees.
  static const double maxPerspective = 60;

  /// Elevation limits in degrees (the chart is always seen from above or level).
  static const double minElevation = 0;
  static const double maxElevation = 90;

  /// Whether the chart is drawn in 3D (only for [ChartType.supports3D] types).
  final bool enabled;

  /// Rotation about the vertical axis in degrees, 0 ≤ a < 360 (null = default of the type).
  final double? azimuth;

  /// View angle above the floor in degrees, 0..90 (null = default of the type).
  final double? elevation;

  /// Field of view in degrees, 0 (no perspective) .. 60.
  final double perspective;

  /// Depth of columns/rows (or pie height) in % of their width, 20..2000.
  final double depth;

  /// Gap between rows (and in front of/behind columns) in % of the row depth, 0..500.
  final double gapDepth;

  final Chart3DLighting lighting;

  /// Floor and back/side walls with gridlines (column, bar, line, area).
  final bool wallsVisible;

  /// Floor color (`#RRGGBB` / `theme:<key>`; null = from the theme).
  final String? floorColor;

  /// Shape of columns and bars.
  final Chart3DShape shape;

  /// Pie: every slice pulled out by this fraction of the radius (0..1).
  final double explode;

  final Map<String, Object?> extras;

  /// Whether [type] is drawn in 3D with these options.
  bool appliesTo(ChartType type) => type.only3D || (enabled && type.supports3D);

  /// The default azimuth of [type].
  static double defaultAzimuth(ChartType type) => switch (type) {
    ChartType.pie => 0,
    ChartType.surface => 35,
    _ => 20,
  };

  /// The default elevation of [type].
  static double defaultElevation(ChartType type) => switch (type) {
    ChartType.pie => 40,
    ChartType.surface => 28,
    _ => 20,
  };

  /// Effective azimuth for [type].
  double azimuthFor(ChartType type) => azimuth ?? defaultAzimuth(type);

  /// Effective elevation for [type].
  double elevationFor(ChartType type) => elevation ?? defaultElevation(type);

  /// [a] in 0 ≤ a < 360.
  static double normalizeAzimuth(double a) {
    if (!a.isFinite) return 0;
    final r = a % 360;
    return r < 0 ? r + 360 : r;
  }

  /// Copy with changes ([clearAzimuth]/[clearElevation] reset to the type defaults).
  ChartThreeD copyWith({
    bool? enabled,
    double? azimuth,
    double? elevation,
    bool clearAzimuth = false,
    bool clearElevation = false,
    double? perspective,
    double? depth,
    double? gapDepth,
    Chart3DLighting? lighting,
    bool? wallsVisible,
    String? floorColor,
    Chart3DShape? shape,
    double? explode,
  }) => ChartThreeD(
    enabled: enabled ?? this.enabled,
    azimuth: clearAzimuth ? null : (azimuth ?? this.azimuth),
    elevation: clearElevation ? null : (elevation ?? this.elevation),
    perspective: perspective ?? this.perspective,
    depth: depth ?? this.depth,
    gapDepth: gapDepth ?? this.gapDepth,
    lighting: lighting ?? this.lighting,
    wallsVisible: wallsVisible ?? this.wallsVisible,
    floorColor: floorColor ?? this.floorColor,
    shape: shape ?? this.shape,
    explode: explode ?? this.explode,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() =>
      (JsonWriter(extras)
            ..unlessDefault('enabled', enabled, false)
            ..opt('azimuth', azimuth == null ? null : jsonNum(azimuth!))
            ..opt('elevation', elevation == null ? null : jsonNum(elevation!))
            ..unlessDefault(
              'perspective',
              jsonNum(perspective),
              jsonNum(defaultPerspective),
            )
            ..unlessDefault('depth', jsonNum(depth), 100)
            ..unlessDefault('gapDepth', jsonNum(gapDepth), 150)
            ..unlessDefault(
              'lighting',
              lighting.name,
              Chart3DLighting.soft.name,
            )
            ..unlessDefault('wallsVisible', wallsVisible, true)
            ..opt('floorColor', floorColor)
            ..unlessDefault('shape', shape.name, Chart3DShape.box.name)
            ..unlessDefault('explode', jsonNum(explode), 0))
          .json;
}
