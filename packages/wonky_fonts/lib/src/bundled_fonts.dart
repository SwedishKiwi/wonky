/// The bundled static TTF faces (Slides 05 §3.1, Write 06 §8.1, Sheets 06
/// §6.1): the manifest of the files in this package's `fonts/` folder.
library;

/// One bundled static TTF face.
final class BundledFontFace {
  /// Creates a face entry.
  const BundledFontFace(
    this.family,
    this.weight,
    this.file, {
    this.italic = false,
  });

  /// The document family it renders (`"Source Sans 3"` for the renamed
  /// `WonkySansThree-*.ttf` instances).
  final String family;

  /// CSS weight 100–900.
  final int weight;

  /// Whether the face is italic.
  final bool italic;

  /// File name inside `fonts/` (`"OpenSans-Regular.ttf"`).
  final String file;

  /// The Flutter asset key of the file in an app depending on this package.
  String get assetKey => BundledFonts.assetKey(file);

  @override
  bool operator ==(Object other) =>
      other is BundledFontFace &&
      other.family == family &&
      other.weight == weight &&
      other.italic == italic &&
      other.file == file;

  @override
  int get hashCode => Object.hash(family, weight, italic, file);

  @override
  String toString() => '$family $weight${italic ? 'i' : ''} ($file)';
}

/// The fonts shipped as package assets of `wonky_fonts` (`fonts/`). The same
/// files are mirrored to `wonky_server/web/fonts/` for server-side PDF
/// exports, so client and server embed identical faces.
///
/// Static instances only: the `pdf` package supports neither variable fonts
/// nor CFF-flavoured OTF. Apps declare nothing: Flutter bundles the assets of
/// every (transitive) dependency, so they are available as
/// `packages/wonky_fonts/fonts/<file>` (loaded on demand, never at start-up).
abstract final class BundledFonts {
  /// The folder inside the package.
  static const directory = 'fonts';

  /// The Flutter asset key prefix of [directory].
  static const assetRoot = 'packages/wonky_fonts/$directory';

  /// The Flutter asset key of [file] (a file name inside `fonts/`).
  static String assetKey(String file) => '$assetRoot/$file';

  static const openSans = 'Open Sans';
  static const ebGaramond = 'EB Garamond';
  static const jetBrainsMono = 'JetBrains Mono';
  static const roboto = 'Roboto';
  static const robotoMono = 'Roboto Mono';
  static const lato = 'Lato';
  static const sourceSans3 = 'Source Sans 3';
  static const nunito = 'Nunito';
  static const montserrat = 'Montserrat';
  static const merriweather = 'Merriweather';

