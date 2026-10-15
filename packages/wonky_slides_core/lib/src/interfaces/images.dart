import 'dart:typed_data';

import '../scene/nodes/scene_nodes.dart';

/// Resolves image references of a deck to pixels (12 §5.3
/// `DeckSession.images`, 10 §11.3 export resources): local bytes for
/// pending uploads and cached images, signed URLs otherwise. The app
/// implements it over the file repository (SL-9/SL-15), the server over
/// file storage (SL-8/SL-20).
abstract interface class SlideImageResolver {
  /// Bytes already in memory (pending upload, cache), or null.
  Uint8List? cachedBytes(SlideImageRef ref);

  /// The image bytes, or null when unavailable (deleted, no access,
  /// offline and not cached).
  Future<Uint8List?> bytes(SlideImageRef ref);

  /// A URL the renderer may load (signed, cached), or null.
  Future<Uri?> url(SlideImageRef ref);
}

/// A [SlideImageResolver] over an in-memory map (tests, previews, AI suggest
/// mode).
final class MemorySlideImageResolver implements SlideImageResolver {
  /// Creates a resolver holding [images] (by `src`).
  MemorySlideImageResolver([Map<String, Uint8List>? images])
    : images = images ?? {};

  /// Bytes by `SlideImageRef.src`.
  final Map<String, Uint8List> images;

  @override
  Uint8List? cachedBytes(SlideImageRef ref) => images[ref.src];

  @override
  Future<Uint8List?> bytes(SlideImageRef ref) async => images[ref.src];

  @override
  Future<Uri?> url(SlideImageRef ref) async => null;
}
