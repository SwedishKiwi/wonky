import 'dart:io';
import 'dart:typed_data';

import 'package:wonky_write_core/wonky_write_core.dart' as core;

/// One bundled static TTF face in `web/fonts/` (the same files the Write app
/// bundles in `assets/fonts/`, Write 06 §8.1).
typedef BundledFontFace = ({
  String family,
  int weight,
  bool italic,
  String file,
});

/// [core.FontProvider] over the bundled TTFs on disk (Write 06 §8.3
/// `FileSystemFontProvider`), used by server-side PDF/HTML/EPUB exports.
///
/// Family substitution matches the app's `AssetFontProvider`, so client and
/// server exports embed the same faces: unbundled registry families map by
/// category (sans → Open Sans, serif → EB Garamond, mono → JetBrains Mono);
/// Open Sans is the glyph fallback (Latin Extended, Greek, Cyrillic). Bytes
/// are cached in memory.
class FileSystemFontProvider implements core.FontProvider {
  FileSystemFontProvider({Directory? directory})
    : directory = directory ?? defaultDirectory();

  /// The process-wide provider (fonts are read once).
  static final FileSystemFontProvider instance = FileSystemFontProvider();

  final Directory directory;
  final Map<String, Future<Uint8List>> _bytes = {};

  static const openSans = 'Open Sans';
  static const ebGaramond = 'EB Garamond';
  static const jetBrainsMono = 'JetBrains Mono';

  static const List<BundledFontFace> faces = [
    (
      family: openSans,
      weight: 400,
      italic: false,
      file: 'OpenSans-Regular.ttf',
    ),
    (family: openSans, weight: 400, italic: true, file: 'OpenSans-Italic.ttf'),
    (
      family: openSans,
      weight: 600,
      italic: false,
      file: 'OpenSans-SemiBold.ttf',
    ),
    (family: openSans, weight: 700, italic: false, file: 'OpenSans-Bold.ttf'),
    (
      family: openSans,
      weight: 700,
      italic: true,
      file: 'OpenSans-BoldItalic.ttf',
    ),
    (
      family: ebGaramond,
      weight: 400,
      italic: false,
      file: 'EBGaramond-Regular.ttf',
    ),
    (
      family: ebGaramond,
      weight: 400,
      italic: true,
      file: 'EBGaramond-Italic.ttf',
    ),
    (
      family: ebGaramond,
      weight: 600,
      italic: false,
      file: 'EBGaramond-SemiBold.ttf',
    ),
    (
      family: ebGaramond,
      weight: 700,
      italic: false,
      file: 'EBGaramond-Bold.ttf',
    ),
    (
      family: ebGaramond,
      weight: 700,
      italic: true,
      file: 'EBGaramond-BoldItalic.ttf',
    ),
    (
      family: jetBrainsMono,
      weight: 400,
      italic: false,
      file: 'JetBrainsMono-Regular.ttf',
    ),
    (
      family: jetBrainsMono,
      weight: 400,
      italic: true,
      file: 'JetBrainsMono-Italic.ttf',
    ),
    (
      family: jetBrainsMono,
      weight: 700,
      italic: false,
      file: 'JetBrainsMono-Bold.ttf',
    ),
    (
      family: jetBrainsMono,
      weight: 700,
      italic: true,
      file: 'JetBrainsMono-BoldItalic.ttf',
    ),
  ];

  static const _bundledFamilies = {openSans, ebGaramond, jetBrainsMono};

  /// `web/fonts` of the server package (the working directory of
  /// `serverpod start`, tests and the Docker image).
  static Directory defaultDirectory() {
    for (final candidate in ['web/fonts', 'wonky_server/web/fonts']) {
      final d = Directory(candidate);
      if (d.existsSync()) return d;
    }
    return Directory('web/fonts');
  }

  /// The bundled family exports use for [family].
  static String exportFamilyFor(String family) {
    if (_bundledFamilies.contains(family)) return family;
    var category = core.FontCategory.sans;
    final known = core.FontRegistry.families.where((f) => f.family == family);
    if (known.isNotEmpty) {
      category = known.first.category;
    } else {
      final lower = family.toLowerCase();
      if (lower.contains('mono') || lower.contains('courier')) {
        category = core.FontCategory.mono;
      } else if (lower.contains('serif') && !lower.contains('sans')) {
        category = core.FontCategory.serif;
      }
    }
    return switch (category) {
      core.FontCategory.serif => ebGaramond,
      core.FontCategory.mono => jetBrainsMono,
      core.FontCategory.sans => openSans,
    };
  }

  static BundledFontFace _closest(String family, int weight, bool italic) {
    final pool = faces.where((f) => f.family == family).toList();
    final sameStyle = pool.where((f) => f.italic == italic).toList();
    final candidates = sameStyle.isEmpty ? pool : sameStyle;
    candidates.sort((a, b) {
      final d = (a.weight - weight).abs().compareTo((b.weight - weight).abs());
      return d != 0 ? d : b.weight.compareTo(a.weight);
    });
    return candidates.first;
  }

  Future<Uint8List> _read(String file) => _bytes.putIfAbsent(file, () async {
    final f = File('${directory.path}/$file');
    if (!await f.exists()) {
      throw core.FontUnavailableException(file);
    }
    return f.readAsBytes();
  });

  /// Whether the font files are present.
  bool get isAvailable =>
      File('${directory.path}/${faces.first.file}').existsSync();

  @override
  Future<core.FontFace> load(
    String family, {
    int weight = 400,
    bool italic = false,
  }) async {
    final face = _closest(exportFamilyFor(family), weight, italic);
    return core.FontFace(
      family: family,
      weight: face.weight,
      italic: face.italic,
      bytes: await _read(face.file),
    );
  }

  @override
  Future<List<core.FontFace>> fallbacksFor(String text) async {
    final face = _closest(openSans, 400, false);
    return [
      core.FontFace(
        family: openSans,
        weight: face.weight,
        italic: false,
        bytes: await _read(face.file),
      ),
    ];
  }
}
