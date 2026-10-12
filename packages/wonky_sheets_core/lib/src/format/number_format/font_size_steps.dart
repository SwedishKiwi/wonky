/// Font sizes of the toolbar menu and the increase/decrease steps (06 §6.2).
abstract final class FontSizeSteps {
  /// Sizes listed in the font size menu.
  static const List<double> menu = [6, 7, 8, 9, 10, 11, 12, 14, 18, 24, 36];

  /// Sizes stepped through by `increaseFontSize` / `decreaseFontSize`.
  static const List<double> steps = [6, 7, 8, 9, 10, 11, 12, 14, 18, 24, 36, 48, 72, 96];

  /// Minimum size accepted by the stepper.
  static const double min = 1;

  /// Maximum size accepted by the stepper.
  static const double max = 400;

  /// The next larger step after [size] ([size] itself when already at or
  /// beyond the largest step).
  static double next(double size) {
    for (final s in steps) {
      if (s > size) return s;
    }
    return size;
  }

  /// The next smaller step before [size] ([size] itself when already at or
  /// below the smallest step).
  static double previous(double size) {
    for (var i = steps.length - 1; i >= 0; i--) {
      if (steps[i] < size) return steps[i];
    }
    return size;
  }

  /// Clamps a typed size to 1–400 with one decimal place.
  static double clampTyped(double size) {
    final c = size.clamp(min, max).toDouble();
    return (c * 10).round() / 10;
  }
}
