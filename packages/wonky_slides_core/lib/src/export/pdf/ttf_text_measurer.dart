/// The real font-metrics measurer of the core text layout (12 §4 SL-10 →
/// SL-20, 10 §11.3): advance widths and vertical metrics read from the
/// bundled static TTFs (`wonky_fonts`) with the `pdf` package's TTF parser,
/// so server-side layouts (PDF, headless previews) break lines like the
/// stage and the PDF draws exactly the measured glyphs.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart' show TtfParser;
import 'package:wonky_fonts/wonky_fonts.dart';

import '../../text_layout/slide_text_layout.dart';
import '../../text_layout/text_paragraphs.dart';
import '../../theme/fonts/slides_fonts.dart';

/// The metrics of one parsed TTF face.
final class TtfFaceMetrics {
  /// Parses [bytes] (a static TrueType face).
  TtfFaceMetrics(this.face)
    : _parser = TtfParser(ByteData.sublistView(face.bytes)) {
    final em = _parser.unitsPerEm.toDouble();
    ascent = _parser.ascent / em;
    descent = -_parser.descent / em;
  }

  /// The face (family, weight, style, bytes).
  final FontFace face;
  final TtfParser _parser;

  /// Above the baseline (em, positive).
  late final double ascent;

  /// Below the baseline (em, positive).
  late final double descent;

  final Map<int, double> _advances = {};

  /// Whether the face has a glyph for [rune].
  bool hasGlyph(int rune) => _parser.charToGlyphIndexMap.containsKey(rune);

  /// The advance of [rune] in em, or null when the face has no glyph.
  double? advance(int rune) {
    final hit = _advances[rune];
    if (hit != null) return hit;
    final g = _parser.charToGlyphIndexMap[rune];
    if (g == null) return null;
    return _advances[rune] = _parser.glyphInfoMap[g]?.advanceWidth ?? 0;
  }
}

/// A set of loaded faces keyed by the family/weight/style text runs ask
/// for (resolved with `SlidesFonts.resolve`, like the stage), plus glyph
/// fallback faces.
final class TtfFaceSet {
  /// Creates a set over [faces] (by requested key) and [fallbacks].
  TtfFaceSet(
    Map<FontFaceKey, TtfFaceMetrics> faces, [
    this.fallbacks = const [],
  ]) : _faces = Map.of(faces);

  final Map<FontFaceKey, TtfFaceMetrics> _faces;

  /// Glyph fallback faces, in order (missing glyphs of every face).
  final List<TtfFaceMetrics> fallbacks;

  /// Every loaded face by requested key.
  Map<FontFaceKey, TtfFaceMetrics> get faces => Map.unmodifiable(_faces);

  /// The key text runs of [family]/[weight]/[italic] are looked up by.
  static FontFaceKey keyOf(String family, int weight, bool italic) =>
      FontFaceKey(family, weight, italic: italic);

  /// The face of a run, or null when not loaded.
  TtfFaceMetrics? faceOf(String family, int weight, bool italic) =>
      _faces[keyOf(family, weight, italic)];

  /// Loads the faces of [keys] from [provider] (requested family → the
  /// bundled face `SlidesFonts.resolve` picks; families the provider can't
  /// load are left out, the measurer then approximates them) and the glyph
  /// fallbacks for [fallbackText].
  static Future<TtfFaceSet> load(
    FontProvider provider,
    Iterable<FontFaceKey> keys, {
    String fallbackText = '',
    void Function(FontFaceKey key)? onMissing,
  }) async {
    final out = <FontFaceKey, TtfFaceMetrics>{};
    final byFile = <String, TtfFaceMetrics>{};
    for (final key in keys.toSet()) {
      try {
        final face = await provider.load(
          key.family,
          weight: key.weight,
          italic: key.italic,
        );
        final id =
            '${face.family}|${face.weight}|${face.italic}|'
            '${face.bytes.length}';
        out[key] = byFile[id] ??= TtfFaceMetrics(face);
      } on FontUnavailableException {
        onMissing?.call(key);
      }
    }
    final fallbacks = <TtfFaceMetrics>[];
    if (fallbackText.isNotEmpty) {
      for (final f in await provider.fallbacksFor(fallbackText)) {
        fallbacks.add(TtfFaceMetrics(f));
      }
    }
    return TtfFaceSet(out, fallbacks);
  }
}

