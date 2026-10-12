import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

/// One bundled static TTF face (`assets/fonts/`).
@immutable
class BundledFace {
  const BundledFace(this.family, this.weight, this.italic, this.asset);

  final String family;
  final int weight;
  final bool italic;
  final String asset;
}

/// The document fonts bundled with Wonky Write (Write 06 §8).
///
/// They are declared as plain `assets:` (not `fonts:`), so Flutter web does
/// not download them at start-up: [WriteFonts.ensureLoaded] registers a
/// family with the engine the first time a theme needs it, and
/// [AssetFontProvider] hands the same bytes to the PDF exporter (static TTF
/// instances — the `pdf` package cannot embed variable fonts).
///
/// Families of the curated registry that are not bundled are substituted by
/// category (sans → Inter on screen / Open Sans in PDFs, serif → EB Garamond,
/// mono → JetBrains Mono). Open Sans also serves as the glyph fallback in
/// PDFs (Latin Extended, Greek, Cyrillic).
abstract final class WriteFonts {
  static const openSans = 'Open Sans';
  static const ebGaramond = 'EB Garamond';
  static const jetBrainsMono = 'JetBrains Mono';

  /// Inter / Geist ship with `shad` (variable fonts, screen only).
  static const shadInter = 'packages/shad/Inter';
  static const shadGeist = 'packages/shad/Geist';
  static const shadGeistMono = 'packages/shad/GeistMono';

  static const faces = <BundledFace>[
    BundledFace(openSans, 400, false, 'assets/fonts/OpenSans-Regular.ttf'),
    BundledFace(openSans, 400, true, 'assets/fonts/OpenSans-Italic.ttf'),
    BundledFace(openSans, 600, false, 'assets/fonts/OpenSans-SemiBold.ttf'),
    BundledFace(openSans, 700, false, 'assets/fonts/OpenSans-Bold.ttf'),
    BundledFace(openSans, 700, true, 'assets/fonts/OpenSans-BoldItalic.ttf'),
    BundledFace(ebGaramond, 400, false, 'assets/fonts/EBGaramond-Regular.ttf'),
    BundledFace(ebGaramond, 400, true, 'assets/fonts/EBGaramond-Italic.ttf'),
    BundledFace(ebGaramond, 600, false, 'assets/fonts/EBGaramond-SemiBold.ttf'),
    BundledFace(ebGaramond, 700, false, 'assets/fonts/EBGaramond-Bold.ttf'),
    BundledFace(
      ebGaramond,
      700,
      true,
      'assets/fonts/EBGaramond-BoldItalic.ttf',
    ),
    BundledFace(
      jetBrainsMono,
      400,
      false,
      'assets/fonts/JetBrainsMono-Regular.ttf',
    ),
    BundledFace(
      jetBrainsMono,
      400,
      true,
      'assets/fonts/JetBrainsMono-Italic.ttf',
    ),
    BundledFace(
      jetBrainsMono,
      700,
      false,
      'assets/fonts/JetBrainsMono-Bold.ttf',
    ),
    BundledFace(
      jetBrainsMono,
      700,
      true,
      'assets/fonts/JetBrainsMono-BoldItalic.ttf',
    ),
  ];

  static const _bundledFamilies = {openSans, ebGaramond, jetBrainsMono};

  /// The registry category of [family] (sans when unknown).
  static FontCategory categoryOf(String family) {
    for (final f in FontRegistry.families) {
      if (f.family == family) return f.category;
    }
    final lower = family.toLowerCase();
    if (lower.contains('mono') || lower.contains('courier')) {
      return FontCategory.mono;
    }
    if (lower.contains('serif') && !lower.contains('sans')) {
      return FontCategory.serif;
    }
    return FontCategory.sans;
  }

  /// The bundled family used for [family] in exported PDFs.
  static String exportFamilyFor(String family) {
    if (_bundledFamilies.contains(family)) return family;
    return switch (categoryOf(family)) {
      FontCategory.serif => ebGaramond,
      FontCategory.mono => jetBrainsMono,
      FontCategory.sans => openSans,
    };
  }

