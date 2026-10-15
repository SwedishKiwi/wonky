/// Font resolution for slides (Slides 05 §3): theme fonts must be bundled
/// families (`wonky_fonts` `BundledFonts`), so the canvas, thumbnails,
/// presenting and the PDF renderers (client and server) use the same files.
library;

import 'package:wonky_fonts/wonky_fonts.dart';

import '../model/common.dart';

/// A resolved face for a requested family/weight/style.
final class ResolvedFontFace {
  /// Creates a resolved face.
  const ResolvedFontFace({
    required this.requestedFamily,
    required this.requestedWeight,
    required this.face,
    required this.category,
    required this.isFallback,
  });

  /// The family the theme or run asked for.
  final String requestedFamily;

  /// The weight asked for (100–900).
  final int requestedWeight;

  /// The bundled face used (closest weight, ties heavier; same style first).
  final BundledFontFace face;

  /// The category of the requested family (drives the fallback).
  final FontCategory category;

  /// Whether [face] belongs to a fallback family (the requested family is
  /// not bundled).
  final bool isFallback;

  /// The family drawn.
  String get family => face.family;

  /// The weight drawn (snapped to a shipped weight).
  int get weight => face.weight;

  /// Whether the face is italic.
  bool get italic => face.italic;

  @override
  bool operator ==(Object other) =>
      other is ResolvedFontFace &&
      other.requestedFamily == requestedFamily &&
      other.requestedWeight == requestedWeight &&
      other.face == face &&
      other.isFallback == isFallback;

  @override
  int get hashCode =>
      Object.hash(requestedFamily, requestedWeight, face, isFallback);

  @override
  String toString() =>
      'ResolvedFontFace($requestedFamily $requestedWeight → $face'
      '${isFallback ? ', fallback' : ''})';
}

/// The fonts Slides can draw: every family of `BundledFonts` (static TTF,
/// identical on client and server).
abstract final class SlidesFonts {
  /// Categories of the bundled families (the curated `FontRegistry` lacks
  /// some of them, e.g. Nunito, Roboto, Lato).
  static const Map<String, FontCategory> _bundledCategories = {
    BundledFonts.openSans: FontCategory.sans,
    BundledFonts.ebGaramond: FontCategory.serif,
    BundledFonts.jetBrainsMono: FontCategory.mono,
    BundledFonts.roboto: FontCategory.sans,
    BundledFonts.robotoMono: FontCategory.mono,
    BundledFonts.lato: FontCategory.sans,
    BundledFonts.sourceSans3: FontCategory.sans,
    BundledFonts.nunito: FontCategory.sans,
    BundledFonts.montserrat: FontCategory.sans,
    BundledFonts.merriweather: FontCategory.serif,
  };

  /// The fallback family per category (05 §2.3: unknown families fall back
  /// by category).
  static const Map<FontCategory, String> fallbackFamilies = {
    FontCategory.sans: BundledFonts.openSans,
    FontCategory.serif: BundledFonts.merriweather,
    FontCategory.mono: BundledFonts.jetBrainsMono,
  };

  /// The selectable families (bundled), in manifest order.
  static List<String> get families => BundledFonts.families;

  /// The canonical name of a bundled family (case-insensitive), or `null`.
  static String? canonicalName(String family) {
    final lower = family.trim().toLowerCase();
    for (final f in BundledFonts.families) {
      if (f.toLowerCase() == lower) return f;
    }
    return null;
  }

  /// Whether [family] can be drawn without a fallback.
  static bool isAvailable(String family) => canonicalName(family) != null;

  /// The category of [family]: bundled families, then the curated registry
  /// (e.g. `Inter` → sans), else `null`.
  static FontCategory? categoryOf(String family) {
    final canonical = canonicalName(family);
    if (canonical != null) return _bundledCategories[canonical];
    return FontRegistry.lookup(family)?.category;
  }

  /// The default category of a theme font role.
  static FontCategory categoryOfRole(ThemeFontRole role) =>
      role == ThemeFontRole.mono ? FontCategory.mono : FontCategory.sans;

  /// Resolves [family] at [weight]/[italic] to a bundled face. Families that
  /// are not bundled fall back to [fallbackFamilies] of their category (or
  /// of [defaultCategory] when the category is unknown).
  static ResolvedFontFace resolve(
    String family, {
    int weight = 400,
    bool italic = false,
    FontCategory defaultCategory = FontCategory.sans,
  }) {
    final canonical = canonicalName(family);
    final category = categoryOf(family) ?? defaultCategory;
    final drawn = canonical ?? fallbackFamilies[category]!;
    final face = BundledFonts.closestFace(
      drawn,
      weight: weight.clamp(100, 900),
      italic: italic,
    )!;
    return ResolvedFontFace(
      requestedFamily: family,
      requestedWeight: weight,
      face: face,
      category: category,
      isFallback: canonical == null,
    );
  }
}
