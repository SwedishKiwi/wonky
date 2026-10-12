/// Font loading interface used by exporters (06 §8.3).
library;

import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'font_registry.dart';

/// A loaded font face: TTF bytes for one family/weight/style.
final class FontFace {
  /// Creates a face.
  const FontFace({
    required this.family,
    required this.weight,
    required this.italic,
    required this.bytes,
  });

  /// Family name.
  final String family;

  /// CSS weight 100–900.
  final int weight;

  /// Whether the face is italic.
  final bool italic;

  /// TTF bytes.
  final Uint8List bytes;

  /// A key identifying the face (`family`, `weight`, `italic`).
  FontFaceKey get key => FontFaceKey(family, weight, italic: italic);

  @override
  bool operator ==(Object other) =>
      other is FontFace &&
      other.family == family &&
      other.weight == weight &&
      other.italic == italic &&
      const ListEquality<int>().equals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(family, weight, italic, bytes.length);

  @override
  String toString() =>
      'FontFace($family $weight${italic ? ' italic' : ''}, '
      '${bytes.length} bytes)';
}

/// Identifies a face without its bytes.
final class FontFaceKey implements Comparable<FontFaceKey> {
  /// Creates a key.
  const FontFaceKey(this.family, this.weight, {this.italic = false});

  /// Family name.
  final String family;

  /// CSS weight.
  final int weight;

  /// Whether italic.
  final bool italic;

  @override
  int compareTo(FontFaceKey other) {
    final f = family.compareTo(other.family);
    if (f != 0) return f;
    final w = weight.compareTo(other.weight);
    if (w != 0) return w;
    return (italic ? 1 : 0) - (other.italic ? 1 : 0);
  }

  @override
  bool operator ==(Object other) =>
      other is FontFaceKey &&
      other.family == family &&
      other.weight == weight &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(family, weight, italic);

  @override
  String toString() => '$family $weight${italic ? ' italic' : ''}';
}

/// Thrown by a [FontProvider] when no face of a family is available.
final class FontUnavailableException implements Exception {
  /// Creates the exception.
  const FontUnavailableException(this.family);

  /// The requested family.
  final String family;

  @override
  String toString() => 'FontUnavailableException: no face for "$family"';
}

/// Loads font bytes for exporters (server: file system; client: assets +
/// HTTP for on-demand fallbacks).
abstract interface class FontProvider {
  /// Returns TTF bytes for the closest available face.
  ///
  /// Throws [FontUnavailableException] when the family is not available.
  Future<FontFace> load(String family, {int weight = 400, bool italic = false});

  /// Fallback chain for glyph coverage (script-aware).
  Future<List<FontFace>> fallbacksFor(String text);
}

/// A [FontProvider] over faces held in memory: for tests and for passing
/// pre-resolved bytes into isolates.
final class InMemoryFontProvider implements FontProvider {
  /// Creates a provider over [faces] (curated and fallback families).
  InMemoryFontProvider(Iterable<FontFace> faces)
    : _faces = List.unmodifiable(faces);

  final List<FontFace> _faces;

  /// All faces held by this provider.
  List<FontFace> get faces => _faces;

  @override
  Future<FontFace> load(
    String family, {
    int weight = 400,
    bool italic = false,
  }) async => loadSync(family, weight: weight, italic: italic);

  /// Synchronous variant of [load].
  FontFace loadSync(String family, {int weight = 400, bool italic = false}) {
    final lower = family.trim().toLowerCase();
    final pool = _faces.where((f) => f.family.toLowerCase() == lower).toList();
    if (pool.isEmpty) throw FontUnavailableException(family);
    final sameStyle = pool.where((f) => f.italic == italic).toList();
    final candidates = sameStyle.isEmpty ? pool : sameStyle;
    FontFace best = candidates.first;
    for (final f in candidates) {
      final d = (f.weight - weight).abs();
      final bd = (best.weight - weight).abs();
      if (d < bd || (d == bd && f.weight > best.weight)) best = f;
    }
    return best;
  }

  @override
  Future<List<FontFace>> fallbacksFor(String text) async {
    final out = <FontFace>[];
    for (final info in FontRegistry.fallbackFamiliesFor(text)) {
      final matching = _faces.where(
        (f) => f.family.toLowerCase() == info.family.toLowerCase(),
      );
      final regular = matching.where((f) => !f.italic && f.weight == 400);
      final face = regular.isNotEmpty ? regular.first : matching.firstOrNull;
      if (face != null) out.add(face);
    }
    return out;
  }
}