  /// The Flutter font family to render [family] with on screen.
  static String screenFamilyFor(String family) {
    switch (family) {
      case 'Inter':
        return shadInter;
      case 'Geist':
        return shadGeist;
      case 'Geist Mono':
        return shadGeistMono;
    }
    if (_bundledFamilies.contains(family)) return family;
    return switch (categoryOf(family)) {
      FontCategory.serif => ebGaramond,
      FontCategory.mono => jetBrainsMono,
      FontCategory.sans => shadInter,
    };
  }

  /// Generic fallbacks for [family] on screen.
  static List<String> screenFallbackFor(String family) =>
      switch (categoryOf(family)) {
        FontCategory.serif => const ['Georgia', 'Times New Roman', 'serif'],
        FontCategory.mono => const ['Menlo', 'Consolas', 'monospace'],
        FontCategory.sans => const ['Helvetica', 'Arial', 'sans-serif'],
      };

  static final Map<String, Future<void>> _loading = {};

  /// Bumped every time a family finished loading (re-layout the editor).
  static final ValueNotifier<int> generation = ValueNotifier(0);

  /// Registers the bundled faces of [families] (screen families as returned
  /// by [screenFamilyFor]) with the engine. Safe to call repeatedly.
  static Future<void> ensureLoaded(Iterable<String> families) async {
    final pending = <Future<void>>[];
    for (final family in families.toSet()) {
      if (!_bundledFamilies.contains(family)) continue;
      pending.add(_loading.putIfAbsent(family, () => _load(family)));
    }
    await Future.wait(pending);
  }

  static Future<void> _load(String family) async {
    try {
      final loader = FontLoader(family);
      for (final face in faces.where((f) => f.family == family)) {
        loader.addFont(rootBundle.load(face.asset));
      }
      await loader.load();
      generation.value++;
    } catch (e) {
      debugPrint('Loading font $family failed: $e');
    }
  }
}

/// [FontProvider] over the bundled TTFs (client-side PDF export, Write 06
/// §8.3). Unbundled families are substituted by category; [fallbacksFor]
/// returns Open Sans (broad European coverage).
class AssetFontProvider implements FontProvider {
  AssetFontProvider({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, Future<Uint8List>> _bytes = {};

  Future<Uint8List> _read(String asset) => _bytes.putIfAbsent(asset, () async {
    final data = await _bundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  });

  BundledFace _closest(String family, int weight, bool italic) {
    final pool = WriteFonts.faces.where((f) => f.family == family).toList();
    final sameStyle = pool.where((f) => f.italic == italic).toList();
    final candidates = sameStyle.isEmpty ? pool : sameStyle;
    candidates.sort((a, b) {
      final d = (a.weight - weight).abs().compareTo((b.weight - weight).abs());
      return d != 0 ? d : b.weight.compareTo(a.weight);
    });
    return candidates.first;
  }

  @override
  Future<FontFace> load(
    String family, {
    int weight = 400,
    bool italic = false,
  }) async {
    final face = _closest(WriteFonts.exportFamilyFor(family), weight, italic);
    return FontFace(
      family: family,
      weight: face.weight,
      italic: face.italic,
      bytes: await _read(face.asset),
    );
  }

  @override
  Future<List<FontFace>> fallbacksFor(String text) async {
    final face = _closest(WriteFonts.openSans, 400, false);
    return [
      FontFace(
        family: WriteFonts.openSans,
        weight: face.weight,
        italic: false,
        bytes: await _read(face.asset),
      ),
    ];
  }
}

bool _licensesRegistered = false;

/// Adds the OFL licenses of the bundled document fonts to the app's license
/// page (Write 06 §8.1).
void registerWriteFontLicenses() {
  if (_licensesRegistered) return;
  _licensesRegistered = true;
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      (WriteFonts.openSans, 'OFL-OpenSans.txt'),
      (WriteFonts.ebGaramond, 'OFL-EBGaramond.txt'),
      (WriteFonts.jetBrainsMono, 'OFL-JetBrainsMono.txt'),
    ]) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
