/// The curated document font registry (Write 06 §8.1) and weight snapping (§8.2).
library;

/// Broad classification of a font family (drives CSS generic families and
/// the `FontPicker` sections).
enum FontCategory {
  /// Sans-serif.
  sans('sans-serif'),

  /// Serif.
  serif('serif'),

  /// Monospace.
  mono('monospace');

  const FontCategory(this.cssGeneric);

  /// The CSS generic family used as the last fallback.
  final String cssGeneric;
}

/// A Unicode script group used to pick fallback fonts.
enum FontScript {
  /// Latin, Greek and Cyrillic (covered by the curated families or Noto
  /// Sans).
  latin,

  /// Arabic.
  arabic,

  /// Hebrew.
  hebrew,

  /// Devanagari.
  devanagari,

  /// Han ideographs (simplified Chinese fallback).
  han,

  /// Japanese kana.
  kana,

  /// Korean hangul.
  hangul,

  /// Symbols, arrows, math, dingbats.
  symbols,

  /// Emoji.
  emoji,
}

/// One shipped face (weight + style) of a family.
final class FontFaceInfo {
  /// Creates a face description.
  const FontFaceInfo(this.weight, {this.italic = false});

  /// CSS weight 100–900.
  final int weight;

  /// Whether the face is italic.
  final bool italic;

  @override
  bool operator ==(Object other) =>
      other is FontFaceInfo && other.weight == weight && other.italic == italic;

  @override
  int get hashCode => Object.hash(weight, italic);

  @override
  String toString() => '$weight${italic ? 'i' : ''}';
}

/// Manifest entry of a font family (Write 06 §8.1).
final class FontFamilyInfo {
  /// Creates a manifest entry.
  const FontFamilyInfo({
    required this.family,
    required this.category,
    required this.faces,
    this.isDisplay = false,
    this.supportsSmallCaps = false,
    this.license = 'OFL-1.1',
    this.isFallback = false,
    this.scripts = const {FontScript.latin},
    this.note,
  });

  /// Family name as used in themes, e.g. `"Source Serif 4"`.
  final String family;

  /// Category.
  final FontCategory category;

  /// Shipped faces.
  final List<FontFaceInfo> faces;

  /// Whether the family is a display face (FontPicker *Display* section).
  final bool isDisplay;

  /// Whether the family has true small caps (`smcp`, Write 06 §6.4).
  final bool supportsSmallCaps;

  /// SPDX license id.
  final String license;

  /// Whether this is a fallback family (not user-selectable).
  final bool isFallback;

  /// Scripts the family covers (used for fallback selection).
  final Set<FontScript> scripts;

  /// Optional note (e.g. "Arial-metric").
  final String? note;

  /// Distinct shipped weights, ascending.
  List<int> get weights {
    final w = {for (final f in faces) f.weight}.toList()..sort();
    return w;
  }

  /// Whether an italic face is shipped for [weight].
  bool hasItalic(int weight) =>
      faces.any((f) => f.italic && f.weight == weight);

  /// The nearest shipped weight to [requested]; ties go heavier (§8.2).
  int snapWeight(int requested) => _nearest(weights, requested);

  /// The closest shipped face for [weight]/[italic]: same style preferred,
  /// then nearest weight (ties heavier).
  FontFaceInfo closestFace(int weight, {bool italic = false}) {
    final sameStyle = faces.where((f) => f.italic == italic).toList();
    final pool = sameStyle.isEmpty ? faces : sameStyle;
    final w = _nearest([for (final f in pool) f.weight], weight);
    return pool.firstWhere((f) => f.weight == w);
  }
}

int _nearest(List<int> candidates, int requested) {
  if (candidates.isEmpty) return requested;
  var best = candidates.first;
  for (final c in candidates) {
    final d = (c - requested).abs();
    final bd = (best - requested).abs();
    if (d < bd || (d == bd && c > best)) best = c;
  }
  return best;
}

