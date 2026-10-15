import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart' show ResolvedImageFill;

/// Decoded slide images (03 §6.5, 02 §6.4) for the stage, thumbnails and
/// presenting: bytes come from the [SlideImageResolver] (pending uploads,
/// the file cache, the server), are decoded once and kept in an LRU.
/// Listeners are notified when an image finished decoding, so painters
/// repaint.
class SlideImageCache extends ChangeNotifier {
  /// Creates a cache over [resolver] keeping up to [capacity] images.
  SlideImageCache(
    this.resolver, {
    this.capacity = 64,
    Future<ui.Image> Function(Uint8List bytes)? decode,
  }) : _decode = decode ?? _defaultDecode;

  /// The image bytes source.
  final SlideImageResolver resolver;

  /// Maximum decoded images kept.
  final int capacity;

  final Future<ui.Image> Function(Uint8List bytes) _decode;
  final LinkedHashMap<String, ui.Image> _images = LinkedHashMap();
  final Map<String, Future<void>> _loading = {};
  final Set<String> _failed = {};
  bool _disposed = false;

  /// Bumped every time an image becomes available.
  int get generation => _generation;
  int _generation = 0;

  static Future<ui.Image> _defaultDecode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// The decoded image of [ref], or null while it loads (a load starts) or
  /// when it is unavailable.
  ui.Image? imageOf(SlideImageRef ref) {
    final hit = _images.remove(ref.src);
    if (hit != null) {
      _images[ref.src] = hit;
      return hit;
    }
    if (!_failed.contains(ref.src)) unawaited(load(ref));
    return null;
  }

  /// Whether [ref] failed to load (missing, no access, corrupt).
  bool hasFailed(SlideImageRef ref) => _failed.contains(ref.src);

  /// Loads [ref] (idempotent while loading).
  Future<void> load(SlideImageRef ref) =>
      _loading[ref.src] ??= _load(ref).whenComplete(() {
        // A block body: returning the removed future would make the
        // completion wait for itself.
        _loading.remove(ref.src);
      });

  /// Loads every image of [scene] (prefetch before presenting, 06 §14).
  Future<void> preload(SlideScene scene) =>
      Future.wait([for (final ref in imagesOf(scene)) load(ref)]);

  /// Whether every image of [scene] is decoded (thumbnails are cached
  /// only when complete).
  bool isComplete(SlideScene scene) => imagesOf(
    scene,
  ).every((r) => _images.containsKey(r.src) || _failed.contains(r.src));

  /// The image references of [scene] (image nodes and image fills).
  static Iterable<SlideImageRef> imagesOf(SlideScene scene) sync* {
    final bg = scene.background;
    for (final f in [bg.fill, bg.overlay]) {
      if (f is ResolvedImageFill) {
        yield SlideImageRef('${SlideImageRef.fileScheme}${f.fileUuid}');
      }
    }
    Iterable<SlideImageRef> walk(List<SceneNode> nodes) sync* {
      for (final n in nodes) {
        switch (n) {
          case ImageNode(:final image):
            yield image;
          case PathNode(fill: ResolvedImageFill(:final fileUuid)):
            yield SlideImageRef('${SlideImageRef.fileScheme}$fileUuid');
          case GroupNode(:final children):
            yield* walk(children);
          default:
            break;
        }
      }
    }

    yield* walk(scene.nodes);
  }

  Future<void> _load(SlideImageRef ref) async {
    try {
      final bytes = resolver.cachedBytes(ref) ?? await resolver.bytes(ref);
      if (bytes == null) {
        _failed.add(ref.src);
        return;
      }
      final image = await _decode(bytes);
      if (_disposed) {
        image.dispose();
        return;
      }
      _images[ref.src] = image;
      while (_images.length > capacity) {
        _images.remove(_images.keys.first)?.dispose();
      }
      _generation++;
      notifyListeners();
    } catch (e) {
      debugPrint('Loading slide image ${ref.src} failed: $e');
      _failed.add(ref.src);
    }
  }

  /// Forgets a failure so the image is fetched again (reconnect).
  void retry(SlideImageRef ref) => _failed.remove(ref.src);

  @override
  void dispose() {
    _disposed = true;
    for (final i in _images.values) {
      i.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
