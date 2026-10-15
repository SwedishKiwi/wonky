/// Slide sizes, units and the page-setup scaling math (Slides 05 §7,
/// 02 §2.2).
library;

import 'dart:math' as math;

import '../model/common.dart';

/// The size presets (02 §3.11 `SlideSizePreset`; names match the synced
/// enum).
enum SlideSizeKind {
  /// 1920 × 1080 (default).
  widescreen16x9(1920, 1080),

  /// 1440 × 1080.
  standard4x3(1440, 1080),

  /// 1728 × 1080.
  wide16x10(1728, 1080),

  /// 1080 × 1080.
  square(1080, 1080),

  /// 1080 × 1920 (P1).
  portrait9x16(1080, 1920),

  /// 1527 × 1080 (A4 landscape ratio).
  a4(1527, 1080),

  /// 1397 × 1080 (US Letter landscape).
  letter(1397, 1080),

  /// Any size within the limits of [SlideSize.validate].
  custom(0, 0);

  const SlideSizeKind(this.width, this.height);

  /// Preset width (su); 0 for [custom].
  final double width;

  /// Preset height (su); 0 for [custom].
  final double height;

  /// Parses a name; `null` when unknown.
  static SlideSizeKind? fromName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// A deck size (`Deck.sizePreset`, `width`, `height`).
final class SlideSize {
  /// Creates a size.
  const SlideSize(this.kind, this.width, this.height);

  /// The size of preset [kind] (not [SlideSizeKind.custom]).
  factory SlideSize.preset(SlideSizeKind kind) {
    if (kind == SlideSizeKind.custom) {
      throw ArgumentError('custom has no preset size; use SlideSize.custom');
    }
    return SlideSize(kind, kind.width, kind.height);
  }

  /// A custom size; throws [ArgumentError] outside the limits.
  factory SlideSize.custom(double width, double height) {
    final problem = validate(width, height);
    if (problem != null) throw ArgumentError(problem);
    for (final k in SlideSizeKind.values) {
      if (k != SlideSizeKind.custom && k.width == width && k.height == height) {
        return SlideSize(k, width, height);
      }
    }
    return SlideSize(SlideSizeKind.custom, width, height);
  }

  /// The default 16:9 size.
  static const SlideSize widescreen = SlideSize(
    SlideSizeKind.widescreen16x9,
    1920,
    1080,
  );

  /// Minimum side (su).
  static const double minSide = 320;

  /// Maximum side (su).
  static const double maxSide = 7680;

  /// The preset.
  final SlideSizeKind kind;

  /// Width (su).
  final double width;

  /// Height (su).
  final double height;

  /// Width / height.
  double get aspect => width / height;

  /// The full slide rectangle.
  SuRect get bounds => SuRect(0, 0, width, height);

  /// Whether the slide is taller than wide.
  bool get isPortrait => height > width;

  /// PDF page size in points (su / 2, 02 §2.2).
  (double, double) get pdfPageSize => (width / 2, height / 2);

  /// `null` when [width] × [height] is a valid deck size, else the message
  /// shown by page setup (02 §13: 320–7,680 su per side, aspect 1:4…4:1).
  static String? validate(double width, double height) {
    if (!width.isFinite || !height.isFinite) {
      return 'Enter a width and a height.';
    }
    if (width < minSide ||
        height < minSide ||
        width > maxSide ||
        height > maxSide) {
      return 'Each side must be between 320 and 7,680 su.';
    }
    final aspect = width / height;
    if (aspect < 0.25 - 1e-9 || aspect > 4 + 1e-9) {
      return 'The aspect ratio must be between 1:4 and 4:1.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SlideSize &&
      other.kind == kind &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(kind, width, height);

  @override
  String toString() => 'SlideSize(${kind.name}, $width × $height)';
}

/// Units of the page setup dialog (05 §7).
enum SlideUnit {
  /// Slide units.
  su,

  /// Screen pixels (96 px = 1 in).
  px,

  /// Inches.
  inch,

  /// Centimeters.
  cm,
}

/// Unit conversion: 1 su = ½ pt (PDF pages are su / 2 pt), so 1 in = 144 su,
/// 1 px = 1.5 su (96 px = 1 in), 1 cm = 144 / 2.54 su.
abstract final class SlideUnits {
  /// Slide units per inch.
  static const double suPerInch = 144;

  /// Slide units per [unit].
  static double suPer(SlideUnit unit) => switch (unit) {
    SlideUnit.su => 1,
    SlideUnit.px => suPerInch / 96,
    SlideUnit.inch => suPerInch,
    SlideUnit.cm => suPerInch / 2.54,
  };

  /// Converts [value] in [unit] to su.
  static double toSu(double value, SlideUnit unit) => value * suPer(unit);

  /// Converts [su] to [unit].
  static double fromSu(double su, SlideUnit unit) => su / suPer(unit);
}

/// The *Scale content* mapping of a size change (05 §7): a uniform scale
/// `s = min(w'/w, h'/h)` and a centering offset (letterbox).
final class SlideSizeScaling {
  /// Creates the mapping from [from] to [to].
  SlideSizeScaling(this.from, this.to)
    : scale = math.min(to.width / from.width, to.height / from.height) {
    dx = (to.width - from.width * scale) / 2;
    dy = (to.height - from.height * scale) / 2;
  }

  /// The old size.
  final SlideSize from;

  /// The new size.
  final SlideSize to;

  /// The uniform scale.
  final double scale;

  /// Horizontal centering offset (su).
  late final double dx;

  /// Vertical centering offset (su).
  late final double dy;

  /// Whether the mapping changes nothing.
  bool get isIdentity => scale == 1 && dx == 0 && dy == 0;

  /// Maps a point.
  (double, double) mapPoint(double x, double y) =>
      (x * scale + dx, y * scale + dy);

  /// Maps a frame in slide space (slides, layouts, masters; not group
  /// children, which live in the group's child space, 02 §6.9).
  SuRect mapRect(SuRect r) => SuRect(
    r.x * scale + dx,
    r.y * scale + dy,
    r.width * scale,
    r.height * scale,
  );

  /// Scales a length (font size, stroke width, inset).
  double scaleLength(double v) => v * scale;

  /// Scales a font size, clamped to 6–800 su.
  double scaleFontSize(double v) => (v * scale).clamp(6, 800).toDouble();
}