const _r4i4r6r7i7 = [
  FontFaceInfo(400),
  FontFaceInfo(400, italic: true),
  FontFaceInfo(600),
  FontFaceInfo(700),
  FontFaceInfo(700, italic: true),
];
const _r4i4r7i7 = [
  FontFaceInfo(400),
  FontFaceInfo(400, italic: true),
  FontFaceInfo(700),
  FontFaceInfo(700, italic: true),
];
const _r4i4r7 = [
  FontFaceInfo(400),
  FontFaceInfo(400, italic: true),
  FontFaceInfo(700),
];
const _r4r6r7 = [FontFaceInfo(400), FontFaceInfo(600), FontFaceInfo(700)];
const _r4r7 = [FontFaceInfo(400), FontFaceInfo(700)];

/// The curated font registry of Write 06 §8.1 (no font files; manifest only).
abstract final class FontRegistry {
  /// Default family of the body role.
  static const defaultBody = 'Inter';

  /// Default family of the heading role.
  static const defaultHeading = 'Inter';

  /// Default family of the mono role.
  static const defaultMono = 'JetBrains Mono';

  /// The user-selectable document families, in registry order.
  static const List<FontFamilyInfo> families = [
    FontFamilyInfo(
      family: 'Inter',
      category: FontCategory.sans,
      faces: _r4i4r6r7i7,
    ),
    FontFamilyInfo(
      family: 'Source Sans 3',
      category: FontCategory.sans,
      faces: _r4i4r6r7i7,
      supportsSmallCaps: true,
    ),
    FontFamilyInfo(
      family: 'IBM Plex Sans',
      category: FontCategory.sans,
      faces: _r4i4r6r7i7,
    ),
    FontFamilyInfo(
      family: 'Open Sans',
      category: FontCategory.sans,
      faces: _r4i4r6r7i7,
    ),
    FontFamilyInfo(
      family: 'Work Sans',
      category: FontCategory.sans,
      faces: _r4i4r6r7i7,
    ),
    FontFamilyInfo(
      family: 'Atkinson Hyperlegible Next',
      category: FontCategory.sans,
      faces: _r4i4r7i7,
      note: 'accessibility',
    ),
    FontFamilyInfo(
      family: 'Montserrat',
      category: FontCategory.sans,
      faces: _r4i4r6r7i7,
      isDisplay: true,
    ),
    FontFamilyInfo(
      family: 'Liberation Sans',
      category: FontCategory.sans,
      faces: _r4i4r7i7,
      note: 'Arial-metric',
    ),
    FontFamilyInfo(
      family: 'Source Serif 4',
      category: FontCategory.serif,
      faces: _r4i4r6r7i7,
      supportsSmallCaps: true,
    ),
    FontFamilyInfo(
      family: 'Merriweather',
      category: FontCategory.serif,
      faces: _r4i4r7i7,
    ),
    FontFamilyInfo(
      family: 'Lora',
      category: FontCategory.serif,
      faces: _r4i4r7i7,
    ),
    FontFamilyInfo(
      family: 'Libre Baskerville',
      category: FontCategory.serif,
      faces: _r4i4r7,
    ),
    FontFamilyInfo(
      family: 'EB Garamond',
      category: FontCategory.serif,
      faces: _r4i4r6r7i7,
      supportsSmallCaps: true,
    ),
    FontFamilyInfo(
      family: 'Crimson Pro',
      category: FontCategory.serif,
      faces: _r4i4r6r7i7,
    ),
    FontFamilyInfo(
      family: 'Literata',
      category: FontCategory.serif,
      faces: _r4i4r7i7,
      supportsSmallCaps: true,
    ),
    FontFamilyInfo(
      family: 'IBM Plex Serif',
      category: FontCategory.serif,
      faces: _r4i4r6r7i7,
    ),
    FontFamilyInfo(
      family: 'Playfair Display',
      category: FontCategory.serif,
      faces: _r4i4r7i7,
      isDisplay: true,
      supportsSmallCaps: true,
    ),
    FontFamilyInfo(
      family: 'Liberation Serif',
      category: FontCategory.serif,
      faces: _r4i4r7i7,
      note: 'Times-metric',
    ),
    FontFamilyInfo(
      family: 'JetBrains Mono',
      category: FontCategory.mono,
      faces: _r4i4r7,
    ),
    FontFamilyInfo(
      family: 'IBM Plex Mono',
      category: FontCategory.mono,
      faces: _r4i4r7,
    ),
    FontFamilyInfo(
      family: 'Source Code Pro',
      category: FontCategory.mono,
      faces: _r4i4r7,
    ),
    FontFamilyInfo(
      family: 'Courier Prime',
      category: FontCategory.mono,
      faces: _r4i4r7i7,
      note: 'typewriter',
    ),
    FontFamilyInfo(
      family: 'Geist',
      category: FontCategory.sans,
      faces: _r4r6r7,
    ),
    FontFamilyInfo(
      family: 'Geist Mono',
      category: FontCategory.mono,
      faces: _r4r6r7,
    ),
  ];

