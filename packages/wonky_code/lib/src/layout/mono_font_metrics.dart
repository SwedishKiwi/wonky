import 'dart:typed_data';

/// Metrics of a monospace font, in em (Slides 07 §2.3, §3.3): the grid every
/// code surface lays out on (canvas, present mode, PDF, type-in, morph).
///
/// The values come from the font file (`head.unitsPerEm`, `hhea` ascender /
/// descender / line gap, the dominant `hmtx` advance); [fromTtf] reads them,
/// [forFamily] returns the measured values of the bundled faces.
final class MonoFontMetrics {
  /// Creates metrics.
  const MonoFontMetrics({
    required this.family,
    this.advanceEm = 0.6,
    this.ascentEm = 1.0,
    this.descentEm = 0.25,
    this.lineGapEm = 0,
  });

  /// JetBrains Mono (bundled in `wonky_fonts`, the default code font): 1000
  /// units per em, advance 600, ascender 1020, descender −300, no line gap.
  static const jetBrainsMono = MonoFontMetrics(
    family: 'JetBrains Mono',
    advanceEm: 0.6,
    ascentEm: 1.02,
    descentEm: 0.3,
  );

  /// Roboto Mono (bundled): 2048 units per em, advance 1229, ascender 2146,
  /// descender −555.
  static const robotoMono = MonoFontMetrics(
    family: 'Roboto Mono',
    advanceEm: 1229 / 2048,
    ascentEm: 2146 / 2048,
    descentEm: 555 / 2048,
  );

  /// The default code font family (Slides 05 `fonts.mono`, 07 §2.5).
  static const defaultFamily = 'JetBrains Mono';

  static const _known = {
    'jetbrains mono': jetBrainsMono,
    'roboto mono': robotoMono,
  };

  /// The metrics of [family]: measured values for the bundled monospace
  /// faces, else the common monospace advance 0.6 em (IBM Plex Mono, Source
  /// Code Pro, Courier Prime, Geist Mono and Noto Sans Mono all use 600/1000).
  static MonoFontMetrics forFamily(String? family) {
    if (family == null || family.isEmpty || family == '@mono') {
      return jetBrainsMono;
    }
    return _known[family.toLowerCase()] ?? MonoFontMetrics(family: family);
  }

  /// Reads the metrics of a TrueType/OpenType font file, or null when the
  /// tables are missing or malformed. The advance is the most frequent
  /// non-zero advance of `hmtx` (a monospace font's cell width; wide CJK or
  /// zero-width marks don't change it).
  static MonoFontMetrics? fromTtf(String family, Uint8List bytes) {
    try {
      final data = ByteData.sublistView(bytes);
      final numTables = data.getUint16(4);
      final tables = <String, int>{};
      for (var i = 0; i < numTables; i++) {
        final rec = 12 + 16 * i;
        final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
        tables[tag] = data.getUint32(rec + 8);
      }
      final head = tables['head'], hhea = tables['hhea'], hmtx = tables['hmtx'];
      if (head == null || hhea == null || hmtx == null) return null;
      final upm = data.getUint16(head + 18);
      if (upm == 0) return null;
      final ascender = data.getInt16(hhea + 4);
      final descender = data.getInt16(hhea + 6);
      final lineGap = data.getInt16(hhea + 8);
      final count = data.getUint16(hhea + 34);
      final freq = <int, int>{};
      for (var i = 0; i < count; i++) {
        final advance = data.getUint16(hmtx + 4 * i);
        if (advance > 0) freq[advance] = (freq[advance] ?? 0) + 1;
      }
      if (freq.isEmpty) return null;
      var best = freq.keys.first;
      for (final e in freq.entries) {
        if (e.value > freq[best]! || (e.value == freq[best]! && e.key < best)) {
          best = e.key;
        }
      }
      return MonoFontMetrics(
        family: family,
        advanceEm: best / upm,
        ascentEm: ascender / upm,
        descentEm: -descender / upm,
        lineGapEm: lineGap / upm,
      );
    } on RangeError {
      return null;
    }
  }

  /// Font family name.
  final String family;

  /// Advance of one grid column (em).
  final double advanceEm;

  /// Ascent above the baseline (em, positive).
  final double ascentEm;

  /// Descent below the baseline (em, positive).
  final double descentEm;

  /// Line gap (em).
  final double lineGapEm;

  /// Width of one column at [fontSize].
  double columnWidth(double fontSize) => fontSize * advanceEm;

  /// Offset of the baseline from the top of a row of [lineHeight] × font
  /// size (the font's ascent + descent centered in the row, as Flutter's
  /// even leading distribution and the PDF writer place it).
  double baselineInRow(double fontSize, double lineHeight) {
    final content = (ascentEm + descentEm) * fontSize;
    return (lineHeight * fontSize - content) / 2 + ascentEm * fontSize;
  }

  @override
  bool operator ==(Object other) =>
      other is MonoFontMetrics &&
      other.family == family &&
      other.advanceEm == advanceEm &&
      other.ascentEm == ascentEm &&
      other.descentEm == descentEm &&
      other.lineGapEm == lineGapEm;

  @override
  int get hashCode =>
      Object.hash(family, advanceEm, ascentEm, descentEm, lineGapEm);

  @override
  String toString() => 'MonoFontMetrics($family, advance $advanceEm em)';
}
