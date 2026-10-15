import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/scene.dart';

import '../stage/slide_image_cache.dart';
import '../stage/slide_stage.dart';

/// A recorded thumbnail.
class SlideThumbnailPicture {
  SlideThumbnailPicture(this.picture, this.size, {required this.complete});

  /// The slide drawn at [size] (logical px).
  final ui.Picture picture;

  /// Logical size of the picture.
  final ui.Size size;

  /// Whether every image was decoded when it was recorded (incomplete
  /// thumbnails are re-recorded once more images are available).
  final bool complete;
}

/// Thumbnails of slides as recorded pictures (03 §18: ≤ 8 ms each, off the
/// critical path, cached by slide revision), LRU-bounded. Keys come from
/// the caller and include the slide's render revision, appearance and
/// width, so a changed slide gets a new entry and the old one ages out.
class SlideThumbnailCache {
  SlideThumbnailCache({this.capacity = 400});

  /// Maximum pictures kept.
  final int capacity;

  final LinkedHashMap<String, (SlideThumbnailPicture, int)> _entries =
      LinkedHashMap();

  /// Pictures recorded so far (tests, benchmarks).
  @visibleForTesting
  int debugRecords = 0;

  /// Cached entries.
  int get length => _entries.length;

  /// The cached picture of [key], or null.
  SlideThumbnailPicture? lookup(String key) => _entries[key]?.$1;

  /// The picture of [key]: cached, or recorded from [scene] at [width]
  /// logical px. An entry recorded while images were missing is recorded
  /// again once [images] has decoded more.
  SlideThumbnailPicture? picture(
    String key,
    SlideScene? Function() scene, {
    required double width,
    SlideImageCache? images,
  }) {
    final hit = _entries.remove(key);
    final gen = images?.generation ?? 0;
    if (hit != null && (hit.$1.complete || hit.$2 == gen)) {
      _entries[key] = hit;
      return hit.$1;
    }
    final s = scene();
    if (s == null || s.width <= 0) return null;
    final scale = width / s.width;
    debugRecords++;
    final picture = recordScene(s, scale: scale, images: images);
    final entry = SlideThumbnailPicture(
      picture,
      ui.Size(width, s.height * scale),
      complete: images == null || images.isComplete(s),
    );
    _entries[key] = (entry, gen);
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return entry;
  }

  /// Drops every entry whose key starts with `<slideId>|`.
  void invalidate(String slideId) =>
      _entries.removeWhere((k, _) => k.startsWith('$slideId|'));

  /// Drops everything.
  void clear() => _entries.clear();
}