  /// Fallback families (not user-selectable, loaded on demand, Write 06 §8.1).
  static const List<FontFamilyInfo> fallbacks = [
    FontFamilyInfo(
      family: 'Noto Sans',
      category: FontCategory.sans,
      faces: _r4i4r7i7,
      isFallback: true,
    ),
    FontFamilyInfo(
      family: 'Noto Serif',
      category: FontCategory.serif,
      faces: _r4i4r7i7,
      isFallback: true,
    ),
    FontFamilyInfo(
      family: 'Noto Sans Mono',
      category: FontCategory.mono,
      faces: _r4r7,
      isFallback: true,
    ),
    FontFamilyInfo(
      family: 'Noto Sans Symbols 2',
      category: FontCategory.sans,
      faces: [FontFaceInfo(400)],
      isFallback: true,
      scripts: {FontScript.symbols},
    ),
    FontFamilyInfo(
      family: 'Noto Emoji',
      category: FontCategory.sans,
      faces: [FontFaceInfo(400)],
      isFallback: true,
      scripts: {FontScript.emoji},
    ),
    FontFamilyInfo(
      family: 'Noto Sans SC',
      category: FontCategory.sans,
      faces: _r4r7,
      isFallback: true,
      scripts: {FontScript.han},
    ),
    FontFamilyInfo(
      family: 'Noto Sans TC',
      category: FontCategory.sans,
      faces: _r4r7,
      isFallback: true,
      scripts: {FontScript.han},
    ),
    FontFamilyInfo(
      family: 'Noto Sans JP',
      category: FontCategory.sans,
      faces: _r4r7,
      isFallback: true,
      scripts: {FontScript.kana, FontScript.han},
    ),
    FontFamilyInfo(
      family: 'Noto Sans KR',
      category: FontCategory.sans,
      faces: _r4r7,
      isFallback: true,
      scripts: {FontScript.hangul, FontScript.han},
    ),
    FontFamilyInfo(
      family: 'Noto Sans Arabic',
      category: FontCategory.sans,
      faces: _r4r7,
      isFallback: true,
      scripts: {FontScript.arabic},
    ),
    FontFamilyInfo(
      family: 'Noto Sans Hebrew',
      category: FontCategory.sans,
      faces: _r4r7,
      isFallback: true,
      scripts: {FontScript.hebrew},
    ),
    FontFamilyInfo(
      family: 'Noto Sans Devanagari',
      category: FontCategory.sans,
      faces: _r4r7,
      isFallback: true,
      scripts: {FontScript.devanagari},
    ),
  ];

  static final Map<String, FontFamilyInfo> _byLowerName = {
    for (final f in [...families, ...fallbacks]) f.family.toLowerCase(): f,
  };

  /// The entry for [family] (case-insensitive; curated and fallback
  /// families), or `null`.
  static FontFamilyInfo? lookup(String family) =>
      _byLowerName[family.trim().toLowerCase()];

  /// Whether [family] is a user-selectable curated family.
  static bool isSelectable(String family) {
    final f = lookup(family);
    return f != null && !f.isFallback;
  }

  /// The canonical spelling of a selectable [family], or `null` if unknown.
  static String? canonicalName(String family) {
    final f = lookup(family);
    return f == null || f.isFallback ? null : f.family;
  }