/// A [SlideTextMeasurer] over real TTF metrics ([TtfFaceSet]). Characters
/// missing in a run's face are measured in the first fallback face that has
/// them (the PDF draws them with that face); faces that are not loaded are
/// approximated with [ApproxTextMeasurer]. No kerning (the PDF writer
/// draws without it).
final class TtfTextMeasurer implements SlideTextMeasurer {
  /// Creates a measurer over [faces].
  TtfTextMeasurer(this.faces);

  /// The loaded faces.
  final TtfFaceSet faces;

  static const _approx = ApproxTextMeasurer();

  @override
  double width(String text, StyledRun run) {
    final face = faces.faceOf(run.fontFamily, run.fontWeight, run.italic);
    if (face == null) return _approx.width(text, run);
    var em = 0.0;
    var n = 0;
    for (final r in text.runes) {
      n++;
      if (r == 0x2028 || r == 0x0a) continue;
      em += face.advance(r) ?? _fallbackAdvance(r);
    }
    return em * run.fontSize + run.letterSpacing * n;
  }

  double _fallbackAdvance(int rune) {
    for (final f in faces.fallbacks) {
      final a = f.advance(rune);
      if (a != null) return a;
    }
    return ApproxTextMeasurer.advance(rune);
  }

  @override
  FontVMetrics metrics(StyledRun run) {
    final face = faces.faceOf(run.fontFamily, run.fontWeight, run.italic);
    if (face == null) return _approx.metrics(run);
    return FontVMetrics(face.ascent, face.descent);
  }
}

/// A measurer that approximates like [ApproxTextMeasurer] and records the
/// faces and characters text runs ask for — the first layout pass of an
/// export, which tells it which TTFs to load.
final class RecordingTextMeasurer implements SlideTextMeasurer {
  /// The requested faces.
  final Set<FontFaceKey> keys = {};

  /// Every measured character (glyph coverage checks).
  final Set<int> runes = {};

  static const _approx = ApproxTextMeasurer();

  @override
  double width(String text, StyledRun run) {
    keys.add(TtfFaceSet.keyOf(run.fontFamily, run.fontWeight, run.italic));
    runes.addAll(text.runes);
    return _approx.width(text, run);
  }

  @override
  FontVMetrics metrics(StyledRun run) {
    keys.add(TtfFaceSet.keyOf(run.fontFamily, run.fontWeight, run.italic));
    return _approx.metrics(run);
  }
}

/// A pure-Dart [FontProvider] over the bundled TTF files of `wonky_fonts`
/// (`BundledFonts`), read by file name with [read]: the server reads
/// `web/fonts/`, the app its package assets. Families resolve with
/// `SlidesFonts.resolve` (bundled families as themselves, others by
/// category), so client and server embed identical faces; Open Sans is the
/// glyph fallback.
final class BundledFileFontProvider implements FontProvider {
  /// Creates a provider reading files with [read] (null = missing).
  BundledFileFontProvider(this.read);

  /// Reads a file of `BundledFonts.directory` by name.
  final Future<Uint8List?> Function(String file) read;

  final Map<String, Future<Uint8List?>> _bytes = {};

  Future<Uint8List?> _file(String file) =>
      _bytes.putIfAbsent(file, () => read(file));

  @override
  Future<FontFace> load(
    String family, {
    int weight = 400,
    bool italic = false,
  }) async {
    final resolved = SlidesFonts.resolve(
      family,
      weight: weight,
      italic: italic,
      defaultCategory: _categoryGuess(family),
    );
    final bytes = await _file(resolved.face.file);
    if (bytes == null) throw FontUnavailableException(family);
    return FontFace(
      family: resolved.face.family,
      weight: resolved.face.weight,
      italic: resolved.face.italic,
      bytes: bytes,
    );
  }

  /// Whether [family] is drawn with a substitute (not bundled).
  static bool isSubstituted(String family) => !SlidesFonts.isAvailable(family);

  static FontCategory _categoryGuess(String family) {
    final l = family.toLowerCase();
    if (l.contains('mono') || l.contains('courier') || l.contains('code')) {
      return FontCategory.mono;
    }
    if (l.contains('serif') && !l.contains('sans')) return FontCategory.serif;
    return FontCategory.sans;
  }

  @override
  Future<List<FontFace>> fallbacksFor(String text) async {
    final face = BundledFonts.closestFace(BundledFonts.openSans)!;
    final bytes = await _file(face.file);
    if (bytes == null) return const [];
    return [
      FontFace(
        family: face.family,
        weight: face.weight,
        italic: face.italic,
        bytes: bytes,
      ),
    ];
  }
}