  /// Every bundled face.
  static const List<BundledFontFace> faces = [
    BundledFontFace(openSans, 400, 'OpenSans-Regular.ttf'),
    BundledFontFace(openSans, 400, 'OpenSans-Italic.ttf', italic: true),
    BundledFontFace(openSans, 600, 'OpenSans-SemiBold.ttf'),
    BundledFontFace(openSans, 700, 'OpenSans-Bold.ttf'),
    BundledFontFace(openSans, 700, 'OpenSans-BoldItalic.ttf', italic: true),
    BundledFontFace(ebGaramond, 400, 'EBGaramond-Regular.ttf'),
    BundledFontFace(ebGaramond, 400, 'EBGaramond-Italic.ttf', italic: true),
    BundledFontFace(ebGaramond, 600, 'EBGaramond-SemiBold.ttf'),
    BundledFontFace(ebGaramond, 700, 'EBGaramond-Bold.ttf'),
    BundledFontFace(ebGaramond, 700, 'EBGaramond-BoldItalic.ttf', italic: true),
    BundledFontFace(jetBrainsMono, 400, 'JetBrainsMono-Regular.ttf'),
    BundledFontFace(
      jetBrainsMono,
      400,
      'JetBrainsMono-Italic.ttf',
      italic: true,
    ),
    BundledFontFace(jetBrainsMono, 700, 'JetBrainsMono-Bold.ttf'),
    BundledFontFace(
      jetBrainsMono,
      700,
      'JetBrainsMono-BoldItalic.ttf',
      italic: true,
    ),
    BundledFontFace(roboto, 400, 'Roboto-Regular.ttf'),
    BundledFontFace(roboto, 400, 'Roboto-Italic.ttf', italic: true),
    BundledFontFace(roboto, 700, 'Roboto-Bold.ttf'),
    BundledFontFace(roboto, 700, 'Roboto-BoldItalic.ttf', italic: true),
    BundledFontFace(robotoMono, 400, 'RobotoMono-Regular.ttf'),
    BundledFontFace(robotoMono, 700, 'RobotoMono-Bold.ttf'),
    BundledFontFace(lato, 400, 'Lato-Regular.ttf'),
    BundledFontFace(lato, 400, 'Lato-Italic.ttf', italic: true),
    BundledFontFace(lato, 700, 'Lato-Bold.ttf'),
    BundledFontFace(lato, 700, 'Lato-BoldItalic.ttf', italic: true),
    BundledFontFace(sourceSans3, 400, 'WonkySansThree-Regular.ttf'),
    BundledFontFace(
      sourceSans3,
      400,
      'WonkySansThree-Italic.ttf',
      italic: true,
    ),
    BundledFontFace(sourceSans3, 700, 'WonkySansThree-Bold.ttf'),
    BundledFontFace(
      sourceSans3,
      700,
      'WonkySansThree-BoldItalic.ttf',
      italic: true,
    ),
    BundledFontFace(nunito, 400, 'Nunito-Regular.ttf'),
    BundledFontFace(nunito, 400, 'Nunito-Italic.ttf', italic: true),
    BundledFontFace(nunito, 700, 'Nunito-Bold.ttf'),
    BundledFontFace(nunito, 700, 'Nunito-BoldItalic.ttf', italic: true),
    BundledFontFace(montserrat, 400, 'Montserrat-Regular.ttf'),
    BundledFontFace(montserrat, 400, 'Montserrat-Italic.ttf', italic: true),
    BundledFontFace(montserrat, 700, 'Montserrat-Bold.ttf'),
    BundledFontFace(montserrat, 700, 'Montserrat-BoldItalic.ttf', italic: true),
    BundledFontFace(merriweather, 400, 'Merriweather-Regular.ttf'),
    BundledFontFace(merriweather, 400, 'Merriweather-Italic.ttf', italic: true),
    BundledFontFace(merriweather, 700, 'Merriweather-Bold.ttf'),
    BundledFontFace(
      merriweather,
      700,
      'Merriweather-BoldItalic.ttf',
      italic: true,
    ),
  ];

  /// The license file (inside `fonts/`) of each bundled family.
  static const Map<String, String> licenseFiles = {
    openSans: 'OFL-OpenSans.txt',
    ebGaramond: 'OFL-EBGaramond.txt',
    jetBrainsMono: 'OFL-JetBrainsMono.txt',
    roboto: 'LICENSE-Roboto.txt',
    robotoMono: 'LICENSE-Roboto.txt',
    lato: 'OFL-Lato.txt',
    sourceSans3: 'OFL-WonkySansThree.txt',
    nunito: 'OFL-Nunito.txt',
    montserrat: 'OFL-Montserrat.txt',
    merriweather: 'OFL-Merriweather.txt',
  };

  /// The bundled families, in manifest order.
  static List<String> get families =>
      {for (final f in faces) f.family}.toList();

  /// Whether [family] has bundled faces (exact name).
  static bool isBundled(String family) => faces.any((f) => f.family == family);

  /// The bundled faces of [family] (empty when not bundled).
  static List<BundledFontFace> facesOf(String family) => [
    for (final f in faces)
      if (f.family == family) f,
  ];

  /// The face of [family] closest to [weight] with the requested style
  /// (the other style when the family has none of it; weight ties pick the
  /// heavier face), or `null` when [family] is not bundled.
  static BundledFontFace? closestFace(
    String family, {
    int weight = 400,
    bool italic = false,
  }) {
    final pool = facesOf(family);
    if (pool.isEmpty) return null;
    final sameStyle = pool.where((f) => f.italic == italic).toList();
    final candidates = sameStyle.isEmpty ? pool : sameStyle;
    candidates.sort((a, b) {
      final d = (a.weight - weight).abs().compareTo((b.weight - weight).abs());
      return d != 0 ? d : b.weight.compareTo(a.weight);
    });
    return candidates.first;
  }
}