  /// Nearest shipped weight of [family] (ties heavier, Write 06 §8.2). Unknown
  /// families snap to the nearest multiple of 100 in 100–900.
  static int snapWeight(String family, int requested) {
    final f = lookup(family);
    if (f != null) return f.snapWeight(requested);
    return ((requested.clamp(100, 900) + 50) ~/ 100 * 100).clamp(100, 900);
  }

  /// The default family for [role] (`body`, `heading`, `mono`).
  static String defaultFor(String role) => switch (role) {
    'mono' => defaultMono,
    'heading' => defaultHeading,
    _ => defaultBody,
  };

  /// The script groups used by [text] beyond what the curated families
  /// cover (Latin/Greek/Cyrillic and general punctuation are reported as
  /// [FontScript.latin]).
  static Set<FontScript> scriptsOf(String text) {
    final out = <FontScript>{};
    for (final r in text.runes) {
      out.add(_scriptOf(r));
    }
    return out;
  }

  static FontScript _scriptOf(int r) {
    if (r < 0x0590) return FontScript.latin;
    if (r < 0x0600) return FontScript.hebrew;
    if (r < 0x0900) {
      return r < 0x0780 || (r >= 0x08A0) ? FontScript.arabic : FontScript.latin;
    }
    if (r < 0x0980) return FontScript.devanagari;
    if (r >= 0x1100 && r < 0x1200) return FontScript.hangul;
    if (r >= 0x1E00 && r < 0x2000) return FontScript.latin;
    if (r >= 0x2000 && r < 0x2070) return FontScript.latin;
    if (r >= 0x2070 && r < 0x2E80) return FontScript.symbols;
    if (r >= 0x3040 && r < 0x3100) return FontScript.kana;
    if (r >= 0x31F0 && r < 0x3200) return FontScript.kana;
    if (r >= 0x2E80 && r < 0xA000) return FontScript.han;
    if (r >= 0xAC00 && r < 0xD7B0) return FontScript.hangul;
    if (r >= 0xF900 && r < 0xFB00) return FontScript.han;
    if (r >= 0xFB1D && r < 0xFB50) return FontScript.hebrew;
    if (r >= 0xFB50 && r < 0xFE00) return FontScript.arabic;
    if (r >= 0xFE70 && r < 0xFF00) return FontScript.arabic;
    if (r >= 0xFF00 && r < 0xFFF0) return FontScript.han;
    if (r >= 0x1F000 && r < 0x1FB00) return FontScript.emoji;
    if (r >= 0x20000 && r < 0x30000) return FontScript.han;
    return FontScript.symbols;
  }

  /// The fallback chain for glyph coverage of [text] (script-aware),
  /// starting with the Noto family of [category].
  static List<FontFamilyInfo> fallbackFamiliesFor(
    String text, {
    FontCategory category = FontCategory.sans,
  }) {
    final scripts = scriptsOf(text);
    final base = switch (category) {
      FontCategory.serif => 'Noto Serif',
      FontCategory.mono => 'Noto Sans Mono',
      FontCategory.sans => 'Noto Sans',
    };
    final names = <String>[base];
    if (scripts.contains(FontScript.arabic)) names.add('Noto Sans Arabic');
    if (scripts.contains(FontScript.hebrew)) names.add('Noto Sans Hebrew');
    if (scripts.contains(FontScript.devanagari)) {
      names.add('Noto Sans Devanagari');
    }
    if (scripts.contains(FontScript.kana)) names.add('Noto Sans JP');
    if (scripts.contains(FontScript.hangul)) names.add('Noto Sans KR');
    if (scripts.contains(FontScript.han) &&
        !scripts.contains(FontScript.kana) &&
        !scripts.contains(FontScript.hangul)) {
      names.add('Noto Sans SC');
    }
    if (scripts.contains(FontScript.symbols)) names.add('Noto Sans Symbols 2');
    if (scripts.contains(FontScript.emoji)) names.add('Noto Emoji');
    return [for (final n in names) lookup(n)!];
  }
}
