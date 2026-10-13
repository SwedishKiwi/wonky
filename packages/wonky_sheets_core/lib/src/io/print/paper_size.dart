/// Paper sizes of the print settings (11 §7.2), in PDF points (1/72 in).
enum PaperSize {
  letter('Letter', 612, 792),
  tabloid('Tabloid', 792, 1224),
  legal('Legal', 612, 1008),
  statement('Statement', 396, 612),
  executive('Executive', 522, 756),
  folio('Folio', 612, 936),
  a3('A3', 841.89, 1190.55),
  a4('A4', 595.28, 841.89),
  a5('A5', 419.53, 595.28),
  b4('B4', 708.66, 1000.63),
  b5('B5', 498.9, 708.66),
  custom('Custom', 612, 792);

  const PaperSize(this.label, this.widthPt, this.heightPt);

  /// Menu label.
  final String label;

  /// Portrait width / height in points ([custom]: placeholder Letter).
  final double widthPt;
  final double heightPt;

  /// The settings JSON id (`letter`, `a4`, …).
  String get id => name;

  /// Parses an id (case-insensitive); null when unknown.
  static PaperSize? tryParse(Object? id) {
    if (id is! String) return null;
    final l = id.toLowerCase();
    for (final p in values) {
      if (p.name == l) return p;
    }
    return null;
  }

  /// Default paper for a spreadsheet locale: Letter for `en_US`, `en_CA`,
  /// `es_MX` (and US-style locales), A4 otherwise.
  static PaperSize defaultFor(String locale) {
    final l = locale.replaceAll('-', '_').toLowerCase();
    const letterLocales = {
      'en_us',
      'en_ca',
      'es_mx',
      'en',
      'fr_ca',
      'es_us',
      'en_ph',
      'es_co',
    };
    return letterLocales.contains(l) ? letter : a4;
  }
}

/// Points per unit.
abstract final class PrintUnits {
  /// Points per inch.
  static const double pointsPerInch = 72;

  /// Points per centimetre.
  static const double pointsPerCm = 72 / 2.54;

  /// Points per grid px at 100 % (96 dpi).
  static const double pointsPerPx = 0.75;

  /// [value] in [unit] (`in` | `cm` | `pt`) as points.
  static double toPoints(double value, String unit) => switch (unit) {
    'cm' => value * pointsPerCm,
    'mm' => value * pointsPerCm / 10,
    'pt' => value,
    _ => value * pointsPerInch,
  };
}
